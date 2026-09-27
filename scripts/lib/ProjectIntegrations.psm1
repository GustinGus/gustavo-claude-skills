# ProjectIntegrations.psm1 - integracoes opcionais que so existem dentro de um projeto.
#
# Hoje: shadcn MCP oficial. O fluxo:
#  1. so roda com -Scope Project e um components.json valido (nunca inicializa shadcn sozinho);
#  2. le o .mcp.json do projeto (somente leitura) e compara a entrada do servidor;
#  3. mostra o comando oficial e os efeitos colaterais, pede confirmacao;
#  4. faz backup de .mcp.json, package.json e lockfiles, executa o comando oficial;
#  5. confere que os outros servidores do .mcp.json ficaram identicos e que a entrada esta correta;
#     se algo falhar, restaura todos os arquivos do backup.
# Reutiliza a montagem de comando e a trava de manifesto de External.psm1.

Set-StrictMode -Version 2.0
Import-Module (Join-Path $PSScriptRoot 'Common.psm1')
Import-Module (Join-Path $PSScriptRoot 'Prereqs.psm1')
Import-Module (Join-Path $PSScriptRoot 'External.psm1')

$script:Step = 'Projeto'

function Get-PiProp {
    param($Object, [string] $Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $Default
}

function ConvertTo-CanonicalJson {
    param($Value)
    if ($null -eq $Value) { return 'null' }
    return ($Value | ConvertTo-Json -Depth 100 -Compress)
}

function Read-JsonFile {
    param([Parameter(Mandatory)] [string] $Path)
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { throw 'arquivo vazio' }
        $data = $raw | ConvertFrom-Json
        if ($data -isnot [System.Management.Automation.PSCustomObject]) { throw 'nao e um objeto JSON' }
        return [pscustomobject]@{ Ok = $true; Data = $data; Error = $null }
    }
    catch {
        return [pscustomobject]@{ Ok = $false; Data = $null; Error = $_.Exception.Message }
    }
}

# components.json "parece shadcn": $schema do ui.shadcn.com, ou aliases + (style ou tailwind).
function Test-ShadcnComponentsJson {
    param([Parameter(Mandatory)] $Data, [Parameter(Mandatory)] $Detect)
    $schema = [string](Get-PiProp $Data '$schema' '')
    $hint = [string](Get-PiProp $Detect 'schemaHint' '')
    if ($hint -and $schema -like "*$hint*") { return $true }
    $hasAliases = $null -ne (Get-PiProp $Data 'aliases')
    $hasStyleOrTailwind = ($null -ne (Get-PiProp $Data 'style')) -or ($null -ne (Get-PiProp $Data 'tailwind'))
    return ($hasAliases -and $hasStyleOrTailwind)
}

function Get-ServerMap {
    param($McpData, [string] $Key)
    $map = [ordered]@{}
    $servers = Get-PiProp $McpData $Key
    if ($servers) {
        foreach ($p in $servers.PSObject.Properties) { $map[$p.Name] = ConvertTo-CanonicalJson $p.Value }
    }
    return $map
}

function Compare-ServerEntry {
    param($Actual, [Parameter(Mandatory)] $Expected)
    $diffs = New-Object System.Collections.Generic.List[string]
    $cmd = [string](Get-PiProp $Actual 'command' '')
    if ($cmd -cne [string]$Expected.command) { $diffs.Add("comando: '$cmd' (esperado '$($Expected.command)')") }
    $a = @(Get-PiProp $Actual 'args' @() | ForEach-Object { [string]$_ })
    $e = @($Expected.args | ForEach-Object { [string]$_ })
    if (($a -join [string][char]31) -cne ($e -join [string][char]31)) {
        $diffs.Add("argumentos: '$($a -join ' ')' (esperado '$($e -join ' ')')")
    }
    $type = Get-PiProp $Actual 'type' 'stdio'
    if ($type -ne 'stdio') { $diffs.Add("tipo: '$type' (esperado 'stdio')") }
    foreach ($p in $Actual.PSObject.Properties) {
        if (@('command', 'args', 'type') -notcontains $p.Name) {
            $isEmpty = ($null -eq $p.Value) -or (($p.Value -is [System.Management.Automation.PSCustomObject]) -and @($p.Value.PSObject.Properties).Count -eq 0)
            if (-not $isEmpty) { $diffs.Add("campo extra: '$($p.Name)'") }
        }
    }
    return , $diffs.ToArray()
}

# ---------------------------------------------------------------- backup / restauracao

function New-ProjectBackup {
    param([string] $ProjectPath, [string[]] $Files, [string] $StateRoot)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $leaf = (Split-Path -Leaf $ProjectPath) -replace '[^A-Za-z0-9._-]', '_'
    $dir = Join-Path (Join-Path (Join-Path $StateRoot 'backups') $stamp) "project-$leaf"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $entries = @()
    foreach ($f in $Files) {
        $src = Join-Path $ProjectPath $f
        $existed = Test-Path -LiteralPath $src -PathType Leaf
        if ($existed) { Copy-Item -LiteralPath $src -Destination (Join-Path $dir $f) -Force }
        $entries += [pscustomobject]@{ File = $f; Existed = $existed }
    }
    return [pscustomobject]@{ Dir = $dir; Entries = $entries; ProjectPath = $ProjectPath }
}

function Restore-ProjectBackup {
    param([Parameter(Mandatory)] $Backup)
    foreach ($e in $Backup.Entries) {
        $target = Join-Path $Backup.ProjectPath $e.File
        if ($e.Existed) { Copy-Item -LiteralPath (Join-Path $Backup.Dir $e.File) -Destination $target -Force }
        elseif (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
}

# ---------------------------------------------------------------- fluxo principal

function Install-OneProjectIntegration {
    param(
        [Parameter(Mandatory)] $Integration,
        [Parameter(Mandatory)] [string] $ProjectPath,
        [Parameter(Mandatory)] [string] $StateRoot,
        [switch] $Force,
        [switch] $NonInteractive
    )
    $label = Get-PiProp $Integration 'displayName' $Integration.name
    $dry = Test-DryRun
    $detect = $Integration.detect
    $cfg = $Integration.config

    $problems = Test-ExternalSafety $Integration
    if ($problems.Count -gt 0) {
        Write-Log "${label}: manifesto recusado - $($problems -join '; ')" 'ERROR'
        Add-Result $script:Step $label 'FAILED' "manifesto inseguro: $($problems -join '; ')"
        return
    }

    Write-Log "Projeto: $ProjectPath" 'INFO'

    # 1. components.json: o projeto precisa ja ser shadcn. Nunca inicializamos sozinhos.
    $componentsPath = Join-Path $ProjectPath $detect.file
    $initHint = Get-PiProp $Integration 'initHint' ''
    if (-not (Test-Path -LiteralPath $componentsPath -PathType Leaf)) {
        Write-Log "${label}: $($detect.file) nao encontrado; o projeto ainda nao usa shadcn. Nada foi alterado." 'WARN'
        Write-Log "Para inicializar o shadcn (nao executado por este instalador): $initHint" 'DETAIL'
        Add-Result $script:Step $label 'PENDING' "projeto sem $($detect.file); inicialize com '$initHint' se quiser"
        return
    }
    $components = Read-JsonFile $componentsPath
    if (-not $components.Ok) {
        Write-Log "${label}: $($detect.file) nao e um JSON valido ($($components.Error))." 'WARN'
        Add-Result $script:Step $label 'PENDING' "$($detect.file) invalido; corrija o arquivo"
        return
    }
    if (-not (Test-ShadcnComponentsJson $components.Data $detect)) {
        Write-Log "${label}: $($detect.file) existe, mas nao parece uma configuracao do shadcn." 'WARN'
        Add-Result $script:Step $label 'PENDING' "$($detect.file) nao parece do shadcn"
        return
    }
    Write-Log "$($detect.file): configuracao shadcn valida." 'OK'

    foreach ($f in @(Get-PiProp $Integration 'requiresFiles' @())) {
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath $f) -PathType Leaf)) {
            Write-Log "${label}: $f nao encontrado; o comando oficial precisa de um projeto Node." 'WARN'
            Add-Result $script:Step $label 'PENDING' "$f ausente no projeto"
            return
        }
    }

    # 2. .mcp.json atual (somente leitura).
    $mcpPath = Join-Path $ProjectPath $cfg.file
    $serversKey = $cfg.serversKey
    $entryName = $cfg.entry
    $mcpBefore = $null
    $entry = $null
    if (Test-Path -LiteralPath $mcpPath -PathType Leaf) {
        $mcpBefore = Read-JsonFile $mcpPath
        if (-not $mcpBefore.Ok) {
            # O comando oficial ignora erro de leitura e recria o arquivo: perderiamos os outros servidores.
            Write-Log "${label}: $($cfg.file) nao e um JSON valido ($($mcpBefore.Error)). Nada foi alterado." 'WARN'
            Add-Result $script:Step $label 'PENDING' "$($cfg.file) invalido; corrija antes (o comando oficial o sobrescreveria)"
            return
        }
        $entry = Get-PiProp (Get-PiProp $mcpBefore.Data $serversKey) $entryName
    }
    $othersBefore = if ($mcpBefore) { Get-ServerMap $mcpBefore.Data $serversKey } else { [ordered]@{} }
    if ($othersBefore.Contains($entryName)) { $othersBefore.Remove($entryName) }
    if ($othersBefore.Count -gt 0) {
        Write-Log "Outros servidores em $($cfg.file) que serao preservados: $(@($othersBefore.Keys) -join ', ')" 'DETAIL'
    }

    $action = 'add'
    $reason = $null
    if ($null -ne $entry) {
        $diffs = Compare-ServerEntry $entry $cfg.expected
        if ($diffs.Count -eq 0) {
            Write-Log "${label}: ja configurado em $($cfg.file) com a configuracao oficial." 'OK'
            Add-Result $script:Step $label 'SKIPPED' "ja configurado em $($cfg.file)"
            return
        }
        $action = 'replace'
        $reason = "entrada '$entryName' diferente da oficial"
        Write-Log "${label}: $reason em $($cfg.file):" 'WARN'
        foreach ($d in $diffs) { Write-Log $d 'DETAIL' }
    }

    # 3. Pre-requisitos do comando oficial.
    $req = Get-PiProp $Integration 'requires'
    $minNode = Get-PiProp $req 'node'
    if ($minNode -and -not (Test-Node -MinVersion $minNode -Step $script:Step -Item "Node.js ($label)")) {
        Add-Result $script:Step $label 'FAILED' "Node.js >= $minNode necessario"
        return
    }
    if ((Get-PiProp $req 'npx' $false) -and -not (Test-NpmNpx -Step $script:Step)) {
        Add-Result $script:Step $label 'FAILED' 'npm/npx necessarios'
        return
    }

    # 4. Mostrar o comando e confirmar.
    $cmd = Get-ExternalCommand $Integration
    Write-Log "Comando oficial que sera executado em '$ProjectPath':" 'INFO'
    Write-Log "  $($cmd.Display)" 'INFO'
    if ($action -eq 'replace') { Write-Log "Antes dele, so a entrada '$entryName' e removida de $($cfg.file); os outros servidores ficam." 'DETAIL' }
    foreach ($note in @(Get-PiProp $Integration 'notes' @())) { Write-Log $note 'DETAIL' }

    if ($dry) {
        $verb = if ($action -eq 'replace') { 'seria substituido' } else { 'seria configurado' }
        if ($action -eq 'replace' -and -not $Force) { $verb = 'pendente: configuracao diferente (seria perguntado)' }
        Write-Log "${label}: $verb (modo -WhatIf, nada foi executado)." 'INFO'
        Add-Result $script:Step $label 'WHATIF' "${verb}: $($cmd.Display)"
        return
    }
    if (-not $Force) {
        if ($NonInteractive) {
            $msg = if ($action -eq 'replace') { "$reason; mantida" } else { 'nao configurado' }
            Write-Log "${label}: nao executado (-NonInteractive sem -Force)." 'WARN'
            Add-Result $script:Step $label 'PENDING' "$msg; use -Force para executar o comando oficial"
            return
        }
        $question = if ($action -eq 'replace') { "Substituir a entrada '$entryName' executando o comando oficial?" } else { 'Executar o comando oficial neste projeto?' }
        $choice = Read-Choice -Prompt "   ${question} [S]im / [N]ao (padrao: N)" -Options @('S', 'N') -Default 'N'
        if ($choice -ne 'S') {
            Write-Log "${label}: recusado pelo usuario. Nada foi alterado." 'WARN'
            if ($action -eq 'replace') { Add-Result $script:Step $label 'PENDING' "$reason; mantida (recusado)" }
            else { Add-Result $script:Step $label 'SKIPPED' 'configuracao recusada pelo usuario' }
            return
        }
    }

    # 5. Backup, execucao e verificacao; qualquer falha restaura os arquivos.
    $backup = New-ProjectBackup -ProjectPath $ProjectPath -Files @(@($cfg.file) + @(Get-PiProp $Integration 'backupFiles' @())) -StateRoot $StateRoot
    Write-Log "Backup de $(@($backup.Entries | Where-Object { $_.Existed } | ForEach-Object { $_.File }) -join ', ') em $($backup.Dir)" 'DETAIL'
    try {
        if ($action -eq 'replace') {
            $servers = Get-PiProp $mcpBefore.Data $serversKey
            $servers.PSObject.Properties.Remove($entryName)
            Write-Utf8File -Path $mcpPath -Content (($mcpBefore.Data | ConvertTo-Json -Depth 100) + "`n")
        }

        $tool = Get-Command $cmd.Tool -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        Write-LogFile "Executando em ${ProjectPath}: $($tool.Source) $($cmd.Arguments -join ' ')"
        Push-Location -LiteralPath $ProjectPath
        try { $run = Invoke-External $tool.Source $cmd.Arguments }
        finally { Pop-Location }
        Write-LogFile "  -> exit $($run.ExitCode)"
        Write-LogFile $run.Output
        foreach ($line in @($run.Output -split "`n" | Where-Object { $_.Trim() -and $_ -notmatch '^npm (notice|warn)' } | Select-Object -Last 6)) { Write-Log $line 'DETAIL' }
        if ($run.ExitCode -ne 0) { throw "comando oficial falhou (exit $($run.ExitCode))" }

        $after = Read-JsonFile $mcpPath
        if (-not $after.Ok) { throw "$($cfg.file) ficou invalido apos o comando: $($after.Error)" }
        $othersAfter = Get-ServerMap $after.Data $serversKey
        foreach ($name in @($othersBefore.Keys)) {
            if (-not $othersAfter.Contains($name)) { throw "o servidor '$name' sumiu de $($cfg.file)" }
            if ($othersAfter[$name] -cne $othersBefore[$name]) { throw "o servidor '$name' foi alterado em $($cfg.file)" }
        }
        $newEntry = Get-PiProp (Get-PiProp $after.Data $serversKey) $entryName
        if ($null -eq $newEntry) { throw "a entrada '$entryName' nao foi criada em $($cfg.file)" }
        $left = Compare-ServerEntry $newEntry $cfg.expected
        if ($left.Count -gt 0) { throw "a entrada '$entryName' ficou diferente da oficial: $($left -join '; ')" }
    }
    catch {
        $why = $_.Exception.Message
        try {
            Restore-ProjectBackup $backup
            Write-Log "${label}: $why. Arquivos do projeto restaurados do backup." 'ERROR'
            Add-Result $script:Step $label 'FAILED' "$why; arquivos restaurados"
        }
        catch {
            Write-Log "${label}: $why. ATENCAO: a restauracao falhou ($($_.Exception.Message)); backup em $($backup.Dir)" 'ERROR'
            Add-Result $script:Step $label 'FAILED' "$why; restauracao falhou, backup em $($backup.Dir)"
        }
        Write-Log 'node_modules pode conter pacotes baixados pela tentativa; nenhum outro arquivo foi alterado.' 'DETAIL'
        return
    }

    $verbDone = if ($action -eq 'replace') { 'substituido' } else { 'configurado' }
    Write-Log "${label}: $verbDone em $mcpPath. Outros servidores preservados: $($othersBefore.Count)." 'OK'
    Write-Log 'Na primeira vez, o Claude Code pede para aprovar servidores MCP de .mcp.json do projeto.' 'DETAIL'
    Add-Result $script:Step $label 'CONFIGURED' "$verbDone em $($cfg.file); outros servidores preservados: $($othersBefore.Count)"
}

function Install-ProjectIntegrations {
    param(
        [Parameter(Mandatory)] [object[]] $Integrations,
        [string[]] $Enabled = @(),
        [Parameter(Mandatory)] [string] $Scope,
        [string] $ProjectPath,
        [Parameter(Mandatory)] [string] $StateRoot,
        [switch] $Force,
        [switch] $NonInteractive
    )
    foreach ($it in $Integrations) {
        $label = Get-PiProp $it 'displayName' $it.name
        $switch = Get-PiProp $it 'switch' ''
        if ($Enabled -notcontains $it.name) {
            Write-Log "${label}: opcional, por projeto, nao solicitado (use -$switch com -Scope Project)." 'INFO'
            Add-Result $script:Step $label 'SKIPPED' "opcional; use -$switch -Scope Project -ProjectPath <projeto>"
            continue
        }
        if ($Scope -ne 'Project') {
            Write-Log "${label}: esta integracao e exclusivamente por projeto e nunca e configurada globalmente." 'WARN'
            Write-Log "Use: .\install.ps1 -Scope Project -ProjectPath <pasta do projeto> -$switch" 'DETAIL'
            Add-Result $script:Step $label 'PENDING' "somente por projeto; rode com -Scope Project -ProjectPath <projeto>"
            continue
        }
        try {
            Install-OneProjectIntegration -Integration $it -ProjectPath $ProjectPath -StateRoot $StateRoot `
                -Force:$Force -NonInteractive:$NonInteractive
        }
        catch {
            Write-Log "${label}: falhou - $($_.Exception.Message)" 'ERROR'
            Write-LogFile ($_ | Out-String)
            Add-Result $script:Step $label 'FAILED' $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Install-ProjectIntegrations, Test-ShadcnComponentsJson, Compare-ServerEntry
