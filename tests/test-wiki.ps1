$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$temp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$install = Join-Path $temp 'installed-skill'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-Fails([scriptblock]$Action, [string]$Message) {
    try { & $Action; throw "se esperaba fallo: $Message" } catch {
        if ($_.Exception.Message -like "se esperaba fallo:*") { throw }
    }
}

try {
    New-Item -ItemType Directory -Path $install -Force | Out-Null
    foreach ($name in @('SKILL.md','VERSION','WIKI_FORMAT')) { Copy-Item -LiteralPath (Join-Path $root $name) -Destination $install }
    foreach ($name in @('scripts','templates','wiki')) { Copy-Item -LiteralPath (Join-Path $root $name) -Destination $install -Recurse }

    $rootCheck = & (Join-Path $root 'scripts/wiki.ps1') check
    $installCheck = & (Join-Path $install 'scripts/wiki.ps1') check
    Assert-True ($rootCheck -contains 'wiki.state: valid') 'el diagnóstico del skill actual no confirmó su wiki'
    Assert-True ($installCheck -contains 'wiki.state: valid') 'el diagnóstico de la copia instalada no confirmó su wiki'
    Assert-Fails { & (Join-Path $install 'scripts/wiki.ps1') check -Target $temp } 'selector -Target'
    Assert-Fails { & (Join-Path $install 'scripts/wiki.ps1') check -Source } 'selector -Source'

    $domainTemplatePath = Join-Path $install 'templates/wiki-layout/domain-AGENTS.md'
    $domainTemplate = [System.IO.File]::ReadAllText($domainTemplatePath)
    foreach ($lineEnding in @("`n", "`r`n")) {
        $normalized = $domainTemplate -replace "`r?`n", $lineEnding
        [System.IO.File]::WriteAllText($domainTemplatePath, $normalized)
        $suffix = if ($lineEnding -eq "`n") { 'lf' } else { 'crlf' }
        & (Join-Path $install 'scripts/wiki.ps1') create-domain -Id "sample-$suffix" -Title "Domain $suffix"
        $created = [System.IO.File]::ReadAllText((Join-Path $install "wiki/20_domains/sample-$suffix/AGENTS.md"))
        Assert-True ($created.Contains("# Dominio: Domain $suffix")) "creación con plantilla $suffix"
        Assert-True ($created.Contains($lineEnding)) "saltos de línea $suffix"
    }

    & (Join-Path $install 'scripts/wiki.ps1') create-domain -Id isolated -Title 'Isolated Skill'
    Assert-True (Test-Path -LiteralPath (Join-Path $install 'wiki/20_domains/isolated/domain.yml')) 'el dominio no se creó en la raíz instalada'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $root 'wiki/20_domains/isolated'))) 'se modificó la wiki del repositorio anfitrión'
    & (Join-Path $install 'scripts/wiki.ps1') check

    & (Join-Path $install 'scripts/wiki.ps1') init-layout
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $install 'wiki/99_runtime'))) 'el layout creó una reserva RAG'

    foreach ($lineBreak in @("`r", "`n")) {
        $domainId = if ($lineBreak -eq "`r") { 'invalid-cr' } else { 'invalid-lf' }
        Assert-Fails { & (Join-Path $install 'scripts/wiki.ps1') create-domain -Id $domainId -Title "Invalid${lineBreak}Title" } "título con $domainId"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $install "wiki/20_domains/$domainId"))) "se creó el dominio $domainId"
        Remove-Item -LiteralPath (Join-Path $install 'wiki/.local-mem.lock') -Force -ErrorAction SilentlyContinue
    }

    $outsideDomains = Join-Path $temp 'outside-domains'
    New-Item -ItemType Directory -Path $outsideDomains | Out-Null
    $domainsPath = Join-Path $install 'wiki/20_domains'
    $domainsBackup = Join-Path $install 'wiki/20_domains.local'
    Move-Item -LiteralPath $domainsPath -Destination $domainsBackup
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $domainsPath -Target $outsideDomains | Out-Null
    Assert-Fails { & (Join-Path $install 'scripts/wiki.ps1') check } 'punto de reparse dentro de la wiki'
    Assert-Fails { & (Join-Path $install 'scripts/wiki.ps1') create-domain -Id escaped } 'escritura a través del punto de reparse'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $outsideDomains 'escaped'))) 'se escribió fuera de la wiki'
    Remove-Item -LiteralPath $domainsPath -Force
    Move-Item -LiteralPath $domainsBackup -Destination $domainsPath
    & (Join-Path $install 'scripts/wiki.ps1') check

    $formatPath = Join-Path $install 'WIKI_FORMAT'
    [System.IO.File]::WriteAllText($formatPath, '99')
    Assert-Fails { & (Join-Path $install 'scripts/wiki.ps1') check } 'formato incompatible'
    [System.IO.File]::WriteAllText($formatPath, '3')
    & (Join-Path $install 'scripts/wiki.ps1') check
    Write-Output 'pruebas de wiki raíz única superadas'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
