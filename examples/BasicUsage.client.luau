--!strict

-- BlockText basic usage. Drop this in StarterPlayer > StarterPlayerScripts.
--
-- A word anchored to a part's Attachment, using a camera-facing preset, one morphing text transition, and
-- cleanup at the end. Client-side presentation only -- none of this replicates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BlockText = require(ReplicatedStorage.Packages.BlockText)

-- Any Attachment works as an anchor. This one is built locally so the sample runs in an empty place.
local sign = Instance.new("Part")
sign.Name = "BlockTextSign"
sign.Size = Vector3.new(2, 2, 2)
sign.Position = Vector3.new(0, 12, 0)
sign.Anchored = true
sign.CanCollide = false
sign.Transparency = 1
sign.Parent = Workspace

local attachment = Instance.new("Attachment")
attachment.Parent = sign

-- "Hologram" billboards the word to the camera, so it stays readable from any angle.
local handle = BlockText.Create(attachment, "HELLO", BlockText.Preset("Hologram", { CubeSize = 0.5 }))

task.wait(3)

-- The cubes already on screen fly out and reassemble as the new word, instead of the text cutting over.
handle:SetText("WORLD", "Scatter")

task.wait(3)

-- Move the anchor and the letters trail after it and settle: the follow is a world-space spring.
sign.Position += Vector3.new(0, 8, 0)

task.wait(3)

handle:Destroy()
sign:Destroy()
