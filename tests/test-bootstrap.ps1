$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$skillVersion = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('ato-ai-skill-mem-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $contract = Join-Path $root 'tests/fixtures/bootstrap-contract.tsv'
    function Get-ContractAssertions([string]$Scenario) {
        $line = Get-Content -LiteralPath $contract | Where-Object { $_ -and -not $_.StartsWith('#') -and ($_ -split "`t")[0] -eq $Scenario } | Select-Object -First 1
        if ($null -eq $line) { throw "escenario contractual ausente: $Scenario" }
        return (($line -split "`t")[2]).Split(';')
    }
    function Get-ContractExit([string]$Scenario) {
        $line = Get-Content -LiteralPath $contract | Where-Object { $_ -and -not $_.StartsWith('#') -and ($_ -split "`t")[0] -eq $Scenario } | Select-Object -First 1
        if ($null -eq $line) { throw "escenario contractual ausente: $Scenario" }
        return [int](($line -split "`t")[1])
    }
    function Invoke-Contract([string]$Scenario, [scriptblock]$Command) {
        $expectedExit = Get-ContractExit $Scenario
        $actualExit = 0
        try { $output = (& $Command) -join "`n" }
        catch { $output = $_.Exception.Message; $actualExit = 1 }
        if ($actualExit -ne $expectedExit) { throw "exit code incumplido ($Scenario): esperado $expectedExit, obtenido $actualExit" }
        return $output
    }
    function Assert-ContractOutput([string]$Scenario, [string]$Output) {
        foreach ($assertion in @(Get-ContractAssertions $Scenario)) {
            $parts = $assertion.Split('=', 2)
            $matched = $false
            foreach ($alternative in $parts[1].Split('|')) {
                $prefix = if ($parts[0] -eq 'error') { 'error' } else { $parts[0] }
                $expected = "$prefix`: $alternative"
                if ($Output -match "(?m)^$([regex]::Escape($expected))$") { $matched = $true; break }
            }
            if (-not $matched) { throw "contrato incumplido ($Scenario): $assertion" }
        }
    }

    $contextNewProject = Join-Path $temp 'context-new'
    New-Item -ItemType Directory -Path $contextNewProject | Out-Null
    $contextNewOutput = Invoke-Contract 'context-new' { & (Join-Path $root 'scripts/bootstrap.ps1') -Target $contextNewProject -Contextualize }
    if ($contextNewOutput -notmatch 'vault.initialization.state: new' -or $contextNewOutput -notmatch 'vault.context.wizard.phase.4: validate-and-authorize') { throw 'contextualize no reportó el estado nuevo y el wizard' }
    Assert-ContractOutput 'context-new' $contextNewOutput
    if (Test-Path (Join-Path $contextNewProject 'mem')) { throw 'contextualize creó una instancia nueva' }

    $sourceStatusOutput = Invoke-Contract 'source-status' { & (Join-Path $root 'scripts/bootstrap.ps1') -SourceStatus }
    Assert-ContractOutput 'source-status' $sourceStatusOutput
    $sourceTargetRejectedOutput = Invoke-Contract 'source-target-rejected' { & (Join-Path $root 'scripts/bootstrap.ps1') -SourceStatus -Target $root }
    Assert-ContractOutput 'source-target-rejected' $sourceTargetRejectedOutput
    & (Join-Path $root 'scripts/vault.ps1') check -Source | Out-Null
    try {
        & (Join-Path $root 'scripts/vault.ps1') check -Target $root
        throw 'vault.ps1 debía rechazar la raíz de la fuente como consumidor'
    }
    catch { if ($_.Exception.Message -eq 'vault.ps1 debía rechazar la raíz de la fuente como consumidor') { throw } }
    try {
        & (Join-Path $root 'scripts/vault.ps1') check -Source -Target $root
        throw 'vault.ps1 debía rechazar Source y Target juntos'
    }
    catch { if ($_.Exception.Message -eq 'vault.ps1 debía rechazar Source y Target juntos') { throw } }

    $stateProject = Join-Path $temp 'state-consumer'
    New-Item -ItemType Directory -Path $stateProject | Out-Null
    $stateOutput = (& (Join-Path $root 'scripts/bootstrap.ps1') -Target $stateProject -Init) -join "`n"
    if ($stateOutput -notmatch 'vault.initialization.state: new') { throw 'init no reportó una vault nueva' }
    $stateVault = Join-Path $stateProject 'mem/vault'
    $stateMarker = Join-Path $stateVault '.ato-ai-skill-mem-version.yml'
    $stateMarkerHash = (Get-FileHash -LiteralPath $stateMarker).Hash
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $stateProject -Init
        throw 'init debía rechazar una vault existente'
    }
    catch {
        if ($_.Exception.Message -eq 'init debía rechazar una vault existente') { throw }
    }
    if ((Get-FileHash -LiteralPath $stateMarker).Hash -ne $stateMarkerHash) { throw 'init modificó el manifiesto de una vault existente' }
    & (Join-Path $root 'scripts/vault.ps1') create-domain -Target $stateProject -Id context -Title Context
    $stateContextOutput = Invoke-Contract 'context-existing-ready' { & (Join-Path $root 'scripts/bootstrap.ps1') -Target $stateProject -Contextualize }
    if ($stateContextOutput -notmatch 'vault.initialization.state: existing' -or $stateContextOutput -notmatch 'vault.context.domains.total: 1') { throw 'contextualize no reportó el estado existente estructuralmente listo' }
    Assert-ContractOutput 'context-existing-ready' $stateContextOutput
    $statusMarkerHash = (Get-FileHash -LiteralPath $stateMarker).Hash
    $statusOutput = (& (Join-Path $root 'scripts/bootstrap.ps1') -Target $stateProject -Status) -join "`n"
    if ($statusOutput -notmatch 'vault.initialization.state: existing' -or (Get-FileHash -LiteralPath $stateMarker).Hash -ne $statusMarkerHash) { throw 'status modificó el manifiesto o no reportó el estado existente' }

    $project = Join-Path $temp 'consumer'
    New-Item -ItemType Directory -Path $project | Out-Null
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -IntegrateCodex
    $vault = Join-Path $project 'mem/vault'
    if (-not ((Get-Item -LiteralPath (Join-Path $project 'mem/VAULT_FORMAT') -Force).LinkType -eq 'SymbolicLink')) { throw 'VAULT_FORMAT debe ser un enlace simbólico' }
    $consumerAdapter = Get-Content -LiteralPath (Join-Path $project '.agents/skills/ato-ai-project-mem/SKILL.md') -Raw
    if ($consumerAdapter -notmatch 'mem/vault/' -or $consumerAdapter -notmatch 'mem/SKILL\.md' -or $consumerAdapter -match '--target \.') { throw 'el adaptador consumidor no conserva rutas y autoridad canónicas' }
    foreach ($path in @('AGENTS.md','00_inbox/decisions-pending','20_domains','_templates')) { if (-not (Test-Path (Join-Path $vault $path))) { throw "falta $path" } }
    if ((Get-Content (Join-Path $vault '.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 3\r?$') { throw 'formato incorrecto' }
    & (Join-Path $root 'scripts/vault.ps1') check -Target $project
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $root -Status
        throw 'la raíz de la fuente debía rechazarse como consumidor'
    }
    catch { if ($_.Exception.Message -eq 'la raíz de la fuente debía rechazarse como consumidor') { throw } }
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target (Join-Path $root 'vault') -Status
        throw 'bootstrap debía rechazar una ruta dentro de la fuente'
    }
    catch { if ($_.Exception.Message -eq 'bootstrap debía rechazar una ruta dentro de la fuente') { throw } }
    $integrationConfigHash = (Get-FileHash -LiteralPath (Join-Path $project '.ato-ai-skill-mem.yml')).Hash
    $integrationAdapterHash = (Get-FileHash -LiteralPath (Join-Path $project '.agents/skills/ato-ai-project-mem/SKILL.md')).Hash
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -IntegrateCodex
    if ((Get-FileHash -LiteralPath (Join-Path $project '.ato-ai-skill-mem.yml')).Hash -ne $integrationConfigHash -or (Get-FileHash -LiteralPath (Join-Path $project '.agents/skills/ato-ai-project-mem/SKILL.md')).Hash -ne $integrationAdapterHash) { throw 'la integración repetida modificó contenido administrado' }

    $conflictProject = Join-Path $temp 'conflict-codex'
    New-Item -ItemType Directory -Path (Join-Path $conflictProject '.agents/skills/ato-ai-project-mem') -Force | Out-Null
    '# conflicting adapter' | Set-Content (Join-Path $conflictProject '.agents/skills/ato-ai-project-mem/SKILL.md')
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $conflictProject -IntegrateCodex
        throw 'la integración debía rechazar un adaptador conflictivo'
    }
    catch { if ($_.Exception.Message -eq 'la integración debía rechazar un adaptador conflictivo') { throw } }
    if ((Get-Content (Join-Path $conflictProject '.agents/skills/ato-ai-project-mem/SKILL.md') -Raw) -notmatch '# conflicting adapter') { throw 'la integración sobrescribió un adaptador conflictivo' }

    $configConflictProject = Join-Path $temp 'config-conflict-codex'
    New-Item -ItemType Directory -Path $configConflictProject | Out-Null
    @('format: 3','vault:','  path: elsewhere') | Set-Content (Join-Path $configConflictProject '.ato-ai-skill-mem.yml')
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $configConflictProject -IntegrateCodex
        throw 'la integración debía rechazar una configuración conflictiva'
    }
    catch { if ($_.Exception.Message -eq 'la integración debía rechazar una configuración conflictiva') { throw } }
    if ((Get-Content (Join-Path $configConflictProject '.ato-ai-skill-mem.yml') -Raw) -notmatch 'path: elsewhere') { throw 'la integración sobrescribió una configuración conflictiva' }

    $roleProject = Join-Path $temp 'role-mismatch'
    New-Item -ItemType Directory -Path (Join-Path $roleProject 'mem/vault') -Force | Out-Null
    @('format: 1','vault_kind: source','vault_format: 3',"skill_version: $skillVersion",'source_revision: test',"source_tag: v$skillVersion",'created_at: 2026-10-26','updated_at: 2026-10-26') | Set-Content (Join-Path $roleProject 'mem/vault/.ato-ai-skill-mem-version.yml')
    $roleStatus = (& (Join-Path $root 'scripts/bootstrap.ps1') -Target $roleProject -Status) -join "`n"
    if ($roleStatus -notmatch 'vault.state: role-mismatch' -or $roleStatus -notmatch 'vault.context.state: blocked') { throw 'no se detectó incompatibilidad de vault_kind' }
    try { & (Join-Path $root 'scripts/bootstrap.ps1') -Target $stateProject -UpdateVault; throw 'UpdateVault debía rechazar una fuente no alineada' }
    catch { if ($_.Exception.Message -eq 'UpdateVault debía rechazar una fuente no alineada') { throw } }
    try { & (Join-Path $root 'scripts/bootstrap.ps1') -UpdateSourceVault; throw 'UpdateSourceVault debía rechazar una fuente no alineada' }
    catch { if ($_.Exception.Message -eq 'UpdateSourceVault debía rechazar una fuente no alineada') { throw } }

    $legacyProject = Join-Path $temp 'legacy-consumer'
    New-Item -ItemType Directory -Path (Join-Path $legacyProject 'mem/workspace/records') -Force | Out-Null
    @('workspace_format: 1','created_at: 2026-10-26') | Set-Content (Join-Path $legacyProject 'mem/workspace/.ato-ai-skill-mem-version.yml')
    '# Legacy record' | Set-Content (Join-Path $legacyProject 'mem/workspace/records/legacy.md')
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $legacyProject -MigrateWorkspaceToVault
    if ((Test-Path (Join-Path $legacyProject 'mem/workspace')) -or -not (Test-Path (Join-Path $legacyProject 'mem/vault/records'))) { throw 'la migración consumer workspace no terminó correctamente' }
    if ((Get-Content (Join-Path $legacyProject 'mem/vault/.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_format: 3\r?$') { throw 'la migración consumer no actualizó el formato' }

    $releaseSource = Join-Path $temp 'release-source'
    New-Item -ItemType Directory -Path $releaseSource | Out-Null
    foreach ($file in @('SKILL.md','VERSION','VAULT_FORMAT')) { Copy-Item -LiteralPath (Join-Path $root $file) -Destination $releaseSource }
    foreach ($directory in @('references','templates','scripts','vault')) { Copy-Item -LiteralPath (Join-Path $root $directory) -Destination $releaseSource -Recurse }
    & git -C $releaseSource init -q
    & git -C $releaseSource checkout -q -b master
    & git -C $releaseSource config user.email test@example.com
    & git -C $releaseSource config user.name 'Contract Tests'
    & git -C $releaseSource add .
    & git -C $releaseSource -c user.email=test@example.com -c user.name='Contract Tests' commit -qm 'test release fixture'
    & git -C $releaseSource tag "v$skillVersion"
    & git -C $releaseSource update-ref refs/remotes/origin/master HEAD
    $releaseCheckOutput = (& (Join-Path $releaseSource 'scripts/release-check.ps1') -Format json) -join "`n"
    if ($releaseCheckOutput -notmatch '"ready":true') { throw 'release-check debía aceptar el fixture alineado' }

    'dirty' | Set-Content (Join-Path $releaseSource '.release-dirty')
    try { & (Join-Path $releaseSource 'scripts/bootstrap.ps1') -UpdateSourceVault; throw 'UpdateSourceVault debía rechazar un checkout sucio' }
    catch { if ($_.Exception.Message -eq 'UpdateSourceVault debía rechazar un checkout sucio') { throw } }
    Remove-Item -LiteralPath (Join-Path $releaseSource '.release-dirty') -Force

    & git -C $releaseSource switch -q -c release-feature
    try { & (Join-Path $releaseSource 'scripts/bootstrap.ps1') -UpdateSourceVault; throw 'UpdateSourceVault debía rechazar una rama distinta de master' }
    catch { if ($_.Exception.Message -eq 'UpdateSourceVault debía rechazar una rama distinta de master') { throw } }
    & git -C $releaseSource switch -q master

    $tagMismatch = Join-Path $temp 'tag-mismatch'
    & git clone -q $releaseSource $tagMismatch
    'post-tag change' | Set-Content (Join-Path $tagMismatch 'post-tag-change')
    & git -C $tagMismatch add post-tag-change
    & git -C $tagMismatch -c user.email=test@example.com -c user.name='Contract Tests' commit -qm 'test post-tag change'
    try { & (Join-Path $tagMismatch 'scripts/bootstrap.ps1') -UpdateSourceVault; throw 'UpdateSourceVault debía rechazar HEAD distinto del tag' }
    catch { if ($_.Exception.Message -eq 'UpdateSourceVault debía rechazar HEAD distinto del tag') { throw } }

    $updateProject = Join-Path $temp 'update-consumer'
    New-Item -ItemType Directory -Path $updateProject | Out-Null
    & (Join-Path $releaseSource 'scripts/bootstrap.ps1') -Target $updateProject -Init
    $updateMarker = Join-Path $updateProject 'mem/vault/.ato-ai-skill-mem-version.yml'
    $updateMarkerText = (Get-Content $updateMarker -Raw) -replace "(?m)^skill_version: $([regex]::Escape($skillVersion))\r?$", 'skill_version: 0.4.0'
    [System.IO.File]::WriteAllText($updateMarker, $updateMarkerText)
    & (Join-Path $releaseSource 'scripts/bootstrap.ps1') -Target $updateProject -UpdateVault
    if ((Get-Content $updateMarker -Raw) -notmatch "(?m)^skill_version: $([regex]::Escape($skillVersion))\r?$") { throw 'UpdateVault no actualizó el manifiesto del consumidor' }

    & (Join-Path $releaseSource 'scripts/bootstrap.ps1') -UpdateSourceVault
    $releaseMarker = Join-Path $releaseSource 'vault/.ato-ai-skill-mem-version.yml'
    if ((Get-Content $releaseMarker -Raw) -notmatch "(?m)^skill_version: $([regex]::Escape($skillVersion))\r?$" -or (Get-Content $releaseMarker -Raw) -notmatch "(?m)^source_tag: v$([regex]::Escape($skillVersion))\r?$") { throw 'UpdateSourceVault no actualizó el manifiesto de release' }
    & git -C $releaseSource add vault/.ato-ai-skill-mem-version.yml
    $postReleaseCheckOutput = (& (Join-Path $releaseSource 'scripts/release-check.ps1') -PostRelease -Format json) -join "`n"
    if ($postReleaseCheckOutput -notmatch '"ready":true') { throw 'release-check debía aceptar el manifiesto posterior al release' }

    $sourceMigration = Join-Path $temp 'source-migration'
    New-Item -ItemType Directory -Path (Join-Path $sourceMigration 'workspace/records') -Force | Out-Null
    foreach ($file in @('SKILL.md','VERSION','VAULT_FORMAT')) { Copy-Item -LiteralPath (Join-Path $root $file) -Destination $sourceMigration }
    foreach ($directory in @('references','templates','scripts')) { Copy-Item -LiteralPath (Join-Path $root $directory) -Destination $sourceMigration -Recurse }
    @('workspace_format: 1','created_at: 2026-10-26') | Set-Content (Join-Path $sourceMigration 'workspace/.ato-ai-skill-mem-version.yml')
    '# Source legacy record' | Set-Content (Join-Path $sourceMigration 'workspace/records/legacy.md')
    & (Join-Path $sourceMigration 'scripts/bootstrap.ps1') -MigrateSourceWorkspaceToVault
    if ((Test-Path (Join-Path $sourceMigration 'workspace')) -or -not (Test-Path (Join-Path $sourceMigration 'vault/records'))) { throw 'la migración source workspace no terminó correctamente' }
    if ((Get-Content (Join-Path $sourceMigration 'vault/.ato-ai-skill-mem-version.yml') -Raw) -notmatch '(?m)^vault_kind: source\r?$') { throw 'la migración source no conservó la propiedad source' }

    & (Join-Path $root 'scripts/vault.ps1') create-domain -Target $project -Id alpha -Title Alpha
    if (-not (Test-Path (Join-Path $vault '20_domains/alpha/domain.yml'))) { throw 'dominio ausente' }
    $alphaDomainFile = Join-Path $vault '20_domains/alpha/domain.yml'
    $alphaDomainText = (Get-Content -LiteralPath $alphaDomainFile -Raw) -replace "(?<!`r)`n", "`r`n"
    [System.IO.File]::WriteAllText($alphaDomainFile, $alphaDomainText)
    foreach ($invalidId in @('Alpha', 'API-Gateway')) {
        try {
            & (Join-Path $root 'scripts/vault.ps1') create-domain -Target $project -Id $invalidId -Title Invalid
            throw "create-domain debía rechazar ID con mayúsculas: $invalidId"
        }
        catch {
            if ($_.Exception.Message -eq "create-domain debía rechazar ID con mayúsculas: $invalidId") { throw }
        }
        if (@(Get-ChildItem -LiteralPath (Join-Path $vault '20_domains') -Force | Where-Object { $_.Name -ceq $invalidId }).Count -gt 0) { throw "quedó un dominio inválido: $invalidId" }
    }
    & (Join-Path $root 'scripts/vault.ps1') check -Target $project
    if (-not (Test-Path (Join-Path $vault '99_runtime/rag/indexes'))) { throw 'falta 99_runtime/rag/indexes tras init-layout' }
    if (-not (Test-Path (Join-Path $vault '.gitignore'))) { throw 'falta .gitignore de la vault' }
    if ((Get-Content (Join-Path $vault '.gitignore') -Raw) -notmatch '99_runtime/rag/indexes/\*/data/') { throw 'falta regla de ignorado para datos RAG' }
    Remove-Item -LiteralPath (Join-Path $vault '99_runtime') -Recurse -Force
    & (Join-Path $root 'scripts/vault.ps1') check -Target $project
    New-Item -ItemType SymbolicLink -Path (Join-Path $vault '99_runtime') -Target $temp | Out-Null
    try { & (Join-Path $root 'scripts/vault.ps1') check -Target $project; throw 'check debía rechazar runtime simbólico' }
    catch { if ($_.Exception.Message -eq 'check debía rechazar runtime simbólico') { throw } }
    Remove-Item -LiteralPath (Join-Path $vault '99_runtime') -Force
    New-Item -ItemType Directory -Path (Join-Path $vault '99_runtime') | Out-Null
    New-Item -ItemType SymbolicLink -Path (Join-Path $vault '99_runtime/rag') -Target $temp | Out-Null
    try { & (Join-Path $root 'scripts/vault.ps1') check -Target $project; throw 'check debía rechazar rag simbólico' }
    catch { if ($_.Exception.Message -eq 'check debía rechazar rag simbólico') { throw } }
    Remove-Item -LiteralPath (Join-Path $vault '99_runtime/rag') -Force
    New-Item -ItemType Directory -Path (Join-Path $vault '99_runtime/rag/indexes/sample/data') -Force | Out-Null
    '# Manifiesto futuro reservado' | Set-Content (Join-Path $vault '99_runtime/rag/manifest.yml')
    & (Join-Path $root 'scripts/vault.ps1') check -Target $project
    Remove-Item -LiteralPath (Join-Path $vault '99_runtime') -Recurse -Force
    & (Join-Path $root 'scripts/vault.ps1') init-layout -Target $project
    Copy-Item -LiteralPath (Join-Path $vault '20_domains/alpha/domain.yml') -Destination (Join-Path $vault '20_domains/alpha/domain.yml.saved')
    (Get-Content -LiteralPath (Join-Path $vault '20_domains/alpha/domain.yml.saved') | Where-Object { $_ -notmatch '^scope:' }) | Set-Content (Join-Path $vault '20_domains/alpha/domain.yml')
    try {
        & (Join-Path $root 'scripts/vault.ps1') check -Target $project
        throw 'check debía rechazar metadata incompleta'
    }
    catch {
        if ($_.Exception.Message -eq 'check debía rechazar metadata incompleta') { throw }
    }
    Move-Item -LiteralPath (Join-Path $vault '20_domains/alpha/domain.yml.saved') -Destination (Join-Path $vault '20_domains/alpha/domain.yml') -Force
    '# Índice raíz inválido' | Set-Content (Join-Path $vault 'INDEX.md')
    try {
        & (Join-Path $root 'scripts/vault.ps1') check -Target $project
        throw 'check debía rechazar INDEX.md en raíz'
    }
    catch {
        if ($_.Exception.Message -eq 'check debía rechazar INDEX.md en raíz') { throw }
    }
    Remove-Item -LiteralPath (Join-Path $vault 'INDEX.md') -Force
    & (Join-Path $root 'scripts/vault.ps1') create-domain -Target $project -Id api-gateway -Title 'Arquitectura: "R&D/Platform"'
    if ((Get-Content (Join-Path $vault '20_domains/api-gateway/domain.yml') -Raw) -notlike '*title: "Arquitectura: \"R&D/Platform\""*') { throw 'título de dominio incorrecto' }
    try {
        & (Join-Path $root 'scripts/vault.ps1') create-domain -Target $project -Id multilinea -Title "primera`nsegunda"
        throw 'el título multilínea debía fallar'
    }
    catch {
        if ($_.Exception.Message -eq 'el título multilínea debía fallar') { throw }
    }
    if (Test-Path (Join-Path $vault '20_domains/multilinea')) { throw 'quedó un dominio parcial' }
    foreach ($titleCase in @(@('empty-title',''), @('blank-title','   '))) {
        try {
            & (Join-Path $root 'scripts/vault.ps1') create-domain -Target $project -Id $titleCase[0] -Title $titleCase[1]
            throw "create-domain debía rechazar title $($titleCase[0])"
        }
        catch {
            if ($_.Exception.Message -eq "create-domain debía rechazar title $($titleCase[0])") { throw }
        }
        if (Test-Path (Join-Path $vault "20_domains/$($titleCase[0])")) { throw 'se creó un paquete con título vacío' }
    }
    Set-Content -LiteralPath (Join-Path $vault '20_domains/.unexpected') -Value 'unexpected'
    try { & (Join-Path $root 'scripts/vault.ps1') check -Target $project; throw 'check debía rechazar entrada oculta' }
    catch { if ($_.Exception.Message -eq 'check debía rechazar entrada oculta') { throw } }
    Remove-Item -LiteralPath (Join-Path $vault '20_domains/.unexpected') -Force
    Set-Content -LiteralPath (Join-Path $vault '20_domains/unexpected.md') -Value 'unexpected'
    try { & (Join-Path $root 'scripts/vault.ps1') check -Target $project; throw 'check debía rechazar archivo en domains' }
    catch { if ($_.Exception.Message -eq 'check debía rechazar archivo en domains') { throw } }
    Remove-Item -LiteralPath (Join-Path $vault '20_domains/unexpected.md') -Force
    New-Item -ItemType Directory -Path (Join-Path $vault '20_domains/.temporary') | Out-Null
    try { & (Join-Path $root 'scripts/vault.ps1') check -Target $project; throw 'check debía rechazar paquete temporal' }
    catch { if ($_.Exception.Message -eq 'check debía rechazar paquete temporal') { throw } }
    Remove-Item -LiteralPath (Join-Path $vault '20_domains/.temporary') -Force
    New-Item -ItemType SymbolicLink -Path (Join-Path $vault '20_domains/linked-domain') -Target (Join-Path $vault '20_domains/alpha') | Out-Null
    try { & (Join-Path $root 'scripts/vault.ps1') check -Target $project; throw 'check debía rechazar dominio simbólico' }
    catch { if ($_.Exception.Message -eq 'check debía rechazar dominio simbólico') { throw } }
    Remove-Item -LiteralPath (Join-Path $vault '20_domains/linked-domain') -Force
    New-Item -ItemType Directory -Path (Join-Path $vault 'records') | Out-Null
    '# Legacy record' | Set-Content (Join-Path $vault 'records/2026-10-25--legacy.md')
    & (Join-Path $root 'scripts/vault.ps1') migration-plan -Target $project
    if (-not (Test-Path (Join-Path $vault '00_inbox/decisions-pending/2026-10-25--legacy.md'))) { throw 'propuesta pendiente ausente' }
    & (Join-Path $root 'scripts/vault.ps1') migration-apply -Target $project -Domain alpha -Record '2026-10-25--legacy.md'
    if (-not (Test-Path (Join-Path $vault '20_domains/alpha/records/2026-10-25--legacy.md'))) { throw 'registro no migrado' }
    if ((Get-Content (Join-Path $vault '_indexes/action-log.md') -Raw) -notmatch '(?m)^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z \| migration-apply') { throw 'el action log no usa UTC ISO-8601' }
    '# Protected root file' | Set-Content (Join-Path $vault 'guard.md')
    try {
        & (Join-Path $root 'scripts/vault.ps1') migration-apply -Target $project -Domain alpha -Record '../guard.md'
        throw 'la migración debía rechazar rutas en --record'
    }
    catch {
        if ($_.Exception.Message -eq 'la migración debía rechazar rutas en --record') { throw }
    }
    if (-not (Test-Path (Join-Path $vault 'guard.md'))) { throw 'se movió un archivo fuera de records' }
    if (Test-Path (Join-Path $vault '20_domains/alpha/guard.md')) { throw 'se escribió fuera de records del dominio' }
    '# Symlink source' | Set-Content (Join-Path $temp 'outside-record.md')
    New-Item -ItemType SymbolicLink -Path (Join-Path $vault 'records/linked.md') -Target (Join-Path $temp 'outside-record.md') | Out-Null
        try { & (Join-Path $root 'scripts/vault.ps1') migration-apply -Target $project -Domain alpha -Record linked.md; throw 'migration-apply debía rechazar registro simbólico' }
    catch { if ($_.Exception.Message -eq 'migration-apply debía rechazar registro simbólico') { throw } }
    if (-not (Test-Path (Join-Path $vault 'records/linked.md')) -or (Test-Path (Join-Path $vault '20_domains/alpha/records/linked.md'))) { throw 'el symlink raíz se movió' }
    Remove-Item -LiteralPath (Join-Path $vault 'records/linked.md') -Force
    '# Rollback record' | Set-Content (Join-Path $vault 'records/2026-10-25--rollback.md')
    Move-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md') -Destination (Join-Path $vault '_indexes/action-log.md.saved')
    New-Item -ItemType Directory -Path (Join-Path $vault '_indexes/action-log.md') | Out-Null
    try {
        & (Join-Path $root 'scripts/vault.ps1') migration-apply -Target $project -Domain alpha -Record '2026-10-25--rollback.md'
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
        try { & (Join-Path $root 'scripts/vault.ps1') migration-apply -Target $project -Domain alpha -Record '2026-10-25--log-link.md'; throw 'migration-apply debía rechazar action log simbólico' }
    catch { if ($_.Exception.Message -eq 'migration-apply debía rechazar action log simbólico') { throw } }
    if (-not (Test-Path (Join-Path $vault 'records/2026-10-25--log-link.md')) -or (Test-Path (Join-Path $vault '20_domains/alpha/records/2026-10-25--log-link.md'))) { throw 'el registro no se conservó ante action log simbólico' }
    Remove-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md') -Force
    Move-Item -LiteralPath (Join-Path $vault '_indexes/action-log.md.saved') -Destination (Join-Path $vault '_indexes/action-log.md')
    Move-Item -LiteralPath (Join-Path $vault '_maps/INDEX.md') -Destination (Join-Path $vault '_maps/INDEX.md.saved')
    New-Item -ItemType SymbolicLink -Path (Join-Path $vault '_maps/INDEX.md') -Target (Join-Path $vault '_maps/INDEX.md.saved') | Out-Null
    try {
        & (Join-Path $root 'scripts/vault.ps1') check -Target $project
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
        & (Join-Path $root 'scripts/vault.ps1') check -Target $project
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
    $migrationContextOutput = Invoke-Contract 'context-blocked' { & (Join-Path $root 'scripts/bootstrap.ps1') -Target $migrationProject -Contextualize }
    Assert-ContractOutput 'context-blocked' $migrationContextOutput
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
    & (Join-Path $root 'scripts/vault.ps1') create-domain -Target $migrationProject -Id migrated -Title Migrated
    & (Join-Path $root 'scripts/vault.ps1') migration-apply -Target $migrationProject -Domain migrated -Record '2026-01-01--legacy&record.md'
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
    & (Join-Path $root 'scripts/vault.ps1') check -Target $migrationProject

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

    $planProject = Join-Path $temp 'plan-consumer'
    $planVault = Join-Path $planProject 'mem/vault'
    New-Item -ItemType Directory -Path (Join-Path $planVault 'records') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $planVault '00_inbox/decisions-pending/z-conflict.md') -Force | Out-Null
    @('vault_kind: consumer','vault_format: 3') | Set-Content (Join-Path $planVault '.ato-ai-skill-mem-version.yml')
    '# Nuevo' | Set-Content (Join-Path $planVault 'records/a-new.md')
    '# Conflicto' | Set-Content (Join-Path $planVault 'records/z-conflict.md')
    try {
        & (Join-Path $root 'scripts/vault.ps1') migration-plan -Target $planProject
        throw 'el plan debía rechazar una propuesta no regular'
    }
    catch {
        if ($_.Exception.Message -eq 'el plan debía rechazar una propuesta no regular') { throw }
    }
    if (Test-Path (Join-Path $planVault '00_inbox/decisions-pending/a-new.md')) { throw 'el plan publicó propuestas parciales' }
    $planLinkProject = Join-Path $temp 'plan-link-consumer'
    $planLinkVault = Join-Path $planLinkProject 'mem/vault'
    New-Item -ItemType Directory -Path (Join-Path $planLinkVault 'records') -Force | Out-Null
    @('vault_kind: consumer','vault_format: 3') | Set-Content (Join-Path $planLinkVault '.ato-ai-skill-mem-version.yml')
    '# Regular' | Set-Content (Join-Path $planLinkVault 'records/a-regular.md')
    New-Item -ItemType SymbolicLink -Path (Join-Path $planLinkVault 'records/z-linked.md') -Target (Join-Path $temp 'outside-record.md') | Out-Null
    try { & (Join-Path $root 'scripts/vault.ps1') migration-plan -Target $planLinkProject; throw 'migration-plan debía rechazar registro simbólico' }
    catch { if ($_.Exception.Message -eq 'migration-plan debía rechazar registro simbólico') { throw } }
    if (Test-Path (Join-Path $planLinkVault '00_inbox/decisions-pending/a-regular.md')) { throw 'migration-plan publicó propuestas antes del rechazo' }
    Write-Output 'pruebas de bootstrap y vault PowerShell superadas'
}
finally { if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
