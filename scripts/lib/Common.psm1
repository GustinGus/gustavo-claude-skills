# Common.psm1 - log, resultados, confirmacoes e caminhos compartilhados pelo instalador.
# Compativel com Windows PowerShell 5.1 e PowerShell 7+.

Set-StrictMode -Version 2.0

$script:LogFile = $null
$script:DryRun = $false
$script:Results = New-Object System.Collections.Generic.List[object]

function Initialize-Installer {
    param(
        [Parameter(Mandatory)] [string] $StateRoot,
        [switch] $DryRun
    )
    $script:DryRun = [bool]$DryRun
    $script:Results.Clear()
    if ($script:DryRun) {
        $script:LogFile = $null
        return
    }
    $logDir = Join-Path $StateRoot 'logs'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:LogFile = Join-Path $logDir "install-$stamp.log"
}

function Test-DryRun { return $script:DryRun }

function Get-LogFile { return $script:LogFile }

function Write-Log {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'STEP', 'DETAIL')] [string] $Level = 'INFO'
    )
    $colors = @{ INFO = 'Gray'; OK = 'Green'; WARN = 'Yellow'; ERROR = 'Red'; STEP = 'Cyan'; DETAIL = 'DarkGray' }
    $prefix = @{ INFO = '   '; OK = ' + '; WARN = ' ! '; ERROR = ' x '; STEP = '== '; DETAIL = '     ' }
    Write-Host ($prefix[$Level] + $Message) -ForegroundColor $colors[$Level]
    Write-LogFile "[$Level] $Message"
}

# Grava so no arquivo de log (detalhes tecnicos que nao precisam aparecer na tela).
function Write-LogFile {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Message)
    if ($script:LogFile) {
        $line = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $Message
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8
    }
}

# Status possiveis: OK, INSTALLED, SKIPPED, UPDATED, WARN, PENDING, FAILED, WHATIF
function Add-Result {
    param(
        [Parameter(Mandatory)] [string] $Step,
        [Parameter(Mandatory)] [string] $Item,
        [Parameter(Mandatory)] [ValidateSet('OK', 'INSTALLED', 'SKIPPED', 'UPDATED', 'WARN', 'PENDING', 'FAILED', 'WHATIF')] [string] $Status,
        [string] $Message = ''
    )
    $script:Results.Add([pscustomobject]@{ Step = $Step; Item = $Item; Status = $Status; Message = $Message })
    Write-LogFile "[RESULT] $Step | $Item | $Status | $Message"
}

function Get-Results { return , $script:Results.ToArray() }

function Write-Summary {
    $colors = @{ OK = 'Green'; INSTALLED = 'Green'; UPDATED = 'Green'; SKIPPED = 'Gray'; WHATIF = 'Cyan'; WARN = 'Yellow'; PENDING = 'Yellow'; FAILED = 'Red' }
    $titles = [ordered]@{
        Instalador  = 'Instalador'
        Prereqs     = 'Pre-requisitos'
        Skills      = 'Skills'
        MCP         = 'Chrome DevTools MCP'
        Externas    = "Depend$([char]0x00EA)ncias externas"
        Verificacao = 'Verificacao final'
    }
    Write-Host ''
    Write-Host '== Resumo' -ForegroundColor Cyan
    $steps = @($titles.Keys) + @($script:Results | ForEach-Object { $_.Step } | Where-Object { -not $titles.Contains($_) } | Select-Object -Unique)
    foreach ($step in $steps) {
        $group = @($script:Results | Where-Object { $_.Step -eq $step })
        if ($group.Count -eq 0) { continue }
        $title = if ($titles.Contains($step)) { $titles[$step] } else { $step }
        Write-Host ''
        Write-Host "-- $title" -ForegroundColor Cyan
        foreach ($r in $group) {
            $line = '{0,-9} {1,-12} {2,-30} {3}' -f $r.Status, $r.Step, $r.Item, $r.Message
            Write-Host $line -ForegroundColor $colors[$r.Status]
        }
    }
    if ($script:LogFile) {
        Write-Host ''
        Write-Host "Log completo: $($script:LogFile)" -ForegroundColor DarkGray
    }
}

# 0 = tudo certo, 1 = alguma falha, 2 = itens pendentes de decisao
function Get-ExitCode {
    $statuses = @($script:Results | ForEach-Object { $_.Status })
    if ($statuses -contains 'FAILED') { return 1 }
    if ($statuses -contains 'PENDING') { return 2 }
    return 0
}

# Pasta de configuracao do Claude Code: CLAUDE_CONFIG_DIR ou %USERPROFILE%\.claude
function Get-ClaudeConfigDir {
    if ($env:CLAUDE_CONFIG_DIR) {
        return [System.IO.Path]::GetFullPath($env:CLAUDE_CONFIG_DIR)
    }
    $homeDir = $env:USERPROFILE
    if (-not $homeDir) { $homeDir = $HOME }
    return (Join-Path $homeDir '.claude')
}

# Pergunta com opcoes de uma letra. Retorna a letra escolhida (maiuscula) ou $Default.
function Read-Choice {
    param(
        [Parameter(Mandatory)] [string] $Prompt,
        [Parameter(Mandatory)] [string[]] $Options,
        [Parameter(Mandatory)] [string] $Default
    )
    for ($i = 0; $i -lt 5; $i++) {
        $answer = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
        $letter = $answer.Trim().Substring(0, 1).ToUpperInvariant()
        if ($Options -contains $letter) { return $letter }
        Write-Host "   Opcao invalida: $answer" -ForegroundColor Yellow
    }
    return $Default
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Content
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

Export-ModuleMember -Function Initialize-Installer, Test-DryRun, Get-LogFile, Write-Log, Write-LogFile,
    Add-Result, Get-Results, Write-Summary, Get-ExitCode, Get-ClaudeConfigDir, Read-Choice, Write-Utf8File
