-- Moonlit Falls: HUD, side picker, keyboard + on-screen buttons, vampire dash.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AbilityRemote = Remotes:WaitForChild("Ability")
local ChooseSideRemote = Remotes:WaitForChild("ChooseSide")
local NotifyRemote = Remotes:WaitForChild("Notify")

local ABILITIES = {
	Human = {
		{ id = "Stake", key = Enum.KeyCode.E, label = "🪵 ปักหลัก", hint = "E" },
		{ id = "Vervain", key = Enum.KeyCode.R, label = "🌿 สาดเวอร์เวน", hint = "R" },
	},
	Vampire = {
		{ id = "Dash", key = Enum.KeyCode.Q, label = "💨 พุ่ง", hint = "Q" },
		{ id = "Bite", key = Enum.KeyCode.E, label = "🩸 กัด", hint = "E" },
		{ id = "Compel", key = Enum.KeyCode.R, label = "👁 สะกดจิต", hint = "R" },
	},
	Werewolf = {
		{ id = "Dash", key = Enum.KeyCode.Q, label = "💨 กระโจน", hint = "Q", wolfOnly = true },
		{ id = "Claw", key = Enum.KeyCode.E, label = "🐾 ข่วน/กัด", hint = "E" },
	},
}

---------------------------------------------------------------- ui helpers
local function make(class: string, props: { [string]: any }, parent: Instance?)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end
local function corner(parent, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 10) }, parent)
end

local gui = make("ScreenGui", { Name = "MoonlitHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- Status panel (top-left)
local panel = make("Frame", {
	Position = UDim2.fromOffset(12, 12),
	Size = UDim2.fromOffset(240, 112),
	BackgroundColor3 = Color3.fromRGB(15, 10, 20),
	BackgroundTransparency = 0.25,
}, gui)
corner(panel)
make("UIStroke", { Color = Color3.fromRGB(120, 20, 40), Thickness = 1.5 }, panel)
make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8) }, panel)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, panel)

local function line(order, size)
	return make("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, size or 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = size or 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(235, 225, 230),
		Text = "",
	}, panel)
end
local titleLbl = line(1, 16)
titleLbl.Text = "🦇 " .. Config.GAME_NAME
titleLbl.TextColor3 = Color3.fromRGB(220, 60, 80)
local sideLbl = line(2)
local timeLbl = line(3)
local extraLbl = line(5)

local bloodBack = make("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Color3.fromRGB(50, 20, 25) }, panel)
corner(bloodBack, 6)
local bloodFill = make("Frame", { Size = UDim2.fromScale(0.6, 1), BackgroundColor3 = Color3.fromRGB(190, 15, 35) }, bloodBack)
corner(bloodFill, 6)

-- Change-side button (top-right)
local switchBtn = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(120, 36),
	BackgroundColor3 = Color3.fromRGB(60, 15, 25),
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Text = "🔄 เปลี่ยนฝั่ง",
}, gui)
corner(switchBtn)

-- Notifications (center)
local toast = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.new(0.8, 0, 0, 40),
	BackgroundColor3 = Color3.fromRGB(10, 5, 10),
	BackgroundTransparency = 1,
	TextTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	Text = "",
}, gui)
corner(toast)
make("UITextSizeConstraint", { MaxTextSize = 22 }, toast)
make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, toast)

local toastId = 0
local function showToast(text: string, color: Color3?)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = color or Color3.new(1, 1, 1)
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.35
	task.delay(3.2, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end
NotifyRemote.OnClientEvent:Connect(showToast)

---------------------------------------------------------------- side picker
local menu = make("Frame", {
	Name = "SideMenu",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.92, 0, 0, 330),
	BackgroundColor3 = Color3.fromRGB(12, 6, 12),
	BackgroundTransparency = 0.1,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(560, 400) }, menu)
corner(menu, 14)
make("UIStroke", { Color = Color3.fromRGB(150, 20, 40), Thickness = 2 }, menu)
make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, menu)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, menu)
make("TextLabel", {
	LayoutOrder = 0,
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1,
	Font = Enum.Font.Fantasy,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(230, 50, 70),
	Text = "🌙 MOONLIT FALLS — เลือกชะตาของคุณ",
}, menu)

for i, side in { "Human", "Vampire", "Werewolf" } do
	local info = Config.SideInfo[side]
	local btn = make("TextButton", {
		LayoutOrder = i,
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundColor3 = info.color:Lerp(Color3.new(0, 0, 0), 0.55),
		AutoButtonColor = true,
		Text = "",
	}, menu)
	corner(btn)
	make("UIStroke", { Color = info.color, Thickness = 1.5 }, btn)
	make("TextLabel", {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = info.color:Lerp(Color3.new(1, 1, 1), 0.3),
		Text = info.title,
	}, btn)
	make("TextLabel", {
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -24, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(220, 215, 220),
		Text = info.desc,
	}, btn)
	btn.Activated:Connect(function()
		ChooseSideRemote:FireServer(side)
		menu.Visible = false
	end)
end

switchBtn.Activated:Connect(function()
	menu.Visible = not menu.Visible
end)

---------------------------------------------------------------- abilities
local lastUsed: { [string]: number } = {}
local buttonsFrame = make("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -110),
	Size = UDim2.fromOffset(150, 200),
	BackgroundTransparency = 1,
}, gui)
make("UIListLayout", {
	Padding = UDim.new(0, 8),
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, buttonsFrame)

local buttons: { [string]: TextButton } = {}

local function character()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return char, hum
	end
	return nil, nil
end

local function dash()
	local char, hum = character()
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local att = root and root:FindFirstChild("RootAttachment")
	if not att or hum.WalkSpeed == 0 then
		return
	end
	local dir = hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection or root.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * 95
	lv.Parent = root
	Debris:AddItem(lv, 0.28)
end

local function useAbility(a)
	local char = character()
	if not char then
		return
	end
	local cd = Config.Cooldowns[a.id] or 1
	if os.clock() - (lastUsed[a.id] or -99) < cd then
		return
	end
	if a.wolfOnly and not char:GetAttribute("Transformed") then
		showToast("กระโจนได้เฉพาะตอนกลายร่างเป็นหมาป่า 🌕")
		return
	end
	lastUsed[a.id] = os.clock()
	if a.id == "Dash" then
		dash()
		AbilityRemote:FireServer("Dash") -- so everyone sees the dash trail
	else
		AbilityRemote:FireServer(a.id)
	end
end

local function currentSide(): string
	return player:GetAttribute("Side") or "Human"
end

local function rebuildButtons()
	for _, b in buttons do
		b:Destroy()
	end
	table.clear(buttons)
	for i, a in ABILITIES[currentSide()] do
		local b = make("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = Color3.fromRGB(35, 10, 20),
			BackgroundTransparency = 0.15,
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Text = a.label,
			AutoButtonColor = true,
		}, buttonsFrame)
		corner(b, 12)
		make("UIStroke", { Color = Config.SideInfo[currentSide()].color, Thickness = 1.5 }, b)
		b:SetAttribute("BaseText", a.label .. (UserInputService.KeyboardEnabled and ("  [" .. a.hint .. "]") or ""))
		b.Activated:Connect(function()
			useAbility(a)
		end)
		buttons[a.id] = b
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	for _, a in ABILITIES[currentSide()] do
		if input.KeyCode == a.key then
			useAbility(a)
		end
	end
end)

player:GetAttributeChangedSignal("Side"):Connect(rebuildButtons)
rebuildButtons()

---------------------------------------------------------------- night vision for vampires
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "MoonlitVision"
cc.Parent = Lighting

---------------------------------------------------------------- per-frame HUD
RunService.RenderStepped:Connect(function()
	local side = currentSide()
	local info = Config.SideInfo[side]
	local char = player.Character
	local wolf = char and char:GetAttribute("Transformed")
	sideLbl.Text = "ฝั่ง: " .. info.title .. (wolf and " (ร่างหมาป่า)" or "")
	sideLbl.TextColor3 = info.color:Lerp(Color3.new(1, 1, 1), 0.35)

	local isDay = ReplicatedStorage:GetAttribute("IsDay")
	local clock = Lighting.ClockTime
	local hh = math.floor(clock)
	local mm = math.floor((clock - hh) * 60)
	local phase = isDay and "☀️ กลางวัน" or (ReplicatedStorage:GetAttribute("FullMoon") and "🌕 คืนจันทร์เต็มดวง" or "🌙 กลางคืน")
	timeLbl.Text = string.format("%s  %02d:%02d", phase, hh, mm)

	local blood = player:GetAttribute("Blood") or 0
	bloodBack.Visible = side == "Vampire"
	bloodFill.Size = UDim2.fromScale(math.clamp(blood / Config.BLOOD_MAX, 0, 1), 1)

	if side == "Vampire" then
		local ring = char and char:GetAttribute("HasRing")
		extraLbl.Text = string.format("🩸 เลือด %d   %s", blood, ring and "💍 มีแหวน" or "⚠️ ไม่มีแหวน")
	else
		extraLbl.Text = string.format("🌿 เวอร์เวน x%d", player:GetAttribute("Vervain") or 0)
	end

	-- Cooldown display on buttons
	for _, a in ABILITIES[side] do
		local b = buttons[a.id]
		if b then
			local left = (Config.Cooldowns[a.id] or 1) - (os.clock() - (lastUsed[a.id] or -99))
			if left > 0 then
				b.Text = string.format("%s (%.1f)", a.label, left)
				b.BackgroundTransparency = 0.55
			else
				b.Text = b:GetAttribute("BaseText")
				b.BackgroundTransparency = 0.15
			end
		end
	end

	-- Vampires see better at night, wolves see the world warmer under a full moon.
	if side == "Vampire" and not isDay then
		cc.Brightness = 0.12
		cc.Saturation = -0.25
		cc.TintColor = Color3.fromRGB(255, 225, 230)
	elseif wolf then
		cc.Brightness = 0.05
		cc.Saturation = 0.1
		cc.TintColor = Color3.fromRGB(255, 235, 200)
	else
		cc.Brightness = 0
		cc.Saturation = 0
		cc.TintColor = Color3.new(1, 1, 1)
	end
end)
