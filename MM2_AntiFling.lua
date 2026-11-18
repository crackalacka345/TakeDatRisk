-- MM2_AntiFling.lua
-- Standalone Anti Fling module for MM2 Helper.
--
-- Stops other players from launching you:
--   1) your own spin and launch speed are capped every physics step
--   2) other players' parts stop colliding with you on your client, so they can't push you
--
-- Usage:
--   local AF = loadstring(game:HttpGet(URL))()
--   AF.setEnabled(true)   -- turn on
--   AF.setEnabled(false)  -- turn off (restores everyone's collision)
--   AF.isEnabled()        -- true / false
--   AF.destroy()          -- same as setEnabled(false)

-- If an older copy is still running (re-executed script), shut it down first
do
    local old = getgenv and getgenv().MM2AntiFling
    if old and old.destroy then
        pcall(old.destroy)
    end
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MAX_SPEED = 120 -- studs/sec, high enough that normal falls are untouched
local MAX_SPIN = 6    -- rad/sec, a normal character never gets near this

local module = {}
local enabled = false
local stepConn = nil
local softened = setmetatable({}, { __mode = "k" }) -- parts whose CanCollide we turned off

local function restoreOthers()
    for part in pairs(softened) do
        if part.Parent then
            pcall(function() part.CanCollide = true end)
        end
        softened[part] = nil
    end
end

local function step()
    local lp = Players.LocalPlayer
    local myChar = lp and lp.Character

    -- 1) cap your own spin and launch speed
    if myChar then
        for _, part in ipairs(myChar:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.AssemblyAngularVelocity.Magnitude > MAX_SPIN then
                    part.AssemblyAngularVelocity = Vector3.zero
                end
                local lv = part.AssemblyLinearVelocity
                if lv.Magnitude > MAX_SPEED then
                    part.AssemblyLinearVelocity = lv.Unit * MAX_SPEED
                end
            end
        end
    end

    -- 2) other players stop colliding with you (client-side only)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            for _, part in ipairs(plr.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                    softened[part] = true
                end
            end
        end
    end
end

function module.setEnabled(value)
    value = value and true or false
    if value == enabled then return end
    enabled = value
    if enabled then
        stepConn = RunService.Stepped:Connect(step)
    else
        if stepConn then
            stepConn:Disconnect()
            stepConn = nil
        end
        restoreOthers()
    end
end

function module.isEnabled()
    return enabled
end

function module.destroy()
    module.setEnabled(false)
end

if getgenv then
    getgenv().MM2AntiFling = module
end

return module
