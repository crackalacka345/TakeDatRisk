-- MM2_Chess.lua
-- Chess window for MM2 Helper, opened from the GAMES tab (loaded by MM2_Games.lua).
-- Bots use a small Luau engine scaled to approximate ELO levels 100-3000.
-- The FAKE ELO panel asks your Discord bot for permission (webhook or web address); a granted client is remembered.

local HttpService = game:GetService("HttpService")

-- ===================== ENGINE BEGIN (pure Lua, no Roblox calls) =====================
-- Board: E.b[0..63] where 0 = a8 and 63 = h1. Row = sq // 8 (0 = rank 8), col = sq % 8 (0 = file a).
-- Pieces: "P N B R Q K" for white, "p n b r q k" for black, "." for empty.
local E = {}

local WHITE = { P = true, N = true, B = true, R = true, Q = true, K = true }
local BLACK = { p = true, n = true, b = true, r = true, q = true, k = true }
local VALUE = { P = 100, N = 320, B = 330, R = 500, Q = 900, K = 0 }
local MATE = 100000
local KNIGHT_D = { { -2, -1 }, { -2, 1 }, { -1, -2 }, { -1, 2 }, { 1, -2 }, { 1, 2 }, { 2, -1 }, { 2, 1 } }
local KING_D = { { -1, -1 }, { -1, 0 }, { -1, 1 }, { 0, -1 }, { 0, 1 }, { 1, -1 }, { 1, 0 }, { 1, 1 } }
local DIAG_D = { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }
local ORTH_D = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
E.START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

-- small bonus for pieces near the centre
local CENTER = {}
for sq = 0, 63 do
    local r, c = math.floor(sq / 8), sq % 8
    local d = math.max(math.abs(r - 3.5), math.abs(c - 3.5))
    CENTER[sq] = math.floor((3.5 - d) * 4)
end

local function inside(r, c)
    return r >= 0 and r < 8 and c >= 0 and c < 8
end

local function ofColor(p, white)
    if p == "." then return false end
    if white then return WHITE[p] == true end
    return BLACK[p] == true
end

local function findKing(b, white)
    local k = white and "K" or "k"
    for i = 0, 63 do
        if b[i] == k then return i end
    end
    return nil
end

function E.fromFen(fen)
    local parts = {}
    for w in fen:gmatch("%S+") do table.insert(parts, w) end
    local s = { b = {}, turn = "w", castle = { K = false, Q = false, k = false, q = false }, ep = -1, half = 0, full = 1 }
    for i = 0, 63 do s.b[i] = "." end
    local r, c = 0, 0
    for ch in parts[1]:gmatch(".") do
        if ch == "/" then
            r = r + 1
            c = 0
        elseif ch:match("%d") then
            c = c + tonumber(ch)
        else
            s.b[r * 8 + c] = ch
            c = c + 1
        end
    end
    s.turn = (parts[2] == "b") and "b" or "w"
    local cs = parts[3] or "-"
    s.castle.K = cs:find("K") ~= nil
    s.castle.Q = cs:find("Q") ~= nil
    s.castle.k = cs:find("k") ~= nil
    s.castle.q = cs:find("q") ~= nil
    local ep = parts[4]
    if ep and ep ~= "-" then
        local file = string.byte(ep, 1) - 97
        local rank = tonumber(ep:sub(2, 2))
        s.ep = (8 - rank) * 8 + file
    end
    s.half = tonumber(parts[5] or "0") or 0
    s.full = tonumber(parts[6] or "1") or 1
    return s
end

function E.newGame()
    return E.fromFen(E.START_FEN)
end

function E.isAttacked(b, sq, byWhite)
    local r, c = math.floor(sq / 8), sq % 8
    -- a white pawn attacks upward, so it stands one row below its target (and vice versa)
    local pr = r + (byWhite and 1 or -1)
    local pc = byWhite and "P" or "p"
    if inside(pr, c - 1) and b[pr * 8 + c - 1] == pc then return true end
    if inside(pr, c + 1) and b[pr * 8 + c + 1] == pc then return true end

    local nc = byWhite and "N" or "n"
    for _, d in ipairs(KNIGHT_D) do
        local rr, cc = r + d[1], c + d[2]
        if inside(rr, cc) and b[rr * 8 + cc] == nc then return true end
    end
    local kc = byWhite and "K" or "k"
    for _, d in ipairs(KING_D) do
        local rr, cc = r + d[1], c + d[2]
        if inside(rr, cc) and b[rr * 8 + cc] == kc then return true end
    end
    local bc = byWhite and "B" or "b"
    local qc = byWhite and "Q" or "q"
    local rc = byWhite and "R" or "r"
    for _, d in ipairs(DIAG_D) do
        local rr, cc = r + d[1], c + d[2]
        while inside(rr, cc) do
            local p = b[rr * 8 + cc]
            if p ~= "." then
                if p == bc or p == qc then return true end
                break
            end
            rr, cc = rr + d[1], cc + d[2]
        end
    end
    for _, d in ipairs(ORTH_D) do
        local rr, cc = r + d[1], c + d[2]
        while inside(rr, cc) do
            local p = b[rr * 8 + cc]
            if p ~= "." then
                if p == rc or p == qc then return true end
                break
            end
            rr, cc = rr + d[1], cc + d[2]
        end
    end
    return false
end

function E.inCheck(s)
    local white = s.turn == "w"
    local k = findKing(s.b, white)
    return k ~= nil and E.isAttacked(s.b, k, not white)
end

-- pseudo-legal moves (may leave own king in check); capsOnly keeps captures and promotions
function E.genPseudo(s, capsOnly)
    local out = {}
    local white = s.turn == "w"
    local b = s.b

    local function add(from, to, cap, promo, ep, castle)
        out[#out + 1] = { from = from, to = to, cap = cap, promo = promo, ep = ep, castle = castle }
    end

    local function addPawn(from, to, cap, ep, promoRow)
        if math.floor(to / 8) == promoRow then
            for _, pr in ipairs({ "Q", "R", "B", "N" }) do
                add(from, to, cap, pr, ep, false)
            end
        else
            add(from, to, cap, nil, ep, false)
        end
    end

    for sq = 0, 63 do
        local p = b[sq]
        if ofColor(p, white) then
            local up = string.upper(p)
            local r, c = math.floor(sq / 8), sq % 8
            if up == "P" then
                local dir = white and -1 or 1
                local startRow = white and 6 or 1
                local promoRow = white and 0 or 7
                local r1 = r + dir
                if inside(r1, c) and b[r1 * 8 + c] == "." then
                    addPawn(sq, r1 * 8 + c, ".", false, promoRow)
                    local r2 = r + 2 * dir
                    if r == startRow and b[r2 * 8 + c] == "." then
                        add(sq, r2 * 8 + c, ".", nil, false, false)
                    end
                end
                for _, dc in ipairs({ -1, 1 }) do
                    local cc = c + dc
                    if inside(r1, cc) then
                        local t = r1 * 8 + cc
                        local target = b[t]
                        if target ~= "." and not ofColor(target, white) then
                            addPawn(sq, t, target, false, promoRow)
                        elseif t == s.ep then
                            local captured = white and "p" or "P"
                            add(sq, t, captured, nil, true, false)
                        end
                    end
                end
            elseif up == "N" or up == "K" then
                local dirs = (up == "N") and KNIGHT_D or KING_D
                for _, d in ipairs(dirs) do
                    local rr, cc = r + d[1], c + d[2]
                    if inside(rr, cc) then
                        local t = rr * 8 + cc
                        local target = b[t]
                        if target == "." then
                            add(sq, t, ".", nil, false, false)
                        elseif not ofColor(target, white) then
                            add(sq, t, target, nil, false, false)
                        end
                    end
                end
                if up == "K" then
                    local ks = white and 60 or 4
                    local rookL = white and "R" or "r"
                    local kingHere = white and "K" or "k"
                    if sq == ks and b[ks] == kingHere and not E.isAttacked(b, ks, not white) then
                        local rightK = white and s.castle.K or s.castle.k
                        local rightQ = white and s.castle.Q or s.castle.q
                        -- king side: f and g empty and safe, rook on h
                        if rightK and b[ks + 1] == "." and b[ks + 2] == "." and b[ks + 3] == rookL
                            and not E.isAttacked(b, ks + 1, not white) and not E.isAttacked(b, ks + 2, not white) then
                            add(sq, ks + 2, ".", nil, false, true)
                        end
                        -- queen side: d, c and b empty, d and c safe, rook on a
                        if rightQ and b[ks - 1] == "." and b[ks - 2] == "." and b[ks - 3] == "." and b[ks - 4] == rookL
                            and not E.isAttacked(b, ks - 1, not white) and not E.isAttacked(b, ks - 2, not white) then
                            add(sq, ks - 2, ".", nil, false, true)
                        end
                    end
                end
            else
                local dirs = {}
                if up == "B" or up == "Q" then
                    for _, d in ipairs(DIAG_D) do table.insert(dirs, d) end
                end
                if up == "R" or up == "Q" then
                    for _, d in ipairs(ORTH_D) do table.insert(dirs, d) end
                end
                for _, d in ipairs(dirs) do
                    local rr, cc = r + d[1], c + d[2]
                    while inside(rr, cc) do
                        local t = rr * 8 + cc
                        local target = b[t]
                        if target == "." then
                            add(sq, t, ".", nil, false, false)
                        else
                            if not ofColor(target, white) then
                                add(sq, t, target, nil, false, false)
                            end
                            break
                        end
                        rr, cc = rr + d[1], cc + d[2]
                    end
                end
            end
        end
    end

    if capsOnly then
        local kept = {}
        for _, m in ipairs(out) do
            if m.cap ~= "." or m.promo then table.insert(kept, m) end
        end
        return kept
    end
    return out
end

function E.makeMove(s, m)
    local n = {
        b = {},
        turn = (s.turn == "w") and "b" or "w",
        castle = { K = s.castle.K, Q = s.castle.Q, k = s.castle.k, q = s.castle.q },
        ep = -1,
        half = s.half + 1,
        full = (s.turn == "b") and (s.full + 1) or s.full,
    }
    for i = 0, 63 do n.b[i] = s.b[i] end

    local p = s.b[m.from]
    local white = WHITE[p] == true
    n.b[m.from] = "."
    local placed = p
    if m.promo then
        placed = white and m.promo or string.lower(m.promo)
    end
    if m.ep then
        n.b[math.floor(m.from / 8) * 8 + m.to % 8] = "."
    end
    n.b[m.to] = placed

    if m.castle then
        if m.to == 62 then n.b[61] = n.b[63]; n.b[63] = "."
        elseif m.to == 58 then n.b[59] = n.b[56]; n.b[56] = "."
        elseif m.to == 6 then n.b[5] = n.b[7]; n.b[7] = "."
        elseif m.to == 2 then n.b[3] = n.b[0]; n.b[0] = "."
        end
    end

    local up = string.upper(p)
    if up == "P" and math.abs(m.to - m.from) == 16 then
        n.ep = math.floor((m.from + m.to) / 2)
    end
    if up == "P" or m.cap ~= "." then
        n.half = 0
    end

    if up == "K" then
        if white then
            n.castle.K = false
            n.castle.Q = false
        else
            n.castle.k = false
            n.castle.q = false
        end
    end
    local function revoke(sq)
        if sq == 63 then n.castle.K = false
        elseif sq == 56 then n.castle.Q = false
        elseif sq == 7 then n.castle.k = false
        elseif sq == 0 then n.castle.q = false
        end
    end
    revoke(m.from)
    revoke(m.to)
    return n
end

function E.legalMoves(s)
    local white = s.turn == "w"
    local out = {}
    local pseudo = E.genPseudo(s, false)
    for _, m in ipairs(pseudo) do
        local n = E.makeMove(s, m)
        local k = findKing(n.b, white)
        if k and not E.isAttacked(n.b, k, not white) then
            table.insert(out, m)
        end
    end
    return out
end

function E.perft(s, depth)
    if depth == 0 then return 1 end
    local total = 0
    for _, m in ipairs(E.legalMoves(s)) do
        total = total + E.perft(E.makeMove(s, m), depth - 1)
    end
    return total
end

-- score from the side to move's point of view
function E.evaluate(s)
    local score = 0
    for sq = 0, 63 do
        local p = s.b[sq]
        if p ~= "." then
            local up = string.upper(p)
            local v = VALUE[up]
            if up == "N" or up == "B" or up == "P" then
                v = v + CENTER[sq]
            end
            if WHITE[p] then score = score + v else score = score - v end
        end
    end
    if s.turn == "w" then return score end
    return -score
end

local function mvvOrder(m)
    local v = 0
    if m.cap ~= "." then v = (VALUE[string.upper(m.cap)] or 0) * 10 end
    if m.promo then v = v + 800 end
    return v
end

local function orderMoves(list)
    for _, m in ipairs(list) do m.ord = mvvOrder(m) end
    table.sort(list, function(a, b) return a.ord > b.ord end)
end
E.orderMoves = orderMoves

function E.quiesce(s, alpha, beta)
    local stand = E.evaluate(s)
    if stand >= beta then return stand end
    if stand > alpha then alpha = stand end
    local white = s.turn == "w"
    local caps = E.genPseudo(s, true)
    orderMoves(caps)
    for _, m in ipairs(caps) do
        local n = E.makeMove(s, m)
        local k = findKing(n.b, white)
        if k and not E.isAttacked(n.b, k, not white) then
            local score = -E.quiesce(n, -beta, -alpha)
            if score >= beta then return score end
            if score > alpha then alpha = score end
        end
    end
    return alpha
end

function E.search(s, depth, alpha, beta, ply)
    if depth <= 0 then return E.quiesce(s, alpha, beta) end
    local moves = E.legalMoves(s)
    if #moves == 0 then
        if E.inCheck(s) then return -(MATE - ply) end
        return 0
    end
    orderMoves(moves)
    local best = -MATE * 4
    for _, m in ipairs(moves) do
        local n = E.makeMove(s, m)
        local score = -E.search(n, depth - 1, -beta, -alpha, ply + 1)
        if score > best then best = score end
        if best > alpha then alpha = best end
        if alpha >= beta then break end
    end
    return best
end

-- cfg = { depth = plies, noise = centipawns of random error at the root, blunder = chance of a random legal move }
-- opts = { budget = seconds (stop deepening after this), yield = function called between root moves }
function E.chooseMove(s, cfg, opts)
    opts = opts or {}
    local moves = E.legalMoves(s)
    if #moves == 0 then return nil end
    if #moves == 1 then return moves[1] end
    if (cfg.blunder or 0) > 0 and math.random() < cfg.blunder then
        return moves[math.random(#moves)]
    end

    local clock = os.clock
    local started = clock()
    local bestMove = moves[1]
    orderMoves(moves)
    for depth = 1, cfg.depth do
        if depth > 1 and opts.budget and clock() - started > opts.budget then break end
        local iterBest, iterScore = nil, -MATE * 4
        for _, m in ipairs(moves) do
            local n = E.makeMove(s, m)
            local score = -E.search(n, depth - 1, -MATE * 4, MATE * 4, 1)
            if (cfg.noise or 0) > 0 then
                score = score + (math.random() * 2 - 1) * cfg.noise
            end
            if iterBest == nil or score > iterScore then
                iterBest, iterScore = m, score
            end
            if opts.yield then opts.yield() end
        end
        bestMove = iterBest
        -- the best move of this depth is searched first next time
        for i, m in ipairs(moves) do
            if m == bestMove then
                table.remove(moves, i)
                table.insert(moves, 1, bestMove)
                break
            end
        end
    end
    return bestMove
end

-- a position key for repetition checks
function E.key(s)
    local parts = {}
    for i = 0, 63 do parts[#parts + 1] = s.b[i] end
    parts[#parts + 1] = s.turn
    parts[#parts + 1] = (s.castle.K and "K" or "") .. (s.castle.Q and "Q" or "") .. (s.castle.k and "k" or "") .. (s.castle.q and "q" or "")
    parts[#parts + 1] = tostring(s.ep)
    return table.concat(parts)
end

-- returns nil while the game goes on, else "mate", "stalemate", "fifty" or "repetition"
function E.outcome(s, history)
    if #E.legalMoves(s) == 0 then
        if E.inCheck(s) then return "mate" end
        return "stalemate"
    end
    if s.half >= 100 then return "fifty" end
    local k = E.key(s)
    local count = 0
    for _, h in ipairs(history) do
        if h == k then count = count + 1 end
    end
    if count >= 3 then return "repetition" end
    return nil
end

-- bot strength table. Ratings are approximate: this is a small Luau engine, not Stockfish.
E.LEVELS = {
    { elo = 100,  depth = 1, noise = 450, blunder = 0.45, budget = 0.5 },
    { elo = 300,  depth = 1, noise = 300, blunder = 0.30, budget = 0.5 },
    { elo = 500,  depth = 1, noise = 180, blunder = 0.15, budget = 0.5 },
    { elo = 800,  depth = 2, noise = 140, blunder = 0.08, budget = 1.0 },
    { elo = 1000, depth = 2, noise = 90,  blunder = 0.04, budget = 1.0 },
    { elo = 1200, depth = 2, noise = 50,  blunder = 0.02, budget = 1.0 },
    { elo = 1400, depth = 2, noise = 25,  blunder = 0,    budget = 1.0 },
    { elo = 1600, depth = 3, noise = 12,  blunder = 0,    budget = 1.5 },
    { elo = 1800, depth = 3, noise = 6,   blunder = 0,    budget = 1.5 },
    { elo = 2000, depth = 3, noise = 0,   blunder = 0,    budget = 2.0 },
    { elo = 2200, depth = 3, noise = 0,   blunder = 0,    budget = 2.0 },
    { elo = 2400, depth = 4, noise = 0,   blunder = 0,    budget = 3.0 },
    { elo = 2600, depth = 4, noise = 0,   blunder = 0,    budget = 3.0 },
    { elo = 2800, depth = 4, noise = 0,   blunder = 0,    budget = 3.0 },
    { elo = 3000, depth = 4, noise = 0,   blunder = 0,    budget = 3.0 },
}

-- ===================== ENGINE END =======================

-- ===================== CHESS WINDOW + FAKE ELO ACCESS =====================
-- Two ways to reach your Discord bot. Set ONE of these before the hub loads:
--   getgenv().MM2ChessWebhookURL = "https://discord.com/api/webhooks/ID/TOKEN"   (webhook, no tunnel needed)
--   getgenv().MM2ChessAccessURL  = "https://your-address"                        (the bot's web server)
local ACCESS_FILE = "MM2Hub/chess_access.json"

local function httpJson(method, url, body)
    local G = getgenv()
    local fn = (G.syn and G.syn.request) or G.request or G.http_request or (G.http and G.http.request)
    if not fn then return nil, "this executor has no request function" end
    local ok, res = pcall(fn, {
        Url = url,
        Method = method,
        Headers = { ["Content-Type"] = "application/json" },
        Body = body and HttpService:JSONEncode(body) or nil,
    })
    if not ok or type(res) ~= "table" then return nil, "request failed" end
    local okJ, data = pcall(function() return HttpService:JSONDecode(res.Body or "") end)
    if not okJ or type(data) ~= "table" then return nil, "bad response" end
    return data
end

local function webhookBase()
    local url = getgenv().MM2ChessWebhookURL
    if type(url) ~= "string" or url == "" then return nil end
    url = url:gsub("%?.*$", "")
    url = url:gsub("/+$", "")
    return url
end

local function webAddress()
    local url = getgenv().MM2ChessAccessURL
    if type(url) ~= "string" or url == "" then return nil end
    return (url:gsub("/+$", ""))
end

local NOT_SET_UP = "access is not set up (set MM2ChessWebhookURL or MM2ChessAccessURL)"

local Access = {}

-- returns state ("pending", "granted", "denied", "none", "invalid", "limited"), nil, note
-- or nil, error text when the answer could not be read
function Access.status(uid, msgId)
    local wh = webhookBase()
    if wh then
        -- webhook mode: the bot writes its answer into the message the game posted
        if not msgId then return "none" end
        local data, err = httpJson("GET", wh .. "/messages/" .. msgId)
        if not data then return nil, err end
        if data.code == 10008 then return "none" end -- the message is gone
        local content = data.content
        if type(content) ~= "string" then return nil, "unexpected reply from Discord" end
        local state, note = content:match("^CHESSSTATUS|(%w+)|[^|]*|[^|]*|?(.*)$")
        if state then return state, nil, (note ~= "" and note or nil) end
        if content:sub(1, 9) == "CHESSREQ|" then return "pending" end -- the bot has not read it yet
        return nil, "unexpected reply from Discord"
    end
    local web = webAddress()
    if web then
        local data, err = httpJson("GET", web .. "/status?userId=" .. uid)
        if not data then return nil, err end
        if type(data.status) ~= "string" then return nil, "unexpected reply from the access server" end
        return data.status
    end
    return nil, NOT_SET_UP
end

-- returns state, msgId (webhook mode only), or nil, nil, error text
function Access.request(uid, username)
    local wh = webhookBase()
    if wh then
        local data, err = httpJson("POST", wh .. "?wait=true", {
            username = "MM2 Chess",
            content = "CHESSREQ|" .. uid .. "|" .. username,
        })
        if not data then return nil, nil, err end
        if type(data.id) ~= "string" then
            return nil, nil, "Discord did not accept the request (check the webhook link)"
        end
        return "pending", data.id
    end
    local web = webAddress()
    if web then
        local data, err = httpJson("POST", web .. "/request", { userId = uid, username = username })
        if not data then return nil, nil, err end
        if type(data.status) ~= "string" then return nil, nil, "unexpected reply from the access server" end
        return data.status
    end
    return nil, nil, NOT_SET_UP
end

-- saved on the client so the request is not asked again (until access is removed)
local function readStore(uid)
    local G = getgenv()
    local ok, data = pcall(function()
        if G.isfile and G.readfile and G.isfile(ACCESS_FILE) then
            return HttpService:JSONDecode(G.readfile(ACCESS_FILE))
        end
        return nil
    end)
    if ok and type(data) == "table" and data.userId == uid then return data end
    return { userId = uid, granted = false }
end

local function writeStore(t)
    local G = getgenv()
    pcall(function()
        if G.makefolder and G.isfolder and not G.isfolder("MM2Hub") then G.makefolder("MM2Hub") end
        if G.writefile then G.writefile(ACCESS_FILE, HttpService:JSONEncode(t)) end
    end)
end

local Chess = {}

-- ctx: playerGui, player, activeFont, activeThemeDef, corner, COLOR_TEXT, COLOR_DIM,
--      COLOR_GOLD, COLOR_RED, COLOR_GREEN, onClose (function to call from the X button)
-- returns a cleanup function
function Chess.open(ctx)
    local playerGui = ctx.playerGui
    local player = ctx.player
    local font = ctx.activeFont or Enum.Font.GothamBold
    local accent = (ctx.activeThemeDef and ctx.activeThemeDef.accent) or Color3.fromRGB(180, 80, 255)
    local corner = ctx.corner
    local C_TEXT, C_DIM = ctx.COLOR_TEXT, ctx.COLOR_DIM
    local C_GOLD, C_RED, C_GREEN = ctx.COLOR_GOLD, ctx.COLOR_RED, ctx.COLOR_GREEN
    local bindClick = getgenv().MM2HubClick
    local uid = tostring(player.UserId)

    local alive = true
    local gen = 0      -- bumps on every new game, so an old bot thread is ignored
    local pollGen = 0
    local game = nil
    local selected = nil
    local targets = {}  -- destination square -> move, for the selected piece
    local botThinking = false
    local levelIndex = 7 -- 1600 by default
    local squares = {}
    local levelBtns = {}

    local function newState()
        local s = E.newGame()
        return { state = s, history = { E.key(s) }, last = nil, over = false }
    end
    game = newState()

    local SQ = 46
    local LIGHT = Color3.fromRGB(232, 218, 188)
    local DARK = Color3.fromRGB(150, 108, 74)
    local SEL = Color3.fromRGB(246, 230, 90)
    local HINT = Color3.fromRGB(120, 210, 120)
    local LAST = Color3.fromRGB(190, 170, 90)

    local function mkLabel(parent, text, size, pos, color)
        local l = Instance.new("TextLabel")
        l.Size = size
        l.Position = pos
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = color
        l.TextScaled = true
        l.TextWrapped = true
        l.Font = font
        l.Parent = parent
        return l
    end

    local function mkBtn(parent, text, size, pos, color)
        local b = Instance.new("TextButton")
        b.Size = size
        b.Position = pos
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Text = text
        b.TextScaled = true
        b.TextColor3 = C_TEXT
        b.Font = font
        b.Parent = parent
        corner(b, 8)
        return b
    end

    -- ---------- window ----------
    local gui = Instance.new("ScreenGui")
    gui.Name = "MM2Hub_Chess"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 60
    gui.Parent = playerGui

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 620, 0, 430)
    main.Position = UDim2.new(0.5, -310, 0.5, -215)
    main.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    corner(main, 12)
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = accent
    mainStroke.Thickness = 2
    mainStroke.Parent = main

    mkLabel(main, "CHESS  |  you play White", UDim2.new(1, -60, 0, 26), UDim2.new(0, 12, 0, 10), C_TEXT)

    local closeBtn = mkBtn(main, "X", UDim2.new(0, 30, 0, 26), UDim2.new(1, -40, 0, 10), C_RED)

    -- ---------- board ----------
    local board = Instance.new("Frame")
    board.Size = UDim2.new(0, SQ * 8, 0, SQ * 8)
    board.Position = UDim2.new(0, 12, 0, 48)
    board.BackgroundTransparency = 1
    board.Parent = main

    local function render()
        local b = game.state.b
        for sq = 0, 63 do
            local s = squares[sq]
            local p = b[sq]
            local isLast = game.last ~= nil and (game.last.from == sq or game.last.to == sq)
            local bg = s.base
            if isLast then bg = LAST end
            if sq == selected then bg = SEL end
            if targets[sq] and p ~= "." then bg = HINT end
            s.btn.BackgroundColor3 = bg
            if p == "." then
                s.piece.Text = ""
            else
                local white = p == string.upper(p)
                s.piece.Text = string.upper(p)
                s.piece.TextColor3 = white and Color3.fromRGB(252, 252, 252) or Color3.fromRGB(28, 28, 34)
                s.stroke.Color = white and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
            end
            s.dot.Visible = (targets[sq] ~= nil) and p == "."
        end
    end

    local onSquare -- defined below, after the game flow functions

    for sq = 0, 63 do
        local r, c = math.floor(sq / 8), sq % 8
        local btn = Instance.new("TextButton")
        btn.Name = "sq" .. sq
        btn.Size = UDim2.new(0, SQ, 0, SQ)
        btn.Position = UDim2.new(0, c * SQ, 0, r * SQ)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Text = ""
        btn.Parent = board

        local piece = Instance.new("TextLabel")
        piece.Size = UDim2.new(0.8, 0, 0.8, 0)
        piece.Position = UDim2.new(0.1, 0, 0.1, 0)
        piece.BackgroundTransparency = 1
        piece.TextScaled = true
        piece.Font = font
        piece.Text = ""
        piece.ZIndex = 2
        piece.Parent = btn
        local pieceStroke = Instance.new("UIStroke")
        pieceStroke.Thickness = 1.2
        pieceStroke.Color = Color3.new(0, 0, 0)
        pieceStroke.Parent = piece

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 14, 0, 14)
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = UDim2.new(0.5, 0, 0.5, 0)
        dot.BackgroundColor3 = HINT
        dot.BorderSizePixel = 0
        dot.Visible = false
        dot.ZIndex = 3
        dot.Parent = btn
        corner(dot, 7)

        squares[sq] = { btn = btn, piece = piece, stroke = pieceStroke, dot = dot, base = ((r + c) % 2 == 0) and LIGHT or DARK }
        bindClick(btn, "MouseButton1Click", function() onSquare(sq) end)
    end

    -- ---------- sidebar ----------
    local side = Instance.new("Frame")
    side.Size = UDim2.new(0, 212, 0, 368)
    side.Position = UDim2.new(0, 396, 0, 48)
    side.BackgroundTransparency = 1
    side.Parent = main

    local statusLbl = mkLabel(side, "Your move (White)", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), C_GOLD)

    mkLabel(side, "BOT STRENGTH (approx. ELO)", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 42), C_DIM)

    local levelList = Instance.new("ScrollingFrame")
    levelList.Size = UDim2.new(1, 0, 0, 170)
    levelList.Position = UDim2.new(0, 0, 0, 62)
    levelList.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
    levelList.BorderSizePixel = 0
    levelList.ScrollBarThickness = 4
    levelList.CanvasSize = UDim2.new(0, 0, 0, #E.LEVELS * 32 + 6)
    levelList.Parent = side
    corner(levelList, 8)

    local function refreshLevels()
        for i, b in ipairs(levelBtns) do
            b.BackgroundColor3 = (i == levelIndex) and accent or Color3.fromRGB(40, 40, 60)
        end
    end

    for i, lv in ipairs(E.LEVELS) do
        local b = mkBtn(levelList, "BOT " .. lv.elo .. " ELO", UDim2.new(1, -10, 0, 28), UDim2.new(0, 5, 0, 4 + (i - 1) * 32), Color3.fromRGB(40, 40, 60))
        levelBtns[i] = b
        bindClick(b, "MouseButton1Click", function()
            levelIndex = i
            refreshLevels()
        end)
    end
    refreshLevels()

    local newBtn = mkBtn(side, "NEW GAME", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 242), Color3.fromRGB(40, 40, 60))
    local resignBtn = mkBtn(side, "RESIGN", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 278), Color3.fromRGB(60, 40, 40))
    local fakeOpenBtn = mkBtn(side, "FAKE ELO", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 314), Color3.fromRGB(40, 40, 60))
    mkLabel(side, "Ratings are approximate. This is a small Luau engine, not Stockfish.", UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 348), C_DIM)

    -- ---------- fake ELO panel (access gated) ----------
    local fakePanel = Instance.new("Frame")
    fakePanel.Size = UDim2.new(0, 320, 0, 210)
    fakePanel.Position = UDim2.new(0.5, -160, 0.5, -105)
    fakePanel.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    fakePanel.BorderSizePixel = 0
    fakePanel.Visible = false
    fakePanel.ZIndex = 20
    fakePanel.Parent = main
    corner(fakePanel, 12)
    local fakeStroke = Instance.new("UIStroke")
    fakeStroke.Color = accent
    fakeStroke.Thickness = 1.5
    fakeStroke.Parent = fakePanel

    local fakeTitle = mkLabel(fakePanel, "FAKE ELO", UDim2.new(1, -60, 0, 24), UDim2.new(0, 12, 0, 8), C_TEXT)
    fakeTitle.ZIndex = 21
    local fakeClose = mkBtn(fakePanel, "X", UDim2.new(0, 28, 0, 24), UDim2.new(1, -36, 0, 8), C_RED)
    fakeClose.ZIndex = 21
    local fakeInfo = mkLabel(fakePanel, "Checking access...", UDim2.new(1, -24, 0, 90), UDim2.new(0, 12, 0, 40), C_DIM)
    fakeInfo.ZIndex = 21
    local fakeBtn = mkBtn(fakePanel, "...", UDim2.new(0, 200, 0, 34), UDim2.new(0.5, -100, 1, -48), accent)
    fakeBtn.ZIndex = 21

    local access = { state = "checking", err = nil }

    local function renderFake()
        fakeBtn.Visible = access.state ~= "granted"
        if access.state == "granted" then
            fakeInfo.Text = "Access granted. The Fake ELO setting comes later."
        elseif access.state == "pending" then
            fakeInfo.Text = "Request sent. Waiting for approval..."
            fakeBtn.Text = "PENDING..."
        elseif access.state == "denied" then
            fakeInfo.Text = "Your request was denied."
            fakeBtn.Text = "REQUEST AGAIN"
        elseif access.state == "offline" then
            fakeInfo.Text = "Couldn't reach the access system." .. (access.err and ("\n" .. access.err) or "")
            fakeBtn.Text = "RETRY"
        elseif access.state == "checking" then
            fakeInfo.Text = "Checking access..."
            fakeBtn.Text = "..."
        else
            fakeInfo.Text = "You don't have access to Fake ELO yet. Request it and an admin can approve."
            fakeBtn.Text = "REQUEST ACCESS"
        end
    end

    local function setAccess(state, err)
        access.state = state
        access.err = err
        renderFake()
    end

    local store = readStore(uid)

    local function saveStore(granted)
        store.granted = granted
        writeStore(store)
    end

    local function applyStatus(st, note)
        if st == "granted" then
            saveStore(true)
            setAccess("granted")
        elseif st == "pending" then
            setAccess("pending")
        elseif st == "denied" then
            saveStore(false)
            setAccess("denied")
        elseif st == "none" then
            saveStore(false)
            setAccess("none")
        elseif st == "invalid" or st == "limited" then
            -- the bot refused the request itself; a saved grant is left alone
            local why = note or (st == "limited" and "too many requests, try again in a minute" or "the request was rejected")
            setAccess("offline", why)
        else
            -- an unexpected reply must never clear a saved grant
            setAccess("offline", "unexpected reply from the access system")
        end
    end

    local function pollAccess()
        pollGen = pollGen + 1
        local myPoll = pollGen
        task.spawn(function()
            for _ = 1, 120 do -- about 10 minutes
                task.wait(5)
                if not alive or myPoll ~= pollGen or access.state ~= "pending" then return end
                local st, _, note = Access.status(uid, store.msgId)
                if st then applyStatus(st, note) end
            end
        end)
    end

    -- on open: a saved grant shows at once; the bot is checked so a removed access is honoured
    task.spawn(function()
        if store.granted then
            setAccess("granted")
        end
        local st, err, note = Access.status(uid, store.msgId)
        if not alive then return end
        if st then
            applyStatus(st, note)
            if access.state == "pending" then pollAccess() end
        elseif access.state ~= "granted" then
            setAccess("offline", err)
        end
    end)
    renderFake()

    bindClick(fakeBtn, "MouseButton1Click", function()
        if access.state == "pending" or access.state == "granted" or access.state == "checking" then return end
        setAccess("pending")
        task.spawn(function()
            local st, msgId, err = Access.request(uid, player.Name)
            if not alive then return end
            if not st then
                setAccess("offline", err)
                return
            end
            if msgId then
                store.msgId = msgId
                writeStore(store)
            end
            applyStatus(st)
            if access.state == "pending" then pollAccess() end
        end)
    end)

    bindClick(fakeOpenBtn, "MouseButton1Click", function()
        fakePanel.Visible = not fakePanel.Visible
    end)
    bindClick(fakeClose, "MouseButton1Click", function()
        fakePanel.Visible = false
    end)

    -- ---------- game flow ----------
    local function setStatus(text, color)
        statusLbl.Text = text
        statusLbl.TextColor3 = color or C_TEXT
    end

    local function clearSelection()
        selected = nil
        targets = {}
    end

    local function legalFrom(sq)
        local out = {}
        for _, m in ipairs(E.legalMoves(game.state)) do
            if m.from == sq then
                -- promotions come as Q, R, B, N: keep the queen (auto-promote)
                if out[m.to] == nil or m.promo == "Q" then out[m.to] = m end
            end
        end
        return out
    end

    local function applyMove(m)
        game.state = E.makeMove(game.state, m)
        game.last = m
        table.insert(game.history, E.key(game.state))
    end

    local function finishIfOver()
        local result = E.outcome(game.state, game.history)
        if not result then return false end
        game.over = true
        if result == "mate" then
            local humanWon = game.state.turn == "b"
            setStatus(humanWon and "Checkmate! You win" or "Checkmate. The bot wins", humanWon and C_GREEN or C_RED)
        elseif result == "stalemate" then
            setStatus("Stalemate. Draw", C_GOLD)
        elseif result == "fifty" then
            setStatus("Draw by the 50-move rule", C_GOLD)
        else
            setStatus("Draw by repetition", C_GOLD)
        end
        return true
    end

    local askBot

    askBot = function()
        botThinking = true
        local myGen = gen
        local lv = E.LEVELS[levelIndex]
        setStatus("Bot is thinking... (" .. lv.elo .. " ELO)", C_DIM)
        task.spawn(function()
            local move = E.chooseMove(game.state, lv, {
                budget = lv.budget,
                yield = function() task.wait() end,
            })
            if not alive or myGen ~= gen then return end
            botThinking = false
            if not move then
                render()
                finishIfOver()
                return
            end
            applyMove(move)
            render()
            if not finishIfOver() then
                setStatus("Your move (White)", C_GOLD)
            end
        end)
    end

    onSquare = function(sq)
        if not alive or game.over or botThinking or game.state.turn ~= "w" then return end
        if selected and targets[sq] then
            local m = targets[sq]
            clearSelection()
            applyMove(m)
            render()
            if not finishIfOver() then askBot() end
            return
        end
        local p = game.state.b[sq]
        if p ~= "." and p == string.upper(p) then
            selected = sq
            targets = legalFrom(sq)
        else
            clearSelection()
        end
        render()
    end

    local function newGame()
        gen = gen + 1
        game = newState()
        botThinking = false
        clearSelection()
        render()
        setStatus("Your move (White)", C_GOLD)
    end

    bindClick(newBtn, "MouseButton1Click", newGame)

    bindClick(resignBtn, "MouseButton1Click", function()
        if game.over then return end
        game.over = true
        botThinking = false
        gen = gen + 1
        setStatus("You resigned", C_RED)
    end)

    local function cleanup()
        if not alive then return end
        alive = false
        gen = gen + 1
        pollGen = pollGen + 1
        pcall(function() gui:Destroy() end)
    end

    bindClick(closeBtn, "MouseButton1Click", function()
        if ctx.onClose then ctx.onClose() else cleanup() end
    end)

    render()
    return cleanup
end

return Chess
