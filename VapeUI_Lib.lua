-- VapeUI_Lib.lua
-- A Vape V4 style UI library for Roblox: dark category panels, expandable module rows,
-- pill toggles, gradient sliders, an ArrayList of enabled options and slide-in notifications.
--
-- It is written for this hub and has the same call shape the WindUI hub uses:
--   local UI = loadstring(game:HttpGet(".../VapeUI_Lib.lua"))()
--   local Window  = UI:CreateWindow({ Title = "vv:2", ToggleKey = "RightShift" })
--   local Section = Window:Section({ Title = "ESP" })      -- one draggable panel
--   local Tab     = Section:Tab({ Title = "ESP" })         -- one expandable module row
--   Tab:Toggle({ Title = "TRACERS", Value = false, Callback = function(on) end })
--   Tab:Button({ Title = "FIND SHERIFF", Callback = function() end })
--   Tab:Slider({ Title = "SPEED", Step = 1, Value = { Min = 0, Max = 100, Default = 16 }, Callback = function(v) end })
--   UI:Notify({ Title = "Hi", Content = "Hello", Duration = 3 })
--   Window:SetVisible(true/false)   Window:Destroy()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local VapeUI = {}
VapeUI.__index = VapeUI

local GUI_NAME = "MM2Hub_VapeUI"
local FONT = Enum.Font.Arial
local FONT_BOLD = Enum.Font.ArialBold
local PANEL_W = 272
local PANEL_GAP = 12
local ROW_H = 38

local C = {
    Panel = Color3.fromRGB(26, 25, 26),
    Header = Color3.fromRGB(19, 18, 19),
    Options = Color3.fromRGB(21, 20, 21),
    Hover = Color3.fromRGB(40, 39, 40),
    Off = Color3.fromRGB(58, 57, 58),
    Text = Color3.fromRGB(235, 235, 235),
    Dim = Color3.fromRGB(155, 155, 155),
    Accent = Color3.fromHSV(0.46, 0.88, 0.82),
    Accent2 = Color3.fromHSV(0.56, 0.85, 0.90),
}

-- ============================
-- HELPERS
-- ============================
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        o[k] = v
    end
    if parent then o.Parent = parent end
    return o
end

local function corner(o, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end

local function padding(o, l, t, r, b)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0),
    }, o)
end

local function accentGradient(o, rotation)
    return new("UIGradient", {
        Color = ColorSequence.new(C.Accent, C.Accent2),
        Rotation = rotation or 0,
    }, o)
end

local function tween(o, t, props)
    TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- a callback that errors must not break the UI
local function safe(name, fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("VapeUI: " .. tostring(name) .. " callback error: " .. tostring(err))
    end
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function fmtNumber(v, step)
    if step and step < 1 then
        return string.format("%.2f", v)
    end
    return tostring(math.floor(v + 0.5))
end

local function keyFromName(name)
    if typeof(name) == "EnumItem" then return name end
    local want = string.lower((tostring(name or ""):gsub("%s", "")))
    for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
        if string.lower(item.Name) == want then return item end
    end
    return Enum.KeyCode.RightShift
end

-- ============================
-- WINDOW
-- ============================
function VapeUI:CreateWindow(opts)
    opts = opts or {}
    local brand = tostring(opts.Title or "vape")
    local playerGui = player:WaitForChild("PlayerGui")

    local old = playerGui:FindFirstChild(GUI_NAME)
    if old then old:Destroy() end

    local Window = { _conns = {}, _sections = {}, _alive = true, _array = {}, _z = 1, _visible = true }
    Window.__index = Window

    local gui = new("ScreenGui", {
        Name = GUI_NAME,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 60,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    gui.Parent = playerGui
    Window._gui = gui

    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local scaleValue = math.clamp(math.min(vp.Y / 640, vp.X / 900), 0.7, 1.2)
    if isTouch then scaleValue = math.min(scaleValue, 0.85) end

    -- the panels live in `root` (hidden with the toggle key); the HUD (watermark, ArrayList, notifications) stays visible
    local root = new("Frame", { Name = "Panels", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
    new("UIScale", { Scale = scaleValue }, root)
    Window._root = root
    Window._scale = scaleValue

    local hud = new("Frame", { Name = "HUD", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false }, gui)
    new("UIScale", { Scale = scaleValue }, hud)

    -- watermark (the rebranded name)
    local mark = new("Frame", {
        Name = "Watermark",
        Position = UDim2.fromOffset(14, 10),
        Size = UDim2.fromOffset(0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
    }, hud)
    new("TextLabel", {
        Name = "Brand",
        Size = UDim2.fromOffset(0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = brand,
        TextColor3 = C.Text,
        Font = FONT_BOLD,
        TextSize = 26,
    }, mark)
    local markLine = new("Frame", {
        Position = UDim2.fromOffset(0, 29),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, mark)
    accentGradient(markLine, 0)

    -- ArrayList (enabled toggles, top right)
    local arrayHost = new("Frame", {
        Name = "ArrayList",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 8),
        Size = UDim2.fromOffset(300, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, hud)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 1),
    }, arrayHost)

    -- notifications (bottom right, newest at the bottom)
    local notifyHost = new("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -12, 1, -12),
        Size = UDim2.new(0, 260, 1, -24),
        BackgroundTransparency = 1,
    }, hud)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 6),
    }, notifyHost)
    VapeUI._notifyHost = notifyHost
    VapeUI._notifyCount = 0

    function Window:_bind(signal, fn)
        local c = signal:Connect(fn)
        table.insert(self._conns, c)
        return c
    end

    function Window:_front(panel)
        self._z = self._z + 1
        panel.ZIndex = self._z
    end

    -- ArrayList entry for an enabled toggle
    function Window:_arraySet(key, text, on)
        local entry = self._array[key]
        if on then
            if entry then return end
            local label = new("TextLabel", {
                Name = "Entry",
                Size = UDim2.fromOffset(0, 20),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = C.Header,
                BackgroundTransparency = 0.3,
                BorderSizePixel = 0,
                Text = text,
                TextColor3 = C.Accent,
                Font = FONT,
                TextSize = 14,
                LayoutOrder = -#text,
            }, arrayHost)
            padding(label, 8, 0, 10, 0)
            local bar = new("Frame", {
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                Size = UDim2.new(0, 2, 1, 0),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
            }, label)
            accentGradient(bar, 90)
            self._array[key] = label
        elseif entry then
            entry:Destroy()
            self._array[key] = nil
        end
    end

    function Window:SetVisible(on)
        self._visible = on and true or false
        root.Visible = self._visible
        mark.Visible = self._visible
        arrayHost.Visible = self._visible
    end

    -- the real Vape finishes its setup here; nothing to do for the built-in UI
    function Window:Init() end

    function Window:Toggle()
        self:SetVisible(not self._visible)
    end

    function Window:Destroy()
        if not self._alive then return end
        self._alive = false
        for _, c in ipairs(self._conns) do
            pcall(function() c:Disconnect() end)
        end
        self._conns = {}
        pcall(function() gui:Destroy() end)
        if VapeUI._notifyHost == notifyHost then VapeUI._notifyHost = nil end
    end

    -- toggle key (desktop)
    local toggleKey = keyFromName(opts.ToggleKey or "RightShift")
    Window:_bind(UserInputService.InputBegan, function(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == toggleKey then Window:Toggle() end
    end)

    -- floating button (phones have no keyboard)
    if UserInputService.TouchEnabled then
        local btn = new("TextButton", {
            Name = "OpenButton",
            Position = UDim2.new(1, -62, 0.5, -70),
            Size = UDim2.fromOffset(46, 46),
            BackgroundColor3 = Color3.new(1, 1, 1),
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Text = string.sub(brand, 1, 4),
            TextColor3 = Color3.new(1, 1, 1),
            Font = FONT_BOLD,
            TextSize = 15,
        }, hud)
        corner(btn, 23)
        accentGradient(btn, 45)
        Window:_bind(btn.MouseButton1Click, function() Window:Toggle() end)
    end

    -- ============================
    -- SECTION = one draggable panel
    -- ============================
    function Window:Section(cfg)
        cfg = cfg or {}
        local title = tostring(cfg.Title or "Section")
        local Section = {}

        local cols = math.max(1, math.floor((vp.X / scaleValue - 16) / (PANEL_W + PANEL_GAP)))
        local index = #self._sections
        local col = index % cols
        local row = math.floor(index / cols)
        local maxBody = math.max(120, math.floor(vp.Y / scaleValue) - 56 - ROW_H - 24)

        local panel = new("Frame", {
            Name = "Panel_" .. title,
            Position = UDim2.fromOffset(16 + col * (PANEL_W + PANEL_GAP), 56 + row * 290),
            Size = UDim2.fromOffset(PANEL_W, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.Panel,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Active = true, -- clicks on a panel must not reach the game underneath
            ZIndex = self._z,
        }, root)
        corner(panel, 5)
        new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, panel)
        table.insert(self._sections, panel)

        local header = new("TextButton", {
            Name = "Header",
            Size = UDim2.new(1, 0, 0, ROW_H + 4),
            BackgroundColor3 = C.Header,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = 0,
        }, panel)
        new("TextLabel", {
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -50, 1, 0),
            BackgroundTransparency = 1,
            Text = title,
            TextColor3 = C.Text,
            Font = FONT_BOLD,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, header)
        local arrow = new("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(20, 20),
            BackgroundTransparency = 1,
            Text = "-",
            TextColor3 = C.Dim,
            Font = FONT_BOLD,
            TextSize = 20,
        }, header)
        local line = new("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
        }, header)
        accentGradient(line, 0)

        local body = new("ScrollingFrame", {
            Name = "Body",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = C.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 1,
        }, panel)
        new("UISizeConstraint", { MaxSize = Vector2.new(math.huge, maxBody) }, body)
        new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, body)

        -- drag by the header; a tap without moving collapses / opens the panel
        local dragging, moved, dragStart, startPos = false, false, nil, nil
        Window:_bind(header.InputBegan, function(input)
            if not isPress(input) then return end
            dragging, moved = true, false
            dragStart = input.Position
            startPos = panel.Position
            Window:_front(panel)
        end)
        Window:_bind(UserInputService.InputChanged, function(input)
            if not dragging or not isMove(input) then return end
            local d = input.Position - dragStart
            if d.Magnitude > 5 then moved = true end
            if moved then
                panel.Position = UDim2.fromOffset(
                    startPos.X.Offset + d.X / scaleValue,
                    startPos.Y.Offset + d.Y / scaleValue
                )
            end
        end)
        Window:_bind(UserInputService.InputEnded, function(input)
            if not dragging or not isPress(input) then return end
            dragging = false
            if not moved then
                body.Visible = not body.Visible
                arrow.Text = body.Visible and "-" or "+"
            end
        end)

        local order = 0

        -- ============================
        -- TAB = one expandable module row
        -- ============================
        function Section:Tab(tcfg)
            tcfg = tcfg or {}
            local Tab = {}
            order = order + 1

            local module = new("Frame", {
                Name = "Module",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = order,
            }, body)
            new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, module)

            local head = new("TextButton", {
                Name = "ModuleHead",
                Size = UDim2.new(1, 0, 0, ROW_H),
                BackgroundColor3 = C.Panel,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = 0,
            }, module)
            local dot = new("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 12, 0.5, 0),
                Size = UDim2.fromOffset(6, 6),
                BackgroundColor3 = C.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
            }, head)
            corner(dot, 3)
            local nameLabel = new("TextLabel", {
                Position = UDim2.fromOffset(26, 0),
                Size = UDim2.new(1, -60, 1, 0),
                BackgroundTransparency = 1,
                Text = tostring(tcfg.Title or "Module"),
                TextColor3 = C.Dim,
                Font = FONT,
                TextSize = 17,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, head)
            local chev = new("TextLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.fromOffset(18, 18),
                BackgroundTransparency = 1,
                Text = "+",
                TextColor3 = C.Dim,
                Font = FONT_BOLD,
                TextSize = 17,
            }, head)

            local options = new("Frame", {
                Name = "Options",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = C.Options,
                BorderSizePixel = 0,
                Visible = false,
                LayoutOrder = 1,
            }, module)
            new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, options)

            local open = false
            local function setOpen(v)
                open = v
                options.Visible = v
                chev.Text = v and "-" or "+"
                nameLabel.TextColor3 = v and C.Text or C.Dim
                tween(head, 0.12, { BackgroundColor3 = v and C.Hover or C.Panel })
            end
            Window:_bind(head.MouseButton1Click, function() setOpen(not open) end)
            Window:_bind(head.MouseEnter, function()
                if not open then tween(head, 0.1, { BackgroundColor3 = C.Hover }) end
            end)
            Window:_bind(head.MouseLeave, function()
                if not open then tween(head, 0.1, { BackgroundColor3 = C.Panel }) end
            end)

            -- the dot shows when any toggle inside this module is on
            local activeCount = 0
            local function bumpActive(delta)
                activeCount = math.max(0, activeCount + delta)
                tween(dot, 0.15, { BackgroundTransparency = activeCount > 0 and 0 or 1 })
            end

            local optOrder = 0

            -- TOGGLE
            function Tab:Toggle(cfg2)
                cfg2 = cfg2 or {}
                optOrder = optOrder + 1
                local text = tostring(cfg2.Title or "Toggle")
                local state = cfg2.Value == true
                local key = {}

                local row = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 32),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = C.Options,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Text = "",
                    LayoutOrder = optOrder,
                }, options)
                padding(row, 16, 7, 12, 7)
                local label = new("TextLabel", {
                    Size = UDim2.new(1, -48, 0, 16),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = text,
                    TextColor3 = state and C.Text or C.Dim,
                    Font = FONT,
                    TextSize = 15,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }, row)
                local track = new("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(34, 16),
                    BackgroundColor3 = state and Color3.new(1, 1, 1) or C.Off,
                    BorderSizePixel = 0,
                }, row)
                corner(track, 8)
                local grad = accentGradient(track, 0)
                grad.Enabled = state
                local knob = new("Frame", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = state and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                    Size = UDim2.fromOffset(12, 12),
                    BackgroundColor3 = state and Color3.new(1, 1, 1) or C.Dim,
                    BorderSizePixel = 0,
                }, track)
                corner(knob, 6)

                local function paint()
                    grad.Enabled = state
                    track.BackgroundColor3 = state and Color3.new(1, 1, 1) or C.Off
                    label.TextColor3 = state and C.Text or C.Dim
                    tween(knob, 0.12, {
                        Position = state and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                        BackgroundColor3 = state and Color3.new(1, 1, 1) or C.Dim,
                    })
                    Window:_arraySet(key, text, state)
                end
                if state then
                    bumpActive(1)
                    Window:_arraySet(key, text, true)
                end

                Window:_bind(row.MouseEnter, function() tween(row, 0.1, { BackgroundColor3 = C.Hover }) end)
                Window:_bind(row.MouseLeave, function() tween(row, 0.1, { BackgroundColor3 = C.Options }) end)
                Window:_bind(row.MouseButton1Click, function()
                    state = not state
                    bumpActive(state and 1 or -1)
                    paint()
                    safe(text, cfg2.Callback, state)
                end)

                local api = {}
                function api:Set(v)
                    v = v and true or false
                    if v == state then return end
                    state = v
                    bumpActive(state and 1 or -1)
                    paint()
                    safe(text, cfg2.Callback, state)
                end
                function api:Destroy()
                    if state then bumpActive(-1) end
                    Window:_arraySet(key, text, false)
                    row:Destroy()
                end
                return api
            end

            -- BUTTON
            function Tab:Button(cfg2)
                cfg2 = cfg2 or {}
                optOrder = optOrder + 1
                local text = tostring(cfg2.Title or "Button")

                local row = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 32),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = C.Options,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Text = text,
                    TextColor3 = C.Text,
                    Font = FONT,
                    TextSize = 15,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = optOrder,
                }, options)
                padding(row, 16, 7, 12, 7)

                Window:_bind(row.MouseEnter, function() tween(row, 0.1, { BackgroundColor3 = C.Hover }) end)
                Window:_bind(row.MouseLeave, function() tween(row, 0.1, { BackgroundColor3 = C.Options }) end)
                Window:_bind(row.MouseButton1Click, function()
                    row.BackgroundColor3 = C.Accent
                    tween(row, 0.25, { BackgroundColor3 = C.Options })
                    safe(text, cfg2.Callback)
                end)

                local api = {}
                function api:Destroy() row:Destroy() end
                return api
            end

            -- SLIDER
            function Tab:Slider(cfg2)
                cfg2 = cfg2 or {}
                optOrder = optOrder + 1
                local text = tostring(cfg2.Title or "Slider")
                local v = type(cfg2.Value) == "table" and cfg2.Value or {}
                local min = tonumber(v.Min) or 0
                local max = tonumber(v.Max) or 100
                if max <= min then max = min + 1 end
                local step = tonumber(cfg2.Step) or 1
                local value = math.clamp(tonumber(v.Default) or min, min, max)

                local row = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 44),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = C.Options,
                    BorderSizePixel = 0,
                    LayoutOrder = optOrder,
                }, options)
                padding(row, 16, 7, 14, 7)
                new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, row)

                local top = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 16),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                }, row)
                new("TextLabel", {
                    Size = UDim2.new(1, -46, 0, 16),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Text = text,
                    TextColor3 = C.Dim,
                    Font = FONT,
                    TextSize = 15,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }, top)
                local valueLabel = new("TextLabel", {
                    AnchorPoint = Vector2.new(1, 0),
                    Position = UDim2.new(1, 0, 0, 0),
                    Size = UDim2.fromOffset(42, 16),
                    BackgroundTransparency = 1,
                    Text = fmtNumber(value, step),
                    TextColor3 = C.Text,
                    Font = FONT_BOLD,
                    TextSize = 15,
                    TextXAlignment = Enum.TextXAlignment.Right,
                }, top)

                -- a taller invisible button around the thin bar, so it is easy to grab on a phone
                local hit = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundTransparency = 1,
                    Text = "",
                    AutoButtonColor = false,
                    LayoutOrder = 2,
                }, row)
                local bar = new("Frame", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    Size = UDim2.new(1, 0, 0, 5),
                    BackgroundColor3 = C.Off,
                    BorderSizePixel = 0,
                }, hit)
                corner(bar, 3)
                local fill = new("Frame", {
                    Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                }, bar)
                corner(fill, 3)
                accentGradient(fill, 0)
                local knob = new("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.fromOffset(12, 12),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                }, fill)
                corner(knob, 6)

                local function setFromX(x)
                    local width = bar.AbsoluteSize.X
                    if width <= 0 then return end
                    local rel = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
                    local raw = min + rel * (max - min)
                    local snapped = math.clamp(math.floor(raw / step + 0.5) * step, min, max)
                    if snapped == value then return end
                    value = snapped
                    fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
                    valueLabel.Text = fmtNumber(value, step)
                    safe(text, cfg2.Callback, value)
                end

                local sliding = false
                Window:_bind(hit.InputBegan, function(input)
                    if not isPress(input) then return end
                    sliding = true
                    setFromX(input.Position.X)
                end)
                Window:_bind(UserInputService.InputChanged, function(input)
                    if sliding and isMove(input) then setFromX(input.Position.X) end
                end)
                Window:_bind(UserInputService.InputEnded, function(input)
                    if sliding and isPress(input) then sliding = false end
                end)

                local api = {}
                function api:Set(n)
                    value = math.clamp(tonumber(n) or value, min, max)
                    fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
                    valueLabel.Text = fmtNumber(value, step)
                end
                function api:Destroy() row:Destroy() end
                return api
            end

            return Tab
        end

        return Section
    end

    return setmetatable(Window, Window)
end

-- ============================
-- NOTIFICATIONS
-- ============================
function VapeUI:Notify(cfg)
    local host = VapeUI._notifyHost
    if not host or not host.Parent then return end
    cfg = cfg or {}
    local duration = tonumber(cfg.Duration) or 3
    VapeUI._notifyCount = VapeUI._notifyCount + 1

    local card = new("CanvasGroup", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.Panel,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        LayoutOrder = VapeUI._notifyCount,
    }, host)
    corner(card, 5)

    local bar = new("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, card)
    accentGradient(bar, 90)

    local inner = new("Frame", {
        Position = UDim2.fromOffset(3, 0),
        Size = UDim2.new(1, -3, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, card)
    padding(inner, 12, 8, 10, 11)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, inner)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = tostring(cfg.Title or ""),
        TextColor3 = C.Text,
        Font = FONT_BOLD,
        TextSize = 15,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    }, inner)
    if cfg.Content and tostring(cfg.Content) ~= "" then
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = tostring(cfg.Content),
            TextColor3 = C.Dim,
            Font = FONT,
            TextSize = 13,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
        }, inner)
    end

    local timer = new("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, card)
    accentGradient(timer, 0)

    tween(card, 0.2, { GroupTransparency = 0 })
    TweenService:Create(timer, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
    task.delay(duration, function()
        if not card.Parent then return end
        tween(card, 0.25, { GroupTransparency = 1 })
        task.wait(0.3)
        if card.Parent then card:Destroy() end
    end)
end

return VapeUI
