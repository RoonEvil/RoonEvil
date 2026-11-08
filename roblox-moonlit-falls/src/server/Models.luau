-- Character models built from parts: werewolf body, vampire cape/eyes/fangs,
-- townsfolk hair and hats, and speech bubbles.
local Models = {}

local rng = Random.new()

local function cosmetic(props): BasePart
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- Welds `part` to `to` at an offset (in `to`'s space) and returns the weld.
local function weldAt(to: BasePart, part: BasePart, offset: CFrame, name: string?)
	part.CFrame = to.CFrame * offset
	local w = Instance.new("Weld")
	w.Name = name or "CosmeticWeld"
	w.Part0 = to
	w.Part1 = part
	w.C0 = offset
	w.Parent = part
	return w
end

local function glue(to: BasePart, part: BasePart)
	local wc = Instance.new("WeldConstraint")
	wc.Part0 = to
	wc.Part1 = part
	wc.Parent = part
end

---------------------------------------------------------------- speech bubble
function Models.Say(model: Model, text: string, color: Color3?)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("Speech")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Speech"
	bb.Size = UDim2.fromOffset(220, 50)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.MaxDistance = 70
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(250, 248, 240)
	label.BackgroundTransparency = 0.1
	label.TextColor3 = color or Color3.fromRGB(30, 25, 30)
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = label
	label.Parent = bb
	bb.Parent = head
	task.delay(3.5, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

---------------------------------------------------------------- townsfolk
local HAIR = {
	Color3.fromRGB(30, 22, 18), Color3.fromRGB(90, 60, 35), Color3.fromRGB(200, 170, 110),
	Color3.fromRGB(140, 60, 30), Color3.fromRGB(170, 170, 170),
}

function Models.DressTownsfolk(model: Model)
	local head = model:FindFirstChild("Head") :: BasePart
	if not head then
		return
	end
	local hs = head.Size
	local hair = HAIR[rng:NextInteger(1, #HAIR)]
	-- Hair cap and back.
	local cap = cosmetic({ Name = "Hair", Size = Vector3.new(hs.X * 1.08, hs.Y * 0.35, hs.Z * 1.08), Color = hair, Material = Enum.Material.SmoothPlastic, Parent = model })
	weldAt(head, cap, CFrame.new(0, hs.Y * 0.38, 0.03))
	local back = cosmetic({ Name = "HairBack", Size = Vector3.new(hs.X * 1.08, hs.Y * (rng:NextNumber() < 0.5 and 0.8 or 1.3), hs.Z * 0.3), Color = hair, Material = Enum.Material.SmoothPlastic, Parent = model })
	weldAt(head, back, CFrame.new(0, hs.Y * 0.05 - (back.Size.Y - hs.Y * 0.8) / 2, hs.Z * 0.42))

	local roll = rng:NextNumber()
	if roll < 0.3 then
		-- Fedora
		local brim = cosmetic({ ClassName = "Part", Name = "HatBrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, hs.X * 1.7, hs.X * 1.7), Color = Color3.fromRGB(40, 35, 30), Parent = model })
		weldAt(head, brim, CFrame.new(0, hs.Y * 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local top = cosmetic({ ClassName = "Part", Name = "HatTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(hs.Y * 0.55, hs.X * 1.05, hs.X * 1.05), Color = Color3.fromRGB(45, 40, 35), Parent = model })
		weldAt(head, top, CFrame.new(0, hs.Y * 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local band = cosmetic({ ClassName = "Part", Name = "HatBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, hs.X * 1.07, hs.X * 1.07), Color = Color3.fromRGB(120, 20, 30), Parent = model })
		weldAt(head, band, CFrame.new(0, hs.Y * 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)))
	elseif roll < 0.5 then
		-- Glasses
		for _, x in { -0.22, 0.22 } do
			local lens = cosmetic({ Name = "Lens", Size = Vector3.new(hs.X * 0.28, hs.Y * 0.18, 0.05), Color = Color3.fromRGB(20, 20, 20), Transparency = 0.3, Parent = model })
			weldAt(head, lens, CFrame.new(hs.X * x, hs.Y * 0.08, -hs.Z * 0.52))
		end
	end

	-- Scarf for some.
	local torso = model:FindFirstChild("UpperTorso") :: BasePart
	if torso and rng:NextNumber() < 0.4 then
		local ts = torso.Size
		local scarf = cosmetic({ Name = "Scarf", Size = Vector3.new(ts.X * 0.75, 0.35, ts.Z * 1.15), Color = Color3.fromHSV(rng:NextNumber(), 0.6, 0.6), Material = Enum.Material.Fabric, Parent = model })
		weldAt(torso, scarf, CFrame.new(0, ts.Y * 0.45, 0))
	end
end

---------------------------------------------------------------- vampires
function Models.DressVampire(char: Model)
	local head = char:FindFirstChild("Head") :: BasePart
	local torso = char:FindFirstChild("UpperTorso") :: BasePart
	if not head or not torso then
		return
	end
	-- Pale skin.
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Color = p.Color:Lerp(Color3.fromRGB(235, 230, 235), 0.3)
		end
	end
	local hs = head.Size
	-- Glowing red eyes and fangs: hidden until hunting (the client shows them).
	for _, x in { -0.2, 0.2 } do
		local eye = cosmetic({ Name = "VampEye", Size = Vector3.new(hs.X * 0.16, hs.Y * 0.08, 0.05), Color = Color3.fromRGB(255, 20, 40), Material = Enum.Material.Neon, Transparency = 1, Parent = char })
		weldAt(head, eye, CFrame.new(hs.X * x, hs.Y * 0.1, -hs.Z * 0.51))
	end
	for _, x in { -0.1, 0.1 } do
		local fang = cosmetic({ ClassName = "WedgePart", Name = "VampFang", Size = Vector3.new(0.08, hs.Y * 0.12, 0.05), Color = Color3.new(1, 1, 1), Transparency = 1, Parent = char })
		weldAt(head, fang, CFrame.new(hs.X * x, -hs.Y * 0.2, -hs.Z * 0.51) * CFrame.Angles(math.rad(180), 0, 0))
	end
	-- Cape: hangs from the shoulders, the client makes it flow.
	local ts = torso.Size
	local cape = cosmetic({ Name = "VampCape", Size = Vector3.new(ts.X * 1.15, ts.Y * 2.6, 0.12), Color = Color3.fromRGB(25, 5, 10), Material = Enum.Material.Fabric, Parent = char })
	local w = Instance.new("Weld")
	w.Name = "CapeWeld"
	w.Part0 = torso
	w.Part1 = cape
	w.C0 = CFrame.new(0, ts.Y * 0.48, ts.Z * 0.55)
	w.C1 = CFrame.new(0, cape.Size.Y / 2, 0)
	w.Parent = cape
	local lining = cosmetic({ Name = "CapeLining", Size = Vector3.new(cape.Size.X * 0.96, cape.Size.Y * 0.98, 0.05), Color = Color3.fromRGB(130, 0, 20), Material = Enum.Material.Fabric, Parent = char })
	lining.CFrame = cape.CFrame * CFrame.new(0, 0, -0.08)
	glue(cape, lining)
	local collar = cosmetic({ ClassName = "WedgePart", Name = "CapeCollar", Size = Vector3.new(ts.X * 1.2, ts.Y * 0.45, 0.35), Color = Color3.fromRGB(25, 5, 10), Material = Enum.Material.Fabric, Parent = char })
	weldAt(torso, collar, CFrame.new(0, ts.Y * 0.68, ts.Z * 0.45) * CFrame.Angles(0, math.rad(180), 0))
end

---------------------------------------------------------------- werewolves
local FUR = Color3.fromRGB(62, 52, 46)
local BELLY = Color3.fromRGB(110, 95, 80)

function Models.BuildWolf(char: Model)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or char:FindFirstChild("WolfBody") then
		return
	end
	-- Hide the human body (remember how it looked).
	for _, d in char:GetDescendants() do
		if (d:IsA("BasePart") and d ~= root) or d:IsA("Decal") then
			d:SetAttribute("OrigTransparency", d.Transparency)
			d.Transparency = 1
		end
	end

	local wolf = Instance.new("Model")
	wolf.Name = "WolfBody"
	wolf.Parent = char
	local g = -(hum.HipHeight + root.Size.Y / 2) -- ground level relative to the root

	local function piece(name, size, color, class)
		return cosmetic({ ClassName = class, Name = name, Size = size, Color = color, Material = Enum.Material.Fabric, Parent = wolf })
	end
	local function jointed(name, size, color, pivot: CFrame, centerFromPivot: Vector3)
		local p = piece(name, size, color)
		local w = Instance.new("Weld")
		w.Name = name .. "Joint"
		w.Part0 = root
		w.Part1 = p
		w.C0 = pivot
		w.C1 = CFrame.new(-centerFromPivot)
		w.Parent = p
		p.CFrame = root.CFrame * pivot * CFrame.new(centerFromPivot)
		return p
	end

	local body = jointed("Body", Vector3.new(2.8, 2.6, 5.8), FUR, CFrame.new(0, g + 3.6, 0.4), Vector3.zero)
	local chest = piece("Chest", Vector3.new(3.1, 3.0, 2.3), FUR)
	chest.CFrame = body.CFrame * CFrame.new(0, 0.3, -2.3)
	glue(body, chest)
	local belly = piece("Belly", Vector3.new(2.2, 0.4, 4.2), BELLY)
	belly.CFrame = body.CFrame * CFrame.new(0, -1.3, 0)
	glue(body, belly)
	-- Hunched shoulders / mane
	local mane = piece("Mane", Vector3.new(2.6, 1.2, 2.6), Color3.fromRGB(45, 38, 34))
	mane.CFrame = body.CFrame * CFrame.new(0, 1.5, -1.8) * CFrame.Angles(math.rad(-15), 0, 0)
	glue(body, mane)

	local head = jointed("Head", Vector3.new(2.2, 2.0, 2.3), FUR, CFrame.new(0, g + 4.7, -2.6), Vector3.new(0, 0.4, -1.1))
	local snout = piece("Snout", Vector3.new(1.3, 1.0, 1.8), BELLY)
	snout.CFrame = head.CFrame * CFrame.new(0, -0.35, -1.85)
	glue(head, snout)
	local jaw = piece("Jaw", Vector3.new(1.1, 0.35, 1.5), Color3.fromRGB(80, 30, 30))
	jaw.CFrame = head.CFrame * CFrame.new(0, -0.95, -1.7)
	glue(head, jaw)
	local nose = piece("Nose", Vector3.new(0.55, 0.4, 0.3), Color3.fromRGB(15, 12, 12))
	nose.CFrame = snout.CFrame * CFrame.new(0, 0.3, -0.95)
	glue(head, nose)
	for _, x in { -0.65, 0.65 } do
		local ear = piece("Ear", Vector3.new(0.5, 1.1, 0.7), FUR, "WedgePart")
		ear.CFrame = head.CFrame * CFrame.new(x, 1.5, 0.3)
		glue(head, ear)
		local eye = piece("Eye", Vector3.new(0.38, 0.22, 0.1), Color3.fromRGB(255, 200, 40))
		eye.Material = Enum.Material.Neon
		eye.CFrame = head.CFrame * CFrame.new(x * 0.75, 0.35, -1.16)
		glue(head, eye)
		for _, side in { -0.25, 0.25 } do
			local tooth = piece("Tooth", Vector3.new(0.12, 0.3, 0.12), Color3.new(1, 1, 1), "WedgePart")
			tooth.CFrame = head.CFrame * CFrame.new(x * 0.6 + side * 0.4, -0.95, -2.5) * CFrame.Angles(math.rad(180), 0, 0)
			glue(head, tooth)
		end
	end

	jointed("Tail", Vector3.new(0.7, 0.7, 3.0), FUR, CFrame.new(0, g + 4.3, 3.2) * CFrame.Angles(math.rad(-35), 0, 0), Vector3.new(0, 0, 1.5))

	for _, leg in {
		{ "LegFL", -0.95, -1.8 },
		{ "LegFR", 0.95, -1.8 },
		{ "LegBL", -0.95, 2.5 },
		{ "LegBR", 0.95, 2.5 },
	} do
		local l = jointed(leg[1], Vector3.new(0.95, 2.7, 1.0), FUR, CFrame.new(leg[2], g + 2.7, leg[3]), Vector3.new(0, -1.35, 0))
		local paw = piece("Paw", Vector3.new(1.05, 0.45, 1.3), Color3.fromRGB(35, 30, 28))
		paw.CFrame = l.CFrame * CFrame.new(0, -1.2, -0.15)
		glue(l, paw)
	end
end

function Models.RemoveWolf(char: Model)
	local wolf = char:FindFirstChild("WolfBody")
	if wolf then
		wolf:Destroy()
	end
	for _, d in char:GetDescendants() do
		local t = d:GetAttribute("OrigTransparency")
		if t ~= nil then
			d.Transparency = t
			d:SetAttribute("OrigTransparency", nil)
		end
	end
end

return Models
