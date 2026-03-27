-- ============================================
-- GAMEROAD RatingSystem.lua
-- ServerScriptService/ に配置（Script型）
-- ELO計算 + OrderedDataStoreでグローバルランキング
-- ============================================

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes       = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_UpdateBoard = Remotes:WaitForChild("UpdateBoard", 15)

-- OrderedDataStore（GetSortedAsync でランキング取得できる）
local EloStore      = DataStoreService:GetOrderedDataStore("EloRating_v1")
local PlayerStore   = DataStoreService:GetDataStore("PlayerData_v1")

-- ============================================
-- ELO計算（シンプル版）
-- 初期ELO: 1000
-- K係数: Lv1-10=32, Lv11-20=24, Lv21+=16
-- ============================================
local function expectedScore(myElo, opponentElo)
    return 1 / (1 + 10 ^ ((opponentElo - myElo) / 400))
end

local function calcEloChange(myElo, opponentElo, won, kFactor)
    kFactor = kFactor or 32
    local expected = expectedScore(myElo, opponentElo)
    local actual   = won and 1 or 0
    return math.floor(kFactor * (actual - expected))
end

local function getKFactor(gamesPlayed)
    if gamesPlayed <= 10 then return 40  -- 初心者は変動大きく
    elseif gamesPlayed <= 50 then return 32
    elseif gamesPlayed <= 200 then return 24
    else return 16 end
end

-- ============================================
-- ELO読み書き（UpdateAsync で原子的に更新）
-- ============================================
local function getPlayerElo(userId)
    local elo = 1000
    pcall(function()
        elo = EloStore:GetAsync(tostring(userId)) or 1000
    end)
    return elo
end

local function updatePlayerElo(userId, delta, gamesPlayed)
    local newElo = 1000
    local ok, err = pcall(function()
        -- UpdateAsync: 現在値を読んで更新する（競合しない）
        newElo = EloStore:UpdateAsync(tostring(userId), function(old)
            local current = old or 1000
            local updated = math.max(100, current + delta)  -- 最低100保証
            return updated
        end)
    end)
    if not ok then
        warn("ELO update failed for " .. userId .. ": " .. tostring(err))
    end
    return newElo or (1000 + delta)
end

-- PlayerDataのstatsにもELOを保存（参照用）
local function saveEloToPlayerData(userId, elo)
    -- GachaSystemのキャッシュ経由でELOを更新（DataStore競合回避）
    local eloEvent = ReplicatedStorage:FindFirstChild("UpdatePlayerElo")
    if eloEvent then
        pcall(function() eloEvent:Fire(userId, elo) end)
    else
        -- フォールバック: 直接書き込み（GachaSystemが未起動の場合）
        pcall(function()
            PlayerStore:UpdateAsync("player_" .. userId, function(data)
                data = data or {}
                data.stats = data.stats or {}
                data.stats.elo = elo
                return data
            end)
        end)
    end
end

-- ============================================
-- ゲーム終了時にELOを更新（外部から呼ぶ）
-- ============================================
local function processGameResult(winnerTeam, playerDefs)
    -- playerDefs = [{userId, team, gamesPlayed}, ...]
    local teamElos = {}

    -- 各プレイヤーのELOを取得
    for _, p in ipairs(playerDefs) do
        if p.userId > 0 then  -- AI(負のID)は除く
            teamElos[p.userId] = getPlayerElo(p.userId)
        end
    end

    -- チーム平均ELO
    local avgTeamA, avgTeamB = 0, 0
    local countA, countB = 0, 0
    for _, p in ipairs(playerDefs) do
        if p.userId > 0 then
            if p.team == "A" then
                avgTeamA = avgTeamA + teamElos[p.userId]
                countA = countA + 1
            else
                avgTeamB = avgTeamB + teamElos[p.userId]
                countB = countB + 1
            end
        end
    end
    avgTeamA = countA > 0 and (avgTeamA / countA) or 1000
    avgTeamB = countB > 0 and (avgTeamB / countB) or 1000

    -- 各プレイヤーのELO更新
    for _, p in ipairs(playerDefs) do
        if p.userId > 0 then
            local myElo   = teamElos[p.userId]
            local oppAvg  = (p.team == "A") and avgTeamB or avgTeamA
            local won     = (p.team == winnerTeam)
            local k       = getKFactor(p.gamesPlayed or 0)
            local delta   = calcEloChange(myElo, oppAvg, won, k)
            local newElo  = updatePlayerElo(p.userId, delta, p.gamesPlayed)

            saveEloToPlayerData(p.userId, newElo)

            -- プレイヤーに通知
            local pl = Players:GetPlayerByUserId(p.userId)
            if pl then
                RE_UpdateBoard:FireClient(pl, {
                    type     = "elo_update",
                    oldElo   = myElo,
                    newElo   = newElo,
                    delta    = delta,
                    won      = won,
                    rank     = nil,  -- 後でランキング確認時に取得
                })
            end
        end
    end
end

-- ============================================
-- グローバルリーダーボード取得（上位10人）
-- ============================================
local LeaderboardCache   = nil
local LeaderboardUpdated = 0

local function getLeaderboard(forceRefresh)
    local now = os.time()
    -- 60秒キャッシュ（リクエスト節約）
    if not forceRefresh and LeaderboardCache
       and (now - LeaderboardUpdated) < 60 then
        return LeaderboardCache
    end

    local board = {}
    local ok, pages = pcall(function()
        return EloStore:GetSortedAsync(
            false,  -- ascending=false → 高い順
            10      -- 上位10件
        )
    end)

    if ok and pages then
        local ok2, items = pcall(function()
            return pages:GetCurrentPage()
        end)
        if ok2 and items then
            for rank, entry in ipairs(items) do
                table.insert(board, {
                    rank   = rank,
                    userId = tonumber(entry.key),
                    elo    = entry.value,
                    name   = "???"  -- Players:GetNameFromUserIdAsync は低速なのでキャッシュ必要
                })
            end
        end
    end

    LeaderboardCache   = board
    LeaderboardUpdated = now
    return board
end

-- ============================================
-- プレイヤーの現在のランクを取得
-- ============================================
local function getPlayerRank(userId)
    local board = getLeaderboard(false)
    for _, entry in ipairs(board) do
        if entry.userId == userId then
            return entry.rank
        end
    end
    return nil  -- トップ10外
end

-- ============================================
-- プレイヤーからのリーダーボード要求
-- ============================================
-- UpdateBoardを再利用（type="leaderboard_request"）
local RE_ReqLB = Remotes:WaitForChild("UpdateBoard", 15)
-- クライアントからはUpdateBoardイベントで要求できないのでRemoteEventを追加
-- SetupRemotesにLeaderboardRequestを追加すべきだが、
-- 今はPlayerAddedで自動送信する方式で代替

Players.PlayerAdded:Connect(function(player)
    task.wait(3)
    local elo   = getPlayerElo(player.UserId)
    local board = getLeaderboard(false)
    local rank  = getPlayerRank(player.UserId)

    local pl = Players:GetPlayerByUserId(player.UserId)
    if pl then
        RE_UpdateBoard:FireClient(pl, {
            type      = "elo_info",
            elo       = elo,
            rank      = rank,
            board     = board,
        })
    end
end)

-- ============================================
-- BindableFunction: 外部からELO更新を呼べるように
-- ============================================
local EloFunc = Instance.new("BindableFunction")
EloFunc.Name  = "ProcessGameResult"
EloFunc.Parent = ReplicatedStorage

EloFunc.OnInvoke = function(winnerTeam, playerDefs)
    processGameResult(winnerTeam, playerDefs)
end

-- リーダーボードを定期更新して全プレイヤーに配信
task.spawn(function()
    while true do
        task.wait(120)  -- 2分ごと
        local board = getLeaderboard(true)
        for _, player in ipairs(Players:GetPlayers()) do
            RE_UpdateBoard:FireClient(player, {
                type  = "leaderboard_update",
                board = board,
            })
        end
    end
end)

print("✅ RatingSystem.lua loaded")
