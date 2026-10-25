$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('ato-ai-skill-mem-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $project = Join-Path $temp 'consumer'
    New-Item -ItemType Directory -Path $project | Out-Null
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project
    if (-not (Test-Path (Join-Path $project 'mem/vault/INDEX.md'))) { throw 'falta el índice del vault' }
    $marker = Get-Content (Join-Path $project 'mem/vault/.ato-ai-skill-mem-version.yml') -Raw
    if ($marker -notmatch '(?m)^vault_format: 2$') { throw 'falta el formato del vault' }
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -IntegrateCodex
    if ((Get-Content (Join-Path $project '.ato-ai-skill-mem.yml') -Raw) -notmatch 'mem/vault') { throw 'la integración no apunta al vault' }

    $legacy = Join-Path $temp 'legacy'
    New-Item -ItemType Directory -Path (Join-Path $legacy 'mem/workspace/records') -Force | Out-Null
    $legacyIndex = Join-Path $legacy 'mem/workspace/INDEX.md'
    [System.IO.File]::WriteAllText($legacyIndex, "# Legacy memory`nLínea preservada`n", [System.Text.UTF8Encoding]::new($false))
    $legacyIndexHash = (Get-FileHash $legacyIndex).Hash
    'record' | Set-Content (Join-Path $legacy 'mem/workspace/records/one.md')
    @('format: 1','workspace_kind: consumer','workspace_format: 1','skill_version: 0.1.0','created_at: 2025-01-01') | Set-Content (Join-Path $legacy 'mem/workspace/.ato-ai-skill-mem-version.yml')
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $legacy -MigrateWorkspaceToVault
    if (Test-Path (Join-Path $legacy 'mem/workspace')) { throw 'la ruta heredada no fue migrada' }
    if (-not (Test-Path (Join-Path $legacy 'mem/vault/INDEX.md'))) { throw 'falta el vault migrado' }
    if ((Get-FileHash (Join-Path $legacy 'mem/vault/INDEX.md')).Hash -ne $legacyIndexHash) { throw 'el índice no fue preservado' }
    if (-not (Test-Path (Join-Path $legacy 'mem/vault/records/one.md'))) { throw 'los records no fueron preservados' }
    if ((Get-Content (Join-Path $legacy 'mem/vault/.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 2$') { throw 'el manifiesto no fue actualizado' }

    $conflict = Join-Path $temp 'conflict'
    New-Item -ItemType Directory -Path (Join-Path $conflict 'mem/workspace') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $conflict 'mem/vault') -Force | Out-Null
    @('format: 1','workspace_kind: consumer','workspace_format: 1') | Set-Content (Join-Path $conflict 'mem/workspace/.ato-ai-skill-mem-version.yml')
    try { & (Join-Path $root 'scripts/bootstrap.ps1') -Target $conflict -MigrateWorkspaceToVault; throw 'aceptó un destino conflictivo' } catch { if ($_.Exception.Message -eq 'aceptó un destino conflictivo') { throw } }
    if (-not (Test-Path (Join-Path $conflict 'mem/workspace/.ato-ai-skill-mem-version.yml'))) { throw 'el conflicto modificó el origen' }

    $sourceFixture = Join-Path $temp 'source-fixture'
    Copy-Item -LiteralPath $root -Destination $sourceFixture -Recurse
    Move-Item -LiteralPath (Join-Path $sourceFixture 'vault') -Destination (Join-Path $sourceFixture 'workspace')
    @('format: 1','workspace_kind: source','workspace_format: 1','skill_version: 0.1.0','created_at: unknown') | Set-Content (Join-Path $sourceFixture 'workspace/.ato-ai-skill-mem-version.yml')
    & (Join-Path $sourceFixture 'scripts/bootstrap.ps1') -MigrateSourceWorkspaceToVault
    if ((Test-Path (Join-Path $sourceFixture 'workspace')) -or -not (Test-Path (Join-Path $sourceFixture 'vault/.ato-ai-skill-mem-version.yml'))) { throw 'el vault fuente no fue migrado' }

    $scriptText = Get-Content (Join-Path $root 'scripts/bootstrap.ps1') -Raw
    if ($scriptText.IndexOf('Write-Marker $oldCreated $markerTemp') -gt $scriptText.IndexOf('Move-Item -LiteralPath $legacyWorkspace -Destination $workspace')) { throw 'el manifiesto no se prepara antes del movimiento' }
    if ($scriptText -notmatch 'la migración fue revertida' -or $scriptText -notmatch 'Move-Item -LiteralPath \$workspace -Destination \$legacyWorkspace') { throw 'falta el rollback PowerShell' }
    $status = & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -Status | Out-String
    if ($status -notmatch 'vault\.state: aligned' -or $status -match 'workspace\.state') { throw 'el diagnóstico conserva vocabulario operativo antiguo' }
    Write-Output 'pruebas de bootstrap PowerShell superadas'
}
finally { if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
