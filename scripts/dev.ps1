param([switch]$OpenStudio)
. (Join-Path $PSScriptRoot 'common.ps1')
Push-Location $ProjectRoot
try {
    Assert-ProjectTools
    $place = $PlaceFile
    Build-Place
    if ($OpenStudio) {
        $studio = Get-StudioExe
        if (!$studio) { throw 'Roblox Studio missing. Install/launch Studio, then rerun bootstrap.' }
        Start-StudioOnce $studio.FullName $place | Out-Null
    }
    Write-Host "Open $place in Studio. Plugins > Rojo > address localhost, port $RojoPort > Connect."
    Write-Host 'Keep this terminal running. Ctrl+C stops Rojo. The prototype world appears in play mode.'
    # Serves the test project so the Luau specs sit in ServerStorage while the AI edits; play builds never include them.
    Invoke-Checked (Join-Path $RokitBin 'rojo.exe') @('serve', 'test.project.json', '--address', '127.0.0.1', '--port', "$RojoPort")
} finally { Pop-Location }
