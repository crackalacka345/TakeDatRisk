-- MM2_Games.lua
-- The whole GAMES tab for MM2 Helper: mini-games, practice ranges and the chess entry.
-- Loaded by MM2_Helper.lua:   local build = loadstring(game:HttpGet(URL))();  build(ctx)
-- ctx carries the hub helpers this tab needs (see the loader in MM2_Helper.lua).
-- Everything here runs on your client only.

return function(ctx)
    local base = ctx.base
    local gamesPage = ctx.gamesPage
    local player = ctx.player
    local playerGui = ctx.playerGui
    local makeButton = ctx.makeButton
    local setStatus = ctx.setStatus
    local saveSettings = ctx.saveSettings
    local settings = ctx.settings
    local corner = ctx.corner
    local COLOR_RED, COLOR_BLUE, COLOR_DIM = ctx.COLOR_RED, ctx.COLOR_BLUE, ctx.COLOR_DIM
    local COLOR_GOLD, COLOR_TEXT, COLOR_GREEN = ctx.COLOR_GOLD, ctx.COLOR_TEXT, ctx.COLOR_GREEN
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")

    -- font and theme can change in the hub's settings, so they are re-read when a game starts
    local activeFont, activeThemeDef
    local function syncTheme()
        if ctx.getTheme then
            local f, d = ctx.getTheme()
            if f then activeFont = f end
            if d then activeThemeDef = d end
        end
    end
    syncTheme()

local GAMES = {} -- key -> starter function, filled in below
local activeGame = nil
local startGame -- forward declaration

local function stopGame(silent)
    if activeGame then
        local cleanup = activeGame.cleanup
        activeGame = nil
        pcall(cleanup)
        if not silent then
            setStatus("Game stopped")
        end
    end
end

-- BLOCK STACK: click or press Space to drop the sliding block. Overlap keeps, rest is lost.
local function startBlockStack()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MM2Hub_StackGame"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 50
    gui.Parent = playerGui

    local W, H, BLOCK_H = 260, 300, 18

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, W + 190, 0, H + 60)
    frame.Position = UDim2.new(0.5, -(W + 190) / 2, 0.5, -(H + 60) / 2)
    frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    corner(frame, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = activeThemeDef.accent
    stroke.Thickness = 2
    stroke.Parent = frame

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -16, 0, 22)
    header.Position = UDim2.new(0, 8, 0, 6)
    header.BackgroundTransparency = 1
    header.Text = "BLOCK STACK  |  click / Space to drop"
    header.TextColor3 = COLOR_TEXT
    header.TextScaled = true
    header.Font = activeFont
    header.Parent = frame

    local scoreLbl = Instance.new("TextLabel")
    scoreLbl.Size = UDim2.new(1, -16, 0, 18)
    scoreLbl.Position = UDim2.new(0, 8, 0, 30)
    scoreLbl.BackgroundTransparency = 1
    scoreLbl.Text = "Score: 0"
    scoreLbl.TextColor3 = COLOR_GOLD
    scoreLbl.TextScaled = true
    scoreLbl.Font = activeFont
    scoreLbl.Parent = frame

    local board = Instance.new("Frame")
    board.Size = UDim2.new(0, W, 0, H)
    board.Position = UDim2.new(0, 10, 0, 56)
    board.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    board.BorderSizePixel = 0
    board.ClipsDescendants = true
    board.Parent = frame
    corner(board, 6)

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, H)
    holder.BackgroundTransparency = 1
    holder.Parent = board

    local function rowY(row)
        return H - (row + 1) * BLOCK_H
    end

    local function blockColor(row)
        return Color3.fromHSV((row * 0.07) % 1, 0.7, 0.95)
    end

    local blocks = {} -- { left = px, width = px }
    local function addBlockFrame(row, left, width)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, width, 0, BLOCK_H - 2)
        f.Position = UDim2.new(0, left, 0, rowY(row))
        f.BackgroundColor3 = blockColor(row)
        f.BorderSizePixel = 0
        f.Parent = holder
        corner(f, 3)
        return f
    end

    blocks[1] = { left = (W - 200) / 2, width = 200 }
    addBlockFrame(0, blocks[1].left, 200)

    local moving = addBlockFrame(1, 0, 200)
    local mx, mdir, mw = 0, 1, 200
    local speed = 140
    local over = false

    local function updateShift()
        local top = #blocks
        holder.Position = UDim2.new(0, 0, 0, math.max(0, (top + 1) * BLOCK_H - H))
    end

    -- LEADERBOARD: top scores saved on this device, with player icons
    local boardPanel = Instance.new("Frame")
    boardPanel.Size = UDim2.new(0, 160, 0, H)
    boardPanel.Position = UDim2.new(0, W + 30, 0, 56)
    boardPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    boardPanel.BorderSizePixel = 0
    boardPanel.Parent = frame
    corner(boardPanel, 6)

    local boardTitle = Instance.new("TextLabel")
    boardTitle.Size = UDim2.new(1, -12, 0, 22)
    boardTitle.Position = UDim2.new(0, 6, 0, 4)
    boardTitle.BackgroundTransparency = 1
    boardTitle.Text = "🏆 LEADERBOARD"
    boardTitle.TextColor3 = COLOR_GOLD
    boardTitle.TextScaled = true
    boardTitle.Font = activeFont
    boardTitle.Parent = boardPanel

    local boardRows = Instance.new("Frame")
    boardRows.Size = UDim2.new(1, 0, 1, -30)
    boardRows.Position = UDim2.new(0, 0, 0, 30)
    boardRows.BackgroundTransparency = 1
    boardRows.Parent = boardPanel

    local function refreshBoard()
        for _, child in ipairs(boardRows:GetChildren()) do
            child:Destroy()
        end
        local list = settings.stackBoard or {}
        if #list == 0 then
            local none = Instance.new("TextLabel")
            none.Size = UDim2.new(1, -12, 0, 20)
            none.Position = UDim2.new(0, 6, 0, 10)
            none.BackgroundTransparency = 1
            none.Text = "No scores yet"
            none.TextColor3 = COLOR_DIM
            none.TextScaled = true
            none.Font = activeFont
            none.Parent = boardRows
        end
        for i = 1, math.min(5, #list) do
            local e = list[i]
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -10, 0, 40)
            row.Position = UDim2.new(0, 5, 0, (i - 1) * 44)
            row.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
            row.BorderSizePixel = 0
            row.Parent = boardRows
            corner(row, 6)

            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.new(0, 30, 0, 30)
            icon.Position = UDim2.new(0, 5, 0.5, -15)
            icon.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            icon.BorderSizePixel = 0
            icon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(e.userId or 0) .. "&w=100&h=100"
            icon.Parent = row
            corner(icon, 15)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(1, -44, 0, 20)
            nameLbl.Position = UDim2.new(0, 40, 0, 3)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = tostring(e.name or "?")
            nameLbl.TextColor3 = COLOR_TEXT
            nameLbl.TextScaled = true
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Font = activeFont
            nameLbl.Parent = row

            local scoreTxt = Instance.new("TextLabel")
            scoreTxt.Size = UDim2.new(1, -44, 0, 14)
            scoreTxt.Position = UDim2.new(0, 40, 0, 23)
            scoreTxt.BackgroundTransparency = 1
            scoreTxt.Text = "#" .. i .. "  •  " .. tostring(e.score or 0)
            scoreTxt.TextColor3 = COLOR_GOLD
            scoreTxt.TextScaled = true
            scoreTxt.TextXAlignment = Enum.TextXAlignment.Left
            scoreTxt.Font = activeFont
            scoreTxt.Parent = row
        end
    end

    local function recordScore(score)
        if score <= 0 then return end
        local list = settings.stackBoard or {}
        table.insert(list, { name = player.DisplayName, userId = player.UserId, score = score })
        table.sort(list, function(a, b)
            return (a.score or 0) > (b.score or 0)
        end)
        while #list > 10 do
            table.remove(list)
        end
        settings.stackBoard = list
        saveSettings()
        refreshBoard()
    end

    refreshBoard()

    local function placeMoving()
        local top = blocks[#blocks]
        local row = #blocks
        local left = math.max(top.left, mx)
        local right = math.min(top.left + top.width, mx + mw)
        if right - left < 3 then
            over = true
            moving.Visible = false
            scoreLbl.Text = "Game over! Score: " .. (#blocks - 1) .. "  (click to restart)"
            recordScore(#blocks - 1)
            return
        end
        blocks[#blocks + 1] = { left = left, width = right - left }
        addBlockFrame(row, left, right - left)
        mw = right - left
        mx = 0
        mdir = 1
        speed = 140 + #blocks * 6
        moving.Size = UDim2.new(0, mw, 0, BLOCK_H - 2)
        moving.BackgroundColor3 = blockColor(#blocks)
        moving.Position = UDim2.new(0, mx, 0, rowY(#blocks))
        scoreLbl.Text = "Score: " .. (#blocks - 1)
        updateShift()
    end

    moving.Size = UDim2.new(0, mw, 0, BLOCK_H - 2)
    moving.BackgroundColor3 = blockColor(1)
    moving.Position = UDim2.new(0, 0, 0, rowY(1))

    local heartConn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
        if over then return end
        mx = mx + mdir * speed * dt
        if mx < 0 then
            mx = 0
            mdir = 1
        elseif mx + mw > W then
            mx = W - mw
            mdir = -1
        end
        moving.Position = UDim2.new(0, mx, 0, rowY(#blocks))
        updateShift()
    end)

    local inputConn = getgenv().MM2HubBind(UserInputService.InputBegan, function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Space then
            if over then
                task.defer(function()
                    startGame("STACK")
                end)
            else
                placeMoving()
            end
        end
    end)

    setStatus("🧱 Block Stack: click or Space to drop blocks", COLOR_GOLD)

    return function()
        heartConn:Disconnect()
        inputConn:Disconnect()
        gui:Destroy()
    end
end

-- OBBY RUN: 25 platforms climbing in a zigzag high above the map. Falling sends you to your checkpoint.
local function startObbyGame()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        setStatus("No character to play with.", COLOR_RED)
        return nil
    end
    local returnCF = root.CFrame

    local folder = Instance.new("Folder")
    folder.Name = "MM2Hub_Obby"
    folder.Parent = workspace

    local BASE = Vector3.new(0, 600, 0)
    local N = 25
    local platforms = {}
    for i = 1, N do
        local p = Instance.new("Part")
        p.Anchored = true
        p.Size = Vector3.new(10, 1, 10)
        p.Position = BASE + Vector3.new(math.sin(i * 0.5) * 8, i * 1.5, -i * 13)
        p.Color = (i == N) and COLOR_GOLD or Color3.fromHSV((i * 0.04) % 1, 0.6, 0.9)
        p.Material = Enum.Material.SmoothPlastic
        p.Parent = folder
        platforms[i] = p
    end

    root.CFrame = CFrame.new(platforms[1].Position + Vector3.new(0, 4, 0))

    local startT = os.clock()
    local checkpoint = 1
    local finished = false
    local lastStatus = 0

    local conn = getgenv().MM2HubBind(RunService.Heartbeat, function()
        local c = player.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r or finished then return end

        local pos = r.Position
        for i = checkpoint + 1, math.min(N, checkpoint + 3) do
            local pp = platforms[i].Position
            local flat = Vector3.new(pos.X - pp.X, 0, pos.Z - pp.Z).Magnitude
            if flat < 8 and pos.Y > pp.Y - 4 then
                checkpoint = i
            end
        end

        if pos.Y < BASE.Y - 40 then
            r.CFrame = CFrame.new(platforms[checkpoint].Position + Vector3.new(0, 4, 0))
            setStatus("You fell! Back to checkpoint " .. checkpoint .. "/" .. N, COLOR_RED)
            return
        end

        if checkpoint >= N then
            finished = true
            setStatus(string.format("🏁 Obby finished in %.1fs! Pick OBBY to play again.", os.clock() - startT), COLOR_GOLD)
            return
        end

        if os.clock() - lastStatus > 0.5 then
            lastStatus = os.clock()
            setStatus(string.format("🏃 Obby: checkpoint %d/%d | %.1fs", checkpoint, N, os.clock() - startT), COLOR_TEXT)
        end
    end)

    return function()
        conn:Disconnect()
        folder:Destroy()
        local c = player.Character
        local rr = c and c:FindFirstChild("HumanoidRootPart")
        if rr then
            rr.CFrame = returnCF
        end
    end
end

-- LOOT RUSH: 30 glowing orbs in a 60-second arena, walk over them to grab them.
local function startLootGame()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        setStatus("No character to play with.", COLOR_RED)
        return nil
    end
    local returnCF = root.CFrame

    local ARENA = Vector3.new(500, 800, 0)
    local folder = Instance.new("Folder")
    folder.Name = "MM2Hub_Loot"
    folder.Parent = workspace

    local floor = Instance.new("Part")
    floor.Anchored = true
    floor.Size = Vector3.new(200, 2, 200)
    floor.Position = ARENA
    floor.Color = Color3.fromRGB(30, 30, 40)
    floor.Material = Enum.Material.Slate
    floor.Parent = folder

    local orbs = {}
    for _ = 1, 30 do
        local orb = Instance.new("Part")
        orb.Shape = Enum.PartType.Ball
        orb.Size = Vector3.new(3, 3, 3)
        orb.Anchored = true
        orb.CanCollide = false
        orb.Material = Enum.Material.Neon
        orb.Color = Color3.fromHSV(math.random(), 0.8, 1)
        orb.Position = ARENA + Vector3.new(math.random(-90, 90), 3, math.random(-90, 90))
        orb.Parent = folder
        table.insert(orbs, orb)
    end

    root.CFrame = CFrame.new(ARENA + Vector3.new(0, 5, 0))

    local score, timeLeft, done = 0, 60, false
    local lastStatus = 0

    local conn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
        if done then return end
        local c = player.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return end

        timeLeft = timeLeft - dt
        local pos = r.Position
        for i = #orbs, 1, -1 do
            local o = orbs[i]
            if (o.Position - pos).Magnitude < 6 then
                o:Destroy()
                table.remove(orbs, i)
                score = score + 1
            end
        end

        if timeLeft <= 0 or #orbs == 0 then
            done = true
            setStatus("💰 Loot Rush over! Collected " .. score .. " orbs. Pick LOOT to play again.", COLOR_GOLD)
            return
        end

        if os.clock() - lastStatus > 0.25 then
            lastStatus = os.clock()
            setStatus(string.format("💰 Loot: %d collected | %ds left", score, math.ceil(timeLeft)), COLOR_GOLD)
        end
    end)

    return function()
        conn:Disconnect()
        folder:Destroy()
        local c = player.Character
        local rr = c and c:FindFirstChild("HumanoidRootPart")
        if rr then
            rr.CFrame = returnCF
        end
    end
end

do -- DODGE: red blocks fall from the sky, survive as long as you can
local function startDodgeGame()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        setStatus("No character to play with.", COLOR_RED)
        return nil
    end
    local returnCF = root.CFrame

    local ARENA = Vector3.new(-500, 800, 0)
    local folder = Instance.new("Folder")
    folder.Name = "MM2Hub_Dodge"
    folder.Parent = workspace

    local floor = Instance.new("Part")
    floor.Anchored = true
    floor.Size = Vector3.new(120, 2, 120)
    floor.Position = ARENA
    floor.Color = Color3.fromRGB(30, 30, 40)
    floor.Material = Enum.Material.Slate
    floor.Parent = folder

    root.CFrame = CFrame.new(ARENA + Vector3.new(0, 5, 0))

    local falling = {}
    local alive = true
    local startT = os.clock()
    local spawnAcc = 0
    local lastStatus = 0

    local conn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
        if not alive then return end
        local c = player.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return end

        local elapsed = os.clock() - startT
        local interval = math.max(0.12, 0.4 - elapsed * 0.004) -- gets faster over time
        spawnAcc = spawnAcc + dt
        if spawnAcc >= interval then
            spawnAcc = 0
            local p = Instance.new("Part")
            p.Anchored = true
            p.CanCollide = false
            p.Size = Vector3.new(4, 4, 4)
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromRGB(255, 60, 60)
            p.Position = ARENA + Vector3.new(math.random(-55, 55), 80, math.random(-55, 55))
            p.Parent = folder
            table.insert(falling, { part = p, speed = 40 + math.random() * 30 + elapsed * 0.5 })
        end

        local pos = r.Position
        for i = #falling, 1, -1 do
            local f = falling[i]
            f.part.Position = f.part.Position - Vector3.new(0, f.speed * dt, 0)
            if (f.part.Position - pos).Magnitude < 4 then
                alive = false
                setStatus(string.format("💥 Hit! Survived %.1fs. Pick DODGE to try again.", os.clock() - startT), COLOR_RED)
                return
            end
            if f.part.Position.Y < ARENA.Y - 5 then
                f.part:Destroy()
                table.remove(falling, i)
            end
        end

        if os.clock() - lastStatus > 0.25 then
            lastStatus = os.clock()
            setStatus(string.format("☄ Dodge: %.1fs survived", os.clock() - startT), COLOR_TEXT)
        end
    end)

    return function()
        conn:Disconnect()
        folder:Destroy()
        local c = player.Character
        local rr = c and c:FindFirstChild("HumanoidRootPart")
        if rr then
            rr.CFrame = returnCF
        end
    end
end

-- REACTION TEST: click the green pad as soon as it turns green, 5 rounds
local function startReactionGame()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MM2Hub_ReactionGame"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 50
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 260)
    frame.Position = UDim2.new(0.5, -150, 0.5, -130)
    frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    corner(frame, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = activeThemeDef.accent
    stroke.Thickness = 2
    stroke.Parent = frame

    local head = Instance.new("TextLabel")
    head.Size = UDim2.new(1, -16, 0, 22)
    head.Position = UDim2.new(0, 8, 0, 8)
    head.BackgroundTransparency = 1
    head.Text = "REACTION TEST  |  5 rounds"
    head.TextColor3 = COLOR_TEXT
    head.TextScaled = true
    head.Font = activeFont
    head.Parent = frame

    local pad = Instance.new("TextButton")
    pad.Size = UDim2.new(1, -24, 0, 150)
    pad.Position = UDim2.new(0, 12, 0, 40)
    pad.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    pad.BorderSizePixel = 0
    pad.AutoButtonColor = false
    pad.Text = "WAIT..."
    pad.TextColor3 = Color3.new(1, 1, 1)
    pad.TextScaled = true
    pad.Font = activeFont
    pad.Parent = frame
    corner(pad, 10)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -24, 0, 40)
    info.Position = UDim2.new(0, 12, 0, 200)
    info.BackgroundTransparency = 1
    info.Text = "Click the GREEN pad as soon as it turns green."
    info.TextColor3 = COLOR_DIM
    info.TextScaled = true
    info.TextWrapped = true
    info.Font = activeFont
    info.Parent = frame

    local round, times, ready, startT, gen = 0, {}, false, 0, 0

    local function setPad(text, color)
        pad.Text = text
        pad.BackgroundColor3 = color
    end

    local nextRound
    nextRound = function()
        gen = gen + 1
        local myGen = gen
        ready = false
        if round >= 5 then
            local sum = 0
            for _, t in ipairs(times) do sum = sum + t end
            local avg = math.floor(sum / math.max(1, #times))
            setPad("DONE! Click to play again", COLOR_GOLD)
            info.Text = string.format("Average reaction: %dms", avg)
            setStatus(string.format("⚡ Reaction average: %dms", avg), COLOR_GOLD)
            return
        end
        setPad("WAIT...", Color3.fromRGB(180, 40, 40))
        task.delay(math.random(15, 40) / 10, function()
            if myGen ~= gen then return end
            ready = true
            startT = os.clock()
            setPad("CLICK!", Color3.fromRGB(40, 200, 80))
        end)
    end

    getgenv().MM2HubClick(pad, "MouseButton1Click", function()
        if round >= 5 then
            round = 0
            times = {}
            info.Text = "Click the GREEN pad as soon as it turns green."
            nextRound()
            return
        end
        if not ready then
            gen = gen + 1
            local myGen = gen
            setPad("TOO EARLY!", COLOR_RED)
            info.Text = "Wait for green. Retrying..."
            task.delay(1, function()
                if myGen == gen then nextRound() end
            end)
            return
        end
        ready = false
        round = round + 1
        local ms = (os.clock() - startT) * 1000
        table.insert(times, ms)
        info.Text = string.format("Round %d: %dms", round, ms)
        gen = gen + 1
        local myGen = gen
        setPad("NICE!", Color3.fromRGB(60, 120, 220))
        task.delay(0.8, function()
            if myGen == gen then nextRound() end
        end)
    end)

    nextRound()

    return function()
        gen = gen + 1
        gui:Destroy()
    end
end

-- register the games (GAMES tab buttons call startGame(key))
GAMES.STACK = startBlockStack
GAMES.OBBY = startObbyGame
GAMES.LOOT = startLootGame
GAMES.DODGE = startDodgeGame
GAMES.REACTION = startReactionGame

startGame = function(key)
    syncTheme()
    stopGame(true)
    local starter = GAMES[key]
    if not starter then return end
    local ok, result = pcall(starter)
    if ok and result then
        activeGame = { key = key, cleanup = result }
    elseif not ok then
        setStatus("Game failed to start: " .. tostring(result), COLOR_RED)
    end
end

end -- mini-game definitions

-- ============================
-- MORE MINI GAMES (each one is registered in GAMES)
-- ============================
do
    -- shared window for the 2D games
    local function gameWindow(title, w, h)
        local gui = Instance.new("ScreenGui")
        gui.Name = "MM2Hub_Game"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 50
        gui.Parent = playerGui

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, w, 0, h)
        frame.Position = UDim2.new(0.5, -math.floor(w / 2), 0.5, -math.floor(h / 2))
        frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Draggable = true
        frame.Parent = gui
        corner(frame, 14)

        local grad = Instance.new("UIGradient")
        grad.Color = ColorSequence.new(Color3.fromRGB(34, 24, 56), Color3.fromRGB(12, 12, 18))
        grad.Rotation = 90
        grad.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Color = activeThemeDef.accent
        stroke.Thickness = 2
        stroke.Parent = frame

        local head = Instance.new("TextLabel")
        head.Size = UDim2.new(1, -60, 0, 26)
        head.Position = UDim2.new(0, 12, 0, 8)
        head.BackgroundTransparency = 1
        head.Text = title
        head.TextColor3 = COLOR_TEXT
        head.TextScaled = true
        head.TextXAlignment = Enum.TextXAlignment.Left
        head.Font = activeFont
        head.Parent = frame

        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0, 30, 0, 26)
        close.Position = UDim2.new(1, -40, 0, 8)
        close.BackgroundColor3 = COLOR_RED
        close.BorderSizePixel = 0
        close.Text = "X"
        close.TextColor3 = Color3.new(1, 1, 1)
        close.TextScaled = true
        close.Font = activeFont
        close.Parent = frame
        corner(close, 6)
        getgenv().MM2HubClick(close, "MouseButton1Click", function()
            stopGame()
        end)

        local score = Instance.new("TextLabel")
        score.Size = UDim2.new(1, -24, 0, 22)
        score.Position = UDim2.new(0, 12, 0, 36)
        score.BackgroundTransparency = 1
        score.Text = ""
        score.TextColor3 = COLOR_GOLD
        score.TextScaled = true
        score.Font = activeFont
        score.Parent = frame

        -- bottom-right grip: resize width and height (drag the title bar to move)
        local grip = Instance.new("TextButton")
        grip.Size = UDim2.new(0, 16, 0, 16)
        grip.AnchorPoint = Vector2.new(1, 1)
        grip.Position = UDim2.new(1, -4, 1, -4)
        grip.BackgroundColor3 = activeThemeDef.accent
        grip.BorderSizePixel = 0
        grip.AutoButtonColor = false
        grip.Text = ""
        grip.ZIndex = 10
        grip.Parent = frame
        corner(grip, 5)

        local resizing, sMouse, sW, sH = false, Vector2.new(), w, h
        grip.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                frame.Draggable = false
                sMouse = UserInputService:GetMouseLocation()
                sW, sH = frame.AbsoluteSize.X, frame.AbsoluteSize.Y
            end
        end)
        local c1 = getgenv().MM2HubBind(UserInputService.InputChanged, function(input)
            if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local m = UserInputService:GetMouseLocation()
                local nw = math.clamp(sW + (m.X - sMouse.X), 240, 700)
                local nh = math.clamp(sH + (m.Y - sMouse.Y), 220, 700)
                frame.Size = UDim2.new(0, nw, 0, nh)
            end
        end)
        local c2 = getgenv().MM2HubBind(UserInputService.InputEnded, function(input)
            if resizing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                resizing = false
                frame.Draggable = true
            end
        end)
        gui.Destroying:Connect(function()
            c1:Disconnect()
            c2:Disconnect()
        end)

        return gui, frame, score
    end

    -- TARGET RUSH (3D): click the floating neon balls before they vanish
    GAMES.TARGET = function()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            setStatus("No character to play with.", COLOR_RED)
            return nil
        end
        local returnCF = root.CFrame
        local CENTER = Vector3.new(-800, 800, 0)
        local DURATION = 30

        local folder = Instance.new("Folder")
        folder.Name = "MM2Hub_Target"
        folder.Parent = workspace

        local floor = Instance.new("Part")
        floor.Anchored = true
        floor.Size = Vector3.new(160, 2, 160)
        floor.Position = CENTER
        floor.Color = Color3.fromRGB(20, 40, 30)
        floor.Material = Enum.Material.Grass
        floor.Parent = folder

        root.CFrame = CFrame.new(CENTER + Vector3.new(0, 4, 0))

        local gui, frame, scoreLbl = gameWindow("🎯 TARGET RUSH", 300, 70)
        local score, spawnAcc, alive = 0, 0, true
        local targets = {}
        local startT = os.clock()

        local function spawnTarget()
            local p = Instance.new("Part")
            p.Shape = Enum.PartType.Ball
            p.Size = Vector3.new(4, 4, 4)
            p.Anchored = true
            p.CanCollide = false
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromHSV(math.random(), 0.8, 1)
            local ang = math.random() * math.pi * 2
            local dist = math.random(4, 22)
            p.Position = CENTER + Vector3.new(math.cos(ang) * dist, 6 + math.random(-2, 10), math.sin(ang) * dist)
            p.Parent = folder

            local cd = Instance.new("ClickDetector")
            cd.MaxActivationDistance = 500
            cd.Parent = p
            cd.MouseClick:Connect(function()
                if alive and p.Parent then
                    score = score + 1
                    p:Destroy()
                end
            end)

            table.insert(targets, { part = p, born = os.clock(), life = math.max(0.9, 1.8 - score * 0.02) })
        end

        local conn
        conn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
            if not alive then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                alive = false
                scoreLbl.Text = "Time's up! Score: " .. score .. "  (X to leave)"
                setStatus("🎯 Target Rush score: " .. score, COLOR_GOLD)
                return
            end
            scoreLbl.Text = string.format("Score %d   |   %ds left", score, math.ceil(left))

            spawnAcc = spawnAcc + dt
            if spawnAcc >= math.max(0.35, 0.9 - score * 0.01) then
                spawnAcc = 0
                spawnTarget()
            end
            for i = #targets, 1, -1 do
                local t = targets[i]
                if not t.part.Parent or os.clock() - t.born > t.life then
                    if t.part.Parent then
                        t.part:Destroy()
                    end
                    table.remove(targets, i)
                end
            end
        end)

        return function()
            alive = false
            conn:Disconnect()
            folder:Destroy()
            gui:Destroy()
            local c = player.Character
            local rr = c and c:FindFirstChild("HumanoidRootPart")
            if rr then
                rr.CFrame = returnCF
            end
        end
    end

    -- SIMON PADS: watch the color order, then repeat it. It gets longer every round.
    GAMES.SIMON = function()
        local gui, frame, scoreLbl = gameWindow("🟥 SIMON PADS", 300, 340)
        local COLORS = {
            Color3.fromRGB(230, 40, 60),
            Color3.fromRGB(40, 200, 90),
            Color3.fromRGB(40, 120, 255),
            Color3.fromRGB(255, 210, 40),
        }
        local DIM = {
            Color3.fromRGB(90, 20, 28),
            Color3.fromRGB(20, 80, 40),
            Color3.fromRGB(20, 50, 110),
            Color3.fromRGB(110, 90, 20),
        }

        local pads = {}
        for i = 1, 4 do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 126, 0, 120)
            b.Position = UDim2.new(0, 12 + col * 138, 0, 70 + row * 130)
            b.BackgroundColor3 = DIM[i]
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Text = ""
            b.Parent = frame
            corner(b, 12)
            pads[i] = b
        end

        local sequence, input, showing, alive, gen = {}, {}, false, true, 0

        local function flash(i, dur)
            pads[i].BackgroundColor3 = COLORS[i]
            task.delay(dur, function()
                if alive then
                    pads[i].BackgroundColor3 = DIM[i]
                end
            end)
        end

        local nextRound
        local function playSequence()
            showing = true
            input = {}
            gen = gen + 1
            local myGen = gen
            scoreLbl.Text = "Watch... round " .. #sequence
            task.spawn(function()
                task.wait(0.6)
                for _, idx in ipairs(sequence) do
                    if myGen ~= gen or not alive then return end
                    flash(idx, 0.35)
                    task.wait(0.55)
                end
                if myGen ~= gen or not alive then return end
                showing = false
                scoreLbl.Text = "Your turn! Round " .. #sequence
            end)
        end

        nextRound = function()
            table.insert(sequence, math.random(1, 4))
            playSequence()
        end

        for i, b in ipairs(pads) do
            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                if showing or not alive then return end
                flash(i, 0.18)
                table.insert(input, i)
                local pos = #input
                if sequence[pos] ~= i then
                    alive = false
                    showing = true
                    scoreLbl.Text = "Wrong! You reached round " .. (#sequence - 1) .. "  (X to leave)"
                    setStatus("🟥 Simon: round " .. (#sequence - 1), COLOR_RED)
                    return
                end
                if pos == #sequence then
                    showing = true
                    scoreLbl.Text = "Nice! Next round..."
                    task.delay(0.8, function()
                        if alive then
                            nextRound()
                        end
                    end)
                end
            end)
        end

        nextRound()

        return function()
            alive = false
            gen = gen + 1
            gui:Destroy()
        end
    end

    -- WHACK-A-MOLE: a mole pops up in one of 9 holes, hit it before it hides
    GAMES.WHACK = function()
        local gui, frame, scoreLbl = gameWindow("🐹 WHACK-A-MOLE", 300, 330)
        local DURATION = 30
        local DIRT = Color3.fromRGB(60, 42, 26)
        local MOLE = Color3.fromRGB(150, 100, 40)
        local HIT = COLOR_GOLD
        local cells = {}
        local score, alive = 0, true
        local litIndex, litLeft = nil, 0
        local waitAcc = 0
        local startT = os.clock()

        local function clearLit()
            if litIndex then
                cells[litIndex].Text = ""
                cells[litIndex].BackgroundColor3 = DIRT
                litIndex = nil
            end
        end

        for i = 1, 9 do
            local col = (i - 1) % 3
            local row = math.floor((i - 1) / 3)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 84, 0, 84)
            b.Position = UDim2.new(0, 12 + col * 94, 0, 70 + row * 90)
            b.BackgroundColor3 = DIRT
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Text = ""
            b.TextScaled = true
            b.Font = activeFont
            b.Parent = frame
            corner(b, 42)
            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                if not alive or litIndex ~= i then return end
                score = score + 1
                litIndex = nil
                b.Text = "💥"
                b.BackgroundColor3 = HIT
                task.delay(0.25, function()
                    if alive and litIndex ~= i then
                        b.Text = ""
                        b.BackgroundColor3 = DIRT
                    end
                end)
            end)
            cells[i] = b
        end

        local conn
        conn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
            if not alive then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                alive = false
                clearLit()
                scoreLbl.Text = "Time's up! Score: " .. score .. "  (X to leave)"
                setStatus("🐹 Whack-a-Mole score: " .. score, COLOR_GOLD)
                return
            end
            scoreLbl.Text = string.format("Score %d   |   %ds left", score, math.ceil(left))

            if litIndex then
                litLeft = litLeft - dt
                if litLeft <= 0 then
                    clearLit()
                end
            else
                waitAcc = waitAcc + dt
                if waitAcc >= math.max(0.25, 0.6 - score * 0.01) then
                    waitAcc = 0
                    local pick = math.random(1, 9)
                    if pick == litIndex then pick = (pick % 9) + 1 end
                    litIndex = pick
                    litLeft = math.max(0.45, 1.2 - score * 0.01)
                    cells[pick].Text = "🐹"
                    cells[pick].BackgroundColor3 = MOLE
                end
            end
        end)

        return function()
            alive = false
            conn:Disconnect()
            gui:Destroy()
        end
    end

    -- COLOR MATCH: the word says one color, its ink is another. Click the INK color.
    GAMES.COLOR = function()
        local gui, frame, scoreLbl = gameWindow("🎨 COLOR MATCH", 300, 300)
        local DURATION = 30
        local NAMES = { "RED", "GREEN", "BLUE", "GOLD" }
        local COLORS = {
            Color3.fromRGB(230, 50, 60),
            Color3.fromRGB(60, 210, 100),
            Color3.fromRGB(60, 130, 255),
            Color3.fromRGB(255, 210, 60),
        }
        local score, inkIdx, alive = 0, 1, true
        local startT = os.clock()

        local word = Instance.new("TextLabel")
        word.Size = UDim2.new(1, -24, 0, 90)
        word.Position = UDim2.new(0, 12, 0, 70)
        word.BackgroundTransparency = 1
        word.Text = ""
        word.TextScaled = true
        word.Font = activeFont
        word.Parent = frame

        local function newRound()
            local w = math.random(1, 4)
            inkIdx = math.random(1, 4)
            word.Text = NAMES[w]
            word.TextColor3 = COLORS[inkIdx]
        end

        for i = 1, 4 do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 130, 0, 60)
            b.Position = UDim2.new(0, 12 + col * 142, 0, 180 + row * 68)
            b.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Text = NAMES[i]
            b.TextColor3 = COLORS[i]
            b.TextScaled = true
            b.Font = activeFont
            b.Parent = frame
            corner(b, 10)
            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                if not alive then return end
                if i == inkIdx then
                    score = score + 1
                    b.BackgroundColor3 = Color3.fromRGB(40, 110, 60)
                else
                    score = math.max(0, score - 1)
                    b.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
                end
                task.delay(0.15, function()
                    b.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
                end)
                newRound()
            end)
        end

        newRound()

        local conn
        conn = getgenv().MM2HubBind(RunService.Heartbeat, function()
            if not alive then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                alive = false
                word.Text = "TIME!"
                word.TextColor3 = COLOR_GOLD
                scoreLbl.Text = "Final score: " .. score .. "  (X to leave)"
                setStatus("🎨 Color Match score: " .. score, COLOR_GOLD)
                return
            end
            scoreLbl.Text = string.format("Score %d   |   %ds left", score, math.ceil(left))
        end)

        return function()
            alive = false
            conn:Disconnect()
            gui:Destroy()
        end
    end
    -- BUBBLE POP: bubbles float up, click them before they escape
    GAMES.BUBBLE = function()
        local gui, frame, scoreLbl = gameWindow("🫧 BUBBLE POP", 320, 380)
        local field = Instance.new("Frame")
        field.Size = UDim2.new(0, 296, 0, 290)
        field.Position = UDim2.new(0, 12, 0, 74)
        field.BackgroundColor3 = Color3.fromRGB(8, 14, 26)
        field.BorderSizePixel = 0
        field.ClipsDescendants = true
        field.Parent = frame
        corner(field, 10)

        local DURATION = 30
        local score, alive, spawnAcc = 0, true, 0
        local bubbles = {}
        local startT = os.clock()

        local function spawn()
            local size = math.random(34, 56)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, size, 0, size)
            b.Position = UDim2.new(0, math.random(0, 296 - size), 0, 290)
            b.BackgroundColor3 = Color3.fromHSV(math.random(), 0.55, 1)
            b.BackgroundTransparency = 0.1
            b.AutoButtonColor = false
            b.Text = ""
            b.Parent = field
            corner(b, math.floor(size / 2))
            local bb = { ui = b, y = 290, speed = math.random(40, 80) + score }
            table.insert(bubbles, bb)
            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                if not alive or not b.Parent then return end
                score = score + 1
                b:Destroy()
            end)
        end

        local conn
        conn = getgenv().MM2HubBind(RunService.Heartbeat, function(dt)
            if not alive then return end
            local left = DURATION - (os.clock() - startT)
            if left <= 0 then
                alive = false
                scoreLbl.Text = "Time's up! Score: " .. score .. "  (X to leave)"
                setStatus("🫧 Bubble Pop score: " .. score, COLOR_GOLD)
                return
            end
            scoreLbl.Text = string.format("Score %d   |   %ds left", score, math.ceil(left))

            spawnAcc = spawnAcc + dt
            if spawnAcc >= math.max(0.25, 0.7 - score * 0.01) then
                spawnAcc = 0
                spawn()
            end
            for i = #bubbles, 1, -1 do
                local bb = bubbles[i]
                if bb.ui.Parent == nil then
                    table.remove(bubbles, i)
                else
                    bb.y = bb.y - bb.speed * dt
                    if bb.y < -60 then
                        bb.ui:Destroy()
                        table.remove(bubbles, i)
                    else
                        bb.ui.Position = UDim2.new(bb.ui.Position.X.Scale, bb.ui.Position.X.Offset, 0, bb.y)
                    end
                end
            end
        end)

        return function()
            alive = false
            conn:Disconnect()
            gui:Destroy()
        end
    end

    -- MEMORY FLIP: find the 8 matching pairs
    GAMES.MEMORY = function()
        local gui, frame, scoreLbl = gameWindow("🃏 MEMORY FLIP", 320, 380)
        local SYMBOLS = { "🎃", "👻", "🦇", "🍬", "🕷", "🧙", "💀", "🔮" }
        local deck = {}
        for _, sym in ipairs(SYMBOLS) do
            table.insert(deck, sym)
            table.insert(deck, sym)
        end
        for k = #deck, 2, -1 do
            local j = math.random(1, k)
            deck[k], deck[j] = deck[j], deck[k]
        end

        local cards = {}
        local open, lock, matches, moves, alive = {}, false, 0, 0, true
        local function update()
            scoreLbl.Text = "Moves " .. moves .. "   |   Pairs " .. matches .. "/8"
        end

        for i = 1, 16 do
            local col = (i - 1) % 4
            local row = math.floor((i - 1) / 4)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 64, 0, 64)
            b.Position = UDim2.new(0, 12 + col * 74, 0, 74 + row * 74)
            b.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Text = "?"
            b.TextScaled = true
            b.TextColor3 = COLOR_TEXT
            b.Font = activeFont
            b.Parent = frame
            corner(b, 10)
            cards[i] = { ui = b, sym = deck[i], shown = false, done = false }

            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                local card = cards[i]
                if not alive or lock or card.shown or card.done then return end
                card.shown = true
                b.Text = card.sym
                b.BackgroundColor3 = Color3.fromRGB(230, 200, 120)
                table.insert(open, i)
                if #open == 2 then
                    moves = moves + 1
                    local i1, i2 = open[1], open[2]
                    local a, c = cards[i1], cards[i2]
                    open = {}
                    if a.sym == c.sym then
                        a.done, c.done = true, true
                        matches = matches + 1
                        if matches == 8 then
                            alive = false
                            setStatus("🃏 Memory solved in " .. moves .. " moves!", COLOR_GOLD)
                        end
                    else
                        lock = true
                        task.delay(0.8, function()
                            if alive then
                                a.shown, c.shown = false, false
                                a.ui.Text = "?"
                                c.ui.Text = "?"
                                a.ui.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
                                c.ui.BackgroundColor3 = Color3.fromRGB(60, 40, 90)
                            end
                            lock = false
                        end)
                    end
                    update()
                end
            end)
        end
        update()

        return function()
            alive = false
            gui:Destroy()
        end
    end

    -- SLIDE PUZZLE: slide the tiles back into order (empty tile is the last one)
    GAMES.PUZZLE = function()
        local gui, frame, scoreLbl = gameWindow("🧩 SLIDE PUZZLE", 320, 380)
        local grid = { 1, 2, 3, 4, 5, 6, 7, 8, 0 } -- 0 = empty

        local function emptyIndex()
            for k = 1, 9 do
                if grid[k] == 0 then return k end
            end
        end
        local function neighbors(k)
            local r, c = math.floor((k - 1) / 3), (k - 1) % 3
            local out = {}
            if r > 0 then table.insert(out, k - 3) end
            if r < 2 then table.insert(out, k + 3) end
            if c > 0 then table.insert(out, k - 1) end
            if c < 2 then table.insert(out, k + 1) end
            return out
        end

        -- scramble with legal moves so the puzzle is always solvable
        for _ = 1, 200 do
            local e = emptyIndex()
            local nb = neighbors(e)
            local pick = nb[math.random(1, #nb)]
            grid[e], grid[pick] = grid[pick], grid[e]
        end

        local tiles = {}
        local moves, alive = 0, true
        local function render()
            for k = 1, 9 do
                local v = grid[k]
                tiles[k].Text = v ~= 0 and tostring(v) or ""
                tiles[k].BackgroundColor3 = v ~= 0 and Color3.fromRGB(70, 60, 120) or Color3.fromRGB(14, 14, 22)
            end
            scoreLbl.Text = "Moves " .. moves
        end

        for k = 1, 9 do
            local col = (k - 1) % 3
            local row = math.floor((k - 1) / 3)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 90, 0, 90)
            b.Position = UDim2.new(0, 12 + col * 98, 0, 74 + row * 98)
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.TextScaled = true
            b.TextColor3 = COLOR_TEXT
            b.Font = activeFont
            b.Parent = frame
            corner(b, 12)
            tiles[k] = b

            getgenv().MM2HubClick(b, "MouseButton1Click", function()
                if not alive then return end
                local e = emptyIndex()
                local adjacent = false
                for _, n in ipairs(neighbors(e)) do
                    if n == k then adjacent = true end
                end
                if not adjacent then return end
                grid[e], grid[k] = grid[k], grid[e]
                moves = moves + 1
                render()

                local solved = true
                for idx = 1, 8 do
                    if grid[idx] ~= idx then solved = false end
                end
                if solved and grid[9] == 0 then
                    alive = false
                    scoreLbl.Text = "Solved in " .. moves .. " moves!  (X to leave)"
                    setStatus("🧩 Puzzle solved in " .. moves .. " moves", COLOR_GOLD)
                end
            end)
        end
        render()

        return function()
            alive = false
            gui:Destroy()
        end
    end
end

local function toggleGame(key)
    if activeGame and activeGame.key == key then
        stopGame()
    else
        startGame(key)
    end
end

-- GAMES TAB
-- PRACTICE KNIFE THROW: a private range far above the map. Bots, the knife and every hit
-- are local only. Nothing is sent to the server, so other players are never affected.
do
    local RANGE_CENTER = Vector3.new(0, 4000, 0)
    local THROW_SPEED = 150
    local GRAVITY = 25
    local THROW_CHARGE = 1 -- same as the real knife's ThrowSpeed attribute
    local THROW_COOLDOWN = 2 * THROW_CHARGE -- the real knife waits 2x ThrowSpeed
    local BOT_RESPAWN = 2
    local FALL_TIME = 0.3
    local STICK_TIME = 2.5

    local function makePart(parent, props)
        local p = Instance.new("Part")
        p.Anchored = true
        p.CanCollide = true
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Material = Enum.Material.SmoothPlastic
        for k, v in pairs(props) do p[k] = v end
        p.Parent = parent
        return p
    end

    -- builds the range: floor, lane lines, walls and a sign (all local)
    local function buildRange(rangeFolder)
        local geo = Instance.new("Folder")
        geo.Name = "Geometry"
        geo.Parent = rangeFolder
        local o = RANGE_CENTER
        makePart(geo, { Name = "Floor", Size = Vector3.new(160, 2, 200), CFrame = CFrame.new(o + Vector3.new(0, -1, 40)), Color = Color3.fromRGB(70, 75, 90) })
        makePart(geo, { Name = "Lane", Size = Vector3.new(6, 0.1, 200), CFrame = CFrame.new(o + Vector3.new(0, 0.05, 40)), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon, CanCollide = false })
        for _, x in ipairs({ -26, 26 }) do
            makePart(geo, { Name = "Stripe", Size = Vector3.new(1, 0.1, 200), CFrame = CFrame.new(o + Vector3.new(x, 0.05, 40)), Color = Color3.fromRGB(200, 200, 220), CanCollide = false })
        end
        local back = makePart(geo, { Name = "BackWall", Size = Vector3.new(160, 40, 2), CFrame = CFrame.new(o + Vector3.new(0, 20, 141)), Color = Color3.fromRGB(40, 44, 58) })
        makePart(geo, { Name = "LeftWall", Size = Vector3.new(2, 40, 200), CFrame = CFrame.new(o + Vector3.new(-80, 20, 40)), Color = Color3.fromRGB(40, 44, 58) })
        makePart(geo, { Name = "RightWall", Size = Vector3.new(2, 40, 200), CFrame = CFrame.new(o + Vector3.new(80, 20, 40)), Color = Color3.fromRGB(40, 44, 58) })
        makePart(geo, { Name = "Roof", Size = Vector3.new(160, 2, 200), CFrame = CFrame.new(o + Vector3.new(0, 40, 40)), Color = Color3.fromRGB(30, 32, 44), Transparency = 0.2 })
        -- distance markers
        for _, z in ipairs({ 20, 40, 60, 80 }) do
            local m = makePart(geo, { Name = "Marker", Size = Vector3.new(160, 0.15, 1), CFrame = CFrame.new(o + Vector3.new(0, 0.1, z)), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon, CanCollide = false })
            local g = Instance.new("SurfaceGui")
            g.Face = Enum.NormalId.Top
            g.Parent = m
            local l = Instance.new("TextLabel")
            l.Size = UDim2.fromScale(1, 1)
            l.BackgroundTransparency = 1
            l.Text = z .. " studs"
            l.TextColor3 = Color3.fromRGB(120, 200, 255)
            l.TextScaled = true
            l.Font = Enum.Font.GothamBold
            l.Parent = g
        end
        -- sign on the back wall
        local sign = Instance.new("SurfaceGui")
        sign.Face = Enum.NormalId.Front
        sign.Parent = back
        local st = Instance.new("TextLabel")
        st.Size = UDim2.fromScale(1, 1)
        st.BackgroundTransparency = 1
        st.Text = "PRACTICE RANGE"
        st.TextColor3 = Color3.fromRGB(255, 200, 60)
        st.TextScaled = true
        st.Font = Enum.Font.GothamBlack
        st.Parent = sign
        return geo
    end

    -- a dummy built from parts; the torso is anchored and the other parts are welded to it
    local function makeBot(folder, cf)
        local model = Instance.new("Model")
        model.Name = "PracticeBot"
        local torso = makePart(model, { Name = "Torso", Size = Vector3.new(2, 2, 1), CFrame = cf, Color = Color3.fromRGB(200, 60, 60) })
        model.PrimaryPart = torso
        local function attach(name, size, offset, color, shape)
            local p = makePart(model, { Name = name, Size = size, CFrame = cf * CFrame.new(offset), Color = color, Anchored = false, Shape = shape or Enum.PartType.Block })
            local w = Instance.new("WeldConstraint")
            w.Part0 = torso
            w.Part1 = p
            w.Parent = p
            return p
        end
        attach("Head", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 1.8, 0), Color3.fromRGB(245, 205, 170), Enum.PartType.Ball)
        attach("LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), Color3.fromRGB(200, 60, 60))
        attach("RightArm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), Color3.fromRGB(200, 60, 60))
        attach("LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), Color3.fromRGB(40, 40, 60))
        attach("RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), Color3.fromRGB(40, 40, 60))
        model.Parent = folder
        return model
    end

    -- the knife model: a copy of your Knife tool's handle when you have one, otherwise a plain blade
    local function makeKnifeVisual()
        local backpack = player:FindFirstChildOfClass("Backpack")
        local tool = (backpack and backpack:FindFirstChild("Knife"))
            or (player.Character and player.Character:FindFirstChild("Knife"))
        local handle = tool and tool:FindFirstChild("Handle")
        local visual
        if handle and handle:IsA("BasePart") then
            visual = handle:Clone()
            for _, d in ipairs(visual:GetDescendants()) do
                if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("BillboardGui")
                    or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
                    d:Destroy()
                end
            end
            visual.Anchored = true
            visual.CanCollide = false
        else
            visual = makePart(nil, { Name = "Knife", Size = Vector3.new(0.3, 0.3, 2.2), Color = Color3.fromRGB(200, 200, 215), CanCollide = false })
        end
        return visual
    end

    local function startPracticeKnife()
        local running = true
        local cam = workspace.CurrentCamera

        -- move your character to the range (only your client sees the range)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local savedCF = hrp and hrp.CFrame

        -- a local-only copy of your knife in the backpack (named PracticeBlade, so the murderer
        -- checks that look for "knife" ignore it). It has no scripts, so it never throws by itself.
        -- Its animations and sounds are copied from your real Knife, so the throw looks and sounds the same.
        local practiceTool = nil
        local practiceAnims, practiceSounds = {}, {}
        do
            local backpack = player:FindFirstChildOfClass("Backpack")
            local clone = getgenv().MM2HubKnifeClone
            local handle = clone and clone:FindFirstChild("Handle")
            -- the real knife may be in the backpack or held, so check both
            local realKnife = (backpack and backpack:FindFirstChild("Knife"))
                or (char and char:FindFirstChild("Knife"))
            if backpack and handle and handle:IsA("BasePart") then
                practiceTool = Instance.new("Tool")
                practiceTool.Name = "PracticeBlade"
                practiceTool.RequiresHandle = true
                practiceTool.CanBeDropped = false
                local h = handle:Clone()
                for _, d in ipairs(h:GetDescendants()) do
                    if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("BillboardGui")
                        or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") or d:IsA("TouchTransmitter") then
                        d:Destroy()
                    end
                end
                h.Name = "Handle"
                h.Anchored = false
                h.CanCollide = false
                h.Massless = true
                h.Parent = practiceTool
                practiceTool.Parent = backpack
            end
            if realKnife then
                -- animations live inside the real knife's client script
                local kc = realKnife:FindFirstChild("KnifeClient")
                if kc then
                    for _, a in ipairs(kc:GetDescendants()) do
                        if a:IsA("Animation") then practiceAnims[a.Name] = a:Clone() end
                    end
                end
                -- Throw sound lives in the Sounds folder, Kill sound in the Handle
                local sf = realKnife:FindFirstChild("Sounds")
                local throwSnd = sf and sf:FindFirstChild("Throw")
                if throwSnd and throwSnd:IsA("Sound") then practiceSounds.Throw = throwSnd:Clone() end
                local killSnd = realKnife:FindFirstChild("Handle") and realKnife.Handle:FindFirstChild("Kill")
                if killSnd and killSnd:IsA("Sound") then practiceSounds.Kill = killSnd:Clone() end
            end
        end

        local function playPracticeSound(name, parent)
            local src = practiceSounds[name]
            if not src then return end
            local snd = src:Clone()
            snd.Parent = parent
            snd:Play()
            task.delay(3, function()
                if snd.Parent then snd:Destroy() end
            end)
        end

        -- load the copied animations on your own character, so they play like the real knife's
        local practiceTracks = {}
        do
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local animator = hum and hum:FindFirstChildOfClass("Animator")
            if animator then
                for name, anim in pairs(practiceAnims) do
                    practiceTracks[name] = animator:LoadAnimation(anim)
                end
            end
        end

        local gui = Instance.new("ScreenGui")
        gui.Name = "MM2Hub_KnifeRange"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 60
        gui.Parent = playerGui

        local rangeFolder = Instance.new("Folder")
        rangeFolder.Name = "MM2Hub_KnifeRange"
        rangeFolder.Parent = workspace
        local geo = buildRange(rangeFolder)
        local botsFolder = Instance.new("Folder")
        botsFolder.Name = "Bots"
        botsFolder.Parent = rangeFolder

        local bots = {}
        local layout = { { -20, 30 }, { 0, 30 }, { 20, 30 }, { -10, 55 }, { 10, 55 }, { 0, 75 } }
        for _, p in ipairs(layout) do
            local cf = CFrame.new(RANGE_CENTER + Vector3.new(p[1], 3, p[2]))
            local model = makeBot(botsFolder, cf)
            bots[model] = { model = model, cf = cf, state = "up", t = 0, respawnAt = 0 }
        end

        local botParams = RaycastParams.new()
        botParams.FilterType = Enum.RaycastFilterType.Include
        botParams.FilterDescendantsInstances = { botsFolder }
        local geoParams = RaycastParams.new()
        geoParams.FilterType = Enum.RaycastFilterType.Include
        geoParams.FilterDescendantsInstances = { geo }

        -- on-screen text in the game's style
        local stats = { kills = 0, heads = 0 }
        local statLabel = Instance.new("TextLabel")
        statLabel.Size = UDim2.new(0, 360, 0, 28)
        statLabel.Position = UDim2.new(0.5, -180, 0, 60)
        statLabel.BackgroundTransparency = 1
        statLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
        statLabel.TextStrokeTransparency = 0.5
        statLabel.TextScaled = true
        statLabel.Font = Enum.Font.GothamBold
        statLabel.Text = "PRACTICE KNIFE THROW  |  kills 0  headshots 0"
        statLabel.Parent = gui

        local banner = Instance.new("TextLabel")
        banner.Size = UDim2.new(0, 520, 0, 90)
        banner.Position = UDim2.new(0.5, -260, 0.35, 0)
        banner.BackgroundTransparency = 1
        banner.TextScaled = true
        banner.Font = Enum.Font.GothamBlack
        banner.TextTransparency = 1
        banner.Text = ""
        banner.Parent = gui
        local bannerStroke = Instance.new("UIStroke")
        bannerStroke.Thickness = 3
        bannerStroke.Color = Color3.new(0, 0, 0)
        bannerStroke.Parent = banner
        local bannerToken = 0

        local function showBanner(text, color)
            bannerToken = bannerToken + 1
            local token = bannerToken
            banner.Text = text
            banner.TextColor3 = color
            banner.TextTransparency = 0
            banner.Size = UDim2.new(0, 640, 0, 110)
            TweenService:Create(banner, TweenInfo.new(0.15), { Size = UDim2.new(0, 520, 0, 90) }):Play()
            task.delay(1.2, function()
                if token == bannerToken and running then
                    TweenService:Create(banner, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
                end
            end)
        end

        local function updateStats()
            statLabel.Text = "PRACTICE KNIFE THROW  |  kills " .. stats.kills .. "  headshots " .. stats.heads
        end

        local function hitBot(inst)
            local model = inst:FindFirstAncestorOfClass("Model")
            local bot = model and bots[model]
            if not bot or bot.state ~= "up" then return end
            local head = inst.Name == "Head"
            stats.kills = stats.kills + 1
            if head then stats.heads = stats.heads + 1 end
            updateStats()
            if head then
                showBanner("HEADSHOT", Color3.fromRGB(255, 70, 90))
            else
                showBanner("Throwing Kill!", COLOR_GOLD)
            end
            playPracticeSound("Kill", rangeFolder)
            bot.state = "falling"
            bot.t = 0
        end

        local projectiles = {}
        local lastThrow = 0

        local function stick(pr, pos)
            pr.part.CFrame = CFrame.lookAt(pos, pos + pr.vel)
            pr.part.Anchored = true
            local part = pr.part
            task.delay(STICK_TIME, function()
                if part.Parent then part:Destroy() end
            end)
        end

        local function throwKnife()
            if not running then return end
            if os.clock() - lastThrow < THROW_COOLDOWN then return end
            lastThrow = os.clock()
            local look = cam.CFrame.LookVector
            local origin = cam.CFrame.Position + look * 2
            local visual = makeKnifeVisual()
            visual.Parent = rangeFolder
            visual.CFrame = CFrame.lookAt(origin, origin + look)
            playPracticeSound("Throw", visual)
            if practiceTracks.ThrowKnife then practiceTracks.ThrowKnife:Play(0.1, 6, 1) end
            table.insert(projectiles, { part = visual, pos = origin, origin = origin, vel = look * THROW_SPEED })
        end

        local heartbeat = RunService.Heartbeat:Connect(function(dt)
            if not running then return end

            -- knife flight, local raycasts only
            for i = #projectiles, 1, -1 do
                local pr = projectiles[i]
                pr.vel = pr.vel - Vector3.new(0, GRAVITY, 0) * dt
                local prev = pr.pos
                local nxt = prev + pr.vel * dt
                local delta = nxt - prev
                local hitB = workspace:Raycast(prev, delta, botParams)
                local hitG = (not hitB) and workspace:Raycast(prev, delta, geoParams)
                if hitB then
                    hitBot(hitB.Instance)
                    stick(pr, hitB.Position)
                    table.remove(projectiles, i)
                elseif hitG then
                    stick(pr, hitG.Position)
                    table.remove(projectiles, i)
                elseif (nxt - pr.origin).Magnitude > 600 then
                    pr.part:Destroy()
                    table.remove(projectiles, i)
                else
                    pr.pos = nxt
                    pr.part.CFrame = CFrame.lookAt(nxt, nxt + pr.vel)
                end
            end

            -- bots: fall, stay down, then stand back up
            local now = os.clock()
            for _, bot in pairs(bots) do
                if bot.state == "falling" then
                    bot.t = math.min(1, bot.t + dt / FALL_TIME)
                    bot.model:PivotTo(bot.cf * CFrame.Angles(-math.rad(90) * bot.t, 0, 0))
                    if bot.t >= 1 then
                        bot.state = "down"
                        bot.respawnAt = now + BOT_RESPAWN
                    end
                elseif bot.state == "down" and now >= bot.respawnAt then
                    bot.state = "up"
                    bot.model:PivotTo(bot.cf)
                end
            end
        end)

        -- same flow as the real knife: a quick right-click tap (or a tap) starts the charge,
        -- the knife throws when the charge finishes, then the cooldown applies
        local charging = false
        local pressStart = 0
        local function startCharge()
            if not running or charging then return end
            local left = THROW_COOLDOWN - (os.clock() - lastThrow)
            if left > 0 then
                setStatus(string.format("Knife recharging: %.1fs", left), COLOR_TEXT)
                return
            end
            charging = true
            setStatus("Charging...", COLOR_GOLD)
            if practiceTracks.ThrowCharge then
                practiceTracks.ThrowCharge:Play(0.1, 2.5, 1 / THROW_CHARGE)
            end
            task.delay(THROW_CHARGE, function()
                if charging and running then
                    charging = false
                    if practiceTracks.ThrowCharge then practiceTracks.ThrowCharge:Stop() end
                    throwKnife()
                end
            end)
        end

        -- right-click is read without the game-processed check, like the real knife does
        local input = UserInputService.InputBegan:Connect(function(io, gp)
            if not running then return end
            if io.UserInputType == Enum.UserInputType.MouseButton2 then
                pressStart = os.clock()
            elseif io.UserInputType == Enum.UserInputType.Touch and not gp then
                startCharge()
            end
        end)
        local inputEnded = UserInputService.InputEnded:Connect(function(io)
            if not running then return end
            if io.UserInputType == Enum.UserInputType.MouseButton2 and os.clock() - pressStart <= 0.3 then
                startCharge()
            end
        end)

        -- stand on the throw line, facing the bots
        if hrp then
            hrp.CFrame = CFrame.lookAt(RANGE_CENTER + Vector3.new(0, 3, -10), RANGE_CENTER + Vector3.new(0, 3, 30))
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        setStatus("Practice knife throw: right-click tap to charge and throw", COLOR_GOLD)

        return function()
            running = false
            heartbeat:Disconnect()
            input:Disconnect()
            inputEnded:Disconnect()
            charging = false
            for _, t in pairs(practiceTracks) do pcall(function() t:Stop() end) end
            if practiceTool then pcall(function() practiceTool:Destroy() end) end
            for _, pr in ipairs(projectiles) do
                if pr.part.Parent then pr.part:Destroy() end
            end
            projectiles = {}
            rangeFolder:Destroy()
            gui:Destroy()
            local c = player.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if r and savedCF then
                r.CFrame = savedCF
                r.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end

    GAMES.KNIFE = startPracticeKnife
end

-- PRACTICE SHERIFF: a private gun range far above the map. Bots, shots and tracers are local
-- only. Nothing is sent to the server, so other players are never affected.
do
    local RANGE_CENTER = Vector3.new(0, 4000, 0)
    local SHOT_COOLDOWN = 0.4
    local SHOT_RANGE = 600
    local BOT_RESPAWN = 2
    local FALL_TIME = 0.3
    local TRACER_TIME = 0.12

    local function makePart(parent, props)
        local p = Instance.new("Part")
        p.Anchored = true
        p.CanCollide = true
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Material = Enum.Material.SmoothPlastic
        for k, v in pairs(props) do p[k] = v end
        p.Parent = parent
        return p
    end

    local function buildRange(rangeFolder)
        local geo = Instance.new("Folder")
        geo.Name = "Geometry"
        geo.Parent = rangeFolder
        local o = RANGE_CENTER
        makePart(geo, { Name = "Floor", Size = Vector3.new(160, 2, 200), CFrame = CFrame.new(o + Vector3.new(0, -1, 40)), Color = Color3.fromRGB(70, 75, 90) })
        makePart(geo, { Name = "Lane", Size = Vector3.new(6, 0.1, 200), CFrame = CFrame.new(o + Vector3.new(0, 0.05, 40)), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon, CanCollide = false })
        local back = makePart(geo, { Name = "BackWall", Size = Vector3.new(160, 40, 2), CFrame = CFrame.new(o + Vector3.new(0, 20, 141)), Color = Color3.fromRGB(40, 44, 58) })
        makePart(geo, { Name = "LeftWall", Size = Vector3.new(2, 40, 200), CFrame = CFrame.new(o + Vector3.new(-80, 20, 40)), Color = Color3.fromRGB(40, 44, 58) })
        makePart(geo, { Name = "RightWall", Size = Vector3.new(2, 40, 200), CFrame = CFrame.new(o + Vector3.new(80, 20, 40)), Color = Color3.fromRGB(40, 44, 58) })
        makePart(geo, { Name = "Roof", Size = Vector3.new(160, 2, 200), CFrame = CFrame.new(o + Vector3.new(0, 40, 40)), Color = Color3.fromRGB(30, 32, 44), Transparency = 0.2 })
        for _, z in ipairs({ 20, 40, 60, 80 }) do
            local m = makePart(geo, { Name = "Marker", Size = Vector3.new(160, 0.15, 1), CFrame = CFrame.new(o + Vector3.new(0, 0.1, z)), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon, CanCollide = false })
            local g = Instance.new("SurfaceGui")
            g.Face = Enum.NormalId.Top
            g.Parent = m
            local l = Instance.new("TextLabel")
            l.Size = UDim2.fromScale(1, 1)
            l.BackgroundTransparency = 1
            l.Text = z .. " studs"
            l.TextColor3 = Color3.fromRGB(120, 200, 255)
            l.TextScaled = true
            l.Font = Enum.Font.GothamBold
            l.Parent = g
        end
        local sign = Instance.new("SurfaceGui")
        sign.Face = Enum.NormalId.Front
        sign.Parent = back
        local st = Instance.new("TextLabel")
        st.Size = UDim2.fromScale(1, 1)
        st.BackgroundTransparency = 1
        st.Text = "PRACTICE SHERIFF"
        st.TextColor3 = Color3.fromRGB(120, 180, 255)
        st.TextScaled = true
        st.Font = Enum.Font.GothamBlack
        st.Parent = sign
        return geo
    end

    local function makeBot(folder, cf)
        local model = Instance.new("Model")
        model.Name = "PracticeBot"
        local torso = makePart(model, { Name = "Torso", Size = Vector3.new(2, 2, 1), CFrame = cf, Color = Color3.fromRGB(200, 60, 60) })
        model.PrimaryPart = torso
        local function attach(name, size, offset, color, shape)
            local p = makePart(model, { Name = name, Size = size, CFrame = cf * CFrame.new(offset), Color = color, Anchored = false, Shape = shape or Enum.PartType.Block })
            local w = Instance.new("WeldConstraint")
            w.Part0 = torso
            w.Part1 = p
            w.Parent = p
        end
        attach("Head", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 1.8, 0), Color3.fromRGB(245, 205, 170), Enum.PartType.Ball)
        attach("LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), Color3.fromRGB(200, 60, 60))
        attach("RightArm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), Color3.fromRGB(200, 60, 60))
        attach("LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), Color3.fromRGB(40, 40, 60))
        attach("RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), Color3.fromRGB(40, 40, 60))
        model.Parent = folder
        return model
    end

    local function startPracticeSheriff()
        local running = true
        local cam = workspace.CurrentCamera

        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local savedCF = hrp and hrp.CFrame

        local gui = Instance.new("ScreenGui")
        gui.Name = "MM2Hub_SheriffRange"
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 60
        gui.Parent = playerGui

        local rangeFolder = Instance.new("Folder")
        rangeFolder.Name = "MM2Hub_SheriffRange"
        rangeFolder.Parent = workspace
        local geo = buildRange(rangeFolder)
        local botsFolder = Instance.new("Folder")
        botsFolder.Name = "Bots"
        botsFolder.Parent = rangeFolder

        local bots = {}
        local layout = { { -20, 30 }, { 0, 30 }, { 20, 30 }, { -10, 55 }, { 10, 55 }, { 0, 75 } }
        for _, p in ipairs(layout) do
            local cf = CFrame.new(RANGE_CENTER + Vector3.new(p[1], 3, p[2]))
            local model = makeBot(botsFolder, cf)
            bots[model] = { model = model, cf = cf, state = "up", t = 0, respawnAt = 0 }
        end

        local botParams = RaycastParams.new()
        botParams.FilterType = Enum.RaycastFilterType.Include
        botParams.FilterDescendantsInstances = { botsFolder }
        local geoParams = RaycastParams.new()
        geoParams.FilterType = Enum.RaycastFilterType.Include
        geoParams.FilterDescendantsInstances = { geo }

        local stats = { kills = 0, heads = 0, shots = 0 }
        local statLabel = Instance.new("TextLabel")
        statLabel.Size = UDim2.new(0, 400, 0, 28)
        statLabel.Position = UDim2.new(0.5, -200, 0, 60)
        statLabel.BackgroundTransparency = 1
        statLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
        statLabel.TextStrokeTransparency = 0.5
        statLabel.TextScaled = true
        statLabel.Font = Enum.Font.GothamBold
        statLabel.Parent = gui
        local function updateStats()
            statLabel.Text = "PRACTICE SHERIFF  |  kills " .. stats.kills .. "  headshots " .. stats.heads .. "  shots " .. stats.shots
        end
        updateStats()

        local banner = Instance.new("TextLabel")
        banner.Size = UDim2.new(0, 520, 0, 90)
        banner.Position = UDim2.new(0.5, -260, 0.35, 0)
        banner.BackgroundTransparency = 1
        banner.TextScaled = true
        banner.Font = Enum.Font.GothamBlack
        banner.TextTransparency = 1
        banner.Text = ""
        banner.Parent = gui
        local bannerStroke = Instance.new("UIStroke")
        bannerStroke.Thickness = 3
        bannerStroke.Color = Color3.new(0, 0, 0)
        bannerStroke.Parent = banner
        local bannerToken = 0

        local function showBanner(text, color)
            bannerToken = bannerToken + 1
            local token = bannerToken
            banner.Text = text
            banner.TextColor3 = color
            banner.TextTransparency = 0
            banner.Size = UDim2.new(0, 640, 0, 110)
            TweenService:Create(banner, TweenInfo.new(0.15), { Size = UDim2.new(0, 520, 0, 90) }):Play()
            task.delay(1.2, function()
                if token == bannerToken and running then
                    TweenService:Create(banner, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
                end
            end)
        end

        local function hitBot(inst)
            local model = inst:FindFirstAncestorOfClass("Model")
            local bot = model and bots[model]
            if not bot or bot.state ~= "up" then return end
            local head = inst.Name == "Head"
            stats.kills = stats.kills + 1
            if head then stats.heads = stats.heads + 1 end
            updateStats()
            if head then
                showBanner("HEADSHOT", Color3.fromRGB(255, 70, 90))
            else
                showBanner("Shot Kill", COLOR_GOLD)
            end
            bot.state = "falling"
            bot.t = 0
        end

        -- a short local beam from the muzzle to where the shot landed
        local function drawTracer(from, to)
            local len = (to - from).Magnitude
            if len < 0.1 then return end
            local beam = makePart(rangeFolder, { Name = "Tracer", Size = Vector3.new(0.15, 0.15, len), CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2),
                Color = Color3.fromRGB(255, 240, 180), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
            task.delay(TRACER_TIME, function()
                if beam.Parent then beam:Destroy() end
            end)
        end

        local lastShot = 0
        local function fire()
            if not running then return end
            if os.clock() - lastShot < SHOT_COOLDOWN then return end
            lastShot = os.clock()
            stats.shots = stats.shots + 1
            local look = cam.CFrame.LookVector
            local origin = cam.CFrame.Position + look * 2
            local hitB = workspace:Raycast(origin, look * SHOT_RANGE, botParams)
            local hitG = (not hitB) and workspace:Raycast(origin, look * SHOT_RANGE, geoParams)
            local endPos = origin + look * SHOT_RANGE
            if hitB then
                endPos = hitB.Position
                hitBot(hitB.Instance)
            elseif hitG then
                endPos = hitG.Position
            end
            drawTracer(origin, endPos)
            updateStats()
        end

        local heartbeat = RunService.Heartbeat:Connect(function(dt)
            if not running then return end
            local now = os.clock()
            for _, bot in pairs(bots) do
                if bot.state == "falling" then
                    bot.t = math.min(1, bot.t + dt / FALL_TIME)
                    bot.model:PivotTo(bot.cf * CFrame.Angles(-math.rad(90) * bot.t, 0, 0))
                    if bot.t >= 1 then
                        bot.state = "down"
                        bot.respawnAt = now + BOT_RESPAWN
                    end
                elseif bot.state == "down" and now >= bot.respawnAt then
                    bot.state = "up"
                    bot.model:PivotTo(bot.cf)
                end
            end
        end)

        local input = UserInputService.InputBegan:Connect(function(io, gp)
            if gp or not running then return end
            if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
                fire()
            end
        end)

        if hrp then
            hrp.CFrame = CFrame.lookAt(RANGE_CENTER + Vector3.new(0, 3, -10), RANGE_CENTER + Vector3.new(0, 3, 30))
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        setStatus("Practice sheriff: click or tap to shoot", COLOR_BLUE)

        return function()
            running = false
            heartbeat:Disconnect()
            input:Disconnect()
            rangeFolder:Destroy()
            gui:Destroy()
            local c = player.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if r and savedCF then
                r.CFrame = savedCF
                r.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end

    GAMES.SHERIFF = startPracticeSheriff
end

-- CHESS: lives in MM2_Chess.lua, fetched the first time you open it
do
    local chessModule = nil
    GAMES.CHESS = function()
        if not chessModule then
            local okLoad, mod = pcall(function()
                return loadstring(game:HttpGet(base .. "MM2_Chess.lua?cb=" .. tostring(os.time())))()
            end)
            if not okLoad or type(mod) ~= "table" or not mod.open then
                setStatus("Chess failed to load: " .. tostring(mod), COLOR_RED)
                return nil
            end
            chessModule = mod
        end
        syncTheme()
        return chessModule.open({
            player = player, playerGui = playerGui,
            activeFont = activeFont, activeThemeDef = activeThemeDef, corner = corner,
            COLOR_TEXT = COLOR_TEXT, COLOR_DIM = COLOR_DIM, COLOR_GOLD = COLOR_GOLD,
            COLOR_RED = COLOR_RED, COLOR_GREEN = COLOR_GREEN,
            onClose = function() stopGame() end,
        })
    end
end

;(function() -- game menu: a card for each game
    local ENTRIES = {
        { key = "STACK", icon = "🧱", name = "BLOCK STACK", desc = "Drop blocks onto the tower", color = COLOR_GOLD },
        { key = "OBBY", icon = "🏃", name = "OBBY RUN", desc = "Climb the platforms", color = Color3.fromRGB(80, 220, 120) },
        { key = "LOOT", icon = "💰", name = "LOOT RUSH", desc = "Grab orbs before time runs out", color = Color3.fromRGB(180, 80, 255) },
        { key = "DODGE", icon = "☄", name = "DODGE", desc = "Survive the falling blocks", color = COLOR_RED },
        { key = "REACTION", icon = "⚡", name = "REACTION TEST", desc = "How fast are your reflexes?", color = COLOR_BLUE },
        { key = "TARGET", icon = "🎯", name = "TARGET RUSH", desc = "Click the floating 3D targets", color = Color3.fromRGB(80, 220, 255) },
        { key = "SIMON", icon = "🟥", name = "SIMON PADS", desc = "Repeat the growing color pattern", color = Color3.fromRGB(255, 120, 0) },
        { key = "WHACK", icon = "🐹", name = "WHACK-A-MOLE", desc = "Smash the moles, fast", color = Color3.fromRGB(150, 110, 60) },
        { key = "COLOR", icon = "🎨", name = "COLOR MATCH", desc = "Click the ink color, not the word", color = Color3.fromRGB(255, 80, 180) },
        { key = "BUBBLE", icon = "🫧", name = "BUBBLE POP", desc = "Pop the bubbles before they escape", color = Color3.fromRGB(90, 200, 255) },
        { key = "MEMORY", icon = "🃏", name = "MEMORY FLIP", desc = "Find all 8 matching pairs", color = Color3.fromRGB(255, 170, 60) },
        { key = "PUZZLE", icon = "🧩", name = "SLIDE PUZZLE", desc = "Slide the tiles back in order", color = Color3.fromRGB(160, 255, 120) },
        { key = "KNIFE", icon = "🔪", name = "PRACTICE KNIFE", desc = "Throw at bots, only you see it", color = COLOR_RED },
        { key = "SHERIFF", icon = "🔫", name = "PRACTICE SHERIFF", desc = "Shoot bots, only you see it", color = COLOR_BLUE },
        { key = "CHESS", icon = "👑", name = "CHESS", desc = "Bots 100-3000 ELO, fake ELO access", color = Color3.fromRGB(240, 200, 120) },
    }
    local CARD_H = 74

    for i, e in ipairs(ENTRIES) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local card = Instance.new("TextButton")
        card.Size = UDim2.new(0.5, -10, 0, CARD_H - 8)
        card.Position = UDim2.new(col * 0.5, col == 0 and 6 or 4, 0, row * CARD_H + 4)
        card.BackgroundColor3 = Color3.fromRGB(26, 26, 40)
        card.BorderSizePixel = 0
        card.AutoButtonColor = false
        card.Text = ""
        card.Parent = gamesPage
        corner(card, 12)

        local cGrad = Instance.new("UIGradient")
        cGrad.Color = ColorSequence.new(Color3.fromRGB(44, 40, 70), Color3.fromRGB(16, 16, 26))
        cGrad.Rotation = 90
        cGrad.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Color = e.color
        cStroke.Thickness = 1.5
        cStroke.Parent = card

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0, 46, 0, 46)
        icon.Position = UDim2.new(0, 8, 0.5, -23)
        icon.BackgroundColor3 = e.color
        icon.BackgroundTransparency = 0.2
        icon.Text = e.icon
        icon.TextScaled = true
        icon.Parent = card
        corner(icon, 23)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -72, 0, 24)
        title.Position = UDim2.new(0, 64, 0, 8)
        title.BackgroundTransparency = 1
        title.Text = e.name
        title.TextColor3 = COLOR_TEXT
        title.TextScaled = true
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Font = activeFont
        title.Parent = card

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, -72, 0, 18)
        sub.Position = UDim2.new(0, 64, 0, 32)
        sub.BackgroundTransparency = 1
        sub.Text = e.desc
        sub.TextColor3 = COLOR_DIM
        sub.TextScaled = true
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Font = activeFont
        sub.Parent = card

        card.MouseButton1Down:Connect(function()
            TweenService:Create(cStroke, TweenInfo.new(0.06), { Thickness = 3.5 }):Play()
        end)
        getgenv().MM2HubClick(card, "MouseButton1Up", function()
            TweenService:Create(cStroke, TweenInfo.new(0.15), { Thickness = 1.5 }):Play()
        end)
        getgenv().MM2HubClick(card, "MouseButton1Click", function()
            toggleGame(e.key)
        end)
    end

    local rows = math.ceil(#ENTRIES / 2)
    local stopGameBtn = makeButton(gamesPage, "■ STOP GAME", rows * CARD_H + 4, COLOR_DIM)
    getgenv().MM2HubClick(stopGameBtn, "MouseButton1Click", function() stopGame() end)
    if gamesPage:IsA("ScrollingFrame") then
        gamesPage.CanvasSize = UDim2.new(0, 0, 0, rows * CARD_H + 120)
    end
end)()

local gamesInfo = Instance.new("TextLabel")
gamesInfo.Size = UDim2.new(1, 0, 0, 80)
gamesInfo.Position = UDim2.new(0, 0, 0, 500)
gamesInfo.BackgroundTransparency = 1
gamesInfo.Text = "Original mini-games in the style of Block Blast, Stumble Guys and Steal a Brainrot. They run only on your client, so nobody else sees them. Your character is teleported during Obby and Loot Rush, and returns when you stop."
gamesInfo.TextColor3 = COLOR_DIM
gamesInfo.TextScaled = true
gamesInfo.TextWrapped = true
gamesInfo.Font = activeFont
gamesInfo.ZIndex = 3
gamesInfo.Parent = gamesPage

player.CharacterAdded:Connect(function()
    stopGame(true)
end)
end
