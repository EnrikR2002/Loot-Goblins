param([switch]$NoOpen)
# The one-click path for people who do not use terminals (Ethan, Ninety). Double-click
# "Play Loot Goblins.bat" in the repository folder. It never changes Git history, never
# discards work, and never needs Rojo: the built place already contains every script.
. (Join-Path $PSScriptRoot 'common.ps1')
Push-Location $ProjectRoot

# Git writes progress to stderr, which PowerShell 5.1 treats as an error under 'Stop'.
function Invoke-Git {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $out = & git @args 2>$null; return [pscustomobject]@{ Ok = ($LASTEXITCODE -eq 0); Text = ($out | Out-String).Trim() } }
    finally { $ErrorActionPreference = $previous }
}

try {
    Write-Host ''
    Write-Host '=== Loot Goblins ===' -ForegroundColor Yellow

    # 1. This game's Studio window must be closed first: two Studio copies lock the same place
    #    file. A Studio open on a different game is fine.
    if (!$NoOpen -and (Test-PlaceOpen)) {
        Write-Host 'Loot Goblins is already open in Roblox Studio.' -ForegroundColor Red
        Write-Host 'Close that Studio window (File > Exit), then double-click "Play Loot Goblins" again.'
        Write-Host 'If you just closed it, wait 10 seconds first.'
        exit 1
    }

    # 2. Get the newest version of the game. Only a safe fast-forward; never throws work away.
    $branch = (Invoke-Git branch --show-current).Text
    Write-Host "Version: $branch"
    $fetched = Invoke-Git fetch origin
    if (!$fetched.Ok) {
        Write-Warning 'Could not reach GitHub (no internet?). Playing the version already on this computer.'
    } elseif ((Invoke-Git rev-parse --abbrev-ref '@{u}').Ok) {
        $behind = [int](Invoke-Git rev-list --count 'HEAD..@{u}').Text
        if ($behind -gt 0) {
            if ((Invoke-Git status --porcelain).Text) {
                Write-Warning "A newer version exists, but this computer has unsaved changes, so I did not update. Ask your AI helper: 'Update my game and keep my changes.'"
            } elseif ((Invoke-Git merge --ff-only '@{u}').Ok) {
                Write-Host "Updated: got $behind new change(s) from GitHub." -ForegroundColor Green
            } else {
                Write-Warning "Could not update automatically. Ask your AI helper to update the game."
            }
        } else {
            Write-Host 'You already have the newest version.'
        }
    }
    $head = (Invoke-Git log -1 --format='%h %s').Text
    Write-Host "Latest change: $head"

    # 3. Make sure the pinned Rojo tool exists (it only builds the place file here).
    try { Assert-ProjectTools | Out-Null }
    catch {
        Write-Host 'First run: installing the game tools (about a minute)...'
        & (Join-Path $PSScriptRoot 'bootstrap.ps1') -Headless
        Assert-ProjectTools | Out-Null
    }

    # 4. Build the game file. It is rebuilt every time, so it is always the newest version.
    New-Item -ItemType Directory -Path 'build' -Force | Out-Null
    $place = $PlaceFile
    Write-Host 'Building the game...'
    Invoke-Checked (Join-Path $RokitBin 'rojo.exe') @('build', 'default.project.json', '--output', $place)

    # 5. Open Studio on it.
    if ($NoOpen) { Write-Host "Built $place (not opened)."; exit 0 }
    $studio = Get-StudioExe
    if (!$studio) { throw 'Roblox Studio is not installed. Install it from https://create.roblox.com/ and sign in once.' }
    Start-StudioOnce $studio.FullName $place | Out-Null

    Write-Host ''
    Write-Host 'Studio is opening. This can take a minute.' -ForegroundColor Green
    Write-Host 'Then:'
    Write-Host '  1. Press the blue PLAY button at the top. The sky is blank until you press it.'
    Write-Host '  2. Press H in the game to read how to play.'
    Write-Host '  3. To test with friends on one computer: Test tab > Server & Clients > 3 players > blue Play.'
    Write-Host 'You can close this window.'
} catch {
    Write-Host ''
    Write-Host "Something went wrong: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Take a screenshot of this window and send it to your AI helper or to Enrik.'
    exit 1
} finally { Pop-Location }
