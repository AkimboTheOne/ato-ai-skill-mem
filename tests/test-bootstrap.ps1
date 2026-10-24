$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ato-ai-skill-mem-" + [guid]::NewGuid())
$project = Join-Path $temporaryRoot 'consumer'
$legacy = Join-Path $temporaryRoot 'legacy'
$conflict = Join-Path $temporaryRoot 'conflict'

try {
    New-Item -ItemType Directory -Path $project | Out-Null
    $agentsPath = Join-Path $project 'AGENTS.md'
    Set-Content -LiteralPath $agentsPath -Value 'before'
    $agentsBefore = [System.IO.File]::ReadAllText($agentsPath)
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project

    $skillLink = Get-Item -LiteralPath (Join-Path $project 'mem/SKILL.md') -Force
    if ($skillLink.LinkType -ne 'SymbolicLink') {
        throw 'SKILL.md no se instaló como enlace simbólico'
    }
    foreach ($linkedItem in @('VERSION', 'WORKSPACE_FORMAT', 'references', 'templates', 'scripts')) {
        if ((Get-Item -LiteralPath (Join-Path $project "mem/$linkedItem") -Force).LinkType -ne 'SymbolicLink') {
            throw "$linkedItem no se instaló como enlace simbólico"
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $project 'mem/workspace/INDEX.md'))) {
        throw 'falta el índice del workspace'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $project 'mem/workspace/.ato-ai-skill-mem-version.yml'))) {
        throw 'falta el manifiesto de versión del workspace'
    }
    if ((Get-Content -LiteralPath (Join-Path $project 'mem/workspace/.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^workspace_format: 1$') {
        throw 'falta el formato del workspace en el manifiesto'
    }
    if ((Get-Content -LiteralPath (Join-Path $project 'mem/workspace/.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^workspace_kind: consumer$') {
        throw 'falta el tipo de workspace de consumidor en el manifiesto'
    }
    $unconfiguredIntegration = & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -Status
    if ($unconfiguredIntegration -notcontains 'integration.codex.state: not-configured') {
        throw 'la integración de Codex no informó estado no configurado'
    }
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -IntegrateCodex
    if ((Get-Content -LiteralPath (Join-Path $project '.ato-ai-skill-mem.yml') -Raw) -ne (Get-Content -LiteralPath (Join-Path $root 'templates/integrations/host-config.yml') -Raw)) {
        throw 'la configuración de integración no coincide con el contrato'
    }
    $adapterSkill = Join-Path $project '.agents/skills/ato-ai-project-mem/SKILL.md'
    if (-not (Test-Path -LiteralPath $adapterSkill -PathType Leaf) -or (Get-Item -LiteralPath $adapterSkill -Force).LinkType -eq 'SymbolicLink') {
        throw 'el adaptador de Codex no es un archivo local regular'
    }
    if ((Get-Content -LiteralPath $adapterSkill -Raw) -ne (Get-Content -LiteralPath (Join-Path $root 'templates/integrations/codex/SKILL.md') -Raw)) {
        throw 'el adaptador de Codex no coincide con la plantilla'
    }
    $configuredIntegration = & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -Status
    if ($configuredIntegration -notcontains 'integration.codex.state: aligned') {
        throw 'la integración de Codex no informó alineación'
    }
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -IntegrateCodex
    if ([System.IO.File]::ReadAllText($agentsPath) -ne $agentsBefore) {
        throw 'la integración de Codex modificó AGENTS.md'
    }
    $integrationConflict = Join-Path $temporaryRoot 'integration-conflict'
    New-Item -ItemType Directory -Path $integrationConflict | Out-Null
    Set-Content -LiteralPath (Join-Path $integrationConflict '.ato-ai-skill-mem.yml') -Value 'format: 9'
    $integrationRejected = $false
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $integrationConflict -IntegrateCodex
    }
    catch {
        $integrationRejected = $true
    }
    if (-not $integrationRejected) {
        throw 'bootstrap aceptó una configuración de integración incompatible'
    }
    if ((Test-Path -LiteralPath (Join-Path $integrationConflict 'mem/SKILL.md')) -or (Test-Path -LiteralPath (Join-Path $integrationConflict '.agents'))) {
        throw 'bootstrap creó archivos antes de rechazar la configuración de integración'
    }
    $sourceStatus = & (Join-Path $root 'scripts/bootstrap.ps1') -SourceStatus
    if ($sourceStatus -notcontains 'workspace.kind: source' -or $sourceStatus -notcontains 'workspace.expected_kind: source') {
        throw 'el workspace fuente no informó su tipo'
    }
    $sourceTargetRejected = $false
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $root -Status
    }
    catch {
        $sourceTargetRejected = $true
    }
    if (-not $sourceTargetRejected) {
        throw 'bootstrap aceptó la raíz fuente como consumidor'
    }
    $sourceUpdateRejected = $false
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -UpdateSourceWorkspace
    }
    catch {
        $sourceUpdateRejected = $true
    }
    if (-not $sourceUpdateRejected) {
        throw 'la actualización de fuente aceptó un checkout no apto'
    }
    $status = & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -Status
    if ($status -notcontains 'workspace.state: aligned') {
        throw 'el estado del workspace no informó alineación'
    }
    $linkedStatus = & (Join-Path $project 'mem/scripts/bootstrap.ps1') -Target $project -Status
    if ($linkedStatus -notcontains 'workspace.state: aligned') {
        throw 'el instalador enlazado no informó alineación'
    }
    Set-Content -LiteralPath (Join-Path $project 'mem/workspace/.ato-ai-skill-mem-version.yml') -Value 'skill_version: 0.0.0'
    $outdatedStatus = & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -Status
    if ($outdatedStatus -notcontains 'workspace.state: compatible-update-available') {
        throw 'el estado del workspace no informó una actualización compatible'
    }
    $updateRejected = $false
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -UpdateWorkspace
    }
    catch {
        $updateRejected = $true
    }
    if (-not $updateRejected) {
        throw 'la actualización del workspace aceptó una fuente sin release'
    }
    Set-Content -LiteralPath (Join-Path $project 'mem/workspace/.ato-ai-skill-mem-version.yml') -Value 'workspace_format: 2'
    $incompatibleStatus = & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -Status
    if ($incompatibleStatus -notcontains 'workspace.data_compatibility: migration-required' -or $incompatibleStatus -notcontains 'workspace.state: migration-required') {
        throw 'el estado del workspace no informó una migración requerida'
    }
    if ([System.IO.File]::ReadAllText($agentsPath) -ne $agentsBefore) {
        throw 'bootstrap modificó AGENTS.md'
    }

    New-Item -ItemType Directory -Path (Join-Path $legacy 'mem/workspace/records') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $legacy 'mem/workspace/INDEX.md') -Value '# Legacy memory'
    $legacyStatus = & (Join-Path $root 'scripts/bootstrap.ps1') -Target $legacy -Status
    if ($legacyStatus -notcontains 'workspace.data_compatibility: compatible' -or $legacyStatus -notcontains 'workspace.state: legacy-compatible') {
        throw 'el workspace heredado no fue reconocido como compatible'
    }

    Set-Content -LiteralPath (Join-Path $project 'mem/workspace/INDEX.md') -Value '# Local memory'
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project
    if ((Get-Content -LiteralPath (Join-Path $project 'mem/workspace/INDEX.md') -Raw) -notmatch 'Local memory') {
        throw 'bootstrap sobrescribió el índice existente del workspace'
    }
    if ([System.IO.File]::ReadAllText($agentsPath) -ne $agentsBefore) {
        throw 'bootstrap modificó AGENTS.md durante una instalación repetida'
    }

    New-Item -ItemType Directory -Path (Join-Path $conflict 'mem/references') -Force | Out-Null
    $failedAsExpected = $false
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $conflict
    }
    catch {
        $failedAsExpected = $true
    }
    if (-not $failedAsExpected) {
        throw 'bootstrap aceptó un conflicto tardío con una ruta que no es enlace'
    }
    if (Test-Path -LiteralPath (Join-Path $conflict 'mem/SKILL.md')) {
        throw 'bootstrap creó SKILL.md antes de detectar un conflicto tardío'
    }
    if (Test-Path -LiteralPath (Join-Path $conflict 'mem/templates')) {
        throw 'bootstrap creó templates antes de detectar un conflicto tardío'
    }

    $removedArgumentRejected = $false
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -Integrate
    }
    catch {
        $removedArgumentRejected = $true
    }
    if (-not $removedArgumentRejected) {
        throw 'bootstrap aceptó un argumento retirado'
    }

    Write-Output 'Pruebas de bootstrap de PowerShell superadas'
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
