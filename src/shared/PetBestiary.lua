-- The V13 bestiary: thirty-seven more companions, each its own little sculpture (shared/PetLook.lua is the framework,
-- the five V11 pets live there, and this file only builds bodies). Every builder makes anchored, harmless parts in
-- GROUPS that the shared animator knows how to move (PetLook.pose):
--   legA legB        stride (walkers)            legBack legFront   hop (hoppers)
--   wingL wingR      flap (fliers)               finL finR          paddle (swimmers)
--   tail             wag                         tail1 tail2 tail3  wave down a chain (floaters)
--   seg1 .. seg5     a sideways wave (slitherers, the ferret)
--   tentA tentB      alternate curls (octopus, jelly, slug frills)
--   armL armR        swing                       head               bob and look about
--   lid              snap open and shut          halo orbit         spin round
--   flame lure       flicker and sway            puff               shown only while the pet is puffed up
-- Shapes face -Z, feet at y = 0, about the size of a goblin's knee to its waist. Palettes come from the art direction:
-- the island pets wear their island's colours, so a pet says where its owner has been.
return function(kit)
	local add, deg, rgb = kit.add, kit.deg, kit.rgb
	local UPRIGHT = kit.UPRIGHT
	local SMOOTH, NEON, METAL, GLASS, FOIL, SLATE = kit.SMOOTH, kit.NEON, kit.METAL, kit.GLASS, kit.FOIL, kit.SLATE
	local WOOD = Enum.Material.Wood
	local BLACK, WHITE, GOLD = kit.BLACK, kit.WHITE, kit.GOLD

	local function E(rig, group, name, size, cf, color, material, transparency)
		return add(rig, group, name, "egg", size, cf, color, material, transparency)
	end
	local function B(rig, group, name, size, cf, color, material, transparency)
		return add(rig, group, name, "ball", Vector3.new(size, size, size), cf, color, material, transparency)
	end
	local function K(rig, group, name, size, cf, color, material, transparency)
		return add(rig, group, name, "block", size, cf, color, material, transparency)
	end
	local function W(rig, group, name, size, cf, color, material, transparency)
		return add(rig, group, name, "wedge", size, cf, color, material, transparency)
	end
	local function Cy(rig, group, name, size, cf, color, material, transparency)
		return add(rig, group, name, "cyl", size, cf, color, material, transparency)
	end
	-- A pair of googly eyes at +-x, looking forward (-Z): white, a pupil, a glint.
	local function eyes(rig, group, x, y, z, r, pupil)
		for _, side in ipairs({ -1, 1 }) do
			B(rig, group, "Eye", r, CFrame.new(side * x, y, z), WHITE)
			B(rig, group, "Pupil", r * 0.52, CFrame.new(side * x * 1.02, y + r * 0.04, z - r * 0.4), pupil or BLACK)
		end
	end
	-- Glowing eyes (no white): ghosts, golems, the island creatures.
	local function glowEyes(rig, group, x, y, z, r, color)
		for _, side in ipairs({ -1, 1 }) do
			E(rig, group, "Eye", Vector3.new(r, r * 1.2, r * 0.6), CFrame.new(side * x, y, z), color, NEON)
		end
	end

	local BUILD = {}

	-- OCEAN ---------------------------------------------------------------------------------------------------------------

	-- Inky: a little octopus, mantle tipped back, big eyes low on its face, eight curling arms in two sets.
	BUILD.Inky = function(rig, look)
		local skin, spot = look.skin or rgb(204, 92, 176), look.spot or rgb(250, 160, 220)
		rig.pivots.tentA = Vector3.new(0, 0.45, 0)
		rig.pivots.tentB = Vector3.new(0, 0.45, 0)
		E(rig, "body", "Mantle", Vector3.new(1.35, 1.6, 1.35), CFrame.new(0, 1.55, 0.2) * deg(-18, 0, 0), skin)
		E(rig, "body", "Face", Vector3.new(1.25, 0.95, 1.1), CFrame.new(0, 0.85, -0.12), skin)
		B(rig, "body", "Spot", 0.3, CFrame.new(-0.3, 2.0, 0.55), spot)
		B(rig, "body", "Spot", 0.22, CFrame.new(0.35, 1.75, 0.62), spot)
		eyes(rig, "body", 0.3, 1.0, -0.58, 0.38)
		for i = 0, 7 do
			local a = (i + 0.5) / 8 * math.pi * 2
			local group = i % 2 == 0 and "tentA" or "tentB"
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local base = out * 0.45 + Vector3.new(0, 0.35, 0)
			local mid = out * 0.95 + Vector3.new(0, 0.18, 0)
			E(rig, group, "Arm", Vector3.new(0.3, 0.28, 0.78), CFrame.lookAt(base, mid) * CFrame.new(0, 0, -0.3), skin)
			E(rig, group, "Curl", Vector3.new(0.24, 0.32, 0.24), CFrame.new(out * 1.2 + Vector3.new(0, 0.3, 0)), spot)
		end
		rig.hat = CFrame.new(0, 2.35, 0.3)
	end

	-- Puffle: a round pufferfish that swims through the air; when startled it becomes a spiky ball (the "puff" group).
	BUILD.Puffle = function(rig, look)
		local skin, stripe = look.skin or rgb(250, 214, 120), look.stripe or rgb(214, 150, 70)
		rig.pivots.finL = Vector3.new(-0.6, 0, 0)
		rig.pivots.finR = Vector3.new(0.6, 0, 0)
		rig.pivots.tail = Vector3.new(0, 0, 0.6)
		B(rig, "body", "Body", 1.4, CFrame.new(0, 0, 0), skin)
		E(rig, "body", "Stripe", Vector3.new(1.42, 0.22, 1.1), CFrame.new(0, 0.42, 0.1), stripe)
		E(rig, "body", "Stripe", Vector3.new(1.3, 0.2, 1.0), CFrame.new(0, 0.18, 0.32), stripe)
		E(rig, "body", "Belly", Vector3.new(1.0, 0.7, 1.0), CFrame.new(0, -0.32, -0.15), rgb(255, 246, 222))
		eyes(rig, "body", 0.32, 0.18, -0.6, 0.36)
		Cy(
			rig,
			"body",
			"Mouth",
			Vector3.new(0.16, 0.26, 0.26),
			CFrame.new(0, -0.18, -0.7) * deg(0, 90, 0),
			rgb(236, 110, 90)
		)
		for _, side in ipairs({ -1, 1 }) do
			E(
				rig,
				side < 0 and "finL" or "finR",
				"Fin",
				Vector3.new(0.12, 0.42, 0.5),
				CFrame.new(side * 0.72, -0.05, 0.05),
				stripe
			)
		end
		W(rig, "tail", "TailFin", Vector3.new(0.12, 0.7, 0.6), CFrame.new(0, 0, 0.92) * deg(0, 180, 0), stripe)
		-- Puffed up: a bigger ball with spikes, hidden until a fright.
		local puff = {}
		table.insert(puff, B(rig, "puff", "PuffBody", 2.2, CFrame.new(0, 0, 0), skin, SMOOTH, 1))
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			local d = Vector3.new(math.cos(a), math.sin(a) * 0.8, math.sin(a) * 0.3).Unit
			table.insert(
				puff,
				W(
					rig,
					"puff",
					"Spike",
					Vector3.new(0.1, 0.36, 0.3),
					CFrame.lookAt(d * 1.12, d * 2) * deg(90, 0, 0),
					stripe,
					SMOOTH,
					1
				)
			)
		end
		rig.puff = puff
		rig.hat = CFrame.new(0, 0.7, -0.05)
	end

	-- Nibs: a pocket shark: blue-grey back, white belly, a big grin, a dorsal fin and a crescent tail.
	BUILD.Nibs = function(rig, look)
		local back, belly = look.back or rgb(110, 132, 164), look.belly or rgb(240, 242, 246)
		rig.pivots.tail = Vector3.new(0, 0, 0.75)
		rig.pivots.finL = Vector3.new(-0.4, -0.15, -0.2)
		rig.pivots.finR = Vector3.new(0.4, -0.15, -0.2)
		E(rig, "body", "Body", Vector3.new(0.9, 0.82, 2.2), CFrame.new(0, 0, 0), back)
		E(rig, "body", "Belly", Vector3.new(0.78, 0.5, 1.9), CFrame.new(0, -0.18, -0.05), belly)
		W(rig, "body", "Dorsal", Vector3.new(0.12, 0.7, 0.62), CFrame.new(0, 0.62, 0.1), back)
		K(rig, "body", "Grin", Vector3.new(0.5, 0.08, 0.06), CFrame.new(0, -0.12, -1.04), rgb(60, 40, 50))
		for i = -1, 1 do
			W(
				rig,
				"body",
				"Tooth",
				Vector3.new(0.06, 0.12, 0.1),
				CFrame.new(i * 0.14, -0.06, -1.06) * deg(180, 0, 0),
				WHITE
			)
		end
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "body", "Eye", 0.18, CFrame.new(side * 0.36, 0.14, -0.66), BLACK)
			W(
				rig,
				side < 0 and "finL" or "finR",
				"Fin",
				Vector3.new(0.1, 0.36, 0.5),
				CFrame.new(side * 0.55, -0.22, -0.2) * deg(0, 0, side * 70),
				back
			)
		end
		W(rig, "tail", "TailUp", Vector3.new(0.12, 0.7, 0.48), CFrame.new(0, 0.32, 1.22) * deg(-35, 180, 0), back)
		W(rig, "tail", "TailDown", Vector3.new(0.12, 0.5, 0.4), CFrame.new(0, -0.22, 1.18) * deg(215, 180, 0), back)
		rig.hat = CFrame.new(0, 0.5, -0.45)
	end

	-- Bubbles: a curly seahorse bobbing upright: snout, crown, belly ridges, a curled tail, a fan of a fin.
	BUILD.Bubbles = function(rig, look)
		local skin, ridge = look.skin or rgb(255, 150, 112), look.ridge or rgb(255, 206, 150)
		rig.pivots.tail = Vector3.new(0, -0.7, 0.1)
		rig.pivots.finR = Vector3.new(0, 0.3, 0.38)
		E(rig, "body", "Body", Vector3.new(0.8, 1.3, 0.85), CFrame.new(0, 0.1, 0) * deg(-8, 0, 0), skin)
		for i = 0, 3 do
			E(rig, "body", "Ridge", Vector3.new(0.5, 0.16, 0.2), CFrame.new(0, 0.45 - i * 0.3, -0.38), ridge)
		end
		E(rig, "head", "Head", Vector3.new(0.7, 0.66, 0.75), CFrame.new(0, 0.95, -0.1), skin)
		Cy(rig, "head", "Snout", Vector3.new(0.6, 0.22, 0.22), CFrame.new(0, 0.9, -0.62) * deg(0, 90, 0), skin)
		W(rig, "head", "Crown", Vector3.new(0.1, 0.32, 0.4), CFrame.new(0, 1.32, 0.0), ridge)
		eyes(rig, "head", 0.26, 1.02, -0.18, 0.22)
		B(rig, "tail", "Tail", 0.42, CFrame.new(0, -0.68, 0.12), skin)
		B(rig, "tail", "Tail", 0.32, CFrame.new(0, -0.95, 0.28), skin)
		B(rig, "tail", "Tail", 0.24, CFrame.new(0, -1.05, 0.06), ridge)
		W(rig, "finR", "Fan", Vector3.new(0.08, 0.5, 0.36), CFrame.new(0, 0.3, 0.44) * deg(0, 180, 0), ridge)
		rig.hat = CFrame.new(0, 1.38, -0.05)
		rig.hatGroup = "head"
	end

	-- Wobble: a glowing jellyfish: a soft bell, a frilled rim, four long tentacles and two curly arms.
	BUILD.Wobble = function(rig, look)
		local bell, glow = look.bell or rgb(244, 160, 236), look.glow or rgb(255, 210, 250)
		rig.pivots.tentA = Vector3.new(0, -0.2, 0)
		rig.pivots.tentB = Vector3.new(0, -0.2, 0)
		E(rig, "bell", "Bell", Vector3.new(1.6, 1.1, 1.6), CFrame.new(0, 0.35, 0), bell, SMOOTH, 0.25)
		E(rig, "bell", "Glow", Vector3.new(0.9, 0.6, 0.9), CFrame.new(0, 0.35, 0), glow, NEON, 0.2)
		Cy(rig, "bell", "Rim", Vector3.new(0.12, 1.66, 1.66), CFrame.new(0, -0.1, 0) * UPRIGHT, glow, NEON, 0.45)
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "bell", "Eye", 0.16, CFrame.new(side * 0.26, 0.38, -0.74), rgb(70, 30, 70))
		end
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + 0.4
			local group = i % 2 == 0 and "tentA" or "tentB"
			E(
				rig,
				group,
				"Tentacle",
				Vector3.new(0.12, 1.5, 0.12),
				CFrame.new(math.cos(a) * 0.5, -0.9, math.sin(a) * 0.5),
				bell,
				SMOOTH,
				0.3
			)
		end
		for _, side in ipairs({ -1, 1 }) do
			E(
				rig,
				side < 0 and "tentA" or "tentB",
				"OralArm",
				Vector3.new(0.26, 1.0, 0.26),
				CFrame.new(side * 0.15, -0.65, 0) * deg(0, 0, side * 12),
				glow,
				SMOOTH,
				0.25
			)
		end
		rig.hat = CFrame.new(0, 0.95, 0)
		rig.hatGroup = "bell"
	end

	-- Twinkle: a starfish that walks upright on two of its arms and cartwheels to keep up.
	BUILD.Twinkle = function(rig, look)
		local skin, dot = look.skin or rgb(255, 140, 70), look.dot or rgb(255, 214, 110)
		rig.pivots.legA = Vector3.new(-0.2, 0.7, 0)
		rig.pivots.legB = Vector3.new(0.2, 0.7, 0)
		local center = Vector3.new(0, 0.95, 0)
		B(rig, "body", "Center", 0.75, CFrame.new(center), skin)
		for i = 0, 4 do
			local a = math.rad(90 + i * 72)
			local dir = Vector3.new(math.cos(a), math.sin(a), 0)
			local group = (i == 2 and "legA") or (i == 3 and "legB") or "body"
			E(
				rig,
				group,
				"Arm",
				Vector3.new(0.42, 0.95, 0.3),
				CFrame.new(center + dir * 0.6) * CFrame.Angles(0, 0, a - math.rad(90)),
				skin
			)
			B(rig, group, "Dot", 0.14, CFrame.new(center + dir * 0.75 - Vector3.new(0, 0, 0.14)), dot)
		end
		eyes(rig, "body", 0.14, 1.04, -0.32, 0.2)
		K(rig, "body", "Smile", Vector3.new(0.18, 0.04, 0.04), CFrame.new(0, 0.86, -0.36), rgb(150, 50, 40))
		rig.hat = CFrame.new(0, 1.62, 0)
	end

	-- Nudi: a frilly rainbow sea slug with two horns and a back of orange-tipped frills.
	BUILD.Nudi = function(rig, look)
		local skin, frill, tip = look.skin or rgb(140, 90, 220), look.frill or rgb(90, 210, 220), rgb(255, 160, 50)
		rig.pivots.tentA = Vector3.new(0, 0.6, 0)
		rig.pivots.tentB = Vector3.new(0, 0.6, 0)
		E(rig, "body", "Body", Vector3.new(0.8, 0.55, 2.0), CFrame.new(0, 0.3, 0), skin)
		E(rig, "body", "Foot", Vector3.new(0.95, 0.2, 2.1), CFrame.new(0, 0.1, 0), skin:Lerp(WHITE, 0.3))
		for i = 0, 5 do
			local z = -0.55 + i * 0.25
			for _, side in ipairs({ -1, 1 }) do
				local group = (i + (side > 0 and 1 or 0)) % 2 == 0 and "tentA" or "tentB"
				E(
					rig,
					group,
					"Frill",
					Vector3.new(0.14, 0.4, 0.14),
					CFrame.new(side * 0.24, 0.66, z) * deg(0, 0, side * -25),
					i % 2 == 0 and frill or tip
				)
			end
		end
		for _, side in ipairs({ -1, 1 }) do
			E(
				rig,
				"body",
				"Horn",
				Vector3.new(0.12, 0.42, 0.12),
				CFrame.new(side * 0.16, 0.7, -0.82) * deg(-20, 0, 0),
				tip
			)
			B(rig, "body", "Eye", 0.12, CFrame.new(side * 0.2, 0.42, -0.94), BLACK)
		end
		rig.hat = CFrame.new(0, 0.62, -0.75)
	end

	-- Tusk: a plump baby narwhal with a stubby spiral horn, spots, flippers and flukes.
	BUILD.Tusk = function(rig, look)
		local skin, spot, belly = look.skin or rgb(150, 170, 196), rgb(110, 130, 160), rgb(236, 240, 246)
		rig.pivots.tail = Vector3.new(0, 0, 0.9)
		rig.pivots.finL = Vector3.new(-0.55, -0.2, -0.3)
		rig.pivots.finR = Vector3.new(0.55, -0.2, -0.3)
		E(rig, "body", "Body", Vector3.new(1.25, 1.1, 2.2), CFrame.new(0, 0, 0), skin)
		E(rig, "body", "Belly", Vector3.new(1.0, 0.6, 1.8), CFrame.new(0, -0.28, -0.1), belly)
		for i, at in ipairs({ { -0.3, 0.35, 0.2 }, { 0.32, 0.3, -0.1 }, { 0.05, 0.45, 0.55 } }) do
			B(rig, "body", "Spot" .. i, 0.2, CFrame.new(at[1], at[2], at[3]), spot)
		end
		Cy(
			rig,
			"body",
			"Horn",
			Vector3.new(1.3, 0.16, 0.16),
			CFrame.new(0, 0.32, -1.55) * deg(0, 90, 0) * deg(0, 0, -12),
			rgb(244, 232, 200)
		)
		for k = 0, 2 do
			Cy(
				rig,
				"body",
				"HornRing",
				Vector3.new(0.05, 0.2 - k * 0.03, 0.2 - k * 0.03),
				CFrame.new(0, 0.3 + k * 0.06, -1.2 - k * 0.3) * deg(0, 90, 0) * deg(0, 0, -12),
				rgb(214, 196, 160)
			)
		end
		eyes(rig, "body", 0.4, 0.12, -0.82, 0.22)
		K(rig, "body", "Smile", Vector3.new(0.4, 0.05, 0.05), CFrame.new(0, -0.08, -1.05), rgb(70, 60, 80))
		for _, side in ipairs({ -1, 1 }) do
			E(
				rig,
				side < 0 and "finL" or "finR",
				"Flipper",
				Vector3.new(0.6, 0.12, 0.36),
				CFrame.new(side * 0.72, -0.3, -0.3) * deg(0, side * 20, side * -20),
				skin
			)
			E(
				rig,
				"tail",
				"Fluke",
				Vector3.new(0.62, 0.1, 0.36),
				CFrame.new(side * 0.3, 0, 1.25) * deg(0, side * 30, 0),
				skin
			)
		end
		rig.hat = CFrame.new(0, 0.62, -0.3)
	end

	-- Lumo: a grumpy anglerfish: dark and round, a jaw of jagged teeth, and a glowing lure on a stalk.
	BUILD.Lumo = function(rig, look)
		local skin, lure = look.skin or rgb(40, 70, 86), look.lure or rgb(170, 255, 230)
		rig.pivots.lure = Vector3.new(0, 0.7, -0.2)
		rig.pivots.tail = Vector3.new(0, 0, 0.65)
		rig.pivots.finL = Vector3.new(-0.6, 0, 0)
		rig.pivots.finR = Vector3.new(0.6, 0, 0)
		B(rig, "body", "Body", 1.4, CFrame.new(0, 0, 0), skin)
		E(rig, "body", "Jaw", Vector3.new(1.2, 0.5, 0.9), CFrame.new(0, -0.38, -0.38), skin:Lerp(BLACK, 0.2))
		K(rig, "body", "Mouth", Vector3.new(0.9, 0.12, 0.1), CFrame.new(0, -0.2, -0.76), rgb(20, 20, 26))
		for i = -2, 2 do
			W(
				rig,
				"body",
				"Tooth",
				Vector3.new(0.06, 0.18, 0.12),
				CFrame.new(i * 0.17, -0.1, -0.78) * deg(180, 0, 0),
				WHITE
			)
		end
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "body", "Eye", 0.22, CFrame.new(side * 0.3, 0.32, -0.56), rgb(255, 240, 160))
			B(rig, "body", "Pupil", 0.1, CFrame.new(side * 0.3, 0.32, -0.66), BLACK)
			E(
				rig,
				side < 0 and "finL" or "finR",
				"Fin",
				Vector3.new(0.1, 0.4, 0.46),
				CFrame.new(side * 0.72, -0.05, 0.1),
				skin:Lerp(lure, 0.15)
			)
		end
		Cy(rig, "lure", "Stalk", Vector3.new(0.8, 0.07, 0.07), CFrame.new(0, 0.95, -0.38) * deg(0, 0, 70), skin)
		B(rig, "lure", "Lure", 0.3, CFrame.new(0, 1.28, -0.66), lure, NEON)
		W(rig, "tail", "TailFin", Vector3.new(0.1, 0.7, 0.55), CFrame.new(0, 0, 0.9) * deg(0, 180, 0), skin)
		rig.light = { part = "Lure", color = lure, range = 9 }
		rig.hat = CFrame.new(0, 0.7, 0.15)
	end

	-- Kelp the Otter: a sea otter with a cream face, whiskers, a flat tail, and a favourite shell held to its chest.
	BUILD.Otter = function(rig, look)
		local fur, face = look.fur or rgb(132, 92, 62), rgb(232, 210, 176)
		rig.pivots.legA = Vector3.new(0, 0.35, 0)
		rig.pivots.legB = Vector3.new(0, 0.35, 0)
		rig.pivots.tail = Vector3.new(0, 0.45, 0.6)
		rig.pivots.head = Vector3.new(0, 1.2, -0.3)
		E(rig, "body", "Body", Vector3.new(1.0, 1.15, 1.5), CFrame.new(0, 0.75, 0.1), fur)
		E(rig, "body", "Chest", Vector3.new(0.75, 0.8, 0.5), CFrame.new(0, 0.75, -0.5), face)
		E(
			rig,
			"body",
			"Shell",
			Vector3.new(0.5, 0.42, 0.18),
			CFrame.new(0, 0.9, -0.78) * deg(-20, 0, 0),
			rgb(255, 180, 196)
		)
		B(rig, "head", "Head", 0.85, CFrame.new(0, 1.45, -0.42), fur)
		E(rig, "head", "Muzzle", Vector3.new(0.6, 0.38, 0.4), CFrame.new(0, 1.32, -0.78), face)
		B(rig, "head", "Nose", 0.16, CFrame.new(0, 1.42, -0.98), rgb(50, 36, 30))
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "head", "Ear", 0.22, CFrame.new(side * 0.38, 1.78, -0.36), fur)
			B(rig, "head", "Eye", 0.14, CFrame.new(side * 0.2, 1.56, -0.8), BLACK)
			K(
				rig,
				"head",
				"Whisker",
				Vector3.new(0.4, 0.03, 0.03),
				CFrame.new(side * 0.42, 1.3, -0.88) * deg(0, side * 15, 0),
				WHITE
			)
			E(
				rig,
				side < 0 and "legA" or "legB",
				"Paw",
				Vector3.new(0.3, 0.26, 0.42),
				CFrame.new(side * 0.36, 0.15, -0.3),
				fur
			)
			E(
				rig,
				side < 0 and "legB" or "legA",
				"Foot",
				Vector3.new(0.34, 0.2, 0.5),
				CFrame.new(side * 0.34, 0.12, 0.55),
				fur
			)
		end
		E(rig, "tail", "Tail", Vector3.new(0.34, 0.2, 1.1), CFrame.new(0, 0.32, 1.2) * deg(10, 0, 0), fur)
		rig.hat = CFrame.new(0, 1.88, -0.42)
		rig.hatGroup = "head"
	end

	-- PIRATE --------------------------------------------------------------------------------------------------------------

	-- Captain Squawk: a parrot in every colour, with a hooked beak, a crest and a long tail.
	BUILD.Parrot = function(rig, look)
		local red, blue, yellow = look.red or rgb(232, 50, 46), look.blue or rgb(40, 110, 230), rgb(255, 210, 50)
		rig.pivots.head = Vector3.new(0, 0.4, -0.3)
		rig.pivots.wingL = Vector3.new(-0.35, 0.2, 0)
		rig.pivots.wingR = Vector3.new(0.35, 0.2, 0)
		rig.pivots.tail = Vector3.new(0, -0.2, 0.5)
		E(rig, "body", "Body", Vector3.new(0.8, 1.15, 0.9), CFrame.new(0, 0, 0) * deg(-15, 0, 0), red)
		B(rig, "head", "Head", 0.72, CFrame.new(0, 0.62, -0.25), red)
		E(rig, "head", "Cheek", Vector3.new(0.5, 0.36, 0.2), CFrame.new(0, 0.55, -0.55), rgb(255, 250, 240))
		E(
			rig,
			"head",
			"Beak",
			Vector3.new(0.26, 0.42, 0.34),
			CFrame.new(0, 0.5, -0.72) * deg(20, 0, 0),
			rgb(240, 220, 170)
		)
		E(rig, "head", "BeakTip", Vector3.new(0.14, 0.2, 0.14), CFrame.new(0, 0.3, -0.8), rgb(40, 34, 36))
		W(rig, "head", "Crest", Vector3.new(0.1, 0.42, 0.44), CFrame.new(0, 1.05, -0.1) * deg(-15, 180, 0), yellow)
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "head", "Eye", 0.13, CFrame.new(side * 0.26, 0.72, -0.48), BLACK)
			local group = side < 0 and "wingL" or "wingR"
			E(rig, group, "Wing", Vector3.new(1.3, 0.12, 0.74), CFrame.new(side * 0.85, 0.15, 0.05), blue)
			E(rig, group, "WingTip", Vector3.new(0.6, 0.1, 0.5), CFrame.new(side * 1.45, 0.15, 0.15), yellow)
			E(rig, "body", "Leg", Vector3.new(0.12, 0.32, 0.12), CFrame.new(side * 0.16, -0.62, 0.05), rgb(90, 90, 96))
		end
		W(rig, "tail", "TailRed", Vector3.new(0.3, 0.12, 1.3), CFrame.new(-0.08, -0.38, 0.95) * deg(-20, 180, 0), red)
		W(rig, "tail", "TailBlue", Vector3.new(0.28, 0.12, 1.1), CFrame.new(0.12, -0.36, 0.88) * deg(-20, 180, 0), blue)
		rig.hat = CFrame.new(0, 1.0, -0.25)
		rig.hatGroup = "head"
	end

	-- Scuttlebutt: a ship's rat in a red bandana, pink ears and nose, whiskers and a long bare tail.
	BUILD.Rat = function(rig, look)
		local fur, pink = look.fur or rgb(150, 146, 150), rgb(255, 170, 180)
		rig.pivots.legA = Vector3.new(0, 0.3, 0)
		rig.pivots.legB = Vector3.new(0, 0.3, 0)
		rig.pivots.tail = Vector3.new(0, 0.35, 0.6)
		rig.pivots.head = Vector3.new(0, 0.6, -0.4)
		E(rig, "body", "Body", Vector3.new(0.85, 0.72, 1.4), CFrame.new(0, 0.48, 0.1), fur)
		E(rig, "head", "Head", Vector3.new(0.62, 0.58, 0.85), CFrame.new(0, 0.62, -0.62) * deg(10, 0, 0), fur)
		B(rig, "head", "Nose", 0.16, CFrame.new(0, 0.56, -1.06), pink)
		K(rig, "head", "Bandana", Vector3.new(0.66, 0.18, 0.62), CFrame.new(0, 0.86, -0.56), rgb(214, 40, 44))
		B(rig, "head", "Knot", 0.18, CFrame.new(0.32, 0.86, -0.3), rgb(214, 40, 44))
		for _, side in ipairs({ -1, 1 }) do
			Cy(
				rig,
				"head",
				"Ear",
				Vector3.new(0.08, 0.46, 0.46),
				CFrame.new(side * 0.32, 0.98, -0.5) * deg(0, 90, 0),
				fur
			)
			Cy(
				rig,
				"head",
				"EarInner",
				Vector3.new(0.05, 0.32, 0.32),
				CFrame.new(side * 0.32, 0.98, -0.54) * deg(0, 90, 0),
				pink
			)
			B(rig, "head", "Eye", 0.12, CFrame.new(side * 0.17, 0.72, -0.92), BLACK)
			K(rig, "head", "Whisker", Vector3.new(0.36, 0.025, 0.025), CFrame.new(side * 0.3, 0.55, -1.0), WHITE)
			B(rig, side < 0 and "legA" or "legB", "Paw", 0.2, CFrame.new(side * 0.3, 0.1, -0.3), pink)
			B(rig, side < 0 and "legB" or "legA", "Foot", 0.22, CFrame.new(side * 0.3, 0.1, 0.45), pink)
		end
		Cy(
			rig,
			"tail",
			"Tail",
			Vector3.new(0.9, 0.08, 0.08),
			CFrame.new(0, 0.32, 1.15) * deg(0, 90, 0) * deg(0, 0, 10),
			pink
		)
		Cy(
			rig,
			"tail",
			"TailTip",
			Vector3.new(0.6, 0.06, 0.06),
			CFrame.new(0.15, 0.42, 1.65) * deg(0, 60, 0) * deg(0, 0, 25),
			pink
		)
		rig.hat = CFrame.new(0, 1.0, -0.6)
		rig.hatGroup = "head"
	end

	-- Flittermouse: a sleepy little bat: big pointed ears, tiny fangs, leathery wings on bony fingers.
	BUILD.Bat = function(rig, look)
		local fur, wing = look.fur or rgb(86, 64, 96), look.wing or rgb(60, 44, 70)
		rig.pivots.wingL = Vector3.new(-0.3, 0.1, 0)
		rig.pivots.wingR = Vector3.new(0.3, 0.1, 0)
		B(rig, "body", "Body", 0.85, CFrame.new(0, 0, 0), fur)
		B(rig, "head", "Head", 0.66, CFrame.new(0, 0.5, -0.12), fur)
		for _, side in ipairs({ -1, 1 }) do
			W(
				rig,
				"head",
				"Ear",
				Vector3.new(0.1, 0.55, 0.34),
				CFrame.new(side * 0.22, 0.95, -0.1) * deg(0, 0, side * -10),
				fur
			)
			B(rig, "head", "Eye", 0.14, CFrame.new(side * 0.15, 0.56, -0.42), rgb(255, 220, 120))
			W(
				rig,
				"head",
				"Fang",
				Vector3.new(0.04, 0.1, 0.06),
				CFrame.new(side * 0.07, 0.34, -0.42) * deg(180, 0, 0),
				WHITE
			)
			local group = side < 0 and "wingL" or "wingR"
			W(
				rig,
				group,
				"Membrane",
				Vector3.new(0.08, 0.7, 1.1),
				CFrame.new(side * 0.85, 0.05, 0.05) * deg(0, 90, side * 90),
				wing
			)
			W(
				rig,
				group,
				"Membrane2",
				Vector3.new(0.08, 0.5, 0.8),
				CFrame.new(side * 1.35, -0.05, 0.1) * deg(0, 90, side * 90),
				wing
			)
			Cy(rig, group, "Finger", Vector3.new(1.5, 0.06, 0.06), CFrame.new(side * 1.0, 0.25, 0), fur)
		end
		rig.hat = CFrame.new(0, 0.85, -0.12)
		rig.hatGroup = "head"
	end

	-- Rascal: a cheeky monkey: tan face and belly, round ears, long arms for clapping and a curly tail.
	BUILD.Monkey = function(rig, look)
		local fur, face = look.fur or rgb(150, 96, 56), rgb(236, 200, 160)
		rig.pivots.legBack = Vector3.new(0, 0.35, 0.1)
		rig.pivots.armL = Vector3.new(-0.42, 1.0, -0.1)
		rig.pivots.armR = Vector3.new(0.42, 1.0, -0.1)
		rig.pivots.tail = Vector3.new(0, 0.5, 0.4)
		rig.pivots.head = Vector3.new(0, 1.3, 0)
		E(rig, "body", "Body", Vector3.new(0.9, 1.05, 0.8), CFrame.new(0, 0.75, 0), fur)
		E(rig, "body", "Belly", Vector3.new(0.6, 0.7, 0.3), CFrame.new(0, 0.7, -0.32), face)
		B(rig, "head", "Head", 0.85, CFrame.new(0, 1.55, -0.05), fur)
		E(rig, "head", "Face", Vector3.new(0.6, 0.55, 0.3), CFrame.new(0, 1.5, -0.35), face)
		for _, side in ipairs({ -1, 1 }) do
			Cy(rig, "head", "Ear", Vector3.new(0.1, 0.36, 0.36), CFrame.new(side * 0.46, 1.6, 0) * deg(0, 0, 0), face)
			B(rig, "head", "Eye", 0.13, CFrame.new(side * 0.13, 1.62, -0.48), BLACK)
			local arm = side < 0 and "armL" or "armR"
			E(
				rig,
				arm,
				"Arm",
				Vector3.new(0.22, 0.85, 0.22),
				CFrame.new(side * 0.55, 0.65, -0.1) * deg(0, 0, side * 12),
				fur
			)
			B(rig, arm, "Hand", 0.22, CFrame.new(side * 0.6, 0.25, -0.12), face)
			E(rig, "legBack", "Leg", Vector3.new(0.26, 0.4, 0.4), CFrame.new(side * 0.28, 0.2, 0.05), fur)
		end
		K(rig, "head", "Grin", Vector3.new(0.3, 0.05, 0.05), CFrame.new(0, 1.38, -0.5), rgb(120, 60, 40))
		Cy(
			rig,
			"tail",
			"Tail",
			Vector3.new(1.0, 0.1, 0.1),
			CFrame.new(0, 0.7, 0.75) * deg(0, 90, 0) * deg(0, 0, 50),
			fur
		)
		B(rig, "tail", "TailCurl", 0.24, CFrame.new(0, 1.18, 1.0), fur)
		rig.hat = CFrame.new(0, 2.0, -0.05)
		rig.hatGroup = "head"
	end

	-- Noodle: a long, wiggly ferret in three segments with a bandit mask.
	BUILD.Ferret = function(rig, look)
		local fur, mask, cream = look.fur or rgb(176, 130, 90), rgb(80, 56, 40), rgb(244, 228, 200)
		rig.pivots.legA = Vector3.new(0, 0.3, 0)
		rig.pivots.legB = Vector3.new(0, 0.3, 0)
		rig.pivots.seg1 = Vector3.new(0, 0.4, -0.5)
		rig.pivots.seg2 = Vector3.new(0, 0.4, 0.2)
		rig.pivots.seg3 = Vector3.new(0, 0.4, 0.9)
		E(rig, "seg1", "Chest", Vector3.new(0.6, 0.55, 0.85), CFrame.new(0, 0.42, -0.45), fur)
		E(rig, "seg2", "Middle", Vector3.new(0.58, 0.52, 0.9), CFrame.new(0, 0.42, 0.25), fur)
		E(rig, "seg3", "Hips", Vector3.new(0.56, 0.5, 0.8), CFrame.new(0, 0.42, 0.9), fur)
		E(
			rig,
			"seg3",
			"Tail",
			Vector3.new(0.24, 0.24, 0.9),
			CFrame.new(0, 0.48, 1.6) * deg(-10, 0, 0),
			fur:Lerp(mask, 0.4)
		)
		E(rig, "head", "Head", Vector3.new(0.5, 0.45, 0.62), CFrame.new(0, 0.6, -1.0), cream)
		E(rig, "head", "Mask", Vector3.new(0.52, 0.18, 0.3), CFrame.new(0, 0.68, -1.12), mask)
		B(rig, "head", "Nose", 0.1, CFrame.new(0, 0.58, -1.32), rgb(220, 120, 130))
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "head", "Eye", 0.09, CFrame.new(side * 0.13, 0.7, -1.28), BLACK)
			B(rig, "head", "Ear", 0.16, CFrame.new(side * 0.2, 0.86, -0.92), cream)
			B(rig, side < 0 and "legA" or "legB", "Paw", 0.18, CFrame.new(side * 0.22, 0.1, -0.45), mask)
			B(rig, side < 0 and "legB" or "legA", "Foot", 0.18, CFrame.new(side * 0.22, 0.1, 0.85), mask)
		end
		rig.pivots.head = Vector3.new(0, 0.6, -0.8)
		rig.hat = CFrame.new(0, 0.9, -1.0)
		rig.hatGroup = "head"
	end

	-- Fuse: a walking cannonball with a fizzing fuse, cartoon eyes and little boots.
	BUILD.Fuse = function(rig, look)
		local iron, spark = look.iron or rgb(40, 40, 48), look.spark or rgb(255, 196, 70)
		rig.pivots.legA = Vector3.new(0, 0.25, 0)
		rig.pivots.legB = Vector3.new(0, 0.25, 0)
		rig.pivots.flame = Vector3.new(0, 1.85, 0.1)
		B(rig, "body", "Ball", 1.4, CFrame.new(0, 1.0, 0), iron, METAL)
		B(rig, "body", "Shine", 0.36, CFrame.new(-0.32, 1.38, -0.5), rgb(160, 160, 176))
		Cy(
			rig,
			"body",
			"Band",
			Vector3.new(0.14, 1.42, 1.42),
			CFrame.new(0, 1.0, 0) * deg(0, 0, 90) * deg(0, 0, 0),
			GOLD,
			METAL
		)
		Cy(
			rig,
			"body",
			"Cap",
			Vector3.new(0.3, 0.4, 0.4),
			CFrame.new(0, 1.74, 0.05) * UPRIGHT,
			rgb(120, 110, 100),
			METAL
		)
		Cy(
			rig,
			"flame",
			"Wick",
			Vector3.new(0.4, 0.08, 0.08),
			CFrame.new(0.05, 1.98, 0.1) * deg(0, 0, 70),
			rgb(200, 180, 140)
		)
		B(rig, "flame", "Spark", 0.24, CFrame.new(0.12, 2.18, 0.1), spark, NEON)
		eyes(rig, "body", 0.24, 1.12, -0.6, 0.34)
		for _, side in ipairs({ -1, 1 }) do
			E(
				rig,
				side < 0 and "legA" or "legB",
				"Boot",
				Vector3.new(0.36, 0.28, 0.52),
				CFrame.new(side * 0.32, 0.14, -0.05),
				rgb(110, 70, 40)
			)
			E(rig, "body", "Hand", Vector3.new(0.26, 0.26, 0.26), CFrame.new(side * 0.78, 0.85, -0.2), WHITE)
		end
		rig.light = { part = "Spark", color = spark, range = 6 }
		rig.hat = CFrame.new(0, 1.7, -0.35)
	end

	-- Chompers: a treasure chest with legs, teeth and a tongue; the lid snaps.
	BUILD.Chompers = function(rig, look)
		local wood, trim = look.wood or rgb(150, 96, 54), look.trim or GOLD
		rig.pivots.lid = Vector3.new(0, 1.12, 0.48)
		rig.pivots.legBack = Vector3.new(0, 0.3, 0.3)
		rig.pivots.legFront = Vector3.new(0, 0.3, -0.3)
		K(rig, "body", "Box", Vector3.new(1.4, 0.8, 1.0), CFrame.new(0, 0.72, 0), wood, WOOD)
		K(rig, "body", "BoxBand", Vector3.new(1.44, 0.14, 1.04), CFrame.new(0, 0.6, 0), trim, METAL)
		E(rig, "body", "Tongue", Vector3.new(0.6, 0.12, 0.5), CFrame.new(0, 1.1, -0.15), rgb(236, 90, 110))
		K(rig, "lid", "Lid", Vector3.new(1.42, 0.42, 1.02), CFrame.new(0, 1.33, 0), wood, WOOD)
		K(rig, "lid", "LidBand", Vector3.new(1.46, 0.12, 1.06), CFrame.new(0, 1.3, 0), trim, METAL)
		for i = -2, 2 do
			W(
				rig,
				"lid",
				"Tooth",
				Vector3.new(0.12, 0.16, 0.1),
				CFrame.new(i * 0.25, 1.06, -0.5) * deg(180, 0, 0),
				WHITE
			)
			W(rig, "body", "LowTooth", Vector3.new(0.12, 0.14, 0.1), CFrame.new(i * 0.25 + 0.12, 1.16, -0.5), WHITE)
		end
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "lid", "Eye", 0.28, CFrame.new(side * 0.3, 1.6, -0.3), WHITE)
			B(rig, "lid", "Pupil", 0.13, CFrame.new(side * 0.3, 1.62, -0.42), BLACK)
			E(rig, "legFront", "Leg", Vector3.new(0.2, 0.42, 0.2), CFrame.new(side * 0.5, 0.2, -0.32), wood)
			E(rig, "legBack", "Leg", Vector3.new(0.2, 0.42, 0.2), CFrame.new(side * 0.5, 0.2, 0.32), wood)
		end
		rig.hat = CFrame.new(0, 1.55, 0.1)
		rig.hatGroup = "lid"
	end

	-- MAGIC ---------------------------------------------------------------------------------------------------------------

	-- Shard: a floating crystal sprite with three shards orbiting it like moons.
	BUILD.Shard = function(rig, look)
		local a, b = look.a or rgb(186, 120, 255), look.b or rgb(110, 230, 255)
		K(rig, "body", "GemA", Vector3.new(0.8, 1.5, 0.8), CFrame.new(0, 0, 0) * deg(0, 45, 0), a, GLASS, 0.15)
		K(rig, "body", "GemB", Vector3.new(0.6, 1.1, 0.6), CFrame.new(0, 0, 0) * deg(0, 0, 45), b, NEON, 0.35)
		eyes(rig, "body", 0.17, 0.1, -0.44, 0.2)
		for i = 0, 2 do
			local ang = i / 3 * math.pi * 2
			K(
				rig,
				"orbit",
				"Moon",
				Vector3.new(0.22, 0.42, 0.22),
				CFrame.new(math.cos(ang) * 1.0, 0.1 * i, math.sin(ang) * 1.0) * deg(20, ang * 57, 30),
				i % 2 == 0 and b or a,
				NEON,
				0.2
			)
		end
		rig.light = { part = "GemB", color = a, range = 8 }
		rig.hat = CFrame.new(0, 0.85, 0)
	end

	-- Flurry: a snowflake spirit from Frost Spire, its six arms turning slowly round a smiling face.
	BUILD.Flurry = function(rig, look)
		local ice, frost = look.ice or rgb(214, 240, 255), look.frost or rgb(150, 220, 255)
		B(rig, "body", "Core", 0.7, CFrame.new(0, 0, 0), ice, SMOOTH)
		eyes(rig, "body", 0.13, 0.06, -0.3, 0.16)
		K(rig, "body", "Smile", Vector3.new(0.16, 0.04, 0.04), CFrame.new(0, -0.12, -0.34), rgb(80, 120, 170))
		for i = 0, 5 do
			local ang = math.rad(i * 60)
			local dir = Vector3.new(math.cos(ang), math.sin(ang), 0)
			K(
				rig,
				"halo",
				"Arm",
				Vector3.new(0.14, 0.9, 0.08),
				CFrame.new(dir * 0.75 + Vector3.new(0, 0, 0.05)) * CFrame.Angles(0, 0, ang - math.rad(90)),
				frost,
				NEON,
				0.15
			)
			K(
				rig,
				"halo",
				"Twig",
				Vector3.new(0.1, 0.32, 0.06),
				CFrame.new(dir * 0.95 + Vector3.new(0, 0, 0.05)) * CFrame.Angles(0, 0, ang - math.rad(90) + 0.8),
				ice,
				NEON,
				0.2
			)
		end
		rig.hat = CFrame.new(0, 0.42, 0)
	end

	-- Glimmer: a will-o'-the-wisp: a bright light with a shy face and a tail of sparks.
	BUILD.Glimmer = function(rig, look)
		local glow, core = look.glow or rgb(255, 236, 150), look.core or rgb(255, 250, 220)
		rig.pivots.tail1 = Vector3.new(0, -0.1, 0.3)
		rig.pivots.tail2 = Vector3.new(0, -0.3, 0.7)
		rig.pivots.tail3 = Vector3.new(0, -0.45, 1.05)
		B(rig, "body", "Halo", 1.3, CFrame.new(0, 0, 0), glow, NEON, 0.7)
		B(rig, "body", "Core", 0.8, CFrame.new(0, 0, 0), core, NEON, 0.05)
		for _, side in ipairs({ -1, 1 }) do
			E(rig, "body", "Eye", Vector3.new(0.1, 0.16, 0.06), CFrame.new(side * 0.14, 0.05, -0.4), rgb(120, 90, 40))
			E(
				rig,
				"body",
				"Blush",
				Vector3.new(0.12, 0.06, 0.04),
				CFrame.new(side * 0.24, -0.08, -0.38),
				rgb(255, 160, 140)
			)
		end
		B(rig, "tail1", "Spark", 0.36, CFrame.new(0, -0.2, 0.55), glow, NEON, 0.2)
		B(rig, "tail2", "Spark", 0.24, CFrame.new(0.1, -0.38, 0.9), glow, NEON, 0.35)
		B(rig, "tail3", "Spark", 0.14, CFrame.new(-0.05, -0.5, 1.2), glow, NEON, 0.5)
		rig.light = { part = "Core", color = glow, range = 8 }
		rig.hat = CFrame.new(0, 0.48, 0)
	end

	-- Dubloon: a living gold coin that rolls along on its edge, a goblin face stamped on it.
	BUILD.Dubloon = function(rig, look)
		local gold, deep = look.gold or GOLD, rgb(214, 150, 40)
		local center = CFrame.new(0, 0.9, 0)
		Cy(rig, "body", "Coin", Vector3.new(0.34, 1.8, 1.8), center * deg(0, 90, 0), gold, FOIL)
		Cy(rig, "body", "Rim", Vector3.new(0.38, 1.82, 1.82), center * deg(0, 90, 0), deep, METAL, 0.5)
		Cy(rig, "body", "Stamp", Vector3.new(0.4, 1.2, 1.2), center * deg(0, 90, 0), deep, METAL)
		-- The face, stamped on the side that looks forward.
		B(rig, "body", "Nose", 0.3, CFrame.new(0, 0.85, -0.22), gold, METAL)
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "body", "Eye", 0.2, CFrame.new(side * 0.25, 1.1, -0.18), WHITE)
			B(rig, "body", "Pupil", 0.1, CFrame.new(side * 0.25, 1.1, -0.27), BLACK)
			W(
				rig,
				"body",
				"Ear",
				Vector3.new(0.08, 0.3, 0.42),
				CFrame.new(side * 0.58, 1.1, -0.18) * deg(0, 0, side * -50),
				gold,
				METAL
			)
		end
		K(rig, "body", "Grin", Vector3.new(0.4, 0.06, 0.06), CFrame.new(0, 0.62, -0.2), rgb(120, 80, 20))
		rig.hat = CFrame.new(0, 1.82, 0)
	end

	-- Rubble: a pebble golem: boulder body, a mossy head, glowing amber eyes, rock fists and stumpy legs.
	BUILD.Rubble = function(rig, look)
		local stone, moss = look.stone or rgb(140, 132, 124), look.moss or rgb(96, 160, 70)
		rig.pivots.legA = Vector3.new(0, 0.4, 0)
		rig.pivots.legB = Vector3.new(0, 0.4, 0)
		rig.pivots.armL = Vector3.new(-0.7, 1.1, 0)
		rig.pivots.armR = Vector3.new(0.7, 1.1, 0)
		rig.pivots.head = Vector3.new(0, 1.5, 0)
		E(rig, "body", "Body", Vector3.new(1.4, 1.2, 1.1), CFrame.new(0, 0.95, 0) * deg(5, 20, 3), stone, SLATE)
		E(
			rig,
			"body",
			"Pebble",
			Vector3.new(0.5, 0.36, 0.4),
			CFrame.new(0.4, 1.3, -0.4) * deg(10, 30, 5),
			stone:Lerp(BLACK, 0.15),
			SLATE
		)
		E(rig, "head", "Head", Vector3.new(0.9, 0.75, 0.82), CFrame.new(0, 1.8, -0.05) * deg(0, -10, 0), stone, SLATE)
		E(rig, "head", "Moss", Vector3.new(0.8, 0.26, 0.7), CFrame.new(0, 2.15, 0), moss)
		glowEyes(rig, "head", 0.2, 1.84, -0.42, 0.16, rgb(255, 180, 60))
		for _, side in ipairs({ -1, 1 }) do
			local arm = side < 0 and "armL" or "armR"
			E(rig, arm, "Arm", Vector3.new(0.42, 0.55, 0.42), CFrame.new(side * 0.85, 0.95, 0), stone, SLATE)
			E(
				rig,
				arm,
				"Fist",
				Vector3.new(0.55, 0.5, 0.55),
				CFrame.new(side * 0.92, 0.55, -0.05),
				stone:Lerp(BLACK, 0.1),
				SLATE
			)
			E(
				rig,
				side < 0 and "legA" or "legB",
				"Leg",
				Vector3.new(0.5, 0.5, 0.55),
				CFrame.new(side * 0.36, 0.25, 0.05),
				stone,
				SLATE
			)
		end
		rig.hat = CFrame.new(0, 2.2, -0.05)
		rig.hatGroup = "head"
	end

	-- Spore: a hopping toadstool from Tangle Isle: a spotted red cap over a cream stem with a face on it.
	BUILD.Spore = function(rig, look)
		local cap, stem = look.cap or rgb(226, 54, 52), look.stem or rgb(246, 236, 210)
		rig.pivots.legBack = Vector3.new(0, 0.2, 0)
		rig.pivots.head = Vector3.new(0, 1.0, 0)
		Cy(rig, "body", "Stem", Vector3.new(0.9, 0.8, 0.8), CFrame.new(0, 0.55, 0) * UPRIGHT, stem)
		E(rig, "head", "Cap", Vector3.new(1.6, 0.8, 1.6), CFrame.new(0, 1.15, 0), cap)
		E(rig, "head", "Gills", Vector3.new(1.3, 0.2, 1.3), CFrame.new(0, 0.85, 0), stem:Lerp(cap, 0.25))
		for i, at in ipairs({
			{ 0, 1.52, 0 },
			{ -0.45, 1.3, -0.3 },
			{ 0.5, 1.3, -0.2 },
			{ -0.2, 1.32, 0.5 },
			{ 0.38, 1.28, 0.42 },
		}) do
			B(rig, "head", "Spot" .. i, 0.26, CFrame.new(at[1], at[2], at[3]), WHITE)
		end
		eyes(rig, "body", 0.16, 0.65, -0.38, 0.2)
		K(rig, "body", "Mouth", Vector3.new(0.2, 0.05, 0.05), CFrame.new(0, 0.42, -0.42), rgb(120, 70, 50))
		for _, side in ipairs({ -1, 1 }) do
			E(rig, "legBack", "Foot", Vector3.new(0.3, 0.16, 0.42), CFrame.new(side * 0.22, 0.08, -0.05), stem)
		end
		rig.hat = CFrame.new(0, 1.62, 0)
		rig.hatGroup = "head"
	end

	-- Lantern Moth: a fuzzy moth with a glowing lantern belly, feathery antennae and soft eye-spotted wings.
	BUILD.Moth = function(rig, look)
		local fuzz, wing, lamp = look.fuzz or rgb(236, 224, 200), look.wing or rgb(170, 150, 190), rgb(255, 180, 80)
		rig.pivots.wingL = Vector3.new(-0.2, 0.1, 0)
		rig.pivots.wingR = Vector3.new(0.2, 0.1, 0)
		E(rig, "body", "Body", Vector3.new(0.5, 0.55, 0.9), CFrame.new(0, 0.15, 0), fuzz)
		E(rig, "body", "Lantern", Vector3.new(0.48, 0.5, 0.62), CFrame.new(0, -0.15, 0.35), lamp, NEON)
		B(rig, "head", "Head", 0.46, CFrame.new(0, 0.32, -0.48), fuzz)
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "head", "Eye", 0.2, CFrame.new(side * 0.16, 0.36, -0.62), BLACK)
			W(
				rig,
				"head",
				"Antenna",
				Vector3.new(0.05, 0.5, 0.26),
				CFrame.new(side * 0.12, 0.7, -0.5) * deg(-10, 0, side * -20),
				fuzz
			)
			local group = side < 0 and "wingL" or "wingR"
			E(rig, group, "Wing", Vector3.new(1.3, 0.08, 0.9), CFrame.new(side * 0.8, 0.25, -0.15), wing)
			E(
				rig,
				group,
				"HindWing",
				Vector3.new(0.85, 0.07, 0.7),
				CFrame.new(side * 0.62, 0.2, 0.45),
				wing:Lerp(WHITE, 0.2)
			)
			Cy(
				rig,
				group,
				"EyeSpot",
				Vector3.new(0.09, 0.4, 0.4),
				CFrame.new(side * 0.95, 0.3, -0.1) * UPRIGHT,
				rgb(90, 60, 110)
			)
		end
		rig.light = { part = "Lantern", color = lamp, range = 8 }
		rig.hat = CFrame.new(0, 0.6, -0.48)
		rig.hatGroup = "head"
	end

	-- ISLAND (the escape pets and the island shop pets) -----------------------------------------------------------------

	-- Little Leviathan: a tiny Leviathan weaving through the air: horned head, amber eyes, five humps, a fluke.
	BUILD.Levi = function(rig, look)
		local back, belly, eye = look.back or rgb(36, 96, 110), look.belly or rgb(170, 214, 200), rgb(255, 176, 50)
		local sizes = { 0.62, 0.56, 0.48, 0.4, 0.3 }
		for i, s in ipairs(sizes) do
			rig.pivots["seg" .. i] = Vector3.new(0, 0, 0.35 + i * 0.42)
			E(rig, "seg" .. i, "Hump", Vector3.new(s, s * 0.9, 0.62), CFrame.new(0, 0, 0.35 + i * 0.42), back)
			E(
				rig,
				"seg" .. i,
				"Belly",
				Vector3.new(s * 0.75, s * 0.4, 0.5),
				CFrame.new(0, -s * 0.25, 0.35 + i * 0.42),
				belly
			)
			if i % 2 == 1 then
				W(
					rig,
					"seg" .. i,
					"Fin",
					Vector3.new(0.06, s * 0.6, 0.36),
					CFrame.new(0, s * 0.5, 0.35 + i * 0.42),
					belly
				)
			end
		end
		W(rig, "seg5", "Fluke", Vector3.new(0.6, 0.06, 0.4), CFrame.new(0, 0, 2.75) * deg(0, 180, 0), back)
		E(rig, "head", "Head", Vector3.new(0.72, 0.6, 0.85), CFrame.new(0, 0.05, -0.15), back)
		E(rig, "head", "Jaw", Vector3.new(0.6, 0.22, 0.7), CFrame.new(0, -0.22, -0.3), belly)
		for _, side in ipairs({ -1, 1 }) do
			E(rig, "head", "Eye", Vector3.new(0.14, 0.18, 0.12), CFrame.new(side * 0.26, 0.15, -0.46), eye, NEON)
			W(
				rig,
				"head",
				"Horn",
				Vector3.new(0.08, 0.36, 0.3),
				CFrame.new(side * 0.2, 0.42, 0.05) * deg(-30, 0, side * -15),
				belly
			)
		end
		rig.pivots.head = Vector3.new(0, 0, 0.1)
		rig.hat = CFrame.new(0, 0.42, -0.15)
		rig.hatGroup = "head"
	end

	-- Sunny: a tiny Sun Temple Guardian: sandstone, gold bands, burning eyes and a turning sun halo.
	BUILD.Sunny = function(rig, look)
		local stone, band = look.stone or rgb(226, 190, 132), GOLD
		rig.pivots.legA = Vector3.new(0, 0.4, 0)
		rig.pivots.legB = Vector3.new(0, 0.4, 0)
		rig.pivots.armL = Vector3.new(-0.75, 1.25, 0)
		rig.pivots.armR = Vector3.new(0.75, 1.25, 0)
		rig.pivots.halo = Vector3.new(0, 2.0, 0.25)
		K(rig, "body", "Body", Vector3.new(1.2, 1.1, 0.95), CFrame.new(0, 1.05, 0), stone, SLATE)
		K(rig, "body", "Band", Vector3.new(1.26, 0.18, 1.0), CFrame.new(0, 1.15, 0), band, METAL)
		K(rig, "body", "Head", Vector3.new(0.85, 0.7, 0.75), CFrame.new(0, 1.85, -0.05), stone, SLATE)
		K(rig, "body", "Brow", Vector3.new(0.9, 0.14, 0.2), CFrame.new(0, 2.0, -0.4), band, METAL)
		glowEyes(rig, "body", 0.2, 1.85, -0.42, 0.14, rgb(255, 140, 40))
		Cy(rig, "halo", "Halo", Vector3.new(0.1, 1.5, 1.5), CFrame.new(0, 2.0, 0.3) * deg(0, 90, 0), band, NEON, 0.2)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			W(
				rig,
				"halo",
				"Ray",
				Vector3.new(0.06, 0.32, 0.18),
				CFrame.new(math.cos(a) * 0.88, 2.0 + math.sin(a) * 0.88, 0.32) * CFrame.Angles(0, 0, a - math.rad(90)),
				band,
				NEON,
				0.1
			)
		end
		for _, side in ipairs({ -1, 1 }) do
			local arm = side < 0 and "armL" or "armR"
			K(rig, arm, "Arm", Vector3.new(0.38, 0.62, 0.42), CFrame.new(side * 0.82, 1.0, 0), stone, SLATE)
			K(rig, arm, "Fist", Vector3.new(0.55, 0.5, 0.55), CFrame.new(side * 0.88, 0.55, -0.05), stone, SLATE)
			K(
				rig,
				side < 0 and "legA" or "legB",
				"Leg",
				Vector3.new(0.42, 0.5, 0.5),
				CFrame.new(side * 0.3, 0.25, 0),
				stone,
				SLATE
			)
		end
		E(rig, "body", "Moss", Vector3.new(0.4, 0.15, 0.3), CFrame.new(0.32, 2.22, 0.1), rgb(96, 160, 70))
		rig.hat = CFrame.new(0, 2.22, -0.05)
	end

	-- Little Echo: a tiny crystal imp, a little see-through, with cyan eyes and a crystal tail.
	BUILD.Echo = function(rig, look)
		local crystal, eye = look.crystal or rgb(196, 120, 255), look.eye or rgb(110, 240, 255)
		rig.pivots.tail1 = Vector3.new(0, -0.3, 0.2)
		rig.pivots.tail2 = Vector3.new(0, -0.55, 0.5)
		rig.pivots.armL = Vector3.new(-0.4, 0, 0)
		rig.pivots.armR = Vector3.new(0.4, 0, 0)
		E(rig, "body", "Body", Vector3.new(0.85, 1.05, 0.75), CFrame.new(0, 0, 0), crystal, GLASS, 0.2)
		E(rig, "body", "Heart", Vector3.new(0.4, 0.45, 0.35), CFrame.new(0, -0.05, 0), eye, NEON, 0.3)
		for _, side in ipairs({ -1, 1 }) do
			W(
				rig,
				"body",
				"Ear",
				Vector3.new(0.08, 0.42, 0.36),
				CFrame.new(side * 0.36, 0.5, 0) * deg(0, 0, side * -25),
				crystal,
				GLASS,
				0.15
			)
			E(rig, "body", "Eye", Vector3.new(0.14, 0.2, 0.08), CFrame.new(side * 0.16, 0.18, -0.36), eye, NEON)
			K(
				rig,
				side < 0 and "armL" or "armR",
				"Arm",
				Vector3.new(0.14, 0.45, 0.14),
				CFrame.new(side * 0.5, -0.1, -0.05) * deg(0, 0, side * 30),
				crystal,
				GLASS,
				0.2
			)
		end
		K(
			rig,
			"tail1",
			"Tail",
			Vector3.new(0.18, 0.5, 0.18),
			CFrame.new(0, -0.55, 0.3) * deg(35, 45, 0),
			crystal,
			GLASS,
			0.2
		)
		K(
			rig,
			"tail2",
			"TailTip",
			Vector3.new(0.14, 0.32, 0.14),
			CFrame.new(0, -0.82, 0.6) * deg(50, 45, 0),
			eye,
			NEON,
			0.3
		)
		rig.light = { part = "Heart", color = eye, range = 7 }
		rig.hat = CFrame.new(0, 0.55, 0)
	end

	-- Lambkin: Bramble's woolly baby: puffs of fleece, a black face, curled horn nubs, thin black legs.
	BUILD.Lamb = function(rig, look)
		local wool, face = look.wool or rgb(244, 238, 222), look.face or rgb(46, 40, 44)
		rig.pivots.legA = Vector3.new(0, 0.5, 0)
		rig.pivots.legB = Vector3.new(0, 0.5, 0)
		rig.pivots.head = Vector3.new(0, 1.0, -0.4)
		for i, at in ipairs({
			{ 0, 1.0, 0 },
			{ -0.3, 1.05, 0.3 },
			{ 0.3, 1.05, 0.3 },
			{ -0.25, 1.1, -0.3 },
			{ 0.28, 1.12, -0.25 },
			{ 0, 1.3, 0.1 },
		}) do
			B(rig, "body", "Wool" .. i, 0.75, CFrame.new(at[1], at[2], at[3]), wool)
		end
		E(rig, "head", "Face", Vector3.new(0.55, 0.6, 0.6), CFrame.new(0, 1.1, -0.7), face)
		B(rig, "head", "Topknot", 0.42, CFrame.new(0, 1.42, -0.55), wool)
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "head", "Horn", 0.24, CFrame.new(side * 0.26, 1.42, -0.65), rgb(200, 170, 120))
			E(
				rig,
				"head",
				"Ear",
				Vector3.new(0.34, 0.12, 0.2),
				CFrame.new(side * 0.36, 1.22, -0.62) * deg(0, 0, side * -20),
				face
			)
			B(rig, "head", "Eye", 0.11, CFrame.new(side * 0.13, 1.18, -0.98), WHITE)
			for _, z in ipairs({ -0.3, 0.3 }) do
				local group = ((side > 0) == (z > 0)) and "legA" or "legB"
				Cy(rig, group, "Leg", Vector3.new(0.6, 0.12, 0.12), CFrame.new(side * 0.26, 0.3, z) * UPRIGHT, face)
			end
		end
		B(rig, "body", "Tail", 0.3, CFrame.new(0, 1.15, 0.62), wool)
		rig.hat = CFrame.new(0, 1.6, -0.55)
		rig.hatGroup = "head"
	end

	-- Bones: a little ghost pirate: tricorn, eyepatch, a waving cutlass, a wisp of a tail.
	BUILD.Bones = function(rig, look)
		local ghost = look.ghost or rgb(170, 255, 220)
		rig.pivots.armR = Vector3.new(0.5, 0.15, 0)
		rig.pivots.armL = Vector3.new(-0.5, 0.15, 0)
		rig.pivots.tail1 = Vector3.new(0, -0.35, 0.1)
		rig.pivots.tail2 = Vector3.new(0, -0.75, 0.25)
		E(rig, "body", "Body", Vector3.new(1.15, 1.25, 1.05), CFrame.new(0, 0.15, 0), ghost, SMOOTH, 0.25)
		E(rig, "tail1", "Tail", Vector3.new(0.78, 0.62, 0.72), CFrame.new(0, -0.55, 0.15), ghost, SMOOTH, 0.32)
		E(rig, "tail2", "TailTip", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0.15, -0.95, 0.32), ghost, SMOOTH, 0.42)
		Cy(rig, "body", "Hat", Vector3.new(0.3, 1.0, 1.0), CFrame.new(0, 0.9, 0) * UPRIGHT, rgb(36, 30, 40))
		for i, n in ipairs({ Vector3.new(0, 0, 1), Vector3.new(-0.866, 0, -0.5), Vector3.new(0.866, 0, -0.5) }) do
			local center = Vector3.new(0, 0.85, 0) + n * 0.5
			K(
				rig,
				"body",
				"Brim" .. i,
				Vector3.new(1.0, 0.24, 0.06),
				CFrame.lookAt(center, center + n) * deg(-25, 0, 0),
				rgb(36, 30, 40)
			)
		end
		E(rig, "body", "Eye", Vector3.new(0.16, 0.26, 0.08), CFrame.new(-0.2, 0.3, -0.5), rgb(30, 60, 50))
		K(rig, "body", "Patch", Vector3.new(0.26, 0.24, 0.06), CFrame.new(0.2, 0.3, -0.52), rgb(20, 20, 24))
		K(
			rig,
			"body",
			"Strap",
			Vector3.new(1.0, 0.05, 0.05),
			CFrame.new(0, 0.42, -0.48) * deg(0, 0, -18),
			rgb(20, 20, 24)
		)
		E(
			rig,
			"armL",
			"Arm",
			Vector3.new(0.24, 0.42, 0.24),
			CFrame.new(-0.62, 0.0, -0.05) * deg(0, 0, -35),
			ghost,
			SMOOTH,
			0.25
		)
		E(
			rig,
			"armR",
			"Arm",
			Vector3.new(0.24, 0.42, 0.24),
			CFrame.new(0.62, 0.05, -0.1) * deg(0, 0, 30),
			ghost,
			SMOOTH,
			0.25
		)
		K(
			rig,
			"armR",
			"Blade",
			Vector3.new(0.06, 0.9, 0.14),
			CFrame.new(0.82, 0.55, -0.25) * deg(-20, 0, -15),
			rgb(220, 226, 236),
			METAL
		)
		K(rig, "armR", "Guard", Vector3.new(0.28, 0.06, 0.12), CFrame.new(0.75, 0.12, -0.18), GOLD, METAL)
		rig.hat = CFrame.new(0, 1.12, 0)
	end

	-- Zap: a mini Warden eel, dark-backed with a crackling cyan stripe, a jaw and fins, sparks round it.
	BUILD.Zap = function(rig, look)
		local back, stripe = look.back or rgb(30, 52, 70), look.stripe or rgb(110, 240, 255)
		local sizes = { 0.42, 0.38, 0.34, 0.28, 0.22 }
		for i, s in ipairs(sizes) do
			local z = 0.3 + i * 0.38
			rig.pivots["seg" .. i] = Vector3.new(0, 0, z)
			E(rig, "seg" .. i, "Segment", Vector3.new(s, s, 0.52), CFrame.new(0, 0, z), back)
			B(rig, "seg" .. i, "Stripe", s * 0.32, CFrame.new(0, s * 0.42, z), stripe, NEON)
		end
		W(
			rig,
			"seg5",
			"TailFin",
			Vector3.new(0.05, 0.3, 0.42),
			CFrame.new(0, 0, 2.4) * deg(0, 180, 0),
			stripe,
			NEON,
			0.2
		)
		E(rig, "head", "Head", Vector3.new(0.48, 0.42, 0.7), CFrame.new(0, 0, -0.1), back)
		E(rig, "head", "Jaw", Vector3.new(0.4, 0.16, 0.55), CFrame.new(0, -0.17, -0.2), back:Lerp(stripe, 0.25))
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "head", "Eye", 0.13, CFrame.new(side * 0.17, 0.1, -0.34), stripe, NEON)
			W(
				rig,
				"head",
				"Fin",
				Vector3.new(0.05, 0.22, 0.3),
				CFrame.new(side * 0.24, 0.05, 0.12) * deg(0, 0, side * 70),
				stripe,
				NEON,
				0.3
			)
		end
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			B(
				rig,
				"orbit",
				"Spark",
				0.12,
				CFrame.new(math.cos(a) * 0.55, math.sin(a) * 0.3 + 0.1, math.sin(a) * 0.55),
				stripe,
				NEON
			)
		end
		rig.pivots.head = Vector3.new(0, 0, 0.1)
		rig.light = { part = "Head", color = stripe, range = 6 }
		rig.hat = CFrame.new(0, 0.3, -0.1)
		rig.hatGroup = "head"
	end

	-- Peek: a pocket Watcher: a round stone statue with carved eyes and a crack, hands up to its cheeks.
	BUILD.Peek = function(rig, look)
		local stone, dark = look.stone or rgb(176, 170, 164), rgb(96, 90, 92)
		rig.pivots.legA = Vector3.new(0, 0.3, 0)
		rig.pivots.legB = Vector3.new(0, 0.3, 0)
		rig.pivots.armL = Vector3.new(-0.5, 1.0, 0)
		rig.pivots.armR = Vector3.new(0.5, 1.0, 0)
		E(rig, "body", "Body", Vector3.new(1.05, 1.35, 0.95), CFrame.new(0, 0.95, 0), stone, SLATE)
		E(rig, "body", "Brow", Vector3.new(0.9, 0.18, 0.3), CFrame.new(0, 1.4, -0.38), dark, SLATE)
		for _, side in ipairs({ -1, 1 }) do
			E(rig, "body", "Socket", Vector3.new(0.28, 0.3, 0.1), CFrame.new(side * 0.22, 1.2, -0.45), dark, SLATE)
			E(
				rig,
				"body",
				"Glint",
				Vector3.new(0.1, 0.12, 0.06),
				CFrame.new(side * 0.22, 1.2, -0.5),
				rgb(255, 230, 160),
				NEON
			)
			local arm = side < 0 and "armL" or "armR"
			E(
				rig,
				arm,
				"Arm",
				Vector3.new(0.24, 0.55, 0.24),
				CFrame.new(side * 0.52, 0.95, -0.2) * deg(-40, 0, side * 20),
				stone,
				SLATE
			)
			B(rig, arm, "Hand", 0.24, CFrame.new(side * 0.42, 1.12, -0.42), stone)
			E(
				rig,
				side < 0 and "legA" or "legB",
				"Foot",
				Vector3.new(0.34, 0.24, 0.48),
				CFrame.new(side * 0.24, 0.12, -0.05),
				stone,
				SLATE
			)
		end
		K(rig, "body", "Crack", Vector3.new(0.04, 0.5, 0.04), CFrame.new(0.15, 0.7, -0.47) * deg(0, 0, 18), dark)
		E(rig, "body", "Moss", Vector3.new(0.5, 0.15, 0.4), CFrame.new(-0.2, 1.62, 0), rgb(110, 170, 80))
		rig.hat = CFrame.new(0, 1.62, 0)
	end

	-- Waddles: a Frost Spire penguin in a knitted scarf; slides on its belly to keep up.
	BUILD.Waddles = function(rig, look)
		local black, white, orange = rgb(36, 40, 52), rgb(246, 246, 250), rgb(255, 150, 40)
		local scarf = look.scarf or rgb(214, 40, 54)
		rig.pivots.legA = Vector3.new(0, 0.2, 0)
		rig.pivots.legB = Vector3.new(0, 0.2, 0)
		rig.pivots.armL = Vector3.new(-0.5, 1.0, 0)
		rig.pivots.armR = Vector3.new(0.5, 1.0, 0)
		E(rig, "body", "Body", Vector3.new(1.05, 1.5, 1.0), CFrame.new(0, 0.85, 0), black)
		E(rig, "body", "Belly", Vector3.new(0.8, 1.15, 0.5), CFrame.new(0, 0.8, -0.32), white)
		E(rig, "body", "Beak", Vector3.new(0.24, 0.16, 0.36), CFrame.new(0, 1.3, -0.56), orange)
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "body", "EyePatch", 0.26, CFrame.new(side * 0.2, 1.42, -0.42), white)
			B(rig, "body", "Eye", 0.11, CFrame.new(side * 0.2, 1.43, -0.53), BLACK)
			E(
				rig,
				side < 0 and "armL" or "armR",
				"Flipper",
				Vector3.new(0.16, 0.75, 0.36),
				CFrame.new(side * 0.56, 0.75, 0) * deg(0, 0, side * 15),
				black
			)
			E(
				rig,
				side < 0 and "legA" or "legB",
				"Foot",
				Vector3.new(0.3, 0.12, 0.42),
				CFrame.new(side * 0.22, 0.06, -0.18),
				orange
			)
		end
		Cy(rig, "body", "Scarf", Vector3.new(0.24, 0.96, 0.96), CFrame.new(0, 1.12, 0) * UPRIGHT, scarf)
		K(rig, "body", "ScarfEnd", Vector3.new(0.24, 0.6, 0.08), CFrame.new(0.28, 0.85, -0.45) * deg(0, 0, 10), scarf)
		rig.hat = CFrame.new(0, 1.62, 0)
	end

	-- Cinderling: a little lava sprite from Ember Isle: basalt body cracked with glowing orange, a crown of flames.
	BUILD.Cinderling = function(rig, look)
		local rock, lava = look.rock or rgb(52, 44, 46), look.lava or rgb(255, 120, 30)
		rig.pivots.legBack = Vector3.new(0, 0.2, 0)
		rig.pivots.flame = Vector3.new(0, 1.3, 0)
		E(rig, "body", "Body", Vector3.new(1.0, 1.0, 0.9), CFrame.new(0, 0.62, 0), rock, SLATE)
		for i, at in ipairs({ { -0.2, 0.6, -0.44, 30 }, { 0.25, 0.75, -0.42, -40 }, { 0.05, 0.38, -0.44, 80 } }) do
			K(
				rig,
				"body",
				"Crack" .. i,
				Vector3.new(0.05, 0.36, 0.04),
				CFrame.new(at[1], at[2], at[3]) * deg(0, 0, at[4]),
				lava,
				NEON
			)
		end
		eyes(rig, "body", 0.2, 0.78, -0.42, 0.24, rgb(200, 60, 10))
		for k, spec in ipairs({ { 0, 0.62, 0 }, { -0.25, 0.44, 0.05 }, { 0.25, 0.48, 0 } }) do
			E(
				rig,
				"flame",
				"Flame" .. k,
				Vector3.new(0.3, spec[2], 0.3),
				CFrame.new(spec[1], 1.2 + spec[2] / 2, spec[3]),
				k == 1 and rgb(255, 214, 80) or lava,
				NEON,
				0.1
			)
		end
		for _, side in ipairs({ -1, 1 }) do
			E(rig, "legBack", "Foot", Vector3.new(0.3, 0.18, 0.4), CFrame.new(side * 0.22, 0.1, 0), rock, SLATE)
		end
		rig.light = { part = "Flame1", color = lava, range = 8 }
		rig.hat = CFrame.new(0, 1.15, 0)
	end

	-- Bonefish: a skeleton fish from Skull Rock rattling through the air: a skull, a spine, ribs and a bony tail.
	BUILD.Bonefish = function(rig, look)
		local bone, glow = look.bone or rgb(236, 228, 206), look.glow or rgb(130, 255, 180)
		rig.pivots.tail = Vector3.new(0, 0, 0.9)
		E(rig, "body", "Skull", Vector3.new(0.7, 0.66, 0.75), CFrame.new(0, 0, -0.55), bone)
		E(rig, "body", "Jaw", Vector3.new(0.5, 0.18, 0.5), CFrame.new(0, -0.3, -0.6), bone)
		for _, side in ipairs({ -1, 1 }) do
			E(rig, "body", "Socket", Vector3.new(0.12, 0.2, 0.2), CFrame.new(side * 0.25, 0.08, -0.72), rgb(30, 30, 34))
			B(rig, "body", "Eye", 0.1, CFrame.new(side * 0.27, 0.08, -0.78), glow, NEON)
		end
		Cy(rig, "body", "Spine", Vector3.new(1.4, 0.1, 0.1), CFrame.new(0, 0, 0.3) * deg(0, 90, 0), bone)
		for i = 0, 3 do
			local z = -0.05 + i * 0.28
			local h = 0.62 - i * 0.1
			for _, side in ipairs({ -1, 1 }) do
				K(
					rig,
					"body",
					"Rib",
					Vector3.new(0.05, h, 0.06),
					CFrame.new(side * 0.12, 0, z) * deg(0, 0, side * 12),
					bone
				)
			end
		end
		W(rig, "tail", "TailUp", Vector3.new(0.05, 0.5, 0.4), CFrame.new(0, 0.2, 1.15) * deg(-30, 180, 0), bone)
		W(rig, "tail", "TailDown", Vector3.new(0.05, 0.5, 0.4), CFrame.new(0, -0.2, 1.15) * deg(210, 180, 0), bone)
		rig.hat = CFrame.new(0, 0.4, -0.55)
	end

	-- Clammy: a Coral Atoll clam that hops on its shell and clacks; there is a pearl inside.
	BUILD.Clammy = function(rig, look)
		local shell, inner = look.shell or rgb(255, 176, 196), rgb(255, 226, 232)
		rig.pivots.lid = Vector3.new(0, 0.55, 0.45)
		rig.pivots.legBack = Vector3.new(0, 0.2, 0)
		E(rig, "body", "Bottom", Vector3.new(1.3, 0.5, 1.1), CFrame.new(0, 0.38, 0), shell)
		E(rig, "body", "Inside", Vector3.new(1.1, 0.2, 0.9), CFrame.new(0, 0.58, 0), inner)
		B(rig, "body", "Pearl", 0.34, CFrame.new(0, 0.7, -0.05), rgb(250, 248, 255))
		E(rig, "lid", "Top", Vector3.new(1.3, 0.5, 1.1), CFrame.new(0, 0.82, 0.05), shell)
		for i = -1, 1 do
			E(
				rig,
				"lid",
				"Ridge",
				Vector3.new(0.16, 0.12, 1.0),
				CFrame.new(i * 0.36, 1.0, 0.05) * deg(0, i * 15, 0),
				shell:Lerp(rgb(200, 90, 120), 0.3)
			)
		end
		for _, side in ipairs({ -1, 1 }) do
			B(rig, "lid", "Eye", 0.22, CFrame.new(side * 0.25, 1.08, -0.38), WHITE)
			B(rig, "lid", "Pupil", 0.1, CFrame.new(side * 0.25, 1.1, -0.48), BLACK)
			E(rig, "legBack", "Foot", Vector3.new(0.26, 0.16, 0.36), CFrame.new(side * 0.3, 0.08, 0), inner)
		end
		rig.hat = CFrame.new(0, 1.1, 0.05)
		rig.hatGroup = "lid"
	end

	-- Twig: a mischievous Tangle Isle imp: big ears, a leaf hat, a wide grin and long grabby arms.
	BUILD.Twig = function(rig, look)
		local skin, leaf = look.skin or rgb(96, 190, 84), rgb(60, 140, 50)
		rig.pivots.legBack = Vector3.new(0, 0.3, 0)
		rig.pivots.armL = Vector3.new(-0.38, 0.85, 0)
		rig.pivots.armR = Vector3.new(0.38, 0.85, 0)
		rig.pivots.tail = Vector3.new(0, 0.5, 0.3)
		E(rig, "body", "Body", Vector3.new(0.75, 0.9, 0.7), CFrame.new(0, 0.65, 0), skin)
		B(rig, "head", "Head", 0.8, CFrame.new(0, 1.35, -0.05), skin)
		for _, side in ipairs({ -1, 1 }) do
			W(
				rig,
				"head",
				"Ear",
				Vector3.new(0.08, 0.36, 0.7),
				CFrame.new(side * 0.55, 1.42, 0.1) * deg(0, side * -30, side * -60),
				skin
			)
			B(rig, "head", "Eye", 0.2, CFrame.new(side * 0.17, 1.42, -0.38), rgb(255, 230, 90))
			B(rig, "head", "Pupil", 0.09, CFrame.new(side * 0.17, 1.42, -0.47), BLACK)
			local arm = side < 0 and "armL" or "armR"
			E(
				rig,
				arm,
				"Arm",
				Vector3.new(0.16, 0.8, 0.16),
				CFrame.new(side * 0.48, 0.5, -0.05) * deg(0, 0, side * 15),
				skin
			)
			B(rig, arm, "Hand", 0.2, CFrame.new(side * 0.56, 0.12, -0.08), skin)
			E(rig, "legBack", "Leg", Vector3.new(0.2, 0.4, 0.3), CFrame.new(side * 0.2, 0.2, 0), skin)
		end
		K(rig, "head", "Grin", Vector3.new(0.42, 0.06, 0.06), CFrame.new(0, 1.2, -0.4), rgb(40, 60, 30))
		E(rig, "head", "LeafHat", Vector3.new(0.9, 0.12, 0.6), CFrame.new(0, 1.76, -0.05) * deg(-10, 20, 8), leaf)
		Cy(rig, "head", "LeafStem", Vector3.new(0.3, 0.05, 0.05), CFrame.new(0.05, 1.9, 0.2) * deg(0, 0, 80), leaf)
		Cy(
			rig,
			"tail",
			"Tail",
			Vector3.new(0.7, 0.08, 0.08),
			CFrame.new(0, 0.5, 0.55) * deg(0, 90, 0) * deg(0, 0, 35),
			skin
		)
		rig.hat = CFrame.new(0, 1.8, -0.05)
		rig.hatGroup = "head"
	end

	-- PREMIUM (cosmetic only: no ability) ----------------------------------------------------------------------------------

	-- The Gilded Whelp: a tiny golden sea dragon with ruby eyes, horns, scalloped wings and a spaded tail.
	BUILD.Whelp = function(rig, look)
		local gold, wing, ruby = look.gold or rgb(255, 200, 60), look.wing or rgb(255, 150, 60), rgb(220, 30, 60)
		rig.pivots.wingL = Vector3.new(-0.3, 0.2, 0)
		rig.pivots.wingR = Vector3.new(0.3, 0.2, 0)
		rig.pivots.tail1 = Vector3.new(0, -0.05, 0.5)
		rig.pivots.tail2 = Vector3.new(0, -0.1, 0.95)
		rig.pivots.head = Vector3.new(0, 0.35, -0.4)
		E(rig, "body", "Body", Vector3.new(0.75, 0.75, 1.15), CFrame.new(0, 0, 0), gold, FOIL)
		E(rig, "body", "Belly", Vector3.new(0.55, 0.4, 0.95), CFrame.new(0, -0.18, -0.05), rgb(255, 236, 170), SMOOTH)
		E(rig, "head", "Head", Vector3.new(0.6, 0.55, 0.7), CFrame.new(0, 0.42, -0.62), gold, FOIL)
		E(rig, "head", "Snout", Vector3.new(0.4, 0.3, 0.42), CFrame.new(0, 0.34, -1.0), gold, FOIL)
		for _, side in ipairs({ -1, 1 }) do
			E(rig, "head", "Eye", Vector3.new(0.14, 0.16, 0.1), CFrame.new(side * 0.2, 0.52, -0.92), ruby, GLASS)
			W(
				rig,
				"head",
				"Horn",
				Vector3.new(0.07, 0.36, 0.28),
				CFrame.new(side * 0.17, 0.78, -0.5) * deg(-35, 0, side * -12),
				rgb(255, 246, 220)
			)
			local group = side < 0 and "wingL" or "wingR"
			W(
				rig,
				group,
				"Wing",
				Vector3.new(0.06, 0.8, 1.1),
				CFrame.new(side * 0.85, 0.35, 0.05) * deg(0, 90, side * 80),
				wing
			)
			Cy(rig, group, "WingBone", Vector3.new(1.2, 0.07, 0.07), CFrame.new(side * 0.85, 0.55, -0.15), gold, METAL)
		end
		E(rig, "tail1", "Tail", Vector3.new(0.3, 0.3, 0.7), CFrame.new(0, -0.05, 0.75), gold, FOIL)
		E(rig, "tail2", "TailTip", Vector3.new(0.2, 0.2, 0.5), CFrame.new(0, -0.1, 1.2), gold, FOIL)
		W(rig, "tail2", "Spade", Vector3.new(0.06, 0.32, 0.3), CFrame.new(0, -0.1, 1.5) * deg(0, 180, 0), ruby)
		rig.hat = CFrame.new(0, 0.75, -0.62)
		rig.hatGroup = "head"
	end

	return BUILD
end
