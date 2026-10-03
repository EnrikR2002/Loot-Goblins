param([switch]$Fix)
. (Join-Path $PSScriptRoot 'common.ps1')
Push-Location $ProjectRoot
try {
    Assert-ProjectTools
    if ($Fix) { Invoke-Checked (Join-Path $RokitBin 'stylua.exe') @('--verify', 'src') }
    Invoke-Checked (Join-Path $RokitBin 'stylua.exe') @('--check', 'src')
    Invoke-Checked (Join-Path $RokitBin 'selene.exe') @('src')
    New-Item -ItemType Directory -Path 'build' -Force | Out-Null
    Invoke-Checked (Join-Path $RokitBin 'rojo.exe') @('build', 'default.project.json', '--output', 'build\LootGoblinsTest001.rbxlx')
    Invoke-Checked 'git' @('diff', '--check')
    Write-Host 'Formatting, lint, Rojo build, and whitespace checks passed. Studio/playtesting is separate.'
} finally { Pop-Location }
