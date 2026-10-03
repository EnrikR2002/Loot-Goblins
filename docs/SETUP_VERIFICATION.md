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
- A fresh clone of the pushed setup branch passes headless bootstrap and checks, leaves Git clean, and builds a byte-identical place (SHA-256 `260394753587d08dcb1ca3682ea6a854f883a5530a4804dc5a1a1924d506a6cd`). Checks also pass in Windows PowerShell 5.1.
- `dev.ps1` builds and serves the mapped project on `127.0.0.1:34872`; the local server responds successfully.
- Setup commit/push/PR creation succeeded: https://github.com/EnrikR2002/Loot-Goblins/pull/1. GitHub's Formatting, lint, and Rojo build check passed. The PR is open and unmerged.
- Roblox Studio 0.741.19.7411056 installed from a valid Roblox-signed official installer. The package-manager manifest had a stale checksum; no hash validation was bypassed.
- The official matching Rojo Studio plugin was downloaded and checksum verified. Both AI clients have the official `Roblox_Studio` stdio launcher registered; existing unrelated settings/servers were preserved.
- Claude Code's built-in `agents-md` plugin logged loading the root `AGENTS.md`; a read-only smoke test identified the same branch categories and human merge-approval requirement. No `CLAUDE.md` was created.
- Studio sign-in and MCP enablement are complete. The generated local `LootGoblinsTest001.rbxlx` place is open. Its official server advertises 28 tools and lists this place as Studio ID `4ff1c02c-d747-4091-a17c-185fe797f3d1` (session-specific; list again when reconnecting).
- Claude Code's `mcp get Roblox_Studio` reports Connected. A fresh Codex CLI read-only session used the official MCP to list Studio instances, query Edit mode, and inspect all three mapped roots successfully. No instances or source files were modified by the connection test. Restart existing AI sessions to load the server into their tool catalogs.

## Remaining verification

- Live Rojo plugin sync, harmless Luau execution, and gameplay playtests remain to be exercised. The generated place's mapped source is visible through Studio MCP, but this connection test did not start play mode or change a source file to test live sync.
- The setup PR must remain unmerged until human review/playtest approval. `main` contains only the preserved initial prototype until then; teammates can check out the setup branch to review it.
- Only Enrik is currently listed as a GitHub collaborator. Ethan/Ninety need repository write access under their real GitHub usernames before they can push team PRs. This setup does not invent usernames, send invitations, change ownership, or publish a Roblox experience.
- Three-player fun testing is a human test. No production features, frameworks, or gameplay redesign were added.
