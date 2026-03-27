-- ============================================
-- GAMEROAD BattleRoyale_4p.lua
-- ServerScriptService/ に配置（Script型）
--
-- 4人麻雀型バトルロワイヤル
-- 設計根拠：
--   「負けたら終わり」→離脱率UP
--   4人全員が最後まで参加→セッション時間延長→リテンション向上
--
-- ルール：
--   4人で複数ラウンド戦う（麻雀の東風戦風）
--   各ラウンドで獲得したポイントを積み上げる
--   規定ラウンド終了時に最多ポイントが優勝
--   1ラウンド = 通常のGAMEROADバトル（先に7枚積んだ人がラウンド勝利）
--   ラウンド勝者：+3pt / 2位：+1pt / 3・4位：+0pt / 最下位ペナルティ有
-- ============================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Remotes        = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_UpdateBoard = Remotes:WaitForChild("UpdateBoard", 15)

-- ポイントテーブル（麻雀の符計算を簡略化）
local POINTS = {
    [1] = 3,   -- ラウンド勝者
    [2] = 1,   -- 2位
    [3] = 0,   -- 3位
    [4] = -1,  -- 最下位ペナルティ
}

local TOTAL_ROUNDS = 4  -- 麻雀東風戦風（4ラウンド）

-- 4人バトロワのセッション管理
local BRSessions = {}  -- roomId -> session

-- ============================================
-- セッション作成
-- ============================================
local function createSession(playerIds, roomId)
    local players = {}
    for _, uid in ipairs(playerIds) do
        local pl = Players:GetPlayerByUserId(uid)
        players[uid] = {
            userId   = uid,
            name     = pl and pl.Name or "???",
            points   = 0,
            roundHistory = {},  -- 各ラウンドの順位
        }
    end

    return {
        roomId      = roomId,
        playerIds   = playerIds,
        players     = players,
        round       = 1,
        totalRounds = TOTAL_ROUNDS,
        active      = true,
    }
end

-- ============================================
-- 全参加者に通知
-- ============================================
local function broadcast4p(session, data)
    for _, uid in ipairs(session.playerIds) do
        local pl = Players:GetPlayerByUserId(uid)
        if pl then RE_UpdateBoard:FireClient(pl, data) end
    end
end

-- ============================================
-- 現在のポイント順位を計算
-- ============================================
local function getRankings(session)
    local list = {}
    for uid, p in pairs(session.players) do
        table.insert(list, {userId = uid, name = p.name, points = p.points})
    end
    table.sort(list, function(a, b) return a.points > b.points end)
    for i, entry in ipairs(list) do entry.rank = i end
    return list
end

-- ============================================
-- 1ラウンドを実行
-- ============================================
local function runRound(session)
    local round = session.round
    local roomId = session.roomId .. "_r" .. round

    -- 4人でバトル開始を通知
    local playerDefs = {}
    for i, uid in ipairs(session.playerIds) do
        local p = session.players[uid]
        -- 4人を2チームに分ける（ラウンドごとにシャッフル）
        table.insert(playerDefs, {
            userId  = uid,
            name    = p.name,
            isHuman = Players:GetPlayerByUserId(uid) ~= nil,
            team    = (i <= 2) and "A" or "B",
            suit    = "club",
        })
    end

    -- ポイント状況を表示してラウンド開始
    local rankings = getRankings(session)
    broadcast4p(session, {
        type       = "br4p_round_start",
        round      = round,
        totalRounds = session.totalRounds,
        roomId     = roomId,
        playerDefs = playerDefs,
        rankings   = rankings,
    })

    task.wait(3)

    -- バトル実行（BattleServer_v2に委譲）
    local StartBR = ReplicatedStorage:WaitForChild("StartBattleRoyaleMatch", 15)
    local winnerId = nil

    if StartBR then
        local ok, result = pcall(function()
            return StartBR:Invoke(playerDefs, "br4p", roomId)
        end)
        if ok then winnerId = result end
    end

    -- 順位をランダムで決定（フォールバック）
    if not winnerId then
        winnerId = session.playerIds[math.random(#session.playerIds)]
    end

    -- 順位付け（簡略化：勝ったチームが1・2位、負けたチームが3・4位）
    local winnerTeam = nil
    for _, def in ipairs(playerDefs) do
        if def.userId == winnerId then
            winnerTeam = def.team
            break
        end
    end

    local rankAssign = {}
    local rankCount  = {win=0, lose=0}
    for _, def in ipairs(playerDefs) do
        if def.team == winnerTeam then
            rankCount.win = rankCount.win + 1
            rankAssign[def.userId] = rankCount.win  -- 1位か2位
        else
            rankCount.lose = rankCount.lose + 1
            rankAssign[def.userId] = 2 + rankCount.lose  -- 3位か4位
        end
    end

    -- ポイント付与
    local roundResult = {}
    for uid, rank in pairs(rankAssign) do
        local pt = POINTS[rank] or 0
        session.players[uid].points = session.players[uid].points + pt
        table.insert(session.players[uid].roundHistory, {round=round, rank=rank, pt=pt})
        table.insert(roundResult, {
            userId  = uid,
            name    = session.players[uid].name,
            rank    = rank,
            pt      = pt,
            total   = session.players[uid].points,
        })
        -- 個別通知
        local pl = Players:GetPlayerByUserId(uid)
        if pl then
            RE_UpdateBoard:FireClient(pl, {
                type        = "br4p_round_result",
                round       = round,
                rank        = rank,
                ptGained    = pt,
                totalPoints = session.players[uid].points,
            })
        end
    end

    -- 全体にラウンド結果を表示
    local newRankings = getRankings(session)
    broadcast4p(session, {
        type        = "br4p_round_end",
        round       = round,
        result      = roundResult,
        rankings    = newRankings,
        nextRound   = round < session.totalRounds,
    })

    task.wait(8)  -- 結果確認タイム（麻雀の点数確認的な間）
end

-- ============================================
-- セッション全体を実行
-- ============================================
local function runSession(playerIds, roomId)
    local session = createSession(playerIds, roomId)
    BRSessions[roomId] = session

    broadcast4p(session, {
        type        = "br4p_start",
        totalRounds = TOTAL_ROUNDS,
        roomId      = roomId,
        players     = (function()
            local list = {}
            for uid, p in pairs(session.players) do
                table.insert(list, {userId=uid, name=p.name, points=0})
            end
            return list
        end)(),
    })
    task.wait(4)

    -- ラウンドを繰り返す
    while session.round <= session.totalRounds and session.active do
        runRound(session)
        session.round = session.round + 1
        task.wait(3)
    end

    -- 最終結果
    local finalRankings = getRankings(session)
    local champion = finalRankings[1]

    broadcast4p(session, {
        type     = "br4p_end",
        rankings = finalRankings,
        champion = champion,
        roomId   = roomId,
    })

    -- ELO更新
    local EloFunc = ReplicatedStorage:FindFirstChild("ProcessGameResult")
    if EloFunc then
        local defs = {}
        for _, entry in ipairs(finalRankings) do
            table.insert(defs, {
                userId      = entry.userId,
                team        = entry.rank <= 2 and "A" or "B",
                gamesPlayed = 0,
            })
        end
        pcall(function()
            EloFunc:Invoke("A", defs)  -- 1・2位がチームA扱い
        end)
    end

    -- クエスト進捗
    local QuestFunc = ReplicatedStorage:FindFirstChild("UpdateQuestProgress")
    if QuestFunc then
        for _, uid in ipairs(playerIds) do
            local pl = Players:GetPlayerByUserId(uid)
            if pl then
                pcall(function() QuestFunc:Invoke(pl, "play", 1) end)
                if uid == champion.userId then
                    pcall(function() QuestFunc:Invoke(pl, "win", 1) end)
                end
            end
        end
    end

    BRSessions[roomId] = nil
    print("✅ 4p BR Session complete. Champion: " .. champion.name ..
          " (" .. champion.points .. "pt)")
end

-- ============================================
-- 外部公開（Matchmaking_v2から呼ぶ）
-- ============================================
local BR4pFunc = Instance.new("BindableFunction")
BR4pFunc.Name  = "StartBattleRoyale4p"
BR4pFunc.Parent = ReplicatedStorage

BR4pFunc.OnInvoke = function(playerIds, roomId)
    task.spawn(function()
        runSession(playerIds, roomId or ("br4p_" .. os.time()))
    end)
end

print("✅ BattleRoyale_4p.lua loaded")
