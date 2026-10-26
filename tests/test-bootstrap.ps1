$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('ato-ai-skill-mem-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $project = Join-Path $temp 'consumer'
    New-Item -ItemType Directory -Path $project | Out-Null
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -IntegrateCodex
    $vault = Join-Path $project 'mem/vault'
    if (-not ((Get-Item -LiteralPath (Join-Path $project 'mem/VAULT_FORMAT') -Force).LinkType -eq 'SymbolicLink')) { throw 'VAULT_FORMAT debe ser un enlace simbólico' }
    $consumerAdapter = Get-Content -LiteralPath (Join-Path $project '.agents/skills/ato-ai-project-mem/SKILL.md') -Raw
    if ($consumerAdapter -notmatch 'mem/vault/' -or $consumerAdapter -notmatch 'mem/SKILL\.md' -or $consumerAdapter -match '--target \.') { throw 'el adaptador consumidor no conserva rutas y autoridad canónicas' }
    foreach ($path in @('AGENTS.md','00_inbox/decisions-pending','20_domains','_templates')) { if (-not (Test-Path (Join-Path $vault $path))) { throw "falta $path" } }
    if ((Get-Content (Join-Path $vault '.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 3\r?$') { throw 'formato incorrecto' }
    & (Join-Path $root 'scripts/vault.ps1') check -Vault $vault
    & (Join-Path $root 'scripts/vault.ps1') create-domain -Vault $vault -Id alpha -Title Alpha
    if (-not (Test-Path (Join-Path $vault '20_domains/alpha/domain.yml'))) { throw 'dominio ausente' }
    $alphaDomainFile = Join-Path $vault '20_domains/alpha/domain.yml'
    $alphaDomainText = (Get-Content -LiteralPath $alphaDomainFile -Raw) -replace "(?<!`r)`n", "`r`n"
    [System.IO.File]::WriteAllText($alphaDomainFile, $alphaDomainText)
    foreach ($invalidId in @('Alpha', 'API-Gateway')) {
        try {
            & (Join-Path $root 'scripts/vault.ps1') create-domain -Vault $vault -Id $invalidId -Title Invalid
            throw "create-domain debía rechazar ID con mayúsculas: $invalidId"
        }
        catch {
            if ($_.Exception.Message -eq "create-domain debía rechazar ID con mayúsculas: $invalidId") { throw }
        }
        if (@(Get-ChildItem -LiteralPath (Join-Path $vault '20_domains') -Force | Where-Object { $_.Name -ceq $invalidId }).Count -gt 0) { throw "quedó un dominio inválido: $invalidId" }
    }
    & (Join-Path $root 'scripts/vault.ps1') check -Vault $vault
    Copy-Item -LiteralPath (Join-Path $vault '20_domains/alpha/domain.yml') -Destination (Join-Path $vault '20_domains/alpha/domain.yml.saved')
    (Get-Content -LiteralPath (Join-Path $vault '20_domains/alpha/domain.yml.saved') | Where-Object { $_ -notmatch '^scope:' }) | Set-Content (Join-Path $vault '20_domains/alpha/domain.yml')
    try {
        & (Join-Path $root 'scripts/vault.ps1') check -Vault $vault
        throw 'check debía rechazar metadata incompleta'
    }
    catch {
        if ($_.Exception.Message -eq 'check debía rechazar metadata incompleta') { throw }
    }
    Move-Item -LiteralPath (Join-Path $vault '20_domains/alpha/domain.yml.saved') -Destination (Join-Path $vault '20_domains/alpha/domain.yml') -Force
    '# Índice raíz inválido' | Set-Content (Join-Path $vault 'INDEX.md')
    try {
        & (Join-Path $root 'scripts/vault.ps1') check -Vault $vault
        throw 'check debía rechazar INDEX.md en raíz'
    }
    catch {
        if ($_.Exception.Message -eq 'check debía rechazar INDEX.md en raíz') { throw }
    }
    Remove-Item -LiteralPath (Join-Path $vault 'INDEX.md') -Force
    & (Join-Path $root 'scripts/vault.ps1') create-domain -Vault $vault -Id api-gateway -Title 'Arquitectura: "R&D/Platform"'
    if ((Get-Content (Join-Path $vault '20_domains/api-gateway/domain.yml') -Raw) -notlike '*title: "Arquitectura: \"R&D/Platform\""*') { throw 'título de dominio incorrecto' }
    try {
        & (Join-Path $root 'scripts/vault.ps1') create-domain -Vault $vault -Id multilinea -Title "primera`nsegunda"
        throw 'el título multilínea debía fallar'
    }
    catch {
        if ($_.Exception.Message -eq 'el título multilínea debía fallar') { throw }
    }
    if (Test-Path (Join-Path $vault '20_domains/multilinea')) { throw 'quedó un dominio parcial' }
    foreach ($titleCase in @(@('empty-title',''), @('blank-title','   '))) {
        try {
            & (Join-Path $root 'scripts/vault.ps1') create-domain -Vault $vault -Id $titleCase[0] -Title $titleCase[1]
            throw "create-domain debía rechazar title $($titleCase[0])"
        }
        catch {
            if ($_.Exception.Message -eq "create-domain debía rechazar title $($titleCase[0])") { throw }
        }
        if (Test-Path (Join-Path $vault "20_domains/$($titleCase[0])")) { throw 'se creó un paquete con título vacío' }
    }
    Set-Content -LiteralPath (Join-Path $vault '20_domains/.unexpected') -Value 'unexpected'
    try { & (Join-Path $root 'scripts/vault.ps1') check -Vault $vault; throw 'check debía rechazar entrada oculta' }
    catch { if ($_.Exception.Message -eq 'check debía rechazar entrada oculta') { throw } }
    Remove-Item -LiteralPath (Join-Path $vault '20_domains/.unexpected') -Force
    Set-Content -LiteralPath (Join-Path $vault '20_domains/unexpected.md') -Value 'unexpected'
    try { & (Join-Path $root 'scripts/vault.ps1') check -Vault $vault; throw 'check debía rechazar archivo en domains' }
    catch { if ($_.Exception.Message -eq 'check debía rechazar archivo en domains') { throw } }
    Remove-Item -LiteralPath (Join-Path $vault '20_domains/unexpected.md') -Force
    New-Item -ItemType Directory -Path (Join-Path $vault '20_domains/.temporary') | Out-Null
    try { & (Join-Path $root 'scripts/vault.ps1') check -Vault $vault; throw 'check debía rechazar paquete temporal' }
    catch { if ($_.Exception.Message -eq 'check debía rechazar paquete temporal') { throw } }
    Remove-Item -LiteralPath (Join-Path $vault '20_domains/.temporary') -Force
    New-Item -ItemType SymbolicLink -Path (Join-Path $vault '20_domains/linked-domain') -Target (Join-Path $vault '20_domains/alpha') | Out-Null
    try { & (Join-Path $root 'scripts/vault.ps1') check -Vault $vault; throw 'check debía rechazar dominio simbólico' }
    catch { if ($_.Exception.Message -eq 'check debía rechazar dominio simbólico') { throw } }
    Remove-Item -LiteralPath (Join-Path $vault '20_domains/linked-domain') -Force
    New-Item -ItemType Directory -Path (Join-Path $vault 'records') | Out-Null
    '# Legacy record' | Set-Content (Join-Path $vault 'records/2026-10-25--legacy.md')
    & (Join-Path $root 'scripts/vault.ps1') migration-plan -Vault $vault
    if (-not (Test-Path (Join-Path $vault '00_inbox/decisions-pending/2026-10-25--legacy.md'))) { throw 'propuesta pendiente ausente' }
    & (Join-Path $root 'scripts/vault.ps1') migration-apply -Vault $vault -Domain alpha -Record '2026-10-25--legacy.md'
    if (-not (Test-Path (Join-Path $vault '20_domains/alpha/records/2026-10-25--legacy.md'))) { throw 'registro no migrado' }
    if ((Get-Content (Join-Path $vault '_indexes/action-log.md') -Raw) -notmatch '(?m)^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z \| migration-apply') { throw 'el action log no usa UTC ISO-8601' }
    '# Protected root file' | Set-Content (Join-Path $vault 'guard.md')
    try {
        & (Join-Path $root 'scripts/vault.ps1') migration-apply -Vault $vault -Domain alpha -Record '../guard.md'
        throw 'la migración debía rechazar rutas en --record'
    }
    catch {
        if ($_.Exception.Message -eq 'la migración debía rechazar rutas en --record') { throw }
    }
    if (-not (Test-Path (Join-Path $vault 'guard.md'))) { throw 'se movió un archivo fuera de records' }
    if (Test-Path (Join-Path $vault '20_domains/alpha/guard.md')) { throw 'se escribió fuera de records del dominio' }
    '# Symlink source' | Set-Content (Join-Path $temp 'outside-record.md')
    New-Item -ItemType SymbolicLink -Path (Join-Path $vault 'records/linked.md') -Target (Join-Path $temp 'outside-record.md') | Out-Null
    try { & (Join-Path $root 'scripts/vault.ps1') migration-apply -Vault $vault -Domain alpha -Record linked.md; throw 'migration-apply debía rechazar registro simbólico' }
    catch { if ($_.Exception.Message -eq 'migration-apply debía rechazar registro simbólico') { throw } }
    if (-not (Test-Path (Join-Path $vault 'records/linked.md')) -or (Test-Path (Join-Path $vault '20_domains/alpha/records/linked.md'))) { throw 'el symlink raíz se movió' }
    Remove-Item -LiteralPath (Join-Path $vault 'records/linked.md') -Force
    '# Rollback record' | Set-Content (Join-Path $vault 'records/2026-10-25--rollback.md')
    Move-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md') -Destination (Join-Path $vault '_indexes/action-log.md.saved')
    New-Item -ItemType Directory -Path (Join-Path $vault '_indexes/action-log.md') | Out-Null
    try {
        & (Join-Path $root 'scripts/vault.ps1') migration-apply -Vault $vault -Domain alpha -Record '2026-10-25--rollback.md'
        throw 'la migración debía fallar si el log no está disponible'
    }
    catch {
        if ($_.Exception.Message -eq 'la migración debía fallar si el log no está disponible') { throw }
    }
    if (-not (Test-Path (Join-Path $vault 'records/2026-10-25--rollback.md'))) { throw 'el registro no fue revertido' }
    if (Test-Path (Join-Path $vault '20_domains/alpha/records/2026-10-25--rollback.md')) { throw 'el destino quedó tras un rollback' }
    Remove-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md') -Recurse -Force
    Move-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md.saved') -Destination (Join-Path $vault '_indexes/action-log.md')
    '# Log symlink record' | Set-Content (Join-Path $vault 'records/2026-10-25--log-link.md')
    Move-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md') -Destination (Join-Path $vault '_indexes/action-log.md.saved')
    New-Item -ItemType SymbolicLink -Path (Join-Path $vault '_indexes/action-log.md') -Target (Join-Path $vault '_indexes/action-log.md.saved') | Out-Null
    try { & (Join-Path $root 'scripts/vault.ps1') migration-apply -Vault $vault -Domain alpha -Record '2026-10-25--log-link.md'; throw 'migration-apply debía rechazar action log simbólico' }
    catch { if ($_.Exception.Message -eq 'migration-apply debía rechazar action log simbólico') { throw } }
    if (-not (Test-Path (Join-Path $vault 'records/2026-10-25--log-link.md')) -or (Test-Path (Join-Path $vault '20_domains/alpha/records/2026-10-25--log-link.md'))) { throw 'el registro no se conservó ante action log simbólico' }
    Remove-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md') -Force
    Move-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md.saved') -Destination (Join-Path $vault '_indexes/action-log.md')
    Move-Item -LiteralPath (Join-Path $vault '_maps/INDEX.md') -Destination (Join-Path $vault '_maps/INDEX.md.saved')
    New-Item -ItemType SymbolicLink -Path (Join-Path $vault '_maps/INDEX.md') -Target (Join-Path $vault '_maps/INDEX.md.saved') | Out-Null
    try {
        & (Join-Path $root 'scripts/vault.ps1') check -Vault $vault
        throw 'check debía rechazar un enlace simbólico canónico'
    }
    catch {
        if ($_.Exception.Message -eq 'check debía rechazar un enlace simbólico canónico') { throw }
    }
    Remove-Item -LiteralPath (Join-Path $vault '_maps/INDEX.md') -Force
    Move-Item -LiteralPath (Join-Path $vault '_maps/INDEX.md.saved') -Destination (Join-Path $vault '_maps/INDEX.md')
    Move-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md') -Destination (Join-Path $vault '_indexes/action-log.md.saved')
    New-Item -ItemType Directory -Path (Join-Path $vault '_indexes/action-log.md') | Out-Null
    try {
        & (Join-Path $root 'scripts/vault.ps1') check -Vault $vault
        throw 'check debía rechazar un archivo canónico convertido en directorio'
    }
    catch {
        if ($_.Exception.Message -eq 'check debía rechazar un archivo canónico convertido en directorio') { throw }
    }
    Remove-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md') -Recurse -Force
    Move-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md.saved') -Destination (Join-Path $vault '_indexes/action-log.md')

    $migrationProject = Join-Path $temp 'migration-consumer'
    $migrationVault = Join-Path $migrationProject 'mem/vault'
    New-Item -ItemType Directory -Path (Join-Path $migrationVault 'records') -Force | Out-Null
    @('format: 1','vault_kind: consumer','vault_format: 2','skill_version: 0.2.0','source_revision: old','source_tag: v0.2.0','created_at: 2026-01-01','updated_at: 2026-01-01') | Set-Content (Join-Path $migrationVault '.ato-ai-skill-mem-version.yml')
    '# Índice legado' | Set-Content (Join-Path $migrationVault 'INDEX.md')
    Copy-Item -LiteralPath (Join-Path $migrationVault 'INDEX.md') -Destination (Join-Path $temp 'legacy-index.expected')
    '# Registro legado' | Set-Content (Join-Path $migrationVault 'records/2026-01-01--legacy&record.md')
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $migrationProject -MigrateVaultFormat
    if ((Get-Content (Join-Path $migrationVault '.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 2\r?$') { throw 'el manifiesto cambió antes de finalizar' }
    if (-not (Test-Path (Join-Path $migrationVault '00_inbox/decisions-pending/2026-01-01--legacy&record.md'))) { throw 'propuesta con carácter especial ausente' }
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $migrationProject -MigrateVaultFormat -Finalize
        throw 'la finalización debía rechazar registros raíz pendientes'
    }
    catch {
        if ($_.Exception.Message -eq 'la finalización debía rechazar registros raíz pendientes') { throw }
    }
    if (-not (Test-Path (Join-Path $migrationVault 'INDEX.md'))) { throw 'el índice se movió antes de finalizar' }
    & (Join-Path $root 'scripts/vault.ps1') create-domain -Vault $migrationVault -Id migrated -Title Migrated
    & (Join-Path $root 'scripts/vault.ps1') migration-apply -Vault $migrationVault -Domain migrated -Record '2026-01-01--legacy&record.md'
    'contenido no Markdown' | Set-Content (Join-Path $migrationVault 'records/legacy.txt')
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $migrationProject -MigrateVaultFormat -Finalize
        throw 'la finalización debía rechazar contenido no Markdown'
    }
    catch {
        if ($_.Exception.Message -eq 'la finalización debía rechazar contenido no Markdown') { throw }
    }
    if ((Get-Content (Join-Path $migrationVault '.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 2\r?$') { throw 'el manifiesto cambió con contenido pendiente' }
    if (-not (Test-Path (Join-Path $migrationVault 'INDEX.md'))) { throw 'el índice cambió con contenido pendiente' }
    Remove-Item -LiteralPath (Join-Path $migrationVault 'records/legacy.txt') -Force
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $migrationProject -MigrateVaultFormat -Finalize
    if ((Get-Content (Join-Path $migrationVault '.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 3\r?$') { throw 'el manifiesto no llegó al formato 3' }
    if (Test-Path (Join-Path $migrationVault 'INDEX.md')) { throw 'el índice legado no fue archivado' }
    if ((Get-FileHash (Join-Path $temp 'legacy-index.expected')).Hash -ne (Get-FileHash (Join-Path $migrationVault '40_archive/legacy-root-INDEX.md')).Hash) { throw 'el índice legado cambió durante el archivado' }
    & (Join-Path $root 'scripts/vault.ps1') check -Vault $migrationVault

    $conflictProject = Join-Path $temp 'conflict-consumer'
    $conflictVault = Join-Path $conflictProject 'mem/vault'
    New-Item -ItemType Directory -Path (Join-Path $conflictVault '40_archive') -Force | Out-Null
    @('format: 1','vault_kind: consumer','vault_format: 2','skill_version: 0.2.0','source_revision: old','source_tag: v0.2.0','created_at: 2026-01-01','updated_at: 2026-01-01') | Set-Content (Join-Path $conflictVault '.ato-ai-skill-mem-version.yml')
    '# Índice legado' | Set-Content (Join-Path $conflictVault 'INDEX.md')
    '# Archivo existente' | Set-Content (Join-Path $conflictVault '40_archive/legacy-root-INDEX.md')
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $conflictProject -MigrateVaultFormat
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $conflictProject -MigrateVaultFormat -Finalize
        throw 'la finalización debía rechazar un archivo de archivo existente'
    }
    catch {
        if ($_.Exception.Message -eq 'la finalización debía rechazar un archivo de archivo existente') { throw }
    }
    if ((Get-Content (Join-Path $conflictVault '.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 2\r?$') { throw 'el manifiesto cambió tras un conflicto' }
    if (-not (Test-Path (Join-Path $conflictVault 'INDEX.md'))) { throw 'el índice cambió tras un conflicto' }

    $ambiguousProject = Join-Path $temp 'ambiguous-consumer'
    $ambiguousVault = Join-Path $ambiguousProject 'mem/vault'
    New-Item -ItemType Directory -Path $ambiguousVault -Force | Out-Null
    @('format: 1','vault_kind: consumer','vault_format: 2','vault_format: 2','skill_version: 0.2.0','created_at: 2026-01-01') | Set-Content (Join-Path $ambiguousVault '.ato-ai-skill-mem-version.yml')
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $ambiguousProject -MigrateVaultFormat
        throw 'la migración debía rechazar un manifiesto ambiguo'
    }
    catch {
        if ($_.Exception.Message -eq 'la migración debía rechazar un manifiesto ambiguo') { throw }
    }
    if (Test-Path (Join-Path $ambiguousVault 'AGENTS.md')) { throw 'un manifiesto ambiguo modificó el layout' }

    $incompleteProject = Join-Path $temp 'incomplete-consumer'
    $incompleteVault = Join-Path $incompleteProject 'mem/vault'
    New-Item -ItemType Directory -Path $incompleteVault -Force | Out-Null
    @('format: 1','vault_kind: consumer','vault_format: 2','skill_version: 0.2.0','created_at: 2026-01-01') | Set-Content (Join-Path $incompleteVault '.ato-ai-skill-mem-version.yml')
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $incompleteProject -MigrateVaultFormat -Finalize
        throw 'la finalización debía rechazar un layout no preparado'
    }
    catch {
        if ($_.Exception.Message -eq 'la finalización debía rechazar un layout no preparado') { throw }
    }
    if (Test-Path (Join-Path $incompleteVault 'AGENTS.md')) { throw 'la finalización creó un layout no preparado' }

    $planVault = Join-Path $temp 'plan-vault'
    New-Item -ItemType Directory -Path (Join-Path $planVault 'records') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $planVault '00_inbox/decisions-pending/z-conflict.md') -Force | Out-Null
    '# Nuevo' | Set-Content (Join-Path $planVault 'records/a-new.md')
    '# Conflicto' | Set-Content (Join-Path $planVault 'records/z-conflict.md')
    try {
        & (Join-Path $root 'scripts/vault.ps1') migration-plan -Vault $planVault
        throw 'el plan debía rechazar una propuesta no regular'
    }
    catch {
        if ($_.Exception.Message -eq 'el plan debía rechazar una propuesta no regular') { throw }
    }
    if (Test-Path (Join-Path $planVault '00_inbox/decisions-pending/a-new.md')) { throw 'el plan publicó propuestas parciales' }
    $planLinkVault = Join-Path $temp 'plan-link-vault'
    New-Item -ItemType Directory -Path (Join-Path $planLinkVault 'records') -Force | Out-Null
    '# Regular' | Set-Content (Join-Path $planLinkVault 'records/a-regular.md')
    New-Item -ItemType SymbolicLink -Path (Join-Path $planLinkVault 'records/z-linked.md') -Target (Join-Path $temp 'outside-record.md') | Out-Null
    try { & (Join-Path $root 'scripts/vault.ps1') migration-plan -Vault $planLinkVault; throw 'migration-plan debía rechazar registro simbólico' }
    catch { if ($_.Exception.Message -eq 'migration-plan debía rechazar registro simbólico') { throw } }
    if (Test-Path (Join-Path $planLinkVault '00_inbox/decisions-pending/a-regular.md')) { throw 'migration-plan publicó propuestas antes del rechazo' }
    Write-Output 'pruebas de bootstrap y vault PowerShell superadas'
}
finally { if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
