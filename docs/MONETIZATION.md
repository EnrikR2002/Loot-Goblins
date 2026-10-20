# Robux: setting up and testing purchases

Loot Goblins can sell a few things for Robux, but **nothing is on sale yet**. No product exists, no id is in the code, and `SALES_ENABLED` is `false`. Until a teammate does the steps below, no purchase window can open and players see no Robux prices (in Studio, premium items show as "ROBUX: NOT ON SALE" so the team can preview them).

Everything sold for Robux is either **something also earnable with Shinies** (a pet, or since V13 a boat class: Robux is only a shortcut) or **cosmetic only** (since V13 that includes a show pet with no ability at all). No Robux item makes a goblin stronger than what Shinies can buy. There are no random rewards, eggs, loot boxes or trading of any kind.

## What could be sold

`src/shared/Config.lua`, `Config.MONETIZATION.PRODUCTS`:

| Key | Grants | Also earnable? |
| --- | --- | --- |
| `pet_Crab`, `pet_Frog`, `pet_Gull`, `pet_Ghost`, `pet_Tortoise` | that pet | yes, for Shinies (100 to 220) |
| `outfit_admiral` | Admiral's Regalia (outfit) | no, premium cosmetic |
| `livery_starlit` | Starlit Galleon (boat paint) | no, premium cosmetic |
| `trail_aurora` | Aurora Ribbon (boost trail) | no, premium cosmetic |
| `petskin_crab_gold` | Golden Crab (pet look) | no, premium cosmetic |
| `boat_reefhopper`, `boat_wraith`, `boat_stormrunner`, `boat_ironbelly`, `boat_broadside` (V13); `boat_anchorjack`, `boat_wavebreaker`, `boat_corsair` (V13.2) | that boat class | yes, for Shinies (350 to 700; the V13.2 three 500, 550 and 650). Since V13.2 every class has the same speed band, so a boat pass sells a play style, not speed |
| `pet_Whelp` (V13) | the Gilded Whelp, a show pet | no, premium cosmetic: **it has no ability** |
| `petskin_wobble_moon` (V13) | Moon Jelly (pet look for Wobble) | no, premium cosmetic |
| `bundle_fleet` (V13; eight boats since V13.2) | all eight unlockable boats | yes, each for Shinies. **No catalogue item points at it, so the shop does not show it**; it is ready for a team that wants a bundle pass |

### What the team should decide (V13)

Commercially sensible, and fair: everything that changes how you play is earnable in a few hours of ordinary raids (see the V13 report's economy model), so a boat pass sells time, not power. If the team wants to sell boats at all, a price that is a convenience next to about two to four hours of play, and a bundle cheaper than the eight passes together (five in V13), would fit. A show pet or a look is pure expression. The AI does not set prices; Roblox gives the real price to the shop once a product exists.

## Turning one on

A teammate does this, not the AI: products and prices are the team's decision.

1. **Creator Dashboard** (create.roblox.com) > the Loot Goblins experience > **Monetization**.
2. Create a **Game Pass** (recommended for permanent items: Roblox itself remembers who owns it, even if our save fails) or a **Developer Product**. Give it a name, a description that says exactly what it is ("A cosmetic boat paint. Changes how your boat looks, not how it sails."), an icon, and the price the team chose. Put it on sale.
3. Copy its numeric **id**.
4. Tell the AI: "Put game pass 123456789 on livery_starlit." The AI sets, in `Config.MONETIZATION.PRODUCTS`:
   ```lua
   livery_starlit = { kind = "pass", id = 123456789, grants = { "livery_starlit" } },
   ```
   (`kind = "product"` for a Developer Product.) When every product you want is filled in, it sets `SALES_ENABLED = true`.
5. Publish and test (below) before anyone buys for real.

The server checks the table at start-up and prints a warning for a bad entry (a typo, a duplicate id, an unknown item).

## Testing safely

- Test in a **published test place** with Studio's **Enable Studio Access to API Services** on. Purchases made in Studio are test purchases and charge nothing; watch for "This is a test purchase" in the window.
- Check: the item becomes owned; it is still owned after leaving and rejoining; buying it again is refused ("You already own that"); the shop shows the Roblox price.
- For a Developer Product, also check the output for `[Monetization]` lines: a receipt that could not be processed yet says why.

## How it stays safe

- The server alone decides what was bought. The client only asks to open a purchase window for an item, and the server refuses unless sales are on, the item has a configured product, the goblin's saved progress is open, and they do not already own it.
- **Game passes** are checked with `UserOwnsGamePassAsync` every time a goblin's profile opens (so a pass bought on the website counts) and granted at once from `PromptGamePassPurchaseFinished` when bought in the game.
- **Developer Products** go through `ProcessReceipt` (`server/Receipts.lua`): an unknown product or a goblin who is not here is left for Roblox to retry; the purchase id is recorded in the goblin's profile together with the grant; it is confirmed only after that profile is saved; a repeated receipt grants nothing more; a permanent item paid for twice becomes 150 Shinies instead.
- Prices are read from Roblox (`GetProductInfoAsync`), never typed into the game.

## Adding a new Robux item

1. Add the item to `src/shared/Catalog.lua` with `rarity = "premium"` and `premium = "<key>"` (or, for an item also sold for Shinies, just add `premium = "<key>"` to it).
2. Give it a look (see "Adding content" in `docs/GAME_DESIGN.md`).
3. Add `<key> = { kind = "pass", id = nil, grants = { "<itemId>" } }` to `Config.MONETIZATION.PRODUCTS`.
4. Run the tests (`tests/luau`): they fail if the key is missing, grants something unknown, or an id is not a whole number.
5. Create the product as above when the team wants it on sale.
