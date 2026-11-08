-- Plays procedural animations and effects for every character on this client:
-- ability clips sent by the server, stunned/burning poses, fallback walk for
-- townsfolk, the flowing vampire cape, glowing eyes, and the four-legged wolf.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Anims = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Anims"))
local AnimRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Anim")

local JOINTS = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg",
	LeftHip = "LeftUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftKnee = "LeftLowerLeg",
}
-- Clips that only move the wolf body (no humanoid pose).
local WOLF_CLIPS = { Howl = 1.8, Claw = 0.5, Dash = 0.45 }
local SLASH_SOUND = "rbxasset://sounds/swordslash.wav"

type Rig = {
	joints: { [string]: { motor: Motor6D, base: CFrame } },
	active: boolean,
	clipName: string?,
	clipStart: number,
	clipLen: number,
	capeBase: CFrame?,
	wolfBases: { [Weld]: CFrame },
	wolfPhase: number,
}
local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any

local function getRig(model: Model): Rig
	local rig = rigs[model]
	if not rig then
		rig = { joints = {}, active = false, clipName = nil, clipStart = 0, clipLen = 0, capeBase = nil, wolfBases = {}, wolfPhase = 0 }
		rigs[model] = rig
	end
	return rig
end

local function captureJoints(model: Model, rig: Rig)
	table.clear(rig.joints)
	for name, partName in JOINTS do
		local p = model:FindFirstChild(partName)
		local m = p and p:FindFirstChild(name)
		if m and m:IsA("Motor6D") then
			rig.joints[name] = { motor = m, base = m.C0 }
		end
	end
end

local function restore(rig: Rig)
	for _, j in rig.joints do
		if j.motor.Parent then
			j.motor.C0 = j.base
		end
	end
	rig.active = false
end

---------------------------------------------------------------- screen fx
local fxGui = Instance.new("ScreenGui")
fxGui.Name = "MoonlitFx"
fxGui.IgnoreGuiInset = true
fxGui.ResetOnSpawn = false
fxGui.DisplayOrder = -1
fxGui.Parent = player:WaitForChild("PlayerGui")
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = fxGui

local function screenFlash(color: Color3, strength: number, duration: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength
	TweenService:Create(flash, TweenInfo.new(duration), { BackgroundTransparency = 1 }):Play()
end

local shakeUntil, shakeMag = 0, 0
local function shake(mag: number, duration: number)
	shakeMag = math.max(mag, os.clock() < shakeUntil and shakeMag or 0)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end
RunService:BindToRenderStep("MoonlitShake", Enum.RenderPriority.Camera.Value + 1, function()
	local left = shakeUntil - os.clock()
	if left > 0 then
		local m = shakeMag * math.min(1, left * 3)
		camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * m), math.rad((math.random() - 0.5) * m), 0)
	end
end)

local function sound(id: string, parent: Instance, volume: number?, pitch: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.RollOffMaxDistance = 80
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 3)
end

local function fxPart(props): BasePart
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		p[k] = v
	end
	p.Parent = workspace
	return p
end

local function particles(at: BasePart | Attachment, color: Color3, count: number, speed: number?, size: number?)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.Size = NumberSequence.new(size or 0.4, 0)
	pe.Speed = NumberRange.new((speed or 10) * 0.6, speed or 10)
	pe.Lifetime = NumberRange.new(0.4, 0.9)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, -20, 0)
	pe.Rate = 0
	pe.LightEmission = 0.4
	pe.Parent = at
	pe:Emit(count)
	Debris:AddItem(pe, 1.5)
end

local function isLocal(model: Model?)
	return model ~= nil and model == player.Character
end

local function nearLocal(model: Model, dist: number)
	local char = player.Character
	return char and (char:GetPivot().Position - model:GetPivot().Position).Magnitude < dist
end

---------------------------------------------------------------- per-clip effects
local Effects = {}

function Effects.Bite(model: Model, target: Model?)
	if not target then
		return
	end
	task.delay(0.15, function()
		local head = target:FindFirstChild("Head")
		if head then
			particles(head, Color3.fromRGB(150, 0, 15), 30, 8, 0.35)
		end
	end)
	if isLocal(model) then
		shake(2, 0.4)
	end
end

function Effects.Bitten(model: Model)
	if isLocal(model) then
		screenFlash(Color3.fromRGB(160, 0, 0), 0.55, 1.2)
		shake(4, 0.6)
	end
end

function Effects.Compel(model: Model, target: Model?)
	local head = model:FindFirstChild("Head")
	local tHead = target and target:FindFirstChild("Head")
	if not head or not tHead then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.1, -0.6)
	a0.Parent = head
	local a1 = Instance.new("Attachment")
	a1.Parent = tHead
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Color3.fromRGB(200, 40, 70), Color3.fromRGB(230, 200, 255))
	beam.Transparency = NumberSequence.new(0.2, 0.6)
	beam.Width0 = 0.15
	beam.Width1 = 0.6
	beam.LightEmission = 1
	beam.CurveSize0 = 1
	beam.CurveSize1 = -1
	beam.Segments = 20
	beam.FaceCamera = true
	beam.Parent = head
	for _, x in { a0, a1, beam } do
		Debris:AddItem(x, 1.3)
	end
	particles(tHead, Color3.fromRGB(230, 200, 255), 20, 3, 0.3)
	if isLocal(target) then
		local blur = Instance.new("BlurEffect")
		blur.Size = 14
		blur.Parent = Lighting
		TweenService:Create(blur, TweenInfo.new(4), { Size = 0 }):Play()
		Debris:AddItem(blur, 4.1)
		screenFlash(Color3.fromRGB(220, 200, 255), 0.5, 2)
	end
end

local function handProp(model: Model, props, offset: CFrame, life: number)
	local hand = model:FindFirstChild("RightHand")
	if not hand then
		return nil
	end
	local p = fxPart(props)
	p.Anchored = false
	p.Massless = true
	p.CFrame = hand.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = hand
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	Debris:AddItem(p, life)
	return p
end

function Effects.Stake(model: Model, target: Model?)
	local stake = handProp(model, { Name = "Stake", Size = Vector3.new(0.35, 2.6, 0.35), Color = Color3.fromRGB(120, 85, 50), Material = Enum.Material.Wood }, CFrame.new(0, -1.1, 0), 0.8)
	if stake then
		local tip = fxPart({ ClassName = "WedgePart", Name = "StakeTip", Size = Vector3.new(0.35, 0.6, 0.35), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood })
		tip.Anchored = false
		tip.Massless = true
		tip.CFrame = stake.CFrame * CFrame.new(0, -1.6, 0) * CFrame.Angles(math.pi, 0, 0)
		local wc = Instance.new("WeldConstraint")
		wc.Part0 = stake
		wc.Part1 = tip
		wc.Parent = tip
		Debris:AddItem(tip, 0.8)
	end
	task.delay(0.35, function()
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			sound(SLASH_SOUND, root, 0.6, 0.8)
		end
		local torso = target and target:FindFirstChild("UpperTorso")
		if torso then
			particles(torso, Color3.fromRGB(120, 0, 10), 25, 9)
		end
	end)
end

function Effects.Throw(model: Model, target: Model?)
	task.delay(0.3, function()
		local hand = model:FindFirstChild("RightHand")
		if not hand then
			return
		end
		local tRoot = target and target:FindFirstChild("HumanoidRootPart")
		local goal = tRoot and tRoot.Position or (hand.Position + model:GetPivot().LookVector * 14)
		local orb = fxPart({ Name = "VervainOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Color = Color3.fromRGB(160, 90, 230), Material = Enum.Material.Neon, Position = hand.Position })
		local trail = Instance.new("Sparkles")
		trail.SparkleColor = Color3.fromRGB(180, 120, 255)
		trail.Parent = orb
		local tween = TweenService:Create(orb, TweenInfo.new(0.25, Enum.EasingStyle.Linear), { Position = goal })
		tween:Play()
		tween.Completed:Connect(function()
			particles(orb, Color3.fromRGB(170, 100, 240), 40, 14, 0.5)
			orb.Transparency = 1
			trail:Destroy()
			sound(SLASH_SOUND, orb, 0.4, 1.6)
			Debris:AddItem(orb, 1.6)
		end)
	end)
end

function Effects.Claw(model: Model, target: Model?)
	local torso = target and (target:FindFirstChild("UpperTorso") or target:FindFirstChild("HumanoidRootPart"))
	if not torso then
		return
	end
	task.delay(0.15, function()
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			sound(SLASH_SOUND, root, 0.7, 0.7)
		end
		for i = -1, 1 do
			local s = fxPart({ Name = "Slash", Size = Vector3.new(0.12, 3.2, 0.12), Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon, CFrame = torso.CFrame * CFrame.new(i * 0.45, 0, -0.8) * CFrame.Angles(0, 0, math.rad(30)) })
			TweenService:Create(s, TweenInfo.new(0.45), { Transparency = 1, Size = Vector3.new(0.05, 3.8, 0.05) }):Play()
			Debris:AddItem(s, 0.5)
		end
		particles(torso, Color3.fromRGB(150, 0, 15), 15, 8)
	end)
end

function Effects.Dash(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.6, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.3
	trail.Color = ColorSequence.new(Color3.fromRGB(120, 0, 20), Color3.fromRGB(20, 0, 5))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 0.3
	trail.Parent = root
	for _, x in { a0, a1, trail } do
		Debris:AddItem(x, 0.7)
	end
	particles(root, Color3.fromRGB(60, 50, 55), 15, 6, 1)
end

function Effects.Transform(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		particles(root, Color3.fromRGB(255, 210, 90), 40, 6, 0.6)
	end
	if isLocal(model) then
		screenFlash(Color3.fromRGB(255, 220, 120), 0.5, 1.8)
		shake(3, 1.5)
	end
end

function Effects.Howl(model: Model)
	local head = model:FindFirstChild("Head", true)
	local wolf = model:FindFirstChild("WolfBody")
	local h = wolf and wolf:FindFirstChild("Head") or head
	if h then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(220, 60)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.MaxDistance = 120
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "AWOOOOOO!! 🌕"
		t.Font = Enum.Font.Fantasy
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 220, 120)
		t.TextStrokeTransparency = 0.3
		t.Parent = bb
		bb.Parent = h
		Debris:AddItem(bb, 2)
	end
	if nearLocal(model, 70) then
		shake(1.5, 1.2)
	end
end

function Effects.Hit(model: Model)
	if isLocal(model) then
		screenFlash(Color3.fromRGB(200, 0, 0), 0.35, 0.5)
		shake(2.5, 0.3)
	end
end

AnimRemote.OnClientEvent:Connect(function(model: Model?, clipName: string, target: Model?)
	if typeof(model) ~= "Instance" or not model.Parent then
		return
	end
	local rig = getRig(model)
	local clip = Anims.Clips[clipName]
	rig.clipName = clipName
	rig.clipStart = os.clock()
	rig.clipLen = clip and clip.length or WOLF_CLIPS[clipName] or 1
	local fx = Effects[clipName]
	if fx then
		task.spawn(fx, model, target)
	end
end)

---------------------------------------------------------------- per-frame update
local function updateCape(model: Model, rig: Rig, root: BasePart, t: number)
	local cape = model:FindFirstChild("VampCape")
	local weld = cape and cape:FindFirstChild("CapeWeld") :: Weld?
	if not weld then
		return
	end
	rig.capeBase = rig.capeBase or weld.C0
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local angle = 6 + math.min(speed, 45) * 1.5 + math.sin(t * 4 + speed * 0.1) * (2 + speed * 0.08)
	weld.C0 = (rig.capeBase :: CFrame) * CFrame.Angles(-math.rad(angle), 0, math.rad(math.sin(t * 2.3) * 2))
end

local function updateVampFace(model: Model, rig: Rig)
	local plr = Players:GetPlayerFromCharacter(model)
	local hunting = rig.clipName == "Bite" or rig.clipName == "Compel" or rig.clipName == "Dash"
	hunting = hunting and os.clock() - rig.clipStart < rig.clipLen + 0.5
	local hungry = plr and (plr:GetAttribute("Blood") or 100) < 25
	local night = ReplicatedStorage:GetAttribute("IsDay") == false
	for _, p in model:GetChildren() do
		if p.Name == "VampEye" then
			p.Transparency = (hunting or hungry or night) and 0 or 1
		elseif p.Name == "VampFang" then
			p.Transparency = (hunting or hungry) and 0 or 1
		end
	end
end

local function updateWolf(wolf: Model, rig: Rig, root: BasePart, t: number, dt: number)
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	rig.wolfPhase += dt * (3 + speed * 0.4)
	local ph = rig.wolfPhase
	local amp = math.clamp(speed / 26, 0, 1) * 0.9
	local clipT = os.clock() - rig.clipStart
	local clipW = 0
	if rig.clipName and clipT < rig.clipLen then
		clipW = math.sin(math.pi * clipT / rig.clipLen)
	end
	for _, p in wolf:GetChildren() do
		local w = p:FindFirstChildOfClass("Weld")
		if w then
			local base = rig.wolfBases[w]
			if not base then
				base = w.C0
				rig.wolfBases[w] = base
			end
			local n = p.Name
			if n == "LegFL" or n == "LegBR" then
				w.C0 = base * CFrame.Angles(math.sin(ph) * amp, 0, 0)
			elseif n == "LegFR" or n == "LegBL" then
				w.C0 = base * CFrame.Angles(-math.sin(ph) * amp, 0, 0)
			elseif n == "Body" then
				local lean = rig.clipName == "Howl" and clipW * 0.25 or 0
				w.C0 = base * CFrame.new(0, math.abs(math.sin(ph)) * 0.3 * amp + math.sin(t * 2) * 0.05, 0) * CFrame.Angles(lean, 0, 0)
			elseif n == "Tail" then
				w.C0 = base * CFrame.Angles(math.sin(t * 3) * 0.1 - amp * 0.3, math.sin(t * (6 + speed * 0.2)) * 0.35, 0)
			elseif n == "Head" then
				local cf = CFrame.Angles(math.sin(t * 1.5) * 0.05 + math.sin(ph * 2) * 0.05 * amp, 0, 0)
				if rig.clipName == "Howl" then
					cf = CFrame.Angles(math.rad(55) * clipW, 0, 0)
				elseif rig.clipName == "Claw" then
					cf = CFrame.new(0, -0.3 * clipW, -1.4 * clipW) * CFrame.Angles(-0.35 * clipW, 0, 0)
				end
				w.C0 = base * cf
			end
		end
	end
end

local function update(model: Model, t: number, dt: number)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rig = rigs[model]
	if not hum or not root or hum.Health <= 0 then
		if rig and rig.active then
			restore(rig)
		end
		return
	end
	rig = getRig(model)

	local pose = {}
	local any = false
	local clipT = os.clock() - rig.clipStart
	local clip = rig.clipName and Anims.Clips[rig.clipName]
	if clip and clipT < clip.length then
		Anims.Add(pose, Anims.Sample(clip, clipT))
		any = true
	end

	local serverNow = workspace:GetServerTimeNow()
	if (model:GetAttribute("StunnedUntil") or 0) > serverNow then
		Anims.Add(pose, Anims.Loops.Stunned(t))
		any = true
	elseif (model:GetAttribute("BurningUntil") or 0) > serverNow then
		Anims.Add(pose, Anims.Loops.Burning(t))
		any = true
	end

	-- Townsfolk (or any rig) with no animation tracks get a procedural walk/idle.
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator or #animator:GetPlayingAnimationTracks() == 0 then
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		Anims.Add(pose, speed > 0.8 and Anims.Loops.Walk(t, speed) or Anims.Loops.Idle(t))
		any = true
	end

	if any then
		if not rig.active then
			captureJoints(model, rig)
			rig.active = true
		end
		for name, j in rig.joints do
			if j.motor.Parent then
				local a = pose[name]
				j.motor.C0 = a and j.base * CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3])) or j.base
			end
		end
	elseif rig.active then
		restore(rig)
	end

	updateCape(model, rig, root, t)
	updateVampFace(model, rig)
	local wolf = model:FindFirstChild("WolfBody")
	if wolf then
		updateWolf(wolf :: Model, rig, root, t, dt)
	elseif next(rig.wolfBases) then
		table.clear(rig.wolfBases)
	end
end

local townsfolk = workspace:WaitForChild("Townsfolk", 10)

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for _, p in Players:GetPlayers() do
		if p.Character then
			update(p.Character, t, dt)
		end
	end
	if townsfolk then
		for _, m in townsfolk:GetChildren() do
			if m:IsA("Model") then
				update(m, t, dt)
			end
		end
	end
end)
