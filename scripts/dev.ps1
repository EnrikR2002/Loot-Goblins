param([switch]$OpenStudio)
. (Join-Path $PSScriptRoot 'common.ps1')
Push-Location $ProjectRoot
try {
    Assert-ProjectTools
    New-Item -ItemType Directory -Path 'build' -Force | Out-Null
    $place = Join-Path $ProjectRoot 'build\LootGoblinsTest001.rbxlx'
    Invoke-Checked (Join-Path $RokitBin 'rojo.exe') @('build', 'default.project.json', '--output', $place)
    if ($OpenStudio) {
        $studio = Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Roblox\Versions') -Filter RobloxStudioBeta.exe -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (!$studio) { throw 'Roblox Studio missing. Install/launch Studio, then rerun bootstrap.' }
        Start-StudioOnce $studio.FullName $place | Out-Null
    }
    Write-Host "Open $place in Studio. Plugins > Rojo > Connect (localhost:34872)."
    Write-Host 'Keep this terminal running. Ctrl+C stops Rojo. The prototype world appears in play mode.'
    Invoke-Checked (Join-Path $RokitBin 'rojo.exe') @('serve', 'default.project.json', '--address', '127.0.0.1', '--port', '34872')
} finally { Pop-Location }
