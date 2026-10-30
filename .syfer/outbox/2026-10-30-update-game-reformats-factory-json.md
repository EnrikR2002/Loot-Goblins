# update-game.ps1 rewrites the whole factory.json

Pending Factory contribution (not yet published). Found during the Loot Goblins 0.1.0 to 0.1.1 migration (`docs/reports/2026-10-30-factory-0.1.1-migration.md`).

`scripts/update-game.ps1` writes `.syfer/factory.json` with Windows PowerShell 5.1 `ConvertTo-Json`. Changing three values (`factoryVersion`, `factoryCommit`, `lastMigratedAt`) reformatted the whole file: 4-space indent, `"key":  value` spacing, `'` escapes, a blank-lined empty `{}`, CRLF line endings. The data was preserved exactly (checked by parsing before and after), but a game's PR shows about 60 changed lines for a 3-value change.

Suggested fix: edit only those three fields in place (keep the file's formatting and line endings), or emit stable formatting with an LF-only writer.
