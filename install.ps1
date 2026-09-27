<#
.SYNOPSIS
    Instala as skills da biblioteca gustavo-claude-skills no Claude Code.

.DESCRIPTION
    Instala o que esta em manifest.json:
    - Etapa 1: as skills da biblioteca. Copia a pasta completa de cada uma (arquivos
      auxiliares e licencas incluidos), nunca substitui uma skill modificada ou de outra
      origem sem confirmacao e faz backup antes de substituir.
    - Etapa 2: o Chrome DevTools MCP no escopo user, via "claude mcp add", com as flags
      --isolated --no-usage-statistics --no-performance-crux (no Windows, via "cmd /c npx").
    - Etapa 3 (opcional, -WithImpeccable): o Impeccable pelo instalador oficial
      (npx impeccable install, escopo global, sem hooks), sempre com confirmacao.
    - Etapa 4 (opcional, -WithShadcn, so com -Scope Project): o MCP oficial do shadcn no
      .mcp.json do projeto (npx shadcn@latest mcp init --client claude), somente se o projeto
      ja tiver components.json. Preserva os outros servidores e restaura tudo se falhar.
    Pode ser executado quantas vezes quiser.

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

.PARAMETER SkipMcp
    Nao configura servidores MCP (so as skills).

.PARAMETER WithImpeccable
    Instala o Impeccable (dependencia externa opcional) pelo instalador oficial.
    Mostra o comando e pede confirmacao; com -NonInteractive so executa se -Force tambem for usado.

.PARAMETER WithShadcn
    Configura o MCP oficial do shadcn no projeto (exige -Scope Project e components.json).
    Nunca configura globalmente e nunca inicializa o shadcn em um projeto que nao o usa.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -WithImpeccable

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Scope Project -ProjectPath "C:\meu-site" -WithShadcn

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
    [switch] $NonInteractive,
    [switch] $SkipMcp,
    [switch] $WithImpeccable,
    [switch] $WithShadcn
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$LibDir = Join-Path (Join-Path $RepoRoot 'scripts') 'lib'
Import-Module (Join-Path $LibDir 'Common.psm1') -Force
Import-Module (Join-Path $LibDir 'Prereqs.psm1') -Force
Import-Module (Join-Path $LibDir 'Skills.psm1') -Force
Import-Module (Join-Path $LibDir 'Mcp.psm1') -Force
Import-Module (Join-Path $LibDir 'External.psm1') -Force
Import-Module (Join-Path $LibDir 'ProjectIntegrations.psm1') -Force

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
    Write-Log 'gustavo-claude-skills - instalador (skills + MCP + externas + projeto)' 'STEP'
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
    $mcpServers = @(Get-Prop $manifest 'mcp' @())
    $externals = @(Get-Prop $manifest 'external' @())
    $projectIntegrations = @(Get-Prop $manifest 'projectIntegrations' @())

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

        # -------------------------------------------------------- MCP
        # Qualquer falha aqui fica restrita ao MCP: as skills ja foram instaladas acima.
        Write-Host ''
        Write-Log "MCP ($($mcpServers.Count))" 'STEP'
        if ($SkipMcp) {
            foreach ($m in $mcpServers) {
                Write-Log "$($m.name): pulado (-SkipMcp)." 'INFO'
                Add-Result 'MCP' $m.name 'SKIPPED' 'pulado (-SkipMcp)'
            }
        }
        elseif ($mcpServers.Count -gt 0) {
            try {
                Install-McpServers -Servers $mcpServers -ClaudePath $claude.Path -StateRoot $stateRoot `
                    -Force:$Force -NonInteractive:$NonInteractive
            }
            catch {
                Write-Log "MCP: falha inesperada - $($_.Exception.Message)" 'ERROR'
                Write-LogFile ($_ | Out-String)
                Add-Result 'MCP' 'geral' 'FAILED' $_.Exception.Message
            }
        }

        # -------------------------------------------------------- dependencias externas
        # Opcionais e isoladas: uma falha aqui nao desfaz nem altera skills ou MCP.
        if ($externals.Count -gt 0) {
            Write-Host ''
            Write-Log "Depend$([char]0x00EA)ncias externas ($($externals.Count))" 'STEP'
            $enabled = @()
            if ($WithImpeccable) { $enabled += 'impeccable' }
            try {
                Install-ExternalDependencies -Dependencies $externals -Enabled $enabled `
                    -Force:$Force -NonInteractive:$NonInteractive
            }
            catch {
                Write-Log "Dependencias externas: falha inesperada - $($_.Exception.Message)" 'ERROR'
                Write-LogFile ($_ | Out-String)
                Add-Result 'Externas' 'geral' 'FAILED' $_.Exception.Message
            }
        }

        # -------------------------------------------------------- integracoes por projeto
        # Independentes do Impeccable e do Chrome DevTools MCP; so tocam arquivos do projeto.
        if ($projectIntegrations.Count -gt 0) {
            Write-Host ''
            Write-Log "Integra$([char]0x00E7)$([char]0x00F5)es por projeto ($($projectIntegrations.Count))" 'STEP'
            $enabledProject = @()
            if ($WithShadcn) { $enabledProject += 'shadcn-mcp' }
            try {
                Install-ProjectIntegrations -Integrations $projectIntegrations -Enabled $enabledProject `
                    -Scope $Scope -ProjectPath $ProjectPath -StateRoot $stateRoot -Force:$Force -NonInteractive:$NonInteractive
            }
            catch {
                Write-Log "Integracoes por projeto: falha inesperada - $($_.Exception.Message)" 'ERROR'
                Write-LogFile ($_ | Out-String)
                Add-Result 'Projeto' 'geral' 'FAILED' $_.Exception.Message
            }
        }

        # -------------------------------------------------------- verificacao
        Write-Host ''
        Write-Log 'Verificacao' 'STEP'
        if ($dryRun) {
            Write-Log 'Verificacao pulada no modo -WhatIf.' 'INFO'
        }
        else {
            Test-InstalledSkills -Skills $skills -RepoRoot $RepoRoot -SkillsDir $skillsDir `
                -OtherSkillsDir $otherSkillsDir -Python $python
            if (-not $SkipMcp -and $mcpServers.Count -gt 0) {
                try { Test-McpServers -Servers $mcpServers }
                catch {
                    Write-Log "Verificacao do MCP falhou - $($_.Exception.Message)" 'ERROR'
                    Add-Result 'MCP' 'verificacao' 'FAILED' $_.Exception.Message
                }
            }
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
