[CmdletBinding()]
param(
    [string]$Target,
    [switch]$Init,
    [switch]$Contextualize,
    [switch]$Status,
    [switch]$UpdateVault,
    [switch]$MigrateWorkspaceToVault,
    [switch]$MigrateVaultFormat,
    [switch]$Finalize,
    [switch]$SourceStatus,
    [switch]$UpdateSourceVault,
    [switch]$MigrateSourceWorkspaceToVault,
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
function Test-LocalFile([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    return $null -ne $item -and -not $item.PSIsContainer -and $item.LinkType -ne 'SymbolicLink'
}
function Test-LocalDirectory([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    return $null -ne $item -and $item.PSIsContainer -and $item.LinkType -ne 'SymbolicLink'
}

$operationCount = [int]$Init.IsPresent + [int]$Contextualize.IsPresent + [int]$Status.IsPresent + [int]$UpdateVault.IsPresent + [int]$MigrateWorkspaceToVault.IsPresent + [int]$MigrateVaultFormat.IsPresent + [int]$SourceStatus.IsPresent + [int]$UpdateSourceVault.IsPresent + [int]$MigrateSourceWorkspaceToVault.IsPresent
if ($operationCount -gt 1) {
    Fail 'solo se puede seleccionar una operación'
}
if ($IntegrateCodex -and $operationCount -gt 0 -and -not $Init) {
    Fail '-IntegrateCodex solo se admite durante la instalación'
}
if ($Finalize -and -not $MigrateVaultFormat) {
    Fail '-Finalize solo se admite con -MigrateVaultFormat'
}
$sourceModeCount = [int]$SourceStatus.IsPresent + [int]$UpdateSourceVault.IsPresent + [int]$MigrateSourceWorkspaceToVault.IsPresent
if ($sourceModeCount -gt 0 -and -not [string]::IsNullOrWhiteSpace($Target)) {
    Fail 'las operaciones de fuente no admiten -Target'
}
if ($sourceModeCount -eq 0 -and [string]::IsNullOrWhiteSpace($Target)) {
    Fail '-Target es obligatorio'
}
if ($sourceModeCount -gt 0) {
    $targetRoot = $null
    $memDir = $null
    $workspace = Join-Path $sourceRoot 'vault'
    $legacyWorkspace = Join-Path $sourceRoot 'workspace'
    $expectedWorkspaceKind = 'source'
}
else {
    $targetRoot = (Resolve-Path -LiteralPath $Target).Path
    if ($targetRoot -eq $sourceRoot) {
        Fail 'la raíz de la fuente no es un proyecto consumidor; usa -SourceStatus'
    }
    $memDir = Join-Path $targetRoot 'mem'
    $workspace = Join-Path $memDir 'vault'
    $legacyWorkspace = Join-Path $memDir 'workspace'
    $expectedWorkspaceKind = 'consumer'
    $integrationConfig = Join-Path $targetRoot '.ato-ai-skill-mem.yml'
    $codexAdapterDir = Join-Path $targetRoot '.agents/skills/ato-ai-project-mem'
}
$versionFile = Join-Path $workspace '.ato-ai-skill-mem-version.yml'
if (-not (Test-Path -LiteralPath $workspace) -and (Test-Path -LiteralPath (Join-Path $legacyWorkspace '.ato-ai-skill-mem-version.yml'))) { $versionFile = Join-Path $legacyWorkspace '.ato-ai-skill-mem-version.yml' }
$initializationState = 'unknown'
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

foreach ($required in @('SKILL.md', 'VERSION', 'VAULT_FORMAT', 'references', 'templates', 'scripts', 'scripts/vault.ps1', 'templates/vault/SKILL-VERSION.yml', 'templates/vault-layout/AGENTS.md', 'templates/integrations/host-config.yml', 'templates/integrations/codex/SKILL.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $required))) {
        Fail "falta el componente canónico $required en $sourceRoot"
    }
}

$skillVersion = (Get-Content -LiteralPath (Join-Path $sourceRoot 'VERSION') -Raw).Trim()
if ($skillVersion -notmatch '^\d+\.\d+\.\d+$') {
    Fail 'VERSION debe contener una versión semántica numérica (X.Y.Z)'
}
$currentVaultFormat = (Get-Content -LiteralPath (Join-Path $sourceRoot 'VAULT_FORMAT') -Raw).Trim()
if ($currentVaultFormat -notmatch '^[1-9]\d*$') {
    Fail 'VAULT_FORMAT debe contener un entero positivo'
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
$sourceWorktreeDirty = & git -C $sourceRoot status --porcelain 2>$null
if ($LASTEXITCODE -ne 0) {
    $sourceWorktreeDirty = 'unknown'
}
else {
    $sourceWorktreeDirty = ($sourceWorktreeDirty -join "`n").Trim()
}
$sourceTag = 'unreleased'
$sourceState = 'not-release-aligned'
if ($sourceBranch -eq 'master' -and $sourceRevision -eq $masterRevision -and $sourceRevision -eq $tagRevision -and [string]::IsNullOrEmpty($sourceWorktreeDirty)) {
    $sourceTag = $expectedTag
    $sourceState = 'release-aligned'
}
function Get-MarkerValue([string]$Key) {
    if (-not (Test-Path -LiteralPath $versionFile)) { return '' }
    $line = Get-Content -LiteralPath $versionFile | Where-Object { $_ -match "^${Key}:\s*(.*)$" } | Select-Object -First 1
    if ($null -eq $line) { return '' }
    return (($line -replace "^${Key}:\s*", '') -replace '"', '').Trim()
}
function Get-MarkerKeyCount([string]$Key) {
    if (-not (Test-Path -LiteralPath $versionFile)) { return 0 }
    return @((Get-Content -LiteralPath $versionFile | Where-Object { $_ -match "^${Key}:" })).Count
}
function Get-MarkerWorkspaceFormat {
    if (-not (Test-Path -LiteralPath $versionFile)) { return '1' }
    $markerFormat = Get-MarkerValue 'vault_format'
    if ([string]::IsNullOrWhiteSpace($markerFormat)) { $markerFormat = Get-MarkerValue 'workspace_format' }
    if ([string]::IsNullOrWhiteSpace($markerFormat)) { return '1' }
    return $markerFormat
}
function Get-MarkerWorkspaceKind {
    if (-not (Test-Path -LiteralPath $versionFile)) { return 'consumer' }
    $markerKind = Get-MarkerValue 'vault_kind'
    if ([string]::IsNullOrWhiteSpace($markerKind)) { $markerKind = Get-MarkerValue 'workspace_kind' }
    if ([string]::IsNullOrWhiteSpace($markerKind)) { return 'consumer' }
    return $markerKind
}
function Get-WorkspaceDataCompatibility {
    if (-not (Test-Path -LiteralPath $workspace)) { if (Test-Path -LiteralPath $legacyWorkspace) { return 'migration-required' }; return 'absent' }
    if ((Get-MarkerWorkspaceFormat) -eq $currentVaultFormat -and -not [string]::IsNullOrWhiteSpace((Get-MarkerValue 'vault_format'))) { return 'compatible' }
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
    if (-not (Test-Path -LiteralPath $workspace)) { if (Test-Path -LiteralPath $legacyWorkspace) { return 'migration-required' }; return 'absent' }
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
function Write-Marker([string]$CreatedAt, [string]$Destination = $versionFile) {
    $updatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
    $marker = Get-Content -LiteralPath (Join-Path $sourceRoot 'templates/vault/SKILL-VERSION.yml') -Raw
    $marker = $marker -replace '(?m)^vault_kind: .*$', "vault_kind: $expectedWorkspaceKind"
    $marker = $marker -replace '(?m)^skill_version: .*$', "skill_version: $skillVersion"
    $marker = $marker -replace '(?m)^vault_format: .*$', "vault_format: $currentVaultFormat"
    $marker = $marker -replace '(?m)^source_revision: .*$', "source_revision: $sourceRevision"
    $marker = $marker -replace '(?m)^source_tag: .*$', "source_tag: $sourceTag"
    $marker = $marker -replace '(?m)^created_at: .*$', "created_at: $CreatedAt"
    $marker = $marker -replace '(?m)^updated_at: .*$', "updated_at: $updatedAt"
    [System.IO.File]::WriteAllText($Destination, $marker)
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
    Write-Output "vault.format: $(Get-MarkerWorkspaceFormat)"
    Write-Output "vault.expected_format: $currentVaultFormat"
    Write-Output "vault.data_compatibility: $(Get-WorkspaceDataCompatibility)"
    Write-Output "vault.kind: $(Get-MarkerWorkspaceKind)"
    Write-Output "vault.expected_kind: $expectedWorkspaceKind"
    Write-Output "vault.state: $(Get-WorkspaceState)"
    if ($expectedWorkspaceKind -eq 'consumer') {
        Write-Output "integration.codex.state: $(Get-CodexIntegrationState)"
        Write-Output 'integration.codex.adapter_path: .agents/skills/ato-ai-project-mem'
    }
    if (Test-Path -LiteralPath $versionFile) {
        Write-Output "vault.skill_version: $(Get-MarkerValue 'skill_version')"
        Write-Output "vault.source_revision: $(Get-MarkerValue 'source_revision')"
        Write-Output "vault.source_tag: $(Get-MarkerValue 'source_tag')"
        Write-Output "vault.created_at: $(Get-MarkerValue 'created_at')"
        Write-Output "vault.updated_at: $(Get-MarkerValue 'updated_at')"
    }
    Write-ContextStatus
}

function Get-LocalFileCount([string]$Path) {
    if (-not (Test-LocalDirectory $Path)) { return 0 }
    return @((Get-ChildItem -LiteralPath $Path -Recurse -File -Force | Where-Object { $_.LinkType -ne 'SymbolicLink' })).Count
}
function Get-RecordFileCount {
    $items = @()
    $rootRecords = Join-Path $workspace 'records'
    if (Test-LocalDirectory $rootRecords) {
        $items += @(Get-ChildItem -LiteralPath $rootRecords -File -Force | Where-Object { $_.LinkType -ne 'SymbolicLink' })
    }
    $domainsRoot = Join-Path $workspace '20_domains'
    if (Test-LocalDirectory $domainsRoot) {
        $items += @(Get-ChildItem -LiteralPath $domainsRoot -Recurse -File -Force | Where-Object { $_.LinkType -ne 'SymbolicLink' -and $_.Extension -eq '.md' -and $_.FullName -match '[\\/]records[\\/]' })
    }
    return $items.Count
}
function Get-ResourceFileCount {
    $items = @()
    $rootResources = Join-Path $workspace '30_resources'
    if (Test-LocalDirectory $rootResources) {
        $items += @(Get-ChildItem -LiteralPath $rootResources -Recurse -File -Force | Where-Object { $_.LinkType -ne 'SymbolicLink' })
    }
    $domainsRoot = Join-Path $workspace '20_domains'
    if (Test-LocalDirectory $domainsRoot) {
        $items += @(Get-ChildItem -LiteralPath $domainsRoot -Recurse -File -Force | Where-Object { $_.LinkType -ne 'SymbolicLink' -and $_.FullName -match '[\\/]resources[\\/]' })
    }
    return $items.Count
}
function Get-DomainCount {
    $domainsRoot = Join-Path $workspace '20_domains'
    if (-not (Test-LocalDirectory $domainsRoot)) { return 0 }
    return @((Get-ChildItem -LiteralPath $domainsRoot -Force | Where-Object { $_.PSIsContainer -and $_.LinkType -ne 'SymbolicLink' })).Count
}
function Get-DomainFileCount([string]$Name) {
    $domainsRoot = Join-Path $workspace '20_domains'
    if (-not (Test-LocalDirectory $domainsRoot)) { return 0 }
    $count = 0
    foreach ($domain in @(Get-ChildItem -LiteralPath $domainsRoot -Force | Where-Object { $_.PSIsContainer -and $_.LinkType -ne 'SymbolicLink' })) {
        if (Test-LocalFile (Join-Path $domain.FullName $Name)) { $count++ }
    }
    return $count
}
function Get-InitializationState {
    if ($initializationState -ne 'unknown') { return $initializationState }
    if (Test-Path -LiteralPath $workspace -PathType Container) { return 'existing' }
    return 'new'
}
function Get-ContextState {
    switch (Get-WorkspaceState) {
        'migration-required' { return 'blocked' }
        'role-mismatch' { return 'blocked' }
        'vault-newer' { return 'blocked' }
        'version-mismatch' { return 'blocked' }
    }
    $domains = Get-DomainCount
    if ((Get-InitializationState) -eq 'new' -or $domains -eq 0) { return 'needs-definition' }
    $checkPass = $false
    if (Test-Path -LiteralPath $workspace -PathType Container) {
        try {
            & (Join-Path $sourceRoot 'scripts/vault.ps1') check -Vault $workspace *> $null
            $checkPass = $true
        }
        catch { $checkPass = $false }
    }
    if (-not $checkPass) { return 'needs-review' }
    return 'structurally-ready'
}
function Get-ContextNextStep {
    switch (Get-ContextState) {
        'blocked' { return 'migrate' }
        'needs-definition' { return 'define-expectation' }
        'needs-review' { return 'review-context' }
        'structurally-ready' { return 'validate-and-authorize' }
    }
}
function Write-ContextStatus {
    Write-Output "vault.initialization.state: $(Get-InitializationState)"
    Write-Output "vault.context.state: $(Get-ContextState)"
    Write-Output "vault.context.next_step: $(Get-ContextNextStep)"
    Write-Output "vault.context.root_agents: $(if (Test-LocalFile (Join-Path $workspace 'AGENTS.md')) { 'present' } else { 'missing' })"
    Write-Output "vault.context.indexes: $(if (Test-LocalFile (Join-Path $workspace '_indexes/INDEX.md')) { 'present' } else { 'missing' })"
    Write-Output "vault.context.maps_index: $(if (Test-LocalFile (Join-Path $workspace '_maps/INDEX.md')) { 'present' } else { 'missing' })"
    Write-Output "vault.context.action_log: $(if (Test-LocalFile (Join-Path $workspace '_indexes/action-log.md')) { 'present' } else { 'missing' })"
    Write-Output "vault.context.domains.total: $(Get-DomainCount)"
    Write-Output "vault.context.domains.with_agents: $(Get-DomainFileCount 'AGENTS.md')"
    Write-Output "vault.context.domains.with_indexes: $(Get-DomainFileCount 'INDEX.md')"
    Write-Output "vault.context.domains.with_metadata: $(Get-DomainFileCount 'domain.yml')"
    Write-Output "vault.data.records: $(Get-RecordFileCount)"
    Write-Output "vault.data.pending: $(Get-LocalFileCount (Join-Path $workspace '00_inbox/decisions-pending'))"
    Write-Output "vault.data.resources: $(Get-ResourceFileCount)"
}
function Write-ContextualizationPlan {
    Write-Output 'vault.context.wizard.mode: guided-agent'
    Write-Output 'vault.context.wizard.persistence: explicit-human-request'
    Write-Output 'vault.context.wizard.phase.1: define-expectation'
    Write-Output 'vault.context.wizard.phase.2: read-context'
    Write-Output 'vault.context.wizard.phase.3: define-data-management'
    Write-Output 'vault.context.wizard.phase.4: validate-and-authorize'
}
if ($Contextualize) {
    Write-Status
    Write-ContextualizationPlan
    exit 0
}
if ($Status -or $SourceStatus) {
    Write-Status
    exit 0
}

if ($MigrateWorkspaceToVault -or $MigrateSourceWorkspaceToVault) {
    if ($MigrateWorkspaceToVault -and -not (Test-Path -LiteralPath $memDir)) { Fail "la instancia no es un directorio: $memDir" }
    if (-not (Test-Path -LiteralPath $legacyWorkspace -PathType Container)) { Fail "no existe el almacenamiento heredado: $legacyWorkspace" }
    if (Test-Path -LiteralPath $workspace) { Fail "no se puede migrar: ya existe el destino $workspace" }
    $oldVersionFile = Join-Path $legacyWorkspace '.ato-ai-skill-mem-version.yml'
    if (-not (Test-Path -LiteralPath $oldVersionFile)) { Fail 'la migración requiere el manifiesto heredado' }
    $oldFormat = ((Get-Content -LiteralPath $oldVersionFile | Where-Object { $_ -match '^workspace_format:' } | Select-Object -First 1) -replace '^workspace_format:\s*','').Trim()
    if ([string]::IsNullOrWhiteSpace($oldFormat)) { $oldFormat = '1' }
    if ($oldFormat -ne '1') { Fail "el formato heredado no es migrable: $oldFormat" }
    $oldCreated = ((Get-Content -LiteralPath $oldVersionFile | Where-Object { $_ -match '^created_at:' } | Select-Object -First 1) -replace '^created_at:\s*','').Trim()
    if ([string]::IsNullOrWhiteSpace($oldCreated)) { $oldCreated = 'unknown' }
    $markerTemp = Join-Path ([System.IO.Path]::GetTempPath()) ('ato-ai-vault-marker-' + [guid]::NewGuid() + '.yml')
    try {
        Write-Marker $oldCreated $markerTemp
        try {
            Move-Item -LiteralPath $legacyWorkspace -Destination $workspace
        }
        catch {
            throw "no se pudo mover el almacenamiento heredado: $($_.Exception.Message)"
        }
        $versionFile = Join-Path $workspace '.ato-ai-skill-mem-version.yml'
        try {
            Move-Item -LiteralPath $markerTemp -Destination $versionFile -Force
        }
        catch {
            try {
                Move-Item -LiteralPath $workspace -Destination $legacyWorkspace
            }
            catch {
                throw "no se pudo actualizar el manifiesto y la reversión también falló: $($_.Exception.Message)"
            }
            throw 'no se pudo actualizar el manifiesto; la migración fue revertida'
        }
    }
    finally {
        if (Test-Path -LiteralPath $markerTemp) { Remove-Item -LiteralPath $markerTemp -Force -ErrorAction SilentlyContinue }
    }
    Write-Output "migración completada: $legacyWorkspace -> $workspace"
    exit 0
}

if ($MigrateVaultFormat) {
    if (-not (Test-Path -LiteralPath $workspace -PathType Container)) { Fail 'la migración de formato requiere una vault existente' }
    if (Test-Path -LiteralPath $legacyWorkspace -PathType Container) { Fail 'existe mem/workspace; ejecuta -MigrateWorkspaceToVault explícitamente' }
    if (-not (Test-Path -LiteralPath $versionFile -PathType Leaf)) { Fail 'la migración de formato requiere un manifiesto de formato 2' }
    if ((Get-MarkerKeyCount 'vault_format') -ne 1 -or (Get-MarkerKeyCount 'vault_kind') -ne 1) { Fail 'el manifiesto de formato 2 es ambiguo' }
    if ((Get-MarkerValue 'vault_format') -ne '2') { Fail 'la migración de formato solo admite vault_format: 2' }
    if ((Get-MarkerValue 'vault_kind') -ne 'consumer') { Fail 'la migración de formato solo admite vault_kind: consumer' }
    if (-not $Finalize) {
        & (Join-Path $sourceRoot 'scripts/vault.ps1') migration-plan -Vault $workspace
        Write-Output 'migración de formato preparada: resuelve los registros raíz y ejecuta -MigrateVaultFormat -Finalize'
        exit 0
    }
    $rootRecords = Join-Path $workspace 'records'
    foreach ($directory in @('00_inbox','10_areas','20_domains','30_resources','40_archive','50_daily','60_exports','_indexes','_maps','_templates')) { if (-not (Test-LocalDirectory (Join-Path $workspace $directory))) { Fail 'la finalización requiere una migración de formato previamente preparada' } }
    foreach ($file in @('AGENTS.md','_indexes/INDEX.md','_indexes/action-log.md','_maps/INDEX.md')) { if (-not (Test-LocalFile (Join-Path $workspace $file))) { Fail 'la finalización requiere una migración de formato previamente preparada' } }
    if ((Test-Path -LiteralPath $rootRecords -PathType Container) -and $null -ne (Get-ChildItem -LiteralPath $rootRecords -Force | Select-Object -First 1)) { Fail "la migración de formato tiene contenido pendiente en records/: $((Get-ChildItem -LiteralPath $rootRecords -Force | Select-Object -First 1).FullName)" }
    $legacyIndex = Join-Path $workspace 'INDEX.md'
    $archivedIndex = Join-Path $workspace '40_archive/legacy-root-INDEX.md'
    if ((Test-Path -LiteralPath $legacyIndex) -and (Test-Path -LiteralPath $archivedIndex)) { Fail "el índice legado ya existe en el archivo: $archivedIndex" }
    $createdAt = Get-MarkerValue 'created_at'
    if ([string]::IsNullOrWhiteSpace($createdAt)) { $createdAt = 'unknown' }
    $markerTemp = Join-Path $workspace ('.ato-ai-vault-marker-' + [guid]::NewGuid() + '.yml')
    $movedIndex = $false
    try {
        Write-Marker $createdAt $markerTemp
        if (Test-Path -LiteralPath $legacyIndex) {
            Move-Item -LiteralPath $legacyIndex -Destination $archivedIndex
            $movedIndex = $true
        }
        try {
            Move-Item -LiteralPath $markerTemp -Destination $versionFile -Force
        }
        catch {
            if ($movedIndex) {
                try { Move-Item -LiteralPath $archivedIndex -Destination $legacyIndex }
                catch { throw "no se pudo escribir el manifiesto y la reversión del índice también falló: $($_.Exception.Message)" }
            }
            throw 'no se pudo escribir el manifiesto; la migración fue revertida'
        }
    }
    finally {
        if (Test-Path -LiteralPath $markerTemp) { Remove-Item -LiteralPath $markerTemp -Force -ErrorAction SilentlyContinue }
    }
    Write-Output 'migración de formato completada: vault_format 2 -> 3'
    exit 0
}

if ($UpdateSourceVault) {
    if (-not (Test-Path -LiteralPath $workspace)) {
        Fail 'la actualización del vault fuente requiere vault/'
    }
    if (-not (Test-Path -LiteralPath $versionFile)) {
        Fail 'el vault fuente requiere un manifiesto con vault_kind: source'
    }
    if ((Get-MarkerWorkspaceKind) -ne 'source') {
        Fail 'el manifiesto no pertenece a un vault de fuente'
    }
    if ($sourceState -ne 'release-aligned') {
        Fail 'la actualización del vault fuente requiere una fuente release-aligned'
    }
    if (-not [string]::IsNullOrEmpty($sourceWorktreeDirty)) {
        Fail 'la actualización del vault fuente requiere un checkout limpio'
    }
    if ((Get-WorkspaceDataCompatibility) -ne 'compatible') {
        Fail 'el formato del vault requiere una migración confirmada'
    }
    if ((Get-WorkspaceState) -notin @('compatible-update-available', 'aligned')) {
        Fail 'la actualización del vault fuente no avanzaría la versión registrada del skill'
    }
    $createdAt = Get-MarkerValue 'created_at'
    if ([string]::IsNullOrWhiteSpace($createdAt)) { $createdAt = 'unknown' }
    Write-Marker $createdAt
    Write-Output "vault de fuente actualizado: $workspace (vault: $(Get-WorkspaceState))"
    exit 0
}

$memItem = Get-Item -LiteralPath $memDir -Force -ErrorAction SilentlyContinue
if ($null -ne $memItem -and -not $memItem.PSIsContainer) {
    Fail "la ruta de instancia existe pero no es un directorio: $memDir"
}
if ($null -ne $memItem -and $memItem.LinkType -eq 'SymbolicLink') {
    Fail "el directorio de instancia debe ser local, no un enlace simbólico: $memDir"
}
if ($Init -and (Test-Path -LiteralPath $workspace -PathType Container)) {
    Fail 'la inicialización requiere una vault ausente; usa -Contextualize o -UpdateVault para una vault existente'
}
if ($UpdateVault -and -not (Test-Path -LiteralPath $workspace)) {
    Fail 'la actualización del vault requiere una instancia existente'
}
if ($UpdateVault -and $sourceState -ne 'release-aligned') {
    Fail 'la actualización del vault requiere una fuente release-aligned'
}
if ($UpdateVault -and (Test-Path -LiteralPath $workspace) -and (Get-WorkspaceDataCompatibility) -ne 'compatible') {
    Fail 'el formato del vault requiere una migración confirmada'
}
if ((Test-Path -LiteralPath $versionFile) -and (Get-MarkerWorkspaceKind) -ne 'consumer') {
    Fail 'el manifiesto no pertenece a un vault de consumidor'
}
if ($IntegrateCodex) {
    Assert-CodexIntegration
}
if ($UpdateVault -and (Get-WorkspaceState) -notin @('legacy-compatible', 'compatible-update-available', 'aligned')) {
    Fail 'la actualización del vault no avanzaría la versión registrada del skill'
}
if (Test-Path -LiteralPath $legacyWorkspace -PathType Container) { Fail 'existe mem/workspace; ejecuta -MigrateWorkspaceToVault explícitamente' }

foreach ($linkedItem in @('SKILL.md', 'VERSION', 'VAULT_FORMAT', 'references', 'templates', 'scripts')) {
    Assert-LinkDestination (Join-Path $sourceRoot $linkedItem) (Join-Path $memDir $linkedItem)
}

[System.IO.Directory]::CreateDirectory($memDir) | Out-Null
foreach ($linkedItem in @('SKILL.md', 'VERSION', 'VAULT_FORMAT', 'references', 'templates', 'scripts')) {
    Ensure-Symlink (Join-Path $sourceRoot $linkedItem) (Join-Path $memDir $linkedItem)
}

$workspaceExisted = Test-Path -LiteralPath $workspace
$initializationState = if ($workspaceExisted) { 'existing' } else { 'new' }
[System.IO.Directory]::CreateDirectory($workspace) | Out-Null
& (Join-Path $sourceRoot 'scripts/vault.ps1') init-layout -Vault $workspace

if ($UpdateVault -or -not (Test-Path -LiteralPath $versionFile)) {
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

Write-Output "instancia de memoria lista: $memDir (vault: $(Get-WorkspaceState))"
Write-ContextStatus
