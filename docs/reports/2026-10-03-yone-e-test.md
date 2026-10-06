# Report: Yone's E (Soul Unbound) — Opus 5.5 capability test

| | |
| --- | --- |
| Date | 2026-10-03 |
| Agent | Claude Opus 5.5 (`claude-opus-5-5`) in the Claude Code desktop app, Windows, auto permission mode |
| Repository | `EnrikR2002/Loot-Goblins` (Ninety's workstation) |
| Branch | `feature/yone-soul-unbound`, from `origin/main` at `d74989c` |
| Feature commit | `b709678` "Add Soul Unbound, Yone's E, as an E-key ability" |
| Pull request | [#5 Add Soul Unbound (Yone's E)](https://github.com/EnrikR2002/Loot-Goblins/pull/5) |
| Merge status | **Not merged.** Waiting for a human playtest and explicit approval. |

## 1. The request

Ninety's message, verbatim:

> Start a task to add Yone's E from League of Legends to the game. Follow AGENTS.md, handle the implementation, testing, branch/PR workflow, and use Roblox Studio MCP as needed. Do not merge without my approval.
>
> Follow AGENTS.md, handle sync/branch/checks/testing, use the existing Roblox Studio MCP connection, and open a PR when finished. Wait for my approval before merging.
> This is primarily a capability test, so I want you to determine the Roblox implementation yourself rather than me prescribing the architecture.
>
> Make me proud

A follow-up asked for this report and `docs/AI_CONTEXT.md`, with no further gameplay changes.

## 2. Outcome in one paragraph

Soul Unbound works in a one-player Studio playtest, driven by real E key presses through the Studio MCP:

- E dashes the spirit out, and the body stays behind as a frozen clone of the avatar, tethered to the spirit.
- The spirit gets faster over 5 seconds, then snaps back exactly onto the body. A carried idol comes back with it.
- Pressing E again after 0.5 s returns early.
- Prompts still take E when they are showing.
- Death and banking clean everything up.

The checks pass locally. The marks and their repeat damage are written but **not tested**, because they need a second player. Testing stopped early when the MCP key-press tool was denied by Claude Code's permission check. The PR is open and waiting for review.

## 3. What Yone's E does in League

Source: the League of Legends wiki page for Yone, read during the session.

- He dashes a fixed distance in the target direction (through terrain) and leaves his body behind. He stays in Spirit Form for **5 s**.
- He gets **10% → 30% bonus move speed**, growing with the time spent active.
- Damage he deals to champions is stored as a mark: **25 / 27.5 / 30 / 32.5 / 35%** by rank.
- Recast is allowed **after 0.5 s**. Otherwise it recasts automatically at the end. On recast, he dashes back to his body, and the marks deal the stored damage as true damage.
- If he dies in Spirit Form, the recast fires automatically and the marks still go off.
- A mark looks different when its damage would kill the target.
- Cooldown **22 / 19 / 16 / 13 / 10 s**, starting on cast.

## 4. Design: League → Loot Goblins

| League | Loot Goblins choice | Why |
| --- | --- | --- |
| Dash toward the cursor | Dash 14 studs where you walk, or where you face if standing still | Third-person Roblox controls; matches what Roblox players expect from dashes |
| Dash passes through terrain | Physics push; walls and players stop it | Safer on a tiny map; avoids ending up inside parts |
| Body left behind | A frozen clone of the player's avatar, darkened, with a cyan outline and a beam tether | Readable at a glance by every player |
| 10% → 30% speed | Same, recalculated every Heartbeat and multiplied with the carry slowdown | Carrying still costs speed |
| Stores 25–35% of damage | 35% (max rank) of **actual** sword damage dealt | Sword is the only player-damage source; ForceField hits store 0 |
| Recast after 0.5 s, auto at 5 s | Same; E again returns early | Faithful |
| Lethal mark looks different | The diamond turns white once its repeat ≥ the target's health | Faithful, and cheap |
| Death → auto-return, marks still go off | Body removed, marks still go off, no corpse teleport | Teleporting a ragdoll adds nothing |
| Cooldown 22–10 s, starts on cast | 10 s (max rank), starts on cast | More uses per playtest round; it's a Config value |
| Key E | E, shared with ProximityPrompts. A visible prompt always wins. | Faithful key, and no conflict with grabbing the idol |

Loot Goblins-specific interactions this creates:

- **Steal and snap back.** Leave your body by the bank, dash in, grapple the idol, and get pulled home with it.
- **Risky escape.** The carrier gets a speed burst but returns to where they cast.
- **Dive and retreat.** Hit someone with the sword, then the marks hit them again after you're back.

## 5. Implementation approach

I chose an architecture that stays inside the existing conventions: no new modules, frameworks or dependencies.

- **Server (`Main.server.lua`, new "Soul Unbound" section).** It owns all state: the spirit table, the cooldown, the body clone, the tether `Beam` (from an `Attachment` in `workspace.Terrain` to the spirit's root), the spirit `Highlight` and `Trail`, the mark `BillboardGui`s, the speed ramp, the return teleport, and the echo damage.
  - The remote `SoulUnboundRequest` carries no arguments: "I pressed E". The server decides whether that means cast or recast.
  - A Heartbeat loop ends spirits whose time is up, keeps WalkSpeed updated, and colors lethal marks.
- **Client (`Main.client.lua`, new section).** It reads two player attributes, `SoulUnboundEndsAt` and `SoulUnboundReadyAt` (server time):
  - **Prediction:** the client plays its own dash right away with a `LinearVelocity`, limited to the horizontal axes, for 0.16 s. It only does this when its copy of the cooldown says ready.
  - **HUD:** a bar shows ready, the spirit time left, or the cooldown.
  - **Local effects:** a pale `ColorCorrectionEffect` on the screen, an FOV punch on the dash, and neon cast and return rings, a return streak, and pink echo slashes. These are triggered by `GameEvent` kind `SoulUnbound`.
- **Body position.** The server records it from its own copy of the root when the request arrives. The client never sends a position, so a modified client can't choose where it teleports back to.
- **Shared E.** The client tracks visible prompts (`ProximityPromptService.PromptShown/PromptHidden`) and skips casting while an E prompt is showing. It also hides the sword prompt for players who already own a sword (locally only), so it doesn't block E near spawn.
- **Hooks into existing code:**
  - `swingSword` → `markSoulDamage`
  - `Humanoid.Died` → end with `"death"`
  - `CharacterRemoving` and `PlayerRemoving` → `"cancel"`
  - `resetRound` → `"cancel"` before teleporting home
- **Config.** Eight `SOUL_*` values in `Config.lua`.

## 6. Files changed (feature commit `b709678`)

| File | Change |
| --- | --- |
| `src/server/Main.server.lua` | +289 lines: new remote, Soul Unbound section, 2 added lines in sword hits, hooks for death, respawn, leave and reset |
| `src/client/Main.client.lua` | +248 / −1 lines: E input, prompt priority, dash, HUD, screen tint, effects, help text |
| `src/shared/Config.lua` | +10 lines: `SOUL_*` values |
| `README.md` | +1 line: control description |

Documentation commit (this step): `docs/AI_CONTEXT.md`, this report, and two small `AGENTS.md` additions (`docs/AI_CONTEXT.md` added to the takeover reading list, plus one sentence on keeping it current). No gameplay code changed in that commit.

## 7. Edge cases handled in code

- Recast lockout (0.5 s), checked on both client and server. A client-side debounce covers the moment before the attributes arrive.
- Cooldown checked on the server; the client checks too only to decide whether to predict the dash.
- Casting while dead or seated is refused.
- If you sit in a seat as a spirit, the return breaks the seat weld before teleporting.
- A carried idol returns with you, because it is welded to the root and the return sets `root.CFrame`.
- Carry slowdown and spirit speed combine. Leaving spirit form restores the right speed (12 when carrying, 16 otherwise).
- Death in spirit form cleans up and still fires the marks. Respawn or leaving cleans up without them.
- A round reset cancels all spirits before the teleport home, so nobody gets pulled back to an old body.
- The body clone has scripts, tools (so nobody can pick a sword off it), force fields and billboards (so marks aren't copied) removed. All its parts are anchored and can't collide, be touched, or be hit by raycasts.
- A victim who respawns or leaves is skipped by the echo, because marks are keyed by Humanoid.
- Chain reactions are safe: each spirit is removed before its echo damage runs, so echo kills that trigger more echoes can't loop.
- The spirit tick sets WalkSpeed only in half-stud steps, so it doesn't replicate a new value every frame.

## 8. Testing performed

**Checks.** `./scripts/check.ps1 -Fix` passed twice (before and after a review fix): StyLua, Selene with 0 errors and 0 warnings, Rojo build, and whitespace.

**Sync.** Rojo live sync was confirmed: each script's `Source` length in Studio matched the repository byte size exactly. A later fix showed up in Studio without any manual action.

**Studio MCP, one-player playtests.** These used real E key presses (`user_keyboard_input`), with in-game recorders sampling state:

| Test | Result |
| --- | --- |
| E in open ground | Dash **14.7 studs in ~0.16 s**, then a clean stop (client position trace) |
| Spirit visuals | The body clone, tether, glow and trail appeared. A screenshot shows the frozen body, the tether and the glowing spirit. HUD reads `E  RETURN TO BODY 4.1`. |
| Speed ramp | 19.5 → 20.5 (normal), 13 → 14 (carrying). Back to 16 or 12 afterwards. |
| Automatic return at 5 s | Ended on time. Body, tether, glow and attributes all removed. |
| E at 0.2 s, then at ~1.2 s | The first press was ignored; the second returned early (spirit time 1.33 s) |
| Accuracy of the return | **0.00 studs** from the body position, upright, in both measured returns |
| Cooldown starts on cast | `SoulUnboundReadyAt` = cast time + 10 s |
| E next to the loose idol | **Grabbed the idol, did not cast**. Cooldown unchanged. |
| Cast while carrying, return early | The idol came back still held, 3.41 studs from the root (the normal carry offset) |
| E at the sword pedestal | Grabbed the sword, did not cast. The prompt then hid for this player only (the server copy stayed on). The next E cast. |
| Cast holding a sword | The spirit kept the sword. The body clone had 0 tools. |
| Death in spirit form | Attribute cleared. Body, anchor and glow removed. |
| Bank as a spirit | `Banks` 0 → 1. The round reset canceled the spirit after 4.34 s, and the player was sent home, not back to the body 313 studs away. No leftovers. |
| Console | Empty in every session |
| Final smoke test after the review fix | Remotes present, idol present, speed 16, console empty. Play stopped and Edit mode clean. |

## 9. Not tested

- **Soul marks and the 35% echo.** These need a second player: the sword only hits players, and single-client MCP play has one. `StudioTestService:ExecuteMultiplayerTestAsync` exists (found through `ReflectionService`) but was not tried.
- **Pressing E during cooldown, and casting while seated.** Partway through, Claude Code's auto-mode permission check denied `user_keyboard_input`, without giving a reason. I did not work around the denial (for example by firing the remote directly), and I stopped input-driven testing. The code paths are simple checks on both sides.
- **How the spirit, body and tether look to other players**, network latency, and whether it's fun. These are for the human 3-player playtest; the checklist is in PR #5.

## 10. Issues encountered and how I handled them

- **The Rojo port was already in use.** `dev.ps1` failed because a Rojo server started with Studio was already serving this clone. I confirmed through `/api/rojo` and by matching script sizes that it was syncing, and kept using it.
- **The 5-second window was shorter than MCP round trips.** The first probe missed the spirit window. I switched to recorders spawned inside the game (`task.spawn` writing to an attribute), and they worked for every later test.
- **Someone else moved the character.** Unexplained movement appeared in Studio during testing, most likely the human in the Studio window. I mentioned it and made the tests measure relative to cast-time positions.
- **The test idol was destroyed.** This is the guardian bug in section 11. I diagnosed it, stopped and restarted play, and suggested a separate fix task.
- **A wrong explanation, later corrected.** I first blamed the idol missing on the client on streaming. `workspace.StreamingEnabled` is false; the idol had simply been destroyed.
- **A flawed probe.** One cooldown test arrived after the cooldown had already expired, so it cast correctly. I recognized it and redesigned the probe. That redesign was the step the key-press denial interrupted.
- **Bug caught in self-review.** The body clone would copy a soul mark billboard from a player who was themselves marked. Fixed before committing.
- **Over-claim caught before posting.** The draft PR description claimed a check on the body clone's scripts and anchoring that never actually ran. I rewrote it to state only what was measured.
- **CI failure, not caused by the code.** The first PR run failed in "Install pinned project tools": rokit got `403 Forbidden` from `api.github.com` (rate limit) before any check ran. All earlier runs on the repository had passed. Pushing the documentation commit starts a new run.
- **Studio was reopened during the session.** The MCP `studio_id` changed. I re-listed instances, and only read-only queries followed.

## 11. Bug found: the guardian pushes a loose idol off the map (already on `main`)

- **Seen:** after the guardian knocked the idol loose, the guardian followed it with `MoveTo(idol.Position)` and kept shoving the 5-stud collidable ball. Between two tests, both crossed the water and went past x ≈ 450, the edge of the 900 × 900 water part.
  - The idol fell below `FallenPartsDestroyHeight` (−500) and was destroyed. `LootGoblinsGenerated` had no `GoldenIdol`.
  - The guardian was falling at about (466, −504, −508).
- **Cause:** `src/server/Main.server.lua` main Heartbeat. A loose idol is a `MoveTo` target and a physics obstacle at the same time, and nothing keeps it inside the play area or respawns it.
- **Impact:** the round can't be won until the server restarts. The push itself needs no player input, so it can happen in any normal playtest.
- **Not caused by this PR:** the sequence (smack → loose idol → guardian push) uses only code from `main`.
- **Suggested fix (not done, out of scope):** respawn the idol at `Config.IDOL_SPAWN` when it leaves the play area or drops below a height. Optionally, stop the guardian a few studs short of a loose idol. A separate task with these details was suggested in the Claude Code app; it has not been started.

## 12. Branch, commits, PR, and status

- `feature/yone-soul-unbound` was created from a freshly fetched `origin/main` (`d74989c`). The working tree was clean, and local `main` already matched `origin/main`.
- Commits:
  - `b709678`, the feature.
  - The documentation commit that adds this report.
- Both are pushed normally, with no force-push and no history rewrite.
- PR #5 targets `main`. It is mergeable, with no review yet. The first CI run failed in tool install (see section 10); the PR shows the run for the documentation push.
- **Not merged.** Per `AGENTS.md`, merging waits for a human playtest and explicit approval. After approval: fetch, merge the latest `origin/main` if needed, rerun checks, and merge only the approved, clean head.

## 13. Notes for evaluating the run

- **Decisions made without asking:**
  - The key binding and how it shares E with prompts
  - Client prediction plus server authority
  - Attributes as the state channel
  - The clone-of-avatar body
  - Max-rank numbers
  - Every visual
  - All edge-case handling

  The only human input was the original request.
- **AGENTS.md process followed:**
  - Read AGENTS.md and checked Git status and remotes
  - Fetched and confirmed a clean `main`
  - Created a correctly named branch
  - Before overwriting the open place file, checked that it matched a fresh build of `main`
  - Ran the checks
  - Tested in Studio through the existing MCP connection without opening a second Studio
  - Stopped play mode after each session
  - Reviewed the diff and scanned it for secrets
  - Committed only the intended files
  - Opened the PR with `gh`
  - Did not merge
- **Scope discipline:** the existing code was touched only at hook points: one line pair in the sword hit, plus death, respawn, leave and reset. The one behavior change outside the feature is the local hiding of the sword prompt for sword owners. It is a direct consequence of sharing E, and it is called out in the PR. The pre-existing guardian bug was reported, not fixed.
- **Where it stopped:**
  - Further key-press testing, after the permission denial (not worked around)
  - Two-player behavior
- **Mistakes:** the streaming misdiagnosis, a flawed cooldown probe, a missing clone filter, and an over-claim in a draft. All were caught by the agent before they reached the PR or code.
- **What humans should judge in the playtest:**
  - Whether the 14-stud dash and 10 s cooldown feel right or too strong
  - Whether other players can read the body, tether and marks
  - Whether sharing E with prompts is intuitive
  - Whether Soul Unbound improves the idol fight or distracts from it
