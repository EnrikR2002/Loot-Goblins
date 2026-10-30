param([switch]$Fix)
. (Join-Path $PSScriptRoot 'common.ps1')
Push-Location $ProjectRoot
try {
    Assert-ProjectTools
    & (Join-Path $PSScriptRoot 'memory.ps1') check
    & (Join-Path $PSScriptRoot 'memory.ps1') test
    if ($Fix) { Invoke-Checked (Join-Path $RokitBin 'stylua.exe') @('--verify', 'src', 'tests/luau') }
    Invoke-Checked (Join-Path $RokitBin 'stylua.exe') @('--check', 'src', 'tests/luau')
    Invoke-Checked (Join-Path $RokitBin 'selene.exe') @('src', 'tests/luau')
    Build-Place
    # The game plus its Luau specs; the specs themselves run in Studio (tests/luau/Runner.lua).
    Invoke-Checked (Join-Path $RokitBin 'rojo.exe') @('build', 'test.project.json', '--output', 'build\LootGoblinsTests.rbxlx')
    Invoke-Checked 'git' @('diff', '--check')
    Write-Host 'Formatting, lint, Rojo builds, and whitespace checks passed. Luau specs and playtesting run in Studio.'
} finally { Pop-Location }
