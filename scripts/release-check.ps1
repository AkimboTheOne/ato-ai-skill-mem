[CmdletBinding()]
param(
    [ValidateSet('text', 'json')]
    [string]$Format = 'text'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$wikiFormat = (Get-Content -LiteralPath (Join-Path $root 'WIKI_FORMAT') -Raw).Trim()
$tag = "v$version"

function Get-GitValue([string[]]$Arguments, [string]$Fallback) {
    $value = & git -C $root @Arguments 2>$null
    if ($LASTEXITCODE -eq 0 -and $null -ne $value -and "$value".Length -gt 0) { return "$value".Trim() }
    return $Fallback
}

$branch = Get-GitValue @('symbolic-ref','--quiet','--short','HEAD') 'unavailable'
$head = Get-GitValue @('rev-parse','HEAD') 'unavailable'
$tagHead = Get-GitValue @('rev-list','-n','1',$tag) 'unavailable'
$main = Get-GitValue @('rev-parse','main') 'unavailable'
$originMain = Get-GitValue @('rev-parse','refs/remotes/origin/main') 'unavailable'
$dirty = (& git -C $root status --porcelain 2>$null) -join "`n"
$checks = [ordered]@{
    version = if ($version -match '^\d+\.\d+\.\d+$') { 'pass' } else { 'fail' }
    wiki_format = if ($wikiFormat -match '^[1-9]\d*$') { 'pass' } else { 'fail' }
    branch = if ($branch -eq 'main') { 'pass' } else { 'fail' }
    worktree = if ([string]::IsNullOrEmpty($dirty)) { 'pass' } else { 'fail' }
    tag = if ($tagHead -ne 'unavailable') { 'pass' } else { 'fail' }
    head_tag = if ($head -ne 'unavailable' -and $head -eq $tagHead) { 'pass' } else { 'fail' }
    main_sync = if ($main -ne 'unavailable' -and $main -eq $originMain) { 'pass' } else { 'fail' }
    wiki = 'fail'
}
try {
    & (Join-Path $root 'scripts/wiki.ps1') check *> $null
    $checks.wiki = 'pass'
}
catch {}
$blockers = @($checks.GetEnumerator() | Where-Object Value -eq 'fail' | ForEach-Object Key)
$ready = $blockers.Count -eq 0

if ($Format -eq 'json') {
    [ordered]@{ schema = 1; ready = $ready; version = $version; expected_tag = $tag; checks = $checks; blockers = $blockers } | ConvertTo-Json -Compress
}
else {
    Write-Output "release.ready: $($ready.ToString().ToLowerInvariant())"
    Write-Output "release.version: $version"
    Write-Output "release.expected_tag: $tag"
    foreach ($name in $checks.Keys) { Write-Output "release.check.$($name): $($checks[$name])" }
    Write-Output "release.blockers: $(if ($blockers.Count -gt 0) { $blockers -join ',' } else { 'none' })"
}
if ($ready) { exit 0 } else { exit 1 }
