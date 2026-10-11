local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Wildbound")
local Config = require(shared:WaitForChild("Config"))

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local request = Instance.new("RemoteEvent")
request.Name = "Request"
request.Parent = remotes
local update = Instance.new("RemoteEvent")
update.Name = "Update"
update.Parent = remotes

local World = require(script.Parent:WaitForChild("World"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local GameService = require(script.Parent:WaitForChild("GameService"))
local RaidService = require(script.Parent:WaitForChild("RaidService"))
local service = GameService.Start(Config, World, PlayerData, { Request = request, Update = update })
RaidService.Start(Config, service, { Request = request, Update = update })
-- Publish remotes only after all handlers are listening, preventing a lost
-- first Sync from clients that load faster than the generated world.
remotes.Parent = shared
print("[Wildbound] Garden, sanctuary, and game services ready.")
