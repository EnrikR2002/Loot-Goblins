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
