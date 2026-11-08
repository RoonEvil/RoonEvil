-- Townsfolk who wander the square. Vampires feed on them, some secretly carry vervain.
local Players = game:GetService("Players")

local NPCs = {}

NPCs.Folder = Instance.new("Folder")
NPCs.Folder.Name = "Townsfolk"
NPCs.Folder.Parent = workspace

local COUNT = 12
local RESPAWN_SECONDS = 15
local VERVAIN_CHANCE = 0.25

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

local rng = Random.new()
local wanderPoints: { Vector3 } = {}

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function isStunned(model: Model)
	return (model:GetAttribute("StunnedUntil") or 0) > workspace:GetServerTimeNow()
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
	if rng:NextNumber() < VERVAIN_CHANCE then
		model:SetAttribute("Vervain", 1)
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = name
	hum.WalkSpeed = 10
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer

	model:PivotTo(CFrame.new(pick(wanderPoints) + Vector3.new(0, 4, 0)))
	model.Parent = NPCs.Folder

	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		root:SetNetworkOwner(nil)
	end

	-- Wander around town.
	task.spawn(function()
		while model.Parent and hum.Health > 0 do
			if not isStunned(model) then
				hum:MoveTo(pick(wanderPoints))
			end
			task.wait(rng:NextNumber(4, 9))
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

function NPCs.Start(points: { Vector3 })
	wanderPoints = points
	for _ = 1, COUNT do
		makeNPC()
	end
end

return NPCs
