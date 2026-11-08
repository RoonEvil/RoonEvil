-- Game settings shared by server and client.
local Config = {}

Config.GAME_NAME = "Moonlit Falls"

-- One full day (24 in-game hours) in real seconds.
Config.DAY_CYCLE_SECONDS = 300
-- Night 1, 4, 7, ... is a full moon.
Config.FULL_MOON_EVERY = 3

Config.BLOOD_MAX = 100
Config.BLOOD_START = 60
Config.BLOOD_DRAIN = 1 -- per second
Config.SUN_DAMAGE = 10 -- per second, vampire without a ring in direct sun
Config.MAX_VERVAIN = 5
Config.TRANSITION_WINDOW = 30 -- die within this many seconds of a bite = wake up as a vampire

Config.Cooldowns = {
	Bite = 2,
	Compel = 12,
	Dash = 5,
	Stake = 4,
	Vervain = 3,
	Claw = 1.5,
}

Config.SideStats = {
	Human = { WalkSpeed = 16, MaxHealth = 100 },
	Vampire = { WalkSpeed = 22, MaxHealth = 150 },
	Werewolf = { WalkSpeed = 18, MaxHealth = 130 },
}
Config.WolfForm = { WalkSpeed = 28, MaxHealth = 240 }

Config.SideInfo = {
	Human = {
		title = "🧍 มนุษย์",
		color = Color3.fromRGB(240, 200, 90),
		desc = "เก็บเวอร์เวนไว้กันโดนกัด ปักหลักไม้ใส่แวมไพร์",
	},
	Vampire = {
		title = "🧛 แวมไพร์",
		color = Color3.fromRGB(200, 30, 50),
		desc = "เร็ว แรง ต้องดื่มเลือด โดนแดดไหม้ถ้าไม่มีแหวน",
	},
	Werewolf = {
		title = "🐺 มนุษย์หมาป่า",
		color = Color3.fromRGB(150, 100, 60),
		desc = "คืนพระจันทร์เต็มดวงกลายร่าง กัดแวมไพร์ทีเดียวพิษเข้า",
	},
}

return Config
