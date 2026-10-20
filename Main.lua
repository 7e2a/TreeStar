-- HorrorPlant AutoFarm - client executor script
-- Host this file at a raw HTTPS URL and set SCRIPT_URL below to that URL.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SCRIPT_URL = "https://raw.githubusercontent.com/7e2a/TreeStar/refs/heads/main/Main.lua" -- Set to the raw HTTPS URL of THIS file
local START_DELAY = 11
local TP_DELAY = 0.15
local TRIGGER_DELAY = 0.1
local REJOIN_DELAY = 1
local RETRY_DELAY = 10

if not game:IsLoaded() then game.Loaded:Wait() end

local function getPlayer()
    local p = Players.LocalPlayer
    while not p do
        task.wait(0.2)
        p = Players.LocalPlayer
    end
    return p
end

local function getRoot()
    local p = getPlayer()
    local character = p.Character
    while not character or not character.Parent do
        task.wait(0.2)
        character = p.Character
    end
    return character:WaitForChild("HumanoidRootPart", 15)
end

local function getPromptPosition(prompt)
    local parent = prompt.Parent
    if not parent then return nil end
    if parent:IsA("Attachment") then return parent.WorldPosition end
    if parent:IsA("BasePart") then return parent.Position end
    if parent:IsA("Model") then return parent:GetPivot().Position end
    return nil
end

local function harvestAll()
    local root = getRoot()
    if not root then
        warn("[AUTO] Root unavailable")
        return 0
    end
    if type(fireproximityprompt) ~= "function" then
        warn("[AUTO] fireproximityprompt is unavailable in this executor")
        return 0
    end
    local count = 0
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") and model.Name == "HorrorPlant" then
            for _, prompt in ipairs(model:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.Parent then
                    local position = getPromptPosition(prompt)
                    if position then
                        root.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
                        task.wait(TP_DELAY)
                        local ok, err = pcall(fireproximityprompt, prompt)
                        if ok then
                            count += 1
                            print("[AUTO] Trigger attempt:", prompt:GetFullName())
                        else
                            warn("[AUTO] Prompt error:", err)
                        end
                        task.wait(TRIGGER_DELAY)
                    end
                end
            end
        end
    end
    print("[AUTO] Trigger attempts:", count)
    return count
end

local function sellAll()
    local networking = ReplicatedStorage:WaitForChild("Networking", 10)
    local events = networking and networking:WaitForChild("Events", 10)
    local event = events and events:WaitForChild("HorrorGarden", 10)
    if not event or not event:IsA("RemoteEvent") then
        warn("[AUTO] Sell RemoteEvent unavailable")
        return
    end
    local ok, err = pcall(function() event:FireServer("sell") end)
    if ok then print("[AUTO] Sell request sent") else warn("[AUTO] Sell error:", err) end
end

local function queueNextRun()
    if SCRIPT_URL == "" then
        warn("[AUTO] Set SCRIPT_URL to the raw URL of this file for automatic restart")
        return
    end
    local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
    if type(queue) ~= "function" then
        warn("[AUTO] queue_on_teleport unavailable")
        return
    end
    local source = string.format("loadstring(game:HttpGet(%q))()", SCRIPT_URL)
    local ok, err = pcall(queue, source)
    if not ok then warn("[AUTO] Queue error:", err) end
end

local function rejoin()
    local p = getPlayer()
    queueNextRun()
    print("[AUTO] Attempting rejoin")
    -- The kick-first technique may disconnect before teleportation can occur.
    -- This follows the requested Infinite Yield-style behavior, but is not guaranteed.
    if #Players:GetPlayers() <= 1 then
        p:Kick("\nRejoining...")
        task.wait()
        TeleportService:Teleport(game.PlaceId, p)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, p)
    end
end

print("[AUTO] Loaded; waiting", START_DELAY, "seconds")
task.wait(START_DELAY)

while true do
    harvestAll()
    sellAll()
    task.wait(REJOIN_DELAY)
    local ok, err = pcall(rejoin)
    if not ok then warn("[AUTO] Rejoin failed:", err) end
    task.wait(RETRY_DELAY)
end
