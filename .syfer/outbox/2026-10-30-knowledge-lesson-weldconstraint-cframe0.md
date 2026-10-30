# Pending Knowledge lesson: generated models need WeldConstraint `CFrame0`

Status: **pending**. Do it after Factory PR #7 (https://github.com/EnrikR2002/SYFER-Roblox-Factory/pull/7, Library item `syfer.asset.pirate-boat`) is merged. It must not delay that asset.

Draft lesson (generalizable): a `.rbxmx` or model file generated or written outside Studio must give every `WeldConstraint` a `CFrame0` (the Part1 frame in Part0's space) and an identity `CFrame1` (`Part1 = Part0 * CFrame0 * CFrame1^-1`). With only `Part0`/`Part1` the model looks right and passes numeric checks while it sits in `ReplicatedStorage`, but the moment a clone is in `Workspace` every welded part snaps onto Part0. Measure offsets on a clone inside Workspace, and look at it.

Evidence: five variants built through Rojo and opened in Studio. `CFrame0 = relative, CFrame1 = identity` kept the offset; `CFrame0 = identity, CFrame1 = inverse` kept it; `CFrame0 = inverse` and no CFrame at all collapsed; a legacy `Weld` with `C0 = relative` kept it. Rojo writes the refs as `Part0Internal`/`Part1Internal`. Only the visual comparison against the original boat caught it; the first numeric check had measured the template, not a live clone. More detail is in the Factory PR #7 description and in the Factory's `library/assets/pirate-boat/README.md` ("Gotchas").

To finish: add the lesson under `docs/learning/` and run `./scripts/memory.ps1 submit` (see `AGENTS.md`), attach the notebook PR, then delete this note.
