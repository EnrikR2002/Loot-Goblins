$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RokitBin = Join-Path $env:USERPROFILE '.rokit\bin'

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
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed (exit $LASTEXITCODE)." }
}

# Two Studio copies lock the same place file ("This file is currently in use by another
# Studio instance"), so never start a second one. The window is always visible.
function Start-StudioOnce {
    param([string]$StudioPath, [string]$Place)
    $running = @(Get-Process -Name RobloxStudioBeta -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        Write-Warning ("Roblox Studio is already running (process $($running.Id -join ', ')), so I did not open a second copy. " +
            "In that Studio use File > Open and choose $Place, or close every Studio window and run this again.")
        return $false
    }
    Start-Process -FilePath $StudioPath -ArgumentList ('"' + $Place + '"')
    return $true
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
