[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Target
)

$ErrorActionPreference = 'Stop'

$sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$targetRoot = (Resolve-Path -LiteralPath $Target).Path
$memDir = Join-Path $targetRoot 'mem'

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
        Fail "could not create symlink $Destination; enable Developer Mode or use a terminal with symlink permission instead of copying the skill"
    }
}

function Assert-LinkDestination([string]$Source, [string]$Destination) {
    $existing = Get-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        if ($existing.LinkType -ne 'SymbolicLink') {
            Fail "cannot replace existing non-link path: $Destination"
        }

        $targets = @($existing.Target | ForEach-Object { [string]$_ })
        if ($targets -notcontains $Source) {
            Fail "existing link differs: $Destination"
        }
        return
    }
}

foreach ($required in @('SKILL.md', 'references', 'templates')) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $required))) {
        Fail "missing canonical $required in $sourceRoot"
    }
}

$memItem = Get-Item -LiteralPath $memDir -Force -ErrorAction SilentlyContinue
if ($null -ne $memItem -and -not $memItem.PSIsContainer) {
    Fail "instance path exists but is not a directory: $memDir"
}
if ($null -ne $memItem -and $memItem.LinkType -eq 'SymbolicLink') {
    Fail "instance directory must be local, not a symlink: $memDir"
}

Assert-LinkDestination (Join-Path $sourceRoot 'SKILL.md') (Join-Path $memDir 'SKILL.md')
Assert-LinkDestination (Join-Path $sourceRoot 'references') (Join-Path $memDir 'references')
Assert-LinkDestination (Join-Path $sourceRoot 'templates') (Join-Path $memDir 'templates')

[System.IO.Directory]::CreateDirectory($memDir) | Out-Null
Ensure-Symlink (Join-Path $sourceRoot 'SKILL.md') (Join-Path $memDir 'SKILL.md')
Ensure-Symlink (Join-Path $sourceRoot 'references') (Join-Path $memDir 'references')
Ensure-Symlink (Join-Path $sourceRoot 'templates') (Join-Path $memDir 'templates')

$workspace = Join-Path $memDir 'workspace'
[System.IO.Directory]::CreateDirectory((Join-Path $workspace 'records')) | Out-Null
$index = Join-Path $workspace 'INDEX.md'
if (-not (Test-Path -LiteralPath $index)) {
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'templates/workspace/INDEX.md') -Destination $index
}

Write-Output "memory instance ready: $memDir"
