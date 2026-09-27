# Prereqs.psm1 - verificacao de pre-requisitos (somente leitura, nao instala nada).

Set-StrictMode -Version 2.0
Import-Module (Join-Path $PSScriptRoot 'Common.psm1')

# Executa um programa e devolve saida + codigo de saida, sem deixar erro escapar.
function Invoke-External {
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [string[]] $Arguments = @()
    )
    # No Windows PowerShell 5.1, stderr de programa vira ErrorRecord; com 'Stop' isso abortaria.
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $FilePath @Arguments 2>&1 | ForEach-Object { "$_" }
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
    }
    catch {
        return [pscustomobject]@{ ExitCode = -1; Output = $_.Exception.Message }
    }
}

function Test-ClaudeCode {
    $cmd = Get-Command claude -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) {
        Write-Log 'Claude Code nao encontrado no PATH.' 'ERROR'
        Write-Log 'Instale em https://code.claude.com/docs e abra um novo terminal.' 'DETAIL'
        Add-Result 'Prereqs' 'Claude Code' 'FAILED' 'comando "claude" nao encontrado no PATH'
        return $null
    }
    $run = Invoke-External $cmd.Source @('--version')
    $version = ($run.Output -split "`n" | Select-Object -First 1).Trim()
    if ($run.ExitCode -ne 0 -or -not $version) {
        Write-Log "Claude Code encontrado em $($cmd.Source), mas 'claude --version' falhou: $($run.Output)" 'ERROR'
        Add-Result 'Prereqs' 'Claude Code' 'FAILED' "'claude --version' falhou"
        return $null
    }
    Write-Log "Claude Code: $version" 'OK'
    Add-Result 'Prereqs' 'Claude Code' 'OK' $version
    return [pscustomobject]@{ Path = $cmd.Source; Version = $version }
}

# Procura um Python 3 real. No Windows, o "python.exe" da Microsoft Store e um atalho
# que nao imprime versao; por isso a versao e sempre conferida.
function Find-Python {
    $candidates = @(
        @{ Name = 'python'; Args = @() },
        @{ Name = 'python3'; Args = @() },
        @{ Name = 'py'; Args = @('-3') }
    )
    foreach ($c in $candidates) {
        $cmd = Get-Command $c.Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmd) { continue }
        $run = Invoke-External $cmd.Source (@($c.Args) + @('--version'))
        if ($run.ExitCode -eq 0 -and $run.Output -match 'Python (3\.\d+(\.\d+)?)') {
            return [pscustomobject]@{ Path = $cmd.Source; PrefixArgs = [string[]]$c.Args; Version = $Matches[1] }
        }
    }
    return $null
}

function Test-Python {
    $py = Find-Python
    if ($py) {
        Write-Log "Python: $($py.Version) ($($py.Path))" 'OK'
        Add-Result 'Prereqs' 'Python 3' 'OK' $py.Version
        return $py
    }
    Write-Log 'Python 3 nao encontrado (python, python3 ou py -3).' 'WARN'
    Write-Log 'A skill ui-ux-pro-max sera instalada, mas o script de busca dela nao vai funcionar.' 'DETAIL'
    Write-Log 'Sugestao: winget install Python.Python.3.12' 'DETAIL'
    Add-Result 'Prereqs' 'Python 3' 'WARN' 'nao encontrado; ui-ux-pro-max sem script de busca'
    return $null
}

Export-ModuleMember -Function Invoke-External, Test-ClaudeCode, Find-Python, Test-Python
