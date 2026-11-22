-- MM2 Helper v3.19 (tabbed, seasonal themes, games)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

-- RUN GENERATION: the updater bumps this on every reload. Loops and connections
-- from an older copy see the number changed and stop by themselves.
local HUB_GEN = (getgenv().MM2HubGen or 0) + 1
getgenv().MM2HubGen = HUB_GEN
getgenv().MM2HubBind = function(signal, fn)
    local c
    c = signal:Connect(function(...)
        if HUB_GEN ~= getgenv().MM2HubGen then
            if c then c:Disconnect() end
            return
        end
        return fn(...)
    end)
    return c
end

-- BUTTON GUARD: if a button's handler errors, the button shuts down and says so when pressed
getgenv().MM2HubClick = function(obj, evName, fn)
    local broken = false
    return obj[evName]:Connect(function(...)
        if broken then
            if obj:IsA("TextButton") then
                obj.Text = "FUNCTION NOT WORKING, TRY REFRESHING"
                task.delay(2.5, function()
                    if obj.Parent and broken then obj.Text = "BROKEN" end
                end)
            end
            return
        end
        local ok, err = pcall(fn, ...)
        if not ok then
            broken = true
            warn("MM2 Hub button error: " .. tostring(err))
            if obj:IsA("TextButton") then obj.Text = "BROKEN" end
        end
    end)
end

for _, gui in pairs(playerGui:GetChildren()) do
    if gui.Name == "MM2_Helper_GUI" or gui.Name == "MM2Hub_StackGame" or gui.Name == "MM2Hub_Notify" then
        gui:Destroy()
    end
end

-- ============================
-- CONFIG
-- ============================
local SHOOT_OFFSET = 15 -- snippet's `shootOffset` (offset / 15 = 1)
local INVIS_DEPTH = 500
local REACH_MIN, REACH_MAX = 4, 30 -- Murder Reach size slider range (studs)
local COIN_SPEED = 50 -- studs per second for Auto Coin tween
local COIN_TIMEOUT = 2 -- seconds to wait for CoinCollected after arriving
local CONFIG_PATH = "MM2Hub_settings.json"

local COLOR_RED = Color3.fromRGB(220, 30, 60)
local COLOR_BLUE = Color3.fromRGB(30, 120, 255)
local COLOR_GOLD = Color3.fromRGB(255, 215, 0)
local COLOR_GREEN = Color3.fromRGB(80, 220, 120)
local COLOR_DIM = Color3.fromRGB(120, 120, 150)
local COLOR_TEXT = Color3.fromRGB(220, 220, 240)

local THEMES = {
    DEFAULT = {
        bg = Color3.fromRGB(10, 10, 15),
        accent = Color3.fromRGB(255, 60, 100),
        border = { Color3.fromRGB(255, 0, 128), Color3.fromRGB(0, 128, 255), Color3.fromRGB(128, 0, 255) },
        cycle = true,
        font = Enum.Font.GothamBold,
        deco = nil,
    },
    HALLOWEEN = {
        bg = Color3.fromRGB(14, 8, 18),
        accent = Color3.fromRGB(255, 120, 0),
        border = { Color3.fromRGB(255, 120, 0), Color3.fromRGB(120, 0, 200), Color3.fromRGB(60, 220, 90) },
        font = Enum.Font.Fondamento,
        deco = { emoji = "🦇", motion = "fly", rate = 0.9, minTime = 5, maxTime = 8, minSize = 16, maxSize = 26 },
    },
    THANKSGIVING = {
        bg = Color3.fromRGB(20, 12, 8),
        accent = Color3.fromRGB(210, 105, 30),
        border = { Color3.fromRGB(210, 105, 30), Color3.fromRGB(160, 82, 45), Color3.fromRGB(218, 165, 32) },
        font = Enum.Font.Merriweather,
        deco = { emoji = "🍂", motion = "fall", rate = 0.6, minTime = 5, maxTime = 8, minSize = 14, maxSize = 22 },
    },
    CHRISTMAS = {
        bg = Color3.fromRGB(8, 16, 12),
        accent = Color3.fromRGB(220, 40, 50),
        border = { Color3.fromRGB(220, 30, 40), Color3.fromRGB(20, 150, 70), Color3.fromRGB(255, 255, 255) },
        font = Enum.Font.FredokaOne,
        deco = { emoji = "❄️", motion = "fall", rate = 0.25, minTime = 6, maxTime = 10, minSize = 10, maxSize = 18 },
    },
    ["NEW YEAR"] = {
        bg = Color3.fromRGB(8, 8, 20),
        accent = Color3.fromRGB(255, 215, 0),
        border = { Color3.fromRGB(255, 215, 0), Color3.fromRGB(192, 192, 192), Color3.fromRGB(120, 0, 255) },
        font = Enum.Font.Bangers,
        deco = { emoji = "🎉", motion = "fall", rate = 0.8, minTime = 4, maxTime = 7, minSize = 12, maxSize = 18 },
    },
}

local THEME_ORDER = { "AUTO", "HALLOWEEN", "THANKSGIVING", "CHRISTMAS", "NEW YEAR", "DEFAULT" }
local FONT_ORDER = { "AUTO", "GOTHIC", "SPOOKY", "ROUND", "COMIC", "SERIF", "SCIFI" }
local FONT_CHOICES = {
    GOTHIC = Enum.Font.GothamBold,
    SPOOKY = Enum.Font.Fondamento,
    ROUND = Enum.Font.FredokaOne,
    COMIC = Enum.Font.Bangers,
    SERIF = Enum.Font.Merriweather,
    SCIFI = Enum.Font.SciFi,
}

-- ============================
-- SETTINGS (saved if the executor supports writefile)
-- ============================
local settings = { themeChoice = "AUTO", fontChoice = "AUTO", bgId = "" }
do
    local ok, data = pcall(function()
        if isfile and isfile(CONFIG_PATH) then
            return HttpService:JSONDecode(readfile(CONFIG_PATH))
        end
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            settings[k] = v
        end
    end
end

local function saveSettings()
    pcall(function()
        if writefile then
            writefile(CONFIG_PATH, HttpService:JSONEncode(settings))
        end
    end)
end

local function currentMonth()
    local ok, m = pcall(function()
        return DateTime.now():ToLocalTime().Month
    end)
    if ok and m then return m end
    local ok2, m2 = pcall(function()
        return os.date("*t").month
    end)
    return ok2 and m2 or 0
end

local function autoThemeKey()
    local m = currentMonth()
    if m == 10 then return "HALLOWEEN"
    elseif m == 11 then return "THANKSGIVING"
    elseif m == 12 then return "CHRISTMAS"
    elseif m == 1 then return "NEW YEAR"
    end
    return "DEFAULT"
end

local function currentThemeKey()
    if settings.themeChoice == "AUTO" or not THEMES[settings.themeChoice] then
        return autoThemeKey()
    end
    return settings.themeChoice
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local activeThemeDef = THEMES.DEFAULT
local activeFont = Enum.Font.GothamBold
local rgbCycle = true
local rgbColors = THEMES.DEFAULT.border
local applyAll -- defined after the UI

-- ============================
-- GUI SKELETON
-- ============================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MM2_Helper_GUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- LOADING SCREEN: blur + loading bar (bottom-right) + caption, removed once the window is ready
local loadingFinish
if getgenv().MM2HubBoot and type(getgenv().MM2HubBoot.finish) == "function" then
    loadingFinish = getgenv().MM2HubBoot.finish
else
do
    local blur = Instance.new("BlurEffect")
    blur.Name = "MM2Hub_Blur"
    blur.Size = 0
    blur.Parent = game:GetService("Lighting")
    TweenService:Create(blur, TweenInfo.new(0.4), { Size = 18 }):Play()

    local lg = Instance.new("ScreenGui")
    lg.Name = "MM2Hub_Loading"
    lg.ResetOnSpawn = false
    lg.DisplayOrder = 100
    lg.IgnoreGuiInset = true
    lg.Parent = playerGui

    local barBack = Instance.new("Frame")
    barBack.Size = UDim2.new(0, 220, 0, 10)
    barBack.AnchorPoint = Vector2.new(1, 1)
    barBack.Position = UDim2.new(1, -20, 1, -60)
    barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    barBack.BorderSizePixel = 0
    barBack.Parent = lg
    corner(barBack, 5)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(255, 60, 100)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBack
    corner(barFill, 5)

    local caption = Instance.new("TextLabel")
    caption.Size = UDim2.new(0, 220, 0, 22)
    caption.AnchorPoint = Vector2.new(1, 0)
    caption.Position = UDim2.new(1, -20, 1, -44)
    caption.BackgroundTransparency = 1
    caption.Text = "its cool, zurq"
    caption.TextColor3 = COLOR_TEXT
    caption.TextScaled = true
    caption.Font = Enum.Font.GothamBold
    caption.Parent = lg

    local LOAD_TIME = 2.5
    local progress, startT = 0, os.clock()
    local conn
    conn = getgenv().MM2HubBind(RunService.Heartbeat, function()
        progress = math.min(1, (os.clock() - startT) / LOAD_TIME)
        barFill.Size = UDim2.new(progress, 0, 1, 0)
    end)

    -- called at the end of the script: waits for the bar, then unblurs and shows the window
    loadingFinish = function(showMain)
        task.spawn(function()
            while progress < 1 do
                task.wait(0.05)
            end
            conn:Disconnect()
            TweenService:Create(caption, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
            TweenService:Create(barBack, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(barFill, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(blur, TweenInfo.new(0.5), { Size = 0 }):Play()
            task.wait(0.5)
            lg:Destroy()
            blur:Destroy()
            showMain()
        end)
    end
end
end

local rgbBorder = Instance.new("Frame")
rgbBorder.Size = UDim2.new(0, 316, 0, 478)
rgbBorder.Position = UDim2.new(0.5, -158, 0.2, -8)
rgbBorder.BackgroundColor3 = Color3.fromRGB(255, 0, 128)
rgbBorder.BorderSizePixel = 0
rgbBorder.Active = true
rgbBorder.Draggable = true
rgbBorder.ZIndex = 1
rgbBorder.Parent = screenGui
corner(rgbBorder, 13)
rgbBorder.Visible = false -- shown when the loading screen finishes

-- window scale: changed by the corner grips, animated by ANIMATED UI
local uiScale = Instance.new("UIScale")
uiScale.Scale = math.clamp(tonumber(settings.uiScale) or 1, 0.6, 1.6)
uiScale.Parent = rgbBorder

local rgbGrad = Instance.new("UIGradient")
rgbGrad.Parent = rgbBorder

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 308, 0, 470)
mainFrame.Position = UDim2.new(0, 4, 0, 4)
mainFrame.BackgroundColor3 = THEMES.DEFAULT.bg
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 2
mainFrame.Parent = rgbBorder
corner(mainFrame, 10)

local bgImage = Instance.new("ImageLabel")
bgImage.Size = UDim2.new(1, 0, 1, 0)
bgImage.BackgroundTransparency = 1
bgImage.ImageTransparency = 0.25
bgImage.ScaleType = Enum.ScaleType.Crop
bgImage.ZIndex = 1
bgImage.Parent = mainFrame

local decorLayer = Instance.new("Frame")
decorLayer.Size = UDim2.new(1, 0, 1, 0)
decorLayer.BackgroundTransparency = 1
decorLayer.ClipsDescendants = true
decorLayer.ZIndex = 1
decorLayer.Parent = mainFrame

-- HEADER
local headerBar = Instance.new("Frame")
headerBar.Size = UDim2.new(1, 0, 0, 48)
headerBar.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
headerBar.BackgroundTransparency = 0.1
headerBar.BorderSizePixel = 0
headerBar.ZIndex = 3
headerBar.Parent = mainFrame
corner(headerBar, 10)

local headerFill = Instance.new("Frame")
headerFill.Size = UDim2.new(1, 0, 0, 10)
headerFill.Position = UDim2.new(0, 0, 1, -10)
headerFill.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
headerFill.BackgroundTransparency = 0.1
headerFill.BorderSizePixel = 0
headerFill.ZIndex = 3
headerFill.Parent = headerBar

local accentDot = Instance.new("Frame")
accentDot.Size = UDim2.new(0, 6, 0, 6)
accentDot.Position = UDim2.new(0, 16, 0.5, -3)
accentDot.BackgroundColor3 = THEMES.DEFAULT.accent
accentDot.BorderSizePixel = 0
accentDot.ZIndex = 4
accentDot.Parent = headerBar
corner(accentDot, 3)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.Position = UDim2.new(0, 30, 0, 0)
title.BackgroundTransparency = 1
title.Text = "vv:2"
title.TextColor3 = COLOR_TEXT
title.TextScaled = true
title.Font = activeFont
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 4
title.Parent = headerBar

local versionBadge = Instance.new("TextLabel")
versionBadge.Size = UDim2.new(0, 40, 0, 18)
versionBadge.Position = UDim2.new(1, -50, 0.5, -9)
versionBadge.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
versionBadge.Text = "v3.19"
versionBadge.TextColor3 = COLOR_DIM
versionBadge.TextScaled = true
versionBadge.Font = activeFont
versionBadge.ZIndex = 4
versionBadge.Parent = headerBar
corner(versionBadge, 5)

-- NOTIFICATIONS: small toast in the bottom-right corner (VapeUI style):
--   "Module name (ON)" / "Module name (OFF)", fades out after 3 seconds
do
    for _, g in ipairs(playerGui:GetChildren()) do
        if g.Name == "MM2Hub_Notify" then g:Destroy() end
    end
    local NOTIFY_TIME = 3
    local host = Instance.new("ScreenGui")
    host.Name = "MM2Hub_Notify"
    host.ResetOnSpawn = false
    host.DisplayOrder = 150
    host.IgnoreGuiInset = true
    host.Parent = playerGui

    local list = Instance.new("Frame")
    list.AnchorPoint = Vector2.new(1, 1)
    list.Position = UDim2.new(1, -14, 1, -14)
    list.Size = UDim2.new(0, 260, 1, -28)
    list.BackgroundTransparency = 1
    list.Parent = host
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Padding = UDim.new(0, 6)
    layout.Parent = list

    local counter = 0
    local lastText, lastTime = nil, 0
    local ON_HEX, OFF_HEX = "#50dc78", "#ff5a5a"

    local function esc(t)
        return (tostring(t):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
    end

    -- "Auto Coin ON" / "Speed OFF" / "Auto Coin (ON)" -> name + state
    local function splitToggle(text)
        local name, state = string.match(text, "^(.-)%s*%(?(ON)%)?$")
        if not name then name, state = string.match(text, "^(.-)%s*%(?(OFF)%)?$") end
        if name and name ~= "" then return name, state end
        return nil
    end

    getgenv().MM2HubNotify = function(text, color)
        text = tostring(text or "")
        if text == "" then return end
        local now = os.clock()
        if text == lastText and now - lastTime < 0.4 then return end -- no double-fire spam
        lastText, lastTime = text, now

        local name, state = splitToggle(text)
        local accent = color or COLOR_DIM
        local rich
        if name then
            local hex = state == "ON" and ON_HEX or OFF_HEX
            accent = state == "ON" and COLOR_GREEN or COLOR_RED
            rich = esc(name) .. ' <font color="' .. hex .. '"><b>(' .. state .. ')</b></font>'
        else
            rich = esc(text)
        end

        counter = counter + 1
        local card = Instance.new("CanvasGroup")
        card.Size = UDim2.new(1, 0, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
        card.BorderSizePixel = 0
        card.GroupTransparency = 1
        card.LayoutOrder = counter
        card.Parent = list
        corner(card, 5)

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 3, 1, 0)
        bar.BackgroundColor3 = accent
        bar.BorderSizePixel = 0
        bar.Parent = card

        local lbl = Instance.new("TextLabel")
        lbl.Position = UDim2.fromOffset(3, 0)
        lbl.Size = UDim2.new(1, -3, 0, 0)
        lbl.AutomaticSize = Enum.AutomaticSize.Y
        lbl.BackgroundTransparency = 1
        lbl.RichText = true
        lbl.Text = rich
        lbl.TextColor3 = COLOR_TEXT
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 15
        lbl.TextWrapped = true
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = card
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 12)
        pad.PaddingRight = UDim.new(0, 10)
        pad.PaddingTop = UDim.new(0, 10)
        pad.PaddingBottom = UDim.new(0, 12)
        pad.Parent = lbl

        local timer = Instance.new("Frame")
        timer.AnchorPoint = Vector2.new(0, 1)
        timer.Position = UDim2.new(0, 0, 1, 0)
        timer.Size = UDim2.new(1, 0, 0, 2)
        timer.BackgroundColor3 = accent
        timer.BorderSizePixel = 0
        timer.Parent = card

        TweenService:Create(card, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
        TweenService:Create(timer, TweenInfo.new(NOTIFY_TIME, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
        task.delay(NOTIFY_TIME, function()
            if not card.Parent then return end
            TweenService:Create(card, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
            task.wait(0.35)
            if card.Parent then card:Destroy() end
        end)
    end
end

-- PAGES + TABS
local TAB_NAMES = { "ESP", "COMBAT", "PLAYER", "GAMES", "MODULES", "MY MODULES", "SETTINGS", "UI" }
local tabButtons, pages = {}, {}

local function makePage(name, scroll)
    local page
    if scroll then
        page = Instance.new("ScrollingFrame")
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = activeThemeDef.accent
        page.CanvasSize = UDim2.new(0, 0, 0, 400)
        page.BorderSizePixel = 0
    else
        page = Instance.new("Frame")
        page.BorderSizePixel = 0
    end
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, -24, 1, -108)
    page.Position = UDim2.new(0, 12, 0, 96)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.ZIndex = 3
    page.Parent = mainFrame
    pages[name] = page
    return page
end

makePage("ESP", false)
makePage("COMBAT", true)
makePage("PLAYER", false)
makePage("GAMES", true)
makePage("MODULES", false)
makePage("MY MODULES", true)
makePage("SETTINGS", true)
makePage("UI", false)

local activeTab = "ESP"

local function setTab(name)
    activeTab = name
    local accent = activeThemeDef.accent
    for tabName, page in pairs(pages) do
        page.Visible = (tabName == name)
    end
    for tabName, tb in pairs(tabButtons) do
        local on = (tabName == name)
        tb.BackgroundColor3 = on and accent or Color3.fromRGB(24, 24, 36)
        tb.TextColor3 = on and Color3.new(1, 1, 1) or COLOR_DIM
    end
end

do -- (own scope: the file is close to Lua's 200 local variable limit)
local tabStrip = Instance.new("ScrollingFrame")
tabStrip.Size = UDim2.new(1, -16, 0, 38)
tabStrip.Position = UDim2.new(0, 8, 0, 54)
tabStrip.BackgroundTransparency = 1
tabStrip.BorderSizePixel = 0
tabStrip.ScrollBarThickness = 2
tabStrip.ScrollBarImageColor3 = activeThemeDef.accent
tabStrip.ScrollingDirection = Enum.ScrollingDirection.X
tabStrip.ZIndex = 4
tabStrip.Parent = mainFrame
tabStrip.InputChanged:Connect(function(input) -- mouse wheel scrolls the tabs sideways
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        tabStrip.CanvasPosition = Vector2.new(math.max(0, tabStrip.CanvasPosition.X - input.Position.Z * 60), 0)
    end
end)
local tabX = 2
for i, name in ipairs(TAB_NAMES) do
    local tb = Instance.new("TextButton")
    local w = #name * 8 + 20
    tb.Size = UDim2.fromOffset(w, 30)
    tb.Position = UDim2.fromOffset(tabX, 2)
    tabX = tabX + w + 4
    tb.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
    tb.BorderSizePixel = 0
    tb.AutoButtonColor = false
    tb.Text = name
    tb.TextColor3 = COLOR_DIM
    tb.TextSize = 14
    tb.Font = activeFont
    tb.ZIndex = 4
    tb.Parent = tabStrip
    corner(tb, 6)
    getgenv().MM2HubClick(tb, "MouseButton1Click", function()
        setTab(name)
    end)
    tabButtons[name] = tb
end
tabStrip.CanvasSize = UDim2.new(0, tabX, 0, 0)
end

local espPage, combatPage, playerPage, gamesPage, settingsPage =
    pages.ESP, pages.COMBAT, pages.PLAYER, pages.GAMES, pages.SETTINGS

-- ============================
-- HELPERS
-- ============================
local function setStatus(text, color)
    getgenv().MM2HubNotify(text, color)
end

local function setToggleVisual(stroke, on)
    TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = on and 0 or 0.5 }):Play()
end

local function makeButton(parent, text, yPos, bgColor)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 44)
    container.Position = UDim2.new(0, 0, 0, yPos)
    container.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
    container.BackgroundTransparency = 0.2
    container.BorderSizePixel = 0
    container.ZIndex = 3
    container.Parent = parent
    corner(container, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = bgColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.5
    stroke.Parent = container

    local colorBar = Instance.new("Frame")
    colorBar.Size = UDim2.new(0, 3, 0.7, 0)
    colorBar.Position = UDim2.new(0, 8, 0.15, 0)
    colorBar.BackgroundColor3 = bgColor
    colorBar.BorderSizePixel = 0
    colorBar.ZIndex = 4
    colorBar.Parent = container
    corner(colorBar, 2)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = text
    btn.TextColor3 = COLOR_TEXT
    btn.TextScaled = true
    btn.Font = activeFont
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 4
    btn.Parent = container

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 20)
    pad.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(34, 34, 52) }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = 0 }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(24, 24, 36) }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = 0.5 }):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.06), { BackgroundColor3 = bgColor }):Play()
        if settings.animatedUI then
            TweenService:Create(stroke, TweenInfo.new(0.06), { Thickness = 3.5 }):Play()
        end
    end)
    getgenv().MM2HubClick(btn, "MouseButton1Up", function()
        TweenService:Create(container, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(24, 24, 36) }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), { Thickness = 1.5 }):Play()
    end)

    return btn, stroke
end

local function hasToolMatching(plr, keyword)
    keyword = keyword:lower()
    local function search(container)
        if not container then return false end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find(keyword, 1, true) then
                return true
            end
        end
        return false
    end
    return search(plr.Character) or search(plr:FindFirstChildOfClass("Backpack"))
end

local function findPlayerByTool(keyword, excludeSelf)
    for _, plr in ipairs(Players:GetPlayers()) do
        if (not excludeSelf or plr ~= player) and hasToolMatching(plr, keyword) then
            return plr
        end
    end
    return nil
end

local function findMurderer()
    -- in an infection round there is no murderer: the zombies (knife holders) take that role
    if getgenv().MM2HubInfection and getgenv().MM2HubZombies then
        local zombies = getgenv().MM2HubZombies()
        return zombies[1]
    end
    return findPlayerByTool("knife", true)
end

local function findSheriffThatsNotMe()
    return findPlayerByTool("gun", true)
end

local function hasLocalGun()
    return hasToolMatching(player, "gun")
end

local function isDead(plr)
    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    return (not hum) or hum.Health <= 0
end

local function findOwnTool(keyword)
    local char = player.Character
    local function search(container)
        if not container then return nil end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find(keyword, 1, true) then
                return item
            end
        end
        return nil
    end
    return (char and search(char)) or search(player:FindFirstChildOfClass("Backpack"))
end

local function outlinePlayer(plr, on, color)
    local char = plr.Character
    if not char then return end
    local existing = char:FindFirstChild("OutlineHighlight")
    if existing then existing:Destroy() end
    if on then
        local hl = Instance.new("Highlight")
        hl.Name = "OutlineHighlight"
        hl.Adornee = char
        hl.FillColor = color or Color3.new(1, 0, 0)
        hl.FillTransparency = 0.7
        hl.OutlineColor = color or Color3.new(1, 1, 1)
        hl.OutlineTransparency = 0
        hl.Parent = char
    end
end

local function clearOutlines()
    for _, plr in ipairs(Players:GetPlayers()) do
        outlinePlayer(plr, false)
    end
end

local function clearBillboards()
    for _, plr in ipairs(Players:GetPlayers()) do
        local bb = plr.Character and plr.Character:FindFirstChild("MM2_RoleLabel")
        if bb then bb:Destroy() end
    end
end

local function addBillboard(plr, labelText, labelColor)
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "MM2_RoleLabel"
    bb.Size = UDim2.new(0, 120, 0, 34)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = hrp
    bb.Parent = plr.Character

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    bg.BackgroundTransparency = 0.25
    bg.BorderSizePixel = 0
    bg.Parent = bb
    corner(bg, 6)

    local stroke = Instance.new("UIStroke")
    stroke.Color = labelColor
    stroke.Thickness = 1.5
    stroke.Parent = bg

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = labelColor
    lbl.TextScaled = true
    lbl.Font = activeFont
    lbl.Parent = bg
end

-- ============================
-- SEASONAL DECORATIONS
-- ============================
local decorGen = 0

local function spawnDecorItem(deco, gen)
    if gen ~= decorGen then return end
    local size = math.random(deco.minSize, deco.maxSize)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = deco.emoji
    lbl.TextSize = size
    lbl.Size = UDim2.new(0, size * 1.5, 0, size * 1.5)
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.TextTransparency = 0.1
    lbl.Font = Enum.Font.SourceSans
    lbl.ZIndex = 1
    lbl.Parent = decorLayer

    local duration = math.random(deco.minTime * 10, deco.maxTime * 10) / 10
    local endPos, endRot
    if deco.motion == "fly" then
        local y = math.random(5, 85) / 100
        lbl.Position = UDim2.new(1.1, 0, y, 0)
        lbl.Rotation = -10
        endPos = UDim2.new(-0.2, 0, math.clamp(y + math.random(-8, 8) / 100, 0, 1), 0)
        endRot = 10
    else
        local x = math.random(0, 100) / 100
        lbl.Position = UDim2.new(x, 0, -0.1, 0)
        lbl.Rotation = math.random(0, 360)
        endPos = UDim2.new(math.clamp(x + math.random(-10, 10) / 100, 0, 1), 0, 1.1, 0)
        endRot = lbl.Rotation + 360
    end

    local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    TweenService:Create(lbl, info, { Position = endPos, Rotation = endRot }):Play()
    task.delay(duration, function()
        lbl:Destroy()
    end)
end

local function startDecor(deco)
    decorGen = decorGen + 1
    local gen = decorGen
    decorLayer:ClearAllChildren()
    if not deco then return end
    task.spawn(function()
        while gen == decorGen and HUB_GEN == getgenv().MM2HubGen do
            spawnDecorItem(deco, gen)
            task.wait(deco.rate)
        end
    end)
end

-- ROUND WATCH: LoadingMap tells us the gamemode, KillEvent tells us who died
do
    local killed = {} -- [Player] = true once a kill has been seen this round
    getgenv().MM2HubKilled = killed
    getgenv().MM2HubInfection = false
    local roundStartFns, roundEndFns = {}, {} -- other features register callbacks here
    getgenv().MM2HubRoundStartFns = roundStartFns
    getgenv().MM2HubRoundEndFns = roundEndFns

    local function toPlayer(v)
        if typeof(v) ~= "Instance" then return nil end
        if v:IsA("Player") then return v end
        return Players:GetPlayerFromCharacter(v)
    end

    local function hookKill(remote)
        if remote:IsA("RemoteEvent") then
            getgenv().MM2HubBind(remote.OnClientEvent, function(...)
                for _, arg in ipairs({ ... }) do
                    local p = toPlayer(arg)
                    if p then killed[p] = true end
                end
            end)
        end
    end

    local function hookLoading(remote)
        if remote:IsA("RemoteEvent") then
            getgenv().MM2HubBind(remote.OnClientEvent, function(mode)
                table.clear(killed) -- a new map means a new round
                local text = string.lower(tostring(mode or ""))
                getgenv().MM2HubInfection = string.find(text, "infection", 1, true) ~= nil
                if getgenv().MM2HubInfection then
                    setStatus("Infection mode: everyone with a knife is a ZOMBIE", COLOR_GREEN)
                end
                for _, f in ipairs(roundStartFns) do pcall(f) end
            end)
        end
    end

    local function scan(obj)
        if obj.Name == "KillEvent" then hookKill(obj) end
        if obj.Name == "LoadingMap" then hookLoading(obj) end
    end
    -- only ReplicatedStorage is scanned: walking the whole game on load causes the lag spike
    local replicated = game:GetService("ReplicatedStorage")
    for _, d in ipairs(replicated:GetDescendants()) do
        scan(d)
    end
    getgenv().MM2HubBind(replicated.DescendantAdded, scan)

    -- round end: Insight.RoundPlayed fires when a round finishes
    local insight = replicated:FindFirstChild("Insight")
    local played = insight and insight:FindFirstChild("RoundPlayed")
    if played and played:IsA("BindableEvent") then
        getgenv().MM2HubBind(played.Event, function()
            for _, f in ipairs(roundEndFns) do pcall(f) end
        end)
    end
end

do -- ZOMBIES (Infection): anyone holding a knife. Empty unless the map is Infection.
local function playerHasKnife(plr)
    local function has(container)
        if not container then return false end
        for _, t in ipairs(container:GetChildren()) do
            if t:IsA("Tool") and string.find(string.lower(t.Name), "knife", 1, true) then
                return true
            end
        end
        return false
    end
    return has(plr.Character) or has(plr:FindFirstChildOfClass("Backpack"))
end

getgenv().MM2HubZombies = function()
    local list = {}
    if not getgenv().MM2HubInfection then return list end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and playerHasKnife(plr) then
            table.insert(list, plr)
        end
    end
    return list
end
end

-- ============================
-- ESP TAB
-- ============================
local findMurderBtn = makeButton(espPage, "🔪 FIND MURDERER", 0, COLOR_RED)
local findSheriffBtn = makeButton(espPage, "🔫 FIND SHERIFF", 50, COLOR_BLUE)
local viewBothBtn, viewBothStroke = makeButton(espPage, "👁 VIEW BOTH", 100, Color3.fromRGB(180, 80, 255))
local seeAllBtn, seeAllStroke = makeButton(espPage, "◈ SEE ALL", 150, Color3.fromRGB(255, 200, 50))
local tracersBtn, tracersStroke = makeButton(espPage, "➳ TRACERS", 200, Color3.fromRGB(80, 220, 255))

getgenv().MM2HubClick(findMurderBtn, "MouseButton1Click", function()
    clearOutlines()
    local zombies = getgenv().MM2HubZombies()
    if #zombies > 0 then
        clearBillboards()
        for _, z in ipairs(zombies) do
            outlinePlayer(z, true, COLOR_GREEN)
            addBillboard(z, "🧟 ZOMBIE", COLOR_GREEN)
        end
        setStatus("🧟 " .. #zombies .. " ZOMBIE(s) (Infection)", COLOR_GREEN)
        return
    end
    local murderer = findMurderer()
    if murderer then
        outlinePlayer(murderer, true, COLOR_RED)
        setStatus("🔪 " .. murderer.DisplayName .. " is the MURDERER", COLOR_RED)
    else
        setStatus("No murderer found.")
    end
end)

getgenv().MM2HubClick(findSheriffBtn, "MouseButton1Click", function()
    clearOutlines()
    local sheriff = findSheriffThatsNotMe()
    if sheriff then
        outlinePlayer(sheriff, true, COLOR_BLUE)
        setStatus("🔫 " .. sheriff.DisplayName .. " is the SHERIFF", COLOR_BLUE)
    else
        setStatus("No sheriff found.")
    end
end)

-- VIEW BOTH: keeps itself up to date. When the sheriff or murderer changes
-- (or dies / respawns) the highlights and labels are redrawn.
local viewBothOn = false
local viewBothGen = 0
local lastMurd, lastSheriff = nil, nil

local function refreshViewBoth(force)
    local murderer = findMurderer()
    local sheriff = findSheriffThatsNotMe()
    local zombies = getgenv().MM2HubZombies()
    local lastZ = getgenv().MM2HubZombieList or {}
    local zombiesChanged = #zombies ~= #lastZ
    if not zombiesChanged then
        for i, z in ipairs(zombies) do
            if z ~= lastZ[i] then
                zombiesChanged = true
                break
            end
        end
    end
    getgenv().MM2HubZombieList = zombies

    local needsRedraw = force
        or zombiesChanged
        or murderer ~= lastMurd
        or sheriff ~= lastSheriff
        or (murderer and murderer.Character and not murderer.Character:FindFirstChild("OutlineHighlight"))
        or (sheriff and sheriff.Character and not sheriff.Character:FindFirstChild("OutlineHighlight"))
    if not needsRedraw then return end

    lastMurd, lastSheriff = murderer, sheriff
    clearOutlines()
    clearBillboards()

    local lines = {}
    if murderer then
        outlinePlayer(murderer, true, COLOR_RED)
        addBillboard(murderer, "⚔ MURDERER", COLOR_RED)
        table.insert(lines, "🔪 " .. murderer.DisplayName .. " = MURDERER")
    else
        table.insert(lines, "🔪 No murderer found")
    end
    if sheriff then
        outlinePlayer(sheriff, true, COLOR_BLUE)
        addBillboard(sheriff, "🛡 SHERIFF", COLOR_BLUE)
        table.insert(lines, "🔫 " .. sheriff.DisplayName .. " = SHERIFF")
    else
        table.insert(lines, "🔫 No sheriff found")
    end
        for _, z in ipairs(zombies) do
        outlinePlayer(z, true, COLOR_GREEN)
        addBillboard(z, "🧟 ZOMBIE", COLOR_GREEN)
        table.insert(lines, "🧟 " .. z.DisplayName .. " = ZOMBIE")
    end
    lines = nil -- redraws are silent now
end

getgenv().MM2HubClick(viewBothBtn, "MouseButton1Click", function()
    viewBothOn = not viewBothOn
    viewBothGen = viewBothGen + 1
    local gen = viewBothGen
    if not viewBothOn then
        clearOutlines()
        clearBillboards()
        lastMurd, lastSheriff = nil, nil
        viewBothBtn.Text = "👁 VIEW BOTH"
        setToggleVisual(viewBothStroke, false)
        setStatus("View Both OFF")
        return
    end
    viewBothBtn.Text = "👁 HIDE BOTH"
    setToggleVisual(viewBothStroke, true)
    setStatus("VIEW BOTH ON")
    lastMurd, lastSheriff = nil, nil
    refreshViewBoth(true)
    task.spawn(function()
        while viewBothOn and gen == viewBothGen and HUB_GEN == getgenv().MM2HubGen do
            task.wait(0.5)
            pcall(refreshViewBoth, false)
        end
    end)
end)

local seeAllOn = false
local seeAllGen = 0
do
    -- Red: Murderer (has the knife) | Blue: Sheriff (has the gun) | Green: Innocent
    local function roleOf(plr)
        if hasToolMatching(plr, "knife") then return "murderer", COLOR_RED end
        if hasToolMatching(plr, "gun") then return "sheriff", COLOR_BLUE end
        return "innocent", COLOR_GREEN
    end

    local applied = {} -- [Player] = { role = "...", char = Model }

    local function refreshSeeAll()
        for plr, info in pairs(applied) do
            if not plr.Parent then applied[plr] = nil end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local role, color = roleOf(plr)
                local info = applied[plr]
                local hl = plr.Character:FindFirstChild("OutlineHighlight")
                if not info or info.role ~= role or info.char ~= plr.Character or not hl then
                    outlinePlayer(plr, true, color)
                    applied[plr] = { role = role, char = plr.Character }
                end
            end
        end
    end

    getgenv().MM2HubClick(seeAllBtn, "MouseButton1Click", function()
        seeAllOn = not seeAllOn
        seeAllGen = seeAllGen + 1
        local gen = seeAllGen
        clearOutlines()
        table.clear(applied)
        if not seeAllOn then
            seeAllBtn.Text = "◈ SEE ALL"
            setToggleVisual(seeAllStroke, false)
            setStatus("SEE ALL OFF")
            return
        end
        seeAllBtn.Text = "◈ HIDE ALL"
        setToggleVisual(seeAllStroke, true)
        setStatus("SEE ALL ON")
        pcall(refreshSeeAll)
        task.spawn(function()
            -- keeps updating: whoever picks up the knife / gun changes colour live
            while seeAllOn and gen == seeAllGen and HUB_GEN == getgenv().MM2HubGen do
                task.wait(0.35)
                pcall(refreshSeeAll)
            end
        end)
    end)
end

-- TRACERS
local tracersOn = false
local tracers = {}

local function destroyTracer(plr)
    local t = tracers[plr]
    if t then
        if t.beam then t.beam:Destroy() end
        if t.a0 then t.a0:Destroy() end
        if t.a1 then t.a1:Destroy() end
        tracers[plr] = nil
    end
end

local function clearAllTracers()
    for plr in pairs(tracers) do
        destroyTracer(plr)
    end
end

local function getLivingHRP(plr)
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function tracerColorFor(plr)
    if hasToolMatching(plr, "knife") then return COLOR_RED end
    if hasToolMatching(plr, "gun") then return COLOR_BLUE end
    return Color3.fromRGB(230, 230, 230)
end

local function ensureTracer(plr)
    local myHRP = getLivingHRP(player)
    local theirHRP = getLivingHRP(plr)
    if not myHRP or not theirHRP then
        destroyTracer(plr)
        return
    end

    local t = tracers[plr]
    if t and t.a0.Parent == myHRP and t.a1.Parent == theirHRP then
        t.beam.Color = ColorSequence.new(tracerColorFor(plr))
        return
    end

    destroyTracer(plr)
    local a0 = Instance.new("Attachment")
    a0.Name = "MM2_TracerA0"
    a0.Parent = myHRP
    local a1 = Instance.new("Attachment")
    a1.Name = "MM2_TracerA1"
    a1.Parent = theirHRP

    local beam = Instance.new("Beam")
    beam.Name = "MM2_Tracer"
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Color = ColorSequence.new(tracerColorFor(plr))
    beam.Width0 = 0.12
    beam.Width1 = 0.12
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.Transparency = NumberSequence.new(0.2)
    beam.Parent = myHRP

    tracers[plr] = { beam = beam, a0 = a0, a1 = a1 }
end

local function refreshTracers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            ensureTracer(plr)
        end
    end
    for plr in pairs(tracers) do
        if plr.Parent ~= Players or plr == player then
            destroyTracer(plr)
        end
    end
end

task.spawn(function()
    while HUB_GEN == getgenv().MM2HubGen do
        task.wait(0.2)
        if tracersOn then
            pcall(refreshTracers)
        end
    end
end)

getgenv().MM2HubClick(tracersBtn, "MouseButton1Click", function()
    tracersOn = not tracersOn
    if tracersOn then
        tracersBtn.Text = "➳ HIDE TRACERS"
        setToggleVisual(tracersStroke, true)
        pcall(refreshTracers)
        setStatus("Tracers ON")
    else
        tracersBtn.Text = "➳ TRACERS"
        setToggleVisual(tracersStroke, false)
        clearAllTracers()
        setStatus("Tracers OFF")
    end
end)

-- ============================
-- COMBAT TAB
-- ============================
local toggleAimBtn, aimStroke = makeButton(combatPage, "◎ ENABLE AUTO AIM", 0, Color3.fromRGB(255, 60, 100))
local autoShootBtn, autoShootStroke = makeButton(combatPage, "🎯 AUTO SHOOT", 50, COLOR_BLUE)
local autoMurdWinBtn, murdWinStroke = makeButton(combatPage, "⚔ AUTO MURD WIN", 100, COLOR_RED)
local autoGunBtn, autoGunStroke = makeButton(combatPage, "🔫 AUTO GRAB GUN", 150, COLOR_BLUE)
local reachBtn, reachStroke = makeButton(combatPage, "📏 MURDER REACH", 200, Color3.fromRGB(0, 200, 180))

local scrollingFrame = Instance.new("ScrollingFrame")
scrollingFrame.Size = UDim2.new(1, 0, 0, 120)
scrollingFrame.Position = UDim2.new(0, 0, 0, 250)
scrollingFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
scrollingFrame.BackgroundTransparency = 0.2
scrollingFrame.BorderSizePixel = 0
scrollingFrame.ScrollBarThickness = 4
scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 60, 100)
scrollingFrame.ZIndex = 3
scrollingFrame.Parent = combatPage
corner(scrollingFrame, 8)
scrollingFrame.ClipsDescendants = true
scrollingFrame.Size = UDim2.new(1, 0, 0, 0)
scrollingFrame.Visible = false

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = scrollingFrame

local listPad = Instance.new("UIPadding")
listPad.PaddingLeft = UDim.new(0, 6)
listPad.PaddingRight = UDim.new(0, 6)
listPad.PaddingTop = UDim.new(0, 6)
listPad.Parent = scrollingFrame

local aimMode = settings.aimMode == "MURD" and "MURD" or "REGULAR" -- REGULAR or MURD (auto aim the knife holder)
local aimEnabled = false
local target = nil

-- AUTO AIM
-- Locks your camera onto the selected target every frame (PC crosshair and
-- mobile shiftlock both follow the camera). While you hold the Gun it fires
-- at the target about every 0.15s, through the Shoot remote, or GunFired if
-- the Shoot remote can't be found.
local BULLET_SPEED = 250 -- assumed bullet speed (studs/sec) used for aim prediction
local AIM_BIND = "MM2HubAutoAim"
local aimBound = false
local aimShotTimer = 0
local gunFiredRemote = nil

local function findGunFiredRemote()
    for _, obj in ipairs(game:GetDescendants()) do
        if obj.Name == "GunFired" and obj:IsA("RemoteEvent") then
            return obj
        end
    end
    return nil
end

local function aimEquipGun()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum then return nil end
    if not char:FindFirstChild("Gun") then
        local bp = (player:FindFirstChildOfClass("Backpack") and player:FindFirstChildOfClass("Backpack"):FindFirstChild("Gun"))
        if bp then
            hum:EquipTool(bp)
            task.wait(0.05)
        end
    end
    return char:FindFirstChild("Gun")
end

local function aimFire(pos)
    local gun = aimEquipGun()
    if not gun then return end

    -- the gun's Shoot remote (as GunClient uses it): origin CFrame + target CFrame
    local shoot = gun:FindFirstChild("Shoot")
    if shoot and shoot:IsA("RemoteEvent") then
        local char = player.Character
        local hrpNow = char and char:FindFirstChild("HumanoidRootPart")
        local att = hrpNow and hrpNow:FindFirstChild("GunRaycastAttachment")
        pcall(function()
            shoot:FireServer(att and att.WorldCFrame or nil, CFrame.new(pos))
        end)
        return
    end

    local remote = gun:FindFirstChild("KnifeLocal")
        and gun.KnifeLocal:FindFirstChild("CreateBeam")
        and gun.KnifeLocal.CreateBeam:FindFirstChild("RemoteFunction")
    if remote then
        pcall(function()
            remote:InvokeServer(1, pos, "AH2")
        end)
    else
        if not gunFiredRemote then
            gunFiredRemote = findGunFiredRemote()
        end
        if gunFiredRemote then
            pcall(function()
                gunFiredRemote:FireServer(pos)
            end)
        end
    end
end

-- a shot is only allowed when the target is close enough, above you, and not behind a wall
local function clearShotAt(tChar, tPos)
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not tChar then return false end
    local origin = camera.CFrame.Position
    local offset = tPos - origin
    if offset.Magnitude > (settings.aimRange or 90) then return false end
    if tPos.Y < myRoot.Position.Y - 6 then return false end -- underground / far below you
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { myChar, tChar }
    return workspace:Raycast(origin, offset, params) == nil
end

local function aimStep(dt)
    if not aimEnabled then return end
    if aimMode == "MURD" then
        target = findMurderer()
    end
    if not target then return end
    local tChar = target.Character
    local part = tChar and (tChar:FindFirstChild("Head") or tChar:FindFirstChild("HumanoidRootPart"))
    if not part then return end
    if isDead(target) then
        -- the target was shot: stop auto aim
        aimEnabled = false
        target = nil
        RunService:UnbindFromRenderStep(AIM_BIND)
        aimBound = false
        toggleAimBtn.Text = "◎ ENABLE AUTO AIM"
        setToggleVisual(aimStroke, false)
        setStatus("🎯 Target down, auto aim stopped", COLOR_GOLD)
        return
    end

    -- Predict where the target will be when the shot arrives (velocity * travel time)
    local hrp = tChar:FindFirstChild("HumanoidRootPart")
    local velocity = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
    local travelTime = (part.Position - camera.CFrame.Position).Magnitude / BULLET_SPEED
    local aimPos = part.Position + velocity * travelTime

    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, aimPos)

    if hasLocalGun() then
        aimShotTimer = aimShotTimer + dt
        if aimShotTimer >= 0.15 then
            aimShotTimer = 0
            if clearShotAt(tChar, part.Position) then
                aimFire(aimPos)
            end
        end
    end
end

local function setAimBound(on)
    if on and not aimBound then
        RunService:BindToRenderStep(AIM_BIND, Enum.RenderPriority.Camera.Value + 1, aimStep)
        aimBound = true
    elseif not on and aimBound then
        RunService:UnbindFromRenderStep(AIM_BIND)
        aimBound = false
    end
end

getgenv().MM2HubClick(toggleAimBtn, "MouseButton1Click", function()
    aimEnabled = not aimEnabled
    if aimEnabled then
        toggleAimBtn.Text = "◎ DISABLE AUTO AIM"
        setAimBound(true)
        if target then
            setStatus("◎ Locked on " .. target.DisplayName, Color3.fromRGB(255, 60, 100))
        else
            setStatus("◎ Aim on, pick a target below", Color3.fromRGB(255, 60, 100))
        end
    else
        toggleAimBtn.Text = "◎ ENABLE AUTO AIM"
        target = nil
        setAimBound(false)
        setStatus("AUTO AIM OFF")
    end
    setToggleVisual(aimStroke, aimEnabled)
    -- the target list slides down under the button when aim is on, and back up when off
    if aimEnabled then
        scrollingFrame.Visible = true
        TweenService:Create(scrollingFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 0, 120) }):Play()
    else
        TweenService:Create(scrollingFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 0, 0) }):Play()
        task.delay(0.26, function()
            if not aimEnabled then scrollingFrame.Visible = false end
        end)
    end
end)

local function createPlayerButton(plr)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.ZIndex = 4
    btn.Parent = scrollingFrame
    corner(btn, 6)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(40, 40, 60)
    btnStroke.Thickness = 1
    btnStroke.Parent = btn

    local thumb = Instance.new("ImageLabel")
    thumb.Size = UDim2.new(0, 28, 0, 28)
    thumb.Position = UDim2.new(0, 6, 0.5, -14)
    thumb.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
    thumb.BorderSizePixel = 0
    thumb.Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=100&h=100"
    thumb.ZIndex = 5
    thumb.Parent = btn
    corner(thumb, 4)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -50, 1, 0)
    nameLabel.Position = UDim2.new(0, 42, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = plr.DisplayName
    nameLabel.TextColor3 = COLOR_TEXT
    nameLabel.TextScaled = true
    nameLabel.Font = activeFont
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 5
    nameLabel.Parent = btn

    getgenv().MM2HubClick(btn, "MouseButton1Click", function()
        target = plr
        for _, v in ipairs(scrollingFrame:GetChildren()) do
            if v:IsA("TextButton") then
                local s = v:FindFirstChildOfClass("UIStroke")
                if s then
                    s.Color = (v == btn) and Color3.fromRGB(255, 60, 100) or Color3.fromRGB(40, 40, 60)
                    s.Thickness = (v == btn) and 1.5 or 1
                end
                TweenService:Create(v, TweenInfo.new(0.1), {
                    BackgroundColor3 = (v == btn) and Color3.fromRGB(35, 20, 40) or Color3.fromRGB(22, 22, 34)
                }):Play()
            end
        end
        setStatus("◎ Targeting: " .. plr.DisplayName, Color3.fromRGB(255, 60, 100))
    end)
end

local function updatePlayerList()
    for _, v in ipairs(scrollingFrame:GetChildren()) do
        if v:IsA("TextButton") then v:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then createPlayerButton(plr) end
    end
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 14)
end
getgenv().MM2HubBind(Players.PlayerAdded, updatePlayerList)
getgenv().MM2HubBind(Players.PlayerRemoving, updatePlayerList)
updatePlayerList()

-- AUTO SHOOT: a ring around the crosshair. When the murderer is inside the ring, in clear
-- line of sight, it fires at their predicted position (the ring turns green).
local autoShootOn = false
local shootLoopRunning = false

local function autoShootStep(canFire)
    local ringGui = playerGui:FindFirstChild("MM2Hub_ShootRing")
    local ring = ringGui and ringGui:FindFirstChild("Ring")
    local stroke = ring and ring:FindFirstChildOfClass("UIStroke")
    -- the circle follows the mouse cursor (the middle of the screen when the mouse is locked)
    local center = UserInputService:GetMouseLocation()
    if ring then
        ring.Position = UDim2.fromOffset(center.X, center.Y)
    end

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not hasLocalGun() then
        if stroke then stroke.Color = COLOR_DIM end
        return
    end

    local murderer = findMurderer()
    local tChar = murderer and murderer.Character
    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
    local head = tChar and tChar:FindFirstChild("Head")
    if not tRoot or not head or isDead(murderer) then
        if stroke then stroke.Color = COLOR_DIM end
        return
    end

    local screenPos = camera:WorldToViewportPoint(head.Position)
    local radius = settings.shootRing or 110
    local inside = screenPos.Z > 0 and (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude <= radius
    if stroke then
        stroke.Color = inside and COLOR_GREEN or COLOR_RED
    end
    if not inside or not clearShotAt(tChar, head.Position) then return end

    if canFire then
        local dist = (head.Position - camera.CFrame.Position).Magnitude
        local aim = math.clamp((settings.shootAim or 100) / 100, 0, 1)
        local lead = 0.5 + 0.5 * aim -- WEAK leads only half the way, STRONG the full way
        local spread = (1 - aim) * 3 -- WEAK adds a few studs of random miss, STRONG has none
        local predicted = head.Position + tRoot.AssemblyLinearVelocity * (dist / BULLET_SPEED) * lead
        if spread > 0 then
            predicted = predicted + Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1) * spread
        end
        aimFire(predicted)
        setStatus("🎯 Auto shooting " .. murderer.DisplayName, COLOR_BLUE)
    end
end

local function startAutoShootLoop()
    if shootLoopRunning then return end
    shootLoopRunning = true
    task.spawn(function()
        local shotTimer = 0
        while autoShootOn and HUB_GEN == getgenv().MM2HubGen do
            local dt = task.wait()
            shotTimer = shotTimer + dt
            local canFire = shotTimer >= 0.15
            if canFire then
                shotTimer = 0
            end
            local ok, err = pcall(autoShootStep, canFire)
            if not ok then
                warn("[MM2 AutoShoot] " .. tostring(err))
            end
        end
        shootLoopRunning = false
    end)
end

getgenv().MM2HubClick(autoShootBtn, "MouseButton1Click", function()
    if not autoShootOn then
        if not hasLocalGun() then
            setStatus("You need the Gun tool to use Auto Shoot.", COLOR_RED)
            return
        end
        autoShootOn = true
        autoShootBtn.Text = "🎯 STOP AUTO SHOOT"
        setToggleVisual(autoShootStroke, true)

        -- the crosshair ring (IgnoreGuiInset so it lines up with the screen center)
        local g = Instance.new("ScreenGui")
        g.Name = "MM2Hub_ShootRing"
        g.ResetOnSpawn = false
        g.IgnoreGuiInset = true
        g.DisplayOrder = 60
        g.Enabled = settings.showCircle ~= false
        g.Parent = playerGui
        local radius = settings.shootRing or 110
        local ring = Instance.new("Frame")
        ring.Name = "Ring"
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Size = UDim2.fromOffset(radius * 2, radius * 2)
        ring.BackgroundTransparency = 1
        ring.Parent = g
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(1, 0)
        rc.Parent = ring
        local rs = Instance.new("UIStroke")
        rs.Color = COLOR_RED
        rs.Thickness = 2
        rs.Parent = ring

        setStatus("AUTO SHOOT ON", COLOR_BLUE)
        startAutoShootLoop()
    else
        autoShootOn = false
        local old = playerGui:FindFirstChild("MM2Hub_ShootRing")
        if old then
            old:Destroy()
        end
        autoShootBtn.Text = "🎯 AUTO SHOOT"
        setToggleVisual(autoShootStroke, false)
        setStatus("AUTO SHOOT OFF")
    end
end)

-- AUTO SHOOT SETTINGS: right-click AUTO SHOOT to slide the panel out, right-click again to hide it
do
    local SHOOT_MIN, SHOOT_MAX = 40, 300
    settings.shootRing = math.clamp(tonumber(settings.shootRing) or 110, SHOOT_MIN, SHOOT_MAX)
    settings.shootAim = math.clamp(tonumber(settings.shootAim) or 100, 0, 100)

    local function applyRing(r)
        local g = playerGui:FindFirstChild("MM2Hub_ShootRing")
        local ring = g and g:FindFirstChild("Ring")
        if ring then
            ring.Size = UDim2.fromOffset(r * 2, r * 2)
        end
    end

    local panel = Instance.new("Frame")
    panel.Name = "AutoShootPanel"
    panel.Size = UDim2.fromOffset(190, 236)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.ZIndex = 20
    panel.Parent = screenGui
    corner(panel, 12)

    local pStroke = Instance.new("UIStroke")
    pStroke.Color = COLOR_BLUE
    pStroke.Thickness = 2
    pStroke.Parent = panel

    local head = Instance.new("TextLabel")
    head.Size = UDim2.new(1, -20, 0, 26)
    head.Position = UDim2.fromOffset(10, 8)
    head.BackgroundTransparency = 1
    head.Text = "AUTO SHOOT SETTINGS"
    head.TextColor3 = COLOR_TEXT
    head.TextScaled = true
    head.Font = activeFont
    head.ZIndex = 21
    head.Parent = panel

    local shootOpen, shootProgress = false, 0
    getgenv().MM2HubBind(RunService.RenderStepped, function(dt)
        if not shootOpen and shootProgress <= 0 then
            panel.Visible = false
            return
        end
        local goal = shootOpen and 1 or 0
        if shootProgress < goal then
            shootProgress = math.min(goal, shootProgress + dt * 4)
        elseif shootProgress > goal then
            shootProgress = math.max(goal, shootProgress - dt * 4)
        end
        local eased = 1 - (1 - shootProgress) ^ 3
        local x = rgbBorder.AbsolutePosition.X
        local w = rgbBorder.AbsoluteSize.X
        local y = rgbBorder.AbsolutePosition.Y + 40
        local hiddenX = x + w - 24
        local shownX = math.max(hiddenX, math.min(x + w + 8, workspace.CurrentCamera.ViewportSize.X - 200))
        panel.Position = UDim2.fromOffset(hiddenX + (shownX - hiddenX) * eased, y)
        panel.Visible = rgbBorder.Visible
    end)

    local function makeSlider(y, label, minV, maxV, get, set, fmt)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -20, 0, 20)
        lbl.Position = UDim2.fromOffset(10, y)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = COLOR_TEXT
        lbl.TextScaled = true
        lbl.Font = activeFont
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 21
        lbl.Parent = panel

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -30, 0, 8)
        track.Position = UDim2.fromOffset(15, y + 36)
        track.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        track.BorderSizePixel = 0
        track.ZIndex = 21
        track.Parent = panel
        corner(track, 4)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = COLOR_BLUE
        fill.BorderSizePixel = 0
        fill.ZIndex = 22
        fill.Parent = track
        corner(fill, 4)

        local knob = Instance.new("TextButton")
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.AnchorPoint = Vector2.new(0.5, 0.5)
        knob.Position = UDim2.new(0, 0, 0.5, 0)
        knob.BackgroundColor3 = Color3.new(1, 1, 1)
        knob.BorderSizePixel = 0
        knob.AutoButtonColor = false
        knob.Text = ""
        knob.ZIndex = 23
        knob.Parent = track
        corner(knob, 9)

        local function show(v)
            local frac = (v - minV) / (maxV - minV)
            fill.Size = UDim2.new(frac, 0, 1, 0)
            knob.Position = UDim2.new(frac, 0, 0.5, 0)
            lbl.Text = label .. ": " .. fmt(v)
        end
        show(get())

        local dragging = false
        local function fromX(x)
            local rel = (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
            local v = math.floor(minV + math.clamp(rel, 0, 1) * (maxV - minV) + 0.5)
            set(v)
            show(v)
        end
        local function begin(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            dragging = true
            fromX(input.Position.X)
        end
        track.InputBegan:Connect(begin)
        knob.InputBegan:Connect(begin)

        getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                fromX(input.Position.X)
            end
        end)
        getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                saveSettings()
            end
        end)
    end

    makeSlider(44, "CIRCLE SIZE", SHOOT_MIN, SHOOT_MAX,
        function() return settings.shootRing end,
        function(v) settings.shootRing = v; applyRing(v) end,
        function(v) return v .. " px" end)

    makeSlider(120, "AIM", 0, 100,
        function() return settings.shootAim end,
        function(v) settings.shootAim = v end,
        function(v)
            local word = v >= 75 and "STRONG" or (v >= 40 and "MEDIUM" or "WEAK")
            return word .. " " .. v .. "%"
        end)

    settings.showCircle = settings.showCircle ~= false
    local circleBtn = Instance.new("TextButton")
    circleBtn.Size = UDim2.fromOffset(170, 32)
    circleBtn.Position = UDim2.fromOffset(10, 192)
    circleBtn.BorderSizePixel = 0
    circleBtn.AutoButtonColor = false
    circleBtn.TextColor3 = Color3.new(1, 1, 1)
    circleBtn.TextScaled = true
    circleBtn.Font = activeFont
    circleBtn.ZIndex = 21
    circleBtn.Parent = panel
    corner(circleBtn, 8)

    local function showCircleUI()
        circleBtn.Text = settings.showCircle and "SHOW CIRCLE: ON" or "SHOW CIRCLE: OFF"
        circleBtn.BackgroundColor3 = settings.showCircle and COLOR_BLUE or Color3.fromRGB(40, 40, 60)
        local g = playerGui:FindFirstChild("MM2Hub_ShootRing")
        if g then g.Enabled = settings.showCircle end
    end
    showCircleUI()
    getgenv().MM2HubClick(circleBtn, "MouseButton1Click", function()
        settings.showCircle = not settings.showCircle
        saveSettings()
        showCircleUI()
    end)

    getgenv().MM2HubClick(autoShootBtn, "MouseButton2Click", function()
        shootOpen = not shootOpen
    end)
end

-- AUTO MURD WIN
local murdWinOn = false

local function murdWinLoop()
    while murdWinOn and HUB_GEN == getgenv().MM2HubGen do
        task.wait(0.1)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum then
            local knife = findOwnTool("knife")
            if not knife then
                setStatus("No knife detected bruh, get out", COLOR_RED)
                task.wait(2)
            else
                if knife.Parent ~= char then
                    hum:EquipTool(knife)
                end
                for _, plr in ipairs(Players:GetPlayers()) do
                    if not murdWinOn then break end
                    local tHRP = plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if tHRP and not isDead(plr) and not getgenv().MM2HubKilled[plr] then
                        hrp.CFrame = CFrame.new(tHRP.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
                        pcall(function() knife:Activate() end)
                        task.wait(0.12)
                        if isDead(plr) then getgenv().MM2HubKilled[plr] = true end
                    end
                end
            end
        end
    end
end

getgenv().MM2HubClick(autoMurdWinBtn, "MouseButton1Click", function()
    murdWinOn = not murdWinOn
    if murdWinOn then
        autoMurdWinBtn.Text = "⚔ STOP MURD WIN"
        setToggleVisual(murdWinStroke, true)
        setStatus("AUTO MURD WIN ON", COLOR_RED)
        task.spawn(murdWinLoop)
    else
        autoMurdWinBtn.Text = "⚔ AUTO MURD WIN"
        setToggleVisual(murdWinStroke, false)
        setStatus("AUTO MURD WIN OFF")
    end
end)

-- AUTO GRAB GUN: with no gun, finds the "GunDrop" part inside a model in workspace,
-- teleports onto it for 0.2s to pick it up, then teleports you back
local autoGunOn = false

local function findGunDrop()
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") then
            local part = m:FindFirstChild("GunDrop", true)
            if part and part:IsA("BasePart") then
                return part
            end
        end
    end
    return nil
end

local function autoGunLoop()
    while autoGunOn and HUB_GEN == getgenv().MM2HubGen do
        task.wait(0.25)
        if hasLocalGun() then
            setStatus("You have the gun!", COLOR_GREEN)
        else
            local drop = findGunDrop()
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if drop and hrp then
                local backCF = hrp.CFrame
                setStatus("Grabbing the gun...", COLOR_BLUE)
                hrp.CFrame = drop.CFrame + Vector3.new(0, 3, 0)
                hrp.AssemblyLinearVelocity = Vector3.zero
                -- wait two physics steps so the touch on the gun registers, then snap back instantly
                RunService.Heartbeat:Wait()
                RunService.Heartbeat:Wait()
                local nowChar = player.Character
                local nowHrp = nowChar and nowChar:FindFirstChild("HumanoidRootPart")
                if nowHrp then
                    nowHrp.CFrame = backCF
                    nowHrp.AssemblyLinearVelocity = Vector3.zero
                end
                task.wait(0.5) -- short pause so the pickup can finish before retrying
            end
        end
    end
end

getgenv().MM2HubClick(autoGunBtn, "MouseButton1Click", function()
    autoGunOn = not autoGunOn
    if autoGunOn then
        autoGunBtn.Text = "🔫 STOP AUTO GUN"
        setToggleVisual(autoGunStroke, true)
        setStatus("AUTO GRAB GUN ON", COLOR_BLUE)
        task.spawn(autoGunLoop)
    else
        autoGunBtn.Text = "🔫 AUTO GRAB GUN"
        setToggleVisual(autoGunStroke, false)
        setStatus("AUTO GRAB GUN OFF")
    end
end)

-- MURDER REACH
-- Enlarges other players' HumanoidRootPart and turns off collisions on their
-- parts, so you walk through the big hitbox instead of getting blocked by it.
-- Client-side: the server still decides what counts as a hit.
local reachOn = false
local reachRunning = false
local reachSize = math.clamp(tonumber(settings.reachSize) or 10, REACH_MIN, REACH_MAX)

local function reachVector()
    return Vector3.new(reachSize, reachSize, reachSize)
end
-- Hitbox helper: instead of resizing the player's real HumanoidRootPart (that is what froze
-- everybody), a separate see-through box is welded to it. The real character is never modified.
do
    local lib = {}
    function lib.ensure(plr, name, size, transparency)
        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local box = char:FindFirstChild(name)
        if box and box:IsA("BasePart") then
            if box.Size ~= size then box.Size = size end
            local weld = box:FindFirstChildOfClass("WeldConstraint")
            if weld and weld.Part0 == hrp then return end
            box:Destroy()
        end
        box = Instance.new("Part")
        box.Name = name
        box.Size = size
        box.Transparency = transparency or 0.75
        box.Color = Color3.fromRGB(255, 60, 100)
        box.Material = Enum.Material.SmoothPlastic
        box.CanCollide = false
        box.CanTouch = false
        box.CanQuery = true
        box.Massless = true
        box.CastShadow = false
        box.CFrame = hrp.CFrame
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = hrp
        weld.Part1 = box
        weld.Parent = box
        box.Parent = char
    end
    function lib.remove(plr, name)
        local char = plr.Character
        local box = char and char:FindFirstChild(name)
        if box then box:Destroy() end
    end
    getgenv().MM2HubHitbox = lib
end

local function setReach(plr, on)
    local lib = getgenv().MM2HubHitbox
    if on then
        lib.ensure(plr, "MM2_ReachBox", reachVector(), 0.75)
    else
        lib.remove(plr, "MM2_ReachBox")
    end
end

local function startReachLoop()
    if reachRunning then return end
    reachRunning = true
    task.spawn(function()
        while reachOn and HUB_GEN == getgenv().MM2HubGen do
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player then
                    pcall(setReach, plr, true)
                end
            end
            task.wait(0.5)
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            pcall(setReach, plr, false)
        end
        reachRunning = false
    end)
end

getgenv().MM2HubClick(reachBtn, "MouseButton1Click", function()
    reachOn = not reachOn
    if reachOn then
        reachBtn.Text = "📏 STOP REACH"
        setToggleVisual(reachStroke, true)
        setStatus("MURDER REACH ON", Color3.fromRGB(0, 200, 180))
        startReachLoop()
    else
        reachBtn.Text = "📏 MURDER REACH"
        setToggleVisual(reachStroke, false)
        setStatus("MURDER REACH OFF")
    end
end)

-- RESIZE: drag a corner grip to scale the whole window; ANIMATED UI breathes and spins the border
do
    if settings.windowH then
        rgbBorder.Size = UDim2.new(0, 316, 0, settings.windowH)
        mainFrame.Size = UDim2.new(0, 308, 0, settings.windowH - 8)
    end

    local resizing = false
    local center0, d0, s0 = nil, 1, 1

    local function makeGrip(ax, ay)
        local g = Instance.new("TextButton")
        g.Size = UDim2.new(0, 14, 0, 14)
        g.Position = UDim2.new(ax, -7, ay, -7)
        g.BackgroundColor3 = activeThemeDef.accent
        g.BorderSizePixel = 0
        g.AutoButtonColor = false
        g.Text = ""
        g.ZIndex = 20
        g.Parent = rgbBorder
        corner(g, 7)
        g.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            resizing = true
            rgbBorder.Draggable = false
            center0 = rgbBorder.AbsolutePosition + rgbBorder.AbsoluteSize / 2
            d0 = math.max(1, (UserInputService:GetMouseLocation() - center0).Magnitude)
            s0 = uiScale.Scale
        end)
    end
    -- bottom-right grip: stretches the window's length (height) only
    local function makeLengthGrip()
        local g = Instance.new("TextButton")
        g.Size = UDim2.new(0, 14, 0, 14)
        g.Position = UDim2.new(1, -7, 1, -7)
        g.BackgroundColor3 = Color3.fromRGB(0, 200, 180)
        g.BorderSizePixel = 0
        g.AutoButtonColor = false
        g.Text = ""
        g.ZIndex = 20
        g.Parent = rgbBorder
        corner(g, 7)

        local dragging, startY, startH = false, 0, 478
        g.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            dragging = true
            rgbBorder.Draggable = false
            startY = UserInputService:GetMouseLocation().Y
            startH = rgbBorder.Size.Y.Offset
        end)
        getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
            if not dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local dy = (UserInputService:GetMouseLocation().Y - startY) / uiScale.Scale
            local h = math.clamp(startH + dy, 380, 700)
            rgbBorder.Size = UDim2.new(0, 316, 0, h)
            mainFrame.Size = UDim2.new(0, 308, 0, h - 8)
            settings.windowH = h
        end)
        getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
            if not dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            dragging = false
            rgbBorder.Draggable = true
            saveSettings()
        end)
    end

    makeGrip(0, 0)
    makeGrip(1, 0)
    makeGrip(0, 1)
    makeLengthGrip()

    getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
        if not resizing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local d = (UserInputService:GetMouseLocation() - center0).Magnitude
        local s = math.clamp(s0 * d / d0, 0.6, 1.6)
        settings.uiScale = s
        uiScale.Scale = s
    end)
    getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
        if not resizing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        resizing = false
        rgbBorder.Draggable = true
        saveSettings()
    end)

    local t0 = os.clock()
    getgenv().MM2HubBind(RunService.Heartbeat, function()
        if resizing then return end
        local base = settings.uiScale or 1
        if settings.animatedUI then
            local t = os.clock() - t0
            uiScale.Scale = base * (1 + 0.015 * math.sin(t * 2.5)) * (getgenv().MM2HubFit or 1)
            rgbGrad.Rotation = (t * 40) % 360
        else
            uiScale.Scale = base * (getgenv().MM2HubFit or 1)
        end
    end)
end

-- SHERIFF HITBOX EXPANDER: makes the murderer's hitbox bigger on your client.
-- (The server decides hits, so the gun's own beam hitbox can't be changed from here.)
do
    local HITBOX = 14
    local on = false
    local lastTarget = nil

    local hbBtn, hbStroke = makeButton(combatPage, "🎯 SHERIFF HITBOX EXPANDER", 250, COLOR_RED)

    local function restoreAll()
        if lastTarget then
            getgenv().MM2HubHitbox.remove(lastTarget, "MM2_MurdBox")
            lastTarget = nil
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            getgenv().MM2HubHitbox.remove(plr, "MM2_MurdBox")
        end
    end

    local acc = 0
    getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
        if not on then return end
        acc = acc + dt
        if acc < 0.5 then return end
        acc = 0
        local m = findMurderer()
        if lastTarget and lastTarget ~= m then
            getgenv().MM2HubHitbox.remove(lastTarget, "MM2_MurdBox")
        end
        lastTarget = m
        if m then
            getgenv().MM2HubHitbox.ensure(m, "MM2_MurdBox", Vector3.new(HITBOX, HITBOX, HITBOX), 0.75)
        end
    end)

    getgenv().MM2HubClick(hbBtn, "MouseButton1Click", function()
        on = not on
        setToggleVisual(hbStroke, on)
        if on then
            setStatus("SHERIFF HITBOX EXPANDER ON", COLOR_RED)
        else
            restoreAll()
            setStatus("SHERIFF HITBOX EXPANDER OFF")
        end
    end)
end

do -- MURDER REACH SIZE POPUP (right-click the MURDER REACH button)
local reachPopup = Instance.new("Frame")
reachPopup.Name = "ReachPopup"
reachPopup.Size = UDim2.fromOffset(200, 170)
reachPopup.Position = UDim2.fromOffset(0, 0)
reachPopup.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
reachPopup.BorderSizePixel = 0
reachPopup.Visible = false
reachPopup.ZIndex = 20
reachPopup.Parent = screenGui
corner(reachPopup, 10)

local popStroke = Instance.new("UIStroke")
popStroke.Color = Color3.fromRGB(0, 200, 180)
popStroke.Thickness = 1.5
popStroke.Parent = reachPopup

local popTitle = Instance.new("TextLabel")
popTitle.Size = UDim2.new(1, -20, 0, 24)
popTitle.Position = UDim2.new(0, 10, 0, 8)
popTitle.BackgroundTransparency = 1
popTitle.Text = "MURDER HITBOX SIZE"
popTitle.TextColor3 = COLOR_TEXT
popTitle.TextScaled = true
popTitle.Font = activeFont
popTitle.ZIndex = 21
popTitle.Parent = reachPopup

local popValue = Instance.new("TextLabel")
popValue.Size = UDim2.new(1, -20, 0, 20)
popValue.Position = UDim2.new(0, 10, 0, 40)
popValue.BackgroundTransparency = 1
popValue.TextColor3 = Color3.fromRGB(0, 200, 180)
popValue.TextScaled = true
popValue.Font = activeFont
popValue.ZIndex = 21
popValue.Parent = reachPopup

local track = Instance.new("Frame")
track.Size = UDim2.new(1, -40, 0, 8)
track.Position = UDim2.new(0, 20, 0, 84)
track.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
track.BorderSizePixel = 0
track.ZIndex = 21
track.Parent = reachPopup
corner(track, 4)

local fill = Instance.new("Frame")
fill.Size = UDim2.new(0, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(0, 200, 180)
fill.BorderSizePixel = 0
fill.ZIndex = 22
fill.Parent = track
corner(fill, 4)

local knob = Instance.new("TextButton")
knob.Size = UDim2.new(0, 18, 0, 18)
knob.AnchorPoint = Vector2.new(0.5, 0.5)
knob.Position = UDim2.new(0, 0, 0.5, 0)
knob.BackgroundColor3 = Color3.new(1, 1, 1)
knob.BorderSizePixel = 0
knob.AutoButtonColor = false
knob.Text = ""
knob.ZIndex = 23
knob.Parent = track
corner(knob, 9)

local reachOpen, reachProgress = false, 0
getgenv().MM2HubBind(RunService.RenderStepped, function(dt)
    if not reachOpen and reachProgress <= 0 then
        reachPopup.Visible = false
        return
    end
    local goal = reachOpen and 1 or 0
    if reachProgress < goal then
        reachProgress = math.min(goal, reachProgress + dt * 4)
    elseif reachProgress > goal then
        reachProgress = math.max(goal, reachProgress - dt * 4)
    end
    local eased = 1 - (1 - reachProgress) ^ 3
    local x = rgbBorder.AbsolutePosition.X
    local w = rgbBorder.AbsoluteSize.X
    local y = rgbBorder.AbsolutePosition.Y + 40
    local hiddenX = x + w - 24
    local shownX = math.max(hiddenX, math.min(x + w + 8, workspace.CurrentCamera.ViewportSize.X - 200))
    reachPopup.Position = UDim2.fromOffset(hiddenX + (shownX - hiddenX) * eased, y)
    reachPopup.Visible = rgbBorder.Visible
end)

local draggingSlider = false

local function setReachSize(v)
    reachSize = math.clamp(math.floor(v + 0.5), REACH_MIN, REACH_MAX)
    settings.reachSize = reachSize
    saveSettings()
    local frac = (reachSize - REACH_MIN) / (REACH_MAX - REACH_MIN)
    fill.Size = UDim2.new(frac, 0, 1, 0)
    knob.Position = UDim2.new(frac, 0, 0.5, 0)
    popValue.Text = "Size: " .. reachSize .. " studs"
end

local function sliderFromX(x)
    local rel = (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
    setReachSize(REACH_MIN + math.clamp(rel, 0, 1) * (REACH_MAX - REACH_MIN))
end

local function beginSlide(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    draggingSlider = true
    rgbBorder.Draggable = false -- stop the window from moving while sliding
    sliderFromX(input.Position.X)
end

track.InputBegan:Connect(beginSlide)
knob.InputBegan:Connect(beginSlide)

getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        sliderFromX(input.Position.X)
    end
end)

getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        draggingSlider = false
        rgbBorder.Draggable = true
    end
end)

local reachDone = Instance.new("TextButton")
reachDone.Size = UDim2.new(0, 100, 0, 28)
reachDone.Position = UDim2.new(0.5, -50, 1, -40)
reachDone.BackgroundColor3 = Color3.fromRGB(24, 24, 36)
reachDone.BorderSizePixel = 0
reachDone.Text = "DONE"
reachDone.TextColor3 = COLOR_TEXT
reachDone.TextScaled = true
reachDone.Font = activeFont
reachDone.ZIndex = 21
reachDone.Parent = reachPopup
corner(reachDone, 6)

getgenv().MM2HubClick(reachDone, "MouseButton1Click", function()
    reachOpen = false
end)

reachBtn.MouseButton2Click:Connect(function()
    reachOpen = not reachOpen
end)

setReachSize(reachSize)

end -- MURDER REACH SIZE POPUP

-- ============================
-- PLAYER TAB
-- ============================
-- ============================
-- SIDE PANELS: SPEED (PLAYER tab) and AIM MODE (right-click AUTO AIM)
-- ============================
do
    -- forward declarations: the two panels open/close each other
    local setSpeedOpen, isSpeedOpen, setAimOpen, isAimOpen

    -- a panel that slides out from the right edge of the main window
    local function makeSidePanel(height)
        local panel = Instance.new("Frame")
        panel.Size = UDim2.new(0, 170, 0, height)
        panel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
        panel.BorderSizePixel = 0
        panel.Visible = false
        panel.ZIndex = 5
        panel.Parent = screenGui
        corner(panel, 12)

        local pStroke = Instance.new("UIStroke")
        pStroke.Color = activeThemeDef.accent
        pStroke.Thickness = 2
        pStroke.Parent = panel

        local progress, isOpen = 0, false
        getgenv().MM2HubBind(RunService.RenderStepped, function(dt)
            if not isOpen and progress <= 0 then
                panel.Visible = false
                return
            end
            local goal = isOpen and 1 or 0
            if progress < goal then
                progress = math.min(goal, progress + dt * 4)
            elseif progress > goal then
                progress = math.max(goal, progress - dt * 4)
            end
            local eased = 1 - (1 - progress) ^ 3
            local x = rgbBorder.AbsolutePosition.X
            local w = rgbBorder.AbsoluteSize.X
            local y = rgbBorder.AbsolutePosition.Y + 40
            local hiddenX = x + w - 24
            local shownX = math.max(hiddenX, math.min(x + w + 8, workspace.CurrentCamera.ViewportSize.X - 200))
            panel.Position = UDim2.fromOffset(hiddenX + (shownX - hiddenX) * eased, y)
            panel.Visible = true
        end)

        local function setOpen(v)
            isOpen = v
        end
        local function getOpen()
            return isOpen
        end
        return panel, setOpen, getOpen
    end

    local function panelButton(parent, text, y, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 140, 0, 32)
        b.Position = UDim2.new(0, 15, 0, y)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextScaled = true
        b.Font = activeFont
        b.ZIndex = 6
        b.Parent = parent
        corner(b, 8)
        return b
    end

    local function panelTitle(parent, text, y)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -20, 0, 24)
        l.Position = UDim2.new(0, 10, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = COLOR_TEXT
        l.TextScaled = true
        l.Font = activeFont
        l.ZIndex = 6
        l.Parent = parent
        return l
    end

    -- ========== SPEED ==========
    local SPEED_MIN, SPEED_MAX = 16, 200
    local speedOn = false
    local speedValue = math.clamp(tonumber(settings.walkSpeed) or 16, SPEED_MIN, SPEED_MAX)
    local baseWalk = setmetatable({}, { __mode = "k" }) -- humanoid -> original WalkSpeed

    local speedPanel
speedPanel, setSpeedOpen, isSpeedOpen = makeSidePanel(230)
    panelTitle(speedPanel, "SPEED", 8)
    local speedValueLbl = panelTitle(speedPanel, "", 40)

    local sTrack = Instance.new("Frame")
    sTrack.Size = UDim2.new(1, -40, 0, 8)
    sTrack.Position = UDim2.new(0, 20, 0, 80)
    sTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    sTrack.BorderSizePixel = 0
    sTrack.ZIndex = 6
    sTrack.Parent = speedPanel
    corner(sTrack, 4)

    local sFill = Instance.new("Frame")
    sFill.Size = UDim2.new(0, 0, 1, 0)
    sFill.BackgroundColor3 = activeThemeDef.accent
    sFill.BorderSizePixel = 0
    sFill.ZIndex = 7
    sFill.Parent = sTrack
    corner(sFill, 4)

    local sKnob = Instance.new("TextButton")
    sKnob.Size = UDim2.new(0, 18, 0, 18)
    sKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    sKnob.Position = UDim2.new(0, 0, 0.5, 0)
    sKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    sKnob.BorderSizePixel = 0
    sKnob.AutoButtonColor = false
    sKnob.Text = ""
    sKnob.ZIndex = 8
    sKnob.Parent = sTrack
    corner(sKnob, 9)

    local function setSpeedUI(v)
        speedValue = math.clamp(math.floor(v + 0.5), SPEED_MIN, SPEED_MAX)
        local frac = (speedValue - SPEED_MIN) / (SPEED_MAX - SPEED_MIN)
        sFill.Size = UDim2.new(frac, 0, 1, 0)
        sKnob.Position = UDim2.new(frac, 0, 0.5, 0)
        speedValueLbl.Text = "Speed: " .. speedValue
    end

    local draggingSpeed = false
    local function speedFromX(x)
        local rel = (x - sTrack.AbsolutePosition.X) / math.max(1, sTrack.AbsoluteSize.X)
        setSpeedUI(SPEED_MIN + math.clamp(rel, 0, 1) * (SPEED_MAX - SPEED_MIN))
    end
    local function beginSpeedDrag(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        draggingSpeed = true
        rgbBorder.Draggable = false
        speedFromX(input.Position.X)
    end
    sTrack.InputBegan:Connect(beginSpeedDrag)
    sKnob.InputBegan:Connect(beginSpeedDrag)
    getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
        if draggingSpeed and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            speedFromX(input.Position.X)
        end
    end)
    getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
        if draggingSpeed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            draggingSpeed = false
            rgbBorder.Draggable = true
        end
    end)

    local speedDone = panelButton(speedPanel, "DONE", 130, activeThemeDef.accent)
    local speedReset = panelButton(speedPanel, "RESET SPEED", 172, Color3.fromRGB(120, 40, 40))

    local speedBtn = makeButton(playerPage, "⚡ SPEED", 150, Color3.fromRGB(255, 200, 60))

    local function currentHumanoid()
        local c = player.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    -- remember each humanoid's original speed, and keep the chosen speed applied (also after respawn)
    getgenv().MM2HubBind(RunService.Heartbeat, function()
        local h = currentHumanoid()
        if not h then return end
        if baseWalk[h] == nil then
            baseWalk[h] = h.WalkSpeed
        end
        if speedOn and h.WalkSpeed ~= speedValue then
            h.WalkSpeed = speedValue
        end
    end)

    getgenv().MM2HubClick(speedBtn, "MouseButton1Click", function()
        setAimOpen(false)
        setSpeedOpen(not isSpeedOpen())
    end)
    getgenv().MM2HubClick(speedDone, "MouseButton1Click", function()
        speedOn = true
        settings.walkSpeed = speedValue
        saveSettings()
        speedBtn.Text = "⚡ SPEED: " .. speedValue
        setSpeedOpen(false)
        setStatus("Speed set to " .. speedValue, COLOR_GREEN)
    end)
    getgenv().MM2HubClick(speedReset, "MouseButton1Click", function()
        speedOn = false
        local h = currentHumanoid()
        local original = (h and baseWalk[h]) or 16
        if h then
            h.WalkSpeed = original
        end
        setSpeedUI(original)
        settings.walkSpeed = nil
        saveSettings()
        speedBtn.Text = "⚡ SPEED"
        setSpeedOpen(false)
        setStatus("Speed reset to " .. original)
    end)
    setSpeedUI(speedValue)

    -- ========== AIM MODE (right-click AUTO AIM) ==========
    local aimPanel
aimPanel, setAimOpen, isAimOpen = makeSidePanel(200)
    panelTitle(aimPanel, "AIM MODE", 8)
    local regBtn = panelButton(aimPanel, "REGULAR", 50, Color3.fromRGB(40, 40, 60))
    local murdBtn = panelButton(aimPanel, "AUTO AIM MURD", 96, Color3.fromRGB(40, 40, 60))
    local aimDone = panelButton(aimPanel, "DONE", 146, Color3.fromRGB(24, 24, 36))

    local function refreshAimModes()
        regBtn.BackgroundColor3 = (aimMode == "REGULAR") and activeThemeDef.accent or Color3.fromRGB(40, 40, 60)
        murdBtn.BackgroundColor3 = (aimMode == "MURD") and activeThemeDef.accent or Color3.fromRGB(40, 40, 60)
    end

    getgenv().MM2HubClick(regBtn, "MouseButton1Click", function()
        aimMode = "REGULAR"
        settings.aimMode = "REGULAR"
        saveSettings()
        refreshAimModes()
        setStatus("Aim mode: REGULAR (pick a target)", COLOR_BLUE)
    end)
    getgenv().MM2HubClick(murdBtn, "MouseButton1Click", function()
        aimMode = "MURD"
        settings.aimMode = "MURD"
        saveSettings()
        refreshAimModes()
        setStatus("Aim mode: AUTO AIM MURD (locks the knife holder)", COLOR_RED)
    end)
    getgenv().MM2HubClick(aimDone, "MouseButton1Click", function()
        setAimOpen(false)
    end)
    toggleAimBtn.MouseButton2Click:Connect(function()
        local nowOpen = not isAimOpen()
        setSpeedOpen(false)
        setAimOpen(nowOpen)
        if nowOpen then
            refreshAimModes()
        end
    end)
    refreshAimModes()
end

local noclipJumpBtn, noclipStroke = makeButton(playerPage, "⚡ NOCLIP / INF JUMP", 0, Color3.fromRGB(0, 200, 180))
local invisBtn, invisStroke = makeButton(playerPage, "◌ INVIS", 50, Color3.fromRGB(180, 80, 255))
local autoCoinBtn, autoCoinStroke = makeButton(playerPage, "🪙 AUTO COIN", 100, COLOR_GOLD)

-- AUTO COIN
-- Tweens to each Coin_Server part inside a model named CoinContainer at 50
-- studs/sec, nearest first. Waits for the CoinCollected remote before moving on.
local autoCoinOn = false
local coinRunning = false
local coinSignal = Instance.new("BindableEvent")

local function findRemoteNamed(name)
    for _, obj in ipairs(game:GetDescendants()) do
        if obj.Name == name and obj:IsA("RemoteEvent") then
            return obj
        end
    end
    return nil
end

local function getCoins()
    local list = {}
    for _, container in ipairs(workspace:GetDescendants()) do
        if container:IsA("Model") and container.Name == "CoinContainer" then
            for _, d in ipairs(container:GetDescendants()) do
                if d:IsA("BasePart") and d.Name == "Coin_Server" then
                    table.insert(list, d)
                end
            end
        end
    end
    return list
end

-- Moves the character to the coin at COIN speed, frame by frame (Heartbeat). The old tween
-- fought the Humanoid physics (gravity/collisions) so the character got stuck or never touched
-- the coin. Parts are noclipped while travelling and velocity is zeroed every frame.
local function tweenToCoin(root, coin)
    local char = root.Parent
    local speed = settings.coinSpeed or COIN_SPEED
    local startDist = (coin.Position - root.Position).Magnitude
    local maxTime = startDist / speed + 1.5

    local saved = {}
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                saved[p] = p.CanCollide
                p.CanCollide = false
            end
        end
    end

    local t = 0
    while autoCoinOn and coin.Parent and root.Parent and t < maxTime
        and HUB_GEN == getgenv().MM2HubGen and not getgenv().MM2HubCoinHide do
        local dt = RunService.Heartbeat:Wait()
        t = t + dt
        local delta = coin.Position - root.Position
        local dist = delta.Magnitude
        if dist < 1 then break end
        local step = math.min(dist, speed * dt)
        root.CFrame = root.CFrame + delta.Unit * step
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    -- make sure the touch registers even if the physics touch didn't fire
    if coin.Parent and root.Parent and typeof(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(root, coin, 0)
            task.wait()
            firetouchinterest(root, coin, 1)
        end)
    end

    for p, cc in pairs(saved) do
        if p.Parent then p.CanCollide = cc end
    end
end

local function autoCoinLoop()
    local remote = findRemoteNamed("CoinCollected")
    local remoteConn
    if remote then
        remoteConn = getgenv().MM2HubBind(remote.OnClientEvent, function(...)
            coinSignal:Fire(...)
        end)
    else
        setStatus("CoinCollected remote not found, using coin removal instead.", Color3.fromRGB(255, 200, 50))
    end

    -- KILL PROTECTION: when the murderer (or a zombie) gets close, the character anchors
    -- under the map until they leave. Coins are collected again once it's clear.
    local HIDE_DEPTH = 60
    local KILL_RANGE = 35
    local hiddenRoot, hiddenFrom = nil, nil
    local function coinKillHide(root)
        if getgenv().MM2HubCoinHide and hiddenRoot ~= root then
            getgenv().MM2HubCoinHide = false -- the character respawned while hidden
        end
        if not settings.coinKillProtect then
            if getgenv().MM2HubCoinHide and hiddenRoot then
                pcall(function() hiddenRoot.Anchored = false; hiddenRoot.CFrame = hiddenFrom end)
                getgenv().MM2HubCoinHide = false
            end
            return false
        end
        local hidden = getgenv().MM2HubCoinHide
        -- measure from the spot above ground, not from under the map
        local refPos = (hidden and hiddenFrom) and hiddenFrom.Position or root.Position
        local m = findMurderer()
        local mRoot = m and m.Character and m.Character:FindFirstChild("HumanoidRootPart")
        local near = mRoot ~= nil and (mRoot.Position - refPos).Magnitude <= KILL_RANGE
        if near and not hidden then
            getgenv().MM2HubCoinHide = true
            hiddenRoot = root
            hiddenFrom = root.CFrame
            root.Anchored = true
            root.CFrame = CFrame.new(root.Position.X, root.Position.Y - HIDE_DEPTH, root.Position.Z)
            setStatus("Kill protection: hiding under the map", COLOR_RED)
        elseif not near and hidden then
            getgenv().MM2HubCoinHide = false
            root.Anchored = false
            root.CFrame = hiddenFrom
            setStatus("Kill protection: clear, back to coins", COLOR_GOLD)
        end
        return getgenv().MM2HubCoinHide
    end

    -- while hidden: rise just above the nearest close coin so it touches the hitbox, then drop back
    local function hideGrab(root)
        if not hiddenFrom then return end
        local nearest, best = nil, 25
        for _, c in ipairs(getCoins()) do
            if c.Parent then
                local d = (c.Position - hiddenFrom.Position).Magnitude
                if d < best then best, nearest = d, c end
            end
        end
        if not nearest then return end
        local fired = false
        local conn = coinSignal.Event:Connect(function() fired = true end)
        root.Anchored = false -- anchored parts don't fire Touched, so unanchor for the grab
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = CFrame.new(nearest.Position + Vector3.new(0, 3, 0))
        local t = 0
        while not fired and t < 0.4 and nearest.Parent and autoCoinOn do
            task.wait(0.05)
            t = t + 0.05
        end
        conn:Disconnect()
        if getgenv().MM2HubCoinHide and root.Parent then
            root.Anchored = true
            root.CFrame = CFrame.new(hiddenFrom.Position.X, hiddenFrom.Position.Y - HIDE_DEPTH, hiddenFrom.Position.Z)
        end
    end

    local skipped = {}
    while autoCoinOn and HUB_GEN == getgenv().MM2HubGen do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            task.wait(0.5)
        elseif coinKillHide(root) then
            hideGrab(root)
            task.wait(0.2)
        else
            local coins = getCoins()
            local candidates = {}
            for _, c in ipairs(coins) do
                if c.Parent and not skipped[c] then
                    table.insert(candidates, c)
                end
            end

            if #coins == 0 then
                setStatus("No Coin_Server parts found in CoinContainer.", Color3.fromRGB(255, 200, 50))
                task.wait(1)
            elseif #candidates == 0 then
                skipped = {}
                task.wait(1)
            else
                table.sort(candidates, function(a, b)
                    return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
                end)
                local coin = candidates[1]

                local fired = false
                local fireConn = coinSignal.Event:Connect(function()
                    fired = true
                end)

                tweenToCoin(root, coin)

                local t = 0
                while settings.coinWait ~= false and not fired and coin.Parent and t < COIN_TIMEOUT and autoCoinOn do
                    task.wait(0.1)
                    t = t + 0.1
                end
                fireConn:Disconnect()

                local got = fired or coin.Parent == nil
                if not got then
                    skipped[coin] = true
                end
                task.wait(0.2)
            end
        end
    end

    if remoteConn then remoteConn:Disconnect() end
    -- never leave the character anchored under the map when auto coin stops
    if getgenv().MM2HubCoinHide and hiddenRoot then
        pcall(function() hiddenRoot.Anchored = false; hiddenRoot.CFrame = hiddenFrom end)
    end
    getgenv().MM2HubCoinHide = false
    coinRunning = false
end

-- AUTO COIN: tap/click toggles it on PC; right-click (or tap on mobile) opens the settings panel
do
    local function toggleCoin()
        autoCoinOn = not autoCoinOn
        if autoCoinOn then
            autoCoinBtn.Text = "🪙 STOP AUTO COIN"
            setToggleVisual(autoCoinStroke, true)
            setStatus("AUTO COIN ON", COLOR_GOLD)
            if not coinRunning then
                coinRunning = true
                task.spawn(autoCoinLoop)
            end
        else
            autoCoinBtn.Text = "🪙 AUTO COIN"
            setToggleVisual(autoCoinStroke, false)
            setStatus("AUTO COIN OFF")
        end
    end

    local coinRoundMode = settings.coinRound == true
    local roundActive = false
    local COIN_MIN, COIN_MAX = 20, 200
    local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 170, 0, 332)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.ZIndex = 5
    panel.Parent = screenGui
    corner(panel, 12)
    local pst = Instance.new("UIStroke")
    pst.Color = activeThemeDef.accent
    pst.Thickness = 2
    pst.Parent = panel

    local function plabel(y, text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -20, 0, 24)
        l.Position = UDim2.new(0, 10, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = COLOR_TEXT
        l.TextScaled = true
        l.Font = activeFont
        l.ZIndex = 6
        l.Parent = panel
        return l
    end
    local function pbtn(y, text, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 140, 0, 32)
        b.Position = UDim2.new(0, 15, 0, y)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextScaled = true
        b.Font = activeFont
        b.ZIndex = 6
        b.Parent = panel
        corner(b, 8)
        return b
    end

    plabel(8, "AUTO COIN")
    local valueLbl = plabel(40, "")

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -40, 0, 8)
    track.Position = UDim2.new(0, 20, 0, 76)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    track.BorderSizePixel = 0
    track.ZIndex = 6
    track.Parent = panel
    corner(track, 4)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = activeThemeDef.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 7
    fill.Parent = track
    corner(fill, 4)
    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.AutoButtonColor = false
    knob.Text = ""
    knob.ZIndex = 8
    knob.Parent = track
    corner(knob, 9)

    local function setCoinSpeed(v)
        local value = math.clamp(math.floor(v + 0.5), COIN_MIN, COIN_MAX)
        settings.coinSpeed = value
        local frac = (value - COIN_MIN) / (COIN_MAX - COIN_MIN)
        fill.Size = UDim2.new(frac, 0, 1, 0)
        knob.Position = UDim2.new(frac, 0, 0.5, 0)
        valueLbl.Text = "Speed: " .. value
    end

    local dragging = false
    local function speedFromX(x)
        local rel = (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
        setCoinSpeed(COIN_MIN + math.clamp(rel, 0, 1) * (COIN_MAX - COIN_MIN))
    end
    local function beginDrag(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        dragging = true
        rgbBorder.Draggable = false
        speedFromX(input.Position.X)
    end
    track.InputBegan:Connect(beginDrag)
    knob.InputBegan:Connect(beginDrag)
    getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            speedFromX(input.Position.X)
        end
    end)
    getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            rgbBorder.Draggable = true
            saveSettings()
        end
    end)

    local onOffBtn = pbtn(122, "START", activeThemeDef.accent)
    local waitBtn = pbtn(164, "WAIT: ON", Color3.fromRGB(40, 40, 60))
    local killBtn = pbtn(206, "KILL PROTECT: OFF", Color3.fromRGB(40, 40, 60))
    local roundBtn = pbtn(248, "EACH ROUND: OFF", Color3.fromRGB(40, 40, 60))
    local doneBtn = pbtn(290, "DONE", Color3.fromRGB(24, 24, 36))

    local function refresh()
        onOffBtn.Text = autoCoinOn and "STOP" or "START"
        waitBtn.Text = "WAIT: " .. (settings.coinWait ~= false and "ON" or "OFF")
        roundBtn.Text = "EACH ROUND: " .. (coinRoundMode and "ON" or "OFF")
        killBtn.Text = "KILL PROTECT: " .. (settings.coinKillProtect and "ON" or "OFF")
        setCoinSpeed(settings.coinSpeed or COIN_SPEED)
    end

    local progress, isOpen = 0, false
    getgenv().MM2HubBind(RunService.RenderStepped, function(dt)
        if not isOpen and progress <= 0 then
            panel.Visible = false
            return
        end
        local goal = isOpen and 1 or 0
        if progress < goal then
            progress = math.min(goal, progress + dt * 4)
        elseif progress > goal then
            progress = math.max(goal, progress - dt * 4)
        end
        local eased = 1 - (1 - progress) ^ 3
        local x = rgbBorder.AbsolutePosition.X
        local w = rgbBorder.AbsoluteSize.X
        local y = rgbBorder.AbsolutePosition.Y + 40
        local hiddenX = x + w - 24
        local shownX = math.max(hiddenX, math.min(x + w + 8, workspace.CurrentCamera.ViewportSize.X - 200))
        panel.Position = UDim2.fromOffset(hiddenX + (shownX - hiddenX) * eased, y)
        panel.Visible = true
    end)

    local function openPanel()
        isOpen = true
        refresh()
    end

    -- EACH ROUND mode: Auto Coin runs from the round start until the round ends
    local function setCoinRunning(on)
        autoCoinOn = on
        if on and not coinRunning then
            coinRunning = true
            task.spawn(autoCoinLoop)
        end
    end
    local function setCoinRound(on)
        coinRoundMode = on
        settings.coinRound = on
        saveSettings()
        if on then
            if roundActive then setCoinRunning(true) end
            autoCoinBtn.Text = "🪙 AUTO COIN: EACH ROUND"
            setStatus("AUTO COIN (EACH ROUND) ON", COLOR_GOLD)
        else
            setCoinRunning(false)
            autoCoinBtn.Text = "🪙 AUTO COIN"
            setStatus("AUTO COIN (EACH ROUND) OFF")
        end
        setToggleVisual(autoCoinStroke, on)
    end
    table.insert(getgenv().MM2HubRoundStartFns, function()
        roundActive = true
        if coinRoundMode then setCoinRunning(true) end
    end)
    table.insert(getgenv().MM2HubRoundEndFns, function()
        roundActive = false
        if coinRoundMode and autoCoinOn then
            setCoinRunning(false)
            setStatus("Round ended, Auto Coin stopped", COLOR_GOLD)
        end
    end)
    if coinRoundMode then
        autoCoinBtn.Text = "🪙 AUTO COIN: EACH ROUND"
        setToggleVisual(autoCoinStroke, true)
        -- loaded mid-round: coins already on the map means a round is running right now
        task.defer(function()
            if #getCoins() > 0 then
                roundActive = true
                setCoinRunning(true)
            end
        end)
    end

    getgenv().MM2HubClick(autoCoinBtn, "MouseButton1Click", function()
        if isMobile then
            openPanel()
        else
            toggleCoin()
        end
        refresh()
    end)
    autoCoinBtn.MouseButton2Click:Connect(openPanel)
    getgenv().MM2HubClick(onOffBtn, "MouseButton1Click", function()
        toggleCoin()
        refresh()
    end)
    getgenv().MM2HubClick(waitBtn, "MouseButton1Click", function()
        settings.coinWait = not (settings.coinWait ~= false)
        saveSettings()
        refresh()
    end)
    getgenv().MM2HubClick(killBtn, "MouseButton1Click", function()
        settings.coinKillProtect = not settings.coinKillProtect
        saveSettings()
        refresh()
    end)
    getgenv().MM2HubClick(roundBtn, "MouseButton1Click", function()
        setCoinRound(not coinRoundMode)
        refresh()
    end)
    getgenv().MM2HubClick(doneBtn, "MouseButton1Click", function()
        isOpen = false
        saveSettings()
    end)
end

-- NO ANIM: stops every animation on your character (toggle)
do
    local on = settings.noAnim == true
    local noAnimBtn, noAnimStroke = makeButton(playerPage, "🚫 NO ANIM", 200, Color3.fromRGB(255, 90, 90))
    setToggleVisual(noAnimStroke, on)

    local function setAnimateDisabled(char, value)
        local animate = char and char:FindFirstChild("Animate")
        if animate and animate:IsA("LocalScript") then
            animate.Disabled = value
        end
    end

    getgenv().MM2HubBind(RunService.Heartbeat, function()
        if not on then return end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
        end
        setAnimateDisabled(char, true)
        if char then
            for _, m in ipairs(char:GetDescendants()) do
                if m:IsA("Motor6D") then
                    m.Transform = CFrame.new() -- stiff: no pose offset from any animation
                end
            end
        end
    end)

    getgenv().MM2HubClick(noAnimBtn, "MouseButton1Click", function()
        on = not on
        settings.noAnim = on
        saveSettings()
        setToggleVisual(noAnimStroke, on)
        if not on then
            setAnimateDisabled(player.Character, false)
        end
        setStatus(on and "NO ANIM ON" or "NO ANIM OFF")
    end)
end

-- ANTI FLING: lives in its own module (MM2_AntiFling.lua) so it can be updated separately
do
    local on = settings.antiFling == true
    local flingBtn, flingStroke = makeButton(playerPage, "🛡 ANTI FLING", 300, Color3.fromRGB(90, 200, 255))
    setToggleVisual(flingStroke, on)

    local base = getgenv().MM2HubBase or "https://raw.githubusercontent.com/crackalacka345/TakeDatRisk/main/"
    local AF = nil
    local okLoad, errLoad = pcall(function()
        AF = loadstring(game:HttpGet(base .. "MM2_AntiFling.lua?cb=" .. tostring(os.time())))()
    end)
    if not okLoad or not AF then
        AF = nil
        setStatus("Anti Fling module failed to load: " .. tostring(errLoad), COLOR_RED)
    else
        AF.setEnabled(on)
    end

    getgenv().MM2HubClick(flingBtn, "MouseButton1Click", function()
        on = not on
        settings.antiFling = on
        saveSettings()
        setToggleVisual(flingStroke, on)
        if AF then AF.setEnabled(on) end
        setStatus(on and "ANTI FLING ON" or "ANTI FLING OFF")
    end)
end

-- OPTIMIZER: removes textures and materials from the world (toggle, restores on off)
do
    local on = settings.optimizer == true
    local optBtn, optStroke = makeButton(playerPage, "⚙ OPTIMIZER", 250, Color3.fromRGB(120, 255, 160))
    setToggleVisual(optStroke, on)

    local saved = {} -- object -> original values

    local function strip(o)
        if saved[o] ~= nil then return end
        if o:IsA("BasePart") then
            local v = { kind = "part", material = o.Material }
            o.Material = Enum.Material.SmoothPlastic
            if o:IsA("MeshPart") then
                v.texture = o.TextureID
                o.TextureID = ""
            end
            saved[o] = v
        elseif o:IsA("Decal") or o:IsA("Texture") then
            saved[o] = { kind = "decal", transparency = o.Transparency }
            o.Transparency = 1
        elseif o:IsA("SpecialMesh") then
            saved[o] = { kind = "mesh", texture = o.TextureId }
            o.TextureId = ""
        elseif o:IsA("SurfaceAppearance") then
            saved[o] = { kind = "parent", parent = o.Parent }
            o.Parent = nil
        end
    end

    local function restoreAll()
        for o, v in pairs(saved) do
            pcall(function()
                if v.kind == "part" then
                    o.Material = v.material
                    if v.texture then o.TextureID = v.texture end
                elseif v.kind == "decal" then
                    o.Transparency = v.transparency
                elseif v.kind == "mesh" then
                    o.TextureId = v.texture
                elseif v.kind == "parent" then
                    o.Parent = v.parent
                end
            end)
            saved[o] = nil
        end
    end

    local function applyAll()
        local count = 0
        for _, o in ipairs(workspace:GetDescendants()) do
            pcall(strip, o)
            count = count + 1
            if count % 400 == 0 then
                task.wait()
            end
        end
    end

    getgenv().MM2HubBind(workspace.DescendantAdded, function(o)
        if on then
            pcall(strip, o)
        end
    end)

    getgenv().MM2HubClick(optBtn, "MouseButton1Click", function()
        on = not on
        settings.optimizer = on
        saveSettings()
        setToggleVisual(optStroke, on)
        if on then
            task.spawn(applyAll)
            setStatus("OPTIMIZER ON", COLOR_GREEN)
        else
            restoreAll()
            setStatus("OPTIMIZER OFF")
        end
    end)

    if on then
        task.spawn(applyAll)
    end
end

-- INVIS (camera can be moved with the mouse while invisible)
local invisActive = false
local invisSurface = nil
local invisCamCF = nil
local invisSinking = false
local invisRising = false
local wasInvisBeforeRespawn = false
local invisYaw, invisPitch = 0, 0

local function forceNoclipChar(char)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

local invisSavedCollide = {} -- [BasePart] = CanCollide before invis touched it

local function saveCollision(char)
    table.clear(invisSavedCollide)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            invisSavedCollide[p] = p.CanCollide
        end
    end
end

-- puts every part back exactly the way it was (the old version set EVERY part to
-- CanCollide = true, including accessories and R15 limbs, which made collision glitchy)
local function restoreCollision(char)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            local was = invisSavedCollide[p]
            if was ~= nil then
                p.CanCollide = was
            end
        end
    end
    table.clear(invisSavedCollide)
end

local function applyInvis(char)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    humanoid.PlatformStand = true
    invisSurface = hrp.Position.Y
    invisCamCF = camera.CFrame
    humanoid.CameraOffset = Vector3.new(0, 0, 0)
    saveCollision(char)
    forceNoclipChar(char)
    invisSinking = true

    local targetCF = CFrame.new(hrp.Position.X, hrp.Position.Y - INVIS_DEPTH, hrp.Position.Z) * (hrp.CFrame - hrp.CFrame.Position)
    local sinkTween = TweenService:Create(hrp, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = targetCF })
    sinkTween:Play()
    sinkTween.Completed:Connect(function()
        invisSinking = false
        if invisActive then
            humanoid.PlatformStand = false
        end
    end)
end

local function removeInvis(char)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    humanoid.PlatformStand = true
    invisRising = true
    invisCamCF = camera.CFrame
    local surfaceY = invisSurface or (hrp.Position.Y + INVIS_DEPTH)
    -- you may have walked somewhere with a different floor height: raycast down for the real floor
    do
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { char }
        local origin = Vector3.new(hrp.Position.X, surfaceY + 6, hrp.Position.Z)
        local hit = workspace:Raycast(origin, Vector3.new(0, -80, 0), params)
        if hit then
            local hipHeight = humanoid.HipHeight > 0 and humanoid.HipHeight or 2
            surfaceY = hit.Position.Y + hipHeight + hrp.Size.Y / 2 + 0.2
        end
    end
    local targetCF = CFrame.new(hrp.Position.X, surfaceY, hrp.Position.Z) * (hrp.CFrame - hrp.CFrame.Position)

    local riseTween = TweenService:Create(hrp, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = targetCF })
    riseTween:Play()
    riseTween.Completed:Connect(function()
        invisRising = false
        invisCamCF = nil
        invisSurface = nil
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        if char and char.Parent then
            restoreCollision(char)
            camera.CameraType = Enum.CameraType.Custom
        end
        if humanoid then
            humanoid.PlatformStand = false
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end)
end

getgenv().MM2HubClick(invisBtn, "MouseButton1Click", function()
    invisActive = not invisActive
    local char = player.Character
    if invisActive then
        local rx, ry = camera.CFrame:ToOrientation()
        invisPitch = math.clamp(rx, -1.3, 1.3)
        invisYaw = ry
        invisBtn.Text = "◌ SHOW SELF"
        setToggleVisual(invisStroke, true)
        wasInvisBeforeRespawn = true
        setStatus("INVIS ON", Color3.fromRGB(180, 80, 255))
        applyInvis(char)
    else
        invisBtn.Text = "◌ INVIS"
        setToggleVisual(invisStroke, false)
        wasInvisBeforeRespawn = false
        setStatus("INVIS OFF")
        removeInvis(char)
    end
end)

getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
    if invisActive and not invisSinking and not invisRising and input.UserInputType == Enum.UserInputType.MouseMovement then
        invisYaw = invisYaw - input.Delta.X * 0.004
        invisPitch = math.clamp(invisPitch - input.Delta.Y * 0.004, -1.3, 1.3)
    end
end)

player.CharacterAdded:Connect(function(char)
    if wasInvisBeforeRespawn and invisActive then
        task.wait(0.5)
        applyInvis(char)
    elseif not wasInvisBeforeRespawn then
        invisActive = false
        invisBtn.Text = "◌ INVIS"
        setToggleVisual(invisStroke, false)
    end
end)

getgenv().MM2HubBind(RunService.RenderStepped, function()
    if not invisActive and not invisSinking and not invisRising then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if invisSinking or invisRising then
        if invisCamCF then
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CFrame = invisCamCF
        end
    elseif invisActive then
        local hrpPos = hrp.Position
        local surfaceY = invisSurface or (hrpPos.Y + INVIS_DEPTH)
        local center = Vector3.new(hrpPos.X, surfaceY + 1.5, hrpPos.Z)
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.new(center) * CFrame.Angles(0, invisYaw, 0) * CFrame.Angles(invisPitch, 0, 0)
    end
end)

RunService.Stepped:Connect(function(_, dt)
    local char = player.Character
    if invisActive and not invisSinking and not invisRising and char then
        forceNoclipChar(char)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if hrp and humanoid then
            local targetY = (invisSurface or hrp.Position.Y) - INVIS_DEPTH + 3
            local diff = targetY - hrp.Position.Y
            if math.abs(diff) > 0.05 then
                hrp.CFrame = hrp.CFrame + Vector3.new(0, diff * math.min(dt * 20, 1), 0)
            end
        end
    end
end)

-- NOCLIP / INF JUMP
local noclip = false
local infiniteJump = false

local function setCollisionForChar(char, canCollide)
    if not char then return end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then part.CanCollide = canCollide end
    end
end

getgenv().MM2HubClick(noclipJumpBtn, "MouseButton1Click", function()
    noclip = not noclip
    infiniteJump = not infiniteJump
    if noclip then
        setStatus("NOCLIP / INF JUMP ON", Color3.fromRGB(0, 200, 180))
        setToggleVisual(noclipStroke, true)
        setCollisionForChar(player.Character, false)
    else
        setStatus("NOCLIP / INF JUMP OFF")
        setToggleVisual(noclipStroke, false)
        setCollisionForChar(player.Character, true)
    end
end)

RunService.Stepped:Connect(function()
    if noclip then
        setCollisionForChar(player.Character, false)
    end
end)

getgenv().MM2HubBind(UserInputService.JumpRequest, function()
    if infiniteJump then
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- ============================
-- GAMES: the whole tab lives in MM2_Games.lua (and MM2_Chess.lua) so the main hub stays small
-- ============================
do
    local base = getgenv().MM2HubBase or "https://raw.githubusercontent.com/crackalacka345/TakeDatRisk/main/"
    local okGames, errGames = pcall(function()
        local build = loadstring(game:HttpGet(base .. "MM2_Games.lua?cb=" .. tostring(os.time())))()
        build({
            base = base, gamesPage = gamesPage, player = player, playerGui = playerGui,
            makeButton = makeButton, setStatus = setStatus, saveSettings = saveSettings,
            settings = settings, corner = corner,
            getTheme = function() return activeFont, activeThemeDef end,
            COLOR_RED = COLOR_RED, COLOR_BLUE = COLOR_BLUE, COLOR_DIM = COLOR_DIM,
            COLOR_GOLD = COLOR_GOLD, COLOR_TEXT = COLOR_TEXT, COLOR_GREEN = COLOR_GREEN,
        })
    end)
    if not okGames then
        setStatus("Games module failed to load: " .. tostring(errGames), COLOR_RED)
    end
end


-- ============================
-- SETTINGS TAB
-- ============================
local bgLabel = Instance.new("TextLabel")
bgLabel.Size = UDim2.new(1, 0, 0, 18)
bgLabel.Position = UDim2.new(0, 0, 0, 0)
bgLabel.BackgroundTransparency = 1
bgLabel.Text = "BACKGROUND IMAGE ID"
bgLabel.TextColor3 = COLOR_DIM
bgLabel.TextScaled = true
bgLabel.Font = activeFont
bgLabel.TextXAlignment = Enum.TextXAlignment.Left
bgLabel.ZIndex = 3
bgLabel.Parent = settingsPage

local bgBox = Instance.new("TextBox")
bgBox.Size = UDim2.new(1, 0, 0, 32)
bgBox.Position = UDim2.new(0, 0, 0, 22)
bgBox.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
bgBox.BorderSizePixel = 0
bgBox.Text = settings.bgId or ""
bgBox.PlaceholderText = "Image asset ID (numbers only)"
bgBox.TextColor3 = COLOR_TEXT
bgBox.PlaceholderColor3 = Color3.fromRGB(90, 90, 120)
bgBox.TextScaled = true
bgBox.ClearTextOnFocus = false
bgBox.Font = activeFont
bgBox.ZIndex = 3
bgBox.Parent = settingsPage
corner(bgBox, 6)

local function applyBackground()
    -- a static image replaces any running animation
    local env = getgenv and getgenv() or nil
    if env and env.MM2HubGif then env.MM2HubGif.stop() end
    if env and env.MM2HubBg then env.MM2HubBg.stop() end
    local id = settings.bgId or ""
    bgImage.Image = (id ~= "") and ("rbxassetid://" .. id) or ""
end

-- filled in by the ANIMATED.. box (see BACKGROUND EXTRAS)
local animUI = {}

local applyBgBtn = makeButton(settingsPage, "🖼 APPLY BACKGROUND", 102, COLOR_GOLD)
local resetBgBtn = makeButton(settingsPage, "↺ RESET BACKGROUND", 202, COLOR_DIM)

getgenv().MM2HubClick(applyBgBtn, "MouseButton1Click", function()
    if animUI.box and animUI.box.Text ~= "" and animUI.play then
        animUI.play(animUI.box.Text)
        return
    end
    local ContentProvider = game:GetService("ContentProvider")
    -- takes the first number in what's typed, so a full library URL or "rbxassetid://123" also works
    local digits = bgBox.Text:match("(%d+)")
    if not digits then
        setStatus("Type an image ID (the number from the Roblox asset URL)", COLOR_RED)
        return
    end
    settings.bgId = digits
    bgBox.Text = digits
    applyBackground()
    saveSettings()
    setStatus("Loading background " .. digits .. "...", COLOR_GOLD)
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync({ bgImage })
        end)
        if bgImage.IsLoaded then
            setStatus("Background " .. digits .. " loaded", COLOR_GREEN)
        else
            setStatus("Background " .. digits .. " didn't load. It must be an Image asset ID.", COLOR_RED)
        end
    end)
end)

getgenv().MM2HubClick(resetBgBtn, "MouseButton1Click", function()
    settings.bgId = ""
    bgBox.Text = ""
    applyBackground()
    saveSettings()
    setStatus("Background reset")
end)

-- ============================
-- BACKGROUND EXTRAS: RANDOM button and the Animated.. box
-- ============================
do
    -- RANDOM picks one of these image/decal asset IDs.
    -- Paste Creator Store decal IDs (the number in the decal's URL) between the braces, separated by commas.
    local RANDOM_BG_IDS = {}

    local animBox = Instance.new("TextBox")
    animBox.Size = UDim2.new(1, 0, 0, 32)
    animBox.Position = UDim2.new(0, 0, 0, 62)
    animBox.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    animBox.BorderSizePixel = 0
    animBox.Text = ""
    animBox.PlaceholderText = "Animated.."
    animBox.TextColor3 = COLOR_TEXT
    animBox.PlaceholderColor3 = Color3.fromRGB(90, 90, 120)
    animBox.TextScaled = true
    animBox.ClearTextOnFocus = false
    animBox.Font = activeFont
    animBox.ZIndex = 3
    animBox.Parent = settingsPage
    corner(animBox, 6)

    animUI.box = animBox

    animUI.play = function(link)
        local env = getgenv and getgenv() or nil
        if not (env and env.MM2HubGif) then
            setStatus("Animated backgrounds need loader.lua", COLOR_RED)
            return
        end
        setStatus("Loading animated background...", COLOR_GOLD)
        task.spawn(function()
            local ok, msg = env.MM2HubGif.play(bgImage, link, 308, 462)
            if ok then
                setStatus("Animated background on (" .. msg .. ")", COLOR_GREEN)
            else
                setStatus(msg, COLOR_RED)
            end
        end)
    end

    animBox.FocusLost:Connect(function(enterPressed)
        if enterPressed and animBox.Text ~= "" then
            animUI.play(animBox.Text)
        end
    end)

    local randomBtn = makeButton(settingsPage, "🎲 RANDOM", 152, Color3.fromRGB(255, 120, 200))
    getgenv().MM2HubClick(randomBtn, "MouseButton1Click", function()
        if #RANDOM_BG_IDS == 0 then
            setStatus("Add decal IDs to RANDOM_BG_IDS in the script first", COLOR_RED)
            return
        end
        local id = tostring(RANDOM_BG_IDS[math.random(1, #RANDOM_BG_IDS)])
        bgBox.Text = id
        settings.bgId = id
        applyBackground()
        saveSettings()
        setStatus("Random background: " .. id, COLOR_GREEN)
    end)
end

do -- ANIMATED UI toggle
    local animBtn, animStroke = makeButton(settingsPage, "✨ ANIMATED UI", 402, Color3.fromRGB(0, 200, 180))
    setToggleVisual(animStroke, settings.animatedUI == true)
    getgenv().MM2HubClick(animBtn, "MouseButton1Click", function()
        settings.animatedUI = not settings.animatedUI
        setToggleVisual(animStroke, settings.animatedUI)
        saveSettings()
        setStatus(settings.animatedUI and "Animated UI on" or "Animated UI off", COLOR_GREEN)
    end)
    if settingsPage:IsA("ScrollingFrame") then
        settingsPage.CanvasSize = UDim2.new(0, 0, 0, 930)
    end
end

do -- 3D UI toggle: parallax window with a drop shadow and a glossy edge
    local btn3d, stroke3d = makeButton(settingsPage, "🧊 3D UI", 452, Color3.fromRGB(120, 200, 255))
    setToggleVisual(stroke3d, settings.ui3d == true)

    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow3D"
    shadow.BackgroundColor3 = Color3.new(0, 0, 0)
    shadow.BackgroundTransparency = 0.45
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 1
    shadow.Visible = false
    shadow.Parent = rgbBorder
    corner(shadow, 12)

    local gloss = Instance.new("UIStroke")
    gloss.Color = Color3.new(1, 1, 1)
    gloss.Thickness = 2
    gloss.Transparency = 0.6
    gloss.Enabled = false
    gloss.Parent = mainFrame

    getgenv().MM2HubBind(RunService.Heartbeat, function()
        if not settings.ui3d then
            shadow.Visible = false
            gloss.Enabled = false
            mainFrame.Position = UDim2.new(0, 4, 0, 4)
            return
        end
        shadow.Visible = true
        gloss.Enabled = true
        local mouse = UserInputService:GetMouseLocation()
        local half = rgbBorder.AbsoluteSize / 2
        local center = rgbBorder.AbsolutePosition + half
        local dx = math.clamp((mouse.X - center.X) / math.max(1, half.X), -1, 1)
        local dy = math.clamp((mouse.Y - center.Y) / math.max(1, half.Y), -1, 1)
        local ox, oy = -dx * 6, -dy * 6
        mainFrame.Position = UDim2.new(0, 4 + ox, 0, 4 + oy)
        shadow.Position = UDim2.new(0, 4 + ox + 8, 0, 4 + oy + 10)
        shadow.Size = mainFrame.Size
    end)

    getgenv().MM2HubClick(btn3d, "MouseButton1Click", function()
        settings.ui3d = not settings.ui3d
        saveSettings()
        setToggleVisual(stroke3d, settings.ui3d)
        setStatus(settings.ui3d and "3D UI on" or "3D UI off", COLOR_GREEN)
    end)
end

local themeBtn = makeButton(settingsPage, "🎨 THEME", 252, Color3.fromRGB(255, 120, 0))
local fontBtn = makeButton(settingsPage, "🔤 FONT", 302, Color3.fromRGB(180, 80, 255))

local function cycleValue(list, current)
    for i, v in ipairs(list) do
        if v == current then
            return list[(i % #list) + 1]
        end
    end
    return list[1]
end

local function updateChoiceLabels()
    local key = currentThemeKey()
    local themeText = settings.themeChoice == "AUTO" and ("AUTO (" .. key .. ")") or settings.themeChoice
    themeBtn.Text = "🎨 THEME: " .. themeText
    fontBtn.Text = "🔤 FONT: " .. settings.fontChoice
end

getgenv().MM2HubClick(themeBtn, "MouseButton1Click", function()
    settings.themeChoice = cycleValue(THEME_ORDER, settings.themeChoice)
    saveSettings()
    applyAll()
end)

getgenv().MM2HubClick(fontBtn, "MouseButton1Click", function()
    settings.fontChoice = cycleValue(FONT_ORDER, settings.fontChoice)
    saveSettings()
    applyAll()
end)

local settingsInfo = Instance.new("TextLabel")
settingsInfo.Size = UDim2.new(1, 0, 0, 40)
settingsInfo.Position = UDim2.new(0, 0, 0, 352)
settingsInfo.BackgroundTransparency = 1
settingsInfo.Text = "AUTO theme follows the month: Oct Halloween, Nov Thanksgiving, Dec Christmas, Jan New Year."
settingsInfo.TextColor3 = COLOR_DIM
settingsInfo.TextScaled = true
settingsInfo.TextWrapped = true
settingsInfo.Font = activeFont
settingsInfo.ZIndex = 3
settingsInfo.Parent = settingsPage

-- ============================
-- APPLY THEME
-- ============================
applyAll = function()
    local key = currentThemeKey()
    local theme = THEMES[key] or THEMES.DEFAULT
    activeThemeDef = theme

    if settings.fontChoice == "AUTO" or not FONT_CHOICES[settings.fontChoice] then
        activeFont = theme.font
    else
        activeFont = FONT_CHOICES[settings.fontChoice]
    end

    rgbCycle = theme.cycle == true
    rgbColors = theme.border
    mainFrame.BackgroundColor3 = theme.bg
    accentDot.BackgroundColor3 = theme.accent

    for _, d in ipairs(mainFrame:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            d.Font = activeFont
        end
    end
    for _, d in ipairs(scrollingFrame:GetDescendants()) do
        if d:IsA("TextLabel") then d.Font = activeFont end
    end

    setTab(activeTab)
    updateChoiceLabels()
    startDecor(theme.deco)
end

-- ============================
-- ANIMATION (border + accent dot)
-- ============================
local gradAngle = 0
getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
    gradAngle = (gradAngle + dt * 60) % 360
    local t = tick()
    rgbGrad.Rotation = gradAngle

    if rgbCycle then
        rgbGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV((t * 0.15) % 1, 1, 1)),
            ColorSequenceKeypoint.new(0.5, Color3.fromHSV((t * 0.15 + 0.33) % 1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV((t * 0.15 + 0.66) % 1, 1, 1)),
        })
    else
        rgbGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, rgbColors[1]),
            ColorSequenceKeypoint.new(0.5, rgbColors[2]),
            ColorSequenceKeypoint.new(1, rgbColors[3]),
        })
    end

    local pulse = math.sin(t * 4) * 0.5 + 0.5
    accentDot.Size = UDim2.new(0, 5 + pulse * 2, 0, 5 + pulse * 2)
    accentDot.Position = UDim2.new(0, 16 - pulse, 0.5, -3 - pulse)
end)

-- ============================
-- MODULES TAB: add modules from a GitHub repo
--   paste github.com/user/repo -> every *.module / *.module.lua file in it is listed,
--   pick one, pick a category, press ADD MODULE
-- ============================
-- (wrapped in a function so its locals do not count toward the main chunk's 200 local limit)
;(function()
    local page = pages.MODULES
    local BG = Color3.fromRGB(24, 24, 36)
    local PANEL = Color3.fromRGB(18, 18, 28)
    local ACCENT = THEMES.DEFAULT.accent
    local LIST_H = 170

    local function pretty(name)
        if name == "ESP" or name == "UI" then return name end
        return name:sub(1, 1) .. name:sub(2):lower()
    end

    -- textbox
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 32)
    box.BackgroundColor3 = BG
    box.BorderSizePixel = 0
    box.PlaceholderText = "github.com/gituser/reponame"
    box.PlaceholderColor3 = Color3.fromRGB(90, 90, 120)
    box.Text = ""
    box.TextColor3 = COLOR_TEXT
    box.TextSize = 14
    box.Font = activeFont
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ZIndex = 4
    box.Parent = page
    corner(box, 8)
    local boxPad = Instance.new("UIPadding")
    boxPad.PaddingLeft = UDim.new(0, 10)
    boxPad.PaddingRight = UDim.new(0, 10)
    boxPad.Parent = box
    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = ACCENT
    boxStroke.Thickness = 1.2
    boxStroke.Transparency = 0.6
    boxStroke.Parent = box

    local info = Instance.new("TextLabel")
    info.Position = UDim2.fromOffset(2, 36)
    info.Size = UDim2.new(1, -4, 0, 16)
    info.BackgroundTransparency = 1
    info.Text = "Paste a GitHub repo link"
    info.TextColor3 = COLOR_DIM
    info.TextSize = 12
    info.Font = activeFont
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextTruncate = Enum.TextTruncate.AtEnd
    info.ZIndex = 4
    info.Parent = page

    local function mkButton(text, pos, size, color)
        local b = Instance.new("TextButton")
        b.Position = pos
        b.Size = size
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.TextSize = 14
        b.Font = activeFont
        b.ZIndex = 4
        b.Parent = page
        corner(b, 8)
        return b
    end

    local addBtn = mkButton("ADD MODULE", UDim2.fromOffset(0, 56), UDim2.new(0.6, -4, 0, 34), ACCENT)
    local catBtn = mkButton("CATEGORY ▾", UDim2.new(0.6, 0, 0, 56), UDim2.new(0.4, 0, 0, 34), BG)

    -- state
    local files = {}           -- detected module files of the current repo
    local pending = nil        -- the selected file, ready to add
    local category = nil
    local listOpen = false
    local lastRepoKey = nil
    local searchGen = 0

    -- selected-file bar + file list (same spot; one is open at a time)
    local selectedBar = Instance.new("TextButton")
    selectedBar.Position = UDim2.fromOffset(0, 98)
    selectedBar.Size = UDim2.new(1, 0, 0, 34)
    selectedBar.BackgroundColor3 = PANEL
    selectedBar.BorderSizePixel = 0
    selectedBar.AutoButtonColor = false
    selectedBar.Text = ""
    selectedBar.TextColor3 = COLOR_GREEN
    selectedBar.TextSize = 13
    selectedBar.Font = activeFont
    selectedBar.TextXAlignment = Enum.TextXAlignment.Left
    selectedBar.TextTruncate = Enum.TextTruncate.AtEnd
    selectedBar.Visible = false
    selectedBar.ZIndex = 5
    selectedBar.Parent = page
    corner(selectedBar, 8)
    local selPad = Instance.new("UIPadding")
    selPad.PaddingLeft = UDim.new(0, 10)
    selPad.PaddingRight = UDim.new(0, 10)
    selPad.Parent = selectedBar

    local list = Instance.new("ScrollingFrame")
    list.Position = UDim2.fromOffset(0, 98)
    list.Size = UDim2.new(1, 0, 0, 0)
    list.BackgroundColor3 = PANEL
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.ScrollBarImageColor3 = ACCENT
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new()
    list.ClipsDescendants = true
    list.Visible = false
    list.ZIndex = 5
    list.Parent = page
    corner(list, 8)
    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 6)
    listPad.PaddingBottom = UDim.new(0, 6)
    listPad.PaddingLeft = UDim.new(0, 6)
    listPad.PaddingRight = UDim.new(0, 8)
    listPad.Parent = list
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = list

    local function setList(open)
        listOpen = open
        if open then
            selectedBar.Visible = false
            list.Visible = true
            TweenService:Create(list, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.new(1, 0, 0, LIST_H) }):Play()
        else
            TweenService:Create(list, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Size = UDim2.new(1, 0, 0, 0) }):Play()
            task.delay(0.22, function()
                if not listOpen then
                    list.Visible = false
                    selectedBar.Visible = pending ~= nil
                end
            end)
        end
    end

    local function setInfo(text, color)
        info.Text = text
        info.TextColor3 = color or COLOR_DIM
    end

    local function fileName(path)
        return path:match("([^/]+)$") or path
    end

    local function selectFile(file)
        pending = file
        selectedBar.Text = "✔ " .. file.path
        setInfo("Ready: " .. fileName(file.path) .. (category and (" → " .. pretty(category)) or " (pick a category)"), COLOR_GREEN)
        setList(false) -- selecting closes the list
    end

    local function fillList()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for i, file in ipairs(files) do
            local row = Instance.new("TextButton")
            row.LayoutOrder = i
            row.Size = UDim2.new(1, 0, 0, 30)
            row.BackgroundColor3 = BG
            row.BorderSizePixel = 0
            row.AutoButtonColor = false
            row.Text = file.path
            row.TextColor3 = COLOR_TEXT
            row.TextSize = 13
            row.Font = activeFont
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextTruncate = Enum.TextTruncate.AtEnd
            row.ZIndex = 6
            row.Parent = list
            corner(row, 6)
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 8)
            pad.PaddingRight = UDim.new(0, 8)
            pad.Parent = row
            row.MouseEnter:Connect(function()
                TweenService:Create(row, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(40, 40, 62) }):Play()
            end)
            row.MouseLeave:Connect(function()
                TweenService:Create(row, TweenInfo.new(0.1), { BackgroundColor3 = BG }):Play()
            end)
            getgenv().MM2HubClick(row, "MouseButton1Click", function()
                selectFile(file)
            end)
        end
    end

    getgenv().MM2HubClick(selectedBar, "MouseButton1Click", function()
        if #files > 0 then setList(true) end -- tap the selection to pick a different file
    end)

    -- link parsing: github.com/user/repo, https://github.com/user/repo.git, .../tree/branch, user/repo
    local function parseRepo(text)
        text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then return nil end
        local t = text:gsub("^https?://", ""):gsub("^www%.", "")
        local rest = t:match("^github%.com/(.+)$")
        if not rest and t:match("^[%w%-_%.]+/[%w%-_%.]+$") then rest = t end
        if not rest then return nil end
        local user, repo, tail = rest:match("^([%w%-_%.]+)/([%w%-_%.]+)(.*)$")
        if not user then return nil end
        repo = repo:gsub("%.git$", "")
        if repo == "" then return nil end
        local branch = tail and (tail:match("^/tree/(.+)$") or tail:match("^/blob/(.+)$"))
        if branch then branch = branch:gsub("/+$", "") end
        return user, repo, branch
    end

    local function isModuleFile(path)
        local lower = path:lower()
        return lower:match("%.module$") ~= nil
            or lower:match("%.module%.lua$") ~= nil
            or lower:match("%.module%.luau$") ~= nil
    end

    local function apiGet(url)
        local ok, body = pcall(game.HttpGet, game, url)
        if not ok or type(body) ~= "string" then return nil, "Couldn't reach GitHub (rate limit?)" end
        local okJ, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not okJ or type(data) ~= "table" then return nil, "GitHub sent something unreadable" end
        return data
    end

    -- branchPath: nil (default branch) or "branch" / "branch/sub/folder" from a /tree/ link.
    -- Branch names can contain "/", so the longest prefix that is a real branch wins;
    -- whatever is left over is a folder inside the repo (only modules in it are listed).
    local function fetchModules(user, repo, branchPath)
        local base = "https://api.github.com/repos/" .. user .. "/" .. repo
        local branch, folder, tree, err
        if not branchPath then
            local data, e = apiGet(base)
            if not data then return nil, e end
            if not data.default_branch then return nil, "Repo not found" end
            branch = data.default_branch
            tree, err = apiGet(base .. "/git/trees/" .. branch .. "?recursive=1")
        else
            local segs = {}
            for seg in branchPath:gmatch("[^/]+") do table.insert(segs, seg) end
            for k = #segs, 1, -1 do
                local try = table.concat(segs, "/", 1, k)
                local t, e = apiGet(base .. "/git/trees/" .. try:gsub("[^%w%-_%./]", function(c)
                    return string.format("%%%02X", c:byte())
                end) .. "?recursive=1")
                if t and type(t.tree) == "table" then
                    branch, tree = try, t
                    if k < #segs then folder = table.concat(segs, "/", k + 1) end
                    break
                end
                err = e
            end
        end
        if not tree then return nil, err or "Repo or branch not found" end
        if type(tree.tree) ~= "table" then return nil, "Repo or branch not found" end
        local found = {}
        for _, item in ipairs(tree.tree) do
            if item.type == "blob" and type(item.path) == "string" and isModuleFile(item.path)
                and (not folder or item.path:sub(1, #folder + 1) == folder .. "/") then
                local encoded = item.path:gsub("[^%w%-_%./]", function(c)
                    return string.format("%%%02X", c:byte())
                end)
                local encBranch = branch:gsub("[^%w%-_%./]", function(c)
                    return string.format("%%%02X", c:byte())
                end)
                table.insert(found, {
                    user = user, repo = repo, branch = branch, path = item.path,
                    url = "https://raw.githubusercontent.com/" .. user .. "/" .. repo .. "/" .. encBranch .. "/" .. encoded,
                })
            end
        end
        table.sort(found, function(x, y) return x.path:lower() < y.path:lower() end)
        return found
    end

    local function search(force)
        local user, repo, branch = parseRepo(box.Text)
        if not user then
            if box.Text:gsub("%s", "") ~= "" and force then
                setInfo("Use a link like github.com/user/repo", COLOR_RED)
            end
            return
        end
        local key = (user .. "/" .. repo .. "@" .. tostring(branch)):lower()
        if key == lastRepoKey and not force then return end
        lastRepoKey = key
        searchGen = searchGen + 1
        local gen = searchGen
        pending = nil
        selectedBar.Visible = false
        setInfo("Fetching " .. user .. "/" .. repo .. "...", COLOR_GOLD)
        task.spawn(function()
            local found, err = fetchModules(user, repo, branch)
            if gen ~= searchGen then return end -- the link changed while we were fetching
            if not found then
                files = {}
                lastRepoKey = nil
                fillList()
                setList(false)
                setInfo(err or "Couldn't read that repo", COLOR_RED)
                return
            end
            files = found
            fillList()
            if #found == 0 then
                setList(false)
                setInfo("No .module files found in " .. user .. "/" .. repo, COLOR_RED)
            else
                setInfo("Found " .. #found .. " module file" .. (#found == 1 and "" or "s") .. ": pick one", COLOR_GREEN)
                setList(true)
            end
        end)
    end

    -- retrieves automatically shortly after typing/pasting stops (or instantly on Enter / leaving the box)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        local gen = searchGen
        local snapshot = box.Text
        task.delay(0.8, function()
            if box.Text == snapshot and searchGen == gen then search(false) end
        end)
    end)
    box.FocusLost:Connect(function()
        search(true)
    end)

    -- category dropdown: slides down under the CATEGORY button
    local cats = {}
    for _, name in ipairs(TAB_NAMES) do
        if name ~= "MODULES" and name ~= "MY MODULES" then table.insert(cats, name) end
    end
    local ROW_H = 28
    local DROP_H = #cats * ROW_H + 8

    local drop = Instance.new("Frame")
    drop.Position = UDim2.new(0.6, 0, 0, 94)
    drop.Size = UDim2.new(0.4, 0, 0, 0)
    drop.BackgroundColor3 = PANEL
    drop.BorderSizePixel = 0
    drop.ClipsDescendants = true
    drop.Visible = false
    drop.ZIndex = 20
    drop.Parent = page
    corner(drop, 8)
    local dropStroke = Instance.new("UIStroke")
    dropStroke.Color = ACCENT
    dropStroke.Thickness = 1.2
    dropStroke.Transparency = 0.4
    dropStroke.Parent = drop
    local dropLayout = Instance.new("UIListLayout")
    dropLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dropLayout.Padding = UDim.new(0, 0)
    dropLayout.Parent = drop
    local dropPad = Instance.new("UIPadding")
    dropPad.PaddingTop = UDim.new(0, 4)
    dropPad.PaddingLeft = UDim.new(0, 4)
    dropPad.PaddingRight = UDim.new(0, 4)
    dropPad.Parent = drop

    local dropOpen = false
    local function setDrop(open)
        dropOpen = open
        catBtn.Text = (category and pretty(category) or "CATEGORY") .. (open and " ▴" or " ▾")
        if open then
            drop.Visible = true
            TweenService:Create(drop, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.new(0.4, 0, 0, DROP_H) }):Play()
        else
            TweenService:Create(drop, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Size = UDim2.new(0.4, 0, 0, 0) }):Play()
            task.delay(0.22, function()
                if not dropOpen then drop.Visible = false end
            end)
        end
    end

    for i, name in ipairs(cats) do
        local row = Instance.new("TextButton")
        row.LayoutOrder = i
        row.Size = UDim2.new(1, 0, 0, ROW_H)
        row.BackgroundTransparency = 1
        row.BackgroundColor3 = Color3.fromRGB(40, 40, 62)
        row.BorderSizePixel = 0
        row.AutoButtonColor = false
        row.Text = pretty(name)
        row.TextColor3 = COLOR_TEXT
        row.TextSize = 14
        row.Font = activeFont
        row.ZIndex = 21
        row.Parent = drop
        corner(row, 6)
        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.1), { BackgroundTransparency = 0 }):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.1), { BackgroundTransparency = 1 }):Play()
        end)
        getgenv().MM2HubClick(row, "MouseButton1Click", function()
            category = name
            setDrop(false)
            if pending then
                setInfo("Ready: " .. fileName(pending.path) .. " → " .. pretty(category), COLOR_GREEN)
            end
        end)
    end

    getgenv().MM2HubClick(catBtn, "MouseButton1Click", function()
        setDrop(not dropOpen)
    end)

    -- ADD MODULE: checks that the selected file downloads and compiles, then saves it with its category
    local adding = false
    getgenv().MM2HubClick(addBtn, "MouseButton1Click", function()
        if adding then return end
        if not pending then
            setStatus("Select a module file first", COLOR_RED)
            return
        end
        if not category then
            setStatus("Pick a category first", COLOR_RED)
            setDrop(true)
            return
        end
        adding = true
        local file = pending
        local cat = category
        setInfo("Downloading " .. fileName(file.path) .. "...", COLOR_GOLD)
        task.spawn(function()
            local ok, src = pcall(game.HttpGet, game, file.url)
            if not ok or type(src) ~= "string" or #src < 5 or src:sub(1, 3) == "404" then
                setInfo("Couldn't download that file", COLOR_RED)
                adding = false
                return
            end
            local fn, err = loadstring(src)
            if not fn then
                warn("MM2 Hub: module syntax error: " .. tostring(err))
                setInfo("That module has a syntax error", COLOR_RED)
                adding = false
                return
            end
            settings.customModules = type(settings.customModules) == "table" and settings.customModules or {}
            local replaced = false
            for _, m in ipairs(settings.customModules) do
                if m.url == file.url then
                    m.category = cat
                    replaced = true
                end
            end
            if not replaced then
                table.insert(settings.customModules, {
                    user = file.user, repo = file.repo, branch = file.branch,
                    path = file.path, url = file.url, category = cat,
                })
            end
            saveSettings()
            if getgenv().MM2HubRefreshMyModules then pcall(getgenv().MM2HubRefreshMyModules) end
            setInfo("Added " .. fileName(file.path) .. " → " .. pretty(cat), COLOR_GREEN)
            setStatus("Module added: " .. fileName(file.path) .. " → " .. pretty(cat), COLOR_GREEN)
            adding = false
        end)
    end)
end)()

-- ============================
-- MY MODULES TAB: the modules added in the MODULES tab (tap X to remove one)
-- ============================
;(function()
    local page = pages["MY MODULES"]
    local BG = Color3.fromRGB(24, 24, 36)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = page

    local function refresh()
        for _, c in ipairs(page:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        local mods = type(settings.customModules) == "table" and settings.customModules or {}
        if #mods == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 0, 34)
            empty.BackgroundTransparency = 1
            empty.Text = "No modules yet. Add one in the MODULES tab."
            empty.TextColor3 = COLOR_DIM
            empty.TextSize = 13
            empty.Font = activeFont
            empty.TextWrapped = true
            empty.ZIndex = 4
            empty.Parent = page
            return
        end
        for i, m in ipairs(mods) do
            local row = Instance.new("Frame")
            row.LayoutOrder = i
            row.Size = UDim2.new(1, -6, 0, 44)
            row.BackgroundColor3 = BG
            row.BackgroundTransparency = 0.2
            row.BorderSizePixel = 0
            row.ZIndex = 3
            row.Parent = page
            corner(row, 8)
            local stroke = Instance.new("UIStroke")
            stroke.Color = THEMES.DEFAULT.accent
            stroke.Thickness = 1.2
            stroke.Transparency = 0.6
            stroke.Parent = row

            local name = Instance.new("TextLabel")
            name.Position = UDim2.fromOffset(12, 4)
            name.Size = UDim2.new(1, -52, 0, 20)
            name.BackgroundTransparency = 1
            name.Text = tostring(m.path or ""):match("([^/]+)$") or "module"
            name.TextColor3 = COLOR_TEXT
            name.TextSize = 14
            name.Font = activeFont
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.TextTruncate = Enum.TextTruncate.AtEnd
            name.ZIndex = 4
            name.Parent = row

            local sub = name:Clone()
            sub.Position = UDim2.fromOffset(12, 24)
            sub.Size = UDim2.new(1, -52, 0, 16)
            local cat = tostring(m.category or "")
            sub.Text = tostring(m.user) .. "/" .. tostring(m.repo) .. "  •  " .. cat:sub(1, 1) .. cat:sub(2):lower()
            sub.TextColor3 = COLOR_DIM
            sub.TextSize = 12
            sub.Parent = row

            local del = Instance.new("TextButton")
            del.Position = UDim2.new(1, -36, 0.5, -14)
            del.Size = UDim2.fromOffset(28, 28)
            del.BackgroundColor3 = Color3.fromRGB(40, 30, 38)
            del.BorderSizePixel = 0
            del.AutoButtonColor = false
            del.Text = "✕"
            del.TextColor3 = COLOR_RED
            del.TextSize = 14
            del.Font = activeFont
            del.ZIndex = 4
            del.Parent = row
            corner(del, 6)
            getgenv().MM2HubClick(del, "MouseButton1Click", function()
                table.remove(mods, i)
                saveSettings()
                setStatus("Module removed: " .. tostring(name.Text), COLOR_DIM)
                refresh()
            end)
        end
    end
    getgenv().MM2HubRefreshMyModules = refresh
    refresh()
end)()

-- ============================
-- START
-- ============================
applyBackground()
applyAll()
setTab("ESP")

-- loading screen: reveal the window once everything is built
if loadingFinish then
    loadingFinish(function()
        -- SAVE UI's: if the last run ended on WindUI / VapeUI, that UI opens instead of this one
        local ui = getgenv().MM2HubUI
        if ui and ui.autoLaunch() then return end
        rgbBorder.Visible = true
        getgenv().MM2HubShown = true
    end)
end

-- ANIMATED BACKGROUND: started only when loader.lua provided the module
;(function()
    local env = getgenv and getgenv()
    if env and env.MM2HubBg then
        task.spawn(function()
            env.MM2HubBg.start(bgImage)
        end)
    end
end)()

-- MOBILE: fits the window to small screens and adds a floating MM2 button (no keyboard on phones)
;(function()
    local UIS = game:GetService("UserInputService")
    local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
    if not isMobile then return end

    local function fitNow()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local fit = math.min(1, (vp.X - 16) / 316, (vp.Y - 70) / 478)
        getgenv().MM2HubFit = math.max(0.5, fit)
        rgbBorder.Position = UDim2.new(0.5, -158, 0, 44)
        uiScale.Scale = (settings.uiScale or 1) * getgenv().MM2HubFit
    end
    fitNow()
    task.spawn(function()
        while not workspace.CurrentCamera do task.wait() end
        getgenv().MM2HubBind(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fitNow)
    end)

    local btn = Instance.new("TextButton")
    btn.Name = "MM2HubMobileToggle"
    btn.Size = UDim2.fromOffset(48, 48)
    btn.Position = UDim2.new(1, -58, 0.5, -24)
    btn.BackgroundColor3 = Color3.fromRGB(255, 0, 128)
    btn.BorderSizePixel = 0
    btn.Text = "MM2"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.ZIndex = 50
    btn.Parent = screenGui
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = btn

    getgenv().MM2HubClick(btn, "MouseButton1Click", function()
        if not getgenv().MM2HubShown then return end
        rgbBorder.Visible = not rgbBorder.Visible
    end)
end)()

-- UI SWITCHER: WindUI / VapeUI versions of the hub, and SAVE UI's (remembers the pick between runs).
-- Exposed as getgenv().MM2HubUI, so the WindUI and VapeUI hubs can switch, save and reset too.
-- (one block, no new top-level locals)
do
    local G = getgenv()
    local UI_FILES = {
        WIND = { file = "MM2_Hub_WindUI.lua", name = "WindUI" },
        VAPE = { file = "MM2_Hub_VapeUI.lua", name = "VapeUI" },
    }
    G.MM2HubUICurrent = "MAIN"
    local api = {}

    function api.current() return G.MM2HubUICurrent or "MAIN" end
    function api.saveOn() return settings.saveUI == true end
    function api.toggleKey() return settings.toggleKey or "RightShift" end

    -- downloads and compiles a UI file; returns the function, or nil and a message
    local function prepare(key)
        local info = UI_FILES[key]
        local base = G.MM2HubBase or "https://raw.githubusercontent.com/crackalacka345/TakeDatRisk/main/"
        local okSrc, src = pcall(game.HttpGet, game, base .. info.file .. "?cb=" .. tostring(os.time()))
        if not okSrc or type(src) ~= "string" or #src < 200 then
            return nil, "Couldn't download the " .. info.name .. " hub"
        end
        local fn, err = loadstring(src)
        if not fn then
            warn(info.name .. " hub syntax error: " .. tostring(err))
            return nil, info.name .. " hub has a syntax error"
        end
        return fn
    end

    -- puts the original hub back; the updater reloads it from the files already in memory
    local function openMain()
        if not G.MM2HubRestart then return false, "Going back needs loader.lua" end
        local ok, msg = G.MM2HubRestart()
        if not ok then return false, tostring(msg) end
        return true, "Original UI loaded"
    end

    -- key = "MAIN", "WIND" or "VAPE". silent = don't remember it (used by the auto launch).
    -- Returns ok, message. With SAVE UI's on, the pick is saved so the next run opens it.
    function api.switch(key, silent)
        if key ~= "MAIN" and not UI_FILES[key] then return false, "Unknown UI" end
        if key == api.current() then return true, "Already on that UI" end
        local fn
        if key ~= "MAIN" then
            local err
            fn, err = prepare(key)
            if not fn then return false, err end
        end
        if settings.saveUI and not silent then
            settings.savedUI = key
            saveSettings()
        end
        local previous = api.current()
        G.MM2HubUICurrent = key
        task.spawn(function()
            if key == "MAIN" then
                local ok, msg = openMain()
                if not ok then
                    G.MM2HubUICurrent = previous
                    warn("MM2 Hub: couldn't go back to the original UI: " .. tostring(msg))
                end
                return
            end
            if G.MM2HubTeardown then G.MM2HubTeardown() end
            if G.MM2HubWindUIClose then pcall(G.MM2HubWindUIClose) end
            if G.MM2HubVapeUIClose then pcall(G.MM2HubVapeUIClose) end
            local ok, e = pcall(fn)
            if not ok then
                -- the new UI crashed while starting: bring the original one back (and don't auto launch it again this run)
                warn(UI_FILES[key].name .. " hub error: " .. tostring(e))
                G.MM2HubUICurrent = "MAIN"
                G.MM2HubSkipAutoUI = true
                G.MM2HubNotice = UI_FILES[key].name .. " failed to start, restored the original UI"
                if G.MM2HubRestart then pcall(G.MM2HubRestart) end
            end
        end)
        return true, "Switching..."
    end

    -- SAVE UI's: on = the UI you switch to is remembered and opens next run
    function api.setSave(on)
        settings.saveUI = on and true or false
        settings.savedUI = on and api.current() or nil
        saveSettings()
    end

    -- RESET: forget the saved UI and go back to the original one
    function api.reset()
        settings.savedUI = nil
        saveSettings()
        if api.current() ~= "MAIN" then
            local ok, msg = api.switch("MAIN", true)
            if ok then return true, "Back to the original UI" end
            return false, msg
        end
        return true, "Saved UI cleared"
    end

    -- called once the hub has loaded: opens the saved UI instead of the original one. true = it did.
    function api.autoLaunch()
        if G.MM2HubSkipAutoUI then
            G.MM2HubSkipAutoUI = nil
            return false
        end
        local want = settings.saveUI and settings.savedUI
        if not want or not UI_FILES[want] then return false end
        local ok, msg = api.switch(want, true)
        if not ok then
            G.MM2HubNotice = tostring(msg)
            return false
        end
        return true
    end

    G.MM2HubUI = api

    -- UI TAB buttons
    local windBtn = makeButton(pages.UI, "🪟 WINDUI HUB", 0, Color3.fromRGB(120, 200, 255))
    getgenv().MM2HubClick(windBtn, "MouseButton1Click", function()
        setStatus("Loading WindUI hub...", COLOR_BLUE)
        local ok, msg = api.switch("WIND")
        if not ok then setStatus(msg, COLOR_RED) end
    end)

    local vapeBtn = makeButton(pages.UI, "💨 VapeUI", 54, Color3.fromRGB(40, 220, 170))
    getgenv().MM2HubClick(vapeBtn, "MouseButton1Click", function()
        setStatus("Loading VapeUI hub...", COLOR_BLUE)
        local ok, msg = api.switch("VAPE")
        if not ok then setStatus(msg, COLOR_RED) end
    end)
end

-- SETTINGS: SAVE UI's (toggle) and RESET, side by side
do
    local api = getgenv().MM2HubUI
    local saveBtn, saveStroke = makeButton(settingsPage, "💾 SAVE UI's: OFF", 806, COLOR_GREEN)
    local resetBtn = makeButton(settingsPage, "↺ RESET", 806, COLOR_RED)
    saveBtn.Parent.Size = UDim2.new(0.62, -4, 0, 44)
    resetBtn.Parent.Size = UDim2.new(0.38, -4, 0, 44)
    resetBtn.Parent.Position = UDim2.new(0.62, 4, 0, 806)

    local function refreshSave()
        local on = api.saveOn()
        saveBtn.Text = on and "💾 SAVE UI's: ON" or "💾 SAVE UI's: OFF"
        setToggleVisual(saveStroke, on)
    end
    refreshSave()

    getgenv().MM2HubClick(saveBtn, "MouseButton1Click", function()
        api.setSave(not api.saveOn())
        refreshSave()
        setStatus(api.saveOn() and "SAVE UI's on: the UI you switch to opens next run" or "SAVE UI's off", COLOR_GREEN)
    end)
    getgenv().MM2HubClick(resetBtn, "MouseButton1Click", function()
        local _, msg = api.reset()
        refreshSave()
        setStatus(tostring(msg), COLOR_GOLD)
    end)
end

-- SETTINGS: main GUI key, version changer, refresh (one block, no new top-level locals)
;(function()
    settings.toggleKey = settings.toggleKey or "RightShift"

    local function keyFromName(text)
        local want = string.lower((tostring(text or ""):gsub("%s", "")))
        for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
            if string.lower(item.Name) == want then return item end
        end
        return nil
    end

    local function settingLabel(text, y)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 16)
        l.Position = UDim2.new(0, 0, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = COLOR_DIM
        l.TextScaled = true
        l.Font = activeFont
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 3
        l.Parent = settingsPage
        return l
    end

    local function settingBox(placeholder, text, y)
        local b = Instance.new("TextBox")
        b.Size = UDim2.new(1, 0, 0, 32)
        b.Position = UDim2.new(0, 0, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
        b.BorderSizePixel = 0
        b.Text = text
        b.PlaceholderText = placeholder
        b.TextColor3 = COLOR_TEXT
        b.PlaceholderColor3 = Color3.fromRGB(90, 90, 120)
        b.TextScaled = true
        b.ClearTextOnFocus = false
        b.Font = activeFont
        b.ZIndex = 3
        b.Parent = settingsPage
        corner(b, 6)
        return b
    end

    -- MAIN GUI KEY: press the button, then press the key to use as the toggle
    local waitingKey = false
    local keyBtn = makeButton(settingsPage, "⌨ MAIN GUI KEY: " .. settings.toggleKey, 500, COLOR_GOLD)
    getgenv().MM2HubClick(keyBtn, "MouseButton1Click", function()
        waitingKey = true
        keyBtn.Text = "Click a key to set as toggle"
        setStatus("Click a key to set as toggle (Esc cancels)", COLOR_GOLD)
    end)
    getgenv().MM2HubBind(UserInputService.InputBegan, function(input, gp)
        if waitingKey then
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            waitingKey = false
            if input.KeyCode ~= Enum.KeyCode.Escape then
                settings.toggleKey = input.KeyCode.Name
                saveSettings()
                setStatus("Main GUI key: " .. settings.toggleKey, COLOR_GREEN)
            else
                setStatus("Key change cancelled", COLOR_DIM)
            end
            keyBtn.Text = "⌨ MAIN GUI KEY: " .. settings.toggleKey
            return
        end
        if UserInputService:GetFocusedTextBox() or not getgenv().MM2HubShown then return end
        if input.KeyCode.Name == settings.toggleKey then
            rgbBorder.Visible = not rgbBorder.Visible
        end
    end)

    -- SCRIPT VERSION: older copies come from the repo's versions/ folder
    settingLabel("SCRIPT VERSION (type 2.8, 3.4 ... or current)", 572)
    local verBox = settingBox("e.g. 2.8 or current", "", 590)
    local loadVerBtn = makeButton(settingsPage, "📂 LOAD VERSION", 630, Color3.fromRGB(120, 200, 255))

    -- tiny VIEW ERROR button, only shown after a version failed to load
    local viewErrBtn = Instance.new("TextButton")
    viewErrBtn.Size = UDim2.fromOffset(120, 20)
    viewErrBtn.Position = UDim2.fromOffset(0, 676)
    viewErrBtn.BackgroundColor3 = Color3.fromRGB(90, 30, 40)
    viewErrBtn.BorderSizePixel = 0
    viewErrBtn.AutoButtonColor = false
    viewErrBtn.Text = "VIEW ERROR"
    viewErrBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
    viewErrBtn.TextScaled = true
    viewErrBtn.Font = activeFont
    viewErrBtn.ZIndex = 4
    viewErrBtn.Visible = getgenv().MM2HubLastError ~= nil
    viewErrBtn.Parent = settingsPage
    corner(viewErrBtn, 5)

    -- ERROR VIEWER: a small notepad with the failed version's code, the error and a possible fix
    local notepad = Instance.new("Frame")
    notepad.Name = "ErrorNotepad"
    notepad.Size = UDim2.fromOffset(330, 320)
    notepad.Position = UDim2.fromOffset(30, 60)
    notepad.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    notepad.BorderSizePixel = 0
    notepad.Active = true
    notepad.Draggable = true
    notepad.Visible = false
    notepad.ZIndex = 50
    notepad.Parent = screenGui
    corner(notepad, 8)

    local nTitle = Instance.new("TextLabel")
    nTitle.Size = UDim2.new(1, -50, 0, 26)
    nTitle.Position = UDim2.fromOffset(10, 6)
    nTitle.BackgroundTransparency = 1
    nTitle.Text = "ERROR VIEWER"
    nTitle.TextColor3 = COLOR_TEXT
    nTitle.TextScaled = true
    nTitle.Font = activeFont
    nTitle.TextXAlignment = Enum.TextXAlignment.Left
    nTitle.ZIndex = 51
    nTitle.Parent = notepad

    local nClose = Instance.new("TextButton")
    nClose.Size = UDim2.fromOffset(26, 26)
    nClose.Position = UDim2.new(1, -32, 0, 6)
    nClose.BackgroundColor3 = Color3.fromRGB(60, 30, 40)
    nClose.BorderSizePixel = 0
    nClose.Text = "X"
    nClose.TextColor3 = COLOR_TEXT
    nClose.TextScaled = true
    nClose.Font = activeFont
    nClose.ZIndex = 51
    nClose.Parent = notepad
    corner(nClose, 6)

    local nScroll = Instance.new("ScrollingFrame")
    nScroll.Size = UDim2.new(1, -16, 1, -44)
    nScroll.Position = UDim2.fromOffset(8, 38)
    nScroll.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    nScroll.BorderSizePixel = 0
    nScroll.ScrollBarThickness = 4
    nScroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
    nScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    nScroll.ZIndex = 51
    nScroll.Parent = notepad
    corner(nScroll, 6)

    local code = Instance.new("TextLabel")
    code.Position = UDim2.fromOffset(6, 6)
    code.Size = UDim2.new(0, 0, 0, 0)
    code.AutomaticSize = Enum.AutomaticSize.XY
    code.BackgroundTransparency = 1
    code.TextWrapped = false
    code.TextXAlignment = Enum.TextXAlignment.Left
    code.TextYAlignment = Enum.TextYAlignment.Top
    code.Font = Enum.Font.Code
    code.TextSize = 12
    code.TextColor3 = Color3.fromRGB(220, 220, 230)
    code.ZIndex = 52
    code.Text = ""
    code.Parent = nScroll

    getgenv().MM2HubClick(nClose, "MouseButton1Click", function()
        notepad.Visible = false
    end)

    local function repairFor(err)
        if string.find(err, "exceeded limit 200", 1, true) or string.find(err, "too many local variables", 1, true) then
            return "POSSIBLE FIX: one block has more than 200 local variables. Wrap that block in (function() ... end)() so its locals get their own space, or move some top-level locals into a table."
        end
        if string.find(err, "'end' expected", 1, true) then
            return "POSSIBLE FIX: an 'end' is missing. Check the last function, if, for or do block above the error line."
        end
        if string.find(err, "unfinished", 1, true) or string.find(err, "unexpected symbol", 1, true) then
            return "POSSIBLE FIX: a bracket, quote or 'end' is unbalanced near the error line."
        end
        return "POSSIBLE FIX: look at the error line for a typo, a missing ')' or 'then', or an unfinished statement."
    end

    local function openErrorViewer()
        local info = getgenv().MM2HubLastError
        if not info then
            setStatus("No error saved", COLOR_DIM)
            return
        end
        local src = {}
        for l in string.gmatch(info.source .. "\n", "([^\n]*)\n") do
            table.insert(src, l)
        end
        local out = { "v" .. info.ver .. ": " .. info.error, "" }
        local line = tonumber(string.match(info.error, ":(%d+):"))
        if line then
            table.insert(out, "AT LINE " .. line .. ":")
            for i = math.max(1, line - 4), math.min(#src, line + 4) do
                table.insert(out, string.format("%s %5d | %s", i == line and ">>" or "  ", i, src[i]))
            end
            table.insert(out, "")
        end
        table.insert(out, repairFor(info.error))
        table.insert(out, "")
        table.insert(out, "FULL CODE:")
        for i, l in ipairs(src) do
            table.insert(out, string.format("%5d | %s", i, l))
        end
        local text = table.concat(out, "\n")
        if #text > 190000 then
            text = string.sub(text, 1, 190000) .. "\n... (cut off, Roblox text limit)"
        end
        code.Text = text
        nTitle.Text = "ERROR: v" .. info.ver
        notepad.Visible = true
    end
    getgenv().MM2HubClick(viewErrBtn, "MouseButton1Click", openErrorViewer)

    local function loadVersion(text)
        local switch = getgenv().MM2HubSwitch
        if not switch then
            setStatus("Version changer needs loader.lua", COLOR_RED)
            return
        end
        setStatus("Loading " .. tostring(text) .. "...", COLOR_DIM)
        local ok, msg = switch(text)
        if not ok then setStatus(msg, COLOR_RED) end
        viewErrBtn.Visible = getgenv().MM2HubLastError ~= nil
    end
    getgenv().MM2HubClick(loadVerBtn, "MouseButton1Click", function() loadVersion(verBox.Text) end)

    -- 3.10 is the newest copy that loads without errors
    local prevVerBtn = makeButton(settingsPage, "⏪ PREVIOUS VERSION (3.10)", 702, COLOR_GOLD)
    getgenv().MM2HubClick(prevVerBtn, "MouseButton1Click", function() loadVersion("3.10") end)

    -- REFRESH: checks GitHub, reloads only when the repo changed
    local refreshBtn = makeButton(settingsPage, "⟳ REFRESH (CHECK FOR UPDATE)", 752, COLOR_GREEN)
    getgenv().MM2HubClick(refreshBtn, "MouseButton1Up", function()
        local refresh = getgenv().MM2HubRefresh
        if not refresh then
            setStatus("Refresh needs loader.lua", COLOR_RED)
            return
        end
        setStatus("Checking GitHub...", COLOR_DIM)
        local ok, msg = refresh()
        if not ok then
            setStatus(msg, COLOR_RED)
        elseif msg ~= "Updated" then
            setStatus(msg, COLOR_DIM)
        end
    end)
end)()

if getgenv().MM2HubNotice then
    setStatus(getgenv().MM2HubNotice, COLOR_GOLD)
    getgenv().MM2HubNotice = nil
end

print("MM2 Helper v3.19 Loaded - toast notifications, live See All, safe reach hitbox, fixed invis + auto coin")
