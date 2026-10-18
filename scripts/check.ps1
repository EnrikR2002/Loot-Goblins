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
    New-Item -ItemType Directory -Path 'build' -Force | Out-Null
    Invoke-Checked (Join-Path $RokitBin 'rojo.exe') @('build', 'default.project.json', '--output', $PlaceFile)
    # V11: the Luau test suite's place (the game plus ServerStorage.LootGoblinsTests). Its tests run in Studio's
    # Edit mode: require(game.ServerStorage.LootGoblinsTests.Runner).run().summary
    Invoke-Checked (Join-Path $RokitBin 'rojo.exe') @('build', 'test.project.json', '--output', (Join-Path $ProjectRoot 'build\LootGoblinsTests.rbxlx'))
    Invoke-Checked 'git' @('diff', '--check')
    Write-Host 'Formatting, lint, Rojo builds, and whitespace checks passed. The Luau tests and playtesting run in Studio.'
} finally { Pop-Location }
