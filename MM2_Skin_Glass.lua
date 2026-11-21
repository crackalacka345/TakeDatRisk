-- MM2_Skin_Glass.lua
-- GLASS look: translucent panels, soft gradient, light borders, pill tabs, rounded translucent buttons.
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

    local function restyleCard(f)
        if f:GetAttribute("MM2Glass") or not isCard(f) then return end
        f:SetAttribute("MM2Glass", true)
        set(f, { BackgroundTransparency = 0.55 })
        local c = f:FindFirstChildOfClass("UICorner")
        if c then set(c, { CornerRadius = UDim.new(0, 12) }) end
        local st = add(Instance.new("UIStroke"))
        st.Color = Color3.new(1, 1, 1)
        st.Transparency = 0.85
        st.Thickness = 1
        st.Parent = f
    end

    -- window: translucent with a soft light gradient and a thin light border
    set(mainFrame, { BackgroundTransparency = 0.3 })
    local g = add(Instance.new("UIGradient"))
    g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 200, 255))
    g.Transparency = NumberSequence.new(0, 0.3)
    g.Rotation = 60
    g.Parent = mainFrame
    local ms = add(Instance.new("UIStroke"))
    ms.Color = Color3.new(1, 1, 1)
    ms.Transparency = 0.7
    ms.Thickness = 1
    ms.Parent = mainFrame
    set(headerBar, { BackgroundTransparency = 0.55 })
    for _, c in ipairs(headerBar:GetChildren()) do
        if c:IsA("Frame") and c.Size.Y.Offset == 10 then set(c, { BackgroundTransparency = 0.55 }) end
    end

    -- tabs: translucent pills
    for _, tb in pairs(tabButtons) do
        set(tb, { BackgroundTransparency = 0.45 })
        local c = tb:FindFirstChildOfClass("UICorner")
        if c then set(c, { CornerRadius = UDim.new(0, 14) }) end
        local st = add(Instance.new("UIStroke"))
        st.Color = Color3.new(1, 1, 1)
        st.Transparency = 0.8
        st.Thickness = 1
        st.Parent = tb
    end

    -- buttons: every existing one now, and any added later (imported modules etc.)
    for _, page in pairs(pages) do
        for _, d in ipairs(page:GetDescendants()) do restyleCard(d) end
        table.insert(conns, page.DescendantAdded:Connect(function(d)
            task.defer(function() restyleCard(d) end)
        end))
    end
    return revert
end
