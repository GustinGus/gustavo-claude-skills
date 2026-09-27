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

# ---------------------------------------------------------------- Node.js, npm/npx, Chrome

function Get-NodeInfo {
    $cmd = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { return $null }
    $run = Invoke-External $cmd.Source @('--version')
    if ($run.ExitCode -ne 0 -or $run.Output -notmatch 'v?(\d+\.\d+\.\d+)') { return $null }
    return [pscustomobject]@{ Path = $cmd.Source; Version = [version]$Matches[1] }
}

# Retorna o Node encontrado se atender a versao minima; caso contrario registra FAILED em $Step.
function Test-Node {
    param([Parameter(Mandatory)] [string] $MinVersion, [Parameter(Mandatory)] [string] $Step, [string] $Item = 'Node.js')
    $node = Get-NodeInfo
    if (-not $node) {
        Write-Log "Node.js nao encontrado (necessario >= $MinVersion)." 'ERROR'
        Write-Log 'Sugestao: winget install OpenJS.NodeJS.LTS  (depois abra um novo terminal)' 'DETAIL'
        Add-Result $Step $Item 'FAILED' "Node.js nao encontrado (necessario >= $MinVersion)"
        return $null
    }
    if ($node.Version -lt [version]$MinVersion) {
        Write-Log "Node.js $($node.Version) e antigo demais (necessario >= $MinVersion)." 'ERROR'
        Write-Log 'Sugestao: winget upgrade OpenJS.NodeJS.LTS' 'DETAIL'
        Add-Result $Step $Item 'FAILED' "versao $($node.Version) < $MinVersion"
        return $null
    }
    Write-Log "Node.js: $($node.Version)" 'OK'
    Add-Result $Step $Item 'OK' "$($node.Version)"
    return $node
}

# npm e npx vem com o Node. No Windows sao npm.cmd / npx.cmd (Application).
function Test-NpmNpx {
    param([Parameter(Mandatory)] [string] $Step)
    $ok = $true
    foreach ($tool in @('npm', 'npx')) {
        $cmd = Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $version = $null
        if ($cmd) {
            $run = Invoke-External $cmd.Source @('--version')
            if ($run.ExitCode -eq 0) { $version = ($run.Output -split "`n" | Select-Object -Last 1).Trim() }
        }
        if ($version) {
            Write-Log "${tool}: $version" 'OK'
            Add-Result $Step $tool 'OK' $version
        }
        else {
            Write-Log "$tool nao encontrado ou nao executa (vem junto com o Node.js)." 'ERROR'
            Add-Result $Step $tool 'FAILED' 'nao encontrado; reinstale o Node.js LTS'
            $ok = $false
        }
    }
    return $ok
}

function Find-Chrome {
    $isWin = ($PSVersionTable.PSEdition -eq 'Desktop') -or [bool](Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue)
    $isMac = [bool](Get-Variable -Name IsMacOS -ValueOnly -ErrorAction SilentlyContinue)
    $candidates = @()
    if ($isWin) {
        foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
            if ($base) { $candidates += (Join-Path $base 'Google\Chrome\Application\chrome.exe') }
        }
        foreach ($hive in @('HKLM:', 'HKCU:')) {
            $key = "$hive\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
            $item = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
            if ($item -and $item.PSObject.Properties['(default)']) { $candidates += $item.'(default)' }
        }
    }
    elseif ($isMac) {
        $candidates += '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
    }
    else {
        foreach ($name in @('google-chrome', 'google-chrome-stable')) {
            $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($cmd) { $candidates += $cmd.Source }
        }
    }
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) { return $c }
    }
    return $null
}

function Test-Chrome {
    param([Parameter(Mandatory)] [string] $Step)
    $chrome = Find-Chrome
    if ($chrome) {
        Write-Log "Google Chrome: $chrome" 'OK'
        Add-Result $Step 'Google Chrome' 'OK' $chrome
        return $chrome
    }
    Write-Log 'Google Chrome nao encontrado nos locais padrao.' 'WARN'
    Write-Log 'O MCP sera configurado, mas so funciona com o Chrome instalado: https://www.google.com/chrome/' 'DETAIL'
    Add-Result $Step 'Google Chrome' 'WARN' 'nao encontrado; o MCP nao conseguira abrir o navegador'
    return $null
}

Export-ModuleMember -Function Invoke-External, Test-ClaudeCode, Find-Python, Test-Python,
    Get-NodeInfo, Test-Node, Test-NpmNpx, Find-Chrome, Test-Chrome
