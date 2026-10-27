# References

Data captured from the game for composing in Blender (V14). They are measurements, not pictures: V14's look follows
`docs/ART_DIRECTION.md`, and no outside artwork is stored here (none was used).

| File | What it is |
| --- | --- |
| `port_ground.txt` | the Goblin Port's terrain from x -60 to 260, z 40 to 300 round its centre (0, 0, 4600), every 4 studs: the Harbour District stands on it |
| `port_things.txt` | the Port's parts in that area (name, parent, position, size, rotation, collision, class, material), mannequin dressing left out: where V13's pieces are, which the Harbour District dresses or keeps clear of |
| `pebble_ground.txt` | Pebble Isle's terrain round (-540, 1972), x -160 to 260, z -160 to 180: the coast's waterline is traced from it |
| `pebble_things.txt` | the parts on and round Pebble Isle (the landmark, palms, the wreck, the treasure, a moored skiff) |
| `skiff_parts.txt` | a V10 skiff's parts in its hull part's frame: the landmarks the Hero Skiff keeps (deck, seats, mast, flag, bow gun) |

How they were made and the token format: `art/README.md`, "Capturing the ground".
