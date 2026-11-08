-- Moonlit Falls: main server logic.
-- Sides, day/night + full moon, blood hunger, sunlight, and every ability.
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local NPCs = require(script.Parent:WaitForChild("NPCs"))

---------------------------------------------------------------- remotes
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Remotes
	return r
end
local AbilityRemote = remote("Ability")
local ChooseSideRemote = remote("ChooseSide")
local NotifyRemote = remote("Notify")
Remotes.Parent = ReplicatedStorage

---------------------------------------------------------------- teams
local TEAM_SETUP = {
	Human = { "Humans", BrickColor.new("Bright yellow") },
	Vampire = { "Vampires", BrickColor.new("Crimson") },
	Werewolf = { "Werewolves", BrickColor.new("Brown") },
}
local teams = {}
for side, info in TEAM_SETUP do
	local t = Instance.new("Team")
	t.Name = info[1]
	t.TeamColor = info[2]
	t.AutoAssignable = false
	t.Parent = Teams
	teams[side] = t
end

---------------------------------------------------------------- helpers
local RED = Color3.fromRGB(255, 80, 90)
local GREEN = Color3.fromRGB(140, 255, 150)
local PURPLE = Color3.fromRGB(200, 150, 255)
local GOLD = Color3.fromRGB(255, 215, 110)

local function now()
	return workspace:GetServerTimeNow()
end

local function notify(plr: Player?, text: string, color: Color3?)
	if plr then
		NotifyRemote:FireClient(plr, text, color)
	end
end

local function notifyAll(text: string, color: Color3?)
	NotifyRemote:FireAllClients(text, color)
end

local function getSide(plr: Player): string
	return plr:GetAttribute("Side") or "Human"
end

-- Side of any character model (player or townsfolk).
local function sideOf(model: Model): string?
	local p = Players:GetPlayerFromCharacter(model)
	if p then
		return getSide(p)
	end
	if model:GetAttribute("NPC") then
		return "Human"
	end
	return nil
end

local function isTransformed(model: Model)
	return model:GetAttribute("Transformed") == true
end

local function baseSpeed(model: Model): number
	local p = Players:GetPlayerFromCharacter(model)
	if not p then
		return 10
	end
	if isTransformed(model) then
		return Config.WolfForm.WalkSpeed
	end
	return Config.SideStats[getSide(p)].WalkSpeed
end

-- Vervain lives on the player for players, on the model for townsfolk.
local function vervainOwner(model: Model): Instance
	return Players:GetPlayerFromCharacter(model) or model
end
local function vervainCount(model: Model): number
	return vervainOwner(model):GetAttribute("Vervain") or 0
end
local function useVervain(model: Model)
	local owner = vervainOwner(model)
	owner:SetAttribute("Vervain", math.max(0, vervainCount(model) - 1))
end

local function addPoints(plr: Player?, amount: number)
	if not plr then
		return
	end
	local stats = plr:FindFirstChild("leaderstats")
	local pts = stats and stats:FindFirstChild("Points")
	if pts then
		pts.Value += amount
	end
end

local function burst(model: Model, color: Color3)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.Size = NumberSequence.new(0.5, 0)
	pe.Speed = NumberRange.new(8, 14)
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 0
	pe.LightEmission = 0.5
	pe.Parent = root
	pe:Emit(25)
	Debris:AddItem(pe, 1.5)
end

local function damage(attacker: Player?, target: Model, amount: number)
	local hum = target:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	if attacker then
		target:SetAttribute("LastAttacker", attacker.UserId)
	end
	hum:TakeDamage(amount)
end

local function stun(model: Model, seconds: number)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local untilT = now() + seconds
	model:SetAttribute("StunnedUntil", untilT)
	hum.WalkSpeed = 0
	hum.JumpHeight = 0
	if model:GetAttribute("NPC") then
		hum:MoveTo(model:GetPivot().Position)
	end
	task.delay(seconds, function()
		if model.Parent and (model:GetAttribute("StunnedUntil") or 0) <= now() + 0.05 then
			hum.WalkSpeed = baseSpeed(model)
			hum.JumpHeight = 7.2
		end
	end)
end

local function allCharacters(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	for _, m in NPCs.Folder:GetChildren() do
		table.insert(list, m)
	end
	return list
end

local function nearest(from: Model, range: number, filter: (Model) -> boolean): Model?
	local root = from:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestDist = nil, range
	for _, m in allCharacters() do
		if m ~= from then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local r = m:FindFirstChild("HumanoidRootPart")
			if hum and r and hum.Health > 0 and filter(m) then
				local d = (r.Position - root.Position).Magnitude
				if d <= bestDist then
					best, bestDist = m, d
				end
			end
		end
	end
	return best
end

local function isSide(...)
	local wanted = { ... }
	return function(m: Model)
		return table.find(wanted, sideOf(m)) ~= nil
	end
end

---------------------------------------------------------------- werewolf form
local function transform(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or isTransformed(char) then
		return
	end
	char:SetAttribute("Transformed", true)
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p:SetAttribute("OrigColor", p.Color)
			p.Color = Color3.fromRGB(70, 50, 35)
		end
	end
	hum.MaxHealth = Config.WolfForm.MaxHealth
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = Config.WolfForm.WalkSpeed

	local head = char:FindFirstChild("Head")
	if head then
		local bb = Instance.new("BillboardGui")
		bb.Name = "WolfTag"
		bb.Size = UDim2.fromOffset(60, 60)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "🐺"
		t.TextScaled = true
		t.Parent = bb
		bb.Parent = head
	end
	burst(char, Color3.fromRGB(255, 200, 80))
	notify(Players:GetPlayerFromCharacter(char), "🌕 พระจันทร์เต็มดวง... คุณกลายร่างเป็นหมาป่า!", GOLD)
end

local function untransform(char: Model)
	if not isTransformed(char) then
		return
	end
	char:SetAttribute("Transformed", false)
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("OrigColor") then
			p.Color = p:GetAttribute("OrigColor")
		end
	end
	local tag = char:FindFirstChild("WolfTag", true)
	if tag then
		tag:Destroy()
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = Config.SideStats.Werewolf.MaxHealth
		hum.Health = math.min(hum.Health, hum.MaxHealth)
		hum.WalkSpeed = Config.SideStats.Werewolf.WalkSpeed
	end
	notify(Players:GetPlayerFromCharacter(char), "☀️ รุ่งเช้าแล้ว คุณกลับเป็นคนตามเดิม", GOLD)
end

---------------------------------------------------------------- abilities
local cooldowns: { [Player]: { [string]: number } } = {}

local function useCooldown(plr: Player, ability: string): boolean
	local cd = Config.Cooldowns[ability]
	if not cd then
		return false
	end
	cooldowns[plr] = cooldowns[plr] or {}
	local last = cooldowns[plr][ability] or 0
	if now() - last < cd then
		return false
	end
	cooldowns[plr][ability] = now()
	return true
end

local Abilities = {}

Abilities.Vampire = {
	Bite = function(plr: Player, char: Model)
		local target = nearest(char, 7, isSide("Human"))
		if not target then
			notify(plr, "ไม่มีเหยื่ออยู่ใกล้ๆ 🩸")
			return
		end
		local victim = Players:GetPlayerFromCharacter(target)
		if vervainCount(target) > 0 then
			useVervain(target)
			damage(nil, char, 20)
			stun(char, 2.5)
			burst(char, Color3.fromRGB(170, 90, 230))
			notify(plr, "🌿 เลือดมีเวอร์เวน! แสบคอไปหมด", RED)
			notify(victim, "🌿 เวอร์เวนในเลือดปกป้องคุณจากการโดนกัด!", PURPLE)
			return
		end
		damage(plr, target, 25)
		burst(target, Color3.fromRGB(160, 0, 20))
		plr:SetAttribute("Blood", math.min(Config.BLOOD_MAX, (plr:GetAttribute("Blood") or 0) + 35))
		target:SetAttribute("BittenAt", now())
		addPoints(plr, 2)
		notify(plr, "🩸 อร่อย... เลือด +35", RED)
		notify(victim, "🧛 คุณโดนแวมไพร์กัด! ถ้าตายใน " .. Config.TRANSITION_WINDOW .. " วิ จะกลายเป็นแวมไพร์", RED)
	end,

	Compel = function(plr: Player, char: Model)
		local target = nearest(char, 18, function(m)
			return sideOf(m) ~= "Vampire" and not isTransformed(m)
		end)
		if not target then
			notify(plr, "ไม่มีใครให้สะกดจิตแถวนี้ 👁")
			return
		end
		local victim = Players:GetPlayerFromCharacter(target)
		if vervainCount(target) > 0 then
			notify(plr, "👁 สะกดจิตไม่ได้... คนนี้กินเวอร์เวนไว้", PURPLE)
			notify(victim, "🌿 มีคนพยายามสะกดจิตคุณ แต่เวอร์เวนกันไว้ได้", PURPLE)
			return
		end
		stun(target, 4)
		burst(target, Color3.fromRGB(255, 255, 255))
		notify(plr, "👁 \"อยู่นิ่งๆ แล้วลืมทุกอย่างซะ\"", RED)
		notify(victim, "😵 คุณถูกสะกดจิต... ขยับไม่ได้!", RED)
	end,
}

Abilities.Human = {
	Stake = function(plr: Player, char: Model)
		local target = nearest(char, 6, isSide("Vampire"))
		if not target then
			notify(plr, "ต้องเข้าใกล้แวมไพร์ก่อนถึงจะปักหลักได้ 🪵")
			return
		end
		damage(plr, target, 35)
		burst(target, Color3.fromRGB(120, 80, 40))
		addPoints(plr, 2)
		notify(plr, "🪵 ปักหลักเข้าเต็มๆ!", GREEN)
		notify(Players:GetPlayerFromCharacter(target), "🪵 โดนหลักไม้ปักอก!", RED)
	end,

	Vervain = function(plr: Player, char: Model)
		if (plr:GetAttribute("Vervain") or 0) <= 0 then
			notify(plr, "ไม่มีเวอร์เวน ไปเก็บที่ทุ่งทางตะวันออกก่อน 🌿")
			return
		end
		local target = nearest(char, 14, isSide("Vampire"))
		if not target then
			notify(plr, "ไม่มีแวมไพร์ในระยะ")
			return
		end
		useVervain(char)
		damage(plr, target, 15)
		stun(target, 3)
		burst(target, Color3.fromRGB(170, 90, 230))
		addPoints(plr, 1)
		notify(plr, "🌿 สาดเวอร์เวนโดน! แวมไพร์ชะงัก", GREEN)
		notify(Players:GetPlayerFromCharacter(target), "🌿 โดนสาดเวอร์เวน! แสบผิวไปหมด", RED)
	end,
}

Abilities.Werewolf = {
	Claw = function(plr: Player, char: Model)
		local target = nearest(char, 7, function(m)
			return sideOf(m) ~= "Werewolf"
		end)
		if not target then
			return
		end
		local wolf = isTransformed(char)
		local targetIsVamp = sideOf(target) == "Vampire"
		local amount = wolf and (targetIsVamp and 45 or 30) or 12
		damage(plr, target, amount)
		burst(target, Color3.fromRGB(200, 30, 30))
		addPoints(plr, 1)
		if wolf and targetIsVamp then
			-- Werewolf venom: slowly kills a vampire.
			target:SetAttribute("VenomUntil", now() + 10)
			notify(plr, "🐺 กัดเข้าไปแล้ว! พิษหมาป่ากำลังทำงาน", GOLD)
			notify(Players:GetPlayerFromCharacter(target), "☠️ โดนหมาป่ากัด! พิษกำลังกินร่าง...", RED)
		end
	end,
}

AbilityRemote.OnServerEvent:Connect(function(plr: Player, ability)
	if typeof(ability) ~= "string" then
		return
	end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	if (char:GetAttribute("StunnedUntil") or 0) > now() then
		return
	end
	local list = Abilities[getSide(plr)]
	local handler = list and list[ability]
	if handler and useCooldown(plr, ability) then
		handler(plr, char)
	end
end)

---------------------------------------------------------------- choosing a side
local lastSwitch: { [Player]: number } = {}

local function setSide(plr: Player, side: string)
	plr:SetAttribute("Side", side)
	plr.Team = teams[side]
end

ChooseSideRemote.OnServerEvent:Connect(function(plr: Player, side)
	if typeof(side) ~= "string" or not Config.SideStats[side] then
		return
	end
	if lastSwitch[plr] and now() - lastSwitch[plr] < 10 then
		notify(plr, "รอสักครู่ก่อนเปลี่ยนฝั่งอีกครั้ง")
		return
	end
	lastSwitch[plr] = now()
	setSide(plr, side)
	plr:LoadCharacter()
end)

---------------------------------------------------------------- map
local map = MapBuilder.Build()

for _, prompt in map.vervainPrompts do
	local plant = prompt.Parent
	prompt.Triggered:Connect(function(plr: Player)
		local char = plr.Character
		if not char then
			return
		end
		if getSide(plr) == "Vampire" then
			damage(nil, char, 10)
			burst(char, Color3.fromRGB(170, 90, 230))
			notify(plr, "🔥 แวมไพร์จับเวอร์เวนไม่ได้! มือไหม้", RED)
			return
		end
		local count = plr:GetAttribute("Vervain") or 0
		if count >= Config.MAX_VERVAIN then
			notify(plr, "พกเวอร์เวนเต็มแล้ว (" .. Config.MAX_VERVAIN .. ")")
			return
		end
		plr:SetAttribute("Vervain", count + 1)
		notify(plr, "🌿 ได้เวอร์เวน +1 (กันโดนกัด/สะกดจิต และใช้สาดแวมไพร์ได้)", PURPLE)
		prompt.Enabled = false
		plant.Transparency = 1
		task.delay(40, function()
			prompt.Enabled = true
			plant.Transparency = 0
		end)
	end)
end

map.ringPrompt.Triggered:Connect(function(plr: Player)
	local char = plr.Character
	if not char then
		return
	end
	if getSide(plr) ~= "Vampire" then
		notify(plr, "💍 แหวนวงนี้มีไว้ให้แวมไพร์เท่านั้น")
		return
	end
	if char:GetAttribute("HasRing") then
		notify(plr, "คุณสวมแหวนอยู่แล้ว")
		return
	end
	char:SetAttribute("HasRing", true)
	burst(char, Color3.fromRGB(90, 150, 255))
	notify(plr, "💍 แม่มดร่ายมนต์ใส่แหวน... เดินกลางแดดได้แล้ว! (หายเมื่อตาย)", Color3.fromRGB(120, 170, 255))
end)

-- Points for finishing off townsfolk.
NPCs.Folder.ChildAdded:Connect(function(model)
	local hum = model:WaitForChild("Humanoid", 5)
	if hum then
		hum.Died:Connect(function()
			local id = model:GetAttribute("LastAttacker")
			addPoints(id and Players:GetPlayerByUserId(id), 3)
		end)
	end
end)

NPCs.Start(map.wanderPoints)

---------------------------------------------------------------- players
local function isDay()
	return ReplicatedStorage:GetAttribute("IsDay") == true
end
local function isFullMoonNight()
	return not isDay() and ReplicatedStorage:GetAttribute("FullMoon") == true
end

local function onCharacter(plr: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local side = getSide(plr)
	local stats = Config.SideStats[side]
	hum.MaxHealth = stats.MaxHealth
	hum.Health = stats.MaxHealth
	hum.WalkSpeed = stats.WalkSpeed
	plr:SetAttribute("Blood", Config.BLOOD_START)

	if side == "Werewolf" and isFullMoonNight() then
		task.delay(1, transform, char)
	end

	hum.Died:Connect(function()
		local id = char:GetAttribute("LastAttacker")
		local killer = id and Players:GetPlayerByUserId(id)
		addPoints(killer, 10)
		if killer and killer ~= plr then
			notify(killer, "💀 คุณจัดการ " .. plr.DisplayName .. " ได้!", GOLD)
		end
		-- Transition: died with a fresh bite = wake up a vampire.
		local bitten = char:GetAttribute("BittenAt")
		if getSide(plr) == "Human" and bitten and now() - bitten < Config.TRANSITION_WINDOW then
			setSide(plr, "Vampire")
			notify(plr, "🧛 คุณตื่นขึ้นมา... หิวเลือด. ยินดีต้อนรับสู่ชีวิตแวมไพร์", RED)
			notifyAll("🦇 " .. plr.DisplayName .. " กลายเป็นแวมไพร์แล้ว!", RED)
		end
	end)
end

local function onPlayer(plr: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local pts = Instance.new("IntValue")
	pts.Name = "Points"
	pts.Parent = stats
	stats.Parent = plr

	setSide(plr, "Human")
	plr:SetAttribute("Vervain", 0)
	plr.CharacterAdded:Connect(function(char)
		onCharacter(plr, char)
	end)
	if plr.Character then
		onCharacter(plr, plr.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, plr in Players:GetPlayers() do
	task.spawn(onPlayer, plr)
end

Players.PlayerRemoving:Connect(function(plr)
	cooldowns[plr] = nil
	lastSwitch[plr] = nil
end)

---------------------------------------------------------------- sunlight, hunger, venom (every second)
local sunParams = RaycastParams.new()
sunParams.FilterType = Enum.RaycastFilterType.Exclude

local function inSunlight(char: Model): boolean
	local head = char:FindFirstChild("Head")
	if not head then
		return false
	end
	sunParams.FilterDescendantsInstances = { char, NPCs.Folder }
	return workspace:Raycast(head.Position, Vector3.new(0, 400, 0), sunParams) == nil
end

local lastWarn: { [Player]: number } = {}
local function warnOnce(plr: Player, text: string)
	if not lastWarn[plr] or now() - lastWarn[plr] > 4 then
		lastWarn[plr] = now()
		notify(plr, text, RED)
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, plr in Players:GetPlayers() do
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				if getSide(plr) == "Vampire" then
					local blood = math.max(0, (plr:GetAttribute("Blood") or 0) - Config.BLOOD_DRAIN)
					plr:SetAttribute("Blood", blood)
					if blood <= 0 then
						hum:TakeDamage(4)
						warnOnce(plr, "🩸 หิวเลือดจนร่างกายเริ่มแห้ง! ไปกัดใครสักคนเร็ว")
					elseif blood > 50 then
						hum.Health = math.min(hum.MaxHealth, hum.Health + 3) -- vampire healing
					end

					if isDay() and not char:GetAttribute("HasRing") and inSunlight(char) then
						hum:TakeDamage(Config.SUN_DAMAGE)
						local root = char:FindFirstChild("HumanoidRootPart")
						if root and not root:FindFirstChild("SunFire") then
							local fire = Instance.new("Fire")
							fire.Name = "SunFire"
							fire.Heat = 12
							fire.Size = 6
							fire.Parent = root
							Debris:AddItem(fire, 1.2)
						end
						warnOnce(plr, "🔥 แดดเผา! หลบเข้าร่มหรือในตึก หรือไปหาแหวนที่ซากปรักหักพังของแม่มด")
					end
				end
				if (char:GetAttribute("VenomUntil") or 0) > now() then
					hum:TakeDamage(5)
				end
			end
		end
	end
end)

---------------------------------------------------------------- day / night
local sky = Lighting:FindFirstChild("MoonSky") :: Sky
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
local nightCount = 0

ReplicatedStorage:SetAttribute("IsDay", true)
ReplicatedStorage:SetAttribute("FullMoon", false)
ReplicatedStorage:SetAttribute("Night", 0)

local function onNightfall()
	nightCount += 1
	local full = (nightCount - 1) % Config.FULL_MOON_EVERY == 0
	ReplicatedStorage:SetAttribute("Night", nightCount)
	ReplicatedStorage:SetAttribute("FullMoon", full)
	if sky then
		sky.MoonAngularSize = full and 32 or 11
	end
	if atmo then
		atmo.Color = full and Color3.fromRGB(150, 150, 190) or Color3.fromRGB(120, 120, 150)
	end
	if full then
		notifyAll("🌕 คืนพระจันทร์เต็มดวง! มนุษย์หมาป่ากำลังกลายร่าง... ระวังตัวด้วย", GOLD)
		for _, plr in Players:GetPlayers() do
			if getSide(plr) == "Werewolf" and plr.Character then
				transform(plr.Character)
			end
		end
	else
		notifyAll("🌙 ค่ำแล้ว... แวมไพร์ออกล่าได้อย่างอิสระ", PURPLE)
	end
end

local function onDawn()
	notifyAll("☀️ รุ่งเช้า! แวมไพร์ที่ไม่มีแหวนต้องหลบแดด", GOLD)
	if atmo then
		atmo.Color = Color3.fromRGB(170, 175, 200)
	end
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			untransform(plr.Character)
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local t = (Lighting.ClockTime + dt * 24 / Config.DAY_CYCLE_SECONDS) % 24
	Lighting.ClockTime = t
	local dayNow = t >= 6 and t < 18
	if dayNow ~= isDay() then
		ReplicatedStorage:SetAttribute("IsDay", dayNow)
		if dayNow then
			onDawn()
		else
			onNightfall()
		end
	end
end)
