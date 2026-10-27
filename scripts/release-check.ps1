[CmdletBinding()]
param(
    [ValidateSet('text', 'json')]
    [string]$Format = 'text',
    [switch]$PostRelease
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Get-GitValue([string[]]$Arguments, [string]$Fallback) {
    try {
        $value = & git -C $root @Arguments 2>$null
        if ($LASTEXITCODE -eq 0 -and $null -ne $value -and "$value".Length -gt 0) { return "$value".Trim() }
    }
    catch {}
    return $Fallback
}

$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$vaultFormat = (Get-Content -LiteralPath (Join-Path $root 'VAULT_FORMAT') -Raw).Trim()
$expectedTag = "v$version"
$branch = Get-GitValue @('symbolic-ref', '--quiet', '--short', 'HEAD') 'detached-or-unavailable'
$headRevision = Get-GitValue @('rev-parse', 'HEAD') 'unavailable'
$masterRevision = Get-GitValue @('rev-parse', 'master') 'unavailable'
$tagRevision = Get-GitValue @('rev-list', '-n', '1', $expectedTag) 'unavailable'
$originMasterRevision = Get-GitValue @('rev-parse', 'refs/remotes/origin/master') 'unavailable'
$dirty = (& git -C $root status --porcelain 2>$null) -join "`n"

$checks = [ordered]@{
    version = 'fail'
    vault_format = 'fail'
    branch = 'fail'
    worktree = 'fail'
    tag = 'fail'
    head_tag = 'fail'
    origin_master = 'fail'
    vault = 'fail'
    manifest = if ($PostRelease) { 'fail' } else { 'skip' }
}
$blockers = [System.Collections.Generic.List[string]]::new()

if ($version -match '^\d+\.\d+\.\d+$') { $checks.version = 'pass' } else { $blockers.Add('version') }
if ($vaultFormat -match '^[1-9]\d*$') { $checks.vault_format = 'pass' } else { $blockers.Add('vault_format') }
if ($branch -eq 'master') { $checks.branch = 'pass' } else { $blockers.Add('branch') }
$changedFiles = ((& git -C $root diff --name-only 2>$null) -join "`n").Trim()
$untrackedFiles = ((& git -C $root ls-files --others --exclude-standard 2>$null) -join "`n").Trim()
if ([string]::IsNullOrEmpty($dirty) -or ($PostRelease -and $changedFiles -eq 'vault/.ato-ai-skill-mem-version.yml' -and [string]::IsNullOrEmpty($untrackedFiles))) { $checks.worktree = 'pass' } else { $blockers.Add('worktree') }
if ($tagRevision -ne 'unavailable') { $checks.tag = 'pass' } else { $blockers.Add('tag') }
if ($headRevision -ne 'unavailable' -and $headRevision -eq $tagRevision) { $checks.head_tag = 'pass' } else { $blockers.Add('head_tag') }
if ($masterRevision -ne 'unavailable' -and $originMasterRevision -ne 'unavailable' -and $masterRevision -eq $originMasterRevision) { $checks.origin_master = 'pass' } else { $blockers.Add('origin_master') }
& (Join-Path $root 'scripts/vault.ps1') check -Source *> $null
if ($LASTEXITCODE -eq 0) { $checks.vault = 'pass' } else { $blockers.Add('vault') }

if ($PostRelease) {
    $marker = Join-Path $root 'vault/.ato-ai-skill-mem-version.yml'
    $values = @{}
    if (Test-Path -LiteralPath $marker) {
        foreach ($line in Get-Content -LiteralPath $marker) {
            if ($line -match '^([^:]+):\s*(.*)$') { $values[$matches[1]] = $matches[2].Trim('"') }
        }
    }
    if ($values['vault_kind'] -eq 'source' -and $values['skill_version'] -eq $version -and $values['vault_format'] -eq $vaultFormat -and $values['source_revision'] -eq $tagRevision -and $values['source_tag'] -eq $expectedTag) {
        $checks.manifest = 'pass'
    }
    else { $blockers.Add('manifest') }
}

$ready = $blockers.Count -eq 0
if ($Format -eq 'json') {
    [ordered]@{
        schema = 1
        ready = $ready
        version = $version
        expected_tag = $expectedTag
        post_release = [bool]$PostRelease
        checks = $checks
        blockers = @($blockers)
    } | ConvertTo-Json -Compress
}
else {
    Write-Output "release.ready: $($ready.ToString().ToLowerInvariant())"
    Write-Output "release.version: $version"
    Write-Output "release.expected_tag: $expectedTag"
    Write-Output "release.check.version: $($checks.version)"
    Write-Output "release.check.vault_format: $($checks.vault_format)"
    Write-Output "release.check.branch: $($checks.branch) ($branch)"
    Write-Output "release.check.worktree: $($checks.worktree)"
    Write-Output "release.check.tag: $($checks.tag)"
    Write-Output "release.check.head_tag: $($checks.head_tag)"
    Write-Output "release.check.origin_master: $($checks.origin_master)"
    Write-Output "release.check.vault: $($checks.vault)"
    Write-Output "release.check.manifest: $($checks.manifest)"
    Write-Output "release.blockers: $(if ($blockers.Count -gt 0) { $blockers -join ',' } else { 'none' })"
}

if ($ready) { exit 0 } else { exit 1 }
