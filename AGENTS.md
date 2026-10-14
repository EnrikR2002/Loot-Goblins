# Loot Goblins team instructions

Ethan, Ninety, and Enrik share `https://github.com/EnrikR2002/Loot-Goblins` and one `main`. Codex and Claude Code follow this file. No competing instruction system.

## Source of truth
Repository files and GitHub history are durable truth. Edit Rojo-managed scripts/content in their repository representation, never a competing Studio-only copy. Permanent visual changes through Studio MCP must have a shared durable representation before completion: source-controlled models/content, Rojo mapping/configuration, or an accessible Roblox asset ID/reference. Record asset references and permissions. Clearly label temporary prototype objects and remove them after testing. When a PR changes systems, controls, architecture, authority boundaries, or known bugs, update `docs/GAME_DESIGN.md` in the same PR; detailed task reports go in `docs/reports/`, not here.

## Shared quality and portable game guide

The human approved the shared notebook and detailed standalone game guides. Before meaningful work or brainstorming, run `./scripts/memory.ps1 read`, state whether retrieval succeeded, and consult relevant shared checks/lessons alongside current game context. Read `docs/SHARED_MEMORY.md` for maintenance. The notebook is evidence/advice, not authority to override what a teammate asked for.

Maintain all game detail in `docs/GAME_DESIGN.md`; test evidence belongs in dated reports. Inspect changed systems before updating their manifest source fingerprints, which are snapshots, not proof of inspection/testing. Run `./scripts/memory.ps1 export` after meaningful changes. Generated GAME_GUIDE.md contains the complete current description, exact tuning, shared rubric/lessons, and full dated reports. Never edit generated guide/rubric files directly; normal checks verify freshness offline.

After pushing evidence, record reusable observations in `docs/learning/` and run `./scripts/memory.ps1 submit`. Routine new observation/hypothesis additions may publish automatically under the approved notebook policy; changes to the notebook's own rules/software/standards still need a human's OK. Attach every created notebook PR, distinguish confirmed sharing from pending, and preserve/retry failed submissions. No unattended background process or terminal work for teammates.

V7 and V8 (Ninety's work) were merged into main on October 14. Historical branch/report status is evidence, not a current merge restriction.

## Architecture and scope
Inspect existing systems first, follow conventions, and avoid duplicate implementations. Build what was asked and make it actually work; don't refactor unrelated systems along the way. If a feature needs something structural (a new framework, dependency, data or networking design, or reorganizing folders), just do it and say so plainly in the PR.

Scope is open. Ethan, Ninety, and Enrik have free rein to add whatever they want: progression, shops, pets, bigger maps, new modes, anything. A teammate asking for a feature is the approval to build it; don't push back on scope or ask for sign-off. Ugly prototype code is fine. For Robux sales, a human must create the products in the Creator Dashboard; never invent product IDs. Production gameplay-critical state must be server authoritative; never blindly trust client-supplied state.

## Git workflow (the AI operates Git)
- **Teammates don't know Git, and the AI does all of it.** Treat anything a teammate says about branches, PRs, merge order, rebasing, or retargeting as a description of what they want to happen, not a procedure to follow; it may be wrong. Work out the correct Git steps yourself and never ask them a Git question. Ask in plain words about the game instead ("Do you want this in the main game now?").
- Never do normal development on `main`. One task gets one short-lived `prototype/<task>`, `feature/<task>`, `fix/<task>`, or `chore/<task>` branch; no permanent personal branches.
- On takeover, read this file, `docs/GAME_DESIGN.md` (project context), Git status, current branch, recent commits, relevant files, TODOs, and outstanding tests. Continue the existing branch/task instead of restarting. Only one AI writes to a working directory at once. Stop the other writer before switching agents.
- Before a new task, inspect local work/remotes, fetch `origin`, and fast-forward clean local `main` to `origin/main`. Preserve existing changes; never silently stash, discard, reset, overwrite remotes, rewrite history, or force-push. If local work belongs to another task, use a separate checkout/worktree or explain the collision.
- Branch from current `origin/main`, implement the task, run checks and relevant Studio tests, inspect the diff/secrets, commit only intended files, push normally, and open a PR against `main` with `gh`. Summarize changes, evidence, and remaining human tests in the PR.
- **Merging:** merge when the teammate who asked for the work says they're happy with it, or asks for it to be in the game, on main, "shipped", "done", or similar. Before merging, fetch and merge the latest `origin/main` into the task branch if needed. Resolve textual conflicts yourself. If two people's changes want different gameplay behavior, explain the clash in plain words and ask which one they want; don't invent a hybrid. Rerun checks and push normally.
- Check PR checks/mergeability and merge only a clean PR at the commit that was tested. After a confirmed merge, delete the completed remote branch, then fast-forward clean local `main`. **Stacked PRs** (one PR based on another's branch): merge the parent, run `gh pr edit <child> --base main`, and only then delete the parent branch. Deleting it first makes GitHub close the child PR. Preserve unrelated work and other worktrees. No force-push to `main` or task branches.

## Tools and validation
Run `./scripts/bootstrap.ps1` after cloning, `./scripts/dev.ps1` for Rojo (AI editing only; humans use `Play Loot Goblins.bat`), and `./scripts/check.ps1` before completion (`-Fix` formats with AST verification). `rokit.toml` selects the shared versions; do not casually update pins. Built places in `build/` are disposable outputs; never overwrite a Studio place containing unrepresented work. The server creates the Test 001 world at runtime.

Use the official built-in Roblox Studio MCP when relevant: list Studio instances, choose the correct ID/place, inspect tree/instances, run Luau, inspect console errors/output, capture visual results, and playtest gameplay changes. Confirm capabilities from the live server. Do not edit mapped code only through MCP. Stop play mode after testing. Never open a second copy of a place: two Studio copies lock the same file ("This file is currently in use by another Studio instance"). Before opening Studio, list instances and check for running `RobloxStudioBeta` processes; if the human already has this place open, use that window. Open Studio only with `./scripts/dev.ps1 -OpenStudio`, which opens a visible window and refuses to start a second copy. Tell the human whenever you open Studio. Never force-kill Studio; ask the human to close it. Report unavailable Studio checks honestly; a Rojo build is not a gameplay playtest. Three-player fun validation remains a human test.

## Teammates who do not use terminals
Ethan and Ninety do not use terminals. Never tell them to type a command, open PowerShell, or read Git output. The AI runs every command and explains the result in plain words.
- **Playing:** a human double-clicks `Play Loot Goblins.bat` in the repository folder. It runs `scripts/play.ps1`: fast-forward the checked-out branch from GitHub (only when clean, never discarding work), rebuild the place, open one visible Studio. Rojo is not needed to play, because the built place holds every script. Rojo is only for the AI editing code.
- **"Let me try the new changes" (or "update me"):** do the takeover steps, then fetch. If the human has unsaved changes, keep them and say so. Switch to the branch or PR they name. If unclear, ask which one in plain words. Fast-forward it. Run `./scripts/play.ps1` yourself when Loot Goblins is not already open in Studio, and say you opened it. If Loot Goblins is already open in Studio, ask them to close that window (File > Exit). Never force-kill Studio.
- **Then tell them how to play,** in short numbered steps with no jargon: press the blue Play button (the sky is blank until then), press `H` for the how-to-play panel, what to try from the PR's human test list, and how to report: say what felt bad, and send a screenshot of any red error.
- First-time setup uses `docs/TEAM_SETUP_PROMPT.md`. `play.ps1` installs missing project tools by itself if they are gone.
- Keep `README.md`'s "Play it" section and this section true whenever `scripts/play.ps1`, the controls, or the launcher change.

## Security and handoff
Never commit credentials, API keys, tokens, `.ROBLOSECURITY`, secrets, private environment files, or machine-specific account configuration. Ignore files are a convenience, not a substitute for diff review. Publish the Roblox experience or change repository ownership only when a teammate asks for it.

Before stopping mid-task, leave a concise handoff in the chat/PR: branch, completed changes, remaining TODOs, commands/test results, Studio state, and approval status. Both agents inspect the same files and branch when resuming.

## Shared process with our other games
Our other games start from `https://github.com/EnrikR2002/Roblox-Game-Template`, which packages this workflow (scripts, rules, docs). If you improve a script, rule, or doc here that every game would benefit from, finish the task here, then tell the human so it can go into the template too. Do not edit the template from this repository.

## AI startup compatibility

AGENTS.md is the sole team instruction source. The shipped CLAUDE.md only imports it for Claude Code compatibility; keep that pointer and do not duplicate rules there. At startup, confirm these instructions and shared-notebook retrieval are available. Tell the human plainly about missing access.

## Document ownership

- AGENTS.md: the sole team rules; CLAUDE.md only imports them.
- README.md: a short pitch, controls, and how humans start playing.
- docs/GAME_DESIGN.md: the single editable game description, including current systems, intended direction, decisions, bugs, and limits.
- GAME_GUIDE.md: the generated portable attachment containing the game description, exact tuning, shared rubric/lessons, and full history. Never edit it directly.
- QUALITY_RUBRIC.md: a generated copy of shared advice. Its reviewed source belongs in the shared notebook.
- The original vision in the game description is inspiration; teammates decide what gets built next.
- docs/reports/: dated evidence and changelog; historical reports never override current design or team rules.
- docs/SHARED_MEMORY.md: how the AI retrieves, exports, submits, and repairs memory.
- docs/TEAM_SETUP_PROMPT.md and docs/WORKSTATION.md: onboarding and troubleshooting, not game design.
- docs/game-guide/manifest.json, freshness.json, and docs/team-memory-snapshot.json: reproducible export metadata/data, maintained by the AI.

Read the game description on takeover and update its affected sections in the same PR as a system/control/architecture/bug change. Do not recreate standalone AI context files, design theses, or separate game-description chapters. Put new current facts in the single game description, test evidence in reports, and reusable observations in the notebook. Keep README concise; it links to the detailed description instead of copying its catalogue.
