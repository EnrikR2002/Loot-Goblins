# Stand-in merge fixes (2026-10-27)

Two bugs found by a whole-repo audit on main (2467b6e, V14). Both happen only on the stand-in path: a goblin whose saved profile cannot be opened yet (another server still holds its lock, for example after a crash, for up to 3 minutes) plays on a blank stand-in, which is merged into the real profile when it opens.

## What was wrong

1. **Rewards paid twice.** Achievements were checked on the stand-in, which starts from zero. A veteran who banked one treasure there unlocked First Haul again (+25 Shinies), and a win re-announced Raid Champion to the server; the Shinies then merged into the real profile. The stand-in also started with empty daily caps, so a goblin who had already earned today's Port game cap could earn a second full one, and challenge wins paid past their daily and per-opponent caps.
2. **Personal bests replaced by worse scores (V14).** V14 keeps bests under record keys (`golf2`, `regatta2:<class>`). The merge compared them with `PortGames.better`, which looked the key up as a game id, found nothing and treated higher as better. A 24-stroke stand-in round replaced an 18-stroke best; a slower lap replaced a faster one.

## What changed

- `server/Progress.lua`: achievements unlock only when the session is `ready` (one `unlock` helper used by banking and deeds, `Progress.checkAchievements` and the raid payout). `adopt()` already checks them on the merged stats when the real profile opens, so nothing earned is lost; it is announced then.
- `server/Economy.lua` `mergePort`: on the same day, Port game Shinies the stand-in paid beyond what was left of the real profile's daily cap (`Config.PLAYGROUND.DAILY_SHINIES`) are taken back.
- `server/Challenges.lua`: a challenge win or tie pays only on an open profile (like buying and claiming). The win still counts toward stats and quests.
- `shared/PortGames.lua`: `lowerWins` (and so `better`) also takes a record key, so merges compare golf strokes and Regatta laps the right way.

## Evidence

- New `EconomySpec` tests: a veteran's stand-in earns no achievement twice; stand-in Port game Shinies past the cap go back (and within the cap are all kept); merged bests keep the better golf round and lap, keep a first lap in a new boat, and take a genuinely better round.
- `PortGamesSpec`: every game's record key is lower-is-better, like its id.
- `./scripts/check.ps1`: StyLua, Selene (0 errors, 0 warnings), both Rojo builds, `git diff --check` and the notebook tests pass.
- **160 Luau tests pass** in Studio's Edit mode on the test place built from this branch (157 before; 3 new in `EconomySpec`), 0 failed.
- No Play-mode playtest: the change is to profile merging, which only runs on the stand-in path.

## Limits

- The Port games' per-game run cap (`DAILY_RUNS`) is not reconciled at the merge; the Shinies cap bounds what a day's games pay in total.
- A goblin who wins a challenge while on a stand-in now gets no challenge Shinies for it (rare; previously it could bypass the caps).

## Human checks

None needed for normal play: the stand-in path only appears when a save cannot open. If you ever see "Your saved progress is still being closed by another server", check that no achievement you already own pops up again.
