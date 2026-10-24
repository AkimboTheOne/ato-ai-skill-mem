$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ato-ai-skill-mem-" + [guid]::NewGuid())
$project = Join-Path $temporaryRoot 'consumer'
$conflict = Join-Path $temporaryRoot 'conflict'

try {
    New-Item -ItemType Directory -Path $project | Out-Null
    $agentsPath = Join-Path $project 'AGENTS.md'
    Set-Content -LiteralPath $agentsPath -Value 'before'
    $agentsBefore = [System.IO.File]::ReadAllText($agentsPath)
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project

    $skillLink = Get-Item -LiteralPath (Join-Path $project 'mem/SKILL.md') -Force
    if ($skillLink.LinkType -ne 'SymbolicLink') {
        throw 'SKILL.md was not installed as a symbolic link'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $project 'mem/workspace/INDEX.md'))) {
        throw 'workspace index is missing'
    }
    if ([System.IO.File]::ReadAllText($agentsPath) -ne $agentsBefore) {
        throw 'bootstrap changed AGENTS.md'
    }

    Set-Content -LiteralPath (Join-Path $project 'mem/workspace/INDEX.md') -Value '# Local memory'
    & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project
    if ((Get-Content -LiteralPath (Join-Path $project 'mem/workspace/INDEX.md') -Raw) -notmatch 'Local memory') {
        throw 'bootstrap overwrote the existing workspace index'
    }
    if ([System.IO.File]::ReadAllText($agentsPath) -ne $agentsBefore) {
        throw 'bootstrap changed AGENTS.md during a repeat install'
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
        throw 'bootstrap accepted a late non-link conflict'
    }
    if (Test-Path -LiteralPath (Join-Path $conflict 'mem/SKILL.md')) {
        throw 'bootstrap created SKILL.md before detecting a late conflict'
    }
    if (Test-Path -LiteralPath (Join-Path $conflict 'mem/templates')) {
        throw 'bootstrap created templates before detecting a late conflict'
    }

    $removedArgumentRejected = $false
    try {
        & (Join-Path $root 'scripts/bootstrap.ps1') -Target $project -Integrate
    }
    catch {
        $removedArgumentRejected = $true
    }
    if (-not $removedArgumentRejected) {
        throw 'bootstrap accepted a removed argument'
    }

    Write-Output 'PowerShell bootstrap tests passed'
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
