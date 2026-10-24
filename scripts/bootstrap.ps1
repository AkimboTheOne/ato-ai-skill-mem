[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Target,
    [switch]$Status,
    [switch]$UpdateWorkspace
)

$ErrorActionPreference = 'Stop'

$sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$targetRoot = (Resolve-Path -LiteralPath $Target).Path
$memDir = Join-Path $targetRoot 'mem'
$workspace = Join-Path $memDir 'workspace'
$versionFile = Join-Path $workspace '.ato-ai-skill-mem-version.yml'

function Fail([string]$Message) {
    throw "error: $Message"
}

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

foreach ($required in @('SKILL.md', 'VERSION', 'WORKSPACE_FORMAT', 'references', 'templates', 'scripts')) {
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
if ($Status) {
    Write-Output "source.version: $skillVersion"
    Write-Output "source.expected_tag: $expectedTag"
    Write-Output "source.branch: $sourceBranch"
    Write-Output "source.revision: $sourceRevision"
    Write-Output "source.state: $sourceState"
    Write-Output "workspace.format: $(Get-MarkerWorkspaceFormat)"
    Write-Output "workspace.expected_format: $currentWorkspaceFormat"
    Write-Output "workspace.data_compatibility: $(Get-WorkspaceDataCompatibility)"
    Write-Output "workspace.state: $(Get-WorkspaceState)"
    if (Test-Path -LiteralPath $versionFile) {
        Write-Output "workspace.skill_version: $(Get-MarkerValue 'skill_version')"
        Write-Output "workspace.source_revision: $(Get-MarkerValue 'source_revision')"
        Write-Output "workspace.created_at: $(Get-MarkerValue 'created_at')"
        Write-Output "workspace.updated_at: $(Get-MarkerValue 'updated_at')"
    }
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
    $updatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
    $marker = Get-Content -LiteralPath (Join-Path $sourceRoot 'templates/workspace/SKILL-VERSION.yml') -Raw
    $marker = $marker -replace '(?m)^skill_version: .*$', "skill_version: $skillVersion"
    $marker = $marker -replace '(?m)^workspace_format: .*$', "workspace_format: $currentWorkspaceFormat"
    $marker = $marker -replace '(?m)^source_revision: .*$', "source_revision: $sourceRevision"
    $marker = $marker -replace '(?m)^source_tag: .*$', "source_tag: $sourceTag"
    $marker = $marker -replace '(?m)^created_at: .*$', "created_at: $createdAt"
    $marker = $marker -replace '(?m)^updated_at: .*$', "updated_at: $updatedAt"
    [System.IO.File]::WriteAllText($versionFile, $marker)
}

Write-Output "instancia de memoria lista: $memDir (workspace: $(Get-WorkspaceState))"
