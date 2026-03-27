-- ============================================
-- GAMEROAD SecurityValidator.lua
-- ReplicatedStorage/ に配置（ModuleScript型）
-- BattleServer_v2からrequireして使う
--
-- カードゲームのチート対策の核心：
--   「全ゲーム状態はサーバーだけが持つ」は既に設計済み
--   追加で必要なのはRemoteEventのスパム・偽造防止
-- ============================================

local Players = game:GetService("Players")

local Security = {}

-- ============================================
-- レート制限（スパム送信の防止）
-- ============================================
local RateLimitDB = {}  -- [userId][eventName] = {count, resetTime}
local RATE_LIMITS = {
    RoadSelect   = {max = 5,  window = 3},   -- 3秒で5回まで
    BattleSelect = {max = 5,  window = 3},
    TargetSelect = {max = 5,  window = 3},
    ArcanaSelect = {max = 3,  window = 5},
    GachaRoll    = {max = 3,  window = 2},   -- ガチャスパム防止
    MatchmakingJoin = {max = 2, window = 5},
}

function Security.checkRateLimit(player, eventName)
    local userId = player.UserId
    local limit  = RATE_LIMITS[eventName]
    if not limit then return true end  -- 未定義イベントは通す

    local now = os.time()
    if not RateLimitDB[userId] then RateLimitDB[userId] = {} end
    local db = RateLimitDB[userId]

    if not db[eventName] or now >= db[eventName].resetTime then
        db[eventName] = {count = 0, resetTime = now + limit.window}
    end

    db[eventName].count = db[eventName].count + 1

    if db[eventName].count > limit.max then
        warn(string.format("[SECURITY] Rate limit: %s by %s (%d/%d)",
            eventName, player.Name, db[eventName].count, limit.max))
        return false
    end
    return true
end

-- ============================================
-- カードID検証（手札にあるかチェック）
-- ============================================
function Security.validateCardInHand(player, gs, cardId)
    local p = gs.playerMap and gs.playerMap[player.UserId]
    if not p then
        warn("[SECURITY] Player not in game: " .. player.Name)
        return false
    end
    for _, card in ipairs(p.hand) do
        if card.id == cardId then
            return true
        end
    end
    warn(string.format("[SECURITY] Card %d not in hand of %s",
        cardId, player.Name))
    return false
end

-- ============================================
-- フェーズ検証（今そのフェーズか）
-- ============================================
function Security.validatePhase(gs, expected)
    if gs.phase ~= expected then
        return false
    end
    return true
end

-- ============================================
-- アクティブプレイヤー検証（その行動をする権限があるか）
-- ============================================
function Security.validateActivePlayer(player, gs, allowedId)
    if allowedId and player.UserId ~= allowedId then
        warn(string.format("[SECURITY] Action by non-active player: %s (expected %d)",
            player.Name, allowedId))
        return false
    end
    return true
end

-- ============================================
-- 入力サニタイズ（型チェック）
-- ============================================
function Security.sanitize(data, schema)
    -- schema = {key = {type, required, min, max}}
    if type(data) ~= "table" then return nil, "data is not a table" end
    for key, rule in pairs(schema) do
        local val = data[key]
        if rule.required and val == nil then
            return nil, "missing required field: " .. key
        end
        if val ~= nil then
            if rule.type and type(val) ~= rule.type then
                return nil, "wrong type for " .. key .. ": expected " .. rule.type
            end
            if rule.type == "number" then
                if rule.min and val < rule.min then
                    return nil, key .. " below minimum"
                end
                if rule.max and val > rule.max then
                    return nil, key .. " above maximum"
                end
            end
        end
    end
    return data, nil
end

-- ============================================
-- 不正行為カウンター（一定回数で自動キック）
-- ============================================
local ViolationDB = {}  -- [userId] = count
local KICK_THRESHOLD = 10  -- 10回違反でキック

function Security.recordViolation(player, reason)
    local uid = player.UserId
    ViolationDB[uid] = (ViolationDB[uid] or 0) + 1
    warn(string.format("[SECURITY] Violation #%d by %s: %s",
        ViolationDB[uid], player.Name, reason))

    if ViolationDB[uid] >= KICK_THRESHOLD then
        -- キック前に少し待つ（ログが残るように）
        task.delay(0.5, function()
            if Players:GetPlayerByUserId(uid) then
                Players:GetPlayerByUserId(uid):Kick(
                    "不正な操作が検出されました。(Code: " .. ViolationDB[uid] .. ")"
                )
            end
        end)
    end
end

-- プレイヤー退出時にクリーン
Players.PlayerRemoving:Connect(function(player)
    RateLimitDB[player.UserId]   = nil
    ViolationDB[player.UserId]   = nil
end)

-- ============================================
-- よく使う検証をまとめたラッパー
-- ============================================
function Security.validateInput(player, data, schema, gs, phase, activeId)
    -- 1. サニタイズ
    local clean, err = Security.sanitize(data, schema)
    if not clean then
        Security.recordViolation(player, "invalid input: " .. err)
        return false
    end

    -- 2. フェーズチェック
    if gs and phase and not Security.validatePhase(gs, phase) then
        -- フェーズ違いは軽い違反（ラグで起きることがある）
        -- recordViolationはしない
        return false
    end

    -- 3. アクティブプレイヤーチェック
    if gs and activeId and not Security.validateActivePlayer(player, gs, activeId) then
        Security.recordViolation(player, "action outside turn")
        return false
    end

    return true
end

return Security
