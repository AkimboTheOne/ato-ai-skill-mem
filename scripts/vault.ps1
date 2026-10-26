[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('init-layout', 'create-domain', 'check', 'migration-plan', 'migration-apply')]
    [string]$Command,
    [Parameter(Mandatory = $true)]
    [string]$Vault,
    [string]$Id,
    [string]$Domain,
    [string]$Title,
    [string]$Record
)

$ErrorActionPreference = 'Stop'
$titleWasProvided = $PSBoundParameters.ContainsKey('Title')
function Fail([string]$Message) { throw "error: $Message" }
if (-not (Test-Path -LiteralPath $Vault -PathType Container)) { Fail "la vault no existe: $Vault" }
$Vault = (Resolve-Path -LiteralPath $Vault).Path
$sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$layout = Join-Path $sourceRoot 'templates/vault-layout'
function Test-ValidId([string]$Value) { return $Value -cmatch '^[a-z0-9][a-z0-9-]{0,62}$' }
function Test-LocalFile([string]$Path) { $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue; return $null -ne $item -and -not $item.PSIsContainer -and $item.LinkType -ne 'SymbolicLink' }
function Test-LocalDirectory([string]$Path) { $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue; return $null -ne $item -and $item.PSIsContainer -and $item.LinkType -ne 'SymbolicLink' }
function Copy-IfMissing([string]$Source, [string]$Destination) { if (-not (Test-Path -LiteralPath $Destination)) { Copy-Item -LiteralPath $Source -Destination $Destination } }
function ConvertTo-YamlQuoted([string]$Value) { return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"' }
function Initialize-Layout {
    foreach ($directory in @('00_inbox/decisions-pending','10_areas','20_domains','30_resources','40_archive','50_daily','60_exports','_indexes','_maps','_templates')) { [System.IO.Directory]::CreateDirectory((Join-Path $Vault $directory)) | Out-Null }
    Copy-IfMissing (Join-Path $layout 'AGENTS.md') (Join-Path $Vault 'AGENTS.md')
    foreach ($name in @('domain.yml','domain-AGENTS.md','domain-INDEX.md','area.md','daily.md','pending-decision.md','export.md')) { Copy-IfMissing (Join-Path $layout $name) (Join-Path $Vault "_templates/$name") }
    if (-not (Test-Path -LiteralPath (Join-Path $Vault '_indexes/INDEX.md'))) { [System.IO.File]::WriteAllText((Join-Path $Vault '_indexes/INDEX.md'), '# Índices de la vault') }
    if (-not (Test-Path -LiteralPath (Join-Path $Vault '_indexes/action-log.md'))) { [System.IO.File]::WriteAllText((Join-Path $Vault '_indexes/action-log.md'), '# Registro de acciones' + [Environment]::NewLine) }
    if (-not (Test-Path -LiteralPath (Join-Path $Vault '_maps/INDEX.md'))) { [System.IO.File]::WriteAllText((Join-Path $Vault '_maps/INDEX.md'), '# Mapas de la vault') }
}
function New-Domain {
    $domainId = if ($Id) { $Id } else { $Domain }
    if (-not (Test-ValidId $domainId)) { Fail '--id debe usar minúsculas, dígitos y guiones' }
    if (-not $titleWasProvided) { $Title = $domainId }
    elseif ([string]::IsNullOrWhiteSpace($Title)) { Fail '--title no puede estar vacío ni contener solo espacios' }
    if ($Title -match '[\r\n]') { Fail '--title debe ser una sola línea' }
    Initialize-Layout
    $domainPath = Join-Path $Vault "20_domains/$domainId"
    if (Test-Path -LiteralPath $domainPath) { Fail "el dominio ya existe: $domainId" }
    $temporaryPath = Join-Path (Join-Path $Vault '20_domains') ('.' + $domainId + '.tmp.' + [guid]::NewGuid())
    try {
        [System.IO.Directory]::CreateDirectory((Join-Path $temporaryPath 'records')) | Out-Null
        [System.IO.Directory]::CreateDirectory((Join-Path $temporaryPath 'resources')) | Out-Null
        $metadata = "format: 1$([Environment]::NewLine)id: $domainId$([Environment]::NewLine)title: $(ConvertTo-YamlQuoted $Title)$([Environment]::NewLine)status: active$([Environment]::NewLine)scope: contextual$([Environment]::NewLine)areas: []$([Environment]::NewLine)routing:$([Environment]::NewLine)  rules: []$([Environment]::NewLine)"
        [System.IO.File]::WriteAllText((Join-Path $temporaryPath 'domain.yml'), $metadata)
        $agentTemplate = Get-Content -LiteralPath (Join-Path $layout 'domain-AGENTS.md') -Raw
        [System.IO.File]::WriteAllText((Join-Path $temporaryPath 'AGENTS.md'), "# Dominio: $Title$([Environment]::NewLine)" + $agentTemplate.Substring($agentTemplate.IndexOf([Environment]::NewLine) + [Environment]::NewLine.Length))
        Copy-Item -LiteralPath (Join-Path $layout 'domain-INDEX.md') -Destination (Join-Path $temporaryPath 'INDEX.md')
        Move-Item -LiteralPath $temporaryPath -Destination $domainPath
    }
    catch {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Recurse -Force -ErrorAction SilentlyContinue }
        throw "error: no se pudo crear el dominio: $domainId. $($_.Exception.Message)"
    }
}
function Test-Vault {
    if (-not (Test-LocalFile (Join-Path $Vault 'AGENTS.md'))) { Fail 'falta archivo local vault/AGENTS.md' }
    if (Test-Path -LiteralPath (Join-Path $Vault 'INDEX.md')) { Fail 'INDEX.md raíz heredado; archívalo antes de validar formato 3' }
    foreach ($directory in @('00_inbox','10_areas','20_domains','30_resources','40_archive','50_daily','60_exports','_indexes','_maps','_templates')) { if (-not (Test-LocalDirectory (Join-Path $Vault $directory))) { Fail "falta directorio local: $directory" } }
    foreach ($file in @('_indexes/INDEX.md','_indexes/action-log.md','_maps/INDEX.md')) { if (-not (Test-LocalFile (Join-Path $Vault $file))) { Fail "falta archivo canónico local: $file" } }
    foreach ($file in @('domain.yml','domain-AGENTS.md','domain-INDEX.md','area.md','daily.md','pending-decision.md','export.md')) { if (-not (Test-LocalFile (Join-Path $Vault "_templates/$file"))) { Fail "falta plantilla canónica local: $file" } }
    $ids = @{}
    Get-ChildItem -LiteralPath (Join-Path $Vault '20_domains') -Force | ForEach-Object {
        $domain = $_.FullName
        if (-not (Test-LocalDirectory $domain)) { Fail "dominio inválido: $domain" }
        foreach ($needed in @('domain.yml','AGENTS.md','INDEX.md')) { if (-not (Test-LocalFile (Join-Path $domain $needed))) { Fail "paquete incompleto: $($_.Name)" } }
        foreach ($needed in @('records','resources')) { if (-not (Test-LocalDirectory (Join-Path $domain $needed))) { Fail "paquete incompleto: $($_.Name)" } }
        $raw = Get-Content -LiteralPath (Join-Path $domain 'domain.yml') -Raw
        $domainId = ([regex]::Match($raw, '(?m)^id:\s*(.+)$')).Groups[1].Value.Trim()
        $format = ([regex]::Match($raw, '(?m)^format:\s*(.+)$')).Groups[1].Value.Trim()
        $title = ([regex]::Match($raw, '(?m)^title:\s*(.+)$')).Groups[1].Value.Trim()
        $status = ([regex]::Match($raw, '(?m)^status:\s*(.+)$')).Groups[1].Value.Trim()
        $scope = ([regex]::Match($raw, '(?m)^scope:\s*(.+)$')).Groups[1].Value.Trim()
        if (-not (Test-ValidId $domainId) -or $_.Name -ne $domainId) { Fail "id inválido: $domain" }
        if ($format -ne '1' -or [string]::IsNullOrWhiteSpace($title) -or [string]::IsNullOrWhiteSpace($scope) -or ($raw -notmatch '(?m)^areas: \[\]\r?$' -and $raw -notmatch '(?ms)^areas:\r?\n  - ') -or $status -notin @('active','archived')) { Fail "metadata incompleta: $domainId" }
        if ($ids.ContainsKey($domainId)) { Fail "id duplicado: $domainId" }; $ids[$domainId] = $true
        if ($raw -notmatch '(?m)^routing:\r?$' -or $raw -notmatch '(?m)^  rules: \[\]\r?$') { Fail "routing no determinista o inválido: $domainId" }
    }
}
function New-MigrationPlan {
    Initialize-Layout
    $records = Join-Path $Vault 'records'
    if (-not (Test-Path -LiteralPath $records)) { return }
    if (-not (Test-LocalDirectory $records)) { Fail "records/ no es un directorio local: $records" }
    $recordItems = @(Get-ChildItem -LiteralPath $records -Force | Where-Object { $_.Name -like '*.md' })
    foreach ($record in $recordItems) {
        if (-not (Test-LocalFile $record.FullName)) { Fail "registro raíz no es un archivo local: $($record.FullName)" }
        $pending = Join-Path $Vault "00_inbox/decisions-pending/$($record.BaseName).md"
        if (Test-Path -LiteralPath $pending) { if (-not (Test-LocalFile $pending)) { Fail "la propuesta existente no es un archivo local: $pending" }; continue }
    }
    $planDirectory = Join-Path (Join-Path $Vault '00_inbox') ('.pending-plan.' + [guid]::NewGuid())
    $published = @()
    try {
        [System.IO.Directory]::CreateDirectory($planDirectory) | Out-Null
        foreach ($record in $recordItems) {
            $pending = Join-Path $Vault "00_inbox/decisions-pending/$($record.BaseName).md"
            if (Test-Path -LiteralPath $pending) { continue }
            $staged = Join-Path $planDirectory "$($record.BaseName).md"
            $template = Get-Content -LiteralPath (Join-Path $layout 'pending-decision.md') -Raw
            $body = $template.Substring($template.IndexOf('# Decisión pendiente'))
            $content = "---$([Environment]::NewLine)id: $(ConvertTo-YamlQuoted $record.BaseName)$([Environment]::NewLine)status: pending$([Environment]::NewLine)source: $(ConvertTo-YamlQuoted "records/$($record.Name)")$([Environment]::NewLine)proposed_domain: null$([Environment]::NewLine)created: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd'))$([Environment]::NewLine)---$([Environment]::NewLine)$([Environment]::NewLine)$body"
            [System.IO.File]::WriteAllText($staged, $content)
        }
        Get-ChildItem -LiteralPath $planDirectory -File | ForEach-Object {
            $destination = Join-Path $Vault "00_inbox/decisions-pending/$($_.Name)"
            Move-Item -LiteralPath $_.FullName -Destination $destination
            $published += $destination
        }
    }
    catch {
        foreach ($destination in $published) { if (Test-Path -LiteralPath $destination) { Move-Item -LiteralPath $destination -Destination $planDirectory -ErrorAction SilentlyContinue } }
        throw
    }
    finally {
        if (Test-Path -LiteralPath $planDirectory) { Remove-Item -LiteralPath $planDirectory -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
function Invoke-MigrationApply {
    $domainId = if ($Domain) { $Domain } else { $Id }
    if (-not (Test-ValidId $domainId)) { Fail '--domain inválido' }
    if ([string]::IsNullOrWhiteSpace($Record)) { Fail '--record es obligatorio' }
    if ($Record -notmatch '^[^/\\]+\.md$') { Fail '--record debe ser el nombre de un archivo Markdown sin rutas' }
    $source = Join-Path $Vault "records/$Record"
    $destination = Join-Path $Vault "20_domains/$domainId/records/$Record"
    if (-not (Test-LocalFile $source)) { Fail "registro raíz inexistente o no local: $Record" }
    if (-not (Test-Path -LiteralPath (Split-Path $destination) -PathType Container)) { Fail "dominio inexistente: $domainId" }
    if (Test-Path -LiteralPath $destination) { Fail "destino existente: $destination" }
    $actionLog = Join-Path $Vault '_indexes/action-log.md'
    if (-not (Test-LocalFile $actionLog)) { Fail "falta el registro de acciones local: $actionLog" }
    Move-Item -LiteralPath $source -Destination $destination
    try {
        "$((Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")) | migration-apply | $domainId | records/$Record | 20_domains/$domainId/records/$Record | operator" | Add-Content -LiteralPath $actionLog
    }
    catch {
        try {
            Move-Item -LiteralPath $destination -Destination $source
        }
        catch {
            throw "no se pudo registrar la migración y la reversión también falló: $Record. $($_.Exception.Message)"
        }
        throw "no se pudo registrar la migración; el movimiento fue revertido: $Record"
    }
}
switch ($Command) {
    'init-layout' { Initialize-Layout }
    'create-domain' { New-Domain }
    'check' { Test-Vault }
    'migration-plan' { New-MigrationPlan }
    'migration-apply' { Invoke-MigrationApply }
}
