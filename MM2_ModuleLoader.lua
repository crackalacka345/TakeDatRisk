-- MM2_ModuleLoader.lua
-- Controlled module loader: static scanner (CHECK CODE), vetting, sandbox, and the imported-module buttons in each category.
-- Loaded by MM2_Helper.lua (same pattern as MM2_Games.lua). Receives the hub's shared pieces as `D`.
return function(D)
local pages, settings, saveSettings, setStatus = D.pages, D.settings, D.saveSettings, D.setStatus
local makeButton, setToggleVisual, corner, mainFrame = D.makeButton, D.setToggleVisual, D.corner, D.mainFrame
local THEMES, TAB_NAMES = D.THEMES, D.TAB_NAMES
local COLOR_RED, COLOR_DIM, COLOR_GOLD, COLOR_TEXT, COLOR_GREEN = D.COLOR_RED, D.COLOR_DIM, D.COLOR_GOLD, D.COLOR_TEXT, D.COLOR_GREEN
local activeFont, activeThemeDef = D.getTheme()
local TweenService, HttpService = game:GetService("TweenService"), game:GetService("HttpService")

-- ============================
-- MODULE LOADER (controlled): vets, sandboxes and runs the modules added in the MODULES tab.
--   * the source is vetted once at ADD time and cached; clicking runs that cached copy (checksum verified)
--   * a static scan rejects dangerous APIs / obfuscation tricks
--   * the code runs in a whitelisted environment (no game/getgenv/loadstring/http/file access)
--   * if setfenv is unavailable nothing is run
--   NOTE: best-effort containment, not a perfect security boundary. Only add modules you trust.
-- ============================
;(function()
    local MAX_SRC = 120000
    local BLOCKED = { "loadstring", "getfenv", "setfenv", "getgenv", "getrenv", "getrawmetatable", "setrawmetatable",
        "hookfunction", "hookmetamethod", "newcclosure", "debug", "require", "HttpGet", "HttpPost", "request",
        "http_request", "HttpService", "MarketplaceService", "writefile", "readfile", "appendfile", "delfile",
        "makefolder", "listfiles", "isfile", "setclipboard", "queue_on_teleport", "TeleportService", "syn",
        "fluxus", "checkcaller", "rconsole", "_G", "shared", "_ENV", "getconnections", "firesignal",
        "FindFirstAncestor", "GetFullName", "CoreGui", "RobloxScriptSecurity", "OpenBrowserWindow", "OpenVideosFolder" }
    local ALLOWED_SERVICES = { Players = 1, RunService = 1, UserInputService = 1, TweenService = 1, Workspace = 1,
        Lighting = 1, ReplicatedStorage = 1, StarterGui = 1, Debris = 1, CollectionService = 1, SoundService = 1,
        ContextActionService = 1, TextService = 1, PathfindingService = 1 }

    local function checksum(src)
        local a, b = 1, 0
        for i = 1, #src do
            a = (a + src:byte(i)) % 65521
            b = (b + a) % 65521
        end
        return b * 65536 + a
    end

    local function validate(src)
        if type(src) ~= "string" or #src < 5 then return false, "empty file" end
        if #src > MAX_SRC then return false, "file too large (max " .. math.floor(MAX_SRC / 1000) .. " KB)" end
        if src:find("\0", 1, true) or src:sub(1, 4) == "\27Lua" then return false, "binary/bytecode not allowed" end
        for _, w in ipairs(BLOCKED) do
            if src:find("%f[%w_]" .. w .. "%f[^%w_]") then return false, "uses blocked API '" .. w .. "'" end
        end
        -- obfuscation tricks that could hide a blocked name
        if src:find("\\%d") or src:find("\\x") or src:find("\\u") then return false, "escaped strings not allowed" end
        if src:find("%f[%w_]char%f[^%w_]") then return false, "string.char not allowed" end
        if src:find("%[%s*[^%]\n]-%.%.") then return false, "computed index not allowed" end
        -- reading .Parent could walk up to the real DataModel (assigning it is fine)
        for pos in src:gmatch("%.Parent%f[^%w_]()") do
            local rest = src:sub(pos, pos + 12):match("^%s*(.-)$")
            if not (rest:sub(1, 1) == "=" and rest:sub(2, 2) ~= "=") then return false, "reading .Parent not allowed" end
        end
        local fn, err = loadstring(src, "=module")
        if not fn then return false, "syntax error: " .. tostring(err):sub(1, 80) end
        return true
    end

    local function copy(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end

    local function makeEnv(modName)
        local env = {}
        env.assert, env.error, env.ipairs, env.pairs, env.next, env.pcall, env.xpcall = assert, error, ipairs, pairs, next, pcall, xpcall
        env.select, env.tonumber, env.tostring, env.type, env.typeof, env.unpack = select, tonumber, tostring, type, typeof, unpack
        env.rawequal, env.print, env.warn, env.tick, env.time, env.task = rawequal, print, warn, tick, time, task
        env.Instance, env.Enum, env.Vector2, env.Vector3, env.CFrame, env.Color3 = Instance, Enum, Vector2, Vector3, CFrame, Color3
        env.UDim, env.UDim2, env.TweenInfo, env.Ray, env.Random, env.BrickColor = UDim, UDim2, TweenInfo, Ray, Random, BrickColor
        env.NumberRange, env.NumberSequence, env.ColorSequence, env.Rect = NumberRange, NumberSequence, ColorSequence, Rect
        env.math, env.string, env.table = copy(math), copy(string), copy(table)
        env.os = { time = os.time, clock = os.clock, date = os.date }
        local services = {}
        local function getService(_, name)
            if type(name) ~= "string" or not ALLOWED_SERVICES[name] then
                error("service '" .. tostring(name) .. "' is not allowed for modules", 2)
            end
            return game:GetService(name)
        end
        env.game = setmetatable({ GetService = getService }, { __index = function(_, k)
            error("game." .. tostring(k) .. " is not allowed for modules", 2)
        end })
        env.hub = {
            name = modName,
            notify = function(text, color) getgenv().MM2HubNotify(tostring(text):sub(1, 120), color) end,
        }
        return env
    end

    local loaded = {} -- [module entry] = { api = table|nil, on = bool }

    local function nameOf(m)
        local n = tostring(m.path or "module"):match("([^/]+)$") or "module"
        return (n:gsub("%.module%.luau?$", ""):gsub("%.module$", ""))
    end

    -- runs (or toggles) a module; returns on/off state or nil, err
    local function activate(m)
        local st = loaded[m]
        if st and st.api and type(st.api.Disable) == "function" then
            if st.on then
                local ok, err = pcall(st.api.Disable)
                st.on = false
                if not ok then return nil, "Disable failed: " .. tostring(err) end
                return false
            end
            local ok, err = pcall(st.api.Enable or function() end)
            if not ok then return nil, "Enable failed: " .. tostring(err) end
            st.on = true
            return true
        end
        if type(setfenv) ~= "function" then return nil, "sandbox unavailable (no setfenv) - module not run" end
        local src = m.source
        if type(src) ~= "string" or m.sum ~= checksum(src) then return nil, "stored module is missing or was altered - re-add it" end
        local ok, why = validate(src)
        if not ok then return nil, "Rejected: " .. tostring(why) end
        local fn, err = loadstring(src, "=" .. nameOf(m))
        if not fn then return nil, "syntax error" end
        setfenv(fn, makeEnv(nameOf(m)))
        local okRun, res = pcall(fn)
        if not okRun then return nil, "Module error: " .. tostring(res):sub(1, 100) end
        if type(res) == "function" then
            local okF, e2 = pcall(res)
            if not okF then return nil, "Module error: " .. tostring(e2):sub(1, 100) end
            loaded[m] = { on = false }
            return true
        elseif type(res) == "table" and (type(res.Enable) == "function" or type(res.Disable) == "function") then
            local okE, e3 = pcall(res.Enable or function() end)
            if not okE then return nil, "Enable failed: " .. tostring(e3):sub(1, 100) end
            loaded[m] = { api = res, on = true }
            return true
        end
        loaded[m] = { on = false }
        return true
    end

    local function unload(m)
        local st = loaded[m]
        if st and st.on and st.api and type(st.api.Disable) == "function" then pcall(st.api.Disable) end
        loaded[m] = nil
    end

    -- imported modules: shown as normal GUI buttons in an "IMPORTED MODULES" section placed
    -- BELOW the built-in content of their category page (built-in layout is never moved)
    local imported = {} -- [cat] = { header, buttons = {containers}, count }
    local function layoutCategory(cat)
        local page, set = pages[cat], imported[cat]
        if not set or #set.items == 0 then return end
        local bottom = 0
        for _, c in ipairs(page:GetChildren()) do
            if c:IsA("GuiObject") and c.Visible and not c:GetAttribute("MM2Imported") then
                local y
                if c.Position.Y.Scale == 0 and c.Size.Y.Scale == 0 then
                    y = c.Position.Y.Offset + c.Size.Y.Offset
                else
                    y = c.AbsolutePosition.Y - page.AbsolutePosition.Y + c.AbsoluteSize.Y
                    if page:IsA("ScrollingFrame") then y = y + page.CanvasPosition.Y end
                end
                if y > bottom then bottom = y end
            end
        end
        local y0 = bottom + 12
        set.header.Position = UDim2.fromOffset(2, y0)
        for i, box in ipairs(set.items) do
            box.Position = UDim2.new(0, 0, 0, y0 + 22 + (i - 1) * 50)
        end
        if page:IsA("ScrollingFrame") then
            if page:GetAttribute("MM2OrigCanvas") == nil then page:SetAttribute("MM2OrigCanvas", page.CanvasSize.Y.Offset) end
            page.CanvasSize = UDim2.new(0, 0, 0, math.max(page:GetAttribute("MM2OrigCanvas"), y0 + 22 + #set.items * 50 + 6))
        end
    end

    local function refreshShelves()
        for cat, set in pairs(imported) do
            set.header:Destroy()
            for _, box in ipairs(set.items) do box:Destroy() end
            if set.conn then set.conn:Disconnect() end
            local page = pages[cat]
            local orig = page:GetAttribute("MM2OrigCanvas")
            if orig ~= nil and page:IsA("ScrollingFrame") then page.CanvasSize = UDim2.new(0, 0, 0, orig) end
        end
        imported = {}
        local mods = type(settings.customModules) == "table" and settings.customModules or {}
        for _, m in ipairs(mods) do
            local cat = m.category
            if type(cat) == "string" and pages[cat] and cat ~= "MODULES" and cat ~= "MY MODULES" then
                local page = pages[cat]
                local set = imported[cat]
                if not set then
                    local header = Instance.new("TextLabel")
                    header.Size = UDim2.new(1, -4, 0, 16)
                    header.BackgroundTransparency = 1
                    header.Text = "IMPORTED MODULES"
                    header.TextColor3 = COLOR_DIM
                    header.TextSize = 11
                    header.Font = activeFont
                    header.TextXAlignment = Enum.TextXAlignment.Left
                    header.ZIndex = 4
                    header:SetAttribute("MM2Imported", true)
                    header.Parent = page
                    set = { header = header, items = {} }
                    set.conn = page:GetPropertyChangedSignal("Visible"):Connect(function()
                        if page.Visible then layoutCategory(cat) end
                    end)
                    imported[cat] = set
                end
                local btn, stroke = makeButton(page, "◆ " .. nameOf(m), 0, THEMES.DEFAULT.accent)
                btn.Parent:SetAttribute("MM2Imported", true)
                table.insert(set.items, btn.Parent)
                getgenv().MM2HubClick(btn, "MouseButton1Click", function()
                    local state, err = activate(m)
                    if state == nil then
                        warn("MM2 Hub: " .. tostring(err))
                        setStatus(nameOf(m) .. ": " .. tostring(err), COLOR_RED)
                        return
                    end
                    setToggleVisual(stroke, state)
                    setStatus(nameOf(m) .. (state and " (ON)" or " (OFF)"), state and COLOR_GREEN or COLOR_DIM)
                end)
            end
        end
        for cat in pairs(imported) do
            layoutCategory(cat)
            task.delay(1.5, function() if imported[cat] then layoutCategory(cat) end end) -- after late-built content
        end
    end

    -- STATIC SCANNER (CHECK CODE): reads the text only, never runs it
    local RULES = {
        { "loadstring", 2, "exec", "Dynamic code execution (loadstring)" },
        { "%f[%w_]load%s*%(", 2, "exec", "Dynamic code execution (load)" },
        { "%f[%w_]require%s*%(%s*%d", 2, "exec", "Requires a remote asset by ID (can pull in hidden code)" },
        { "%f[%w_]getfenv", 1, "exec", "Reads/changes function environments" },
        { "%f[%w_]setfenv", 1, "exec", "Reads/changes function environments" },
        { "httpget", 2, "http", "HTTP download (external code/data)" },
        { "httppost", 2, "http", "HTTP POST (can send data out)" },
        { "requestasync", 2, "http", "HTTP request (can send data out)" },
        { "%f[%w_]http_request", 2, "http", "HTTP request (can send data out)" },
        { "%f[%w_]request%s*%(", 2, "http", "HTTP request (can send data out)" },
        { "websocket", 2, "http", "WebSocket connection (can send data out)" },
        { "httpservice", 1, "http", "Uses HttpService" },
        { "api/webhooks", 3, "http", "Discord webhook (common data-theft endpoint)" },
        { "ngrok", 3, "http", "Tunnel domain (ngrok) often used by attackers" },
        { "grabify", 3, "http", "IP-logger domain" },
        { "iplogger", 3, "http", "IP-logger domain" },
        { "pastebin%.com", 2, "http", "Downloads from a paste site" },
        { "hastebin", 2, "http", "Downloads from a paste site" },
        { "ipify", 2, "player", "Looks up the player's IP address" },
        { "raw%.githubusercontent%.com", 1, "http", "Fetches another external file" },
        { "%.userid", 1, "player", "Reads the player's UserId" },
        { "accountage", 1, "player", "Reads account age" },
        { "rbxanalyticsservice", 2, "player", "Accesses client/hardware identifiers" },
        { "gethwid", 3, "player", "Reads hardware ID" },
        { "hwid", 2, "player", "Mentions hardware ID" },
        { "clientid", 2, "player", "Reads a client identifier" },
        { "ipaddress", 2, "player", "Mentions IP address" },
        { "%f[%w_]email", 2, "player", "Mentions e-mail" },
        { "roblosecurity", 3, "cred", "Roblox session cookie (.ROBLOSECURITY)" },
        { "_|warning", 3, "cred", "Roblox cookie warning prefix" },
        { "x%-csrf", 3, "cred", "CSRF/session token handling" },
        { "cookie", 2, "cred", "Mentions cookies" },
        { "authorization", 2, "cred", "Mentions authorization headers" },
        { "password", 2, "cred", "Mentions passwords" },
        { "token", 1, "cred", "Mentions tokens" },
        { "fireserver", 1, "remote", "Fires a RemoteEvent (check what it sends)" },
        { "invokeserver", 1, "remote", "Invokes a RemoteFunction (check what it sends)" },
        { "hookmetamethod", 2, "remote", "Metamethod hook (can intercept/alter remotes)" },
        { "__namecall", 2, "remote", "__namecall hook (can intercept/alter remotes)" },
        { "hookfunction", 2, "remote", "Function hook" },
        { "getrawmetatable", 2, "remote", "Raw metatable access" },
        { "setreadonly", 2, "remote", "Unlocks read-only tables" },
        { "getconnections", 2, "remote", "Reads/disables event connections" },
        { "firesignal", 2, "remote", "Forces signals to fire" },
        { "getnilinstances", 1, "remote", "Enumerates hidden instances" },
        { "remotespy", 2, "remote", "Remote spy" },
        { "writefile", 2, "file", "Writes files" },
        { "appendfile", 2, "file", "Writes files" },
        { "readfile", 2, "file", "Reads files" },
        { "listfiles", 2, "file", "Lists files" },
        { "delfile", 2, "file", "Deletes files" },
        { "delfolder", 2, "file", "Deletes folders" },
        { "loadfile", 2, "file", "Loads code from a file" },
        { "dofile", 2, "file", "Runs code from a file" },
        { "makefolder", 1, "file", "Creates folders" },
        { "setclipboard", 1, "file", "Writes to the clipboard" },
        { "toclipboard", 1, "file", "Writes to the clipboard" },
        { "queue_on_teleport", 2, "file", "Runs code again after teleporting" },
        { "promptpurchase", 2, "misc", "Opens purchase prompts" },
        { "promptproductpurchase", 2, "misc", "Opens purchase prompts" },
        { "promptgamepasspurchase", 2, "misc", "Opens purchase prompts" },
        { "marketplaceservice", 1, "misc", "Uses MarketplaceService" },
        { "teleportservice", 1, "misc", "Uses TeleportService" },
        { "base64", 1, "obf", "Base64 handling (possible encoded payload)" },
        { "bxor", 1, "obf", "XOR operations (possible decoder)" },
        { "%f[%w_]_0x", 2, "obf", "Obfuscator-style names" },
        { ("[Il]"):rep(7), 2, "obf", "Obfuscator-style names (IIIlll...)", true },
        { ("[%w+/]"):rep(70), 2, "obf", "Very long encoded-looking string", true },
        { ("%x"):rep(60), 2, "obf", "Long hex blob (possible encoded payload)", true },
        { "\\x%x%x", 2, "obf", "Hex-escaped string (hides text)", true },
    }

    local function scan(src)
        local byLine, order, tags = {}, {}, {}
        local n = 0
        for line in (src .. "\n"):gmatch("(.-)\r?\n") do
            n = n + 1
            local low, sev, reasons = line:lower(), 0, {}
            for _, r in ipairs(RULES) do
                if (r[5] and line or low):find(r[1]) then
                    sev = math.max(sev, r[2])
                    table.insert(reasons, r[4])
                    tags[r[3]] = true
                end
            end
            local _, esc = line:gsub("\\%d%d?%d?", "")
            if esc >= 4 then sev = math.max(sev, 2); table.insert(reasons, "Many numeric escapes (hides text)"); tags.obf = true end
            if #line > 400 then sev = math.max(sev, 2); table.insert(reasons, "Very long line (minified/obfuscated?)"); tags.obf = true end
            if sev > 0 then
                table.insert(order, { line = n, sev = sev, text = line:gsub("^%s+", ""):sub(1, 110), reasons = reasons })
            end
        end
        local summary = {}
        if tags.exec and tags.http then table.insert(summary, "Downloads from the web AND executes code dynamically: possible remote code execution") end
        if tags.http and tags.player then table.insert(summary, "Reads player/identity info AND makes web requests: possible data exfiltration") end
        if tags.http and tags.cred then table.insert(summary, "Touches credentials/tokens AND makes web requests: possible credential theft") end
        if tags.obf and (tags.exec or tags.http) then table.insert(summary, "Obfuscated/encoded content combined with execution or web access: possible hidden payload") end
        local strong = #summary
        local sev2 = 0
        for _, f in ipairs(order) do
            if f.sev >= 3 then strong = strong + 1 elseif f.sev == 2 then sev2 = sev2 + 1 end
        end
        local verdict = (strong > 0 or sev2 >= 4) and "DANGEROUS" or ((#order > 0) and "WARNING" or "SAFE")
        return { verdict = verdict, findings = order, summary = summary, lines = n }
    end

    getgenv().MM2HubModules = { scan = scan, validate = validate, checksum = checksum, unload = unload, refreshShelves = refreshShelves }
    refreshShelves()
end)()

end
