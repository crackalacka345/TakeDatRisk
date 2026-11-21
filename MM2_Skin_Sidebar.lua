-- MM2_Skin_Sidebar.lua
-- SIDEBAR look: dark icon rail on the left instead of the tab row, pages use the freed space, hover labels for each tab.
-- Loaded by MM2_Helper.lua when chosen in SETTINGS > UI STYLE. It only restyles the existing window (no features are
-- touched) and returns a function that puts everything back exactly as it was.
return function(D)
    local mainFrame, pages, tabButtons, TAB_NAMES, headerBar = D.mainFrame, D.pages, D.tabButtons, D.TAB_NAMES, D.headerBar
    local saved, added, conns = {}, {}, {}
    local function set(o, props)
        for k, v in pairs(props) do
            table.insert(saved, { o, k, o[k] })
            o[k] = v
        end
    end
    local function add(inst) table.insert(added, inst) return inst end
    local function isCard(f) -- a button made by makeButton
        return f:IsA("Frame") and f.Size.Y.Offset == 44 and f.Size.Y.Scale == 0
            and f:FindFirstChildOfClass("UIStroke") ~= nil and f:FindFirstChildOfClass("TextButton") ~= nil
    end
    local function revert()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        for i = #saved, 1, -1 do
            local s = saved[i]
            pcall(function() s[1][s[2]] = s[3] end)
        end
        for _, a in ipairs(added) do pcall(function() a:Destroy() end) end
    end
    local strip = tabButtons[TAB_NAMES[1]].Parent

    local ICONS = { ESP = "👁", COMBAT = "⚔", PLAYER = "👤", GAMES = "🎮", MODULES = "🧩",
        ["MY MODULES"] = "📦", SETTINGS = "⚙", UI = "🎨" }
    local RAIL_W = 46

    -- the tab row becomes a vertical rail on the left
    set(strip, { Size = UDim2.new(0, RAIL_W, 1, -62), Position = UDim2.new(0, 8, 0, 54),
        ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(0, 0, 0, #TAB_NAMES * 40 + 6),
        ScrollBarThickness = 0, BackgroundTransparency = 0.1, BackgroundColor3 = Color3.fromRGB(14, 14, 22) })
    local sc = add(Instance.new("UICorner"))
    sc.CornerRadius = UDim.new(0, 10)
    sc.Parent = strip

    -- hover label (the rail only shows icons)
    local tip = add(Instance.new("TextLabel"))
    tip.Size = UDim2.fromOffset(0, 24)
    tip.AutomaticSize = Enum.AutomaticSize.X
    tip.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    tip.BorderSizePixel = 0
    tip.TextColor3 = Color3.new(1, 1, 1)
    tip.TextSize = 12
    tip.Font = Enum.Font.GothamBold
    tip.Visible = false
    tip.ZIndex = 40
    tip.Parent = mainFrame
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 6)
    tc.Parent = tip
    local tp = Instance.new("UIPadding")
    tp.PaddingLeft, tp.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
    tp.Parent = tip

    for i, name in ipairs(TAB_NAMES) do
        local tb = tabButtons[name]
        set(tb, { Size = UDim2.fromOffset(RAIL_W - 8, 34), Position = UDim2.fromOffset(4, 4 + (i - 1) * 40),
            Text = ICONS[name] or name:sub(1, 1), TextSize = 18 })
        local c = tb:FindFirstChildOfClass("UICorner")
        if c then set(c, { CornerRadius = UDim.new(0, 8) }) end
        table.insert(conns, tb.MouseEnter:Connect(function()
            local y = (tb.AbsolutePosition.Y - mainFrame.AbsolutePosition.Y) / (D.uiScale and D.uiScale.Scale or 1)
            tip.Text = name
            tip.Position = UDim2.fromOffset(RAIL_W + 14, y + 5)
            tip.Visible = true
        end))
        table.insert(conns, tb.MouseLeave:Connect(function() tip.Visible = false end))
    end

    -- pages use the freed top space and sit right of the rail
    for _, page in pairs(pages) do
        set(page, { Position = UDim2.new(0, RAIL_W + 16, 0, 56), Size = UDim2.new(1, -(RAIL_W + 28), 1, -68) })
    end
    return revert
end
