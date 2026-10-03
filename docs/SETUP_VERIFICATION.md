# Workstation verification — 2026-10-03

Enrik's workstation, shared with Ethan and Ninety through `EnrikR2002/Loot-Goblins`.

## Preserved baseline

The supplied remote was empty, and the workspace contained the original ZIP plus two design/readme documents. The initial `main` commit (`a3d7185`) imports that distribution unchanged. Original archive SHA-256: `0b6e9582dd80d072564c932bf101d2d4804e557c93e0650a72b79ee087b022c6`.

All workstation changes use `chore/setup-verification`. Gameplay source changes are only StyLua formatting and six explanatory/scoped lint comments. Each script was compared against a formatted copy of the original ZIP source; they match after removing those comments. `default.project.json` and `Config.lua` retain the original contents.

## Confirmed locally

- Git 2.38.0, GitHub CLI 2.102.0, Node 22.16.0 (existing), Codex CLI 0.159.0-alpha.12.1, and Claude Code 2.1.288 execute.
- GitHub CLI authenticates as EnrikR2002 using the OS keyring; the supplied repository is accessible with admin permission. Baseline push/fetch works and local `main` equals `origin/main`.
- Rokit 1.2.0 selects Rojo 7.7.1, StyLua 2.5.2, and Selene 0.32.0 from `rokit.toml`.
- `./scripts/check.ps1 -Fix` and normal checks pass: formatting, zero Selene errors/warnings/parse errors, Rojo build, and Git whitespace check.
- Bootstrap was rerun and preserved hashes of instructions, pins, project mapping, and all three scripts. PowerShell parses all helper scripts.
- Bootstrap and checks also pass from an ordinary, unpackaged Windows PowerShell process, preserving those protected file hashes. The existing Codex CLI directory was added to the user PATH without reinstalling it. GitHub CLI's account metadata uses a shared per-user configuration directory outside packaged `AppData`; the token remains in the OS keyring. Native Windows PowerShell authenticates and queries GitHub as EnrikR2002, so Claude and Codex can use the same GitHub access. Existing app configuration copies were preserved.
- A fresh clone of the pushed setup branch passes headless bootstrap and checks, leaves Git clean, and builds a byte-identical place (SHA-256 `260394753587d08dcb1ca3682ea6a854f883a5530a4804dc5a1a1924d506a6cd`). Checks also pass in Windows PowerShell 5.1.
- `dev.ps1` builds and serves the mapped project on `127.0.0.1:34872`; the local server responds successfully.
- Setup commit/push/PR creation succeeded: https://github.com/EnrikR2002/Loot-Goblins/pull/1. GitHub's Formatting, lint, and Rojo build check passed. The PR is open and unmerged.
- Roblox Studio 0.741.19.7411056 installed from a valid Roblox-signed official installer. The package-manager manifest had a stale checksum; no hash validation was bypassed.
- The official matching Rojo Studio plugin was downloaded and checksum verified. Both AI clients have the official `Roblox_Studio` stdio launcher registered; existing unrelated settings/servers were preserved.
- Claude Code's built-in `agents-md` plugin logged loading the root `AGENTS.md`; a read-only smoke test identified the same branch categories and human merge-approval requirement. No `CLAUDE.md` was created.
- Studio sign-in and MCP enablement are complete. The generated local `LootGoblinsTest001.rbxlx` place is open. Its official server advertises 28 tools. Studio IDs change when reopening a place; list again when reconnecting.
- Claude Code's `mcp get Roblox_Studio` reports Connected. A fresh Codex CLI read-only session used the official MCP to list Studio instances, query Edit mode, and inspect all three mapped roots successfully. No instances or source files were modified by the connection test. Restart existing AI sessions to load the server into their tool catalogs.
- A fresh Claude Code read-only session also called the official `list_roblox_studios`, `get_studio_state`, and `search_game_tree` tools successfully. It identified the same local place in Edit mode and its mapped Config ModuleScript; the built-in loader automatically attached this repository's root `AGENTS.md`. Both AI clients can continue the same existing branch using the shared instructions; stop the previous writer first.
- Windows redirected the first plugin copy into Codex's packaged app cache. The official Rojo 7.7.1 plugin was copied to Studio's actual plugin folder with the same verified SHA-256 (`50a8d83db87deab4d65fd6100eb74396de232355b1ae89c641035d02c49db6f4`). Studio was saved/reopened; a pre-sync place snapshot was retained locally. Rojo detected and connected to `LootGoblinsTest001` at `localhost:34872`.
- Live sync passed in both directions of the file-edit test: a temporary comment in `src/shared/Config.lua` arrived in Studio through Rojo; restoring the exact original repository bytes removed it in Studio. Git remained clean.
- Official MCP Luau assertions passed in Edit mode for all mapped scripts. MCP started a single-client playtest and queried both Server and Client datamodels: both islands, spawn, bank pad, altar, Golden Idol/grab prompt, guardian, three-seat boat, and all three remotes were present. The player's Banks value was zero; the enabled HUD showed its initial objective; health was 100 and walk speed 16. Console output was empty. An official MCP screenshot showed the world/HUD, and MCP stopped play and confirmed return to Edit mode. No gameplay source was changed.

## Remaining verification

- The setup PR must remain unmerged until human review/playtest approval. `main` contains only the preserved initial prototype until then; teammates can check out the setup branch to review it.
- Enrik has admin/write access. Existing write-access invitations for `Ninety-7` and `syferhalo` are pending acceptance; those accounts cannot yet be counted as verified team writers. This setup did not create those invitations, change ownership, or publish a Roblox experience.
- Three-player fun testing is a human test. No production features, frameworks, or gameplay redesign were added.
