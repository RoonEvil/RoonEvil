-- Client-only atmosphere: clock hands, glowing windows and lamps at night,
-- bats, fireflies, cemetery mist, the spinning daylight ring, a hunger/sunburn
-- vignette, and a slow camera fly-over while the side menu is open.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function isNight()
	return ReplicatedStorage:GetAttribute("IsDay") == false
end

---------------------------------------------------------------- windows & lamps
local windowOrig: { [BasePart]: { Color3 | Enum.Material } } = {}
local WARM = Color3.fromRGB(255, 200, 120)

local function applyWindow(p: BasePart)
	if not windowOrig[p] then
		windowOrig[p] = { p.Color, p.Material }
	end
	local orig = windowOrig[p]
	if isNight() then
		p.Material = Enum.Material.Neon
		p.Color = p.Name == "Window" and WARM or orig[1] :: Color3
	else
		p.Material = p.Name == "Window" and orig[2] :: Enum.Material or Enum.Material.SmoothPlastic
		p.Color = orig[1] :: Color3
	end
end

local function applyLight(l: Light)
	l.Enabled = isNight()
end

local function refreshNight()
	for _, p in CollectionService:GetTagged("NightWindow") do
		applyWindow(p)
	end
	for _, l in CollectionService:GetTagged("NightLight") do
		applyLight(l)
	end
end
CollectionService:GetInstanceAddedSignal("NightWindow"):Connect(applyWindow)
CollectionService:GetInstanceAddedSignal("NightLight"):Connect(applyLight)
ReplicatedStorage:GetAttributeChangedSignal("IsDay"):Connect(refreshNight)
task.defer(refreshNight)

---------------------------------------------------------------- effects folder
local fx = Instance.new("Folder")
fx.Name = "ClientAmbience"
fx.Parent = workspace

local function ghostPart(props): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		p[k] = v
	end
	p.Parent = fx
	return p
end

local mapFolder = workspace:WaitForChild("MoonlitFalls", 30)
local markers = mapFolder and mapFolder:WaitForChild("AmbienceMarkers", 10)

local function markerPositions(name: string, fallback: Vector3): { Vector3 }
	local list = {}
	if markers then
		for _, m in markers:GetChildren() do
			if m.Name == name and m:IsA("BasePart") then
				table.insert(list, m.Position)
			end
		end
	end
	if #list == 0 then
		table.insert(list, fallback)
	end
	return list
end

---------------------------------------------------------------- fireflies & mist
local nightEmitters: { ParticleEmitter } = {}

for _, pos in markerPositions("Forest", Vector3.new(160, 0, -120)) do
	local box = ghostPart({ Size = Vector3.new(90, 12, 90), Position = pos + Vector3.new(0, 6, 0), Transparency = 1 })
	local pe = Instance.new("ParticleEmitter")
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.Color = ColorSequence.new(Color3.fromRGB(220, 255, 120))
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.25), NumberSequenceKeypoint.new(0.8, 0.25), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(4, 7)
	pe.Speed = NumberRange.new(0.3, 1)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.RotSpeed = NumberRange.new(-30, 30)
	pe.Rate = 18
	pe.Parent = box
	table.insert(nightEmitters, pe)
end

local mist: ParticleEmitter
do
	local pos = markerPositions("Cemetery", Vector3.new(-150, 0, 0))[1]
	local box = ghostPart({ Size = Vector3.new(70, 1, 60), Position = pos + Vector3.new(0, 1, 0), Transparency = 1 })
	mist = Instance.new("ParticleEmitter")
	mist.Shape = Enum.ParticleEmitterShape.Box
	mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	mist.Color = ColorSequence.new(Color3.fromRGB(200, 205, 220))
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(0.7, 0.85), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new(10, 16)
	mist.Lifetime = NumberRange.new(8, 12)
	mist.Speed = NumberRange.new(0.5, 1.5)
	mist.SpreadAngle = Vector2.new(180, 10)
	mist.Rate = 6
	mist.LightInfluence = 0.6
	mist.Parent = box
end

---------------------------------------------------------------- bats
type Bat = { body: BasePart, left: BasePart, right: BasePart, center: Vector3, radius: number, speed: number, height: number, phase: number }
local bats: { Bat } = {}
local rng = Random.new()
local roosts = { markerPositions("BatRoost", Vector3.new(0, 48, -22))[1], markerPositions("Cemetery", Vector3.new(-150, 0, 0))[1] + Vector3.new(0, 18, 0) }
local BAT_COLOR = Color3.fromRGB(18, 14, 18)

for i = 1, 18 do
	local s = rng:NextNumber(0.8, 1.2)
	local body = ghostPart({ Name = "Bat", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.9) * s, Color = BAT_COLOR, Material = Enum.Material.SmoothPlastic })
	local left = ghostPart({ Name = "BatWing", Size = Vector3.new(1.6, 0.06, 0.8) * s, Color = BAT_COLOR, Material = Enum.Material.SmoothPlastic })
	local right = ghostPart({ Name = "BatWing", Size = Vector3.new(1.6, 0.06, 0.8) * s, Color = BAT_COLOR, Material = Enum.Material.SmoothPlastic })
	table.insert(bats, {
		body = body,
		left = left,
		right = right,
		center = roosts[(i % 2) + 1],
		radius = rng:NextNumber(10, 28),
		speed = rng:NextNumber(0.5, 1.1) * (rng:NextNumber() < 0.5 and -1 or 1),
		height = rng:NextNumber(-6, 10),
		phase = rng:NextNumber(0, math.pi * 2),
	})
end

---------------------------------------------------------------- vignette
local gui = Instance.new("ScreenGui")
gui.Name = "MoonlitVignette"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -2
gui.Parent = player:WaitForChild("PlayerGui")
local vignette = Instance.new("Frame")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BorderSizePixel = 0
vignette.BackgroundTransparency = 1
vignette.Parent = gui
local grad = Instance.new("UIGradient")
-- Transparent in the middle, solid at the edges (radial-ish via two passes).
grad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.25, 0.85),
	NumberSequenceKeypoint.new(0.75, 0.85),
	NumberSequenceKeypoint.new(1, 0),
})
grad.Parent = vignette

---------------------------------------------------------------- intro fly-over
local wasMenuOpen = false
local function menuOpen(): boolean
	local hud = player.PlayerGui:FindFirstChild("MoonlitHUD")
	local menu = hud and hud:FindFirstChild("SideMenu")
	return menu ~= nil and menu.Visible
end

---------------------------------------------------------------- per frame
local clockHands: Model? = nil
local ring: BasePart? = nil
local lastLookup = 0

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local night = isNight()

	-- Find streamed-in map pieces now and then.
	if t - lastLookup > 2 and mapFolder then
		lastLookup = t
		clockHands = clockHands and clockHands.Parent and clockHands or mapFolder:FindFirstChild("ClockHands") :: Model?
		ring = ring and ring.Parent and ring or mapFolder:FindFirstChild("DaylightRing", true) :: BasePart?
	end

	-- Clock hands follow the in-game time.
	if clockHands then
		local center = clockHands:GetAttribute("Center") :: Vector3?
		local hour = clockHands:FindFirstChild("HourHand") :: BasePart?
		local minute = clockHands:FindFirstChild("MinuteHand") :: BasePart?
		if center and hour and minute then
			local ct = Lighting.ClockTime
			local ha = (ct % 12) / 12 * math.pi * 2
			local ma = (ct % 1) * math.pi * 2
			hour.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, -ha) * CFrame.new(0, hour.Size.Y / 2 - 0.2, 0)
			minute.CFrame = CFrame.new(center + Vector3.new(0, 0, 0.05)) * CFrame.Angles(0, 0, -ma) * CFrame.new(0, minute.Size.Y / 2 - 0.2, 0)
		end
	end

	if ring then
		ring.CFrame = CFrame.new(ring.Position) * CFrame.Angles(0, t * 1.5, 0) * CFrame.Angles(0, 0, math.sin(t) * 0.3)
	end

	for _, pe in nightEmitters do
		pe.Enabled = night
	end
	mist.Rate = night and 9 or 3

	-- Bats circle the clock tower and the cemetery at night.
	for _, b in bats do
		if night then
			local a = b.phase + t * b.speed
			local wobble = math.sin(t * 2.3 + b.phase) * 3
			local pos = b.center + Vector3.new(math.cos(a) * b.radius, b.height + wobble, math.sin(a) * b.radius)
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(b.speed)
			local cf = CFrame.lookAt(pos, pos + tangent)
			local flap = math.sin(t * 20 + b.phase) * 0.9
			b.body.CFrame = cf
			b.left.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-b.left.Size.X / 2, 0, 0)
			b.right.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(b.right.Size.X / 2, 0, 0)
			b.body.Transparency, b.left.Transparency, b.right.Transparency = 0, 0, 0
		elseif b.body.Transparency == 0 then
			b.body.Transparency, b.left.Transparency, b.right.Transparency = 1, 1, 1
		end
	end

	-- Hunger / sunburn vignette.
	local char = player.Character
	local side = player:GetAttribute("Side")
	local strength, color = 0, Color3.new(0, 0, 0)
	if char and (char:GetAttribute("BurningUntil") or 0) > workspace:GetServerTimeNow() then
		strength, color = 0.55 + math.sin(t * 12) * 0.1, Color3.fromRGB(255, 120, 20)
	elseif side == "Vampire" and (player:GetAttribute("Blood") or 100) < 25 then
		strength, color = 0.35 + math.sin(t * 5) * 0.12, Color3.fromRGB(140, 0, 10)
	elseif night then
		strength, color = 0.25, Color3.fromRGB(5, 0, 15)
	end
	vignette.BackgroundColor3 = color
	vignette.BackgroundTransparency = 1 - strength

	-- Fly-over camera while choosing a side.
	local open = menuOpen()
	if open then
		camera.CameraType = Enum.CameraType.Scriptable
		local a = t * 0.08
		local pos = Vector3.new(math.cos(a) * 130, 55, math.sin(a) * 130)
		camera.CFrame = CFrame.lookAt(pos, Vector3.new(0, 15, 0))
	elseif wasMenuOpen then
		camera.CameraType = Enum.CameraType.Custom
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraSubject = hum
		end
	end
	wasMenuOpen = open
end)
