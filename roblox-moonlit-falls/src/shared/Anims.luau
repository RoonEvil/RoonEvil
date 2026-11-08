-- Procedural animations. No uploaded assets needed: poses are joint angles
-- (degrees, X/Y/Z) applied on top of each R15 Motor6D's resting C0.
--
-- Joint axes on R15:  +X on a shoulder/hip swings the limb forward,
-- -X on Waist leans forward, -X on Neck looks down, +Z on RightShoulder lifts it sideways.
local Anims = {}

local GRAB = {
	Waist = { -30, 0, 0 },
	Neck = { -25, 0, 20 },
	RightShoulder = { 75, 0, 25 },
	LeftShoulder = { 75, 0, -25 },
	RightElbow = { 45, 0, 0 },
	LeftElbow = { 45, 0, 0 },
}
local COMPEL = {
	Waist = { -8, 0, 0 },
	Neck = { -6, 0, 0 },
	RightShoulder = { 95, 0, 8 },
	RightElbow = { 10, 0, 0 },
	LeftShoulder = { 10, 0, -10 },
}
local STAKE_DOWN = {
	RightShoulder = { 55, 0, -5 },
	RightElbow = { 5, 0, 0 },
	LeftShoulder = { 40, 0, -10 },
	Waist = { -25, 0, 0 },
}
local DASH = {
	Waist = { -35, 0, 0 },
	Neck = { 20, 0, 0 },
	RightShoulder = { -55, 0, 10 },
	LeftShoulder = { -55, 0, -10 },
	RightHip = { 25, 0, 0 },
	LeftHip = { -30, 0, 0 },
}
local VICTIM = {
	Neck = { 10, 0, -35 },
	Waist = { 12, 0, 0 },
	RightShoulder = { 35, 0, 45 },
	LeftShoulder = { 35, 0, -45 },
	RightKnee = { -15, 0, 0 },
	LeftKnee = { -15, 0, 0 },
}
local ROAR = {
	Waist = { 20, 0, 0 },
	Neck = { 35, 0, 0 },
	RightShoulder = { 30, 0, 80 },
	LeftShoulder = { 30, 0, -80 },
	RightElbow = { 60, 0, 0 },
	LeftElbow = { 60, 0, 0 },
}

-- One-shot clips: list of {time, pose}. Missing joints = rest.
Anims.Clips = {
	Bite = { length = 1.0, keys = { { 0, {} }, { 0.12, GRAB }, { 0.78, GRAB }, { 1.0, {} } } },
	Bitten = { length = 1.0, keys = { { 0, {} }, { 0.1, VICTIM }, { 0.8, VICTIM }, { 1.0, {} } } },
	Compel = { length = 1.4, keys = { { 0, {} }, { 0.2, COMPEL }, { 1.1, COMPEL }, { 1.4, {} } } },
	Stake = {
		length = 0.8,
		keys = {
			{ 0, {} },
			{ 0.25, { RightShoulder = { 170, 0, 10 }, RightElbow = { 35, 0, 0 }, Waist = { 12, 0, 0 } } },
			{ 0.38, STAKE_DOWN },
			{ 0.6, STAKE_DOWN },
			{ 0.8, {} },
		},
	},
	Throw = {
		length = 0.7,
		keys = {
			{ 0, {} },
			{ 0.2, { RightShoulder = { 150, 0, 35 }, Waist = { 0, 30, 0 }, LeftShoulder = { 40, 0, -20 } } },
			{ 0.35, { RightShoulder = { 45, 0, -10 }, Waist = { -12, -25, 0 } } },
			{ 0.7, {} },
		},
	},
	Claw = {
		length = 0.6,
		keys = {
			{ 0, {} },
			{ 0.15, { RightShoulder = { 130, 0, 60 }, LeftShoulder = { 130, 0, -60 }, Waist = { 12, 0, 0 } } },
			{ 0.3, { RightShoulder = { 40, 0, -25 }, LeftShoulder = { 40, 0, 25 }, Waist = { -30, 0, 0 } } },
			{ 0.6, {} },
		},
	},
	Dash = { length = 0.45, keys = { { 0, {} }, { 0.08, DASH }, { 0.32, DASH }, { 0.45, {} } } },
	Hit = { length = 0.4, keys = { { 0, {} }, { 0.07, { Waist = { 15, 0, 0 }, Neck = { 22, 0, 0 } } }, { 0.4, {} } } },
	Transform = {
		length = 1.8,
		keys = {
			{ 0, {} },
			{ 0.3, { Waist = { -45, 0, 0 }, Neck = { -30, 0, 0 }, RightShoulder = { 20, 0, 10 }, LeftShoulder = { 20, 0, -10 } } },
			{ 0.9, ROAR },
			{ 1.5, ROAR },
			{ 1.8, {} },
		},
	},
	Wave = {
		length = 1.6,
		keys = {
			{ 0, {} },
			{ 0.25, { RightShoulder = { 0, 0, 150 }, RightElbow = { 20, 0, 0 } } },
			{ 0.55, { RightShoulder = { 0, 0, 130 }, RightElbow = { 50, 0, 0 } } },
			{ 0.85, { RightShoulder = { 0, 0, 150 }, RightElbow = { 20, 0, 0 } } },
			{ 1.15, { RightShoulder = { 0, 0, 130 }, RightElbow = { 50, 0, 0 } } },
			{ 1.6, {} },
		},
	},
	Scream = {
		length = 1.0,
		keys = {
			{ 0, {} },
			{ 0.15, { Neck = { 15, 0, 0 }, RightShoulder = { 160, 0, 20 }, LeftShoulder = { 160, 0, -20 } } },
			{ 0.8, { Neck = { 15, 0, 0 }, RightShoulder = { 150, 0, 30 }, LeftShoulder = { 150, 0, -30 } } },
			{ 1.0, {} },
		},
	},
}

-- Looping layers, chosen every frame from the character's state.
Anims.Loops = {
	Stunned = function(t)
		return {
			Neck = { -30 + math.sin(t * 2) * 5, math.sin(t * 1.3) * 12, 0 },
			Waist = { -8, 0, math.sin(t * 1.7) * 6 },
			RightShoulder = { 5, 0, 6 },
			LeftShoulder = { 5, 0, -6 },
		}
	end,
	Burning = function(t)
		local s = math.sin(t * 30) * 5
		return {
			Neck = { -20 + s, 0, 0 },
			Waist = { -15, s, 0 },
			RightShoulder = { 135, 0, -35 },
			LeftShoulder = { 135, 0, 35 },
			RightElbow = { 95, 0, 0 },
			LeftElbow = { 95, 0, 0 },
		}
	end,
	-- Fallback walk for rigs with no animation tracks (townsfolk).
	Walk = function(t, speed)
		local f = t * (4 + speed * 0.35)
		local a = math.sin(f) * math.clamp(speed * 2.6, 0, 40)
		local k = math.clamp(speed * 2.2, 0, 35)
		return {
			RightShoulder = { -a, 0, 0 },
			LeftShoulder = { a, 0, 0 },
			RightElbow = { 15, 0, 0 },
			LeftElbow = { 15, 0, 0 },
			RightHip = { a, 0, 0 },
			LeftHip = { -a, 0, 0 },
			RightKnee = { -math.max(0, math.sin(f + 1.2)) * k, 0, 0 },
			LeftKnee = { -math.max(0, -math.sin(f + 1.2)) * k, 0, 0 },
			Waist = { -3, math.sin(f) * 4, 0 },
		}
	end,
	Idle = function(t)
		local b = math.sin(t * 1.6)
		return {
			Neck = { b * 2, math.sin(t * 0.37) * 10, 0 },
			RightShoulder = { 0, 0, 3 + b * 2 },
			LeftShoulder = { 0, 0, -3 - b * 2 },
		}
	end,
}

local function smooth(x)
	return x * x * (3 - 2 * x)
end

-- Pose of a clip at time t: { Joint = {x, y, z} }.
function Anims.Sample(clip, t: number)
	local keys = clip.keys
	for i = 1, #keys - 1 do
		local t0, p0 = keys[i][1], keys[i][2]
		local t1, p1 = keys[i + 1][1], keys[i + 1][2]
		if t >= t0 and t <= t1 then
			local a = smooth((t - t0) / math.max(t1 - t0, 1e-3))
			local out = {}
			for joint, v in p0 do
				local w = p1[joint] or { 0, 0, 0 }
				out[joint] = { v[1] + (w[1] - v[1]) * a, v[2] + (w[2] - v[2]) * a, v[3] + (w[3] - v[3]) * a }
			end
			for joint, w in p1 do
				if not out[joint] then
					out[joint] = { w[1] * a, w[2] * a, w[3] * a }
				end
			end
			return out
		end
	end
	return {}
end

-- Adds pose b into pose a (in place) with weight w.
function Anims.Add(a, b, w: number?)
	w = w or 1
	for joint, v in b do
		local cur = a[joint]
		if cur then
			cur[1] += v[1] * w
			cur[2] += v[2] * w
			cur[3] += v[3] * w
		else
			a[joint] = { v[1] * w, v[2] * w, v[3] * w }
		end
	end
	return a
end

return Anims
