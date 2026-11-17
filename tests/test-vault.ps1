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
    foreach ($name in @('SKILL.md','VERSION','VAULT_FORMAT')) { Copy-Item -LiteralPath (Join-Path $root $name) -Destination $install }
    foreach ($name in @('scripts','templates','vault')) { Copy-Item -LiteralPath (Join-Path $root $name) -Destination $install -Recurse }

    $rootCheck = & (Join-Path $root 'scripts/vault.ps1') check
    $installCheck = & (Join-Path $install 'scripts/vault.ps1') check
    Assert-True ($rootCheck -contains 'vault.state: valid') 'el diagnóstico del skill actual no confirmó su vault'
    Assert-True ($installCheck -contains 'vault.state: valid') 'el diagnóstico de la copia instalada no confirmó su vault'
    Assert-Fails { & (Join-Path $install 'scripts/vault.ps1') check -Target $temp } 'selector -Target'
    Assert-Fails { & (Join-Path $install 'scripts/vault.ps1') check -Source } 'selector -Source'

    & (Join-Path $install 'scripts/vault.ps1') create-domain -Id isolated -Title 'Isolated Skill'
    Assert-True (Test-Path -LiteralPath (Join-Path $install 'vault/20_domains/isolated/domain.yml')) 'el dominio no se creó en la raíz instalada'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $root 'vault/20_domains/isolated'))) 'se modificó la vault del repositorio anfitrión'
    & (Join-Path $install 'scripts/vault.ps1') check

    & (Join-Path $install 'scripts/vault.ps1') init-layout
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $install 'vault/99_runtime'))) 'el layout creó una reserva RAG'
    $formatPath = Join-Path $install 'VAULT_FORMAT'
    [System.IO.File]::WriteAllText($formatPath, '99')
    Assert-Fails { & (Join-Path $install 'scripts/vault.ps1') check } 'formato incompatible'
    [System.IO.File]::WriteAllText($formatPath, '3')
    & (Join-Path $install 'scripts/vault.ps1') check
    Write-Output 'pruebas de vault raíz única superadas'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
