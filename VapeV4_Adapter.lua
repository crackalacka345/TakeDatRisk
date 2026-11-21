-- VapeV4_Adapter.lua
-- Uses the REAL Vape V4 UI as a library (Vape's "Independent" mode, see the Vape wiki):
--   shared.VapeIndependent = true
--   local vape = loadstring(game:HttpGet(".../VapeV4ForRoblox/main/NewMainScript.lua", true))()
--   vape.Categories.Combat:CreateModule({ Name = ..., Function = function(on) end })
--   vape:Init()
--
-- This file turns the hub's WindUI-shaped calls into those Vape calls, so the hub code stays the same:
--   Window:Section({ Title })        -> one of Vape's own categories (Render, Combat, Blatant, Utility, World, Minigames)
--   Tab:Toggle({ Title, Callback })  -> a Vape module (click it to switch it on / off)
--   Tab:Slider(...) / Tab:Button(..) -> a Vape slider / button inside that module's settings
--
-- Usage:   local lib, err = loadstring(game:HttpGet(".../VapeV4_Adapter.lua"))().load()
--          lib is nil (and err says why) when Vape could not be loaded, so the caller can fall back.

local Adapter = {}

local VAPE_URL = "https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/NewMainScript.lua"
local PROFILE = "MM2Hub" -- Vape saves its settings under this name

-- which of Vape's own categories each hub section goes into (first one that exists wins)
local CATEGORY_CHOICES = {
    ESP = { "Render", "Utility" },
    Combat = { "Combat", "Blatant" },
    Player = { "Blatant", "Utility" },
    ["Auto Coin"] = { "World", "Utility" },
    Games = { "Minigames", "Inventory", "Utility" },
    Settings = { "Utility", "World" },
}
local CATEGORY_FALLBACK = { "Utility", "Combat", "Blatant", "Render", "World", "Inventory", "Minigames" }

local function safe(name, fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("Vape adapter: " .. tostring(name) .. " callback error: " .. tostring(err))
    end
end

local function usable(category)
    return type(category) == "table" and type(category.CreateModule) == "function"
end

local function pickCategory(vape, title)
    local cats = vape.Categories
    for _, name in ipairs(CATEGORY_CHOICES[title] or {}) do
        if usable(cats[name]) then return cats[name] end
    end
    for _, name in ipairs(CATEGORY_FALLBACK) do
        if usable(cats[name]) then return cats[name] end
    end
    for _, c in pairs(cats) do
        if usable(c) then return c end
    end
    return nil
end

local function build(vape)
    local Lib = {}
    local usedNames = {}

    -- Vape replaces a module that has the same name, so every name has to be unique
    local function uniqueName(name)
        name = tostring(name or "Module")
        local candidate, n = name, 1
        while usedNames[candidate] do
            n = n + 1
            candidate = name .. " " .. n
        end
        usedNames[candidate] = true
        return candidate
    end

    function Lib:Notify(cfg)
        cfg = cfg or {}
        pcall(function()
            vape:CreateNotification(tostring(cfg.Title or ""), tostring(cfg.Content or ""), tonumber(cfg.Duration) or 3)
        end)
    end

    function Lib:CreateWindow(opts)
        opts = opts or {}
        local Window = { _vape = vape, _alive = true, IsVape = true }

        -- Vape opens and closes with RightShift on its own. Only change it if another key was picked.
        local key = opts.ToggleKey
        if type(key) == "string" and key ~= "" and key ~= "RightShift" and type(vape.Keybind) == "table" then
            pcall(function() vape.Keybind = { key } end)
        end

        function Window:Section(cfg)
            cfg = cfg or {}
            local title = tostring(cfg.Title or "Section")
            local category = pickCategory(vape, title)
            local Section = {}

            function Section:Tab(tcfg)
                tcfg = tcfg or {}
                local Tab = {}
                local tabTitle = tostring(tcfg.Title or title)
                local holder = nil -- a plain module for sliders / buttons that have no toggle before them
                local owner = nil  -- the last toggle module made in this tab; sliders and buttons go inside it

                local function target()
                    if owner then return owner end
                    if not holder then
                        holder = category:CreateModule({
                            Name = uniqueName(tabTitle),
                            Function = function() end,
                            Tooltip = tabTitle .. " settings",
                        })
                    end
                    return holder
                end

                function Tab:Toggle(c)
                    c = c or {}
                    local text = tostring(c.Title or "Toggle")
                    local mod
                    mod = category:CreateModule({
                        Name = uniqueName(text),
                        Function = function(on)
                            safe(text, c.Callback, on and true or false)
                        end,
                        Tooltip = text,
                    })
                    owner = mod
                    if c.Value == true and not mod.Enabled then mod:Toggle() end
                    local api = {}
                    function api:Set(v)
                        v = v and true or false
                        if mod.Enabled ~= v then mod:Toggle() end
                    end
                    function api:Destroy() pcall(function() mod.Object:Destroy() end) end
                    return api
                end

                function Tab:Button(c)
                    c = c or {}
                    local text = tostring(c.Title or "Button")
                    target():CreateButton({
                        Name = text,
                        Function = function()
                            safe(text, c.Callback)
                        end,
                    })
                    return { Destroy = function() end }
                end

                function Tab:Slider(c)
                    c = c or {}
                    local text = tostring(c.Title or "Slider")
                    local v = type(c.Value) == "table" and c.Value or {}
                    local min = tonumber(v.Min) or 0
                    local max = tonumber(v.Max) or 100
                    if max <= min then max = min + 1 end
                    local step = tonumber(c.Step) or 1
                    local def = math.clamp(tonumber(v.Default) or min, min, max)
                    local slider = target():CreateSlider({
                        Name = text,
                        Min = min,
                        Max = max,
                        Default = def,
                        Decimal = step < 1 and math.floor(1 / step + 0.5) or nil,
                        Function = function(val)
                            safe(text, c.Callback, val)
                        end,
                    })
                    local api = {}
                    function api:Set(n)
                        pcall(function() slider:SetValue(n) end)
                    end
                    function api:Destroy() end
                    return api
                end

                return Tab
            end

            return Section
        end

        -- finishes the setup: loads Vape's saved settings and shows the "press RightShift" hint
        function Window:Init()
            local ok, err = pcall(function() vape:Init() end)
            if not ok then warn("Vape adapter: vape:Init failed: " .. tostring(err)) end
        end

        function Window:SetVisible() end -- Vape handles this itself (RightShift)
        function Window:Toggle() end

        function Window:Destroy()
            if not self._alive then return end
            self._alive = false
            pcall(function() vape:Uninject() end)
            pcall(function() if shared.vape == vape then shared.vape = nil end end)
        end

        return Window
    end

    return Lib
end

-- downloads and starts Vape in Independent mode; returns the library, or nil and the reason
function Adapter.load()
    if not (writefile and readfile and isfile and makefolder and isfolder and listfiles) then
        return nil, "this executor has no file functions, which Vape needs"
    end

    -- a copy that is still open from an earlier run is closed first
    pcall(function()
        if shared.vape and shared.vape.Uninject then shared.vape:Uninject() end
    end)
    pcall(function() shared.vape = nil end)

    shared.VapeIndependent = true
    local okGet, src = pcall(game.HttpGet, game, VAPE_URL, true)
    if not okGet or type(src) ~= "string" or #src < 100 then
        return nil, "couldn't download Vape"
    end
    local fn, err = loadstring(src)
    if not fn then
        return nil, "Vape's loader has a syntax error: " .. tostring(err)
    end
    local okRun, vape = pcall(fn)
    if not okRun or type(vape) ~= "table" or type(vape.Categories) ~= "table" then
        return nil, "Vape did not start: " .. tostring(vape)
    end
    pcall(function() vape.Place = PROFILE end)
    if not pickCategory(vape, "Combat") then
        return nil, "Vape started but has no categories to use"
    end
    return build(vape)
end

return Adapter
