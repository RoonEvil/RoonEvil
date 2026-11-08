-- Townsfolk who wander the square, chat, wave at people, and run from vampires at night.
-- Vampires feed on them; some secretly carry vervain.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Models = require(script.Parent:WaitForChild("Models"))

local NPCs = {}

NPCs.Folder = Instance.new("Folder")
NPCs.Folder.Name = "Townsfolk"
NPCs.Folder.Parent = workspace

local COUNT = 12
local RESPAWN_SECONDS = 15
local VERVAIN_CHANCE = 0.25
local FLEE_RANGE = 24

local NAMES = {
	"Mrs. Hollis", "Pastor Wren", "Coach Barrow", "Nora the Barista", "Old Man Fitch",
	"Deputy Lane", "Ivy Marsh", "Tobias Crane", "Lucy Pell", "Dr. Ashford",
	"Mayor Quill", "Gwen Harlow", "Felix Rowe", "Martha Bell",
}
local SKINS = {
	Color3.fromRGB(255, 220, 190), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 134, 94),
	Color3.fromRGB(141, 85, 54), Color3.fromRGB(96, 60, 40),
}
local SHIRTS = {
	Color3.fromRGB(120, 30, 40), Color3.fromRGB(40, 60, 110), Color3.fromRGB(60, 90, 60),
	Color3.fromRGB(200, 190, 170), Color3.fromRGB(30, 30, 35), Color3.fromRGB(110, 80, 140),
}
local PANTS = { Color3.fromRGB(35, 40, 60), Color3.fromRGB(60, 50, 40), Color3.fromRGB(25, 25, 25) }

local LINES_DAY = {
	"อากาศดีนะวันนี้ ☀️",
	"เบอร์เกอร์ร้าน Grill อร่อยสุดในเมือง",
	"ได้ข่าวว่ามีสัตว์ป่ากัดคนในป่าอีกแล้ว...",
	"ทำไมคนเมืองนี้ชอบใส่แหวนกันจัง?",
	"หอนาฬิกาเดินเร็วไปห้านาทีมาสิบปีแล้ว",
	"อย่าเข้าป่าตอนกลางคืนนะ เตือนแล้ว",
	"บ้าน Ravencroft มีคนย้ายมาใหม่อีกแล้วเหรอ",
	"เมื่อคืนฝันว่ามีคนบอกให้ลืม... ลืมอะไรนะ",
}
local LINES_VERVAIN = {
	"ชาเวอร์เวนแก้วนี้หอมดีจริง 🌿",
	"ยายบอกให้ใส่เวอร์เวนในกาแฟทุกเช้า",
}
local LINES_NIGHT = {
	"หมอกลงหนาจัง กลับบ้านดีกว่า",
	"ได้ยินเสียงหอนไหม...?",
	"รู้สึกเหมือนมีคนจ้องอยู่เลย",
	"คืนนี้ค้างคาวเยอะผิดปกตินะ 🦇",
}
local LINES_FLEE = { "ช่วยด้วย!!", "อย่าเข้ามานะ!", "ตาแดงๆ นั่นอะไรน่ะ!", "มะ-มะ-แวมไพร์!!" }
local LINES_GREET = { "สวัสดีจ้ะ 👋", "หวัดดี! มาเที่ยวเหรอ", "ยินดีต้อนรับสู่ Moonlit Falls" }

local rng = Random.new()
local wanderPoints: { Vector3 } = {}
local animRemote: RemoteEvent? = nil

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function isNight()
	return ReplicatedStorage:GetAttribute("IsDay") == false
end

local function isStunned(model: Model)
	return (model:GetAttribute("StunnedUntil") or 0) > workspace:GetServerTimeNow()
end

local function playAnim(model: Model, name: string)
	if animRemote then
		animRemote:FireAllClients(model, name)
	end
end

function NPCs.Say(model: Model, text: string, color: Color3?)
	Models.Say(model, text, color)
end

-- Nearest player within range, and whether that player is a vampire.
local function nearestPlayer(root: BasePart, range: number): (Model?, boolean)
	local best, bestD, vamp = nil, range, false
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if r and hum and hum.Health > 0 then
			local d = (r.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD = char, d
				vamp = p:GetAttribute("Side") == "Vampire" or char:GetAttribute("Transformed") == true
			end
		end
	end
	return best, vamp
end

local function makeNPC(): Model?
	local desc = Instance.new("HumanoidDescription")
	local skin = pick(SKINS)
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = pick(SHIRTS)
	local pants = pick(PANTS)
	desc.LeftLegColor = pants
	desc.RightLegColor = pants

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Townsfolk] could not create NPC:", model)
		return nil
	end

	local name = pick(NAMES)
	model.Name = name
	model:SetAttribute("NPC", true)
	local hasVervain = rng:NextNumber() < VERVAIN_CHANCE
	if hasVervain then
		model:SetAttribute("Vervain", 1)
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = name
	hum.WalkSpeed = 10
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer

	model:PivotTo(CFrame.new(pick(wanderPoints) + Vector3.new(0, 4, 0)))
	model.Parent = NPCs.Folder
	Models.DressTownsfolk(model)

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	if root then
		root:SetNetworkOwner(nil)
	end

	-- Brain: wander, chat, greet, flee.
	task.spawn(function()
		local nextMove, nextChat, lastGreet = 0, os.clock() + rng:NextNumber(3, 12), 0
		while model.Parent and hum.Health > 0 do
			task.wait(0.5)
			if isStunned(model) or not root then
				continue
			end
			local t = os.clock()
			local near, threat = nearestPlayer(root, FLEE_RANGE)
			if near and threat and isNight() then
				-- Run away from the vampire / werewolf.
				local away = root.Position - near:GetPivot().Position
				away = Vector3.new(away.X, 0, away.Z)
				if away.Magnitude < 0.1 then
					away = Vector3.new(1, 0, 0)
				end
				hum.WalkSpeed = 17
				hum:MoveTo(root.Position + away.Unit * 30)
				nextMove = t + 1.5
				if t > nextChat then
					NPCs.Say(model, pick(LINES_FLEE), Color3.fromRGB(170, 20, 30))
					playAnim(model, "Scream")
					nextChat = t + 4
				end
				continue
			end
			hum.WalkSpeed = 10
			if near and t - lastGreet > 25 and (near:GetPivot().Position - root.Position).Magnitude < 10 then
				lastGreet = t
				hum:MoveTo(root.Position)
				root.CFrame = CFrame.lookAt(root.Position, Vector3.new(near:GetPivot().Position.X, root.Position.Y, near:GetPivot().Position.Z))
				NPCs.Say(model, pick(LINES_GREET))
				playAnim(model, "Wave")
				nextMove = t + 3
				nextChat = t + 8
				continue
			end
			if t > nextChat then
				local lines = isNight() and LINES_NIGHT or LINES_DAY
				if hasVervain and rng:NextNumber() < 0.4 then
					lines = LINES_VERVAIN
				end
				NPCs.Say(model, pick(lines))
				nextChat = t + rng:NextNumber(10, 22)
			end
			if t > nextMove then
				hum:MoveTo(pick(wanderPoints))
				nextMove = t + rng:NextNumber(4, 9)
			end
		end
	end)

	hum.Died:Connect(function()
		task.delay(RESPAWN_SECONDS, function()
			model:Destroy()
			makeNPC()
		end)
	end)

	return model
end

function NPCs.Start(points: { Vector3 }, remote: RemoteEvent?)
	wanderPoints = points
	animRemote = remote
	for _ = 1, COUNT do
		makeNPC()
	end
end

return NPCs
