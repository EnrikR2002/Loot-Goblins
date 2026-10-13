param([ValidateSet('read','submit','init','export','check','test','library-build','library-check')][string]$Action = 'read')
$ErrorActionPreference = 'Stop'
$memoryPython = $null
$memoryPrefix = @()
foreach ($candidate in @('python','python3','py')) {
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if (!$command -or $command.Source -like '*WindowsApps*') { continue }
    $prefix = if ($candidate -eq 'py') { @('-3') } else { @() }
    & $command.Source @prefix -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>$null
    if ($LASTEXITCODE -eq 0) { $memoryPython = $command.Source; $memoryPrefix = $prefix; break }
}
if (!$memoryPython) {
    if ($env:OS -ne 'Windows_NT' -or !(Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'The AI needs to install Python 3.10 or newer, then retry. Keep the existing notebook and guide.'
    }
    Write-Host 'Installing the missing notebook tool. Your game launcher does not depend on this tool.'
    & winget install --id Python.Python.3.12 --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw 'Python installation did not finish. The AI should repair setup and retry; no records were discarded.' }
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if (!$launcher) { throw 'Python was installed. The AI should open a fresh tool session and retry.' }
    $memoryPython = $launcher.Source
    $memoryPrefix = @('-3')
}
& $memoryPython @memoryPrefix (Join-Path $PSScriptRoot 'memory.py') $Action
if ($LASTEXITCODE -ne 0) { throw 'The memory step needs attention. The AI should read the reason above and repair it; existing records were preserved.' }
