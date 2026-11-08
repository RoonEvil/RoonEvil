-- Builds the whole town of Moonlit Falls out of parts and terrain, plus the lighting.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local MapBuilder = {}

local rng = Random.new(1864)
local mapFolder: Folder

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent or mapFolder
	props.Parent = nil
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function signOn(target: BasePart, face: Enum.NormalId, text: string, textColor: Color3?)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.Fantasy
	label.TextColor3 = textColor or Color3.fromRGB(255, 235, 200)
	label.Parent = sg
end

local function light(parent: BasePart, range: number, brightness: number, color: Color3)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color
	l.Parent = parent
	CollectionService:AddTag(l, "NightLight")
	return l
end

local function window(model: Model, cf: CFrame, w: number, h: number)
	part({ Name = "WindowFrame", Size = Vector3.new(w + 0.6, h + 0.6, 0.3), CFrame = cf * CFrame.new(0, 0, 0.05), Color = Color3.fromRGB(230, 225, 210), Material = Enum.Material.Wood, Parent = model })
	local glass = part({ Name = "Window", Size = Vector3.new(w, h, 0.3), CFrame = cf * CFrame.new(0, 0, -0.1), Color = Color3.fromRGB(70, 80, 95), Material = Enum.Material.Glass, Reflectance = 0.15, Parent = model })
	CollectionService:AddTag(glass, "NightWindow")
	part({ Name = "Mullion", Size = Vector3.new(0.15, h, 0.35), CFrame = cf * CFrame.new(0, 0, -0.15), Color = Color3.fromRGB(230, 225, 210), Material = Enum.Material.Wood, Parent = model })
	part({ Name = "Sill", Size = Vector3.new(w + 1, 0.3, 0.8), CFrame = cf * CFrame.new(0, -h / 2 - 0.35, -0.3), Color = Color3.fromRGB(200, 195, 185), Parent = model })
end

-- Hollow building with a door, windows and a pitched roof. Built facing +Z, then rotated by `yaw`.
local function building(name, center: Vector3, yaw: number, w, d, h, wallColor: Color3, roofColor: Color3, signText: string?)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = mapFolder
	local t = 1
	local mid = Vector3.new(0, h / 2, 0)
	local doorW, doorH = 6, 9
	local sideW = (w - doorW) / 2

	local function wall(size, pos)
		return part({ Size = size, Position = pos, Color = wallColor, Material = Enum.Material.Brick, Parent = model })
	end
	wall(Vector3.new(w, h, t), mid + Vector3.new(0, 0, -d / 2))
	wall(Vector3.new(t, h, d), mid + Vector3.new(-w / 2, 0, 0))
	wall(Vector3.new(t, h, d), mid + Vector3.new(w / 2, 0, 0))
	wall(Vector3.new(sideW, h, t), mid + Vector3.new(-(doorW / 2 + sideW / 2), 0, d / 2))
	wall(Vector3.new(sideW, h, t), mid + Vector3.new(doorW / 2 + sideW / 2, 0, d / 2))
	wall(Vector3.new(doorW, h - doorH, t), Vector3.new(0, doorH + (h - doorH) / 2, d / 2))

	-- Trim and foundation
	local trim = Color3.fromRGB(225, 220, 205)
	part({ Name = "Foundation", Size = Vector3.new(w + 1, 1, d + 1), Position = Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(90, 88, 85), Material = Enum.Material.Concrete, CanCollide = false, Parent = model })
	part({ Name = "Cornice", Size = Vector3.new(w + 1.4, 0.6, d + 1.4), Position = Vector3.new(0, h - 0.3, 0), Color = trim, Parent = model })
	for _, x in { -doorW / 2 - 0.3, doorW / 2 + 0.3 } do
		part({ Name = "DoorFrame", Size = Vector3.new(0.6, doorH, 0.6), Position = Vector3.new(x, doorH / 2, d / 2 + 0.2), Color = trim, Material = Enum.Material.Wood, Parent = model })
	end
	part({ Name = "DoorFrame", Size = Vector3.new(doorW + 1.2, 0.6, 0.6), Position = Vector3.new(0, doorH + 0.3, d / 2 + 0.2), Color = trim, Material = Enum.Material.Wood, Parent = model })
	-- Open door swung inward
	part({ Name = "Door", Size = Vector3.new(doorW - 0.4, doorH - 0.2, 0.3), CFrame = CFrame.new(-doorW / 2 + 0.3, doorH / 2, d / 2 - 0.3) * CFrame.Angles(0, math.rad(-80), 0) * CFrame.new((doorW - 0.4) / 2, 0, 0), Color = Color3.fromRGB(90, 40, 30), Material = Enum.Material.Wood, CanCollide = false, Parent = model })
	part({ Name = "Step", Size = Vector3.new(doorW + 2, 0.5, 2), Position = Vector3.new(0, 0.25, d / 2 + 1.2), Color = Color3.fromRGB(120, 118, 112), Material = Enum.Material.Concrete, Parent = model })

	-- Windows: front (two floors if tall) and sides
	local floors = h >= 16 and { 4.5, h - 5 } or { 4.5 }
	for _, y in floors do
		for _, x in { -(doorW / 2 + sideW / 2), doorW / 2 + sideW / 2 } do
			window(model, CFrame.new(x, y + 1, d / 2 + 0.5), math.min(4, sideW - 2), 3.5)
		end
		for _, side in { -1, 1 } do
			for _, z in { -d / 4, d / 4 } do
				window(model, CFrame.new(side * (w / 2 + 0.5), y + 1, z) * CFrame.Angles(0, side * math.rad(90), 0), 3.5, 3.5)
			end
		end
	end

	-- Pitched roof (two wedges meeting at the ridge)
	local rh = math.max(5, d * 0.32)
	local half = d / 2 + 1.5
	part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(w + 2, rh, half), CFrame = CFrame.new(0, h + rh / 2, -half / 2), Color = roofColor, Material = Enum.Material.Slate, Parent = model })
	part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(w + 2, rh, half), CFrame = CFrame.new(0, h + rh / 2, half / 2) * CFrame.Angles(0, math.pi, 0), Color = roofColor, Material = Enum.Material.Slate, Parent = model })
	part({ Name = "Ceiling", Size = Vector3.new(w, 0.6, d), Position = Vector3.new(0, h + 0.1, 0), Color = Color3.fromRGB(60, 50, 45), Material = Enum.Material.Wood, Parent = model })
	local chim = part({ Name = "Chimney", Size = Vector3.new(2.5, rh + 3, 2.5), Position = Vector3.new(w / 3, h + (rh + 3) / 2, -d / 5), Color = Color3.fromRGB(110, 60, 50), Material = Enum.Material.Brick, Parent = model })
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(120, 120, 125)
	smoke.Opacity = 0.08
	smoke.RiseVelocity = 3
	smoke.Size = 2
	local smokeAtt = part({ Name = "ChimneyTop", Size = Vector3.new(1, 0.2, 1), Position = chim.Position + Vector3.new(0, chim.Size.Y / 2 + 0.2, 0), Transparency = 1, CanCollide = false, Parent = model })
	smoke.Parent = smokeAtt

	part({ Name = "Floor", Size = Vector3.new(w - 1, 0.3, d - 1), Position = Vector3.new(0, 1.05, 0), Color = Color3.fromRGB(110, 75, 50), Material = Enum.Material.WoodPlanks, Parent = model })
	part({ Name = "Rug", Size = Vector3.new(w * 0.4, 0.05, d * 0.4), Position = Vector3.new(0, 1.22, 0), Color = Color3.fromRGB(110, 20, 30), Material = Enum.Material.Fabric, CanCollide = false, Parent = model })
	-- A table and chairs inside
	part({ Name = "Table", Size = Vector3.new(4, 0.4, 3), Position = Vector3.new(-w / 4, 3.6, -d / 5), Color = Color3.fromRGB(80, 50, 30), Material = Enum.Material.Wood, Parent = model })
	part({ Name = "TableLeg", Size = Vector3.new(0.6, 2.4, 0.6), Position = Vector3.new(-w / 4, 2.4, -d / 5), Color = Color3.fromRGB(70, 45, 28), Material = Enum.Material.Wood, Parent = model })
	for _, dz in { -2.4, 2.4 } do
		local seat = Instance.new("Seat")
		seat.Anchored = true
		seat.Size = Vector3.new(2, 0.4, 2)
		seat.Position = Vector3.new(-w / 4, 2.6, -d / 5 + dz)
		seat.Color = Color3.fromRGB(100, 60, 35)
		seat.Material = Enum.Material.Wood
		seat.Parent = model
	end
	local lamp = part({ Name = "Lamp", Size = Vector3.new(1.2, 1, 1.2), Position = Vector3.new(0, h - 1.5, 0), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
	light(lamp, math.max(w, d), 1.5, Color3.fromRGB(255, 190, 120))

	if signText then
		local board = part({ Name = "Sign", Size = Vector3.new(math.min(w - 4, 22), 3, 0.4), Position = Vector3.new(0, doorH + 2.4, d / 2 + 0.8), Color = Color3.fromRGB(40, 25, 20), Material = Enum.Material.Wood, Parent = model })
		signOn(board, Enum.NormalId.Back, signText)
	end

	model.WorldPivot = CFrame.new()
	model:PivotTo(CFrame.new(center) * CFrame.Angles(0, yaw, 0))
	return model
end

-- Attach extra pieces to a building in its local space (front = +Z).
local function addTo(model: Model, props)
	local pivot = model:GetPivot()
	props.Parent = model
	if props.CFrame then
		props.CFrame = pivot * props.CFrame
	end
	return part(props)
end

local function oak(pos: Vector3)
	local h = rng:NextNumber(12, 20)
	part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.2, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 50, 35), Material = Enum.Material.Wood })
	local base = Color3.fromRGB(28 + rng:NextInteger(0, 20), 58 + rng:NextInteger(0, 25), 32)
	for i = 1, 3 do
		local r = rng:NextNumber(8, 13)
		local off = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1, 3), rng:NextNumber(-3, 3))
		part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r, r), Position = pos + Vector3.new(0, h, 0) + off * (i == 1 and 0 or 1), Color = base:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.2)), Material = Enum.Material.Grass })
	end
end

local function pine(pos: Vector3)
	local h = rng:NextNumber(22, 34)
	part({ Name = "Trunk", Size = Vector3.new(1.6, h * 0.5, 1.6), Position = pos + Vector3.new(0, h * 0.25, 0), Color = Color3.fromRGB(60, 42, 30), Material = Enum.Material.Wood })
	local color = Color3.fromRGB(20, 45 + rng:NextInteger(0, 15), 30)
	for i = 0, 4 do
		local s = (1 - i / 5) * 13 + 2
		local y = h * 0.25 + i * (h * 0.15)
		part({ Name = "Needles", Size = Vector3.new(s, h * 0.18, s), CFrame = CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, math.rad(45 * (i % 2)), 0), Color = color, Material = Enum.Material.Grass })
	end
end

local function rock(pos: Vector3, s: number)
	part({ Name = "Rock", Size = Vector3.new(s, s * 0.7, s * 1.2), CFrame = CFrame.new(pos + Vector3.new(0, s * 0.25, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Color = Color3.fromRGB(95, 95, 100), Material = Enum.Material.Rock })
end

local function streetLamp(pos: Vector3)
	part({ Size = Vector3.new(1.2, 1, 1.2), Position = pos + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(25, 25, 25), Material = Enum.Material.Metal })
	part({ Size = Vector3.new(0.5, 12, 0.5), Position = pos + Vector3.new(0, 6, 0), Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.Metal })
	part({ Size = Vector3.new(1.8, 0.3, 1.8), Position = pos + Vector3.new(0, 13.6, 0), Color = Color3.fromRGB(25, 25, 25), Material = Enum.Material.Metal })
	local bulb = part({ Name = "LampGlass", Size = Vector3.new(1.3, 1.5, 1.3), Position = pos + Vector3.new(0, 12.7, 0), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon })
	CollectionService:AddTag(bulb, "NightWindow")
	light(bulb, 26, 2, Color3.fromRGB(255, 210, 140))
end

local function bench(cf: CFrame)
	local wood = Color3.fromRGB(110, 70, 40)
	local seat = Instance.new("Seat")
	seat.Anchored = true
	seat.Size = Vector3.new(6, 0.4, 2)
	seat.CFrame = cf * CFrame.new(0, 2, 0)
	seat.Color = wood
	seat.Material = Enum.Material.Wood
	seat.Parent = mapFolder
	part({ Size = Vector3.new(6, 2, 0.3), CFrame = cf * CFrame.new(0, 3.3, 0.9) * CFrame.Angles(math.rad(-10), 0, 0), Color = wood, Material = Enum.Material.Wood })
	for _, x in { -2.6, 2.6 } do
		part({ Size = Vector3.new(0.4, 2, 2), CFrame = cf * CFrame.new(x, 1, 0), Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.Metal })
	end
end

local function car(cf: CFrame, color: Color3)
	part({ Name = "CarBody", Size = Vector3.new(5.5, 2, 11), CFrame = cf * CFrame.new(0, 1.8, 0), Color = color, Material = Enum.Material.SmoothPlastic, Reflectance = 0.1 })
	part({ Name = "CarCabin", Size = Vector3.new(5, 1.8, 5.5), CFrame = cf * CFrame.new(0, 3.7, 0.5), Color = color, Material = Enum.Material.SmoothPlastic })
	part({ Name = "CarGlass", Size = Vector3.new(5.1, 1.4, 5.6), CFrame = cf * CFrame.new(0, 3.8, 0.5), Color = Color3.fromRGB(30, 35, 45), Material = Enum.Material.Glass, Transparency = 0.2 })
	for _, x in { -2.6, 2.6 } do
		for _, z in { -3.5, 3.5 } do
			part({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 2.2, 2.2), CFrame = cf * CFrame.new(x, 1.1, z), Color = Color3.fromRGB(20, 20, 20) })
		end
	end
	for _, x in { -1.9, 1.9 } do
		part({ Name = "Headlight", Size = Vector3.new(1, 0.5, 0.2), CFrame = cf * CFrame.new(x, 2, -5.55), Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon })
		part({ Name = "Taillight", Size = Vector3.new(1, 0.5, 0.2), CFrame = cf * CFrame.new(x, 2, 5.55), Color = Color3.fromRGB(200, 20, 20), Material = Enum.Material.Neon })
	end
end

local function fence(from: Vector3, to: Vector3, gapAt: number?)
	local dir = to - from
	local len = dir.Magnitude
	local n = math.floor(len / 4)
	local iron = Color3.fromRGB(25, 25, 28)
	for i = 0, n do
		local p = from + dir.Unit * (i * len / n)
		if not gapAt or math.abs(i - gapAt) > 1 then
			part({ Name = "FencePost", Size = Vector3.new(0.4, 5, 0.4), Position = p + Vector3.new(0, 2.5, 0), Color = iron, Material = Enum.Material.Metal })
			part({ ClassName = "WedgePart", Name = "FenceSpike", Size = Vector3.new(0.4, 0.8, 0.4), Position = p + Vector3.new(0, 5.4, 0), Color = iron, Material = Enum.Material.Metal })
		end
	end
	local cf = CFrame.lookAt((from + to) / 2, to)
	for _, y in { 1.2, 4.2 } do
		if gapAt then
			local gapPos = gapAt * len / n
			local a = gapPos - 4
			local b = len - gapPos - 4
			part({ Name = "FenceRail", Size = Vector3.new(0.2, 0.25, a), CFrame = CFrame.lookAt(from + dir.Unit * (a / 2), to) + Vector3.new(0, y, 0), Color = iron, Material = Enum.Material.Metal })
			part({ Name = "FenceRail", Size = Vector3.new(0.2, 0.25, b), CFrame = CFrame.lookAt(to - dir.Unit * (b / 2), to) + Vector3.new(0, y, 0), Color = iron, Material = Enum.Material.Metal })
		else
			part({ Name = "FenceRail", Size = Vector3.new(0.2, 0.25, len), CFrame = cf + Vector3.new(0, y, 0), Color = iron, Material = Enum.Material.Metal })
		end
	end
end

local function grave(pos: Vector3, style: number)
	local stone = Color3.fromRGB(110 + rng:NextInteger(-15, 15), 110, 115)
	local tilt = CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), math.rad(90), math.rad(rng:NextNumber(-6, 6)))
	if style == 1 then
		local s = part({ Name = "Tombstone", Size = Vector3.new(3, 4, 0.8), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * tilt, Color = stone, Material = Enum.Material.Slate })
		part({ Name = "TombTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 3, 3), CFrame = s.CFrame * CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(90), 0), Color = stone, Material = Enum.Material.Slate })
		signOn(s, Enum.NormalId.Front, "R.I.P", Color3.fromRGB(60, 60, 65))
	elseif style == 2 then
		local cf = CFrame.new(pos + Vector3.new(0, 2.5, 0)) * tilt
		part({ Name = "Cross", Size = Vector3.new(0.7, 5, 0.7), CFrame = cf, Color = stone, Material = Enum.Material.Slate })
		part({ Name = "Cross", Size = Vector3.new(3, 0.7, 0.7), CFrame = cf * CFrame.new(0, 1, 0), Color = stone, Material = Enum.Material.Slate })
	else
		part({ Name = "Tombstone", Size = Vector3.new(2.5, 2.5, 0.8), CFrame = CFrame.new(pos + Vector3.new(0, 1.25, 0)) * tilt, Color = stone, Material = Enum.Material.Slate })
	end
	part({ Name = "GraveMound", Size = Vector3.new(5, 0.6, 2.6), CFrame = CFrame.new(pos + Vector3.new(-3, 0.3, 0)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(70, 55, 40), Material = Enum.Material.Ground })
end

local function setupLighting()
	Lighting.ClockTime = 8
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(40, 40, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 90, 110)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.36
	atmo.Haze = 2
	atmo.Glare = 0.2
	atmo.Color = Color3.fromRGB(170, 175, 200)
	atmo.Decay = Color3.fromRGB(80, 70, 100)
	atmo.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.Name = "MoonSky"
	sky.MoonAngularSize = 11
	sky.StarCount = 4000
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local sun = Instance.new("SunRaysEffect")
	sun.Intensity = 0.08
	sun.Parent = Lighting
end

function MapBuilder.Build()
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "MoonlitFalls"
	mapFolder.Parent = workspace

	setupLighting()

	part({ Name = "Ground", Size = Vector3.new(800, 2, 800), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(55, 80, 45), Material = Enum.Material.Grass })

	-- Town square, roads, sidewalks
	part({ Name = "Square", Size = Vector3.new(70, 0.2, 70), Position = Vector3.new(0, 0.1, 0), Color = Color3.fromRGB(120, 115, 110), Material = Enum.Material.Cobblestone })
	part({ Name = "MainStreet", Size = Vector3.new(400, 0.15, 14), Position = Vector3.new(0, 0.08, 0), Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Asphalt })
	part({ Name = "CrossStreet", Size = Vector3.new(14, 0.15, 158), Position = Vector3.new(0, 0.08, -79), Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Asphalt })
	part({ Name = "FallsPath", Size = Vector3.new(8, 0.12, 170), Position = Vector3.new(0, 0.07, 120), Color = Color3.fromRGB(105, 85, 60), Material = Enum.Material.Ground })
	for x = -190, 190, 12 do
		if math.abs(x) > 38 then
			part({ Name = "RoadLine", Size = Vector3.new(5, 0.05, 0.4), Position = Vector3.new(x, 0.17, 0), Color = Color3.fromRGB(220, 200, 90), Material = Enum.Material.SmoothPlastic, CanCollide = false })
		end
	end
	for _, z in { -9, 9 } do
		part({ Name = "Sidewalk", Size = Vector3.new(400, 0.5, 4), Position = Vector3.new(0, 0.25, z), Color = Color3.fromRGB(150, 148, 140), Material = Enum.Material.Concrete })
	end

	-- Fountain with spray
	part({ Name = "FountainBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 16, 16), CFrame = CFrame.new(0, 1, 18) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 150, 155), Material = Enum.Material.Marble })
	part({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 14, 14), CFrame = CFrame.new(0, 2.05, 18) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 110, 160), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, Reflectance = 0.3 })
	part({ Name = "FountainPillar", Size = Vector3.new(2, 6, 2), Position = Vector3.new(0, 4, 18), Color = Color3.fromRGB(160, 160, 165), Material = Enum.Material.Marble })
	local bowl = part({ Name = "FountainBowl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 6, 6), CFrame = CFrame.new(0, 7, 18) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(160, 160, 165), Material = Enum.Material.Marble })
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Size = NumberSequence.new(0.4, 0.1)
	spray.Speed = NumberRange.new(6, 9)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -25, 0)
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Rate = 60
	spray.EmissionDirection = Enum.NormalId.Top
	local sprayAtt = Instance.new("Attachment")
	sprayAtt.Parent = bowl
	sprayAtt.WorldCFrame = CFrame.new(0, 7.5, 18)
	spray.Parent = sprayAtt
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		bench(CFrame.new(math.cos(a) * 24, 0, math.sin(a) * 24 + 4) * CFrame.Angles(0, -a - math.pi / 2, 0))
	end

	-- Clock tower with a real clock face (the client turns the hands).
	part({ Name = "ClockTower", Size = Vector3.new(10, 44, 10), Position = Vector3.new(0, 22, -22), Color = Color3.fromRGB(130, 90, 70), Material = Enum.Material.Brick })
	part({ Name = "TowerBand", Size = Vector3.new(11, 1, 11), Position = Vector3.new(0, 30, -22), Color = Color3.fromRGB(200, 195, 180) })
	part({ Name = "TowerTop", Size = Vector3.new(12, 2, 12), Position = Vector3.new(0, 45, -22), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Slate })
	part({ ClassName = "WedgePart", Name = "Spire", Size = Vector3.new(12, 10, 6), CFrame = CFrame.new(0, 51, -25), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Slate })
	part({ ClassName = "WedgePart", Name = "Spire", Size = Vector3.new(12, 10, 6), CFrame = CFrame.new(0, 51, -19) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Slate })
	local face = part({ Name = "ClockFace", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 7, 7), CFrame = CFrame.new(0, 37, -16.8) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(245, 235, 200), Material = Enum.Material.Neon })
	CollectionService:AddTag(face, "NightWindow")
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		part({ Name = "ClockTick", Size = Vector3.new(0.25, i % 3 == 0 and 0.9 or 0.5, 0.1), CFrame = CFrame.new(0, 37, -16.55) * CFrame.Angles(0, 0, -a) * CFrame.new(0, 2.9, 0), Color = Color3.fromRGB(20, 20, 20), CanCollide = false })
	end
	local clock = Instance.new("Model")
	clock.Name = "ClockHands"
	clock.Parent = mapFolder
	clock:SetAttribute("Center", Vector3.new(0, 37, -16.45))
	part({ Name = "HourHand", Size = Vector3.new(0.35, 1.9, 0.1), Position = Vector3.new(0, 37.9, -16.45), Color = Color3.fromRGB(15, 15, 15), CanCollide = false, Parent = clock })
	part({ Name = "MinuteHand", Size = Vector3.new(0.22, 2.8, 0.1), Position = Vector3.new(0, 38.4, -16.4), Color = Color3.fromRGB(15, 15, 15), CanCollide = false, Parent = clock })
	signOn(part({ Name = "TowerPlaque", Size = Vector3.new(8, 3, 0.3), Position = Vector3.new(0, 26, -16.8), Color = Color3.fromRGB(40, 30, 25) }), Enum.NormalId.Back, "MOONLIT FALLS · 1864")

	-- Town buildings around the square
	local grill = building("Moonlit Grill", Vector3.new(-48, 0, 50), math.pi, 32, 22, 14, Color3.fromRGB(120, 60, 45), Color3.fromRGB(40, 35, 35), "🍔 MOONLIT GRILL")
	for i = 0, 7 do
		addTo(grill, { Name = "Awning", Size = Vector3.new(30 / 8, 0.3, 4), CFrame = CFrame.new(-15 + 30 / 16 + i * 30 / 8, 11, 13) * CFrame.Angles(math.rad(-20), 0, 0), Color = i % 2 == 0 and Color3.fromRGB(170, 20, 30) or Color3.fromRGB(240, 235, 225), Material = Enum.Material.Fabric })
	end
	local lib = building("Old Library", Vector3.new(48, 0, 50), math.pi, 30, 22, 16, Color3.fromRGB(140, 130, 115), Color3.fromRGB(60, 50, 45), "📚 OLD LIBRARY")
	for _, x in { -12, -7, 7, 12 } do
		addTo(lib, { Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(15, 1.6, 1.6), CFrame = CFrame.new(x, 7.5, 13) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(225, 220, 210), Material = Enum.Material.Marble })
	end
	addTo(lib, { Name = "Portico", Size = Vector3.new(30, 1, 5), CFrame = CFrame.new(0, 15.5, 13), Color = Color3.fromRGB(225, 220, 210), Material = Enum.Material.Marble })
	building("Sheriff Office", Vector3.new(-48, 0, -55), 0, 28, 20, 13, Color3.fromRGB(150, 150, 140), Color3.fromRGB(30, 40, 60), "⭐ SHERIFF")
	car(CFrame.new(-28, 0, -40), Color3.fromRGB(240, 240, 240))
	part({ Name = "Siren", Size = Vector3.new(3, 0.5, 0.8), Position = Vector3.new(-28, 4.85, -39.5), Color = Color3.fromRGB(220, 30, 30), Material = Enum.Material.Neon })
	local school = building("Falls High School", Vector3.new(52, 0, -58), 0, 40, 24, 18, Color3.fromRGB(150, 70, 60), Color3.fromRGB(40, 40, 40), "🎓 FALLS HIGH")
	addTo(school, { Name = "Flagpole", Size = Vector3.new(0.4, 22, 0.4), CFrame = CFrame.new(-24, 11, 16), Color = Color3.fromRGB(200, 200, 200), Material = Enum.Material.Metal })
	addTo(school, { Name = "Flag", Size = Vector3.new(0.1, 3, 5), CFrame = CFrame.new(-24, 20.5, 18.6), Color = Color3.fromRGB(130, 20, 30), Material = Enum.Material.Fabric })
	car(CFrame.new(28, 0, -38) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(40, 60, 110))
	car(CFrame.new(-70, 0, 20) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(120, 25, 25))

	-- Ravencroft Boarding House: big old mansion with a porch.
	local house = building("Ravencroft Boarding House", Vector3.new(0, 0, -180), 0, 46, 30, 22, Color3.fromRGB(95, 85, 75), Color3.fromRGB(30, 25, 25), "🦇 RAVENCROFT HOUSE")
	addTo(house, { Name = "PorchFloor", Size = Vector3.new(30, 1, 7), CFrame = CFrame.new(0, 0.5, 18.5), Color = Color3.fromRGB(80, 60, 45), Material = Enum.Material.WoodPlanks })
	addTo(house, { Name = "PorchRoof", Size = Vector3.new(32, 0.8, 8), CFrame = CFrame.new(0, 11.5, 18.5), Color = Color3.fromRGB(30, 25, 25), Material = Enum.Material.Slate })
	for _, x in { -14, -7, 7, 14 } do
		addTo(house, { Name = "PorchColumn", Size = Vector3.new(1, 10.5, 1), CFrame = CFrame.new(x, 6, 21.5), Color = Color3.fromRGB(220, 215, 205), Material = Enum.Material.Wood })
	end
	car(CFrame.new(28, 0, -150) * CFrame.Angles(0, math.rad(15), 0), Color3.fromRGB(20, 20, 25))

	for _, p in { Vector3.new(-30, 0, -30), Vector3.new(30, 0, -30), Vector3.new(-30, 0, 30), Vector3.new(30, 0, 30), Vector3.new(-70, 0, 11), Vector3.new(70, 0, 11), Vector3.new(-120, 0, -11), Vector3.new(120, 0, -11), Vector3.new(9, 0, -110), Vector3.new(-9, 0, -150), Vector3.new(6, 0, 100) } do
		streetLamp(p)
	end

	-- Old cemetery (west) with an iron fence, graves, a crypt and an angel.
	local cx, cz = -150, 0
	part({ Name = "CemeteryGround", Size = Vector3.new(70, 0.2, 60), Position = Vector3.new(cx, 0.1, cz), Color = Color3.fromRGB(60, 65, 50), Material = Enum.Material.Ground })
	fence(Vector3.new(cx + 35, 0, cz - 30), Vector3.new(cx + 35, 0, cz + 30), 7)
	fence(Vector3.new(cx - 35, 0, cz - 30), Vector3.new(cx + 35, 0, cz - 30))
	fence(Vector3.new(cx - 35, 0, cz + 30), Vector3.new(cx + 35, 0, cz + 30))
	fence(Vector3.new(cx - 35, 0, cz - 30), Vector3.new(cx - 35, 0, cz + 30))
	for i = -2, 3 do
		for j = -2, 2 do
			if not (i == 0 and j == 0) then
				grave(Vector3.new(cx + i * 9, 0, cz + j * 10 + rng:NextNumber(-1, 1)), rng:NextInteger(1, 3))
			end
		end
	end
	part({ Name = "StatueBase", Size = Vector3.new(3, 3, 3), Position = Vector3.new(cx, 1.5, cz), Color = Color3.fromRGB(130, 130, 135), Material = Enum.Material.Marble })
	part({ Name = "Statue", Size = Vector3.new(1.6, 4, 1.2), Position = Vector3.new(cx, 5, cz), Color = Color3.fromRGB(170, 170, 175), Material = Enum.Material.Marble })
	part({ Name = "StatueHead", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Position = Vector3.new(cx, 7.6, cz), Color = Color3.fromRGB(170, 170, 175), Material = Enum.Material.Marble })
	for _, s in { -1, 1 } do
		part({ ClassName = "WedgePart", Name = "Wing", Size = Vector3.new(0.3, 4, 2.5), CFrame = CFrame.new(cx + s * 1.2, 6, cz + 0.8) * CFrame.Angles(0, 0, math.rad(s * 20)), Color = Color3.fromRGB(170, 170, 175), Material = Enum.Material.Marble })
	end
	building("Founders Crypt", Vector3.new(cx - 26, 0, cz), math.pi / 2, 14, 12, 10, Color3.fromRGB(90, 90, 95), Color3.fromRGB(50, 50, 55), "⚰ CRYPT")

	-- Vervain field (east, at the forest edge).
	local vervainPrompts = {}
	fence(Vector3.new(108, 0, 58), Vector3.new(108, 0, 102), 5)
	for i = 1, 12 do
		local pos = Vector3.new(130 + rng:NextNumber(-18, 18), 0, 80 + rng:NextNumber(-18, 18))
		local plant = part({ Name = "Vervain", Size = Vector3.new(1.4, 1.4, 1.4), Position = pos + Vector3.new(0, 2.2, 0), Color = Color3.fromRGB(150, 90, 210), Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, CanCollide = false })
		local stem = part({ Name = "VervainStem", Size = Vector3.new(0.3, 2, 0.3), Position = pos + Vector3.new(0, 1, 0), Color = Color3.fromRGB(50, 110, 50), CanCollide = false })
		stem:SetAttribute("PlantStem", true)
		for k = 1, 3 do
			local a = k * 2.1
			part({ Name = "VervainLeaf", Size = Vector3.new(0.9, 0.1, 0.4), CFrame = CFrame.new(pos + Vector3.new(0, 0.5 + k * 0.4, 0)) * CFrame.Angles(0, a, math.rad(25)) * CFrame.new(0.4, 0, 0), Color = Color3.fromRGB(60, 130, 60), CanCollide = false, Parent = plant })
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(170, 110, 255)
		glow.Range = 6
		glow.Brightness = 1
		glow.Parent = plant
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "เก็บเวอร์เวน"
		prompt.ObjectText = "🌿 Vervain"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 8
		prompt.Parent = plant
		table.insert(vervainPrompts, prompt)
	end
	local fieldSign = part({ Size = Vector3.new(10, 3, 0.4), Position = Vector3.new(105, 3, 80), Color = Color3.fromRGB(40, 25, 20), Material = Enum.Material.Wood })
	fieldSign.Orientation = Vector3.new(0, 90, 0)
	signOn(fieldSign, Enum.NormalId.Front, "🌿 VERVAIN FIELD")
	signOn(fieldSign, Enum.NormalId.Back, "🌿 VERVAIN FIELD")
	-- Old greenhouse shed next to the field
	building("Herb Shed", Vector3.new(165, 0, 50), math.pi, 14, 10, 9, Color3.fromRGB(110, 90, 70), Color3.fromRGB(50, 60, 50), nil)

	-- Witch ruins deep in the woods: a daylight ring for vampires.
	local wx, wz = -120, -220
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local h = rng:NextNumber(5, 9)
		part({ Name = "RuinStone", Size = Vector3.new(3, h, 3), CFrame = CFrame.new(wx + math.cos(a) * 14, h / 2, wz + math.sin(a) * 14) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), a, rng:NextNumber(-0.1, 0.1)), Color = Color3.fromRGB(85, 85, 90), Material = Enum.Material.Rock })
		if i % 2 == 0 then
			local candle = part({ Name = "Candle", Size = Vector3.new(0.4, 1, 0.4), Position = Vector3.new(wx + math.cos(a) * 9, 0.5, wz + math.sin(a) * 9), Color = Color3.fromRGB(240, 235, 220) })
			local flame = Instance.new("Fire")
			flame.Size = 1
			flame.Heat = 2
			flame.Parent = candle
		end
	end
	part({ Name = "RuneCircle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 20, 20), CFrame = CFrame.new(wx, 0.06, wz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 40, 110), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false })
	local altar = part({ Name = "Altar", Size = Vector3.new(6, 3, 4), Position = Vector3.new(wx, 1.5, wz), Color = Color3.fromRGB(70, 65, 70), Material = Enum.Material.Rock })
	local ring = part({ Name = "DaylightRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.4, 1.4), Position = Vector3.new(wx, 3.6, wz), Color = Color3.fromRGB(80, 140, 255), Material = Enum.Material.Neon, CanCollide = false })
	ring:SetAttribute("Spin", true)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(90, 150, 255)
	glow.Range = 18
	glow.Brightness = 3
	glow.Parent = ring
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(120, 170, 255)
	sparkle.Parent = ring
	local ringPrompt = Instance.new("ProximityPrompt")
	ringPrompt.ActionText = "สวมแหวนกันแดด"
	ringPrompt.ObjectText = "💍 Daylight Ring"
	ringPrompt.HoldDuration = 3
	ringPrompt.MaxActivationDistance = 10
	ringPrompt.Parent = altar
	local grimoire = part({ Name = "Grimoire", Size = Vector3.new(1.6, 0.4, 1.2), CFrame = CFrame.new(wx - 1.8, 3.2, wz) * CFrame.Angles(0, 0.4, 0), Color = Color3.fromRGB(70, 30, 25), Material = Enum.Material.Fabric })
	grimoire:SetAttribute("Book", true)
	signOn(part({ Size = Vector3.new(10, 3, 0.4), Position = Vector3.new(wx, 3, wz + 22), Color = Color3.fromRGB(40, 25, 20), Material = Enum.Material.Wood }), Enum.NormalId.Back, "🔮 WITCH RUINS")

	-- The falls (south): rock cliff, waterfall and a pond.
	local terrain = workspace.Terrain
	local fz = 230
	terrain:FillBlock(CFrame.new(0, 22, fz + 22), Vector3.new(140, 44, 30), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(-55, 14, fz + 4), Vector3.new(30, 28, 20), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(55, 14, fz + 4), Vector3.new(30, 28, 20), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(0, 1.5, fz - 6), Vector3.new(76, 3, 36), Enum.Material.Water)
	for i = -4, 4 do
		terrain:FillBall(Vector3.new(i * 9, 1, fz - 25 + math.abs(i) * 1.5), 4, Enum.Material.Rock)
	end
	local fall = part({ Name = "Waterfall", Size = Vector3.new(16, 42, 1), Position = Vector3.new(0, 21, fz + 6.5), Color = Color3.fromRGB(170, 205, 235), Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false, Reflectance = 0.2 })
	local foam = Instance.new("ParticleEmitter")
	foam.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	foam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	foam.Size = NumberSequence.new(3, 7)
	foam.Speed = NumberRange.new(4, 8)
	foam.SpreadAngle = Vector2.new(70, 70)
	foam.Lifetime = NumberRange.new(1.5, 2.5)
	foam.Rate = 40
	foam.EmissionDirection = Enum.NormalId.Top
	local foamAtt = Instance.new("Attachment")
	foamAtt.Parent = fall
	foamAtt.WorldCFrame = CFrame.new(0, 2, fz + 4)
	foam.Parent = foamAtt
	local stream = Instance.new("ParticleEmitter")
	stream.Color = ColorSequence.new(Color3.fromRGB(210, 230, 255))
	stream.Transparency = NumberSequence.new(0.5, 0.9)
	stream.Size = NumberSequence.new(2, 3)
	stream.Speed = NumberRange.new(20, 26)
	stream.Acceleration = Vector3.new(0, -10, 0)
	stream.Lifetime = NumberRange.new(1.5, 1.8)
	stream.Rate = 50
	stream.EmissionDirection = Enum.NormalId.Bottom
	local streamAtt = Instance.new("Attachment")
	streamAtt.Parent = fall
	streamAtt.WorldCFrame = CFrame.new(0, 42, fz + 5)
	stream.Parent = streamAtt
	local fallSign = part({ Size = Vector3.new(12, 3, 0.4), Position = Vector3.new(14, 3, fz - 30), Color = Color3.fromRGB(40, 25, 20), Material = Enum.Material.Wood })
	signOn(fallSign, Enum.NormalId.Front, "🌊 MOONLIT FALLS")
	signOn(fallSign, Enum.NormalId.Back, "🌊 MOONLIT FALLS")

	-- Forest all around town, leaving clearings for the landmarks.
	local clearings = {
		{ Vector3.new(0, 0, 0), 115 },
		{ Vector3.new(cx, 0, cz), 50 },
		{ Vector3.new(140, 0, 70), 48 },
		{ Vector3.new(wx, 0, wz), 26 },
		{ Vector3.new(0, 0, -180), 40 },
		{ Vector3.new(0, 0, fz), 80 },
	}
	local placed = 0
	while placed < 240 do
		local pos = Vector3.new(rng:NextNumber(-380, 380), 0, rng:NextNumber(-380, 380))
		local ok = math.abs(pos.Z) > 14 and math.abs(pos.X) > 14 -- keep roads clear
		for _, c in clearings do
			if (pos - c[1]).Magnitude < c[2] then
				ok = false
				break
			end
		end
		if ok then
			if rng:NextNumber() < 0.55 then
				pine(pos)
			else
				oak(pos)
			end
			placed += 1
			if rng:NextNumber() < 0.3 then
				rock(pos + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)), rng:NextNumber(2, 5))
			end
		end
	end
	-- A few bushes and flower beds in town
	for _ = 1, 30 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(40, 100)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if math.abs(p.Z) > 14 and math.abs(p.X) > 10 then
			local s = rng:NextNumber(2.5, 4)
			part({ Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), Position = p + Vector3.new(0, s * 0.35, 0), Color = Color3.fromRGB(40, 85, 40), Material = Enum.Material.Grass })
		end
	end

	-- Invisible markers the client uses for ambience.
	local markers = Instance.new("Folder")
	markers.Name = "AmbienceMarkers"
	markers.Parent = mapFolder
	local function marker(name, pos)
		local m = Instance.new("Part")
		m.Name = name
		m.Anchored = true
		m.CanCollide = false
		m.CanQuery = false
		m.Transparency = 1
		m.Size = Vector3.new(1, 1, 1)
		m.Position = pos
		m.Parent = markers
	end
	marker("Cemetery", Vector3.new(cx, 0, cz))
	marker("BatRoost", Vector3.new(0, 48, -22))
	marker("Forest", Vector3.new(160, 0, -120))
	marker("Forest", Vector3.new(-200, 0, 150))
	marker("Forest", Vector3.new(wx, 0, wz))
	marker("Forest", Vector3.new(200, 0, 200))

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.Position = Vector3.new(0, 0.3, 6)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 3
	spawn.Parent = mapFolder

	local wanderPoints = {}
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(5, 80)
		table.insert(wanderPoints, Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
	end

	return {
		wanderPoints = wanderPoints,
		vervainPrompts = vervainPrompts,
		ringPrompt = ringPrompt,
	}
end

return MapBuilder
