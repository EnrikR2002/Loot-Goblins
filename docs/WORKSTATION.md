# Loot Goblins workstation

One repository: https://github.com/EnrikR2002/Loot-Goblins. One task branch and PR at a time. One instruction file: `AGENTS.md`.

For AI-led onboarding, paste the [teammate setup prompt](TEAM_SETUP_PROMPT.md) into Codex or Claude Code. The agent should use the existing helpers and only ask you for steps that require your account or GUI approval.

## First time (Windows x64)

If this computer already works on another of our games, Git, Studio, the AI clients, Rokit and the MCP setup are done: clone this repository, run `./scripts/bootstrap.ps1` (safe to rerun) and skip to step 6.

1. Install Git, GitHub CLI, Roblox Studio, and your chosen AI client if missing. Use the official installers. `winget install --id Git.Git --exact` and `winget install --id GitHub.cli --exact` install the Git tools. Studio: https://create.roblox.com/.
2. Clone the repository and open its folder in Codex or Claude Code.
3. Run `./scripts/bootstrap.ps1` from a normal PowerShell terminal in the repository folder. It installs Rokit if missing, downloads the three pinned tools, prepares the matching Rojo plugin, and adds the official Studio MCP launcher to both installed AI clients. Existing same-name MCP configurations are preserved for inspection. Run it again after first launching/signing into Studio, or after a reviewed tool-pin update.
4. Sign in to Studio and your AI client. Run `gh auth login --hostname github.com --git-protocol https --web` once for GitHub CLI. Configure your own Git name/email if missing. Enrik must grant Ethan/Ninety repository write access using their real GitHub usernames; public clone access does not grant push access.
5. Open the generated development place first (the welcome screen has no Assistant controls). Click the **Assistant icon at the top right > ... beside the Assistant model name > Settings > MCP Servers > Enable Studio as MCP server**. Older Studio layouts call the menu item **Manage MCP Servers**. Bootstrap already registers both AI clients, so no API keys or additional quick-connect setup are needed. Restart Codex and your Claude Code session after enabling MCP. A green connected-client indicator confirms the connection. Never install an unofficial Roblox MCP server for this workflow.
6. Run `./scripts/dev.ps1 -OpenStudio`. In the generated local place, click **Connect** on Rojo's detected-server notification, or **Plugins > Rojo > Connect**, using `localhost:34872` (this game's port; other games of ours use different ports, so enter the right one when several are open). Keep the terminal running. If prompted, allow the Rojo plugin to contact that localhost server, then review the initial sync. Restart Studio once if Rojo was just installed and its button is missing. The blank sky in Edit mode is expected: Test 001 creates its islands and objects when you press Play.
7. Tell the AI your task. It reads `AGENTS.md`, handles branch/sync/checks/push/PR, and waits for your playtest/review approval before merging.

The guide assumes Windows x64 for automatic Rokit installation. Other systems use the official [Rokit installer](https://github.com/rojo-rbx/rokit) and the same `rokit.toml` pins.

## Playing without a terminal

Ethan and Ninety play by double-clicking **`Play Loot Goblins.bat`** in the repository folder. It runs `scripts/play.ps1`:

1. Refuses to continue if Loot Goblins is already open in Studio, and says to close that window (two Studio copies lock the same place file). A Studio open on a different game does not matter.
2. Fetches GitHub and fast-forwards the checked-out branch, only when there are no local changes. Otherwise it warns and plays what is on the computer.
3. Installs the project tools if they are missing.
4. Rebuilds `build/LootGoblinsTest001.rbxlx` and opens it in one visible Studio.
5. Prints the next steps: press Play, press `H`.

No Rojo connection is needed to play. The built place holds all scripts, and the server builds the world on Play. Rojo live sync is for the AI editing code.

To try a teammate's changes, the human tells their AI which branch or PR. The AI follows the "Teammates who do not use terminals" section of `AGENTS.md`. It switches branches, runs `./scripts/play.ps1`, and explains how to play. `./scripts/play.ps1 -NoOpen` builds without opening Studio (for AI checks).

## Daily commands (the AI can run these)

```powershell
./scripts/play.ps1                  # What the .bat runs: update, build, open Studio (refuses if Loot Goblins is already open)
./scripts/bootstrap.ps1             # Safe to rerun; never changes Git history or gameplay
./scripts/dev.ps1 -OpenStudio       # Build the place, open a visible Studio (only if none runs), serve on loopback
./scripts/dev.ps1                   # Build/serve without launching another Studio window
./scripts/check.ps1                 # Formatting, lint, Rojo build, whitespace
./scripts/check.ps1 -Fix            # Format with StyLua AST verification, then check
```

Scripts work from another current directory as well. GitHub runs the same tools/checks on PRs and `main`. The generated `build/` directory is ignored. Do not keep permanent Studio-only work in a generated place: export source-controlled `.rbxmx`/`.rbxm` content and map it with Rojo, or record an accessible Roblox asset ID and required permissions in the project. This setup does not create or publish a new Roblox experience.

Rojo manages `src/shared` under `ReplicatedStorage.LootGoblins`, `src/server` under `ServerScriptService.LootGoblinsServer`, and `src/client` under `StarterPlayer.StarterPlayerScripts.LootGoblinsClient`. The scripts retain their original names, including `Main`, inside those folders.

## Two prompts

**Start:** Start a new task for [TASK]. Sync with main first, create the appropriate isolated task branch, read AGENTS.md, inspect the relevant existing systems, implement only this task, use Roblox Studio MCP where useful, run checks, test it, commit, push and open a PR. Do not merge until I approve the result.

**After approval:** The PR passed our playtest/review. Sync it against latest main, resolve normal conflicts, rerun checks, merge it if everything is clean, delete the completed remote branch if safe, and update my local main.

**Switch AI:** Stop the current writer first. Open the same folder/branch in the other AI and say: Read AGENTS.md, Git status, branch, recent commits, relevant files, outstanding TODOs/tests, and the previous handoff. Continue this task. Approval status is [STATUS]. Do not start over or merge unapproved work.

## Studio verification

The AI should list Studio instances first and reuse the window you already have open; it must never open a second copy of the same place (see the "file is in use" entry under Troubleshooting). If another of our games is also open in Studio, it must pick the window whose place is `LootGoblinsTest001`. It then selects this local place's ID, inspects the mapped folders/scripts, and run a harmless Luau assertion. For relevant changes, start play mode, inspect the generated world/HUD and console output, then stop. To verify live Rojo sync without changing gameplay, temporarily add a comment to a mapped source file, confirm it arrives in Studio, and restore the file.

Human fun test: **top-left Test dropdown > Server & Clients > set player count to 3 > blue Play button** (older layouts: **Test > Start**, 3 players). Check grab, carry slowdown, grapple/steal, Q drop, guardian, boat, bank, and reset with Ethan/Ninety. A build or single-client smoke test does not prove the three-player loop is fun.

## Troubleshooting

- **Rojo says "address in use"** means a Rojo server for this game is already running (often started together with Studio). Use it, or stop it before starting another. Each of our games has its own port (`$RojoPort` in `scripts/common.ps1`; Loot Goblins uses the plugin default, 34872). If the Rojo plugin connects to the wrong game, enter the right port by hand.
- **"This file is currently in use by another Studio instance or is read-only"** means a second Studio copy has the place open. Earlier versions of `dev.ps1` opened Studio with a hidden window, so you could have a copy running that you never saw. Fix: close every Studio window, press Ctrl+Shift+Esc, open the **Details** tab, and end any leftover `RobloxStudioBeta.exe`. Then open `build\LootGoblinsTest001.rbxlx` once. Now `dev.ps1 -OpenStudio` opens a visible window and refuses to start a second copy. AI helpers must not force-kill Studio; they ask you to close it.
- **Working on two of our games at once** (for example Claude on Loot Goblins and Codex on another game) is fine. Each game has its own Rojo server and port, its own Studio window and its own place file, so they do not share state. Two things cross over: the Studio MCP lists **every** open Studio to **every** AI client (each AI must pick the window named for its own game and leave the other alone), and the Rojo plugin remembers one host and port, so connect each Studio window to its own game's port by hand. Expect slower Studio and screenshots with two windows open.
- **Rojo drops out during AI testing.** The plugin disconnects each time play mode starts or stops, and Rojo 7.7.1 can crash if a watched file vanishes mid-write. If an AI runs long Studio tests, it should serve Rojo in a restart loop and reconnect the plugin after every play session. Without that, Studio can silently run old scripts.
- **Screenshots time out or Studio freezes** when the display goes to sleep. Keep the display awake while an AI tests in Studio.
- Run bootstrap again after missing prerequisites are installed. It reports sign-ins and Studio toggles that need you. `-Headless` installs only project tools for CI; it does not set up Studio or AI clients.
- If Studio's newer registry layout prevents `rojo plugin install`, bootstrap downloads the matching official `Rojo.rbxm` release, verifies its SHA-256, and preserves an existing different local plugin in a `.bak` file.
- Packaged Windows apps can redirect `AppData` writes into their own cache. If bootstrap reports a plugin but Studio's **Plugins > Plugins Folder** is empty, rerun bootstrap from a normal PowerShell terminal, then restart Studio. This occurred in Enrik's Codex app; the verified plugin was copied to Studio's actual folder and live sync was confirmed.
- Official MCP on Windows uses `cmd.exe /d /c %LOCALAPPDATA%\Roblox\mcp.bat`. Studio creates/manages this launcher. If it is missing, enable MCP in Studio and restart the client. Keep other MCP configurations intact.
- Claude Code 2.1.281+ is recommended for direct `AGENTS.md` support across providers. Verify `/memory` or `/context` lists the root file. A project/ancestor `CLAUDE.md` can take precedence; do not add a competing one. [Official Claude memory documentation](https://code.claude.com/docs/en/memory).
- MCP testing from a new client session requires Studio open and MCP enabled. [Official Roblox MCP instructions](https://create.roblox.com/docs/studio/mcp), [Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).
