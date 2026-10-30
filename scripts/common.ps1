$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RokitBin = Join-Path $env:USERPROFILE '.rokit\bin'
# The built, disposable place file. Everything that opens or builds it uses this one path.
$PlaceFile = Join-Path $ProjectRoot 'build\LootGoblinsTest001.rbxlx'
# Each game gets its own Rojo port so two games can be edited at once. In Studio, type
# localhost:<this port> into the Rojo plugin (it only auto-detects the default 34872).
$RojoPort = 34872

# Include newly installed user tools even in a terminal opened before bootstrap.
foreach ($directory in @($RokitBin) + ([Environment]::GetEnvironmentVariable('Path', 'User') -split ';')) {
    if ($directory -and $directory -notin ($env:Path -split ';')) {
        $env:Path = $directory + ';' + $env:Path
    }
}
# The Rokit shims must win over unrelated global Roblox tool versions.
$env:Path = $RokitBin + ';' + $env:Path

function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments)
    # Tools print normal progress and warnings to stderr. Under 'Stop', Windows PowerShell 5.1 turns that into a
    # terminating error when the caller captures the stream (2>&1), so stderr is only shown and the exit code decides.
    $global:LASTEXITCODE = $null
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Command @Arguments
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($exitCode -ne 0) { throw "$Command failed (exit $exitCode)." }
}

# True when a Studio window already has THIS game's place file open. Studio shows the full
# file path in its window title. A Studio open on another of our games does not count, so
# two games can be open side by side. Fallback: a lock file next to the place while any
# Studio runs (the title can be empty while Studio is still loading).
function Test-PlaceOpen {
    param([string]$Place = $PlaceFile)
    $studios = @(Get-Process -Name RobloxStudioBeta -ErrorAction SilentlyContinue)
    if ($studios.Count -eq 0) { return $false }
    if (@($studios | Where-Object { $_.MainWindowTitle -like "*$Place*" }).Count -gt 0) { return $true }
    return (Test-Path -LiteralPath ($Place + '.lock'))
}

# Two Studio copies lock the same place file ("This file is currently in use by another
# Studio instance"), so never start a second one for the same place. The window is always visible.
function Start-StudioOnce {
    param([string]$StudioPath, [string]$Place)
    if (Test-PlaceOpen $Place) {
        Write-Warning ("Roblox Studio already has this game open, so I did not open a second copy. " +
            "Use that window, or close it (File > Exit) and run this again.")
        return $false
    }
    Start-Process -FilePath $StudioPath -ArgumentList ('"' + $Place + '"')
    return $true
}

# Rebuilds the place from the repository. Studio saves into this same file, so a copy that
# someone saved since the last build is kept next to it instead of being overwritten.
function Build-Place {
    $stamp = $PlaceFile + '.built'
    if (Test-Path -LiteralPath $PlaceFile) {
        $built = if (Test-Path -LiteralPath $stamp) { [IO.File]::ReadAllText($stamp).Trim() } else { '' }
        if ("$((Get-Item -LiteralPath $PlaceFile).LastWriteTimeUtc.Ticks)" -ne $built) {
            $saved = $PlaceFile -replace '\.rbxlx$', ('.saved-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.rbxlx')
            Copy-Item -LiteralPath $PlaceFile -Destination $saved
            Write-Warning "Studio changes saved into the game file were kept in $saved. Ask your AI helper to move anything you built there into the game."
        }
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $PlaceFile) -Force | Out-Null
    Invoke-Checked (Join-Path $RokitBin 'rojo.exe') @('build', (Join-Path $ProjectRoot 'default.project.json'), '--output', $PlaceFile)
    [IO.File]::WriteAllText($stamp, "$((Get-Item -LiteralPath $PlaceFile).LastWriteTimeUtc.Ticks)")
}

function Get-StudioExe {
    Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Roblox\Versions') -Filter RobloxStudioBeta.exe -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Assert-ProjectTools {
    foreach ($line in Get-Content -LiteralPath (Join-Path $ProjectRoot 'rokit.toml')) {
        if ($line -match '^\s*(\w+)\s*=\s*"[^"@]+@([^"]+)"') {
            $name, $expected = $Matches[1], $Matches[2]
            $shim = Join-Path $RokitBin ($name + '.exe')
            if (!(Test-Path -LiteralPath $shim)) { throw "Missing $name. Run ./scripts/bootstrap.ps1." }
            $actual = (& $shim --version | Out-String).Trim()
            if ($LASTEXITCODE -ne 0 -or $actual -notmatch ('(?<![\d.])' + [regex]::Escape($expected) + '(?![\d.])')) {
                throw "$name must be $expected; got '$actual'. Run ./scripts/bootstrap.ps1."
            }
            Write-Host $actual
        }
    }
}
