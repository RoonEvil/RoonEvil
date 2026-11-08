-- Builds the whole town of Moonlit Falls out of parts, plus the lighting.
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

local rng = Random.new(1864)
local mapFolder: Folder

local function part(props)
	local p = Instance.new("Part")
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

-- Hollow building with a door. Built facing +Z, then rotated by `yaw`.
local function building(name, center: Vector3, yaw: number, w, d, h, wallColor: Color3, roofColor: Color3, signText: string?)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = mapFolder
	local t = 1
	local mid = Vector3.new(0, h / 2, 0)
	local doorW, doorH = 6, 9
	local sideW = (w - doorW) / 2

	local function wall(size, pos, mat)
		return part({
			Size = size,
			Position = pos,
			Color = wallColor,
			Material = mat or Enum.Material.Brick,
			Parent = model,
		})
	end

	wall(Vector3.new(w, h, t), mid + Vector3.new(0, 0, -d / 2))
	wall(Vector3.new(t, h, d), mid + Vector3.new(-w / 2, 0, 0))
	wall(Vector3.new(t, h, d), mid + Vector3.new(w / 2, 0, 0))
	wall(Vector3.new(sideW, h, t), mid + Vector3.new(-(doorW / 2 + sideW / 2), 0, d / 2))
	wall(Vector3.new(sideW, h, t), mid + Vector3.new(doorW / 2 + sideW / 2, 0, d / 2))
	wall(Vector3.new(doorW, h - doorH, t), Vector3.new(0, doorH + (h - doorH) / 2, d / 2))

	part({
		Name = "Roof",
		Size = Vector3.new(w + 3, 1.2, d + 3),
		Position = Vector3.new(0, h + 0.6, 0),
		Color = roofColor,
		Material = Enum.Material.Slate,
		Parent = model,
	})
	part({
		Name = "Floor",
		Size = Vector3.new(w - 1, 0.3, d - 1),
		Position = Vector3.new(0, 0.15, 0),
		Color = Color3.fromRGB(110, 75, 50),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	-- Warm light inside so it feels lived in at night.
	local lamp = part({
		Name = "Lamp",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, h - 1.5, 0),
		Color = Color3.fromRGB(255, 200, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Range = math.max(w, d)
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Parent = lamp

	if signText then
		local board = part({
			Name = "Sign",
			Size = Vector3.new(math.min(w - 4, 22), 3, 0.4),
			Position = Vector3.new(0, doorH + 2, d / 2 + 0.8),
			Color = Color3.fromRGB(40, 25, 20),
			Material = Enum.Material.Wood,
			Parent = model,
		})
		signOn(board, Enum.NormalId.Back, signText)
	end

	model.WorldPivot = CFrame.new()
	model:PivotTo(CFrame.new(center) * CFrame.Angles(0, yaw, 0))
	return model
end

local function tree(pos: Vector3)
	local h = rng:NextNumber(14, 26)
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, 2.2, 2.2),
		CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 50, 35),
		Material = Enum.Material.Wood,
	})
	local r = rng:NextNumber(10, 16)
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(r, r, r),
		Position = pos + Vector3.new(0, h, 0),
		Color = Color3.fromRGB(25 + rng:NextInteger(0, 20), 55 + rng:NextInteger(0, 25), 30),
		Material = Enum.Material.Grass,
	})
end

local function streetLamp(pos: Vector3)
	part({
		Size = Vector3.new(0.6, 12, 0.6),
		Position = pos + Vector3.new(0, 6, 0),
		Color = Color3.fromRGB(30, 30, 30),
		Material = Enum.Material.Metal,
	})
	local bulb = part({
		Size = Vector3.new(1.4, 1.4, 1.4),
		Position = pos + Vector3.new(0, 12.5, 0),
		Color = Color3.fromRGB(255, 220, 150),
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
	})
	local l = Instance.new("PointLight")
	l.Range = 24
	l.Brightness = 2
	l.Color = Color3.fromRGB(255, 210, 140)
	l.Parent = bulb
end

local function setupLighting()
	Lighting.ClockTime = 8
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(40, 40, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 90, 110)
	Lighting.GlobalShadows = true

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.38
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
end

function MapBuilder.Build()
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "MoonlitFalls"
	mapFolder.Parent = workspace

	setupLighting()

	-- Ground
	part({
		Name = "Ground",
		Size = Vector3.new(800, 2, 800),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(55, 80, 45),
		Material = Enum.Material.Grass,
	})

	-- Town square
	part({
		Name = "Square",
		Size = Vector3.new(70, 0.2, 70),
		Position = Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(120, 115, 110),
		Material = Enum.Material.Cobblestone,
	})
	-- Roads
	part({ Name = "MainStreet", Size = Vector3.new(400, 0.15, 14), Position = Vector3.new(0, 0.08, 0), Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Asphalt })
	part({ Name = "CrossStreet", Size = Vector3.new(14, 0.15, 300), Position = Vector3.new(0, 0.08, -60), Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Asphalt })

	-- Fountain in the square
	part({ Name = "FountainBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 16, 16), CFrame = CFrame.new(0, 1, 18) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 150, 155), Material = Enum.Material.Marble })
	local water = part({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 14, 14), CFrame = CFrame.new(0, 2.05, 18) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 110, 160), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	water.Reflectance = 0.3
	part({ Name = "FountainPillar", Size = Vector3.new(2, 6, 2), Position = Vector3.new(0, 4, 18), Color = Color3.fromRGB(160, 160, 165), Material = Enum.Material.Marble })

	-- Clock tower
	local tower = part({ Name = "ClockTower", Size = Vector3.new(10, 44, 10), Position = Vector3.new(0, 22, -22), Color = Color3.fromRGB(130, 90, 70), Material = Enum.Material.Brick })
	signOn(tower, Enum.NormalId.Back, "🕰\nMOONLIT FALLS\nest. 1864")
	part({ Name = "TowerTop", Size = Vector3.new(12, 2, 12), Position = Vector3.new(0, 45, -22), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Slate })

	-- Town buildings around the square
	building("Moonlit Grill", Vector3.new(-48, 0, 50), math.pi, 32, 22, 14, Color3.fromRGB(120, 60, 45), Color3.fromRGB(40, 35, 35), "🍔 MOONLIT GRILL")
	building("Old Library", Vector3.new(48, 0, 50), math.pi, 30, 22, 16, Color3.fromRGB(140, 130, 115), Color3.fromRGB(60, 50, 45), "📚 OLD LIBRARY")
	building("Sheriff Office", Vector3.new(-48, 0, -55), 0, 28, 20, 13, Color3.fromRGB(150, 150, 140), Color3.fromRGB(30, 40, 60), "⭐ SHERIFF")
	building("Falls High School", Vector3.new(52, 0, -58), 0, 40, 24, 18, Color3.fromRGB(150, 70, 60), Color3.fromRGB(40, 40, 40), "🎓 FALLS HIGH")
	building("Ravencroft Boarding House", Vector3.new(0, 0, -180), 0, 46, 30, 22, Color3.fromRGB(95, 85, 75), Color3.fromRGB(30, 25, 25), "🦇 RAVENCROFT HOUSE")

	for _, p in { Vector3.new(-30, 0, -30), Vector3.new(30, 0, -30), Vector3.new(-30, 0, 30), Vector3.new(30, 0, 30), Vector3.new(-90, 0, 9), Vector3.new(90, 0, 9), Vector3.new(9, 0, -110) } do
		streetLamp(p)
	end

	-- Old cemetery (west)
	local cx, cz = -150, 0
	part({ Name = "CemeteryGround", Size = Vector3.new(70, 0.2, 60), Position = Vector3.new(cx, 0.1, cz), Color = Color3.fromRGB(60, 65, 50), Material = Enum.Material.Ground })
	for i = -3, 3 do
		for j = -2, 2 do
			local stone = part({
				Name = "Tombstone",
				Size = Vector3.new(3, rng:NextNumber(3, 5), 0.8),
				Position = Vector3.new(cx + i * 8, 2, cz + j * 10),
				Color = Color3.fromRGB(110, 110, 115),
				Material = Enum.Material.Slate,
			})
			stone.Orientation = Vector3.new(rng:NextNumber(-6, 6), 90, rng:NextNumber(-6, 6))
		end
	end
	local crypt = building("Founders Crypt", Vector3.new(cx - 28, 0, cz), math.pi / 2, 14, 12, 10, Color3.fromRGB(90, 90, 95), Color3.fromRGB(50, 50, 55), "⚰ CRYPT")
	crypt:SetAttribute("Shade", true)

	-- Vervain field (east, at the forest edge). Purple flowers with a pick-up prompt.
	local vervainPrompts = {}
	for i = 1, 10 do
		local pos = Vector3.new(130 + rng:NextNumber(-18, 18), 0, 80 + rng:NextNumber(-18, 18))
		local plant = part({
			Name = "Vervain",
			Size = Vector3.new(1.6, 2.2, 1.6),
			Position = pos + Vector3.new(0, 1.1, 0),
			Color = Color3.fromRGB(150, 90, 210),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
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

	-- Witch ruins deep in the woods: a daylight ring for vampires.
	local wx, wz = -120, -220
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part({
			Name = "RuinStone",
			Size = Vector3.new(3, rng:NextNumber(5, 9), 3),
			Position = Vector3.new(wx + math.cos(a) * 14, 3, wz + math.sin(a) * 14),
			Color = Color3.fromRGB(85, 85, 90),
			Material = Enum.Material.Rock,
		})
	end
	local altar = part({ Name = "Altar", Size = Vector3.new(6, 3, 4), Position = Vector3.new(wx, 1.5, wz), Color = Color3.fromRGB(70, 65, 70), Material = Enum.Material.Rock })
	local ring = part({
		Name = "DaylightRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 1.4, 1.4),
		Position = Vector3.new(wx, 3.4, wz),
		Color = Color3.fromRGB(80, 140, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(90, 150, 255)
	glow.Range = 18
	glow.Brightness = 3
	glow.Parent = ring
	local ringPrompt = Instance.new("ProximityPrompt")
	ringPrompt.ActionText = "สวมแหวนกันแดด"
	ringPrompt.ObjectText = "💍 Daylight Ring"
	ringPrompt.HoldDuration = 3
	ringPrompt.MaxActivationDistance = 10
	ringPrompt.Parent = altar
	local ruinSign = part({ Size = Vector3.new(10, 3, 0.4), Position = Vector3.new(wx, 3, wz + 22), Color = Color3.fromRGB(40, 25, 20), Material = Enum.Material.Wood })
	signOn(ruinSign, Enum.NormalId.Back, "🔮 WITCH RUINS")

	-- Forest all around town, leaving clearings for the landmarks.
	local clearings = {
		{ Vector3.new(0, 0, 0), 115 },
		{ Vector3.new(cx, 0, cz), 50 },
		{ Vector3.new(130, 0, 80), 30 },
		{ Vector3.new(wx, 0, wz), 26 },
		{ Vector3.new(0, 0, -180), 36 },
		{ Vector3.new(0, 0, -100), 14 },
	}
	local placed = 0
	while placed < 220 do
		local pos = Vector3.new(rng:NextNumber(-380, 380), 0, rng:NextNumber(-380, 380))
		local ok = math.abs(pos.Z) > 10 and math.abs(pos.X) > 10 -- keep roads clear
		for _, c in clearings do
			if (pos - c[1]).Magnitude < c[2] then
				ok = false
				break
			end
		end
		if ok then
			tree(pos)
			placed += 1
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.Position = Vector3.new(0, 0.3, 6)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 3
	spawn.Parent = mapFolder

	-- Where townsfolk like to walk.
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
