-- ============================================
-- GAMEROAD QuestSystem.lua
-- ServerScriptService/ に配置（Script型）
--
-- 設計根拠（調査より）：
--   Day1→Day7リテンション最大の武器は「毎日帰ってくる理由」
--   デイリークエスト完了率が高いほど課金転換率が上がる
--   シーズンパスはFANBOXより継続課金リスクが低い（Roblox標準）
-- ============================================

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Remotes        = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_UpdateBoard = Remotes:WaitForChild("UpdateBoard", 15)

local QuestStore   = DataStoreService:GetDataStore("QuestData_v1")
local SeasonStore  = DataStoreService:GetDataStore("SeasonData_v1")

-- ============================================
-- シーズン定義（3ヶ月ごとに手動更新）
-- ============================================
local CURRENT_SEASON = {
    id      = "season_1",
    name    = "恐竜の夜明け",
    endTime = 1798761599,  -- 2026年12月31日末（公開後に次シーズンへ更新）
    maxRank = 50,
    -- シーズンパスGamePass ID（仮：本番公開前に差し替え）
    passId  = 3333331,
    -- ランクごとの報酬（無料/パス）
    rewards = {
        [1]  = {free = {gems=50},             pass = {gems=200, skin="kabu_default"}},
        [5]  = {free = {gems=100},            pass = {gems=500}},
        [10] = {free = {gems=200},            pass = {gems=1000, skin="haruto_default"}},
        [20] = {free = {gems=300},            pass = {gems=2000}},
        [30] = {free = {gems=500},            pass = {gems=3000, skin="saasuna_ice"}},
        [40] = {free = {gems=700},            pass = {gems=5000}},
        [50] = {free = {gems=1000, title="伝説の恐竜使い"}, pass = {gems=10000, skin="dil_phantom", title="覚醒の恐竜王"}},
    },
}

-- ============================================
-- デイリークエスト定義（毎日リセット）
-- ============================================
local DAILY_QUEST_POOL = {
    {id="play3",    text="3試合プレイする",         target=3,   type="play",   reward={gems=50,  exp=100}},
    {id="win2",     text="2試合勝利する",           target=2,   type="win",    reward={gems=100, exp=200}},
    {id="arcana3",  text="アルカナを3回使う",       target=3,   type="arcana", reward={gems=80,  exp=150}},
    {id="col5",     text="列を5枚積み上げる",       target=5,   type="column", reward={gems=60,  exp=120}},
    {id="gacha1",   text="ガチャを1回引く",         target=1,   type="gacha",  reward={gems=30,  exp=50}},
    {id="chip10",   text="チップを10枚溜める",      target=10,  type="chip",   reward={gems=70,  exp=130}},
    {id="solo3",    text="AI練習を3回プレイする",   target=3,   type="solo",   reward={gems=40,  exp=80}},
    {id="team5",    text="タッグ戦を5試合プレイ",   target=5,   type="tag",    reward={gems=120, exp=250}},
    {id="7col",     text="7枚積み上げを達成する",   target=1,   type="7col",   reward={gems=200, exp=500}},
    {id="partner5", text="パートナーを5回育成",     target=5,   type="partner",reward={gems=60,  exp=120}},
}

-- ウィークリークエスト（日曜リセット）
local WEEKLY_QUEST_POOL = {
    {id="w_win10",  text="今週10勝する",            target=10,  type="win",    reward={gems=500,  exp=1000, seasonExp=200}},
    {id="w_play30", text="今週30試合プレイする",     target=30,  type="play",   reward={gems=300,  exp=600,  seasonExp=100}},
    {id="w_tag15",  text="タッグ戦を15試合プレイ",  target=15,  type="tag",    reward={gems=700,  exp=1500, seasonExp=300}},
    {id="w_rank",   text="ランクマッチで5勝する",    target=5,   type="rank_win",reward={gems=1000, exp=2000, seasonExp=500}},
}

-- ============================================
-- 今日の日付キー（JST基準）
-- ============================================
local function getDayKey()
    -- UTC+9 (JST)
    local t = os.time() + 9 * 3600
    local d = os.date("*t", t)
    return string.format("%04d%02d%02d", d.year, d.month, d.day)
end

local function getWeekKey()
    local t = os.time() + 9 * 3600
    local d = os.date("*t", t)
    -- 週の始まり（月曜）を基準
    local weekday = d.wday == 1 and 7 or d.wday - 1
    local monday  = t - (weekday - 1) * 86400
    local md      = os.date("*t", monday)
    return string.format("%04d%02d%02d", md.year, md.month, md.day)
end

-- ============================================
-- クエストデータ読み書き
-- ============================================
local QuestCache = {}

local function loadQuestData(player)
    local key = "quest_" .. player.UserId
    local ok, data = pcall(function()
        return QuestStore:GetAsync(key)
    end)
    local now = os.time()
    if not ok or not data then
        data = {daily = {}, weekly = {}, lastDayKey = "", lastWeekKey = ""}
    end

    local dayKey  = getDayKey()
    local weekKey = getWeekKey()

    -- 日付が変わっていたらデイリーリセット
    if data.lastDayKey ~= dayKey then
        -- 3つのデイリークエストをランダム選択
        local pool = {table.unpack(DAILY_QUEST_POOL)}
        local selected = {}
        for i = 1, math.min(3, #pool) do
            local j = math.random(i, #pool)
            pool[i], pool[j] = pool[j], pool[i]
            selected[pool[i].id] = {progress = 0, done = false}
        end
        data.daily       = selected
        data.dailyIds    = {}
        for i = 1, math.min(3, #pool) do
            table.insert(data.dailyIds, pool[i].id)
        end
        data.lastDayKey  = dayKey
    end

    -- 週が変わっていたらウィークリーリセット
    if data.lastWeekKey ~= weekKey then
        local pool = {table.unpack(WEEKLY_QUEST_POOL)}
        local selected = {}
        for i = 1, math.min(2, #pool) do
            local j = math.random(i, #pool)
            pool[i], pool[j] = pool[j], pool[i]
            selected[pool[i].id] = {progress = 0, done = false}
        end
        data.weekly      = selected
        data.weeklyIds   = {}
        for i = 1, math.min(2, #pool) do
            table.insert(data.weeklyIds, pool[i].id)
        end
        data.lastWeekKey = weekKey
    end

    QuestCache[player.UserId] = data
    return data
end

local function saveQuestData(player)
    local data = QuestCache[player.UserId]
    if not data then return end
    pcall(function()
        QuestStore:SetAsync("quest_" .. player.UserId, data)
    end)
end

-- ============================================
-- シーズンデータ
-- ============================================
local SeasonCache = {}

local function loadSeasonData(player)
    local key = "season_" .. CURRENT_SEASON.id .. "_" .. player.UserId
    local ok, data = pcall(function()
        return SeasonStore:GetAsync(key)
    end)
    if not ok or not data then
        data = {rank = 0, exp = 0, hasPremium = false, claimedRanks = {}}
    end
    -- GamePassを確認
    local hasPremium = false
    pcall(function()
        hasPremium = MarketplaceService:UserOwnsGamePassAsync(
            player.UserId, CURRENT_SEASON.passId)
    end)
    data.hasPremium = hasPremium
    SeasonCache[player.UserId] = data
    return data
end

local function saveSeasonData(player)
    local data = SeasonCache[player.UserId]
    if not data then return end
    local key = "season_" .. CURRENT_SEASON.id .. "_" .. player.UserId
    pcall(function()
        SeasonStore:SetAsync(key, data)
    end)
end

-- ============================================
-- シーズンEXP追加 → ランクアップ判定 → 報酬付与
-- ============================================
local function addSeasonExp(player, amount)
    local sData = SeasonCache[player.UserId]
    if not sData then return end

    local oldRank = sData.rank
    sData.exp = sData.exp + amount

    -- 1ランクアップに必要なEXP（線形）
    local expPerRank = 500
    local newRank = math.min(
        CURRENT_SEASON.maxRank,
        math.floor(sData.exp / expPerRank)
    )

    -- ランクアップした分の報酬を付与
    for r = oldRank + 1, newRank do
        if CURRENT_SEASON.rewards[r] and not sData.claimedRanks[r] then
            sData.claimedRanks[r] = true
            local reward = sData.hasPremium
                and CURRENT_SEASON.rewards[r].pass
                or  CURRENT_SEASON.rewards[r].free

            -- ジェム付与（GachaSystemのaddGemsを呼ぶ）
            if reward.gems and reward.gems > 0 then
                local GemFunc = ReplicatedStorage:FindFirstChild("AddGems")
                if GemFunc then
                    pcall(function() GemFunc:Invoke(player, reward.gems) end)
                end
            end

            -- ランクアップ通知
            local pl = Players:GetPlayerByUserId(player.UserId)
            if pl then
                RE_UpdateBoard:FireClient(pl, {
                    type       = "season_rank_up",
                    newRank    = r,
                    maxRank    = CURRENT_SEASON.maxRank,
                    reward     = reward,
                    hasPremium = sData.hasPremium,
                })
            end
        end
    end

    sData.rank = newRank
    saveSeasonData(player)
end

-- ============================================
-- クエスト進捗を更新する関数（外部から呼ぶ）
-- ============================================
local function updateQuestProgress(player, eventType, amount)
    local qData = QuestCache[player.UserId]
    if not qData then return end

    amount = amount or 1
    local completed = {}

    -- デイリーをチェック
    for _, qid in ipairs(qData.dailyIds or {}) do
        local qDef = nil
        for _, d in ipairs(DAILY_QUEST_POOL) do
            if d.id == qid then qDef = d; break end
        end
        if qDef and qDef.type == eventType then
            local prog = qData.daily[qid]
            if prog and not prog.done then
                prog.progress = prog.progress + amount
                if prog.progress >= qDef.target then
                    prog.done = true
                    table.insert(completed, {source="daily", def=qDef})
                end
            end
        end
    end

    -- ウィークリーをチェック
    for _, qid in ipairs(qData.weeklyIds or {}) do
        local qDef = nil
        for _, d in ipairs(WEEKLY_QUEST_POOL) do
            if d.id == qid then qDef = d; break end
        end
        if qDef and qDef.type == eventType then
            local prog = qData.weekly[qid]
            if prog and not prog.done then
                prog.progress = prog.progress + amount
                if prog.progress >= qDef.target then
                    prog.done = true
                    table.insert(completed, {source="weekly", def=qDef})
                end
            end
        end
    end

    -- 完了報酬を付与
    for _, comp in ipairs(completed) do
        local def = comp.def

        -- ジェム付与
        if def.reward.gems and def.reward.gems > 0 then
            local GemFunc = ReplicatedStorage:FindFirstChild("AddGems")
            if GemFunc then
                pcall(function() GemFunc:Invoke(player, def.reward.gems) end)
            end
        end

        -- シーズンEXP追加
        if def.reward.seasonExp then
            addSeasonExp(player, def.reward.seasonExp)
        end

        -- 自動受け取り完了通知（手動クレーム不要）
        local pl = Players:GetPlayerByUserId(player.UserId)
        if pl then
            RE_UpdateBoard:FireClient(pl, {
                type      = "quest_auto_complete",
                source    = comp.source,
                questId   = def.id,
                text      = def.text,
                gemsGiven = (def.reward and def.reward.gems) or 0,
            })
        end
    end

    saveQuestData(player)
end

-- ============================================
-- 外部公開（BattleServerから呼ぶ）
-- ============================================
local QuestFunc = Instance.new("BindableFunction")
QuestFunc.Name  = "UpdateQuestProgress"
QuestFunc.Parent = ReplicatedStorage

QuestFunc.OnInvoke = function(player, eventType, amount)
    updateQuestProgress(player, eventType, amount)
end

-- ============================================
-- プレイヤー入退室
-- ============================================
Players.PlayerAdded:Connect(function(player)
    local qData = loadQuestData(player)
    local sData = loadSeasonData(player)

    task.wait(3)
    local pl = Players:GetPlayerByUserId(player.UserId)
    if not pl then return end

    -- クエスト情報を送信
    local dailyList = {}
    for _, qid in ipairs(qData.dailyIds or {}) do
        for _, d in ipairs(DAILY_QUEST_POOL) do
            if d.id == qid then
                table.insert(dailyList, {
                    id       = d.id,
                    text     = d.text,
                    target   = d.target,
                    progress = (qData.daily[qid] or {}).progress or 0,
                    done     = (qData.daily[qid] or {}).done or false,
                    reward   = d.reward,
                })
                break
            end
        end
    end

    local weeklyList = {}
    for _, qid in ipairs(qData.weeklyIds or {}) do
        for _, d in ipairs(WEEKLY_QUEST_POOL) do
            if d.id == qid then
                table.insert(weeklyList, {
                    id       = d.id,
                    text     = d.text,
                    target   = d.target,
                    progress = (qData.weekly[qid] or {}).progress or 0,
                    done     = (qData.weekly[qid] or {}).done or false,
                    reward   = d.reward,
                })
                break
            end
        end
    end

    RE_UpdateBoard:FireClient(pl, {
        type = "quest_update", quests = dailyList,
        daily       = dailyList,
        weekly      = weeklyList,
        season      = {
            id         = CURRENT_SEASON.id,
            name       = CURRENT_SEASON.name,
            rank       = sData.rank,
            maxRank    = CURRENT_SEASON.maxRank,
            exp        = sData.exp,
            expPerRank = 500,
            hasPremium = sData.hasPremium,
            passId     = CURRENT_SEASON.passId,
        },
    })
end)

Players.PlayerRemoving:Connect(function(player)
    saveQuestData(player)
    saveSeasonData(player)
    QuestCache[player.UserId]   = nil
    SeasonCache[player.UserId]  = nil
end)

-- 定期オートセーブ
task.spawn(function()
    while true do
        task.wait(300)
        for _, pl in ipairs(Players:GetPlayers()) do
            saveQuestData(pl)
            saveSeasonData(pl)
        end
    end
end)

print("✅ QuestSystem.lua loaded")

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- クエスト報酬受け取り（クライアントから呼ばれる）
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━
local RE_QuestClaim = Remotes:WaitForChild("QuestClaim", 15)
RE_QuestClaim.OnServerEvent:Connect(function(player, data)
    local questId = data and data.questId
    if not questId then return end

    local qData = loadQuestData(player)
    local def    = nil
    -- デイリー・ウィークリーから探す
    for _, q in ipairs(qData.daily or {}) do
        if q.id == questId then def = q; break end
    end
    if not def then
        for _, q in ipairs(qData.weekly or {}) do
            if q.id == questId then def = q; break end
        end
    end

    if not def then
        RE_UpdateBoard:FireClient(player, {
            type = "quest_claim_result", success = false,
            message = "クエストが見つかりません"
        })
        return
    end
    if def.progress < def.required then
        RE_UpdateBoard:FireClient(player, {
            type = "quest_claim_result", success = false,
            message = "まだ達成していません"
        })
        return
    end
    if def.claimed then
        RE_UpdateBoard:FireClient(player, {
            type = "quest_claim_result", success = false,
            message = "すでに受け取り済みです"
        })
        return
    end

    -- 報酬付与
    def.claimed = true
    local gemsGiven = (def.reward and def.reward.gems) or 0
    if gemsGiven > 0 then
        local AddGems = ReplicatedStorage:FindFirstChild("AddGems")
        if AddGems then pcall(function() AddGems:Invoke(player, gemsGiven) end) end
    end

    saveQuestData(player)

    RE_UpdateBoard:FireClient(player, {
        type    = "quest_claim_result",
        success = true,
        questId = questId,
        gems    = gemsGiven,
        message = "受け取り完了！ +" .. gemsGiven .. "💎"
    })
end)
