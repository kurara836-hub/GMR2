-- ============================================
-- GAMEROAD PartnerSystem_v2.lua
-- ServerScriptService/ に配置（Script型）
-- 
-- 設計思想：
--   Adopt Me! の「ペットとの絆」をカードゲームのパートナーに転用
--   子供が「育てたい・返ってきたい」と思う感情ループを作る
--   リプレイ学習でパートナーが実際に賢くなる → 成長が見える
-- ============================================

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes       = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_UpdateBoard = Remotes:WaitForChild("UpdateBoard", 15)
local RE_ReplayChoice = Remotes:WaitForChild("SaveReplayChoice", 15)

local PartnerStore   = DataStoreService:GetDataStore("PartnerData_v1")
local ReplayStore    = DataStoreService:GetDataStore("ReplayData_v1")

-- ============================================
-- パートナーマスターデータ
-- （ガチャシステムと同じIDリストと一致させる）
-- ============================================
local PARTNER_MASTERS = {
    ["haruto_default"] = {
        name        = "ハルト",
        suit        = "heart",
        personality = "warm",   -- warm / cool / cheerful / serious
        baseAdvice  = {
            road    = {"ロードはこれでいこう！", "高いカードを使おう", "勝ちに行くぞ！"},
            battle  = {"これで決める！", "バトルカードはこれだ", "勝てる！"},
            win     = {"やった！", "完璧だ！", "そうそう！"},
            lose    = {"くっ…", "次は勝つ！", "諦めるな！"},
            chip    = {"チップを溜めよう", "まだ勝負できる"},
            pity    = {"天井が近い！", "もう少し！"},
        },
        levelPhrases = {
            [1]  = "よろしく！一緒に頑張ろう！",
            [5]  = "だいぶ慣れてきたな…！",
            [10] = "お前のことなら何でもわかるぞ。",
        },
    },
    ["shell_default"] = {
        name        = "シェル",
        suit        = "spade",
        personality = "cool",
        baseAdvice  = {
            road    = {"…これを出す", "計算上、最適", "ロードはこれで"},
            battle  = {"バトル。これで決まる", "最適解", "勝率は高い"},
            win     = {"…想定内", "予測通り", "まあ、こんなものか"},
            lose    = {"想定外だ…", "次は修正する", "…},"},
            chip    = {"チップ管理が重要", "温存"},
            pity    = {"天井計算済み", "もうすぐだ"},
        },
        levelPhrases = {
            [1]  = "…よろしく。余計なことは言わない。",
            [5]  = "…悪くない組み合わせだ。",
            [10] = "…認める。お前は信頼できる。",
        },
    },
    ["kabu_default"] = {
        name        = "カブー",
        suit        = "club",
        personality = "cheerful",
        baseAdvice  = {
            road    = {"よっしゃこれだ！", "これでいくぜ！", "任せろ！"},
            battle  = {"ぶちかませ！", "これだ！", "勝つぞ！"},
            win     = {"やったー！！", "最高！", "無敵！"},
            lose    = {"うぐっ…", "なんで！？", "もう一回！"},
            chip    = {"チップ増えてきた！", "溜まってきたぞ"},
            pity    = {"もうすぐSSR来る！！", "天井近い！来い！"},
        },
        levelPhrases = {
            [1]  = "オッス！よろしくな！全力でいくぜ！",
            [5]  = "お前となら何でもできる気がする！",
            [10] = "ずっと一緒に戦ってきたな！最強コンビだ！",
        },
        -- ━━ 相方AIデッキ（チップ溜め→一気に勝つスタイル）━━
        defaultMainDeck = {
            "club_K","club_K","club_K",
            "club_Q","club_Q",
            "club_J","club_J",
            "club_r12a","club_r5","club_r1",
            "club_10","club_10","club_9","club_9",
            "club_8","club_7","club_7","club_6",
            "club_5","club_5","club_4","club_3",
            "club_2","club_1","club_1",
            "common_joker1","common_ace","common_draw2",
            "common_mirror","common_wild",
        },
        defaultExDeck = {},
    },
}

-- ============================================
-- デフォルトパートナーデータ
-- ============================================
local function defaultPartnerData(skinId)
    return {
        skinId      = skinId or "kabu_default",
        level       = 1,
        exp         = 0,
        bond        = 0,          -- 絆値（感情軸）
        totalGames  = 0,
        wins        = 0,
        -- リプレイ学習データ
        learnedMoves = {},        -- {situation -> best_choice} の辞書
        -- パートナーの状態
        mood        = "normal",   -- normal / happy / sleepy / excited
        lastPlayTime = 0,
    }
end

-- ============================================
-- パートナーデータの読み書き
-- ============================================
local PartnerCache = {}

local function loadPartner(player)
    local key = "partner_" .. player.UserId
    local ok, data = pcall(function()
        return PartnerStore:GetAsync(key)
    end)
    if ok and data then
        PartnerCache[player.UserId] = data
    else
        PartnerCache[player.UserId] = defaultPartnerData("kabu_default")
    end
    return PartnerCache[player.UserId]
end

local function savePartner(player)
    local data = PartnerCache[player.UserId]
    if not data then return end
    local key = "partner_" .. player.UserId
    pcall(function()
        PartnerStore:SetAsync(key, data)
    end)
end

-- ============================================
-- EXP・レベルアップ計算
-- ============================================
local function expForLevel(lv)
    return lv * lv * 100  -- Lv1→2: 100 / Lv9→10: 9000
end

local function addExp(partnerData, amount)
    partnerData.exp = (partnerData.exp or 0) + amount
    local leveled = false
    while partnerData.level < 10 and
          partnerData.exp >= expForLevel(partnerData.level) do
        partnerData.exp = partnerData.exp - expForLevel(partnerData.level)
        partnerData.level = partnerData.level + 1
        leveled = true
    end
    return leveled
end

-- ============================================
-- 絆値・ムード更新
-- ============================================
local MOOD_THRESHOLD = {
    excited = 80,
    happy   = 40,
    normal  = 0,
    sleepy  = -20,  -- 長時間未プレイで発生
}

local function updateMood(partnerData)
    local bond = partnerData.bond or 0
    local now  = os.time()
    local last = partnerData.lastPlayTime or 0
    local hoursSince = (now - last) / 3600

    -- 72時間以上プレイしてないと眠い
    if hoursSince > 72 then
        partnerData.mood = "sleepy"
    elseif bond >= MOOD_THRESHOLD.excited then
        partnerData.mood = "excited"
    elseif bond >= MOOD_THRESHOLD.happy then
        partnerData.mood = "happy"
    else
        partnerData.mood = "normal"
    end
end

-- ============================================
-- アドバイス生成（Lv依存 + リプレイ学習）
-- ============================================
local function generateAdvice(partnerData, context)
    -- context = {phase, boardState, handCards, enemyChips, ...}
    local master = PARTNER_MASTERS[partnerData.skinId]
               or PARTNER_MASTERS["kabu_default"]
    local phase = context.phase or "road"

    -- Lv1-3: 基本アドバイスのみ
    if partnerData.level <= 3 then
        local lines = master.baseAdvice[phase] or {"考え中..."}
        return lines[math.random(#lines)]
    end

    -- Lv4-6: 盤面情報を加味
    if partnerData.level <= 6 then
        local baseLines = master.baseAdvice[phase] or {""}
        local base = baseLines[math.random(#baseLines)]

        -- 追加情報
        if context.myChips and context.myChips >= 4 then
            base = base .. "（チップを活かせる！）"
        end
        if context.maxCol and context.maxCol >= 5 then
            base = base .. "（あと少しで7枚！）"
        end
        return base
    end

    -- Lv7-9: 戦略的敗北の判断
    if partnerData.level <= 9 then
        -- 相手の方が圧倒的に有利なら「あえて負ける」提案
        local enemyMax = context.enemyMaxCol or 0
        local myMax    = context.myMaxCol or 0
        if enemyMax <= 2 and myMax >= 4 then
            return "【ドレイン戦略】あえて弱いカードで負けて敵の手を使わせよう"
        end
        local lines = master.baseAdvice[phase] or {""}
        return lines[math.random(#lines)] .. "（Lv" .. partnerData.level .. "判断）"
    end

    -- Lv10: リプレイ学習から最適アドバイス
    local learnedMoves = partnerData.learnedMoves or {}
    local situation = phase .. "_" .. tostring(context.myChips or 0)
                   .. "_" .. tostring(context.enemyMaxCol or 0)

    if learnedMoves[situation] then
        return "【学習済み】" .. learnedMoves[situation]
    end

    -- フルコンビ戦ロジック（コンビ戦チャット用プログラム準拠）
    local advice = ""
    if phase == "road" then
        if (context.myChips or 0) >= 4 and (context.myMaxCol or 0) >= 4 then
            advice = "【露払い】高いカードで一気に決める！"
        elseif (context.enemyMaxCol or 0) >= 6 then
            advice = "【緊急】相手が天井目前！全力で止める！"
        else
            advice = "【高度推察】相手の手札を逆算中... 中間値を出せ"
        end
    elseif phase == "battle" then
        advice = "【カードカウンティング】残り高ランク:" ..
                 tostring(context.highCardsLeft or "?") .. "枚"
    end

    return advice ~= "" and advice or
           (master.baseAdvice[phase] or {""})[1]
end

-- ============================================
-- ゲーム結果を記録 → EXP付与 → 絆値更新
-- ============================================
local function recordGameResult(player, result)
    -- result = {won, turns, myMaxCol, partnerActions}
    local data = PartnerCache[player.UserId]
    if not data then return end

    data.totalGames = (data.totalGames or 0) + 1
    data.lastPlayTime = os.time()

    -- EXP計算
    local expGain = 50  -- 基本
    if result.won     then expGain = expGain + 100 end
    if result.turns and result.turns >= 10 then expGain = expGain + 30 end
    if result.myMaxCol and result.myMaxCol >= 6 then expGain = expGain + 20 end

    local leveled = addExp(data, expGain)

    -- 絆値
    local bondGain = result.won and 10 or 3
    data.bond = math.min((data.bond or 0) + bondGain, 100)

    updateMood(data)

    -- 通知内容を構築
    local notif = {
        type     = "partner_update",
        expGain  = expGain,
        leveled  = leveled,
        newLevel = data.level,
        bond     = data.bond,
        mood     = data.mood,
        skinId   = data.skinId,
    }

    -- レベルアップセリフ
    if leveled then
        local master = PARTNER_MASTERS[data.skinId]
                    or PARTNER_MASTERS["kabu_default"]
        local phrase = master.levelPhrases[data.level]
        if phrase then notif.levelPhrase = phrase end
        data.wins = result.won and (data.wins or 0) + 1 or (data.wins or 0)
    end

    savePartner(player)

    local pl = Players:GetPlayerByUserId(player.UserId)
    if pl then
        RE_UpdateBoard:FireClient(pl, notif)
    end
end

-- ============================================
-- リプレイ学習処理（プレミ登録 + 良い選択の両対応）
-- ============================================
RE_ReplayChoice.OnServerEvent:Connect(function(player, data)
    -- data = {turn, situation, choice, wasGood, roadCard, battleCard}
    local partnerData = PartnerCache[player.UserId]
    if not partnerData then return end

    if not partnerData.learnedMoves then
        partnerData.learnedMoves = {}
    end

    local key = data.situation or ("turn_" .. tostring(data.turn))

    if data.wasGood then
        -- 良い選択として記録
        partnerData.learnedMoves[key] = {
            choice    = data.choice or "良い選択",
            isGood    = true,
            roadRank  = data.roadCard  and data.roadCard.rank  or nil,
            battleRank = data.battleCard and data.battleCard.rank or nil,
        }
        addExp(partnerData, 10)
    else
        -- プレミ登録 → 「次回この状況ではやめよう」として記録
        partnerData.learnedMoves[key] = {
            choice    = data.choice or "不明な行動",
            isGood    = false,  -- やってはいけない行動
            roadRank  = data.roadCard  and data.roadCard.rank  or nil,
            battleRank = data.battleCard and data.battleCard.rank or nil,
        }
        addExp(partnerData, 5)  -- プレミ登録にも少し経験値
    end

    savePartner(player)

    local pl = Players:GetPlayerByUserId(player.UserId)
    if pl then
        RE_UpdateBoard:FireClient(pl, {
            type      = "replay_learned",
            situation = key,
            wasGood   = data.wasGood,
            exp       = data.wasGood and 10 or 5,
        })
    end
end)

-- ============================================
-- バトル中の状況マッチングアドバイス
-- （BattleServerからBindableEventで呼ばれる）
-- 呼び方: PartnerAdviceEvent:Fire(userId, situation, chipCount, turn)
-- ============================================
local PartnerAdviceEvent = Instance.new("BindableEvent")
PartnerAdviceEvent.Name   = "PartnerAdviceEvent"
PartnerAdviceEvent.Parent = ReplicatedStorage

PartnerAdviceEvent.Event:Connect(function(userId, situation, chipCount, turnNum)
    local partnerData = PartnerCache[userId]
    if not partnerData or not partnerData.learnedMoves then return end

    local learned = partnerData.learnedMoves[situation]
    if not learned then return end

    local pl = Players:GetPlayerByUserId(userId)
    if not pl then return end

    local master = PARTNER_MASTERS[partnerData.skinId]
             or PARTNER_MASTERS["kabu_default"]

    local msg, adviceType
    if learned.isGood == false then
        -- 「この状況でそれはプレミだよ」
        msg = string.format("気をつけて！前に%sでうまくいかなかったよ",
            situation == "road_high"   and "ロードを出しすぎた時"
         or situation == "road_low"    and "ロードが低すぎた時"
         or situation == "battle_miss" and "バトルカードを選んだ時"
         or situation == "chip_waste"  and "チップが多かった時"
         or situation == "col_miss"    and "列を狙った時"
         or "似た状況")
        adviceType = "danger"
    else
        -- 「この状況ではこれが正解」
        local partnerName = master.name or "相方"
        msg = string.format("%sが前に覚えたやつ！" ..
            (learned.roadRank and " ロード%dが良さそう" or "") ..
            "行けるよ！",
            partnerName,
            learned.roadRank or 0)
        adviceType = "learned"
    end

    RE_UpdateBoard:FireClient(pl, {
        type       = "partner_advice",
        message    = msg,
        adviceType = adviceType,
    })
end)

-- ============================================
-- 相方AIデッキをMatchmakingに提供する関数
-- Matchmaking_v2 から require して使う
-- ============================================
local function GetPartnerDeck(skinId, suit)
    local master = PARTNER_MASTERS[skinId] or PARTNER_MASTERS["kabu_default"]
    -- スートが一致するパートナーのデッキを探す
    for _, m in pairs(PARTNER_MASTERS) do
        if m.suit == suit and m.defaultMainDeck then
            return m.defaultMainDeck, m.defaultExDeck or {}
        end
    end
    return master.defaultMainDeck or {}, master.defaultExDeck or {}
end

-- ReplicatedStorageにBindableFunction経由で公開
local GetPartnerDeckFunc = Instance.new("BindableFunction")
GetPartnerDeckFunc.Name   = "GetPartnerDeck"
GetPartnerDeckFunc.Parent = ReplicatedStorage
GetPartnerDeckFunc.OnInvoke = function(skinId, suit)
    return GetPartnerDeck(skinId, suit)
end

-- ============================================
-- プレイヤー入退室
-- ============================================
Players.PlayerAdded:Connect(function(player)
    local data = loadPartner(player)
    updateMood(data)

    -- 接続時にパートナー情報を送信
    task.wait(2)
    local pl = Players:GetPlayerByUserId(player.UserId)
    if pl then
        local master = PARTNER_MASTERS[data.skinId]
                    or PARTNER_MASTERS["kabu_default"]

        -- 眠っていたパートナーの「起こす」演出
        local greeting = ""
        if data.mood == "sleepy" then
            greeting = "…ん…？戻ってきたのか…！よかった…"
            data.mood = "happy"
            data.bond = math.min((data.bond or 0) + 5, 100)
            savePartner(player)
        elseif data.mood == "excited" then
            greeting = master.levelPhrases[data.level] or "また来たな！一緒にやろう！"
        else
            greeting = "準備完了！"
        end

        RE_UpdateBoard:FireClient(pl, {
            type      = "partner_info",
            skinId    = data.skinId,
            name      = master.name,
            level     = data.level,
            exp       = data.exp,
            expNext   = expForLevel(data.level),
            bond      = data.bond,
            mood      = data.mood,
            greeting  = greeting,
            wins      = data.wins,
            totalGames= data.totalGames,
        })
    end
end)

Players.PlayerRemoving:Connect(function(player)
    savePartner(player)
    PartnerCache[player.UserId] = nil
end)

-- ============================================
-- 外部公開（BattleServerと連携するためのBindableFunction）
-- ============================================
local AdviceFunc = Instance.new("BindableFunction")
AdviceFunc.Name  = "GetPartnerAdvice"
AdviceFunc.Parent = ReplicatedStorage

AdviceFunc.OnInvoke = function(userId, context)
    local data = PartnerCache[userId]
    if not data then return "準備中..." end
    return generateAdvice(data, context)
end

local ResultFunc = Instance.new("BindableFunction")
ResultFunc.Name  = "RecordGameResult"
ResultFunc.Parent = ReplicatedStorage

ResultFunc.OnInvoke = function(player, result)
    recordGameResult(player, result)
end

-- 定期オートセーブ
task.spawn(function()
    while true do
        task.wait(300)
        for _, player in ipairs(Players:GetPlayers()) do
            savePartner(player)
        end
    end
end)

print("✅ PartnerSystem_v2.lua loaded")
