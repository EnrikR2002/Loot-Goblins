param([switch]$Headless)
. (Join-Path $PSScriptRoot 'common.ps1')
Push-Location $ProjectRoot
try {
    if (!(Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Install Git: winget install --id Git.Git --exact. Then open a new terminal and rerun bootstrap.'
    }
    Invoke-Checked 'git' @('--version')

    $rokit = Join-Path $RokitBin 'rokit.exe'
    if (!(Test-Path -LiteralPath $rokit)) {
        # Official, tested Rokit bootstrap release. Project tool pins live in rokit.toml.
        $stage = Join-Path ([IO.Path]::GetTempPath()) ('loot-rokit-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $stage | Out-Null
        $zip = Join-Path $stage 'rokit.zip'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/rojo-rbx/rokit/releases/download/v1.2.0/rokit-1.2.0-windows-x86_64.zip' -OutFile $zip
        $expectedHash = 'f9ba1704014ff67d51e8005f605955c7c26d2429a5312a9419dc477fc310e96d'
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower() -ne $expectedHash) {
            throw 'Rokit checksum mismatch; download was not executed.'
        }
        Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $stage 'unpacked')
        Invoke-Checked (Join-Path $stage 'unpacked\rokit.exe') @('self-install')
    }
    Invoke-Checked $rokit @('--version')
    Invoke-Checked $rokit @('trust', 'rojo-rbx/rojo', 'JohnnyMorganz/StyLua', 'Kampfkarren/selene')
    Invoke-Checked $rokit @('install')
    Assert-ProjectTools

    if (!$Headless) {
        # Use Rojo's official matching plugin release; this also handles new Studio
        # installs whose registry layout the CLI's plugin installer does not recognize.
        $plugin = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins\RojoManagedPlugin.rbxm'
        $studio = Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Roblox\Versions') -Filter RobloxStudioBeta.exe -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($studio) {
            Write-Host "Studio: $($studio.FullName)"
            $manifest = Get-Content -LiteralPath 'rokit.toml' -Raw
            if ($manifest -notmatch 'rojo-rbx/rojo@([^"\s]+)') { throw 'Missing Rojo version pin.' }
            $release = Invoke-RestMethod ('https://api.github.com/repos/rojo-rbx/rojo/releases/tags/v' + $Matches[1])
            $asset = $release.assets | Where-Object name -EQ 'Rojo.rbxm'
            if (!$asset.digest -or $asset.digest -notmatch '^sha256:([a-f0-9]{64})$') { throw 'Missing official plugin checksum.' }
            $pluginHash = $Matches[1]
            $currentHash = if (Test-Path -LiteralPath $plugin) { (Get-FileHash -LiteralPath $plugin).Hash.ToLower() } else { '' }
            if ($currentHash -ne $pluginHash) {
                $download = Join-Path ([IO.Path]::GetTempPath()) ('loot-rojo-' + [guid]::NewGuid() + '.rbxm')
                Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $download
                if ((Get-FileHash -LiteralPath $download).Hash.ToLower() -ne $pluginHash) { throw 'Rojo plugin checksum mismatch.' }
                if ($currentHash) {
                    $backup = $plugin + '.' + $currentHash.Substring(0, 12) + '.bak'
                    if (!(Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $plugin -Destination $backup }
                }
                New-Item -ItemType Directory -Path (Split-Path -Parent $plugin) -Force | Out-Null
                Copy-Item -LiteralPath $download -Destination $plugin
            }
            Write-Host 'Matching Rojo Studio plugin ready; restart Studio if this is its first installation.'
        } else {
            Write-Warning 'Studio missing. Install from https://create.roblox.com/, launch/sign in once, then rerun bootstrap.'
        }

        # Add the official Studio launcher, preserving any existing server with this name.
        $launcher = '%LOCALAPPDATA%\Roblox\mcp.bat'
        if (Get-Command codex -ErrorAction SilentlyContinue) {
            $ErrorActionPreference = 'Continue'
            $existing = & codex mcp get Roblox_Studio 2>$null
            $serverExists = $LASTEXITCODE -eq 0
            $ErrorActionPreference = 'Stop'
            if (!$serverExists) { Invoke-Checked 'codex' @('mcp', 'add', 'Roblox_Studio', '--', 'cmd.exe', '/d', '/c', $launcher) }
            else { Write-Host 'Existing Codex Roblox_Studio MCP configuration preserved.' }
        } else { Write-Warning 'Codex missing: install/sign into the Codex app or CLI before using it.' }
        $claude = Get-Command claude.cmd -ErrorAction SilentlyContinue
        if (!$claude) { $claude = Get-Command claude -ErrorAction SilentlyContinue }
        if ($claude) {
            $ErrorActionPreference = 'Continue'
            $existing = & $claude.Source mcp get Roblox_Studio 2>$null
            $serverExists = $LASTEXITCODE -eq 0
            $ErrorActionPreference = 'Stop'
            if (!$serverExists) {
                Invoke-Checked $claude.Source @('mcp', 'add', '--scope', 'user', '--transport', 'stdio', 'Roblox_Studio', '--', 'cmd.exe', '/d', '/c', $launcher)
            } else { Write-Host 'Existing Claude Code Roblox_Studio MCP configuration preserved.' }
        } else { Write-Warning 'Claude Code missing: install/sign into Claude Code before using it.' }
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            & gh auth status
            if ($LASTEXITCODE -ne 0) { Write-Warning 'Run: gh auth login --hostname github.com --git-protocol https --web' }
        } else { Write-Warning 'GitHub CLI missing: winget install --id GitHub.cli --exact; then gh auth login --web' }
        Write-Host 'Studio: open a place > Assistant icon > ... > Settings > MCP Servers > Enable Studio as MCP server. Restart the AI client after registration.'
        Write-Host 'Next: ./scripts/dev.ps1 -OpenStudio; Plugins > Rojo > Connect (localhost:34872).'
    }
    Write-Host 'Project tools ready. Run ./scripts/check.ps1.'
} finally { Pop-Location }
