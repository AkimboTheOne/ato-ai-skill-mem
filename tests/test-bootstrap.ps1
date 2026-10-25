$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('ato-ai-skill-mem-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $project = Join-Path $temp 'consumer'
    New-Item -ItemType Directory -Path $project | Out-Null
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project
    $vault = Join-Path $project 'mem/vault'
    if (-not ((Get-Item -LiteralPath (Join-Path $project 'mem/VAULT_FORMAT') -Force).LinkType -eq 'SymbolicLink')) { throw 'VAULT_FORMAT debe ser un enlace simbólico' }
    foreach ($path in @('AGENTS.md','00_inbox/decisions-pending','20_domains','_templates')) { if (-not (Test-Path (Join-Path $vault $path))) { throw "falta $path" } }
    if ((Get-Content (Join-Path $vault '.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 3$') { throw 'formato incorrecto' }
    & (Join-Path $root 'scripts/vault.ps1') check -Vault $vault
    & (Join-Path $root 'scripts/vault.ps1') create-domain -Vault $vault -Id alpha -Title Alpha
    if (-not (Test-Path (Join-Path $vault '20_domains/alpha/domain.yml'))) { throw 'dominio ausente' }
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
    New-Item -ItemType Directory -Path (Join-Path $vault 'records') | Out-Null
    '# Legacy record' | Set-Content (Join-Path $vault 'records/2026-10-25--legacy.md')
    & (Join-Path $root 'scripts/vault.ps1') migration-plan -Vault $vault
    if (-not (Test-Path (Join-Path $vault '00_inbox/decisions-pending/2026-10-25--legacy.md'))) { throw 'propuesta pendiente ausente' }
    & (Join-Path $root 'scripts/vault.ps1') migration-apply -Vault $vault -Domain alpha -Record '2026-10-25--legacy.md'
    if (-not (Test-Path (Join-Path $vault '20_domains/alpha/records/2026-10-25--legacy.md'))) { throw 'registro no migrado' }
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
    if ((Get-Content (Join-Path $migrationVault '.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 2$') { throw 'el manifiesto cambió antes de finalizar' }
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
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $migrationProject -MigrateVaultFormat -Finalize
    if ((Get-Content (Join-Path $migrationVault '.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 3$') { throw 'el manifiesto no llegó al formato 3' }
    if (Test-Path (Join-Path $migrationVault 'INDEX.md')) { throw 'el índice legado no fue archivado' }
    if ((Get-FileHash (Join-Path $temp 'legacy-index.expected')).Hash -ne (Get-FileHash (Join-Path $migrationVault '40_archive/legacy-root-INDEX.md')).Hash) { throw 'el índice legado cambió durante el archivado' }
    & (Join-Path $root 'scripts/vault.ps1') check -Vault $migrationVault

    $conflictProject = Join-Path $temp 'conflict-consumer'
    $conflictVault = Join-Path $conflictProject 'mem/vault'
    New-Item -ItemType Directory -Path (Join-Path $conflictVault '40_archive') -Force | Out-Null
    @('format: 1','vault_kind: consumer','vault_format: 2','skill_version: 0.2.0','source_revision: old','source_tag: v0.2.0','created_at: 2026-01-01','updated_at: 2026-01-01') | Set-Content (Join-Path $conflictVault '.ato-ai-skill-mem-version.yml')
    '# Índice legado' | Set-Content (Join-Path $conflictVault 'INDEX.md')
    '# Archivo existente' | Set-Content (Join-Path $conflictVault '40_archive/legacy-root-INDEX.md')
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $conflictProject -MigrateVaultFormat -Finalize
        throw 'la finalización debía rechazar un archivo de archivo existente'
    }
    catch {
        if ($_.Exception.Message -eq 'la finalización debía rechazar un archivo de archivo existente') { throw }
    }
    if ((Get-Content (Join-Path $conflictVault '.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 2$') { throw 'el manifiesto cambió tras un conflicto' }
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
    Write-Output 'pruebas de bootstrap y vault PowerShell superadas'
}
finally { if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
