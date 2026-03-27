-- ============================================
-- GAMEROAD PartnerComfort.lua
-- ServerScriptService/ に配置（Script型）
--
-- 設計思想：
--   ・敗北演出は一切ない。負けた瞬間に即カット。
--   ・パートナーが「今日良かったこと」だけを拾って褒める。
--   ・ストレス要素を全て「パートナーとの時間」に変換する。
--   ・課金導線は出さない。ショップはプレイヤーが自分で開く。
-- ============================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")

local Remotes        = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_UpdateBoard = Remotes:WaitForChild("UpdateBoard", 15)
local RE_Comfort     = Remotes:WaitForChild("PartnerComfort", 15)

-- ============================================
-- 褒めセリフバンク
-- ────────────────────────────────────────────
-- 全て「良かったこと」しか言わない。
-- ネガティブワード（負け・ダメ・失敗）を完全排除。
-- ============================================

local PRAISE_GENERAL = {
    "今日もちゃんとやってたじゃん。えらいえらい",
    "最後まで戦い抜いた。それだけで十分すごいよ",
    "毎日コツコツ来てくれてありがとう。うれしい",
    "また来てくれたね。待ってたよ",
    "ゆっくりで大丈夫。一緒にやっていこう",
    "今日も一緒にいられてよかった",
}

local PRAISE_BY_STAT = {
    highRoad    = "ロードで高いカード出せてたね！あの読み、よかった",
    column6     = "あと一歩まで積み上げてた。めちゃくちゃ惜しかった",
    arcanaUsed  = "アルカナ使ってたじゃん。どんどん上手くなってる",
    chipsMany   = "チップをたくさん溜められてたよ。戦略が分かってきてる証拠",
    longBattle  = "長い試合、最後まで諦めなかったね。かっこよかった",
    goodTarget  = "ターゲット選び上手かった。ちゃんと考えてるのが伝わった",
    firstGame   = "今日最初の一戦。来てくれただけで嬉しいよ",
    playedMany  = "今日たくさんやってくれたね。一緒にいられて楽しかった",
}

local PRAISE_TIME = {
    -- 時間帯別（サーバー時刻UTCから推定）
    morning = "朝から来てくれたんだ。今日一日、一緒に頑張ろうね",
    noon    = "お昼に会えてよかった。少し休みながらやろうね",
    night   = "夜遅くまでありがとう。無理しないでね",
}

-- ============================================
-- 試合結果を解析して「良かったこと」だけ抽出
-- ============================================
local function extractGoodThings(stats)
    local goods = {}

    if stats.maxRoadRank and stats.maxRoadRank >= 10 then
        table.insert(goods, PRAISE_BY_STAT.highRoad)
    end
    if stats.maxColLength and stats.maxColLength >= 6 then
        table.insert(goods, PRAISE_BY_STAT.column6)
    end
    if stats.arcanaCount and stats.arcanaCount >= 1 then
        table.insert(goods, PRAISE_BY_STAT.arcanaUsed)
    end
    if stats.totalChips and stats.totalChips >= 8 then
        table.insert(goods, PRAISE_BY_STAT.chipsMany)
    end
    if stats.turns and stats.turns >= 12 then
        table.insert(goods, PRAISE_BY_STAT.longBattle)
    end
    if stats.isFirstGameToday then
        table.insert(goods, PRAISE_BY_STAT.firstGame)
    end
    if stats.gamesPlayedToday and stats.gamesPlayedToday >= 5 then
        table.insert(goods, PRAISE_BY_STAT.playedMany)
    end

    -- 何も特筆することがなければ汎用褒め
    if #goods == 0 then
        local idx = math.random(#PRAISE_GENERAL)
        table.insert(goods, PRAISE_GENERAL[idx])
    end

    -- 最大2つまで
    while #goods > 2 do table.remove(goods, math.random(#goods)) end

    return goods
end

-- ============================================
-- 時間帯別あいさつ
-- ============================================
local function getTimeGreeting()
    local hour = tonumber(os.date("!%H"))  -- UTC
    -- 日本時間に近似（UTC+9）
    local jst = (hour + 9) % 24
    if jst >= 5 and jst < 12 then
        return PRAISE_TIME.morning
    elseif jst >= 12 and jst < 18 then
        return PRAISE_TIME.noon
    else
        return PRAISE_TIME.night
    end
end

-- ============================================
-- セッション単位の統計トラッカー
-- ============================================
local PlayerStats = {}  -- userId -> stats

local function getStats(userId)
    if not PlayerStats[userId] then
        PlayerStats[userId] = {
            gamesPlayedToday = 0,
            isFirstGameToday = true,
            maxRoadRank      = 0,
            maxColLength     = 0,
            arcanaCount      = 0,
            totalChips       = 0,
            turns            = 0,
        }
    end
    return PlayerStats[userId]
end

-- ============================================
-- 試合終了時に呼ばれる（BattleServerから）
-- isWin に関わらず同じ処理（勝敗は出さない）
-- ============================================
local function onBattleEnd(player, resultData)
    local stats = getStats(player.UserId)

    -- 統計を更新
    stats.gamesPlayedToday = stats.gamesPlayedToday + 1
    if resultData.maxRoadRank then
        stats.maxRoadRank = math.max(stats.maxRoadRank, resultData.maxRoadRank)
    end
    if resultData.maxColLength then
        stats.maxColLength = math.max(stats.maxColLength, resultData.maxColLength)
    end
    stats.arcanaCount = stats.arcanaCount + (resultData.arcanaUsed or 0)
    stats.totalChips  = stats.totalChips  + (resultData.chipsGained or 0)
    stats.turns       = resultData.turns or 0

    -- 良かったことリスト生成
    local goods = extractGoodThings(stats)
    stats.isFirstGameToday = false

    -- 即座にクライアントへ送信（敗北画面より先に届く）
    RE_Comfort:FireClient(player, {
        type     = "battle_end_comfort",
        lines    = goods,
        isWin    = resultData.isWin,  -- クライアントで勝利時だけ追加演出
        greeting = stats.gamesPlayedToday == 1 and getTimeGreeting() or nil,
    })
end

-- ============================================
-- ロード中のパートナーコメント（クライアントが要求）
-- ============================================
local LOADING_COMMENTS = {
    "ちょっと待っててね",
    "もうすぐだよ",
    "待たせてごめんね",
    "今日もよろしくね",
    "一緒に行こう",
    "準備できたら教えるね",
}

RE_Comfort.OnServerEvent:Connect(function(player, data)
    if data.type == "loading_comment_request" then
        local idx = math.random(#LOADING_COMMENTS)
        RE_Comfort:FireClient(player, {
            type    = "loading_comment",
            text    = LOADING_COMMENTS[idx],
        })
    end
end)

-- ============================================
-- BindableFunction：BattleServerから呼ぶ
-- ============================================
local ComfortFunc = Instance.new("BindableFunction")
ComfortFunc.Name  = "NotifyBattleEnd"
ComfortFunc.Parent = ReplicatedStorage
ComfortFunc.OnInvoke = function(player, resultData)
    onBattleEnd(player, resultData)
end

Players.PlayerRemoving:Connect(function(player)
    PlayerStats[player.UserId] = nil
end)

print("✅ PartnerComfort.lua loaded")
