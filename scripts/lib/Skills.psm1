# Skills.psm1 - instalacao idempotente das skills da biblioteca no Claude Code.
#
# Regras:
#  - copia a pasta inteira da skill (SKILL.md, references, scripts, data, licencas);
#  - nunca substitui uma skill modificada ou que nao foi instalada por nos sem confirmacao;
#  - sempre copia para uma pasta temporaria, confere o hash e so entao troca;
#  - guarda a versao anterior em backups/ antes de substituir;
#  - registra o hash de cada instalacao em state.json.

Set-StrictMode -Version 2.0
Import-Module (Join-Path $PSScriptRoot 'Common.psm1')
Import-Module (Join-Path $PSScriptRoot 'Prereqs.psm1')

# Arquivos gerados em uso (ex.: cache do Python ao rodar search.py) nao contam como alteracao.
$script:IgnoredDirNames = @('__pycache__')
$script:IgnoredFileNames = @('.DS_Store', 'Thumbs.db', 'desktop.ini')
$script:IgnoredExtensions = @('.pyc')

$script:IsWin = ($PSVersionTable.PSEdition -eq 'Desktop') -or
    [bool](Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue)

function Get-Prop {
    param($Object, [string] $Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $Default
}

function Test-SamePath {
    param([string] $A, [string] $B)
    $a2 = $A.TrimEnd('\', '/')
    $b2 = $B.TrimEnd('\', '/')
    if ($script:IsWin) { return [string]::Equals($a2, $b2, [System.StringComparison]::OrdinalIgnoreCase) }
    return [string]::Equals($a2, $b2, [System.StringComparison]::Ordinal)
}

# ---------------------------------------------------------------- arquivos e hashes

function Get-SkillFiles {
    param([Parameter(Mandatory)] [string] $Root)
    $rootFull = (Resolve-Path -LiteralPath $Root).ProviderPath.TrimEnd('\', '/')
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($f in (Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force)) {
        $rel = $f.FullName.Substring($rootFull.Length + 1).Replace('\', '/')
        $segments = $rel.Split('/')
        $skip = $false
        for ($i = 0; $i -lt $segments.Length - 1; $i++) {
            if ($script:IgnoredDirNames -contains $segments[$i]) { $skip = $true }
        }
        if ($script:IgnoredFileNames -contains $f.Name) { $skip = $true }
        if ($script:IgnoredExtensions -contains $f.Extension.ToLowerInvariant()) { $skip = $true }
        if (-not $skip) { $result.Add([pscustomobject]@{ Rel = $rel; Full = $f.FullName }) }
    }
    return , $result.ToArray()
}

function Get-StringSha256 {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
        return ([System.BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}

# Hash da arvore: caminho relativo + hash de cada arquivo, em ordem ordinal.
function Get-TreeHash {
    param([Parameter(Mandatory)] [string] $Root)
    $files = Get-SkillFiles $Root
    $map = @{}
    foreach ($f in $files) {
        $map[$f.Rel] = (Get-FileHash -LiteralPath $f.Full -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $keys = [string[]]@($map.Keys)
    [System.Array]::Sort($keys, [System.StringComparer]::Ordinal)
    $lines = foreach ($k in $keys) { "$k`t$($map[$k])" }
    return [pscustomobject]@{
        Hash      = Get-StringSha256 (($lines) -join "`n")
        Files     = $map
        FileCount = $keys.Length
    }
}

function Compare-Trees {
    param([hashtable] $Installed, [hashtable] $Source)
    $added = @($Source.Keys | Where-Object { -not $Installed.ContainsKey($_) } | Sort-Object)
    $removed = @($Installed.Keys | Where-Object { -not $Source.ContainsKey($_) } | Sort-Object)
    $changed = @($Source.Keys | Where-Object { $Installed.ContainsKey($_) -and $Installed[$_] -ne $Source[$_] } | Sort-Object)
    return [pscustomobject]@{ Added = $added; Removed = $removed; Changed = $changed }
}

function Copy-SkillTree {
    param([Parameter(Mandatory)] [string] $Source, [Parameter(Mandatory)] [string] $Destination)
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($f in (Get-SkillFiles $Source)) {
        $target = Join-Path $Destination ($f.Rel.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -LiteralPath $f.Full -Destination $target -Force
    }
}

# ---------------------------------------------------------------- state.json

function Read-State {
    param([Parameter(Mandatory)] [string] $Path)
    $installs = New-Object System.Collections.Generic.List[object]
    if (Test-Path -LiteralPath $Path) {
        try {
            $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
            $data = $raw | ConvertFrom-Json
            foreach ($i in @(Get-Prop $data 'installs' @())) { $installs.Add($i) }
        }
        catch {
            throw "state.json invalido em '$Path': $($_.Exception.Message). Corrija ou apague o arquivo e rode de novo."
        }
    }
    return [pscustomobject]@{ Path = $Path; Installs = $installs }
}

function Save-State {
    param([Parameter(Mandatory)] $State)
    # [ordered] + array gera "Argument types do not match" no ConvertTo-Json; por isso pscustomobject.
    $data = [pscustomobject]@{ version = 1; installs = $State.Installs.ToArray() }
    Write-Utf8File -Path $State.Path -Content ($data | ConvertTo-Json -Depth 5)
}

function Get-StateRecord {
    param($State, [string] $Target, [string] $Skill)
    foreach ($i in $State.Installs) {
        if ($i.skill -eq $Skill -and (Test-SamePath $i.target $Target)) { return $i }
    }
    return $null
}

function Set-StateRecord {
    param($State, [string] $Target, [string] $Skill, [string] $Hash, [string] $SourceCommit)
    $existing = Get-StateRecord $State $Target $Skill
    if ($existing) { [void]$State.Installs.Remove($existing) }
    $State.Installs.Add([pscustomobject][ordered]@{
            target       = $Target
            skill        = $Skill
            hash         = $Hash
            sourceCommit = $SourceCommit
            installedAt  = (Get-Date).ToString('o')
        })
}

# ---------------------------------------------------------------- instalacao

function Get-SourceCommit {
    param([string] $RepoRoot)
    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $git) { return $null }
    $run = Invoke-External $git.Source @('-C', $RepoRoot, 'rev-parse', '--short', 'HEAD')
    if ($run.ExitCode -eq 0) { return $run.Output.Trim() }
    return $null
}

# Troca a pasta de destino pela copia temporaria ja verificada, guardando a anterior em backup.
function Set-SkillFolder {
    param(
        [string] $Name, [string] $SourceDir, [string] $SourceHash,
        [string] $SkillsDir, [string] $BackupDir
    )
    $dest = Join-Path $SkillsDir $Name
    $tmp = Join-Path $SkillsDir ".$Name.tmp-$PID"
    $old = Join-Path $SkillsDir ".$Name.old-$PID"

    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    Copy-SkillTree -Source $SourceDir -Destination $tmp
    $copied = Get-TreeHash $tmp
    if ($copied.Hash -ne $SourceHash) {
        Remove-Item -LiteralPath $tmp -Recurse -Force
        throw "a copia temporaria de '$Name' nao confere com a fonte (hash diferente)"
    }

    $hadOld = Test-Path -LiteralPath $dest
    if ($hadOld) {
        try { Move-Item -LiteralPath $dest -Destination $old }
        catch {
            Remove-Item -LiteralPath $tmp -Recurse -Force
            throw "nao foi possivel mover a versao atual de '$Name' (arquivo em uso? feche o Claude Code e tente de novo): $($_.Exception.Message)"
        }
    }
    try {
        Move-Item -LiteralPath $tmp -Destination $dest
    }
    catch {
        if ($hadOld -and -not (Test-Path -LiteralPath $dest)) { Move-Item -LiteralPath $old -Destination $dest }
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        throw
    }

    if (-not $hadOld) { return $null }
    $backup = Join-Path $BackupDir $Name
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    try {
        Move-Item -LiteralPath $old -Destination $backup
    }
    catch {
        # Destino em outro volume (instalacao por projeto): copia e depois apaga.
        Copy-Item -LiteralPath $old -Destination $backup -Recurse -Force
        Remove-Item -LiteralPath $old -Recurse -Force
    }
    return $backup
}

function Show-TreeDiff {
    param($Diff)
    $sections = @(
        @{ Title = 'So na versao da biblioteca (seriam adicionados)'; Items = $Diff.Added },
        @{ Title = 'So na versao instalada (seriam removidos, ficam no backup)'; Items = $Diff.Removed },
        @{ Title = 'Conteudo diferente'; Items = $Diff.Changed }
    )
    foreach ($s in $sections) {
        if (@($s.Items).Count -eq 0) { continue }
        Write-Log "$($s.Title):" 'DETAIL'
        foreach ($i in (@($s.Items) | Select-Object -First 20)) { Write-Log "  $i" 'DETAIL' }
        if (@($s.Items).Count -gt 20) { Write-Log "  ... e mais $(@($s.Items).Count - 20)" 'DETAIL' }
    }
}

function Install-OneSkill {
    param(
        [Parameter(Mandatory)] $Skill,
        [Parameter(Mandatory)] [string] $RepoRoot,
        [Parameter(Mandatory)] [string] $SkillsDir,
        [Parameter(Mandatory)] $State,
        [Parameter(Mandatory)] [string] $BackupDir,
        [string] $SourceCommit,
        [switch] $Force,
        [switch] $NonInteractive
    )
    $name = $Skill.name
    $sourceDir = Join-Path $RepoRoot ($Skill.path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
    $dest = Join-Path $SkillsDir $name
    $dry = Test-DryRun

    if (-not (Test-Path -LiteralPath (Join-Path $sourceDir 'SKILL.md'))) {
        Write-Log "${name}: SKILL.md nao encontrado na biblioteca ($sourceDir)." 'ERROR'
        Add-Result 'Skills' $name 'FAILED' 'SKILL.md ausente na biblioteca'
        return
    }
    $src = Get-TreeHash $sourceDir
    $record = Get-StateRecord $State $SkillsDir $name

    # 1. Nao existe no destino: instalar.
    if (-not (Test-Path -LiteralPath $dest)) {
        if ($dry) {
            Write-Log "${name}: seria instalada ($($src.FileCount) arquivos)." 'INFO'
            Add-Result 'Skills' $name 'WHATIF' 'seria instalada'
            return
        }
        [void](Set-SkillFolder $name $sourceDir $src.Hash $SkillsDir $BackupDir)
        Set-StateRecord $State $SkillsDir $name $src.Hash $SourceCommit
        Write-Log "${name}: instalada ($($src.FileCount) arquivos)." 'OK'
        Add-Result 'Skills' $name 'OK' "instalada ($($src.FileCount) arquivos)"
        return
    }

    $isDir = Test-Path -LiteralPath $dest -PathType Container
    $installed = $null
    if ($isDir) { $installed = Get-TreeHash $dest }

    # 2. Ja existe e e identica: nada a fazer.
    if ($installed -and $installed.Hash -eq $src.Hash) {
        if (-not $dry -and (-not $record -or $record.hash -ne $src.Hash)) {
            Set-StateRecord $State $SkillsDir $name $src.Hash $SourceCommit
        }
        Write-Log "${name}: ja instalada e identica." 'OK'
        Add-Result 'Skills' $name 'SKIPPED' 'ja instalada e identica'
        return
    }

    # 3. Instalada por nos e sem alteracao local: atualizar para a versao nova da biblioteca.
    $ours = $installed -and $record -and $record.hash -eq $installed.Hash
    $reason = $null
    if ($ours) {
        $action = 'update'
    }
    else {
        # 4. Conflito: pasta nao instalada por nos, ou modificada depois da instalacao.
        if (-not $isDir) { $reason = 'existe um arquivo (nao uma pasta) com esse nome' }
        elseif ($record) { $reason = 'foi modificada depois da instalacao' }
        else { $reason = 'ja existe e nao foi instalada por este instalador' }

        Write-Log "${name}: $reason." 'WARN'
        if ($installed) { Show-TreeDiff (Compare-Trees $installed.Files $src.Files) }

        if ($Force) {
            $action = 'replace'
        }
        elseif ($NonInteractive -or $dry) {
            $action = 'skip'
        }
        else {
            $action = $null
            while (-not $action) {
                $choice = Read-Choice -Prompt "   ${name}: [S]ubstituir (com backup), [P]ular ou [D]iferencas? (padrao: P)" -Options @('S', 'P', 'D') -Default 'P'
                switch ($choice) {
                    'S' { $action = 'replace' }
                    'P' { $action = 'skip' }
                    'D' {
                        if ($installed) { Show-TreeDiff (Compare-Trees $installed.Files $src.Files) }
                        else { Write-Log 'O destino e um arquivo; nao ha diferencas de pasta para mostrar.' 'DETAIL' }
                    }
                }
            }
        }
    }

    if ($action -eq 'skip') {
        $hint = 'rode sem -NonInteractive para decidir, ou com -Force para substituir (com backup)'
        if ($dry) { $hint = 'na execucao real sera perguntado (ou use -Force)' }
        Write-Log "${name}: mantida como esta ($hint)." 'WARN'
        Add-Result 'Skills' $name 'PENDING' "$reason; mantida"
        return
    }

    if ($dry) {
        $verb = if ($action -eq 'update') { 'atualizada' } else { 'substituida (com backup)' }
        Write-Log "${name}: seria $verb." 'INFO'
        Add-Result 'Skills' $name 'WHATIF' "seria $verb"
        return
    }

    $backup = Set-SkillFolder $name $sourceDir $src.Hash $SkillsDir $BackupDir
    Set-StateRecord $State $SkillsDir $name $src.Hash $SourceCommit
    $verb = if ($action -eq 'update') { 'atualizada' } else { 'substituida' }
    Write-Log "${name}: $verb. Versao anterior em: $backup" 'OK'
    Add-Result 'Skills' $name 'UPDATED' "$verb; backup em $backup"
}

function Install-Skills {
    param(
        [Parameter(Mandatory)] [object[]] $Skills,
        [Parameter(Mandatory)] [string] $RepoRoot,
        [Parameter(Mandatory)] [string] $SkillsDir,
        [Parameter(Mandatory)] [string] $StateRoot,
        [switch] $Force,
        [switch] $NonInteractive
    )
    $dry = Test-DryRun
    $statePath = Join-Path $StateRoot 'state.json'
    $state = Read-State $statePath
    $backupDir = Join-Path (Join-Path $StateRoot 'backups') (Get-Date -Format 'yyyyMMdd-HHmmss')
    $commit = Get-SourceCommit $RepoRoot

    if (-not (Test-Path -LiteralPath $SkillsDir)) {
        if ($dry) { Write-Log "A pasta $SkillsDir seria criada." 'INFO' }
        else { New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null }
    }
    elseif (-not $dry) {
        # Restos de uma execucao interrompida.
        Get-ChildItem -LiteralPath $SkillsDir -Directory -Force -Filter '.*.tmp-*' -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
        foreach ($leftover in @(Get-ChildItem -LiteralPath $SkillsDir -Directory -Force -Filter '.*.old-*' -ErrorAction SilentlyContinue)) {
            Write-Log "Pasta antiga deixada por uma execucao interrompida: $($leftover.FullName) (confira e apague manualmente)." 'WARN'
        }
    }

    foreach ($skill in $Skills) {
        try {
            Install-OneSkill -Skill $skill -RepoRoot $RepoRoot -SkillsDir $SkillsDir -State $state `
                -BackupDir $backupDir -SourceCommit $commit -Force:$Force -NonInteractive:$NonInteractive
        }
        catch {
            Write-Log "$($skill.name): falhou - $($_.Exception.Message)" 'ERROR'
            Write-LogFile ($_ | Out-String)
            Add-Result 'Skills' $skill.name 'FAILED' $_.Exception.Message
        }
    }

    if (-not $dry) {
        try { Save-State $state }
        catch {
            Write-Log "Nao foi possivel gravar $statePath - $($_.Exception.Message)" 'ERROR'
            Add-Result 'Skills' 'state.json' 'FAILED' $_.Exception.Message
        }
    }
}

# ---------------------------------------------------------------- verificacao

function Get-FrontmatterName {
    param([string] $SkillMd)
    $lines = @(Get-Content -LiteralPath $SkillMd -TotalCount 40 -Encoding UTF8)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { break }
        if ($lines[$i] -match '^name:\s*(.+?)\s*$') { return $Matches[1].Trim('"', "'") }
    }
    return $null
}

function Invoke-SmokeTest {
    param($Skill, [string] $InstalledDir, $Python)
    $test = Get-Prop $Skill 'smokeTest'
    if (-not $test) { return }
    $name = $Skill.name
    if ((Get-Prop $test 'type') -ne 'python') { return }
    if (-not $Python) {
        Add-Result 'Verificacao' "$name (script)" 'WARN' 'Python 3 nao encontrado; script nao testado'
        return
    }
    $script = Join-Path $InstalledDir ($test.script.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Log "${name}: script nao encontrado no caminho instalado: $script" 'ERROR'
        Add-Result 'Verificacao' "$name (script)" 'FAILED' "script ausente: $script"
        return
    }
    # -B: nao gravar __pycache__ na pasta instalada durante o teste.
    $arguments = @($Python.PrefixArgs) + @('-B', $script) + @($test.args)
    $oldEnc = $env:PYTHONIOENCODING
    $env:PYTHONIOENCODING = 'utf-8'
    try { $run = Invoke-External $Python.Path $arguments }
    finally { $env:PYTHONIOENCODING = $oldEnc }
    Write-LogFile "Smoke test $name -> $($Python.Path) $($arguments -join ' ') (exit $($run.ExitCode))"
    Write-LogFile $run.Output
    $expect = Get-Prop $test 'expectOutput'
    if ($run.ExitCode -ne 0 -or ($expect -and $run.Output -notlike "*$expect*")) {
        Write-Log "${name}: o script instalado falhou (exit $($run.ExitCode))." 'ERROR'
        Write-Log (($run.Output -split "`n" | Select-Object -Last 5) -join ' | ') 'DETAIL'
        Add-Result 'Verificacao' "$name (script)" 'FAILED' "exit $($run.ExitCode); detalhes no log"
        return
    }
    Write-Log "${name}: script de busca executado com sucesso pelo caminho instalado." 'OK'
    Add-Result 'Verificacao' "$name (script)" 'OK' $script
}

function Test-InstalledSkills {
    param(
        [Parameter(Mandatory)] [object[]] $Skills,
        [Parameter(Mandatory)] [string] $RepoRoot,
        [Parameter(Mandatory)] [string] $SkillsDir,
        [string] $OtherSkillsDir,
        $Python
    )
    $pending = @((Get-Results) | Where-Object { $_.Step -eq 'Skills' -and $_.Status -eq 'PENDING' } | ForEach-Object { $_.Item })
    foreach ($skill in $Skills) {
        $name = $skill.name
        $dir = Join-Path $SkillsDir $name
        $md = Join-Path $dir 'SKILL.md'
        if (-not (Test-Path -LiteralPath $md)) {
            Write-Log "${name}: SKILL.md nao encontrado em $dir" 'ERROR'
            Add-Result 'Verificacao' $name 'FAILED' 'SKILL.md ausente no destino'
            continue
        }
        $problems = New-Object System.Collections.Generic.List[string]
        $fmName = Get-FrontmatterName $md
        if ($fmName -ne $name) { $problems.Add("frontmatter name='$fmName'") }

        $sourceDir = Join-Path $RepoRoot ($skill.path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        $srcTree = Get-TreeHash $sourceDir
        $dstTree = Get-TreeHash $dir
        foreach ($lic in @($srcTree.Files.Keys | Where-Object { $_ -notmatch '/' -and $_ -match '^(?i)licen[cs]e' })) {
            if (-not $dstTree.Files.ContainsKey($lic)) { $problems.Add("licenca ausente: $lic") }
        }

        if ($pending -contains $name) {
            if ($dstTree.Hash -ne $srcTree.Hash) {
                Add-Result 'Verificacao' $name 'PENDING' 'versao diferente da biblioteca mantida por escolha'
            }
            continue
        }
        if ($dstTree.Hash -ne $srcTree.Hash) {
            $diff = Compare-Trees $dstTree.Files $srcTree.Files
            $problems.Add("conteudo difere da biblioteca (+$($diff.Added.Count) -$($diff.Removed.Count) ~$($diff.Changed.Count))")
        }
        if ($problems.Count -gt 0) {
            Write-Log "${name}: $($problems -join '; ')" 'ERROR'
            Add-Result 'Verificacao' $name 'FAILED' ($problems -join '; ')
        }
        else {
            Add-Result 'Verificacao' $name 'OK' "SKILL.md + $($dstTree.FileCount) arquivos identicos"
        }

        if ($OtherSkillsDir -and (Test-Path -LiteralPath (Join-Path $OtherSkillsDir $name))) {
            Write-Log "${name}: tambem existe em $OtherSkillsDir; o Claude Code vera as duas." 'WARN'
            Add-Result 'Verificacao' "$name (duplicada)" 'WARN' "tambem existe em $OtherSkillsDir"
        }
    }

    foreach ($skill in $Skills) {
        $dir = Join-Path $SkillsDir $skill.name
        if (Test-Path -LiteralPath (Join-Path $dir 'SKILL.md')) {
            Invoke-SmokeTest -Skill $skill -InstalledDir $dir -Python $Python
        }
    }
}

Export-ModuleMember -Function Get-TreeHash, Install-Skills, Test-InstalledSkills, Test-SamePath, Get-Prop
