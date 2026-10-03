local Config = {}

Config.NORMAL_WALK_SPEED = 16
Config.CARRY_WALK_SPEED = 12
Config.PICKUP_DISTANCE = 10
Config.GRAPPLE_RANGE = 70
Config.GRAPPLE_COOLDOWN = 2.75
Config.BANK_RADIUS = 13
Config.ROUND_RESET_DELAY = 4

Config.HOME_CENTER = Vector3.new(0, 8, 0)
Config.TREASURE_CENTER = Vector3.new(0, 8, -300)
Config.BOAT_START = CFrame.new(0, 8.5, -55) * CFrame.Angles(0, math.rad(180), 0)
Config.IDOL_SPAWN = CFrame.new(0, 17, -300)
Config.GUARDIAN_SPAWN = CFrame.new(0, 12, -328)

Config.BOAT_SPEED = 58
Config.BOAT_TURN_RATE = math.rad(78)

Config.GUARDIAN_DAMAGE = 12
Config.GUARDIAN_HIT_RANGE = 7
Config.GUARDIAN_HIT_COOLDOWN = 1.1
Config.GUARDIAN_WALK_SPEED = 21

Config.SWORD_PEDESTAL = CFrame.new(12, 15, 14)
Config.SWORD_DAMAGE = 20
Config.SWORD_RANGE = 8
Config.SWORD_MIN_DOT = 0.3
Config.SWORD_COOLDOWN = 0.6
Config.SWORD_KNOCKBACK = 30

return Config
