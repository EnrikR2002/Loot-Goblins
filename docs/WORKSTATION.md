# Loot Goblins workstation

One repository: https://github.com/EnrikR2002/Loot-Goblins. One task branch and PR at a time. One instruction file: `AGENTS.md`.

## First time (Windows x64)

1. Install Git, GitHub CLI, Roblox Studio, and your chosen AI client if missing. Use the official installers. `winget install --id Git.Git --exact` and `winget install --id GitHub.cli --exact` install the Git tools. Studio: https://create.roblox.com/.
2. Clone the repository and open its folder in Codex or Claude Code.
3. Run `./scripts/bootstrap.ps1`. It installs Rokit if missing, downloads the three pinned tools, prepares the matching Rojo plugin, and adds the official Studio MCP launcher to both installed AI clients. Existing same-name MCP configurations are preserved for inspection. Run it again after first launching/signing into Studio, or after a reviewed tool-pin update.
4. Sign in to Studio and your AI client. Run `gh auth login --hostname github.com --git-protocol https --web` once for GitHub CLI. Configure your own Git name/email if missing. Enrik must grant Ethan/Ninety repository write access using their real GitHub usernames; public clone access does not grant push access.
5. In Studio: **Assistant > ... > Manage MCP Servers > Enable Studio as MCP server**. Restart the AI client after MCP registration. A green connected-client indicator confirms the connection. Never install an unofficial Roblox MCP server for this workflow.
6. Run `./scripts/dev.ps1 -OpenStudio`. In the generated local place: **Plugins > Rojo > Connect**, using `localhost:34872`. Keep the terminal running. If prompted, allow the Rojo plugin to contact that localhost server, then review the initial sync. Restart Studio once if Rojo was just installed and its button is missing.
7. Tell the AI your task. It reads `AGENTS.md`, handles branch/sync/checks/push/PR, and waits for your playtest/review approval before merging.

The guide assumes Windows x64 for automatic Rokit installation. Other systems use the official [Rokit installer](https://github.com/rojo-rbx/rokit) and the same `rokit.toml` pins.

## Daily commands (the AI can run these)

```powershell
./scripts/bootstrap.ps1             # Safe to rerun; never changes Git history or gameplay
./scripts/dev.ps1 -OpenStudio       # Build the local place, open Studio, serve on loopback
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

The AI should list Studio instances, select this local place's ID, inspect the mapped folders/scripts, and run a harmless Luau assertion. For relevant changes, start play mode, inspect the generated world/HUD and console output, then stop. To verify live Rojo sync without changing gameplay, temporarily add a comment to a mapped source file, confirm it arrives in Studio, and restore the file.

Human fun test: **Test > Server & Clients > 3 clients > Start** (older layouts: **Test > Start**, 3 players). Check grab, carry slowdown, grapple/steal, Q drop, guardian, boat, bank, and reset with Ethan/Ninety. A build or single-client smoke test does not prove the three-player loop is fun.

## Troubleshooting

- Run bootstrap again after missing prerequisites are installed. It reports sign-ins and Studio toggles that need you. `-Headless` installs only project tools for CI; it does not set up Studio or AI clients.
- If Studio's newer registry layout prevents `rojo plugin install`, bootstrap downloads the matching official `Rojo.rbxm` release, verifies its SHA-256, and preserves an existing different local plugin in a `.bak` file.
- Official MCP on Windows uses `cmd.exe /d /c %LOCALAPPDATA%\Roblox\mcp.bat`. Studio creates/manages this launcher. If it is missing, enable MCP in Studio and restart the client. Keep other MCP configurations intact.
- Claude Code 2.1.281+ is recommended for direct `AGENTS.md` support across providers. Verify `/memory` or `/context` lists the root file. A project/ancestor `CLAUDE.md` can take precedence; do not add a competing one. [Official Claude memory documentation](https://code.claude.com/docs/en/memory).
- MCP testing from a new client session requires Studio open and MCP enabled. [Official Roblox MCP instructions](https://create.roblox.com/docs/studio/mcp), [Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli).
- `main` must exist for PRs. The empty remote was initialized with the original, unchanged Test 001 distribution; all setup changes are reviewed separately on `chore/setup-verification`.
