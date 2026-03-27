-- ============================================
-- GAMEROAD GachaSystem.lua
-- ガチャ・課金・DevProductsの完全実装
-- ProcessReceiptを正しく実装しないと課金成功でも報酬が出ない
-- ============================================

local Players          = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService      = game:GetService("HttpService")

local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
local ReceiptStore    = DataStoreService:GetDataStore("PurchaseReceipts_v1")

local GachaSystem = {}   -- モジュールテーブル（require()で返す）
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_UpdateBoard = Remotes:WaitForChild("UpdateBoard", 15)

-- ============================================
-- Developer Product IDs（Studioで作成後に差し替え）
-- ============================================
local PRODUCTS = {
    [1111111] = {name = "ジェムx100",  gems = 100,   rolls = 0},
    [1111112] = {name = "ジェムx600",  gems = 600,   rolls = 0},  -- 10%ボーナス
    [1111113] = {name = "ジェムx1300", gems = 1300,  rolls = 0},  -- 30%ボーナス
    [1111114] = {name = "単発ガチャ1回", gems = 0,   rolls = 1},
    [1111115] = {name = "10連ガチャ",   gems = 0,   rolls = 10},
}

-- Game Pass IDs
local GAME_PASSES = {
    VIP         = 2222221,  -- VIPパス：毎日ジェム+10・Premium Payouts対象
    AutoWin     = 2222222,  -- スキップパス：AIとの対戦を即勝利にカウント
}

-- ============================================
-- ガチャテーブル（レアリティ・重みづけ）
-- ============================================
local RARITY = {
    SSR = {weight = 3,  label = "SSR ✦✦✦",  color = Color3.fromRGB(255, 215, 0)},
    SR  = {weight = 12, label = "SR ✦✦",     color = Color3.fromRGB(180, 100, 220)},
    R   = {weight = 35, label = "R ✦",       color = Color3.fromRGB(100, 150, 255)},
    N   = {weight = 50, label = "N",          color = Color3.fromRGB(180, 180, 180)},
}

-- パートナースキン一覧
-- 今後キャラを追加する時はここだけ変更する
-- artType: "handdrawn"=手描き / "ai"=AI illustration / "default"=デフォルト
-- authorName: 手描きの時だけ設定（作者クレジット表示用）
-- 新規採用イラストはここに追加する
local PARTNER_SKINS = {
    -- SSR
    {id="haruto_battle",   name="ハルト【戦闘】",      rarity="SSR", suit="heart"},
    {id="saarsna_ice",    name="サースナー【氷紋】",   rarity="SSR", suit="spade"},
    {id="dil_trickster",  name="ディル【怪盗】",       rarity="SSR", suit="diamond"},
    -- SR
    {id="haruto_default", name="ハルト",               rarity="SR",  suit="heart"},
    {id="kabu_summer",    name="カブー【夏】",          rarity="SR",  suit="club"},
    {id="shell_knight",   name="シェル【騎士】",        rarity="SR",  suit="spade"},
    {id="saarsna_maid",   name="サースナー【メイド】",  rarity="SR",  suit="spade"},
    {id="dil_default",    name="ディル",                rarity="SR",  suit="diamond"},
    -- R
    {id="kabu_default",   name="カブー",               rarity="R",   suit="club"},
    {id="shell_default",  name="シェル",               rarity="R",   suit="spade"},
    {id="mob_fighter",    name="モブ戦士A",             rarity="R",   suit="heart"},
    {id="mob_scholar",    name="モブ学者B",             rarity="R",   suit="diamond"},
    -- N（排出率50%の埋め草）
    {id="n_beetle",       name="カブトムシ騎士",       rarity="N",   suit="club"},
    {id="n_mushroom",     name="キノコ剣士",           rarity="N",   suit="club"},
    {id="n_crystal",      name="クリスタル守衛",        rarity="N",   suit="diamond"},
    {id="n_shadow",       name="影の斥候",             rarity="N",   suit="spade"},
}

-- 排出テーブルを構築（重みで引ける確率を作る）
local function buildPool()
    local pool = {}
    for _, skin in ipairs(PARTNER_SKINS) do
        local r = RARITY[skin.rarity]
        for _ = 1, r.weight do
            table.insert(pool, skin)
        end
    end
    return pool
end
local GACHA_POOL = buildPool()

-- 天井システム：100連でSSR確定
local PITY_THRESHOLD = 100

-- ============================================
-- プレイヤーデータ管理
-- ============================================
local PlayerCache = {}  -- メモリキャッシュ

local DEFAULT_DATA = {
    gems        = 50,       -- 初期ジェム（無料スタート）
    rolls       = 0,        -- 累計ガチャ回数
    pity        = 0,        -- 天井カウンター
    owned       = {},       -- 所持スキンID一覧
    equipped    = "kabu_default",  -- 装備中スキン
    loginStreak = 0,
    lastLogin   = 0,
    voteTickets = 0,        -- 転生投票権
    tutorialDone  = false,  -- 初回チュートリアル完了フラグ
    achievements  = {},     -- 達成済み実績ID一覧
    stats = {               -- プレイ統計（実績判定用）
        totalWins  = 0,
        totalGames = 0,
        maxStreak  = 0,
        curStreak  = 0,
        gachaRolls = 0,
        ssrPulled  = 0,
    },
    -- 4スート別デッキスロット（イラスト選択）
    -- キー: カードID（例:"card_A"), 値: skinID
    -- スートは別キャンバス。トランプ版でランダム割り振りされた
    -- スートに対応するスロットがバトルで使われる
    deckSlots   = {
        heart   = {},
        diamond = {},
        club    = {},
        spade   = {},
    },
    stats = {
        wins = 0, losses = 0, totalGames = 0,
    }
}

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = deepCopy(v) end
    return c
end

local function shallowMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            shallowMerge(target[k], v)
        else
            target[k] = v
        end
    end
end

local function loadPlayerData(player)
    local key = "player_" .. player.UserId
    local success, data = pcall(function()
        return PlayerDataStore:GetAsync(key)
    end)
    if success and data then
        -- デフォルト値のディープマージ（ネストされたテーブルも保持）
        local merged = deepCopy(DEFAULT_DATA)
        shallowMerge(merged, data)
        PlayerCache[player.UserId] = merged
    else
        PlayerCache[player.UserId] = deepCopy(DEFAULT_DATA)
    end
    return PlayerCache[player.UserId]
end

local function savePlayerData(player)
    local data = PlayerCache[player.UserId]
    if not data then return end
    local key = "player_" .. player.UserId
    local success, err = pcall(function()
        PlayerDataStore:SetAsync(key, data)
    end)
    if not success then
        warn("DataStore save failed for " .. player.Name .. ": " .. tostring(err))
    end
end

-- ============================================
-- 日次ログインボーナス
-- ============================================
local function checkDailyLogin(player)
    local data = PlayerCache[player.UserId]
    local now = os.time()
    local lastLogin = data.lastLogin or 0
    -- 24時間（86400秒）以上経過していたらログインボーナス
    -- 連続ログインが途切れているかチェック（48時間以上空いたらリセット）
    if now - lastLogin >= 172800 then
        data.loginStreak = 0
    end

    if now - lastLogin >= 86400 then
        data.loginStreak = (data.loginStreak or 0) + 1
        data.lastLogin = now

        -- 連続日数に応じた報酬テーブル
        local streak = data.loginStreak
        local bonus  = 10 + math.min(streak * 3, 40)  -- 基本報酬（最大50ジェム）
        local bonusText = nil
        local special = false

        -- 7の倍数日: 特別報酬
        if streak % 7 == 0 then
            bonus = bonus + 100
            bonusText = string.format("🎁 %d日連続ボーナス: +100ジェム追加！", streak)
            special = true
        end
        -- 30の倍数日: 超特別報酬（ガチャチケット）
        if streak % 30 == 0 then
            bonus = bonus + 300
            data.rolls = (data.rolls or 0)  -- ガチャ引き数は別管理
            bonusText = string.format("🌟 %d日連続！ガチャチケット+2枚！", streak)
            special = true
            -- チケットをロール可能回数として加算
            data.freeRolls = (data.freeRolls or 0) + 2
        end

        data.gems = (data.gems or 0) + bonus

        -- VIP持ちはさらに+20%
        local hasVIP = false
        pcall(function()
            hasVIP = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAME_PASSES.VIP)
        end)
        if hasVIP then
            local vipBonus = math.floor(bonus * 0.2)
            bonus = bonus + vipBonus
            data.gems = data.gems + vipBonus
        end

        local pl = Players:GetPlayerByUserId(player.UserId)
        if pl then
            RE_UpdateBoard:FireClient(pl, {
                type      = "login_bonus",  -- BattleClientのポップアップUI用
                bonus     = bonus,
                streak    = streak,
                special   = special,
                bonusText = bonusText,
                gems      = bonus,          -- ポップアップ表示用
                totalGems = data.gems,
            })
        end
        savePlayerData(player)
    end
end

-- ============================================
-- 実績（バッジ）システム
-- ============================================
local ACHIEVEMENTS = {
    {id="first_win",    name="初勝利！",       icon="⚔",  desc="初めてバトルに勝利",
     cond=function(s) return (s.totalWins or 0) >= 1 end,          reward={gems=100}},
    {id="win10",        name="10勝達成",        icon="🏅",  desc="バトル10勝",
     cond=function(s) return (s.totalWins or 0) >= 10 end,         reward={gems=200}},
    {id="win50",        name="50勝の猛者",      icon="🥇",  desc="バトル50勝",
     cond=function(s) return (s.totalWins or 0) >= 50 end,         reward={gems=500}},
    {id="win100",       name="百戦錬磨",        icon="🏆",  desc="バトル100勝",
     cond=function(s) return (s.totalWins or 0) >= 100 end,        reward={gems=1000}},
    {id="streak5",      name="5連勝！",         icon="🔥",  desc="5連勝達成",
     cond=function(s) return (s.maxStreak or 0) >= 5 end,          reward={gems=150}},
    {id="streak10",     name="無双10連勝",      icon="💥",  desc="10連勝達成",
     cond=function(s) return (s.maxStreak or 0) >= 10 end,         reward={gems=500}},
    {id="gacha10",      name="ガチャデビュー",  icon="🎰",  desc="ガチャを10回引く",
     cond=function(s) return (s.gachaRolls or 0) >= 10 end,        reward={gems=50}},
    {id="gacha100",     name="ガチャ中毒",      icon="🌀",  desc="ガチャを100回引く",
     cond=function(s) return (s.gachaRolls or 0) >= 100 end,       reward={gems=300}},
    {id="first_ssr",    name="初SSR！",         icon="✨",  desc="SSRカードを初入手",
     cond=function(s) return (s.ssrPulled or 0) >= 1 end,          reward={gems=200}},
    {id="login7",       name="7日連続ログイン", icon="📅",  desc="7日連続ログイン",
     cond=function(s,d) return (d.loginStreak or 0) >= 7 end,      reward={gems=300}},
    {id="login30",      name="30日連続ログイン",icon="🌟",  desc="30日連続ログイン",
     cond=function(s,d) return (d.loginStreak or 0) >= 30 end,     reward={gems=1000}},
}

local function checkAchievements(player, data)
    local achieved = data.achievements or {}
    local stats    = data.stats or {}
    local newOnes  = {}

    for _, ach in ipairs(ACHIEVEMENTS) do
        if not achieved[ach.id] then
            local ok = pcall(function()
                if ach.cond(stats, data) then
                    achieved[ach.id] = true
                    -- 報酬付与
                    if ach.reward.gems then
                        data.gems = (data.gems or 0) + ach.reward.gems
                    end
                    table.insert(newOnes, ach)
                end
            end)
        end
    end
    data.achievements = achieved

    if #newOnes > 0 then
        local pl = Players:GetPlayerByUserId(player.UserId)
        if pl then
            for _, ach in ipairs(newOnes) do
                RE_UpdateBoard:FireClient(pl, {
                    type    = "achievement_unlocked",
                    id      = ach.id,
                    name    = ach.name,
                    icon    = ach.icon,
                    desc    = ach.desc,
                    reward  = ach.reward,
                })
            end
        end
    end
end

-- ============================================
-- ガチャロール
-- ============================================
local ROLL_COST_GEM = 150  -- 1回150ジェム

local function rollOnce(data)
    data.pity  = (data.pity  or 0) + 1
    data.rolls = (data.rolls or 0) + 1
    data.stats = data.stats or {}
    data.stats.gachaRolls = (data.stats.gachaRolls or 0) + 1

    -- 天井：pityがPITY_THRESHOLDに達したらSSR確定
    local result
    if data.pity >= PITY_THRESHOLD then
        -- SSRのみのプールから抽選
        local ssrPool = {}
        for _, s in ipairs(PARTNER_SKINS) do
            if s.rarity == "SSR" then table.insert(ssrPool, s) end
        end
        result = ssrPool[math.random(#ssrPool)]
        data.pity = 0
        data.stats = data.stats or {}
        data.stats.ssrPulled = (data.stats.ssrPulled or 0) + 1
    else
        result = GACHA_POOL[math.random(#GACHA_POOL)]
        if result.rarity == "SSR" then
            data.pity = 0
            data.stats = data.stats or {}
            data.stats.ssrPulled = (data.stats.ssrPulled or 0) + 1
        end
    end

    -- 重複チェック（持っていたら「共鳴石」変換→将来実装のための記録だけ）
    local isDupe = false
    if data.owned then
        for _, id in ipairs(data.owned) do
            if id == result.id then isDupe = true; break end
        end
    end
    if not isDupe then
        data.owned = data.owned or {}
        table.insert(data.owned, result.id)
    end

    return {skin = result, isDupe = isDupe}
end

local function performGacha(player, count)
    local data = PlayerCache[player.UserId]
    if not data then return nil, "データなし" end

    local cost = ROLL_COST_GEM * count
    -- freeRollsがあれば1回分無料（1ロールのみ対象）
    local freeUsed = 0
    if (data.freeRolls or 0) > 0 and count == 1 then
        data.freeRolls = data.freeRolls - 1
        freeUsed = 1
        cost = 0
    end
    if data.gems < cost then
        return nil, "ジェムが足りない（必要: " .. cost .. "  所持: " .. data.gems .. "）"
    end

    data.gems = data.gems - cost
    local results = {}
    for _ = 1, count do
        table.insert(results, rollOnce(data))
    end

    savePlayerData(player)
    return results, nil
end

-- ============================================
-- ProcessReceipt（課金の核心・必ず実装）
-- ============================================
MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)

    -- 二重付与防止：このReceiptIdが既に処理済みか確認
    local receiptKey = "receipt_" .. receiptInfo.PurchaseId
    local alreadyProcessed = false
    pcall(function()
        alreadyProcessed = ReceiptStore:GetAsync(receiptKey)
    end)
    if alreadyProcessed then
        return Enum.ProductPurchaseDecision.PurchaseGranted  -- 処理済みなのでGrantedを返す
    end

    -- プレイヤーが既にいない場合：NotProcessedYetを返すと再試行される
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local data = PlayerCache[player.UserId]
    if not data then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local product = PRODUCTS[receiptInfo.ProductId]
    if not product then
        warn("Unknown ProductId: " .. receiptInfo.ProductId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- 報酬付与
    if product.gems > 0 then
        data.gems = (data.gems or 0) + product.gems
    end

    -- ガチャ回数の付与（ジェム経由ではなく直接回数付与型の場合）
    local gachaResults = nil
    if product.rolls > 0 then
        local results, err = performGacha(player, product.rolls)
        if err then
            warn("Gacha failed after purchase: " .. err)
        else
            gachaResults = results
        end
    end

    -- 処理済みフラグを保存
    pcall(function()
        ReceiptStore:SetAsync(receiptKey, true)
    end)
    savePlayerData(player)

    -- クライアントに通知
    RE_UpdateBoard:FireClient(player, {
        type        = "purchase_complete",
        productName = product.name,
        gemsAdded   = product.gems,
        totalGems   = data.gems,
        gachaResults = gachaResults,
    })

    return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ============================================
-- RemoteEvent：ガチャ要求受信（ジェム消費型）
-- ============================================
local RE_GachaRoll = Remotes:WaitForChild("GachaRoll", 15)

RE_GachaRoll.OnServerEvent:Connect(function(player, count)
    count = math.min(math.max(count or 1, 1), 10)  -- 1〜10に制限

    local data = PlayerCache[player.UserId]
    if not data then return end

    local results, err = performGacha(player, count)
    if err then
        RE_UpdateBoard:FireClient(player, {type = "gacha_error", message = err})
        return
    end

    RE_UpdateBoard:FireClient(player, {
        type      = "gacha_result",
        results   = results,
        totalGems = data.gems,
        pity      = data.pity,
    })
end)

-- スキン装備変更
local RE_EquipSkin = Remotes:WaitForChild("EquipSkin", 15)
RE_EquipSkin.OnServerEvent:Connect(function(player, skinId)
    local data = PlayerCache[player.UserId]
    if not data or not data.owned then return end
    for _, id in ipairs(data.owned) do
        if id == skinId then
            data.equipped = skinId
            savePlayerData(player)
            RE_UpdateBoard:FireClient(player, {type = "equip_ok", skinId = skinId})
            return
        end
    end
    RE_UpdateBoard:FireClient(player, {type = "equip_error", message = "未所持"})
end)

-- Robux購入プロンプト（クライアントから要求）
local RE_BuyProduct = Remotes:WaitForChild("BuyProduct", 15)
RE_BuyProduct.OnServerEvent:Connect(function(player, productId)
    if not PRODUCTS[productId] then return end
    MarketplaceService:PromptProductPurchase(player, productId)
end)

-- ゲームパス確認
local RE_CheckPass = Remotes:WaitForChild("CheckPass", 15)
RE_CheckPass.OnServerEvent:Connect(function(player, passType)
    local passId = GAME_PASSES[passType]
    if not passId then return end
    local success, hasPass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
    end)
    if success then
        RE_UpdateBoard:FireClient(player, {
            type = "pass_status", passType = passType, owned = hasPass
        })
    end
end)

-- チュートリアル完了フラグ保存
local RE_UBServer = Remotes:WaitForChild("UpdateBoard", 15)
RE_UBServer.OnServerEvent:Connect(function(player, data)
    if not data or data.type ~= "tutorial_complete" then return end
    local pd = PlayerCache[player.UserId]
    if pd and not pd.tutorialDone then
        pd.tutorialDone = true
        savePlayerData(player)
    end
end)

-- RatingSystemからのELO更新を受け取る（DataStore競合回避）
local UpdateEloEvent = Instance.new("BindableEvent")
UpdateEloEvent.Name   = "UpdatePlayerElo"
UpdateEloEvent.Parent = ReplicatedStorage

UpdateEloEvent.Event:Connect(function(userId, elo)
    local data = PlayerCache[userId]
    if data then
        data.stats = data.stats or {}
        data.stats.elo = elo
        -- 次のオートセーブで保存される（即座には書き込まない）
    end
end)

-- PetSystemからのスキン解放通知を受け取る（BindableEvent経由）
local PetSkinUnlockEvent = Instance.new("BindableEvent")
PetSkinUnlockEvent.Name  = "PetSkinUnlock"
PetSkinUnlockEvent.Parent = ReplicatedStorage

PetSkinUnlockEvent.Event:Connect(function(userId, skinId)
    local data = PlayerCache[userId]
    if not data then return end
    if not data.owned then data.owned = {} end
    local alreadyHas = false
    for _, id in ipairs(data.owned) do
        if id == skinId then alreadyHas=true; break end
    end
    if not alreadyHas then
        table.insert(data.owned, skinId)
        savePlayerData(game:GetService("Players"):GetPlayerByUserId(userId))
    end
end)

-- ============================================
-- プレイヤー入退室
-- ============================================
Players.PlayerAdded:Connect(function(player)
    local data = loadPlayerData(player)
    task.wait(2)  -- ロード後すぐはクライアントの準備ができてない可能性
    checkDailyLogin(player)
    RE_UpdateBoard:FireClient(player, {
        type      = "player_data",
        gems         = data.gems,
        pity         = data.pity,
        equipped     = data.equipped,
        owned        = data.owned,
        stats        = data.stats,
        streak       = data.loginStreak,
        tutorialDone = data.tutorialDone or false,
    })
end)

Players.PlayerRemoving:Connect(function(player)
    savePlayerData(player)
    PlayerCache[player.UserId] = nil
end)

-- 定期オートセーブ（5分ごと）
task.spawn(function()
    while true do
        task.wait(300)
        for _, player in ipairs(Players:GetPlayers()) do
            savePlayerData(player)
        end
    end
end)


-- ══════════════════════════════════════════
-- デッキスロット管理（4スート別イラスト選択）
-- ══════════════════════════════════════════

-- スロットに使用スキンをセット
-- suit: "heart"/"diamond"/"club"/"spade"
-- cardId: "card_spade_A" 等
-- skinId: ガチャで入手したスキンID（nilで解除）
function GachaSystem.SetDeckSkin(player, suit, cardId, skinId)
    local VALID_SUITS = {heart=true, diamond=true, club=true, spade=true}
    if not VALID_SUITS[suit] then return false, "不正なスート" end

    PlayerDataStore:UpdateAsync("player_" .. player.UserId, function(data)
        if not data then return nil end
        if not data.deckSlots then
            data.deckSlots = {heart={}, diamond={}, club={}, spade={}}
        end
        if skinId then
            -- 所持確認（owned はリスト形式）
            local hasIt = false
            for _, id in ipairs(data.owned or {}) do
                if id == skinId then hasIt = true; break end
            end
            if not hasIt then return nil end  -- 未所持なら変更しない
            data.deckSlots[suit][cardId] = skinId
        else
            data.deckSlots[suit][cardId] = nil  -- 解除
        end
        return data
    end)
    return true
end

-- デッキスロット取得
function GachaSystem.GetDeckSlots(player)
    local ok, data = pcall(function()
        return PlayerDataStore:GetAsync("player_" .. player.UserId)
    end)
    if ok and data and data.deckSlots then
        return data.deckSlots
    end
    return {heart={}, diamond={}, club={}, spade={}}
end


-- ══════════════════════════════════════════
-- 所持スキン取得（カードスタイル変更UI用）
-- suit: "heart"/"diamond"/"club"/"spade"
-- cardId: "card_A" など（将来的にカード固有スキンを絞り込む用）
-- 返却: {{id, name, rarity, suit}, ...}
-- ══════════════════════════════════════════
function GachaSystem.GetOwnedSkinsForCard(player, suit, cardId)
    local data = PlayerCache[player.UserId]
    if not data or not data.owned then return {} end

    -- 所持スキンIDセット
    local ownedSet = {}
    for _, id in ipairs(data.owned) do
        ownedSet[id] = true
    end

    -- PARTNER_SKINSからsuitが一致 & 所持済みのものを返す
    local result = {}
    for _, skin in ipairs(PARTNER_SKINS) do
        if skin.suit == suit and ownedSet[skin.id] then
            table.insert(result, {
                id     = skin.id,
                name   = skin.name,
                rarity = skin.rarity,
                suit   = skin.suit,
            })
        end
    end
    return result
end

-- ══════════════════════════════════════════
-- 採用イラスト登録（管理者が使う）
-- ══════════════════════════════════════════
-- artType: "handdrawn" / "ai"
-- authorName: 手描きの場合のみ（nilの場合は非表示）
function GachaSystem.RegisterFanArt(skinId, skinName, rarity, suit, artType, authorName)
    -- PARTNER_SKINSテーブルに動的追加
    table.insert(PARTNER_SKINS, {
        id         = skinId,
        name       = skinName,
        rarity     = rarity or "R",
        suit       = suit,
        artType    = artType or "handdrawn",
        authorName = (artType == "handdrawn") and authorName or nil,
    })
    print(("[GachaSystem] ファンアート登録: %s (%s) by %s"):format(
        skinId, artType, authorName or "AI"))
end

-- ══════════════════════════════════════════
-- VoteSystem連携
-- ══════════════════════════════════════════

-- ガチャチケット付与（転生確定時に呼ぶ）
function GachaSystem.AddTickets(player, amount)
    PlayerDataStore:UpdateAsync("player_" .. player.UserId, function(data)
        if not data then return nil end
        data.voteTickets = (data.voteTickets or 0) + amount
        return data
    end)
end

-- 投票権消費（VoteSystem.CastVoteから呼ぶ）
function GachaSystem.UseVoteTicket(player, amount)
    local used = false
    local failReason = nil
    pcall(function()
        PlayerDataStore:UpdateAsync("player_" .. player.UserId, function(data)
            if not data then return nil end
            local current = data.voteTickets or 0
            if current < amount then
                failReason = "投票権不足: " .. current
                return nil  -- UpdateAsync をキャンセル（データ変更しない）
            end
            data.voteTickets = current - amount
            used = true
            return data
        end)
    end)
    if failReason then error(failReason) end
    if not used then error("投票権消費失敗") end
end

print("✅ GachaSystem.lua loaded")

return GachaSystem
