# V14: rebuilds the game's Blender art and exports it (art/README.md). For the AI; humans never need it.
#   ./scripts/art.ps1                  build every set (Harbor, Skiff, Pebble) from its build script, then export
#   ./scripts/art.ps1 harbor skiff     only those sets
#   ./scripts/art.ps1 -Export X.blend  export a .blend someone edited by hand (its build script would overwrite it)
#   -Preview                           also render Workbench previews into the scratch folder given by -Out
# Blender is found from $env:BLENDER, then the usual install folders. The game data is deterministic: a rebuild
# with no changes writes identical src/client/Art14 and art/manifest files.
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Export,
    [switch]$Preview,
    [string]$Out,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Sets
)
if (-not $Sets) { $Sets = @('harbor', 'skiff', 'pebble') }
. (Join-Path $PSScriptRoot 'common.ps1')

function Get-Blender {
    if ($env:BLENDER -and (Test-Path -LiteralPath $env:BLENDER)) { return $env:BLENDER }
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Blender Foundation'),
        (Join-Path $env:ProgramFiles 'Blender Foundation')
    )
    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root) {
            $exe = Get-ChildItem -LiteralPath $root -Filter blender.exe -Recurse -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending | Select-Object -First 1
            if ($exe) { return $exe.FullName }
        }
    }
    $cmd = Get-Command blender -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'Blender 4.5 was not found. Install it (blender.org, 4.5 LTS) or set $env:BLENDER to blender.exe.'
}

$blender = Get-Blender
$scripts = Join-Path $ProjectRoot 'art\blender\scripts'
Push-Location $ProjectRoot
try {
    if ($Preview) {
        if (-not $Out) { throw '-Preview needs -Out <folder> (a scratch folder: previews are not committed).' }
        $env:LG_PREVIEW = $Out
    }
    if ($Export) {
        Invoke-Checked $blender @('--background', $Export, '--python', (Join-Path $scripts 'lgexport.py'))
    } else {
        foreach ($set in $Sets) {
            Invoke-Checked $blender @('--background', '--factory-startup', '--python', (Join-Path $scripts ("build_" + $set.ToLower() + ".py")))
        }
    }
    Write-Host 'Art exported. Run ./scripts/check.ps1, then the Luau tests in Studio (ArtSpec checks the export).'
} finally {
    Remove-Item Env:LG_PREVIEW -ErrorAction SilentlyContinue
    Pop-Location
}
