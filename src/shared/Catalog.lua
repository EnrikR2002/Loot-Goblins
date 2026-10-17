-- The catalogue (V11, Goblin Life): every cosmetic, pet, pet look and start-kit a goblin can own, in one list,
-- plus the achievements that unlock some of them. Shared, so the server (prices, ownership, what may be worn)
-- and the client (the shop, the locker, the previews) read the same rows.
--
-- One currency: SHINIES, earned by playing raids (server/Progress.lua). Raid GOLD only decides who wins a raid.
-- Robux is an optional second way to get a few things, and only once a human has created the product in the
-- Creator Dashboard and pasted its id into Config.MONETIZATION (no id is invented here).
--
-- A row:
--   id       stable forever (saved in profiles). Never rename or reuse one; retire it with `retired = true`.
--   slot     where it goes (Catalog.SLOTS). One item per slot, except emotes (every owned emote is in the wheel).
--   name, blurb   what the shop says.
--   rarity   common | uncommon | rare | legendary | trophy (unlocked by an achievement) | premium (Robux only).
--   price    Shinies. nil = not for sale for Shinies (free, trophy or premium).
--   free     everybody owns it from the start.
--   unlock   the achievement that grants it (trophy items).
--   premium  a key into Config.MONETIZATION.PRODUCTS (Robux). Pets list one too: the Robux way to the same pet.
--   pet      (pet looks) which pet it dresses.
--   vibe     a word for the shop card (nautical, silly, spooky...): personality, not power.
-- What an item LOOKS like lives in code next to the thing it dresses: shared/Wardrobe.lua (goblins),
-- shared/BoatLook.lua (boats), shared/PetLook.lua (pets), client/Looks.lua (trails, trick effects, callouts),
-- shared/EmoteMoves.lua (emotes and victory dances). Every row must have a look there; the tests check it.
local Catalog = {}

Catalog.RARITIES = {
	common = { order = 1, name = "Common", color = Color3.fromRGB(196, 184, 160) },
	uncommon = { order = 2, name = "Uncommon", color = Color3.fromRGB(120, 210, 96) },
	rare = { order = 3, name = "Rare", color = Color3.fromRGB(80, 176, 255) },
	legendary = { order = 4, name = "Legendary", color = Color3.fromRGB(255, 196, 46) },
	trophy = { order = 5, name = "Trophy", color = Color3.fromRGB(196, 128, 255) },
	premium = { order = 6, name = "Premium", color = Color3.fromRGB(90, 226, 176) },
}

-- Where things go. `default` is worn when nothing else is chosen (and is always owned); `optional` slots can be
-- empty. `group` is the shop's top-level tab.
Catalog.SLOTS = {
	{ id = "hat", group = "goblin", name = "Hats", optional = true },
	{ id = "eyes", group = "goblin", name = "Eyewear", optional = true },
	{ id = "face", group = "goblin", name = "Face", optional = true },
	{ id = "outfit", group = "goblin", name = "Outfits", optional = true },
	{ id = "back", group = "goblin", name = "Back", optional = true },
	{ id = "skin", group = "goblin", name = "Skin", default = "skin_classic" },
	{ id = "ears", group = "goblin", name = "Ears", default = "ears_long" },
	{ id = "nose", group = "goblin", name = "Nose", default = "nose_round" },
	{ id = "livery", group = "boat", name = "Paint", default = "livery_classic" },
	{ id = "flag", group = "boat", name = "Flags", default = "flag_jolly" },
	{ id = "figurehead", group = "boat", name = "Figureheads", optional = true },
	{ id = "trail", group = "boat", name = "Boost Trails", optional = true },
	{ id = "wake", group = "boat", name = "Wakes", optional = true },
	{ id = "trickfx", group = "style", name = "Trick Effects", optional = true },
	{ id = "callout", group = "style", name = "Callouts", default = "callout_classic" },
	{ id = "emote", group = "style", name = "Emotes", multi = true },
	{ id = "victory", group = "style", name = "Victory Dances", default = "victory_cheer" },
	{ id = "pet", group = "pets", name = "Pets", optional = true },
	{ id = "petskin", group = "pets", name = "Pet Looks", optional = true },
	{ id = "pethat", group = "pets", name = "Pet Hats", optional = true },
	{ id = "kit", group = "pets", name = "Start Kits", optional = true },
}

Catalog.GROUPS = {
	{ id = "goblin", name = "Goblin" },
	{ id = "boat", name = "Boat" },
	{ id = "style", name = "Style" },
	{ id = "pets", name = "Pets & Kits" },
}

local ITEMS = {
	-- Hats ---------------------------------------------------------------------------------------------------------
	{
		id = "hat_bandana",
		slot = "hat",
		name = "Red Bandana",
		blurb = "Every goblin's first hat. Knotted at the back, tails flapping.",
		rarity = "common",
		free = true,
		vibe = "nautical",
	},
	{
		id = "hat_sailor",
		slot = "hat",
		name = "Tiny Sailor Cap",
		blurb = "Far too small. Perches on top of the head like a gull on a post.",
		rarity = "common",
		price = 35,
		vibe = "silly",
	},
	{
		id = "hat_tricorn",
		slot = "hat",
		name = "Pirate Tricorn",
		blurb = "Three corners, one skull, no excuses.",
		rarity = "common",
		price = 45,
		vibe = "nautical",
	},
	{
		id = "hat_bucket",
		slot = "hat",
		name = "Bucket Helmet",
		blurb = "A tin bucket with eye holes. Protection rating: emotional.",
		rarity = "common",
		price = 40,
		vibe = "goblin",
	},
	{
		id = "hat_chef",
		slot = "hat",
		name = "Galley Cook's Toque",
		blurb = "A tall white chef's hat with a ladle tucked in the band.",
		rarity = "uncommon",
		price = 80,
		vibe = "silly",
	},
	{
		id = "hat_explorer",
		slot = "hat",
		name = "Explorer's Pith Helmet",
		blurb = "Khaki dome, green band, a feather from somewhere unwise.",
		rarity = "uncommon",
		price = 100,
		vibe = "adventurous",
	},
	{
		id = "hat_viking",
		slot = "hat",
		name = "Horned Helm",
		blurb = "Two curly horns and a dent where the Guardian tapped it.",
		rarity = "uncommon",
		price = 120,
		vibe = "mischievous",
	},
	{
		id = "hat_feather",
		slot = "hat",
		name = "Ridiculous Plumed Hat",
		blurb = "A brim like a cartwheel and a feather like a palm frond.",
		rarity = "rare",
		price = 220,
		vibe = "elegant",
	},
	{
		id = "hat_captain",
		slot = "hat",
		name = "Oversized Captain's Hat",
		blurb = "A bicorne three heads wide with gold braid. You can see it from the skyship.",
		rarity = "rare",
		price = 280,
		vibe = "prestigious",
	},
	{
		id = "hat_crown",
		slot = "hat",
		name = "Royal Crown",
		blurb = "Gold, rubies and a velvet cap. Nobody asked who crowned you.",
		rarity = "legendary",
		price = 650,
		vibe = "prestigious",
	},
	{
		id = "hat_idol",
		slot = "hat",
		name = "Idol King's Crown",
		blurb = "The Golden Idol's own crown and sun halo, copied in brass by a goblin who got it home.",
		rarity = "trophy",
		unlock = "idol_thief",
		vibe = "prestigious",
	},
	-- Eyewear ------------------------------------------------------------------------------------------------------
	{
		id = "eyes_patch",
		slot = "eyes",
		name = "Eyepatch",
		blurb = "Black leather, worn over whichever eye was not looking.",
		rarity = "common",
		price = 30,
		vibe = "nautical",
	},
	{
		id = "eyes_spectacles",
		slot = "eyes",
		name = "Oversized Spectacles",
		blurb = "Round lenses the size of saucers. Everything looks closer, especially trouble.",
		rarity = "common",
		price = 40,
		vibe = "silly",
	},
	{
		id = "eyes_googly",
		slot = "eyes",
		name = "Googly Eyes",
		blurb = "They wobble. They always wobble.",
		rarity = "uncommon",
		price = 75,
		vibe = "silly",
	},
	{
		id = "eyes_goggles",
		slot = "eyes",
		name = "Brass Diving Goggles",
		blurb = "Riveted brass and thick green glass, strapped on tight.",
		rarity = "uncommon",
		price = 90,
		vibe = "adventurous",
	},
	{
		id = "eyes_monocle",
		slot = "eyes",
		name = "Gold Monocle",
		blurb = "A gold-rimmed monocle on a chain. Pairs with a raised eyebrow.",
		rarity = "uncommon",
		price = 110,
		vibe = "elegant",
	},
	{
		id = "eyes_shades",
		slot = "eyes",
		name = "Star Shades",
		blurb = "Star-shaped sunglasses for goblins who do tricks off ramps.",
		rarity = "rare",
		price = 220,
		vibe = "mischievous",
	},
	{
		id = "eyes_mask",
		slot = "eyes",
		name = "Pickpocket's Mask",
		blurb = "A bandit's eye mask, earned by snatching treasure out of another goblin's hands.",
		rarity = "trophy",
		unlock = "sticky_fingers",
		vibe = "mischievous",
	},
	-- Face ---------------------------------------------------------------------------------------------------------
	{
		id = "face_moustache",
		slot = "face",
		name = "Curly Moustache",
		blurb = "Glued on. Twirls at both ends.",
		rarity = "common",
		price = 35,
		vibe = "silly",
	},
	{
		id = "face_tooth",
		slot = "face",
		name = "Gold Tooth Grin",
		blurb = "A wide grin with one gleaming gold tooth.",
		rarity = "common",
		price = 45,
		vibe = "goblin",
	},
	{
		id = "face_scar",
		slot = "face",
		name = "Battle Scar",
		blurb = "Stitched across one cheek. The story changes every time.",
		rarity = "common",
		price = 30,
		vibe = "adventurous",
	},
	{
		id = "face_warpaint",
		slot = "face",
		name = "War Paint",
		blurb = "Two bold stripes under each eye, in raid-day red.",
		rarity = "uncommon",
		price = 70,
		vibe = "mischievous",
	},
	{
		id = "face_beard",
		slot = "face",
		name = "Braided Beard",
		blurb = "A long ginger beard in two braids with gold rings.",
		rarity = "uncommon",
		price = 110,
		vibe = "nautical",
	},
	{
		id = "face_chops",
		slot = "face",
		name = "Old Salt's Mutton Chops",
		blurb = "Grey whiskers grown over twenty-five raids at sea.",
		rarity = "trophy",
		unlock = "old_salt",
		vibe = "nautical",
	},
	-- Outfits ------------------------------------------------------------------------------------------------------
	{
		id = "outfit_deckhand",
		slot = "outfit",
		name = "Deckhand Stripes",
		blurb = "A striped shirt, a rope belt and a neckerchief.",
		rarity = "common",
		price = 60,
		vibe = "nautical",
	},
	{
		id = "outfit_barrel",
		slot = "outfit",
		name = "Barrel Overalls",
		blurb = "A barrel on braces. Lost a bet; kept the barrel.",
		rarity = "common",
		price = 70,
		vibe = "goblin",
	},
	{
		id = "outfit_explorer",
		slot = "outfit",
		name = "Explorer's Vest",
		blurb = "Khaki, many pockets, a satchel strap and a compass on a cord.",
		rarity = "uncommon",
		price = 120,
		vibe = "adventurous",
	},
	{
		id = "outfit_armor",
		slot = "outfit",
		name = "Pot-Lid Armour",
		blurb = "Saucepan lids, a colander and a lot of string. Clanks.",
		rarity = "uncommon",
		price = 140,
		vibe = "goblin",
	},
	{
		id = "outfit_formal",
		slot = "outfit",
		name = "Fancy Waistcoat",
		blurb = "Purple velvet waistcoat, white shirt front, an enormous bow tie.",
		rarity = "uncommon",
		price = 130,
		vibe = "elegant",
	},
	{
		id = "outfit_captain",
		slot = "outfit",
		name = "Captain's Coat",
		blurb = "Long red coat, gold buttons, epaulettes and swishing tails.",
		rarity = "rare",
		price = 280,
		vibe = "nautical",
	},
	{
		id = "outfit_royal",
		slot = "outfit",
		name = "Royal Robe",
		blurb = "Purple robe with a spotted ermine collar and a gold chain of office.",
		rarity = "legendary",
		price = 600,
		vibe = "prestigious",
	},
	{
		id = "outfit_ghost",
		slot = "outfit",
		name = "Ghostly Pirate Coat",
		blurb = "Tattered and glowing ghost-teal, earned by getting the Skull Chalice home.",
		rarity = "trophy",
		unlock = "ghost_walker",
		vibe = "spooky",
	},
	{
		id = "outfit_admiral",
		slot = "outfit",
		name = "Admiral's Regalia",
		blurb = "Navy-blue dress coat, gold sash and a chest of medals for battles nobody remembers.",
		rarity = "premium",
		premium = "outfit_admiral",
		vibe = "prestigious",
	},
	-- Back and shoulder --------------------------------------------------------------------------------------------
	{
		id = "back_sack",
		slot = "back",
		name = "Loot Sack",
		blurb = "A patched sack slung over the shoulder. Empty, for now.",
		rarity = "common",
		price = 50,
		vibe = "goblin",
	},
	{
		id = "back_cape",
		slot = "back",
		name = "Tattered Cape",
		blurb = "A ragged red cape that streams out behind you at boat speed.",
		rarity = "uncommon",
		price = 100,
		vibe = "adventurous",
	},
	{
		id = "back_anchor",
		slot = "back",
		name = "Tiny Anchor",
		blurb = "An anchor-shaped backpack. Does not anchor anything.",
		rarity = "uncommon",
		price = 90,
		vibe = "nautical",
	},
	{
		id = "back_parrot",
		slot = "back",
		name = "Stuffed Parrot",
		blurb = "A stuffed parrot sewn to your shoulder. Your pet is not jealous. Probably.",
		rarity = "uncommon",
		price = 120,
		vibe = "silly",
	},
	{
		id = "back_wings",
		slot = "back",
		name = "Bat Wings",
		blurb = "Leathery little wings. Decorative. Please do not try.",
		rarity = "rare",
		price = 240,
		vibe = "spooky",
	},
	{
		id = "back_hoard",
		slot = "back",
		name = "Bulging Hoard Sack",
		blurb = "Overflowing with gold coins: proof you have banked 150 gold in all.",
		rarity = "trophy",
		unlock = "hoarder",
		vibe = "prestigious",
	},
	-- Skin, ears, nose ---------------------------------------------------------------------------------------------
	{
		id = "skin_classic",
		slot = "skin",
		name = "Classic Goblin",
		blurb = "The green every goblin is born with.",
		rarity = "common",
		free = true,
		vibe = "goblin",
	},
	{
		id = "skin_moss",
		slot = "skin",
		name = "Moss",
		blurb = "A deeper, forest green.",
		rarity = "common",
		free = true,
		vibe = "goblin",
	},
	{
		id = "skin_swamp",
		slot = "skin",
		name = "Swamp",
		blurb = "Olive and murky, like a goblin who lives in a bog.",
		rarity = "common",
		free = true,
		vibe = "goblin",
	},
	{
		id = "skin_sea",
		slot = "skin",
		name = "Sea Goblin",
		blurb = "Blue-green, as if you grew up under a pier.",
		rarity = "common",
		price = 40,
		vibe = "nautical",
	},
	{
		id = "skin_cave",
		slot = "skin",
		name = "Cave Goblin",
		blurb = "Pale grey-green. Has not seen the sun in a while.",
		rarity = "common",
		price = 40,
		vibe = "spooky",
	},
	{
		id = "skin_hob",
		slot = "skin",
		name = "Hobgoblin",
		blurb = "Brick red, like a goblin who stood too close to Ember Isle.",
		rarity = "uncommon",
		price = 100,
		vibe = "mischievous",
	},
	{
		id = "skin_violet",
		slot = "skin",
		name = "Bog Violet",
		blurb = "A rare purple goblin. Other goblins point.",
		rarity = "rare",
		price = 200,
		vibe = "spooky",
	},
	{
		id = "skin_gold",
		slot = "skin",
		name = "Golden Goblin",
		blurb = "Shining gold skin for a Hoard Legend: 750 gold banked in all.",
		rarity = "trophy",
		unlock = "hoard_legend",
		vibe = "prestigious",
	},
	{
		id = "ears_long",
		slot = "ears",
		name = "Long Pointed Ears",
		blurb = "Swept back, pink inside. The classic.",
		rarity = "common",
		free = true,
		vibe = "goblin",
	},
	{
		id = "ears_droopy",
		slot = "ears",
		name = "Droopy Ears",
		blurb = "Long ears that hang down and bounce when you run.",
		rarity = "common",
		free = true,
		vibe = "silly",
	},
	{
		id = "ears_bat",
		slot = "ears",
		name = "Bat Ears",
		blurb = "Tall, pointed straight up, always listening.",
		rarity = "common",
		price = 35,
		vibe = "spooky",
	},
	{
		id = "ears_tiny",
		slot = "ears",
		name = "Tiny Nubs",
		blurb = "Ears so small they are mostly a rumour.",
		rarity = "common",
		price = 30,
		vibe = "silly",
	},
	{
		id = "ears_hoops",
		slot = "ears",
		name = "Gold Hoop Earrings",
		blurb = "The long ears, with three gold hoops in each.",
		rarity = "uncommon",
		price = 80,
		vibe = "nautical",
	},
	{
		id = "nose_round",
		slot = "nose",
		name = "Big Round Nose",
		blurb = "The classic goblin conk.",
		rarity = "common",
		free = true,
		vibe = "goblin",
	},
	{
		id = "nose_long",
		slot = "nose",
		name = "Long Pointy Nose",
		blurb = "Long, thin and always first through a door.",
		rarity = "common",
		price = 25,
		vibe = "mischievous",
	},
	{
		id = "nose_potato",
		slot = "nose",
		name = "Warty Potato",
		blurb = "Lumpy, warty and proud of it.",
		rarity = "common",
		price = 30,
		vibe = "goblin",
	},
	-- Boat paint ---------------------------------------------------------------------------------------------------
	{
		id = "livery_classic",
		slot = "livery",
		name = "Class Colours",
		blurb = "Honey wood with the class stripe: gold on a skiff, teal on a cutter.",
		rarity = "common",
		free = true,
		vibe = "nautical",
	},
	{
		id = "livery_sunset",
		slot = "livery",
		name = "Sunset Run",
		blurb = "Tangerine hull, magenta stripe, peach sails.",
		rarity = "common",
		price = 60,
		vibe = "elegant",
	},
	{
		id = "livery_pumpkin",
		slot = "livery",
		name = "Pumpkin Patch",
		blurb = "An orange hull with green stripes and a stalk on the stern.",
		rarity = "common",
		price = 80,
		vibe = "silly",
	},
	{
		id = "livery_reef",
		slot = "livery",
		name = "Coral Reef",
		blurb = "Turquoise hull, coral-pink stripe, spotted sails.",
		rarity = "uncommon",
		price = 120,
		vibe = "nautical",
	},
	{
		id = "livery_shark",
		slot = "livery",
		name = "Shark Bite",
		blurb = "Grey hull with a toothy grin painted on the bow.",
		rarity = "uncommon",
		price = 150,
		vibe = "mischievous",
	},
	{
		id = "livery_jolly",
		slot = "livery",
		name = "Jolly Goblin",
		blurb = "Black hull, bone stripe, black sails with a grinning goblin skull.",
		rarity = "rare",
		price = 260,
		vibe = "spooky",
	},
	{
		id = "livery_royal",
		slot = "livery",
		name = "Royal Barge",
		blurb = "White and gold with purple sails. Wave graciously.",
		rarity = "legendary",
		price = 600,
		vibe = "prestigious",
	},
	{
		id = "livery_leviathan",
		slot = "livery",
		name = "Leviathan Scale",
		blurb = "Deep teal scales and amber eyes on the bow, for those who brought the Leviathan's Tooth home.",
		rarity = "trophy",
		unlock = "serpent_slipper",
		vibe = "prestigious",
	},
	{
		id = "livery_starlit",
		slot = "livery",
		name = "Starlit Galleon",
		blurb = "Midnight-blue hull scattered with stars, silver stripe, night-sky sails.",
		rarity = "premium",
		premium = "livery_starlit",
		vibe = "elegant",
	},
	-- Flags --------------------------------------------------------------------------------------------------------
	{
		id = "flag_jolly",
		slot = "flag",
		name = "Jolly Goblin Flag",
		blurb = "A goblin skull with crossed bones. Tradition.",
		rarity = "common",
		free = true,
		vibe = "nautical",
	},
	{
		id = "flag_checker",
		slot = "flag",
		name = "Chequered Flag",
		blurb = "For goblins who treat every crossing as a race.",
		rarity = "common",
		price = 40,
		vibe = "adventurous",
	},
	{
		id = "flag_fish",
		slot = "flag",
		name = "Fish Windsock",
		blurb = "A striped fish that swims in the wind.",
		rarity = "common",
		price = 50,
		vibe = "silly",
	},
	{
		id = "flag_crown",
		slot = "flag",
		name = "Golden Crown Banner",
		blurb = "Purple swallowtail with a gold crown.",
		rarity = "uncommon",
		price = 100,
		vibe = "prestigious",
	},
	{
		id = "flag_ghost",
		slot = "flag",
		name = "Spectral Pennant",
		blurb = "A long tattered pennant that glows ghost-teal.",
		rarity = "rare",
		price = 200,
		vibe = "spooky",
	},
	{
		id = "flag_map",
		slot = "flag",
		name = "Chart Flag",
		blurb = "A treasure map flown as a flag, for banking treasure from eight islands.",
		rarity = "trophy",
		unlock = "island_hopper",
		vibe = "adventurous",
	},
	-- Figureheads ----------------------------------------------------------------------------------------------------
	{
		id = "fig_goblin",
		slot = "figurehead",
		name = "Goblin Bust",
		blurb = "A carved goblin leaning out over the bow, ears back.",
		rarity = "common",
		price = 60,
		vibe = "goblin",
	},
	{
		id = "fig_duck",
		slot = "figurehead",
		name = "Rubber Duck",
		blurb = "A giant yellow duck. It squeaks in spirit.",
		rarity = "uncommon",
		price = 120,
		vibe = "silly",
	},
	{
		id = "fig_dragon",
		slot = "figurehead",
		name = "Sea Dragon",
		blurb = "A green dragon head with horns, a frill and glowing eyes.",
		rarity = "rare",
		price = 280,
		vibe = "adventurous",
	},
	{
		id = "fig_idol",
		slot = "figurehead",
		name = "Golden Idol",
		blurb = "A gleaming gold goblin king, arms out, leading the way.",
		rarity = "legendary",
		price = 700,
		vibe = "prestigious",
	},
	-- Boost trails and wakes -------------------------------------------------------------------------------------------
	{
		id = "trail_gold",
		slot = "trail",
		name = "Gold Sparkle",
		blurb = "A ribbon of glittering gold behind every boost.",
		rarity = "common",
		price = 60,
		vibe = "prestigious",
	},
	{
		id = "trail_bubbles",
		slot = "trail",
		name = "Bubble Stream",
		blurb = "A stream of soap-bright bubbles.",
		rarity = "common",
		price = 70,
		vibe = "silly",
	},
	{
		id = "trail_ember",
		slot = "trail",
		name = "Ember Sparks",
		blurb = "Orange sparks and a hot red ribbon.",
		rarity = "uncommon",
		price = 120,
		vibe = "mischievous",
	},
	{
		id = "trail_ghost",
		slot = "trail",
		name = "Ghost Wisps",
		blurb = "Pale teal wisps that curl away behind you.",
		rarity = "uncommon",
		price = 120,
		vibe = "spooky",
	},
	{
		id = "trail_rainbow",
		slot = "trail",
		name = "Rainbow Ribbon",
		blurb = "Every colour at once, in a long flowing ribbon.",
		rarity = "rare",
		price = 250,
		vibe = "silly",
	},
	{
		id = "trail_aurora",
		slot = "trail",
		name = "Aurora Ribbon",
		blurb = "Shimmering green and violet, like Frost Spire's sky.",
		rarity = "premium",
		premium = "trail_aurora",
		vibe = "elegant",
	},
	{
		id = "wake_glitter",
		slot = "wake",
		name = "Glitter Wake",
		blurb = "Your wake sparkles gold at speed.",
		rarity = "uncommon",
		price = 100,
		vibe = "prestigious",
	},
	{
		id = "wake_ink",
		slot = "wake",
		name = "Squid Ink",
		blurb = "A dark purple wake. Very mysterious. Slightly smelly.",
		rarity = "common",
		price = 60,
		vibe = "spooky",
	},
	{
		id = "wake_petals",
		slot = "wake",
		name = "Petal Wake",
		blurb = "Pink petals swirl in your wake.",
		rarity = "uncommon",
		price = 110,
		vibe = "elegant",
	},
	-- Trick effects and callouts -------------------------------------------------------------------------------------
	{
		id = "trickfx_stars",
		slot = "trickfx",
		name = "Starburst",
		blurb = "Stars spin off the hull through every trick.",
		rarity = "common",
		price = 50,
		vibe = "silly",
	},
	{
		id = "trickfx_confetti",
		slot = "trickfx",
		name = "Confetti Cannon",
		blurb = "A burst of confetti on every clean landing.",
		rarity = "uncommon",
		price = 110,
		vibe = "silly",
	},
	{
		id = "trickfx_fireworks",
		slot = "trickfx",
		name = "Fireworks",
		blurb = "Sparklers through the trick and a firework on a big landing.",
		rarity = "rare",
		price = 260,
		vibe = "prestigious",
	},
	{
		id = "trickfx_comet",
		slot = "trickfx",
		name = "Comet Tail",
		blurb = "A blazing comet tail through tricks, for landing four in one jump.",
		rarity = "trophy",
		unlock = "trick_master",
		vibe = "adventurous",
	},
	{
		id = "callout_classic",
		slot = "callout",
		name = "Street Style",
		blurb = "Big tilted letters in loud colours.",
		rarity = "common",
		free = true,
		vibe = "mischievous",
	},
	{
		id = "callout_gold",
		slot = "callout",
		name = "Gold Rush",
		blurb = "Every callout in shining gold.",
		rarity = "common",
		price = 40,
		vibe = "prestigious",
	},
	{
		id = "callout_comic",
		slot = "callout",
		name = "Comic Pop",
		blurb = "White letters on bursting comic-book colours.",
		rarity = "common",
		price = 50,
		vibe = "silly",
	},
	{
		id = "callout_spooky",
		slot = "callout",
		name = "Spooky",
		blurb = "Wobbling ghost-teal letters.",
		rarity = "uncommon",
		price = 80,
		vibe = "spooky",
	},
	{
		id = "callout_royal",
		slot = "callout",
		name = "Royal Decree",
		blurb = "Purple and gold, in a very serious typeface.",
		rarity = "rare",
		price = 180,
		vibe = "elegant",
	},
	-- Emotes and victory dances --------------------------------------------------------------------------------------
	{
		id = "emote_wave",
		slot = "emote",
		name = "Wave",
		blurb = "A big friendly wave.",
		rarity = "common",
		free = true,
		vibe = "goblin",
	},
	{
		id = "emote_cackle",
		slot = "emote",
		name = "Cackle",
		blurb = "Lean back and cackle like you just got away with it.",
		rarity = "common",
		free = true,
		vibe = "mischievous",
	},
	{
		id = "emote_salute",
		slot = "emote",
		name = "Salute",
		blurb = "A crisp salute. Aye aye.",
		rarity = "common",
		price = 30,
		vibe = "nautical",
	},
	{
		id = "emote_panic",
		slot = "emote",
		name = "Panic!",
		blurb = "Arms flailing, knees knocking.",
		rarity = "common",
		price = 45,
		vibe = "silly",
	},
	{
		id = "emote_jig",
		slot = "emote",
		name = "Goblin Jig",
		blurb = "A bouncy sailor's jig.",
		rarity = "common",
		price = 50,
		vibe = "nautical",
	},
	{
		id = "emote_flex",
		slot = "emote",
		name = "Flex",
		blurb = "Show off those mighty goblin arms.",
		rarity = "uncommon",
		price = 90,
		vibe = "mischievous",
	},
	{
		id = "emote_faceplant",
		slot = "emote",
		name = "Faceplant",
		blurb = "Fall flat on your face. For when the Leviathan wins.",
		rarity = "uncommon",
		price = 80,
		vibe = "silly",
	},
	{
		id = "victory_cheer",
		slot = "victory",
		name = "Arms Up",
		blurb = "Both arms in the air and a little hop.",
		rarity = "common",
		free = true,
		vibe = "goblin",
	},
	{
		id = "victory_stomp",
		slot = "victory",
		name = "Victory Stomp",
		blurb = "A stomping, spinning goblin war dance.",
		rarity = "uncommon",
		price = 120,
		vibe = "mischievous",
	},
	{
		id = "victory_shower",
		slot = "victory",
		name = "Gold Shower",
		blurb = "Throw handfuls of gold coins into the air and bask in them.",
		rarity = "rare",
		price = 260,
		vibe = "prestigious",
	},
	{
		id = "victory_crown",
		slot = "victory",
		name = "Self-Crowning",
		blurb = "Lift a crown from nowhere and crown yourself. Earned by winning a raid.",
		rarity = "trophy",
		unlock = "raid_champion",
		vibe = "prestigious",
	},
	-- Pets (ids match Config.PETS: the server reads the pet's ability by this id) ------------------------------------
	{
		id = "Crab",
		slot = "pet",
		name = "Tug Crab",
		blurb = "A loyal, busy little crab who loves boats. Scuttles sideways, snaps at gulls.",
		rarity = "uncommon",
		price = 100,
		premium = "pet_Crab",
		utility = true,
		vibe = "nautical",
	},
	{
		id = "Frog",
		slot = "pet",
		name = "Spring Frog",
		blurb = "Bounces everywhere, never sits still, catches flies mid-air.",
		rarity = "uncommon",
		price = 130,
		premium = "pet_Frog",
		utility = true,
		vibe = "silly",
	},
	{
		id = "Gull",
		slot = "pet",
		name = "Scout Gull",
		blurb = "A curious seabird who flies ahead, looks around and squawks about treasure.",
		rarity = "uncommon",
		price = 150,
		premium = "pet_Gull",
		utility = true,
		vibe = "adventurous",
	},
	{
		id = "Ghost",
		slot = "pet",
		name = "Pocket Ghost",
		blurb = "A tiny mischievous spirit that floats, giggles and does loop-the-loops.",
		rarity = "rare",
		price = 180,
		premium = "pet_Ghost",
		utility = true,
		vibe = "spooky",
	},
	{
		id = "Tortoise",
		slot = "pet",
		name = "Shell Tortoise",
		blurb = "Calm, sturdy and unbothered. Plods along and keeps you safe.",
		rarity = "rare",
		price = 220,
		premium = "pet_Tortoise",
		utility = true,
		vibe = "nautical",
	},
	{
		id = "petskin_crab_hermit",
		slot = "petskin",
		pet = "Crab",
		name = "Hermit Crab",
		blurb = "Your crab, living in a little striped shell.",
		rarity = "uncommon",
		price = 90,
		vibe = "nautical",
	},
	{
		id = "petskin_crab_gold",
		slot = "petskin",
		pet = "Crab",
		name = "Golden Crab",
		blurb = "Your crab, polished gold from claw to claw.",
		rarity = "premium",
		premium = "petskin_crab_gold",
		vibe = "prestigious",
	},
	{
		id = "petskin_gull_puffin",
		slot = "petskin",
		pet = "Gull",
		name = "Puffin",
		blurb = "Your gull, as a puffin: black and white with a stripy orange beak.",
		rarity = "uncommon",
		price = 90,
		vibe = "silly",
	},
	{
		id = "petskin_frog_dart",
		slot = "petskin",
		pet = "Frog",
		name = "Dart Frog",
		blurb = "Your frog, bright blue with black spots.",
		rarity = "uncommon",
		price = 90,
		vibe = "adventurous",
	},
	{
		id = "petskin_tortoise_moss",
		slot = "petskin",
		pet = "Tortoise",
		name = "Mossback",
		blurb = "Your tortoise, with a little garden growing on its shell.",
		rarity = "uncommon",
		price = 90,
		vibe = "goblin",
	},
	{
		id = "petskin_ghost_pumpkin",
		slot = "petskin",
		pet = "Ghost",
		name = "Pumpkin Ghost",
		blurb = "Your ghost, wearing a carved pumpkin.",
		rarity = "uncommon",
		price = 90,
		vibe = "spooky",
	},
	{
		id = "pethat_bow",
		slot = "pethat",
		name = "Pet Bow",
		blurb = "A big red bow for your pet.",
		rarity = "common",
		price = 30,
		vibe = "silly",
	},
	{
		id = "pethat_party",
		slot = "pethat",
		name = "Pet Party Hat",
		blurb = "A striped cone with a pompom.",
		rarity = "common",
		price = 35,
		vibe = "silly",
	},
	{
		id = "pethat_tricorn",
		slot = "pethat",
		name = "Pet Tricorn",
		blurb = "A tiny pirate hat for your first mate.",
		rarity = "common",
		price = 40,
		vibe = "nautical",
	},
	{
		id = "pethat_crown",
		slot = "pethat",
		name = "Pet Crown",
		blurb = "A tiny gold crown. Your pet now outranks you.",
		rarity = "uncommon",
		price = 100,
		vibe = "prestigious",
	},
	-- Start kits (V7): start each raid carrying one piece of gear. Gear is free in the world too. ---------------------
	{
		id = "kit_Rebreather",
		slot = "kit",
		gear = "Rebreather",
		name = "Start with: Diver's Rebreather",
		blurb = "Start each raid carrying it. (Free from the cache on Kelp Cay too.)",
		rarity = "common",
		price = 90,
		utility = true,
		vibe = "adventurous",
	},
	{
		id = "kit_CinderBoots",
		slot = "kit",
		gear = "CinderBoots",
		name = "Start with: Cinder Boots",
		blurb = "Start each raid carrying them. (Free from the cache on Lantern Key too.)",
		rarity = "common",
		price = 90,
		utility = true,
		vibe = "adventurous",
	},
	{
		id = "kit_FrostClaws",
		slot = "kit",
		gear = "FrostClaws",
		name = "Start with: Frost Claws",
		blurb = "Start each raid carrying them. (Free from the cache on Lantern Key too.)",
		rarity = "common",
		price = 90,
		utility = true,
		vibe = "adventurous",
	},
}

-- Achievements: deterministic, one clear deed each, read from a goblin's lasting stats (server/Economy.lua). Each
-- pays Shinies once and some unlock a trophy item. No daily chores, nothing random.
Catalog.ACHIEVEMENTS = {
	{
		id = "first_haul",
		name = "First Haul",
		how = "Bank your first treasure at the Hoard.",
		stat = "treasures",
		goal = 1,
		shinies = 25,
	},
	{
		id = "raid_champion",
		name = "Raid Champion",
		how = "Win a raid.",
		stat = "wins",
		goal = 1,
		shinies = 40,
		reward = "victory_crown",
	},
	{
		id = "sticky_fingers",
		name = "Sticky Fingers",
		how = "Snatch a treasure from a goblin you have knocked down.",
		stat = "snatches",
		goal = 1,
		shinies = 30,
		reward = "eyes_mask",
	},
	{
		id = "trick_master",
		name = "Trick Master",
		how = "Land four tricks in one jump.",
		stat = "bestCombo",
		goal = 4,
		shinies = 40,
		reward = "trickfx_comet",
	},
	{
		id = "idol_thief",
		name = "Idol Thief",
		how = "Bank the Golden Idol from the Sun Temple.",
		stat = "bank_Idol",
		goal = 1,
		shinies = 50,
		reward = "hat_idol",
	},
	{
		id = "serpent_slipper",
		name = "Serpent Slipper",
		how = "Bank the Leviathan's Tooth (the Leviathan hunts whoever takes it).",
		stat = "bank_Tooth",
		goal = 1,
		shinies = 50,
		reward = "livery_leviathan",
	},
	{
		id = "ghost_walker",
		name = "Skull Rock Survivor",
		how = "Bank the Skull Chalice (the Ghost Fleet comes for it).",
		stat = "bank_Chalice",
		goal = 1,
		shinies = 50,
		reward = "outfit_ghost",
	},
	{
		id = "island_hopper",
		name = "Island Hopper",
		how = "Bank treasure from eight different islands.",
		stat = "islands",
		goal = 8,
		shinies = 60,
		reward = "flag_map",
	},
	{
		id = "old_salt",
		name = "Old Salt",
		how = "Play 25 raids.",
		stat = "raids",
		goal = 25,
		shinies = 60,
		reward = "face_chops",
	},
	{
		id = "hoarder",
		name = "Hoarder",
		how = "Bank 150 gold in all.",
		stat = "banked",
		goal = 150,
		shinies = 60,
		reward = "back_hoard",
	},
	{
		id = "hoard_legend",
		name = "Hoard Legend",
		how = "Bank 750 gold in all.",
		stat = "banked",
		goal = 750,
		shinies = 150,
		reward = "skin_gold",
	},
}

-- Indexes ------------------------------------------------------------------------------------------------------------
Catalog.items = ITEMS
Catalog.byId = {}
Catalog.bySlot = {}
Catalog.slotById = {}
Catalog.achievementById = {}
for index, slot in ipairs(Catalog.SLOTS) do
	slot.order = index
	Catalog.slotById[slot.id] = slot
	Catalog.bySlot[slot.id] = {}
end
for index, item in ipairs(ITEMS) do
	item.order = index
	Catalog.byId[item.id] = item
	table.insert(Catalog.bySlot[item.slot], item)
end
for _, achievement in ipairs(Catalog.ACHIEVEMENTS) do
	Catalog.achievementById[achievement.id] = achievement
end

function Catalog.get(id)
	return type(id) == "string" and Catalog.byId[id] or nil
end

function Catalog.slot(id)
	return Catalog.slotById[id]
end

-- Can this item be bought with Shinies?
function Catalog.forSale(item)
	return item ~= nil and not item.retired and type(item.price) == "number" and item.price > 0
end

-- Does everyone own it from the start (free items and slot defaults)?
function Catalog.isFree(item)
	if not item then
		return false
	end
	if item.free then
		return true
	end
	local slot = Catalog.slotById[item.slot]
	return slot ~= nil and slot.default == item.id
end

-- The look (what is worn) ------------------------------------------------------------------------------------------
-- A look is a table slot -> item id (only slots that hold something). It travels as one string attribute:
--   "hat=hat_tricorn;eyes=eyes_patch;skin=skin_moss;pet=Crab;petskin=petskin_crab_hermit"
-- Everyone's client reads it to draw that goblin's boat effects and pet; the server reads it to dress the goblin.
Catalog.LOOK_SLOTS = {
	"hat",
	"eyes",
	"face",
	"outfit",
	"back",
	"skin",
	"ears",
	"nose",
	"livery",
	"flag",
	"figurehead",
	"trail",
	"wake",
	"trickfx",
	"callout",
	"victory",
	"pet",
	"petskin",
	"pethat",
}

function Catalog.encodeLook(look)
	local parts = {}
	for _, slot in ipairs(Catalog.LOOK_SLOTS) do
		local id = look[slot]
		if id then
			table.insert(parts, slot .. "=" .. id)
		end
	end
	return table.concat(parts, ";")
end

-- Reading a look from an attribute: unknown slots and items that do not belong in their slot are dropped, and the
-- defaults fill the rest (a client never draws something the catalogue does not know).
function Catalog.decodeLook(text)
	local look = {}
	if type(text) == "string" then
		for slot, id in string.gmatch(text, "([%w_]+)=([%w_]+)") do
			local item = Catalog.byId[id]
			if item and item.slot == slot then
				look[slot] = id
			end
		end
	end
	return Catalog.withDefaults(look)
end

function Catalog.withDefaults(look)
	for _, slot in ipairs(Catalog.SLOTS) do
		if slot.default and not look[slot.id] then
			look[slot.id] = slot.default
		end
	end
	-- A pet look only makes sense on its own pet.
	local skin = look.petskin and Catalog.byId[look.petskin]
	if skin and skin.pet ~= look.pet then
		look.petskin = nil
	end
	return look
end

-- The order the shop lists a slot's items in: free first, then by price, trophies and premium last.
function Catalog.sorted(slotId)
	local list = table.clone(Catalog.bySlot[slotId] or {})
	table.sort(list, function(a, b)
		local ra, rb = Catalog.RARITIES[a.rarity].order, Catalog.RARITIES[b.rarity].order
		local fa, fb = Catalog.isFree(a) and 0 or 1, Catalog.isFree(b) and 0 or 1
		if fa ~= fb then
			return fa < fb
		end
		local pa, pb = a.price or math.huge, b.price or math.huge
		if (a.price ~= nil) ~= (b.price ~= nil) then
			return a.price ~= nil
		end
		if pa ~= pb then
			return pa < pb
		end
		if ra ~= rb then
			return ra < rb
		end
		return a.order < b.order
	end)
	return list
end

return Catalog
