[CmdletBinding()]
param(
    [string]$Target,
    [switch]$Status,
    [switch]$UpdateWorkspace,
    [switch]$SourceStatus,
    [switch]$UpdateSourceWorkspace,
    [switch]$IntegrateCodex,
    [Parameter(DontShow = $true)]
    [switch]$Integrate
)

$ErrorActionPreference = 'Stop'

if ($Integrate) {
    throw 'error: -Integrate fue retirado; usa -IntegrateCodex'
}

$sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

function Fail([string]$Message) {
    throw "error: $Message"
}

$operationCount = [int]$Status.IsPresent + [int]$UpdateWorkspace.IsPresent + [int]$SourceStatus.IsPresent + [int]$UpdateSourceWorkspace.IsPresent
if ($operationCount -gt 1) {
    Fail 'solo se puede seleccionar una operación'
}
if ($IntegrateCodex -and $operationCount -gt 0) {
    Fail '-IntegrateCodex solo se admite durante la instalación'
}
$sourceModeCount = [int]$SourceStatus.IsPresent + [int]$UpdateSourceWorkspace.IsPresent
if ($sourceModeCount -gt 0 -and -not [string]::IsNullOrWhiteSpace($Target)) {
    Fail 'las operaciones de fuente no admiten -Target'
}
if ($sourceModeCount -eq 0 -and [string]::IsNullOrWhiteSpace($Target)) {
    Fail '-Target es obligatorio'
}
if ($sourceModeCount -gt 0) {
    $targetRoot = $null
    $memDir = $null
    $workspace = Join-Path $sourceRoot 'workspace'
    $expectedWorkspaceKind = 'source'
}
else {
    $targetRoot = (Resolve-Path -LiteralPath $Target).Path
    if ($targetRoot -eq $sourceRoot) {
        Fail 'la raíz de la fuente no es un proyecto consumidor; usa -SourceStatus'
    }
    $memDir = Join-Path $targetRoot 'mem'
    $workspace = Join-Path $memDir 'workspace'
    $expectedWorkspaceKind = 'consumer'
    $integrationConfig = Join-Path $targetRoot '.ato-ai-skill-mem.yml'
    $codexAdapterDir = Join-Path $targetRoot '.agents/skills/ato-ai-project-mem'
}
$versionFile = Join-Path $workspace '.ato-ai-skill-mem-version.yml'
$integrationTemplate = Join-Path $sourceRoot 'templates/integrations/host-config.yml'
$codexAdapterTemplate = Join-Path $sourceRoot 'templates/integrations/codex/SKILL.md'

function Ensure-Symlink([string]$Source, [string]$Destination) {
    $existing = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        return
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
    }
    catch {
        Fail "no se pudo crear el enlace simbólico $Destination; habilita el modo de desarrollador o usa una terminal con permiso para enlaces simbólicos en vez de copiar el skill"
    }
}

function Assert-LinkDestination([string]$Source, [string]$Destination) {
    $existing = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        if ($existing.LinkType -ne 'SymbolicLink') {
            Fail "no se puede reemplazar una ruta existente que no es enlace: $Destination"
        }

        $targets = @($existing.Target | ForEach-Object { [string]$_ })
        if ($targets -notcontains $Source) {
            Fail "el enlace existente difiere: $Destination"
        }
        return
    }
}

foreach ($required in @('SKILL.md', 'VERSION', 'WORKSPACE_FORMAT', 'references', 'templates', 'scripts', 'templates/integrations/host-config.yml', 'templates/integrations/codex/SKILL.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $required))) {
        Fail "falta el componente canónico $required en $sourceRoot"
    }
}

$skillVersion = (Get-Content -LiteralPath (Join-Path $sourceRoot 'VERSION') -Raw).Trim()
if ($skillVersion -notmatch '^\d+\.\d+\.\d+$') {
    Fail 'VERSION debe contener una versión semántica numérica (X.Y.Z)'
}
$currentWorkspaceFormat = (Get-Content -LiteralPath (Join-Path $sourceRoot 'WORKSPACE_FORMAT') -Raw).Trim()
if ($currentWorkspaceFormat -notmatch '^[1-9]\d*$') {
    Fail 'WORKSPACE_FORMAT debe contener un entero positivo'
}
$expectedTag = "v$skillVersion"
function Get-GitValue([string[]]$Arguments, [string]$Fallback) {
    try {
        $value = & git -C $sourceRoot @Arguments 2>$null
        if ($LASTEXITCODE -eq 0 -and $null -ne $value -and "$value".Length -gt 0) { return "$value".Trim() }
    }
    catch {}
    return $Fallback
}
$sourceRevision = Get-GitValue @('rev-parse', 'HEAD') 'unknown'
$sourceBranch = Get-GitValue @('symbolic-ref', '--quiet', '--short', 'HEAD') 'detached-or-unavailable'
$masterRevision = Get-GitValue @('rev-parse', 'master') 'unavailable'
$tagRevision = Get-GitValue @('rev-list', '-n', '1', $expectedTag) 'unavailable'
$sourceDirty = & git -C $sourceRoot status --porcelain -- AGENTS.md README.md SKILL.md VERSION WORKSPACE_FORMAT references templates scripts 2>$null
if ($LASTEXITCODE -ne 0) {
    $sourceDirty = 'unknown'
}
else {
    $sourceDirty = ($sourceDirty -join "`n").Trim()
}
$sourceWorktreeDirty = & git -C $sourceRoot status --porcelain 2>$null
if ($LASTEXITCODE -ne 0) {
    $sourceWorktreeDirty = 'unknown'
}
else {
    $sourceWorktreeDirty = ($sourceWorktreeDirty -join "`n").Trim()
}
$sourceTag = 'unreleased'
$sourceState = 'not-release-aligned'
if ($sourceBranch -eq 'master' -and $sourceRevision -eq $masterRevision -and $sourceRevision -eq $tagRevision -and [string]::IsNullOrEmpty($sourceDirty)) {
    $sourceTag = $expectedTag
    $sourceState = 'release-aligned'
}
function Get-MarkerValue([string]$Key) {
    if (-not (Test-Path -LiteralPath $versionFile)) { return '' }
    $line = Get-Content -LiteralPath $versionFile | Where-Object { $_ -match "^${Key}:\s*(.*)$" } | Select-Object -First 1
    if ($null -eq $line) { return '' }
    return (($line -replace "^${Key}:\s*", '') -replace '"', '').Trim()
}
function Get-MarkerWorkspaceFormat {
    if (-not (Test-Path -LiteralPath $versionFile)) { return '1' }
    $markerFormat = Get-MarkerValue 'workspace_format'
    if ([string]::IsNullOrWhiteSpace($markerFormat)) { return '1' }
    return $markerFormat
}
function Get-MarkerWorkspaceKind {
    if (-not (Test-Path -LiteralPath $versionFile)) { return 'consumer' }
    $markerKind = Get-MarkerValue 'workspace_kind'
    if ([string]::IsNullOrWhiteSpace($markerKind)) { return 'consumer' }
    return $markerKind
}
function Get-WorkspaceDataCompatibility {
    if (-not (Test-Path -LiteralPath $workspace)) { return 'absent' }
    if ((Get-MarkerWorkspaceFormat) -eq $currentWorkspaceFormat) { return 'compatible' }
    return 'migration-required'
}
function Get-VersionRelation([string]$WorkspaceVersion) {
    $sourceParts = $skillVersion.Split('.') | ForEach-Object { [int]$_ }
    $workspaceParts = $WorkspaceVersion.Split('.') | ForEach-Object { [int]$_ }
    for ($index = 0; $index -lt 3; $index++) {
        if ($sourceParts[$index] -gt $workspaceParts[$index]) { return 'source-newer' }
        if ($sourceParts[$index] -lt $workspaceParts[$index]) { return 'workspace-newer' }
    }
    return 'same'
}
function Get-WorkspaceState {
    if (-not (Test-Path -LiteralPath $workspace)) { return 'absent' }
    if (-not (Test-Path -LiteralPath $versionFile)) { return 'legacy-compatible' }
    if ((Get-MarkerWorkspaceKind) -ne $expectedWorkspaceKind) { return 'role-mismatch' }
    if ((Get-WorkspaceDataCompatibility) -ne 'compatible') { return 'migration-required' }
    if ((Get-MarkerValue 'skill_version') -ne $skillVersion) {
        $workspaceVersion = Get-MarkerValue 'skill_version'
        if ($workspaceVersion -notmatch '^\d+\.\d+\.\d+$') { return 'version-mismatch' }
        switch (Get-VersionRelation $workspaceVersion) {
            'source-newer' { return 'compatible-update-available' }
            'workspace-newer' { return 'workspace-newer' }
            default { return 'version-mismatch' }
        }
    }
    return 'aligned'
}
function Write-Marker([string]$CreatedAt) {
    $updatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
    $marker = Get-Content -LiteralPath (Join-Path $sourceRoot 'templates/workspace/SKILL-VERSION.yml') -Raw
    $marker = $marker -replace '(?m)^workspace_kind: .*$', "workspace_kind: $expectedWorkspaceKind"
    $marker = $marker -replace '(?m)^skill_version: .*$', "skill_version: $skillVersion"
    $marker = $marker -replace '(?m)^workspace_format: .*$', "workspace_format: $currentWorkspaceFormat"
    $marker = $marker -replace '(?m)^source_revision: .*$', "source_revision: $sourceRevision"
    $marker = $marker -replace '(?m)^source_tag: .*$', "source_tag: $sourceTag"
    $marker = $marker -replace '(?m)^created_at: .*$', "created_at: $CreatedAt"
    $marker = $marker -replace '(?m)^updated_at: .*$', "updated_at: $updatedAt"
    [System.IO.File]::WriteAllText($versionFile, $marker)
}
function Test-FileMatches([string]$Path, [string]$Template) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item -or $item.PSIsContainer -or $item.LinkType -eq 'SymbolicLink') { return $false }
    return [System.IO.File]::ReadAllText($Path) -eq [System.IO.File]::ReadAllText($Template)
}
function Test-CodexAdapterManaged {
    $adapterItem = Get-Item -LiteralPath $codexAdapterDir -Force -ErrorAction SilentlyContinue
    if ($null -eq $adapterItem -or -not $adapterItem.PSIsContainer -or $adapterItem.LinkType -eq 'SymbolicLink') { return $false }
    if (-not (Test-FileMatches (Join-Path $codexAdapterDir 'SKILL.md') $codexAdapterTemplate)) { return $false }
    return @((Get-ChildItem -LiteralPath $codexAdapterDir -Force)).Count -eq 1
}
function Get-CodexIntegrationState {
    if ($null -eq (Get-Item -LiteralPath $integrationConfig -Force -ErrorAction SilentlyContinue)) { return 'not-configured' }
    if (-not (Test-FileMatches $integrationConfig $integrationTemplate)) { return 'unsupported-config' }
    if (-not (Test-Path -LiteralPath $codexAdapterDir -PathType Container)) { return 'adapter-missing' }
    if (Test-CodexAdapterManaged) { return 'aligned' }
    return 'conflict'
}
function Assert-CodexIntegration {
    if ($null -ne (Get-Item -LiteralPath $integrationConfig -Force -ErrorAction SilentlyContinue) -and -not (Test-FileMatches $integrationConfig $integrationTemplate)) {
        Fail "la configuración de integración no coincide: $integrationConfig"
    }
    foreach ($path in @((Join-Path $targetRoot '.agents'), (Join-Path $targetRoot '.agents/skills'))) {
        $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and ($item.LinkType -eq 'SymbolicLink' -or -not $item.PSIsContainer)) {
            Fail "la ruta de integración no es un directorio local: $path"
        }
    }
    if ($null -ne (Get-Item -LiteralPath $codexAdapterDir -Force -ErrorAction SilentlyContinue) -and -not (Test-CodexAdapterManaged)) {
        Fail "el adaptador de Codex existente no está administrado: $codexAdapterDir"
    }
}
function Install-CodexIntegration {
    [System.IO.Directory]::CreateDirectory($codexAdapterDir) | Out-Null
    if ($null -eq (Get-Item -LiteralPath $integrationConfig -Force -ErrorAction SilentlyContinue)) {
        Copy-Item -LiteralPath $integrationTemplate -Destination $integrationConfig
    }
    $adapterSkill = Join-Path $codexAdapterDir 'SKILL.md'
    if ($null -eq (Get-Item -LiteralPath $adapterSkill -Force -ErrorAction SilentlyContinue)) {
        Copy-Item -LiteralPath $codexAdapterTemplate -Destination $adapterSkill
    }
}
function Write-Status {
    Write-Output "source.version: $skillVersion"
    Write-Output "source.expected_tag: $expectedTag"
    Write-Output "source.branch: $sourceBranch"
    Write-Output "source.revision: $sourceRevision"
    Write-Output "source.state: $sourceState"
    Write-Output "workspace.format: $(Get-MarkerWorkspaceFormat)"
    Write-Output "workspace.expected_format: $currentWorkspaceFormat"
    Write-Output "workspace.data_compatibility: $(Get-WorkspaceDataCompatibility)"
    Write-Output "workspace.kind: $(Get-MarkerWorkspaceKind)"
    Write-Output "workspace.expected_kind: $expectedWorkspaceKind"
    Write-Output "workspace.state: $(Get-WorkspaceState)"
    if ($expectedWorkspaceKind -eq 'consumer') {
        Write-Output "integration.codex.state: $(Get-CodexIntegrationState)"
        Write-Output 'integration.codex.adapter_path: .agents/skills/ato-ai-project-mem'
    }
    if (Test-Path -LiteralPath $versionFile) {
        Write-Output "workspace.skill_version: $(Get-MarkerValue 'skill_version')"
        Write-Output "workspace.source_revision: $(Get-MarkerValue 'source_revision')"
        Write-Output "workspace.source_tag: $(Get-MarkerValue 'source_tag')"
        Write-Output "workspace.created_at: $(Get-MarkerValue 'created_at')"
        Write-Output "workspace.updated_at: $(Get-MarkerValue 'updated_at')"
    }
}
if ($Status -or $SourceStatus) {
    Write-Status
    exit 0
}

if ($UpdateSourceWorkspace) {
    if (-not (Test-Path -LiteralPath $workspace)) {
        Fail 'la actualización del workspace fuente requiere workspace/'
    }
    if (-not (Test-Path -LiteralPath $versionFile)) {
        Fail 'el workspace fuente requiere un manifiesto con workspace_kind: source'
    }
    if ((Get-MarkerWorkspaceKind) -ne 'source') {
        Fail 'el manifiesto no pertenece a un workspace de fuente'
    }
    if ($sourceState -ne 'release-aligned') {
        Fail 'la actualización del workspace fuente requiere una fuente release-aligned'
    }
    if (-not [string]::IsNullOrEmpty($sourceWorktreeDirty)) {
        Fail 'la actualización del workspace fuente requiere un checkout limpio'
    }
    if ((Get-WorkspaceDataCompatibility) -ne 'compatible') {
        Fail 'el formato del workspace requiere una migración confirmada'
    }
    if ((Get-WorkspaceState) -notin @('compatible-update-available', 'aligned')) {
        Fail 'la actualización del workspace fuente no avanzaría la versión registrada del skill'
    }
    $createdAt = Get-MarkerValue 'created_at'
    if ([string]::IsNullOrWhiteSpace($createdAt)) { $createdAt = 'unknown' }
    Write-Marker $createdAt
    Write-Output "workspace de fuente actualizado: $workspace (workspace: $(Get-WorkspaceState))"
    exit 0
}

$memItem = Get-Item -LiteralPath $memDir -Force -ErrorAction SilentlyContinue
if ($null -ne $memItem -and -not $memItem.PSIsContainer) {
    Fail "la ruta de instancia existe pero no es un directorio: $memDir"
}
if ($null -ne $memItem -and $memItem.LinkType -eq 'SymbolicLink') {
    Fail "el directorio de instancia debe ser local, no un enlace simbólico: $memDir"
}
if ($UpdateWorkspace -and -not (Test-Path -LiteralPath $workspace)) {
    Fail 'la actualización del workspace requiere una instancia existente'
}
if ($UpdateWorkspace -and $sourceState -ne 'release-aligned') {
    Fail 'la actualización del workspace requiere una fuente release-aligned'
}
if ($UpdateWorkspace -and (Test-Path -LiteralPath $workspace) -and (Get-WorkspaceDataCompatibility) -ne 'compatible') {
    Fail 'el formato del workspace requiere una migración confirmada'
}
if ((Test-Path -LiteralPath $versionFile) -and (Get-MarkerWorkspaceKind) -ne 'consumer') {
    Fail 'el manifiesto no pertenece a un workspace de consumidor'
}
if ($IntegrateCodex) {
    Assert-CodexIntegration
}
if ($UpdateWorkspace -and (Get-WorkspaceState) -notin @('legacy-compatible', 'compatible-update-available', 'aligned')) {
    Fail 'la actualización del workspace no avanzaría la versión registrada del skill'
}

foreach ($linkedItem in @('SKILL.md', 'VERSION', 'WORKSPACE_FORMAT', 'references', 'templates', 'scripts')) {
    Assert-LinkDestination (Join-Path $sourceRoot $linkedItem) (Join-Path $memDir $linkedItem)
}

[System.IO.Directory]::CreateDirectory($memDir) | Out-Null
foreach ($linkedItem in @('SKILL.md', 'VERSION', 'WORKSPACE_FORMAT', 'references', 'templates', 'scripts')) {
    Ensure-Symlink (Join-Path $sourceRoot $linkedItem) (Join-Path $memDir $linkedItem)
}

$workspaceExisted = Test-Path -LiteralPath $workspace
[System.IO.Directory]::CreateDirectory((Join-Path $workspace 'records')) | Out-Null
$index = Join-Path $workspace 'INDEX.md'
if (-not (Test-Path -LiteralPath $index)) {
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'templates/workspace/INDEX.md') -Destination $index
}

if ($UpdateWorkspace -or -not (Test-Path -LiteralPath $versionFile)) {
    $createdAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
    if ($workspaceExisted) {
        $createdAt = Get-MarkerValue 'created_at'
        if ([string]::IsNullOrWhiteSpace($createdAt)) { $createdAt = 'unknown' }
    }
    Write-Marker $createdAt
}
if ($IntegrateCodex) {
    Install-CodexIntegration
}

Write-Output "instancia de memoria lista: $memDir (workspace: $(Get-WorkspaceState))"
