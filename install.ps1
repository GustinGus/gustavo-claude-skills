<#
.SYNOPSIS
    Instala as skills da biblioteca gustavo-claude-skills no Claude Code.

.DESCRIPTION
    Etapa 1 do instalador: somente as skills listadas em manifest.json.
    - Copia a pasta completa de cada skill (arquivos auxiliares e licencas incluidos).
    - Nunca substitui uma skill modificada ou de outra origem sem confirmacao.
    - Faz backup antes de substituir e pode ser executado quantas vezes quiser.

    Global:  %USERPROFILE%\.claude\skills  (ou $env:CLAUDE_CONFIG_DIR\skills)
    Projeto: <ProjectPath>\.claude\skills
    Estado, logs e backups: <pasta do Claude>\gustavo-claude-skills\

.PARAMETER Scope
    User (padrao) instala para todos os projetos; Project instala so em -ProjectPath.

.PARAMETER ProjectPath
    Pasta do projeto para -Scope Project. Padrao: diretorio atual.

.PARAMETER Force
    Substitui skills em conflito sem perguntar (sempre com backup).

.PARAMETER NonInteractive
    Nunca pergunta. Conflitos sao mantidos como estao e marcados como pendentes.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Scope Project -ProjectPath C:\dev\meu-site -WhatIf

.NOTES
    Codigos de saida: 0 = sucesso, 1 = falha, 2 = itens pendentes de decisao.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('User', 'Project')]
    [string] $Scope = 'User',
    [string] $ProjectPath = (Get-Location).Path,
    [switch] $Force,
    [switch] $NonInteractive
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$LibDir = Join-Path (Join-Path $RepoRoot 'scripts') 'lib'
Import-Module (Join-Path $LibDir 'Common.psm1') -Force
Import-Module (Join-Path $LibDir 'Prereqs.psm1') -Force
Import-Module (Join-Path $LibDir 'Skills.psm1') -Force

$dryRun = [bool]$WhatIfPreference

try {
    # ------------------------------------------------------------ destinos
    $configDir = Get-ClaudeConfigDir
    $stateRoot = Join-Path $configDir 'gustavo-claude-skills'
    $userSkillsDir = Join-Path $configDir 'skills'

    if ($Scope -eq 'Project') {
        if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
            throw "ProjectPath nao existe ou nao e uma pasta: $ProjectPath"
        }
        $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).ProviderPath
        if (Test-SamePath $ProjectPath $RepoRoot) {
            throw 'Recusado: -ProjectPath aponta para a propria biblioteca gustavo-claude-skills. Escolha o projeto onde as skills devem ser usadas.'
        }
        $skillsDir = Join-Path (Join-Path $ProjectPath '.claude') 'skills'
        $otherSkillsDir = $userSkillsDir
    }
    else {
        $skillsDir = $userSkillsDir
        $cwd = (Get-Location).Path
        $otherSkillsDir = $null
        if (-not (Test-SamePath $cwd $RepoRoot)) {
            $otherSkillsDir = Join-Path (Join-Path $cwd '.claude') 'skills'
        }
    }

    Initialize-Installer -StateRoot $stateRoot -DryRun:$dryRun

    Write-Host ''
    Write-Log 'gustavo-claude-skills - instalador (etapa 1: skills)' 'STEP'
    if ($dryRun) { Write-Log 'Modo -WhatIf: nada sera alterado.' 'WARN' }
    $configSource = if ($env:CLAUDE_CONFIG_DIR) { 'CLAUDE_CONFIG_DIR' } else { 'padrao' }
    Write-Log "Pasta do Claude Code: $configDir ($configSource)" 'INFO'
    Write-Log "Escopo: $Scope -> $skillsDir" 'INFO'

    # ------------------------------------------------------------ manifesto
    $manifestPath = Join-Path $RepoRoot 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) { throw "manifest.json nao encontrado em $RepoRoot" }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $skills = @($manifest.skills)
    if ($skills.Count -eq 0) { throw 'manifest.json nao lista nenhuma skill.' }

    # ------------------------------------------------------------ pre-requisitos
    Write-Host ''
    Write-Log 'Pre-requisitos' 'STEP'
    $claude = Test-ClaudeCode
    $needsPython = @($skills | Where-Object { @(Get-Prop $_ 'requires' @()) -contains 'python' }).Count -gt 0
    $python = $null
    if ($needsPython) { $python = Test-Python }

    if (-not $claude) {
        Write-Log 'Instalacao interrompida: o Claude Code e necessario.' 'ERROR'
    }
    else {
        # -------------------------------------------------------- skills
        Write-Host ''
        Write-Log "Skills ($($skills.Count))" 'STEP'
        Install-Skills -Skills $skills -RepoRoot $RepoRoot -SkillsDir $skillsDir -StateRoot $stateRoot `
            -Force:$Force -NonInteractive:$NonInteractive

        # -------------------------------------------------------- verificacao
        Write-Host ''
        Write-Log 'Verificacao' 'STEP'
        if ($dryRun) {
            Write-Log 'Verificacao dos arquivos pulada no modo -WhatIf.' 'INFO'
        }
        else {
            Test-InstalledSkills -Skills $skills -RepoRoot $RepoRoot -SkillsDir $skillsDir `
                -OtherSkillsDir $otherSkillsDir -Python $python
        }
    }
}
catch {
    Write-Log $_.Exception.Message 'ERROR'
    Write-LogFile ($_ | Out-String)
    Add-Result 'Instalador' 'geral' 'FAILED' $_.Exception.Message
}

Write-Summary
$code = Get-ExitCode
switch ($code) {
    0 { Write-Host 'Concluido.' -ForegroundColor Green }
    1 { Write-Host 'Concluido com falhas. Veja o resumo acima.' -ForegroundColor Red }
    2 { Write-Host 'Concluido com itens pendentes de decisao.' -ForegroundColor Yellow }
}
exit $code
