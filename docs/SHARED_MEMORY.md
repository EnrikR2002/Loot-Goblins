# Your game guide and our shared notebook

Each game has **GAME_GUIDE.md**, a detailed description you can give to any AI. It includes the game's mechanics, controls, exact tuning, current decisions and limits, the shared quality rubric, and dated change/test reports. **QUALITY_RUBRIC.md** is the shared standard available separately.

## Ethan and Ninety: everyday use

1. Open this game's folder in Codex or Claude Code.
2. Say what you want, or what felt confusing, unfair, slow, or fun.
3. Follow the AI's playtest steps and tell it what happened.

The AI checks the shared notebook, updates this game's documents, and shares useful lessons. It handles GitHub and files. You don't need to run commands or maintain another repo. First-time access can require accepting the notebook invitation or signing in; the AI will explain those clicks.

To use a different AI, say **"Open the latest game guide so I can give it to another AI."** Attach GAME_GUIDE.md to that AI and ask for ideas or critique. The guide includes the rubric, so one attachment is sufficient. Detailed source/runtime bug confirmation still requires code and tests. The guide can be long; it does not silently omit the changelog to make a short summary.

To fix misleading advice, say **"Audit our shared lessons about [topic] against the original evidence and fix them."** The AI preserves history and distinguishes an observed result from a guess or game preference.

## For the AI maintaining this game

`docs/GAME_DESIGN.md` is the single editable game description; dated reports hold task evidence, and the separate prototype decision (where present) remains the human approval record. `manifest.json` records included chapters, appendices, the described gameplay revision, and source fingerprints. Fingerprints establish a snapshot, not that every source was audited or gameplay passed. Inspect changed systems, update their descriptions/evidence, and update only affected fingerprints. Then export. Dated reports are embedded in full as history, newest first; they never override the current game description. Historical file paths can refer to files that have since been consolidated.

Before a meaningful task, run `./scripts/memory.ps1 read` and read the relevant material in `.local/team-memory/QUALITY_RUBRIC.md`. This retrieves data from the private [shared notebook](https://github.com/EnrikR2002/Roblox-Team-Knowledge), without executing code downloaded from it. If retrieval fails, preserve the last snapshot, state it may be old, and continue independent work. Do not silently claim freshness.

After work, update affected sections in docs/GAME_DESIGN.md and dated evidence; run `./scripts/memory.ps1 export`. The normal project check includes offline guide freshness and memory regression checks. Never hand-edit generated GAME_GUIDE.md or QUALITY_RUBRIC.md. `docs/team-memory-snapshot.json` makes committed guides reproducible offline and in CI.

For a genuinely reusable observation, add an attributed JSON record under `docs/learning/` using the notebook's examples. Link the source report at an exact pushed commit, name its test/observation method, and include applicability and limits. Run `./scripts/memory.ps1 submit` after the evidence is pushed. The helper verifies source access and creates or retries an idempotent lesson PR. Attach each created PR to this chat. Check whether it actually merged before saying the lesson is shared; otherwise report it as pending. Submitted local records stay durable in the game and are recognized on retry.

Routine new observations/hypotheses may publish automatically under the shared policy. Existing records, baseline standards, software, and team rules require normal human review. Game changes retain this game's merge/playtest rules. Nobody must run the full rubric after an unrelated edit or add excluded systems to satisfy it. No process runs after the AI session closes.
