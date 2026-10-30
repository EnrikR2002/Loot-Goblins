# Assets

Models and reusable pieces that are not code. Rojo maps this folder to `ReplicatedStorage.LootGoblinsAssets`, so every file here is in the game on the next build; server code clones what it needs (`Assets.Chair:Clone()`).

- **A model built in Studio:** right-click it > **Save to File...** > save as `assets/<Name>.rbxmx` in this folder (text format, so Git can diff it). Anything left only in Studio is lost on the next build.
- **A SYFER Factory Library item** (chairs, boats, swords, UI...): the AI installs it with the Factory's `scripts/install-library.ps1`; it lands in `assets/<item>/` and is recorded in `.syfer/factory.json`. Do not edit installed items here; keep game-specific tuning in `src/` and improve the shared item in the Factory.

Rojo ignores this README.
