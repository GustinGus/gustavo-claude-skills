# External.psm1 - dependencias externas opcionais, instaladas pelos instaladores oficiais.
#
# Nada aqui copia arquivos de terceiros: o modulo detecta (somente leitura) se a dependencia
# ja esta instalada, mostra o comando oficial, pede confirmacao e o executa.
# Cada dependencia do manifesto tem um "install.method"; hoje so existe "npx".

Set-StrictMode -Version 2.0
Import-Module (Join-Path $PSScriptRoot 'Common.psm1')
Import-Module (Join-Path $PSScriptRoot 'Prereqs.psm1')

$script:Step = 'Externas'

function Get-ExtProp {
    param($Object, [string] $Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $Default
}

function Get-UserHome {
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    return $HOME
}

# Pasta base usada na deteccao. "claude-home" = ~/.claude, onde o instalador oficial
# do Impeccable grava (ele nao le CLAUDE_CONFIG_DIR).
function Get-DetectRoot {
    param([string] $Root)
    switch ($Root) {
        'claude-home' { return (Join-Path (Get-UserHome) '.claude') }
        default { throw "raiz de deteccao desconhecida no manifesto: '$Root'" }
    }
}

# Retorna Installed (tudo presente), Absent (nada presente) ou Incomplete, com o que falta.
function Get-ExternalState {
    param([Parameter(Mandatory)] $Dependency)
    $detect = $Dependency.detect
    $root = Get-DetectRoot (Get-ExtProp $detect 'root' 'claude-home')
    $missing = New-Object System.Collections.Generic.List[string]
    $present = 0
    $total = 0
    foreach ($rel in @(Get-ExtProp $detect 'requiredFiles' @())) {
        $total++
        if (Test-Path -LiteralPath (Join-Path $root $rel) -PathType Leaf) { $present++ } else { $missing.Add($rel) }
    }
    foreach ($g in @(Get-ExtProp $detect 'requiredGlobs' @())) {
        $total++
        $dir = Join-Path $root (Split-Path -Parent $g.pattern)
        $count = 0
        if (Test-Path -LiteralPath $dir -PathType Container) {
            $count = @(Get-ChildItem -LiteralPath $dir -File -Filter (Split-Path -Leaf $g.pattern) -ErrorAction SilentlyContinue).Count
        }
        if ($count -ge [int]$g.min) { $present++ } else { $missing.Add("$($g.pattern) (encontrados $count, minimo $($g.min))") }
    }
    $version = $null
    $versionFile = Get-ExtProp $detect 'versionFile'
    if ($versionFile) {
        $vf = Join-Path $root $versionFile
        if (Test-Path -LiteralPath $vf -PathType Leaf) {
            $line = @(Get-Content -LiteralPath $vf -TotalCount 40 -Encoding UTF8 | Where-Object { $_ -match '^version:\s*(.+?)\s*$' } | Select-Object -First 1)
            if ($line.Count -gt 0 -and $line[0] -match '^version:\s*(.+?)\s*$') { $version = $Matches[1].Trim('"', "'") }
        }
    }
    $state = if ($missing.Count -eq 0) { 'Installed' } elseif ($present -eq 0) { 'Absent' } else { 'Incomplete' }
    return [pscustomobject]@{ State = $state; Missing = $missing.ToArray(); Version = $version; Root = $root }
}

# Monta o comando oficial a partir do manifesto (nunca de entrada do usuario).
function Get-ExternalCommand {
    param([Parameter(Mandatory)] $Dependency)
    $install = $Dependency.install
    if ((Get-ExtProp $install 'method') -ne 'npx') { throw "metodo de instalacao nao suportado: $(Get-ExtProp $install 'method')" }
    $package = "$($install.package)@$($install.version)"
    $argList = @('-y', $package) + @($install.args | ForEach-Object { [string]$_ })
    return [pscustomobject]@{ Tool = 'npx'; Arguments = [string[]]$argList; Display = "npx $($argList -join ' ')" }
}

function Test-ExternalSafety {
    param([Parameter(Mandatory)] $Dependency)
    $problems = New-Object System.Collections.Generic.List[string]
    $argList = @($Dependency.install.args | ForEach-Object { [string]$_ })
    foreach ($req in @(Get-ExtProp $Dependency.install 'requiredArgs' @())) {
        if ($argList -notcontains $req) { $problems.Add("argumento obrigatorio ausente: $req") }
    }
    foreach ($bad in @(Get-ExtProp $Dependency.install 'forbiddenArgs' @())) {
        if ($argList -contains $bad) { $problems.Add("argumento proibido presente: $bad") }
    }
    return , $problems.ToArray()
}

function Install-OneExternal {
    param(
        [Parameter(Mandatory)] $Dependency,
        [switch] $Force,
        [switch] $NonInteractive
    )
    $name = $Dependency.name
    $label = Get-ExtProp $Dependency 'displayName' $name
    $dry = Test-DryRun

    $problems = Test-ExternalSafety $Dependency
    if ($problems.Count -gt 0) {
        Write-Log "${label}: manifesto recusado - $($problems -join '; ')" 'ERROR'
        Add-Result $script:Step $label 'FAILED' "manifesto inseguro: $($problems -join '; ')"
        return
    }

    # O instalador oficial grava em ~/.claude. Se o Claude Code usa outra pasta, a skill ficaria invisivel.
    $detectRoot = Get-DetectRoot (Get-ExtProp $Dependency.detect 'root' 'claude-home')
    $claudeDir = Get-ClaudeConfigDir
    if ([System.IO.Path]::GetFullPath($claudeDir).TrimEnd('\', '/') -ne [System.IO.Path]::GetFullPath($detectRoot).TrimEnd('\', '/')) {
        Write-Log "${label}: o instalador oficial grava em $detectRoot, mas o Claude Code esta usando $claudeDir (CLAUDE_CONFIG_DIR)." 'WARN'
        Add-Result $script:Step $label 'PENDING' "CLAUDE_CONFIG_DIR diferente de $detectRoot; instale manualmente"
        return
    }

    $state = Get-ExternalState $Dependency
    $versionText = if ($state.Version) { " (v$($state.Version))" } else { '' }
    if ($state.State -eq 'Installed') {
        Write-Log "${label}: ja instalado$versionText em $($state.Root)." 'OK'
        Write-Log "Para atualizar: $(Get-ExtProp $Dependency.install 'updateHint' '')" 'DETAIL'
        Add-Result $script:Step $label 'SKIPPED' "ja instalado$versionText"
        return
    }

    $action = 'install'
    if ($state.State -eq 'Incomplete') {
        $action = 'repair'
        Write-Log "${label}: instalacao incompleta em $($state.Root)$versionText. Faltando:" 'WARN'
        foreach ($m in $state.Missing) { Write-Log "  $m" 'DETAIL' }
        Write-Log 'O reparo e feito pelo instalador oficial, que pode sobrescrever os arquivos do Impeccable.' 'DETAIL'
    }
    else {
        Write-Log "${label}: nao instalado." 'INFO'
    }

    $req = Get-ExtProp $Dependency 'requires'
    $minNode = Get-ExtProp $req 'node'
    if ($minNode -and -not (Test-Node -MinVersion $minNode -Step $script:Step -Item "Node.js ($label)")) {
        Add-Result $script:Step $label 'FAILED' "Node.js >= $minNode necessario"
        return
    }
    if ((Get-ExtProp $req 'npx' $false) -and -not (Test-NpmNpx -Step $script:Step)) {
        Add-Result $script:Step $label 'FAILED' 'npm/npx necessarios'
        return
    }

    $cmd = Get-ExternalCommand $Dependency
    $verb = if ($action -eq 'repair') { 'reparar' } else { 'instalar' }
    Write-Log "Comando oficial que sera executado (a partir de $(Get-UserHome)):" 'INFO'
    Write-Log "  $($cmd.Display)" 'INFO'
    foreach ($note in @(Get-ExtProp $Dependency 'notes' @())) { Write-Log $note 'DETAIL' }

    if ($dry) {
        Write-Log "${label}: seria executado para $verb (modo -WhatIf, nada foi executado)." 'INFO'
        Add-Result $script:Step $label 'WHATIF' "seria executado: $($cmd.Display)"
        return
    }
    if (-not $Force) {
        if ($NonInteractive) {
            Write-Log "${label}: nao executado (-NonInteractive sem -Force)." 'WARN'
            Add-Result $script:Step $label 'PENDING' "nao executado; use -Force para $verb sem perguntar"
            return
        }
        $choice = Read-Choice -Prompt "   Executar este comando para $verb o ${label}? [S]im / [N]ao (padrao: N)" -Options @('S', 'N') -Default 'N'
        if ($choice -ne 'S') {
            Write-Log "${label}: recusado pelo usuario." 'WARN'
            if ($action -eq 'repair') { Add-Result $script:Step $label 'PENDING' 'reparo recusado; instalacao continua incompleta' }
            else { Add-Result $script:Step $label 'SKIPPED' 'instalacao recusada pelo usuario' }
            return
        }
    }

    $tool = Get-Command $cmd.Tool -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    Write-LogFile "Executando: $($tool.Source) $($cmd.Arguments -join ' ')"
    Push-Location (Get-UserHome)
    try { $run = Invoke-External $tool.Source $cmd.Arguments }
    finally { Pop-Location }
    Write-LogFile "  -> exit $($run.ExitCode)"
    Write-LogFile $run.Output
    foreach ($line in @($run.Output -split "`n" | Where-Object { $_.Trim() -and $_ -notmatch '^npm (notice|warn)' } | Select-Object -Last 8)) { Write-Log $line 'DETAIL' }

    if ($run.ExitCode -ne 0) {
        Write-Log "${label}: o instalador oficial falhou (exit $($run.ExitCode)). Nada mais foi alterado por este script." 'ERROR'
        Add-Result $script:Step $label 'FAILED' "instalador oficial falhou (exit $($run.ExitCode)); detalhes no log"
        return
    }

    $after = Get-ExternalState $Dependency
    if ($after.State -ne 'Installed') {
        Write-Log "${label}: o instalador terminou, mas ainda faltam: $($after.Missing -join ', ')" 'ERROR'
        Add-Result $script:Step $label 'FAILED' "incompleto apos instalar: $($after.Missing -join ', ')"
        return
    }
    $v = if ($after.Version) { " v$($after.Version)" } else { '' }
    if ($action -eq 'repair') {
        Write-Log "${label}: reparado$v." 'OK'
        Add-Result $script:Step $label 'UPDATED' "reparado$v"
    }
    else {
        Write-Log "${label}: instalado$v em $($after.Root)." 'OK'
        Add-Result $script:Step $label 'INSTALLED' "instalado$v"
    }
}

# $Enabled: nomes das dependencias opcionais pedidas pelo usuario (ex.: -WithImpeccable).
function Install-ExternalDependencies {
    param(
        [Parameter(Mandatory)] [object[]] $Dependencies,
        [string[]] $Enabled = @(),
        [switch] $Force,
        [switch] $NonInteractive
    )
    foreach ($dep in $Dependencies) {
        $label = Get-ExtProp $dep 'displayName' $dep.name
        if ((Get-ExtProp $dep 'optional' $false) -and ($Enabled -notcontains $dep.name)) {
            $switch = Get-ExtProp $dep 'switch' ''
            Write-Log "${label}: opcional, nao solicitado (use -$switch)." 'INFO'
            Add-Result $script:Step $label 'SKIPPED' "opcional; use -$switch para instalar"
            continue
        }
        try {
            Install-OneExternal -Dependency $dep -Force:$Force -NonInteractive:$NonInteractive
        }
        catch {
            Write-Log "${label}: falhou - $($_.Exception.Message)" 'ERROR'
            Write-LogFile ($_ | Out-String)
            Add-Result $script:Step $label 'FAILED' $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Get-ExternalState, Get-ExternalCommand, Test-ExternalSafety, Install-ExternalDependencies
