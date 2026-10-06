# Teammate setup prompt

Ethan and Ninety can paste the same prompt below into their own Codex or Claude Code. No name substitution is needed: the agent should use that developer's own GitHub account and Git identity. The shared toolchain is already on `main`.

```text
Set up my computer to develop Loot Goblins with Ethan, Ninety, and Enrik.

Shared repository: https://github.com/EnrikR2002/Loot-Goblins

The repository already contains our tooling and instructions. Reuse them and get me working; do not recreate the setup or redesign the game. Continue automatically with safe work. Keep updates short and only interrupt me for account approval, required GUI permissions, missing personal information, or a real blocker.

1. Quickly inspect my OS, relevant installed tools, current folder, and likely existing project locations. Reuse the correct clone, preserving local changes and remotes. Otherwise clone the supplied repository into a sensible development folder. Fetch and safely sync clean local main. Never reset, force-push, discard work, or create another repository/experience.

2. Read AGENTS.md, README.md, and docs/WORKSTATION.md. Install only missing prerequisites from official sources: Git, GitHub CLI, Roblox Studio, Codex, and Claude Code; Node only if a chosen installation requires it. Preserve working versions and settings unless compatibility requires a change. Use my own GitHub account and Git identity, never Enrik's. Missing sign-in for the other AI must not block the AI I am using. Both agents must use the existing AGENTS.md; do not add CLAUDE.md or another instruction system.

3. On Windows, run ./scripts/bootstrap.ps1 in a normal user PowerShell context. Use rokit.toml's existing pins for Rojo, StyLua, and Selene. Configure the official Studio MCP for both installed AI clients. Verify the plugin and GitHub authentication are visible outside a packaged app's redirected AppData cache. On another OS, reproduce the same pinned tools/workflow using official installation instructions; report unsupported steps honestly. Never bypass checksum or signature failures.

4. Handle as much setup as possible yourself. For sign-ins, repository invitation acceptance, or Studio's MCP permission toggle, give me exact minimal clicks. If this AI session must restart to load MCP, leave a short handoff so I can continue the same setup. Preserve unrelated configuration.

5. Check the one-click path I will use every day: run `./scripts/play.ps1 -NoOpen` and confirm it builds. Then explain, in two plain sentences and with no commands, that I start the game by double-clicking "Play Loot Goblins.bat" in the repository folder and pressing Play in Studio. I do not use terminals; you run every command for me. Next, run the existing dev helper, reusing the correct Studio place and Rojo server when already running. Connect Rojo, verify a harmless source comment syncs, and restore the exact original file afterward. Run checks. Use official Studio MCP to inspect mapped scripts, run harmless assertions, start a short playtest, inspect output, then stop. The prototype world appears during Play. Verify GitHub authentication and repository write permission; report any missing access. Do not create throwaway commits or PRs just to onboard, and do not change gameplay.

If a shared repository fix is actually needed, use a short-lived chore branch, checks, and a PR. Never merge without approval. Finish with a brief READY / MANUAL ACTIONS / BLOCKERS report, distinguishing tested connections from configuration-only checks.

Leave me ready to say: "Start a task for [TASK]. Follow AGENTS.md, handle sync/branch/checks/testing, and open a PR. Wait for my approval before merging."
```
