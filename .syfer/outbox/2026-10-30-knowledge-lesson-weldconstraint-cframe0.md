# Pending Knowledge lesson: generated models need WeldConstraint `CFrame0`

Status: **submitted, waiting for a human to merge** the Knowledge PR: https://github.com/EnrikR2002/SYFER-Roblox-Knowledge/pull/22

It was opened on a `chore/` branch on purpose, not through `memory.ps1 submit`: `submit` makes a `learning/` PR that the notebook's publish workflow merges automatically within seconds, and a human asked that this one not be merged automatically. Its files are exactly what `submit` would have produced.

The durable local record is `docs/learning/generated-welded-models-need-cframe0-and-a-workspace-check.json` (the lesson, its limits and its evidence at exact commits). The first version of this note, with the five-variant results, is kept in Git history at `f061b9a` and is linked from that record as evidence. The source of the finding is Factory PR #7 (https://github.com/EnrikR2002/SYFER-Roblox-Factory/pull/7, Library item `syfer.asset.pirate-boat`).

To finish, after the Knowledge PR is merged:

1. Run `./scripts/memory.ps1 read`. It should report one more shared lesson than before (63) including this one.
2. Run `./scripts/memory.ps1 submit`. It should say "No unshared local lessons; confirmed matching records are already in the notebook." If it opens a new PR instead, stop: the Knowledge PR has not merged yet.
3. Delete this note.

Do not run `submit` before the Knowledge PR is merged: it would publish the same lesson automatically and clash with that PR.
