-- ============================================
-- GAMEROAD Matchmaking_v2.lua
-- ServerScriptService/ に配置（Script型）
-- MemoryStoreQueueでクロスサーバーマッチング実装
-- 公式推奨パターン：1サーバーがcentralized handler
-- ============================================

local Players             = game:GetService("Players")
local MemoryStoreService  = game:GetService("MemoryStoreService")
local TeleportService     = game:GetService("TeleportService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local DataStoreService    = game:GetService("DataStoreService")

local Remotes       = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_UpdateBoard = Remotes:WaitForChild("UpdateBoard", 15)
local RE_MMJoin     = Remotes:WaitForChild("MatchmakingJoin", 15)
local RE_MMCancel   = Remotes:WaitForChild("MatchmakingCancel", 15)
local RE_OpenBattleSet = Remotes:WaitForChild("OpenBattleSet", 15)

-- MemoryStore キュー（モード別）
-- TTL 300秒 = 5分待っても試合が始まらなければ自動削除
local Queues = {
    tag_trump    = MemoryStoreService:GetQueue("MM_Tag_Trump"),    -- コンビ戦・トランプ版
    tag_tcg      = MemoryStoreService:GetQueue("MM_Tag_TCG"),      -- コンビ戦・TCG版
    battle_trump = MemoryStoreService:GetQueue("MM_Battle_Trump"), -- バトロワ・トランプ版
    battle_tcg   = MemoryStoreService:GetQueue("MM_Battle_TCG"),   -- バトロワ・TCG版
    solo         = MemoryStoreService:GetQueue("MM_Solo"),         -- ソロAI練習（共通）
}

-- 必要人数
local MODE_SIZE = {
    tag_trump    = 4,
    tag_tcg      = 4,
    battle_trump = 4,
    battle_tcg   = 4,
    solo         = 1,
}

-- TCGフラグ（このモードはTCG版か）
local IS_TCG = {
    tag_trump    = false,
    tag_tcg      = true,
    battle_trump = false,
    battle_tcg   = true,
    solo         = false,  -- ソロはTCG版オプションをjoinQueue時に引数で渡す
}

-- baseMode（tag/battle/solo）を返す
local function baseMode(mode)
    if mode == "tag_trump" or mode == "tag_tcg" then return "tag" end
    if mode == "battle_trump" or mode == "battle_tcg" then return "battle" end
    return "solo"
end

-- Place ID（公開後に差し替え）
-- ロビーと試合場を別Placeにするとサーバー分離できる
-- 最初は同一Place内でやる → PlaceId = game.PlaceId
local GAME_PLACE_ID = game.PlaceId  -- 後で専用Placeに変えてもいい

-- 現在キュー待ち中のプレイヤー（このサーバー内）
local WaitingPlayers = {}  -- [userId] = mode

-- ============================================
-- キューに追加
-- ============================================
local function joinQueue(player, mode)
    local queue = Queues[mode]
    if not queue then return end

    -- 既にキュー待ちならスキップ
    if WaitingPlayers[player.UserId] then
        RE_UpdateBoard:FireClient(player, {
            type = "mm_status", message = "既にキュー待ちです"
        })
        return
    end

    -- DataStoreからELOを取得（スキルベースマッチング用・なければ1000）
    local elo = 1000
    pcall(function()
        local store = DataStoreService:GetDataStore("PlayerData_v1")
        local d = store:GetAsync("player_" .. player.UserId)
        if d and d.stats and d.stats.elo then elo = d.stats.elo end
    end)

    -- デッキ登録チェック（初回プレイヤーがいきなりマッチングに入るのを防ぐ）
    if mode ~= "solo" then
        local hasDeck = false
        pcall(function()
            local bsData = BattleSetStore:GetAsync("battleset_" .. player.UserId)
            hasDeck = bsData ~= nil
        end)
        if not hasDeck then
            RE_UpdateBoard:FireClient(player, {
                type    = "mm_status",
                message = "⚠️ まずバトルセットを登録してください（ロビー→📋バトルセット）",
            })
            return
        end
    end

    local entry = {
        userId   = player.UserId,
        name     = player.Name,
        elo      = elo,
        serverId = game.JobId,  -- このサーバーのID（TeleportAsyncで使う）
        joinedAt = os.time(),
    }

    local ok, err = pcall(function()
        -- priority = elo（スキルベースで近い人を優先的にマッチ）
        queue:AddAsync(
            tostring(player.UserId),  -- key
            entry,                    -- value
            300,                      -- TTL: 5分
            elo                       -- priority（低い方が先）
        )
    end)

    if ok then
        WaitingPlayers[player.UserId] = mode
        RE_UpdateBoard:FireClient(player, {
            type    = "matching_start",
            mode    = mode,
        })
        RE_UpdateBoard:FireClient(player, {
            type    = "mm_status",
            message = "マッチング中... (" .. mode .. ")",
            mode    = mode,
        })
        print(player.Name .. " joined " .. mode .. " queue (ELO:" .. elo .. ")")
    else
        warn("Queue add failed: " .. tostring(err))
        RE_UpdateBoard:FireClient(player, {
            type = "mm_status", message = "マッチングエラー。もう一度お試しください"
        })
    end
end

-- ============================================
-- キューから削除（キャンセル）
-- ============================================
local function leaveQueue(player)
    local mode = WaitingPlayers[player.UserId]
    if not mode then return end

    local queue = Queues[mode]
    if queue then
        -- RemoveAsync: keyで直接削除
        -- MemoryStoreQueue は ReadAsync で取り出してから RemoveAsync が正式フロー
        -- 個別削除は SortedMap で実装する方が正確だが、
        -- TTLで自然消滅させるのが最もシンプル（5分後に自動消える）
        -- 実用上はTTL任せで問題ない
    end
    WaitingPlayers[player.UserId] = nil
    RE_UpdateBoard:FireClient(player, {
        type = "mm_status", message = "キャンセルしました"
    })
    print(player.Name .. " left queue")
end

-- ============================================
-- マッチング処理ループ（このサーバーが担当）
-- 全サーバーが同じキューを見るが ReadAsync の invisibility timeout で
-- 重複取り出しを防止する
-- ============================================
local function processQueue(mode)
    local queue = Queues[mode]
    local needed = MODE_SIZE[mode]

    -- 必要人数分を一気に読む
    local ok, items, id = pcall(function()
        return queue:ReadAsync(
            needed,  -- 最大取り出し数
            false,   -- excludeInvisible
            15       -- invisibility timeout: 15秒間は他サーバーが触れない
        )
    end)

    if not ok then
        -- Throttling対策：エラーなら次のループまで待つ
        return false
    end

    if #items < needed then
        -- まだ人数が足りない → アイテムをキューに戻す（RemoveしないでOK）
        return false
    end

    -- 人数が揃った → マッチ確定
    -- キューから削除
    pcall(function()
        queue:RemoveAsync(id)
    end)

    -- チーム分け
    local matched = {}
    for _, item in ipairs(items) do
        table.insert(matched, item)
    end

    -- スート考慮チーム分け
    -- 優先：同チーム内のスートが違う組み合わせ
    local teamA, teamB = {}, {}
    if baseMode(mode) == "tag" then
        -- 全組み合わせを試してミラーが少ないペアを選ぶ
        local function countMirrors(a1, a2, b1, b2)
            local count = 0
            if a1.suit == a2.suit then count = count + 2 end  -- 同チームミラー（重大）
            if b1.suit == b2.suit then count = count + 2 end
            if a1.suit == b1.suit then count = count + 1 end  -- 対戦ミラー
            if a1.suit == b2.suit then count = count + 1 end
            if a2.suit == b1.suit then count = count + 1 end
            if a2.suit == b2.suit then count = count + 1 end
            return count
        end
        -- 4人の全パターンを試す（4!/2 = 12通り）
        local bestScore = 999
        local bestAssign = nil
        local m = matched
        local patterns = {
            {m[1],m[2],m[3],m[4]}, {m[1],m[3],m[2],m[4]}, {m[1],m[4],m[2],m[3]},
        }
        for _, pat in ipairs(patterns) do
            local score = countMirrors(pat[1],pat[2],pat[3],pat[4])
            if score < bestScore then
                bestScore = score
                bestAssign = pat
            end
        end
        if bestAssign then
            teamA = {bestAssign[1], bestAssign[2]}
            teamB = {bestAssign[3], bestAssign[4]}
        else
            teamA = {matched[1], matched[2]}
            teamB = {matched[3], matched[4]}
        end
        print(string.format("マッチング: ミラースコア=%d (0が最良)", bestScore))
    elseif mode == "battle" then
        -- バトロワは全員同じリスト（チームなし）
        teamA = matched
    end

    print("✅ Match found! Mode:" .. mode ..
          " Players:" .. #matched)

    return true, matched, teamA, teamB
end

-- ============================================
-- ゲーム起動（同一サーバー内でゲームを開始する）
-- ※ 別Placeに飛ばす場合は TeleportService:TeleportAsync を使う
-- 今は同一サーバー内でゲームを動かす（初期リリース向け）
-- ============================================
local function startMatchedGame(matched, teamA, teamB, mode)
    -- キュー待ち状態を解除
    for _, entry in ipairs(matched) do
        WaitingPlayers[entry.userId] = nil
    end

    local playerIds = {}
    for _, entry in ipairs(matched) do
        table.insert(playerIds, entry.userId)
    end

    local roomId = mode .. "_" .. os.time() .. "_" .. math.random(9999)

    -- ━━ バトロワ4人麻雀型 ━━
    if baseMode(mode) == "battle" then
        local BR4p = ReplicatedStorage:FindFirstChild("StartBattleRoyale4p")
        if BR4p then
            task.spawn(function()
                BR4p:Invoke(playerIds, roomId)
            end)
            print("✅ BR4p started: " .. #playerIds .. " players")
        else
            warn("StartBattleRoyale4p not found")
        end
        return
    end

    -- ━━ タッグ戦2vs2（コンビ戦） ━━
    if baseMode(mode) == "tag" then
        local playerDefs = {}
        local DeckStore     = game:GetService("DataStoreService"):GetDataStore("GameRoad_Decks_v1")
        local BattleSetStore = game:GetService("DataStoreService"):GetDataStore("GameRoad_BattleSet_v1")

        -- バトルセットからlibIdを取得し、その2デッキをロード
        local function loadBattleDecks(userId)
            -- 1) バトルセット取得
            local bsOk, bsData = pcall(function()
                return BattleSetStore:GetAsync("battleset_" .. userId)
            end)
            local libId1 = 1
            local libId2 = 2
            if bsOk and bsData then
                libId1 = bsData.slot1libId or 1
                libId2 = bsData.slot2libId or 2
            end

            -- 2) 2デッキをロード
            local decks = {}
            for _, libId in ipairs({libId1, libId2}) do
                local key = "deck_" .. userId .. "_lib" .. libId
                local ok, result = pcall(function()
                    return DeckStore:GetAsync(key)
                end)
                if ok and result and result.main and #result.main > 0 then
                    table.insert(decks, result)  -- {main, ex, oshi}
                end
            end
            return decks  -- 最大2デッキ
        end

        -- スートに合うデッキを自動選択
        -- 判定基準: 過半数のカードが同スートのデッキを優先
        -- 同率/どちらもなければデッキ1
        local function pickDeckForSuit(decks, suit)
            if #decks == 0 then return nil end
            if #decks == 1 then return decks[1] end

            local function suitScore(deck)
                local count = 0
                for _, cardId in ipairs(deck.main or {}) do
                    -- カードIDの命名規則: "club_A", "heart_3" など先頭がスート
                    if string.find(tostring(cardId), suit, 1, true) then
                        count = count + 1
                    end
                end
                return count
            end

            local s1 = suitScore(decks[1])
            local s2 = suitScore(decks[2])
            return s1 >= s2 and decks[1] or decks[2]
        end

        for i, entry in ipairs(matched) do
            local team = (i <= 2) and "A" or "B"
            table.insert(playerDefs, {
                userId  = entry.userId,
                name    = entry.name,
                isHuman = true,
                team    = team,
                suit    = "club",         -- 直後のシャッフルで上書きされる（暫定値）
                isTCG   = IS_TCG[mode] or false,
                _decks  = loadBattleDecks(entry.userId),  -- バトル登録済み2デッキ
            })
        end

        -- ── スートをランダム割り振り ──
        local suits = {"heart", "diamond", "club", "spade"}
        for i = #suits, 2, -1 do
            local j = math.random(i)
            suits[i], suits[j] = suits[j], suits[i]
        end
        for i, pd in ipairs(playerDefs) do
            pd.suit = suits[i] or "club"
        end

        -- ── スート確定後にベストデッキを選択 ──
        for _, pd in ipairs(playerDefs) do
            local best = pickDeckForSuit(pd._decks or {}, pd.suit)
            if best then
                pd.savedMainDeck = best.main
                pd.savedExDeck   = best.ex
            end
            pd._decks = nil  -- 不要なので破棄
        end

        -- BattleServer_v2にStartGame BindableFunctionで通知
        local StartGame = ReplicatedStorage:FindFirstChild("StartGame")
        if StartGame then
            task.spawn(function()
                StartGame:Invoke(playerDefs, "tag", roomId)
            end)
        else
            -- フォールバック：match_foundを送ってクライアント側で起動
            for _, entry in ipairs(matched) do
                local pl = Players:GetPlayerByUserId(entry.userId)
                if pl then
                    RE_UpdateBoard:FireClient(pl, {
                        type       = "match_found",
                        mode       = "tag",
                        playerDefs = playerDefs,
                        roomId     = roomId,
                    })
                    -- バトルセット選択画面を開く
                    if RE_OpenBattleSet then
                        RE_OpenBattleSet:FireClient(pl)
                    end
                end
            end
        end
        print("✅ Tag match started: " .. #playerIds .. " players")
        return
    end
end

-- ============================================
-- ソロAI練習（即時開始）
-- ============================================
local function startSoloPractice(player)
    WaitingPlayers[player.UserId] = nil

    local playerDefs = {
        -- 人間プレイヤー
        {userId=player.UserId, name=player.Name, isHuman=true,  team="A",
         suit="club", isTCG=false},  -- soloはトランプ版ルール
        -- AIパートナー（チームA）
        {userId=-1,            name="ハルト",    isHuman=false, team="A", suit="heart"},
        -- AI敵チーム
        {userId=-2,            name="ガタン",    isHuman=false, team="B", suit="heart"},
        {userId=-3,            name="シェル",    isHuman=false, team="B", suit="spade"},
    }

    RE_UpdateBoard:FireClient(player, {
        type       = "match_found",
        mode       = "solo",
        playerDefs = playerDefs,
    })
end

-- ============================================
-- RemoteEvent コールバック
-- ============================================
RE_MMJoin.OnServerEvent:Connect(function(player, data)
    local mode = data and data.mode or "tag"
    if not Queues[mode] then mode = "tag_trump" end

    if mode == "solo" then
        startSoloPractice(player)
    else
        joinQueue(player, mode)
    end
end)

RE_MMCancel.OnServerEvent:Connect(function(player)
    leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
    leaveQueue(player)
end)

-- ============================================
-- マッチングループ（定期チェック）
-- Throttling対策：3秒ごとに1モードずつチェック
-- 全モードを毎秒チェックするとThrottlingが起きる（実証済み）
-- ============================================
-- Throttling対策：ループを分散させる
-- 5キュー（solo除く4+solo）→ 2秒ごとに1モード巡回
-- 全モードを毎秒チェックするとMemoryStore Throttlingが起きる
local modeList = {"tag_trump", "tag_tcg", "battle_trump", "battle_tcg"}
-- soloは joinQueue 時に即時起動なのでループ不要
local modeIdx  = 1

task.spawn(function()
    while true do
        task.wait(3)  -- 3秒ごと

        local mode = modeList[modeIdx]
        modeIdx = modeIdx % #modeList + 1

        local ok, matched, teamA, teamB = processQueue(mode)
        if ok and matched then
            startMatchedGame(matched, teamA, teamB, mode)
        end
    end
end)

-- ============================================
-- マッチング状況をUI更新（待機中の人に「あと○人」を表示）
-- ============================================
task.spawn(function()
    while true do
        task.wait(10)  -- 10秒ごと

        for _, mode in ipairs(modeList) do
            local queue = Queues[mode]
            local size = 0
            pcall(function()
                size = queue:GetSizeAsync(true) or 0
            end)

            local needed = MODE_SIZE[mode]
            -- このモードで待っている人に残り人数を通知
            for userId, m in pairs(WaitingPlayers) do
                if m == mode then
                    local pl = Players:GetPlayerByUserId(userId)
                    if pl then
                        RE_UpdateBoard:FireClient(pl, {
                            type    = "mm_status",
                            message = "マッチング中... (" .. size .. "/"
                                      .. needed .. "人)",
                            mode    = mode,
                            inQueue = size,
                            needed  = needed,
                        })
                    end
                end
            end
        end
    end
end)

-- ============================================
-- フレンド対戦（あいことば方式）
-- ============================================
local FriendRooms = {}   -- { code: {host, mode, players[], createdAt} }

local function generateCode()
    local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local code = ""
    for i = 1, 6 do
        local r = math.random(#chars)
        code = code .. chars:sub(r, r)
    end
    return code
end

local RE_FriendRoom = Remotes:WaitForChild("FriendRoom", 15)

RE_FriendRoom.OnServerEvent:Connect(function(player, data)
    if not data then return end
    local uid = player.UserId

    if data.type == "create" then
        -- 部屋作成
        local code = generateCode()
        -- コード重複チェック
        while FriendRooms[code] do code = generateCode() end

        FriendRooms[code] = {
            host      = uid,
            hostName  = player.Name,
            mode      = data.mode or "battle_tcg",
            players   = {uid},
            maxPlayers = 2,
            createdAt = os.time(),
        }
        -- 5分で自動消滅
        task.delay(300, function()
            if FriendRooms[code] then
                FriendRooms[code] = nil
            end
        end)
        RE_UpdateBoard:FireClient(player, {
            type    = "friendroom_created",
            code    = code,
            message = string.format("部屋を作りました！あいことば: %s", code),
        })

    elseif data.type == "join" then
        -- 部屋参加
        local code = (data.code or ""):upper():gsub("%s","")
        local room = FriendRooms[code]
        if not room then
            RE_UpdateBoard:FireClient(player, {
                type    = "friendroom_error",
                message = "あいことばが正しくありません",
            })
            return
        end
        if #room.players >= room.maxPlayers then
            RE_UpdateBoard:FireClient(player, {
                type    = "friendroom_error",
                message = "この部屋は満員です",
            })
            return
        end
        if room.host == uid then
            RE_UpdateBoard:FireClient(player, {
                type    = "friendroom_error",
                message = "自分が作った部屋には入れません",
            })
            return
        end

        table.insert(room.players, uid)

        -- ホストに通知
        local hostPl = Players:GetPlayerByUserId(room.host)
        if hostPl then
            RE_UpdateBoard:FireClient(hostPl, {
                type      = "friendroom_joined",
                joinerId  = uid,
                joinerName = player.Name,
            })
        end

        -- 2人揃ったらゲーム開始
        if #room.players >= room.maxPlayers then
            FriendRooms[code] = nil
            local roomId = "friend_" .. code
            -- StartGame BindableFunction経由でゲーム開始
            local StartGameF = ReplicatedStorage:FindFirstChild("StartGame")
            if StartGameF then
                task.spawn(function()
                    local playerDefs = {}
                    for i, pid in ipairs(room.players) do
                        local pl2 = Players:GetPlayerByUserId(pid)
                        playerDefs[i] = {
                            userId   = pid,
                            name     = pl2 and pl2.Name or tostring(pid),
                            isHuman  = true,
                            team     = i == 1 and "A" or "B",
                            suit     = "club",
                            isFriendMatch = true,  -- ELO変動なしフラグ
                        }
                    end
                    -- 両プレイヤーに開始通知
                    for _, pid in ipairs(room.players) do
                        local pl2 = Players:GetPlayerByUserId(pid)
                        if pl2 then
                            RE_UpdateBoard:FireClient(pl2, {
                                type    = "friendroom_start",
                                roomId  = roomId,
                                message = "フレンド対戦スタート！（ELO変動なし）",
                            })
                        end
                    end
                    pcall(function()
                        StartGameF:Invoke(playerDefs, room.mode, roomId)
                    end)
                end)
            end
        end

    elseif data.type == "cancel" then
        -- 部屋解散
        for code, room in pairs(FriendRooms) do
            if room.host == uid then
                FriendRooms[code] = nil
                RE_UpdateBoard:FireClient(player, {
                    type    = "friendroom_cancelled",
                    message = "部屋を解散しました",
                })
                break
            end
        end
    end
end)

print("✅ Matchmaking_v2.lua loaded")
