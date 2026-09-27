# Mcp.psm1 - configuracao dos servidores MCP do manifesto via "claude mcp".
#
# A configuracao existente e lida direto do arquivo de usuario do Claude Code
# (.claude.json), porque "claude mcp get" tenta conectar no servidor e iniciaria o npx.
# Alteracoes sempre passam pelo CLI oficial: "claude mcp remove" / "claude mcp add".

Set-StrictMode -Version 2.0
Import-Module (Join-Path $PSScriptRoot 'Common.psm1')
Import-Module (Join-Path $PSScriptRoot 'Prereqs.psm1')

function Get-McpProp {
    param($Object, [string] $Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }
    $p = $Object.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $Default
}

function Test-IsWindowsPlatform {
    return ($PSVersionTable.PSEdition -eq 'Desktop') -or [bool](Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue)
}

# Escopo user: <CLAUDE_CONFIG_DIR>\.claude.json ou %USERPROFILE%\.claude.json
# (confirmado com Claude Code 2.1.283).
function Get-ClaudeUserConfigFile {
    if ($env:CLAUDE_CONFIG_DIR) {
        return (Join-Path ([System.IO.Path]::GetFullPath($env:CLAUDE_CONFIG_DIR)) '.claude.json')
    }
    $homeDir = $env:USERPROFILE
    if (-not $homeDir) { $homeDir = $HOME }
    return (Join-Path $homeDir '.claude.json')
}

# Comando esperado. No Windows o npx (npx.cmd) precisa ser iniciado via "cmd /c".
function Get-McpExpectedServer {
    param([Parameter(Mandatory)] $Entry, [bool] $Windows = (Test-IsWindowsPlatform))
    $argList = @($Entry.args | ForEach-Object { [string]$_ })
    $wrapper = @(Get-McpProp $Entry 'windowsWrapper' @())
    if ($Windows -and $wrapper.Count -gt 0) {
        return [pscustomobject]@{
            Type    = 'stdio'
            Command = [string]$wrapper[0]
            Args    = [string[]](@($wrapper | Select-Object -Skip 1) + @([string]$Entry.command) + $argList)
        }
    }
    return [pscustomobject]@{ Type = 'stdio'; Command = [string]$Entry.command; Args = [string[]]$argList }
}

# Garante que o manifesto nao perdeu as flags aprovadas nem ganhou flags proibidas.
function Test-McpEntrySafety {
    param([Parameter(Mandatory)] $Entry)
    $problems = New-Object System.Collections.Generic.List[string]
    $argList = @($Entry.args | ForEach-Object { [string]$_ })
    foreach ($req in @(Get-McpProp $Entry 'requiredArgs' @())) {
        if ($argList -notcontains $req) { $problems.Add("flag obrigatoria ausente: $req") }
    }
    foreach ($bad in @(Get-McpProp $Entry 'forbiddenArgs' @())) {
        foreach ($a in $argList) {
            if ($a -eq $bad -or $a.StartsWith("$bad=")) { $problems.Add("flag proibida presente: $a") }
        }
    }
    if ((Get-McpProp $Entry 'scope') -ne 'user') { $problems.Add("escopo diferente de 'user'") }
    return , $problems.ToArray()
}

# Le a definicao atual do servidor no escopo user.
function Read-UserMcpServer {
    param([Parameter(Mandatory)] [string] $ConfigFile, [Parameter(Mandatory)] [string] $Name)
    if (-not (Test-Path -LiteralPath $ConfigFile)) {
        return [pscustomobject]@{ Readable = $true; Found = $false; Server = $null; Error = $null }
    }
    try {
        $raw = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8
        $data = $null
        try { $data = $raw | ConvertFrom-Json }
        catch {
            # Windows PowerShell 5.1 recusa chaves que diferem so por maiusculas; o 7+ le como hashtable.
            if ($PSVersionTable.PSVersion.Major -ge 6) { $data = $raw | ConvertFrom-Json -AsHashtable }
            else { throw }
        }
        $servers = Get-McpProp $data 'mcpServers'
        $server = Get-McpProp $servers $Name
        return [pscustomobject]@{ Readable = $true; Found = ($null -ne $server); Server = $server; Error = $null }
    }
    catch {
        return [pscustomobject]@{ Readable = $false; Found = $false; Server = $null; Error = $_.Exception.Message }
    }
}

function Compare-McpServer {
    param($Actual, [Parameter(Mandatory)] $Expected, [bool] $Windows = (Test-IsWindowsPlatform))
    $diffs = New-Object System.Collections.Generic.List[string]
    $type = Get-McpProp $Actual 'type' 'stdio'
    if ($type -ne $Expected.Type) { $diffs.Add("tipo: '$type' (esperado '$($Expected.Type)')") }

    $command = [string](Get-McpProp $Actual 'command' '')
    $sameCommand = if ($Windows) { [string]::Equals($command, $Expected.Command, [System.StringComparison]::OrdinalIgnoreCase) }
    else { $command -ceq $Expected.Command }
    if (-not $sameCommand) { $diffs.Add("comando: '$command' (esperado '$($Expected.Command)')") }

    $argList = @(Get-McpProp $Actual 'args' @() | ForEach-Object { [string]$_ })
    if (($argList -join [string][char]31) -cne ($Expected.Args -join [string][char]31)) {
        $diffs.Add("argumentos: '$($argList -join ' ')'")
        $diffs.Add("  esperado: '$($Expected.Args -join ' ')'")
    }

    $envVars = Get-McpProp $Actual 'env'
    $envCount = 0
    if ($envVars -is [System.Collections.IDictionary]) { $envCount = $envVars.Count }
    elseif ($envVars) { $envCount = @($envVars.PSObject.Properties).Count }
    if ($envCount -gt 0) { $diffs.Add("variaveis de ambiente extras: $envCount") }
    return , $diffs.ToArray()
}

function Format-McpServer {
    param($Server)
    $argList = @(Get-McpProp $Server 'args' @() | ForEach-Object { [string]$_ })
    return ("$(Get-McpProp $Server 'command' '') $($argList -join ' ')").Trim()
}

function Invoke-ClaudeMcp {
    param([Parameter(Mandatory)] [string] $ClaudePath, [Parameter(Mandatory)] [string[]] $Arguments)
    Write-LogFile "claude $($Arguments -join ' ')"
    $run = Invoke-External $ClaudePath $Arguments
    Write-LogFile "  -> exit $($run.ExitCode): $($run.Output)"
    return $run
}

function Add-UserMcpServer {
    param([string] $ClaudePath, [string] $Name, [string] $Command, [string[]] $Arguments, $EnvVars)
    $cliArgs = @('mcp', 'add', $Name, '--scope', 'user')
    if ($EnvVars) {
        $pairs = if ($EnvVars -is [System.Collections.IDictionary]) { $EnvVars.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } }
        else { $EnvVars.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" } }
        foreach ($p in @($pairs)) { $cliArgs += @('-e', $p) }
    }
    # "--" separa as opcoes do claude das do servidor (-y, --isolated, ...).
    $cliArgs += @('--', $Command) + @($Arguments)
    return Invoke-ClaudeMcp $ClaudePath $cliArgs
}

function Install-OneMcp {
    param(
        [Parameter(Mandatory)] $Entry,
        [Parameter(Mandatory)] [string] $ClaudePath,
        [Parameter(Mandatory)] [string] $StateRoot,
        [switch] $Force,
        [switch] $NonInteractive
    )
    $name = $Entry.name
    $dry = Test-DryRun
    $configFile = Get-ClaudeUserConfigFile
    $expected = Get-McpExpectedServer $Entry
    $expectedText = "$($expected.Command) $($expected.Args -join ' ')"

    Write-Log "Configuracao desejada (escopo user): $expectedText" 'INFO'
    Write-Log "Arquivo de configuracao: $configFile" 'DETAIL'

    $current = Read-UserMcpServer $configFile $name
    $action = $null
    $reason = $null

    if (-not $current.Readable) {
        $reason = "nao foi possivel ler $configFile ($($current.Error))"
        Write-Log "${name}: $reason" 'WARN'
        if ($Force) { $action = 'replace' } else { $action = 'skip' }
    }
    elseif (-not $current.Found) {
        $action = 'add'
    }
    else {
        $diffs = Compare-McpServer $current.Server $expected
        if ($diffs.Count -eq 0) {
            Write-Log "${name}: ja configurado e identico." 'OK'
            Add-Result 'MCP' $name 'SKIPPED' 'ja configurado e identico'
            return
        }
        $reason = 'configuracao existente diferente da aprovada'
        Write-Log "${name}: $reason." 'WARN'
        foreach ($d in $diffs) { Write-Log $d 'DETAIL' }
        if ($Force) { $action = 'replace' }
        elseif ($NonInteractive -or $dry) { $action = 'skip' }
        else {
            $choice = Read-Choice -Prompt "   ${name}: [S]ubstituir pela configuracao aprovada ou [P]ular? (padrao: P)" -Options @('S', 'P') -Default 'P'
            $action = if ($choice -eq 'S') { 'replace' } else { 'skip' }
        }
    }

    if ($action -eq 'skip') {
        $hint = if ($dry) { 'na execucao real sera perguntado (ou use -Force)' } else { 'rode sem -NonInteractive para decidir, ou com -Force para substituir' }
        Write-Log "${name}: mantido como esta ($hint)." 'WARN'
        Add-Result 'MCP' $name 'PENDING' "$reason; mantido"
        return
    }

    if ($dry) {
        $verb = if ($action -eq 'add') { 'seria adicionado' } else { 'seria substituido' }
        Write-Log "${name}: $verb (claude mcp add $name --scope user -- $expectedText)." 'INFO'
        Add-Result 'MCP' $name 'WHATIF' $verb
        return
    }

    $old = $current.Server
    if ($action -eq 'replace') {
        if ($old) {
            $backupDir = Join-Path (Join-Path $StateRoot 'backups') (Get-Date -Format 'yyyyMMdd-HHmmss')
            $backupFile = Join-Path $backupDir "mcp-$name.json"
            Write-Utf8File -Path $backupFile -Content ($old | ConvertTo-Json -Depth 10)
            Write-Log "Configuracao anterior salva em $backupFile" 'DETAIL'
        }
        $rm = Invoke-ClaudeMcp $ClaudePath @('mcp', 'remove', $name, '-s', 'user')
        if ($rm.ExitCode -ne 0 -and $rm.Output -notmatch 'No MCP server named') {
            Write-Log "${name}: 'claude mcp remove' falhou: $($rm.Output)" 'ERROR'
            Add-Result 'MCP' $name 'FAILED' "claude mcp remove falhou (exit $($rm.ExitCode))"
            return
        }
    }

    $add = Add-UserMcpServer -ClaudePath $ClaudePath -Name $name -Command $expected.Command -Arguments $expected.Args
    if ($add.ExitCode -ne 0) {
        Write-Log "${name}: 'claude mcp add' falhou (exit $($add.ExitCode)): $($add.Output)" 'ERROR'
        $restored = ''
        if ($old -and (Get-McpProp $old 'type' 'stdio') -eq 'stdio') {
            $back = Add-UserMcpServer -ClaudePath $ClaudePath -Name $name -Command (Get-McpProp $old 'command') `
                -Arguments ([string[]]@(Get-McpProp $old 'args' @())) -EnvVars (Get-McpProp $old 'env')
            $restored = if ($back.ExitCode -eq 0) { '; configuracao anterior restaurada' } else { '; nao foi possivel restaurar a anterior (veja o backup)' }
            Write-Log "Restauracao da configuracao anterior: exit $($back.ExitCode)" 'DETAIL'
        }
        Add-Result 'MCP' $name 'FAILED' "claude mcp add falhou (exit $($add.ExitCode))$restored"
        return
    }

    if ($action -eq 'add') {
        Write-Log "${name}: adicionado no escopo user." 'OK'
        Add-Result 'MCP' $name 'OK' 'adicionado (escopo user)'
    }
    else {
        Write-Log "${name}: substituido pela configuracao aprovada." 'OK'
        Add-Result 'MCP' $name 'UPDATED' 'substituido (configuracao anterior em backups)'
    }
}

function Install-McpServers {
    param(
        [Parameter(Mandatory)] [object[]] $Servers,
        [Parameter(Mandatory)] [string] $ClaudePath,
        [Parameter(Mandatory)] [string] $StateRoot,
        [switch] $Force,
        [switch] $NonInteractive
    )
    foreach ($entry in $Servers) {
        $name = $entry.name
        try {
            $problems = Test-McpEntrySafety $entry
            if ($problems.Count -gt 0) {
                Write-Log "${name}: manifesto recusado - $($problems -join '; ')" 'ERROR'
                Add-Result 'MCP' $name 'FAILED' "manifesto inseguro: $($problems -join '; ')"
                continue
            }

            $req = Get-McpProp $entry 'requires'
            $ready = $true
            $minNode = Get-McpProp $req 'node'
            if ($minNode) {
                if (-not (Test-Node -MinVersion $minNode -Step 'MCP')) { $ready = $false }
            }
            if ((Get-McpProp $req 'npx' $false) -and -not (Test-NpmNpx -Step 'MCP')) { $ready = $false }
            if (Get-McpProp $req 'chrome' $false) { [void](Test-Chrome -Step 'MCP') }

            if (-not $ready) {
                Write-Log "${name}: nao configurado porque faltam pre-requisitos (veja acima)." 'ERROR'
                Add-Result 'MCP' $name 'FAILED' 'pre-requisitos ausentes (Node.js/npx)'
                continue
            }
            Install-OneMcp -Entry $entry -ClaudePath $ClaudePath -StateRoot $StateRoot -Force:$Force -NonInteractive:$NonInteractive
        }
        catch {
            Write-Log "${name}: falhou - $($_.Exception.Message)" 'ERROR'
            Write-LogFile ($_ | Out-String)
            Add-Result 'MCP' $name 'FAILED' $_.Exception.Message
        }
    }
}

function Test-McpServers {
    param([Parameter(Mandatory)] [object[]] $Servers)
    $configFile = Get-ClaudeUserConfigFile
    $mcpResults = @((Get-Results) | Where-Object { $_.Step -eq 'MCP' })
    foreach ($entry in $Servers) {
        $name = $entry.name
        # So verifica o que foi (ou ja estava) configurado; falhas e pendencias ja aparecem no resumo.
        $status = @($mcpResults | Where-Object { $_.Item -eq $name } | Select-Object -Last 1)
        if ($status.Count -eq 0 -or @('OK', 'UPDATED', 'SKIPPED') -notcontains $status[0].Status) { continue }
        $current = Read-UserMcpServer $configFile $name
        $diffs = @()
        if ($current.Found) { $diffs = Compare-McpServer $current.Server (Get-McpExpectedServer $entry) }
        if ($current.Found -and $diffs.Count -eq 0) {
            Write-Log "${name}: presente no escopo user com a configuracao aprovada." 'OK'
            Add-Result 'MCP' "$name (verificacao)" 'OK' (Format-McpServer $current.Server)
        }
        else {
            $why = if (-not $current.Readable) { "arquivo ilegivel: $($current.Error)" } elseif (-not $current.Found) { "ausente em $configFile" } else { $diffs -join '; ' }
            Write-Log "${name}: verificacao falhou - $why" 'ERROR'
            Add-Result 'MCP' "$name (verificacao)" 'FAILED' $why
        }
    }
}

Export-ModuleMember -Function Get-ClaudeUserConfigFile, Get-McpExpectedServer, Test-McpEntrySafety,
    Read-UserMcpServer, Compare-McpServer, Install-McpServers, Test-McpServers
