--!strict

-- BlockText waypoint arrow. Drop this in StarterPlayer > StarterPlayerScripts.
--
-- An arrow floating above the player that keeps pointing at a fixed world destination however the player
-- moves. `Font.ARROW` points along the layout frame's local +X, and `FaceTarget` aims that +X at the target
-- every frame -- including the pitch, so the arrow tips up or down when the destination is above or below.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BlockText = require(ReplicatedStorage.Packages.BlockText)

local DESTINATION = Vector3.new(120, 8, -80)
local HEIGHT_ABOVE_HEAD = 6
local ARRIVAL_RADIUS = 12

local player = Players.LocalPlayer

-- A function anchor is polled every frame. Returning nil HOLDS the last frame instead of destroying the word,
-- so the arrow survives a respawn and re-anchors itself when the character comes back.
local function anchor(): CFrame?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return CFrame.new(root.Position + Vector3.new(0, HEIGHT_ABOVE_HEAD, 0))
end

local arrow = BlockText.Create(anchor, BlockText.Font.ARROW, {
	CubeSize = 0.45,
	Color = Color3.fromRGB(255, 210, 70),
	FloatHeight = 0.25,
	-- Polled every frame, so a moving destination works exactly the same way.
	FaceTarget = function()
		return DESTINATION
	end,
})

-- Retire the arrow on arrival. `SetFaceTarget(nil)` would instead stop the aiming and leave the word behind,
-- falling back to the anchor's own orientation.
local arrived: RBXScriptConnection
arrived = RunService.Heartbeat:Connect(function()
	local here = anchor()
	if here ~= nil and (here.Position - DESTINATION).Magnitude <= ARRIVAL_RADIUS then
		arrived:Disconnect()
		arrow:Destroy()
	end
end)
