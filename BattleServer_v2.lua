-- ============================================
-- GAMEROAD BattleServer v2  (最終版)
-- 修正点：
--   1. 非同期フロー → コルーチン+状態機械
--   2. カードID衝突 → カウンター式
--   3. players二重インデックス → playerList/playerMap分離
--   4. SecurityValidator統合
--   5. CombiLogic統合（コンビ戦ドレイン・露払い・情報共有）
-- ============================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local DeckStore         = DataStoreService:GetDataStore("GameRoad_Decks_v1")

-- SecurityValidatorをrequire
local Security = nil
local secModule = ReplicatedStorage:FindFirstChild("SecurityValidator")
if secModule then
    local ok, result = pcall(require, secModule)
    if ok then Security = result end
end
if not Security then
    Security = {
        checkRateLimit    = function() return true end,
        validateCardInHand = function() return true end,
        recordViolation   = function() end,
    }
end

-- CombiLogicをrequire（コンビ戦AI強化）
local CombiLogic = nil
local combiModule = ReplicatedStorage:FindFirstChild("CombiLogic")
if combiModule then
    local ok, result = pcall(require, combiModule)
    if ok then CombiLogic = result end
end
-- フォールバック（CombiLogicがない場合は基本動作）
if not CombiLogic then
    CombiLogic = {
        assignRoles         = function() return "free","free" end,
        shouldDrain         = function() return false end,
        shouldPathclear     = function() return false end,
        aiPickRoad          = function(_, player) 
            local h = player.hand
            if #h == 0 then return nil end
            return h[math.random(#h)]
        end,
        aiPickBattle        = function(_, player)
            local h = player.hand
            if #h == 0 then return nil end
            return h[1]
        end,
        buildConsultMessage = function() return {navigator="", partner=""} end,
        buildTeamInfo       = function() return {} end,
        estimateHighCards   = function() return 0 end,
    }
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_RoadSelect    = Remotes:WaitForChild("RoadSelect", 15)
local RE_BattleSelect  = Remotes:WaitForChild("BattleSelect", 15)
local RE_ArcanaSelect  = Remotes:WaitForChild("ArcanaSelect", 15)
local RE_TargetSelect  = Remotes:WaitForChild("TargetSelect", 15)
local RE_UpdateBoard   = Remotes:WaitForChild("UpdateBoard", 15)
local RE_GameOver      = Remotes:WaitForChild("GameOver", 15)
local RE_PartnerAdvice = Remotes:WaitForChild("PartnerAdvice", 15)

-- PartnerSystem の学習アドバイス（BindableEvent 経由）
-- PartnerSystem_v2 が ReplicatedStorage に "PartnerAdviceEvent" を作るのを待つ
local PartnerAdviceBindable = ReplicatedStorage:WaitForChild("PartnerAdviceEvent", 10)

-- ============================================
-- カードID生成（バグ2修正：カウンター式）
-- ============================================
local _cardIdCounter = 0
local function newCardId()
    _cardIdCounter = _cardIdCounter + 1
    return _cardIdCounter
end

local SUITS = {"heart", "diamond", "club", "spade"}

-- CardDataをrequire（TCG版デッキ生成に使用）
local CardDataModule = require(ReplicatedStorage:WaitForChild("CardData", 15))
local ArcanaSystem   = require(ReplicatedStorage:WaitForChild("ArcanaSystem", 15))

-- buildDeck: trump版は52枚固定 / TCG版はCardData経由
local function buildDeck(suit, isTCG)
    return CardDataModule.buildDeck(suit or "club", isTCG and "tcg" or "trump")
end

local function buildEXDeck(suit)
    return CardDataModule.buildEXDeck(suit or "club", "tcg")
end

local function rankStr(r)
    if r == 1 then return "A" elseif r == 11 then return "J"
    elseif r == 12 then return "Q" elseif r == 13 then return "K"
    else return tostring(r) end
end

-- ============================================
-- プレイヤー構造体
-- ============================================
local function makePlayer(userId, name, isHuman, team, suit, skin)
    return {
        id         = userId,
        name       = name,
        isHuman    = isHuman,
        isAI       = not isHuman,
        team       = team,
        suit       = suit or "club",
        partnerSkin= skin or "default",
        hand       = {},
        shields    = {},
        chips      = {},
        columns    = {{}, {}, {}},
        arcana     = {},
        arcanaUsed = {},
        graveyard  = {},  -- 除去されたカードの墓地（将来の墓地参照カード用）
        -- EXゾーン（ハルニアの鼓動・蜜カード・EXトリガー）
        -- 各要素: {id=string, name=string, rank=number, effect=string}
        ex         = {},
        -- ハルニア専用フラグ
        isHalnia   = false,  -- createGameState時にsuit=="heart"なら true
        defeated   = false,
    }
end

-- ============================================
-- ゲーム状態（バグ3修正：playerList/playerMap分離）
-- ============================================
local function createGameState(playerDefs, mode)
    -- playerDefsの最初の1人からisTCGとsuitを取る
    local isTCG = false
    local suit1 = "club"
    if playerDefs and playerDefs[1] then
        isTCG = playerDefs[1].isTCG or false
        suit1 = playerDefs[1].suit or "club"
    end
    local deck = buildDeck(suit1, isTCG)
    local gs = {
        mode       = mode,
        isTCG      = isTCG,
        playerList = {},   -- 順番アクセス用（配列）
        playerMap  = {},   -- ID→プレイヤー（辞書）
        deck       = deck,
        -- バトル状態
        phase      = "road",  -- road/battle/arcana/target/result
        road       = {},
        battle     = {},
        arcanaBonus= {},
        roadOverride = {},
        extraBattle  = {},
        cancelStack  = {},
        activeId   = nil,
        defId      = nil,
        targetShieldIdx = nil,
        roadOnly   = false,
        amberUser  = nil,
        archeoDouble = nil,
        justiceUser  = nil,
        turn       = 0,
        victory    = nil,
        _stats     = {},  -- userId -> {road,col,arcana,chips}
        -- 入力待ち管理（状態機械の核心）
        pendingInputs = {},  -- {[userId] = bool}
        -- リプレイ
        replayData = {},
    }

    -- EXデッキ定義（TCG版のみ使用）
    -- ハルニアの鼓動は heart スートの場合に自動セット
    local EX_TEMPLATES = {
        -- ハルニア EXライフカード（効果で除去されるライフ）
        harnia_kodou = {id="harnia_kodou", name="ハルニアの鼓動", rank=0,
            effect="ex_life",
            deckLimit=1,  -- カードテキスト制限: EXデッキに1枚まで（ゲーム開始時に必ず1枚配置）
            desc="[EX・必須] heartスート専用。シールドが攻撃されるたびに鼓動カードを1枚消費。0枚で敗北。",
            suit="heart"},
        -- 蜜カード（クラディオン向け・EXに貯まる特殊トークン）
        honey_token  = {id="honey_token",  name="蜜",            rank=0,
            effect="honey",      -- バトル時に消費→パワー+1/枚
            suit="club"},
        -- ハルニア 鼓動カード（全部ただのライフ。追加効果なし）
        -- デッキ構築でプレイヤーが何枚積むか決める（最大7枚-1枚=6枚）
        ex_trig_fire = {id="ex_trig_fire", name="ハルニアの鼓動・炎",  rank=0,
            effect="ex_life", suit="heart"},
        ex_trig_soul = {id="ex_trig_soul", name="ハルニアの鼓動・魂",  rank=0,
            effect="ex_life", suit="heart"},
        ex_trig_pass = {id="ex_trig_pass", name="ハルニアの鼓動・情熱",rank=0,
            effect="ex_life", suit="heart"},
        ex_trig_undy = {id="ex_trig_undy", name="ハルニアの鼓動・不屈",rank=0,
            effect="ex_life", suit="heart"},

        -- ─ ファントムコーデカード（ダイアモンドスート用）─
        -- アイドルカード効果「EXからまだ装着していない部位のコーデを呼ぶ」で発動
        -- deckLimit=1: このカードはEXデッキに1枚まで（カード側テキスト制限）
        coord_tops   = {id="coord_tops",   name="コーデ：トップス",   rank=0,
            effect="coord",  part="tops",   deckLimit=1,
            desc="[EX] アイドルカード効果で装着。装着時: このターンのバトル+3",
            suit="diamond"},
        coord_bottoms = {id="coord_bottoms", name="コーデ：ボトムス", rank=0,
            effect="coord",  part="bottoms", deckLimit=1,
            desc="[EX] アイドルカード効果で装着。装着時: チップになった時1枚引く",
            suit="diamond"},
        coord_shoes  = {id="coord_shoes",  name="コーデ：シューズ",   rank=0,
            effect="coord",  part="shoes",  deckLimit=1,
            desc="[EX] アイドルカード効果で装着。装着時: このターンロードランク+2",
            suit="diamond"},
        coord_acc    = {id="coord_acc",    name="コーデ：アクセ",     rank=0,
            effect="coord",  part="acc",    deckLimit=1,
            desc="[EX] アイドルカード効果で装着。装着時: アルカナボーナス+2",
            suit="diamond"},
    }

    local di = 1
    for i, def in ipairs(playerDefs) do
        local p = makePlayer(def.userId, def.name, def.isHuman,
                             def.team, def.suit, def.skin)

        -- プレイヤー個別デッキ（保存済みがあればそれを使う）
        local playerDeck
        if gs.isTCG and def.savedMainDeck and #def.savedMainDeck > 0 then
            -- 保存カードIDをCardDataで解決してデッキ生成
            playerDeck = {}
            for _, cardId in ipairs(def.savedMainDeck) do
                local card = CardDataModule.getCardById(cardId)
                if card then table.insert(playerDeck, card) end
            end
            -- 足りない場合はデフォルトで補完
            if #playerDeck < 20 then
                local defaults = CardDataModule.buildDeck(def.suit, "tcg")
                for _, c in ipairs(defaults) do
                    table.insert(playerDeck, c)
                    if #playerDeck >= 30 then break end
                end
            end
        else
            -- デフォルト（トランプ版 or デッキ未保存）
            playerDeck = CardDataModule.buildDeck(def.suit or "club",
                           gs.isTCG and "tcg" or "trump")
        end
        -- シャッフル
        for k = #playerDeck, 2, -1 do
            local j = math.random(1, k)
            playerDeck[k], playerDeck[j] = playerDeck[j], playerDeck[k]
        end

        -- 手札3枚・シールド3枚
        for _ = 1, 3 do
            local c = table.remove(playerDeck, 1)
            if c then table.insert(p.hand, c) end
        end
        for _ = 1, 3 do
            local c = table.remove(playerDeck, 1)
            if c then table.insert(p.shields, c) end
        end
        p._deck = playerDeck  -- 残りを各自で保持

        -- アルカナデッキ生成（各プレイヤー個別）
        p.arcana     = ArcanaSystem.buildArcana()
        p.arcanaUsed = {}

        -- TCG版のみEXゾーンをセットアップ
        if gs.isTCG then
            if def.suit == "heart" then
                -- ハルニア: EXに「ハルニアの鼓動」+トリガー4枚を自動セット
                p.isHalnia = true
                table.insert(p.ex, EX_TEMPLATES.harnia_kodou)
                -- def.exCards があれば使う（カスタムデッキ対応）
                -- なければデフォルトトリガーセット
                local triggers = def.exCards or {
                    "ex_trig_fire", "ex_trig_soul", "ex_trig_pass",
                    "ex_trig_undy", "ex_trig_soul", "ex_trig_fire",
                }
                for _, tid in ipairs(triggers) do
                    if EX_TEMPLATES[tid] then
                        table.insert(p.ex, EX_TEMPLATES[tid])
                    end
                end
            end
            -- 蜜カードは効果で追加されるのでここでは追加しない
        -- ファントムコーデ：アイドルカード効果でEXから呼ばれる
        elseif def.suit == "diamond" then
            -- ダイアモンドスートはコーデカード持ち（EXに積んでおく）
            local coordCards = def.exCards or {}
            for _, cid in ipairs(coordCards) do
                if EX_TEMPLATES[cid] then
                    table.insert(p.ex, EX_TEMPLATES[cid])
                end
            end
        end

        table.insert(gs.playerList, p)
        gs.playerMap[def.userId] = p
    end

    return gs
end

-- ============================================
-- EXゾーン処理システム
-- ============================================

-- EXから1枚削除してトリガー効果を返す
-- 戻り値: {effect=string, card=table} or nil
local function removeTopEX(pl)
    if #pl.ex == 0 then return nil end
    -- ハルニアの鼓動は末尾（index 1）に固定し最後まで残す
    -- 通常は先頭から削除（EXトリガー優先）
    local removeIdx = nil
    for i = 2, #pl.ex do  -- index1=ハルニアの鼓動をスキップ
        if pl.ex[i].effect ~= "ex_life" then
            removeIdx = i
            break
        end
    end
    -- 他EXがなければハルニアの鼓動を削除（敗北確定）
    if not removeIdx then removeIdx = 1 end
    local card = table.remove(pl.ex, removeIdx)
    return card
end

-- シールド攻撃時のハルニア処理
-- 鼓動はただのライフカード。1枚消費。全部なくなったら敗北。
-- 攻撃無効化なし、追加効果なし。
local function processShieldAttack(gs, defender, shieldIdx)
    if not defender.isHalnia then return nil end

    -- EXから「ハルニアの鼓動」を1枚消費する
    local kodouIdx = nil
    for i, c in ipairs(defender.ex) do
        if c.effect == "ex_life" then kodouIdx = i; break end
    end
    if not kodouIdx then
        -- 鼓動がすでに0枚 = 即敗北
        defender.defeated = true
        return {type="halnia_defeat"}
    end

    -- 鼓動1枚消費
    table.remove(defender.ex, kodouIdx)

    -- 残り鼓動が0になったら敗北
    local remaining = 0
    for _, c in ipairs(defender.ex) do
        if c.effect == "ex_life" then remaining = remaining + 1 end
    end

    if remaining == 0 then
        defender.defeated = true
        return {type="halnia_defeat", remaining=0}
    end

    return {type="kodou_consumed", remaining=remaining}
end

-- EXトリガー効果（現在未使用。将来のEXカード拡張用に残す）
local function applyEXTrigger(gs, trigResult, battleResult)
    -- ハルニアの鼓動はただのライフカードなので追加効果なし
    -- 将来別のEXカードで使う場合はここに追加
end

-- 蜜カードをEXに追加（クラディオン系カード効果から呼ぶ）
local function addHoney(gs, pl, count)
    count = count or 1
    for _ = 1, count do
        table.insert(pl.ex, {
            id="honey_token", name="蜜", rank=0, effect="honey", suit="club"
        })
    end
    -- クライアントに通知
    broadcast(gs, {
        type      = "honey_added",
        playerId  = pl.id,
        count     = count,
        total     = (function()
            local n = 0
            for _, c in ipairs(pl.ex) do if c.effect == "honey" then n=n+1 end end
            return n
        end)(),
    })
end

-- バトル時に蜜を消費してパワーボーナスを得る
-- amount: 消費する蜜の枚数（0でスキップ）
local function consumeHoney(gs, pl, amount)
    if amount <= 0 then return 0 end
    local consumed = 0
    for i = #pl.ex, 1, -1 do
        if pl.ex[i].effect == "honey" and consumed < amount then
            table.remove(pl.ex, i)
            consumed = consumed + 1
        end
    end
    return consumed  -- 実際に消費した枚数（= パワーボーナス）
end

-- EXゾーンの状態をクライアントに送る
local function broadcastEXState(gs)
    for _, pl in ipairs(gs.playerList) do
        if pl.isHuman then
            local rp = Players:GetPlayerByUserId(pl.userId)
            if rp then
                -- 自分のEX情報
                local exInfo = {}
                for _, c in ipairs(pl.ex) do
                    table.insert(exInfo, {id=c.id, name=c.name, effect=c.effect})
                end
                -- 全員のEX枚数（表向き情報）
                local exCounts = {}
                for _, op in ipairs(gs.playerList) do
                    exCounts[tostring(op.id)] = #op.ex
                end
                RE_UpdateBoard:FireClient(rp, {
                    type     = "ex_state",
                    myEX     = exInfo,
                    exCounts = exCounts,
                })
            end
        end
    end
end

-- ============================================
-- スート特性ボーナス（トランプ版・TCG版共通）
-- リアルでも遊べるシンプルルールのみ
-- ♥ Heart  : 1ターン目ロード+2（先手有利）
-- ♦ Diamond: 防御時バトル+3（カウンター）
-- ♣ Club   : チップ3枚以上でバトル+2（コンボ）
-- ♠ Spade  : 相手のロードカードが見える（情報）
-- ============================================
local SUIT_BONUS = {
    heart   = "first_strike",
    diamond = "counter",
    club    = "chip_boost",
    spade   = "info",
}

local function getSuitBonus(gs, p)
    -- スート特性はTCG版のみ有効
    if not gs.isTCG then return 0 end
    local b = SUIT_BONUS[p.suit or "club"]
    if b == "chip_boost"   and #p.chips >= 3   then return 2 end
    if b == "first_strike" and gs.turn == 1     then return 2 end
    if b == "counter"      and p.id == gs.defId then return 3 end
    -- "info" は数値ボーナスなし・UI表示のみ（BattleClientで処理）
    return 0
end

-- ============================================
-- バトル合計計算
-- ============================================
local function calcTotal(gs, p)
    local t = 0
    if gs.roadOverride[p.id] ~= nil then
        t = t + gs.roadOverride[p.id]
    elseif gs.road[p.id] then
        t = t + gs.road[p.id].rank
    end
    if not gs.roadOnly then
        if gs.battle[p.id] then t = t + gs.battle[p.id].rank end
        if gs.extraBattle[p.id] then
            for _, c in ipairs(gs.extraBattle[p.id]) do t = t + c.rank end
        end
    end
    t = t + (gs.arcanaBonus[p.id] or 0)
    t = t + getSuitBonus(gs, p)
    return math.max(0, t)
end

-- ============================================
-- ブロードキャスト（全人間プレイヤーに送信）
-- ============================================
-- 観戦者テーブル: roomId → {userId, ...}
local Observers = {}

local function broadcast(gs, data)
    for _, p in ipairs(gs.playerList) do
        if p.isHuman then
            local pl = Players:GetPlayerByUserId(p.id)
            if pl then RE_UpdateBoard:FireClient(pl, data) end
        end
    end
    -- 観戦者にも送信（個人情報は隠す）
    local roomId = gs.roomId
    if roomId and Observers[roomId] then
        local publicData = {
            type         = data.type,
            road         = data.road,
            battle       = data.battle,
            winnerId     = data.winnerId,
            totals       = data.totals,
            columns      = data.columns,
            victory      = data.victory,
            turn         = data.turn,
            isObserving  = true,
        }
        for _, obsId in ipairs(Observers[roomId]) do
            local obs = Players:GetPlayerByUserId(obsId)
            if obs then RE_UpdateBoard:FireClient(obs, publicData) end
        end
    end
end

local function sendTo(gs, userId, data)
    local pl = Players:GetPlayerByUserId(userId)
    if pl then RE_UpdateBoard:FireClient(pl, data) end
end

-- PhaseChangedをbCastする（EXPhaseClient等が待ち受けている）
local RE_PhaseChanged = Remotes:WaitForChild("PhaseChanged", 15)
local function broadcastPhase(gs, phaseData)
    for _, p in ipairs(gs.playerList) do
        if p.isHuman then
            local pl = Players:GetPlayerByUserId(p.id)
            if pl then RE_PhaseChanged:FireClient(pl, phaseData) end
        end
    end
end

-- ============================================
-- AIロジック
-- ============================================
local function aiPickCard(hand, mode, difficulty)
    if #hand == 0 then return nil end
    local sorted = {table.unpack(hand)}
    table.sort(sorted, function(a, b) return a.rank < b.rank end)

    if mode == "road" then
        if difficulty == "easy"   then return sorted[1]
        elseif difficulty == "hard" then return sorted[math.ceil(#sorted/2)]
        else return sorted[math.ceil(#sorted/2)] end
    else -- battle
        table.sort(sorted, function(a, b) return a.rank > b.rank end)
        if difficulty == "easy" then return sorted[math.random(#sorted)]
        else return sorted[1] end
    end
end

local function removeFromHand(p, cardId)
    for i, c in ipairs(p.hand) do
        if c.id == cardId then return table.remove(p.hand, i) end
    end
    return nil
end

-- ============================================
-- 状態機械コア（バグ1修正）
-- ============================================
-- Robloxの非同期モデル：
--   各ターンはcoroutineで動く
--   人間の入力待ちはcoroutine.yield()で一時停止
--   RemoteEventのコールバックでcoroutine.resume()して再開

local ActiveGames = {}  -- roomId -> {gs, coroutine}
local WaitingFor  = {}  -- roomId -> {[userId] -> coroutine}

local INPUT_TIMEOUT = 30  -- 秒（放置タイムアウト）

local function yieldForInput(roomId, userId)
    WaitingFor[roomId] = WaitingFor[roomId] or {}
    local co = coroutine.running()
    WaitingFor[roomId][userId] = co

    -- タイムアウト: 30秒後に自動でnilをresume（AI選択にフォールバック）
    task.delay(INPUT_TIMEOUT, function()
        local waiting = WaitingFor[roomId]
        if waiting and waiting[userId] == co then
            waiting[userId] = nil
            -- クライアントにタイムアウト通知
            local pl = Players:GetPlayerByUserId(userId)
            if pl then
                local re = Remotes:FindFirstChild("UpdateBoard")
                if re then
                    re:FireClient(pl, {type = "input_timeout", userId = userId})
                end
            end
            coroutine.resume(co, nil)  -- nilを返してAI選択へ
        end
    end)

    -- クライアントにカウントダウン開始を通知
    local pl = Players:GetPlayerByUserId(userId)
    if pl then
        local re = Remotes:FindFirstChild("UpdateBoard")
        if re then
            re:FireClient(pl, {type = "input_timer_start", seconds = INPUT_TIMEOUT})
        end
    end

    return coroutine.yield()
end

-- ロードフェーズ
-- アルカナ選択フェーズ
-- プレイヤーのコーデ装着状況
local function getCoordState(player)
    player._coord = player._coord or {tops=false, bottoms=false, shoes=false, acc=false}
    return player._coord
end

-- EXからコーデを呼び出して装着（アイドルカード効果）
local function callCoordFromEX(gs, player, maxParts)
    local coordState = getCoordState(player)
    local called = 0
    for i = #player.ex, 1, -1 do
        if called >= maxParts then break end
        local c = player.ex[i]
        if c.effect == "coord" and c.part and not coordState[c.part] then
            coordState[c.part] = true
            table.remove(player.ex, i)
            called = called + 1
            -- 部位ごとの即時効果
            if     c.part == "tops"    then
                gs.arcanaBonus[player.id] = (gs.arcanaBonus[player.id] or 0) + 3
            elseif c.part == "bottoms" then
                player._coordDraw = (player._coordDraw or 0) + 1
            elseif c.part == "shoes"   then
                gs.arcanaBonus[player.id] = (gs.arcanaBonus[player.id] or 0) + 2
            elseif c.part == "acc"     then
                gs.arcanaBonus[player.id] = (gs.arcanaBonus[player.id] or 0) + 2
            end
            broadcast(gs, {type="coord_worn", playerId=player.id, part=c.part, cardName=c.name})
        end
    end
    -- フルコーデチェックはカード側のカードテキストで処理。ゲーム側では何もしない
    return called
end

-- カード効果適用（プレイ時）
local function applyCardEffect(gs, player, card, phase)
    if not card or not card.effect then return end
    local fx = card.effect

    -- POWER_IF_CHIP: チップが一定数以上の時バトル+
    if fx == "power_if_chip" and phase == "road" then
        if #player.chips >= 3 then
            gs.arcanaBonus[player.id] = (gs.arcanaBonus[player.id] or 0) + (card.value or 1)
        end
    end
    -- SHIELD_BOOST: シールドとして使われた時手札に戻る
    if fx == "shield_boost" and phase == "shield" then
        gs.shieldReturn = gs.shieldReturn or {}
        gs.shieldReturn[player.id] = card
    end
    -- アイドルカード: EXからコーデを呼び出す
    if fx == "idol_call"     and phase == "road" then callCoordFromEX(gs, player, 1) end
    if fx == "idol_call_2"   and phase == "road" then callCoordFromEX(gs, player, 2) end
    if fx == "idol_call_all" and phase == "road" then callCoordFromEX(gs, player, 4) end
end

local function arcanaPhase(roomId, gs)
    gs.phase = "arcana"
    gs.arcanaBan = gs.arcanaBan or {}

    -- AIのアルカナ選択
    for _, p in ipairs(gs.playerList) do
        if p.isAI then
            local pick = ArcanaSystem.aiPickArcana(gs, p, "normal")
            if pick then
                local tgt = pick.target
                ArcanaSystem.applyArcana(pick.card, pick.direction, gs, p, tgt)
            end
        end
    end

    -- AI使用アルカナをブロードキャスト
    -- （人間の選択は受信後にサーバーから通知）

    -- 人間プレイヤーにアルカナ選択を要求
    for _, p in ipairs(gs.playerList) do
        if p.isHuman then
            local pl = Players:GetPlayerByUserId(p.id)
            if pl then
                -- 未使用アルカナ一覧を作成
                local available = {}
                p.arcanaUsed = p.arcanaUsed or {}
                for _, a in ipairs(p.arcana or {}) do
                    if not p.arcanaUsed[a.n] then
                        table.insert(available, {
                            n    = a.n,
                            name = a.name,
                            icon = a.icon,
                            posDesc = a.posDesc,
                            negDesc = a.negDesc,
                        })
                    end
                end
                -- 封印チェック
                local banned = (gs.arcanaBan[p.id] or 0) > 0
                RE_UpdateBoard:FireClient(pl, {
                    type      = "request_arcana",
                    roomId    = roomId,
                    available = available,
                    banned    = banned,
                    turn      = gs.turn,
                    -- 対象候補（敵プレイヤー）
                    targets   = (function()
                        local t = {}
                        for _, ep in ipairs(gs.playerList) do
                            if ep.team ~= p.team then
                                table.insert(t, {id=ep.id, name=ep.name})
                            end
                        end
                        return t
                    end)(),
                })
            end
            -- 15秒タイムアウトで自動スキップ（yieldForInputを使用）
            yieldForInput(roomId, p.id)
        end
    end

    task.wait(0.3)
end

local function roadPhase(roomId, gs)
    gs.phase = "road"
    gs.road = {}

    -- AIのロード選択（CombiLogic適用）
    for _, p in ipairs(gs.playerList) do
        -- noRoad: プテラノ逆位置でロード出せない
        if gs.noRoad and gs.noRoad[p.id] and gs.noRoad[p.id] > 0 then
            gs.noRoad[p.id] = gs.noRoad[p.id] - 1
            -- ロードなしで参加（ランク0扱い）
            gs.road[p.id] = {id="no_road", rank=0, name="（ロード封印）"}
        elseif p.isAI then
            -- チームメンバーと敵を特定
            local ally, enemies = nil, {}
            for _, op in ipairs(gs.playerList) do
                if op.id ~= p.id then
                    if op.team == p.team then ally = op
                    else table.insert(enemies, op) end
                end
            end
            local role, _ = ally
                and CombiLogic.assignRoles(gs, p, ally)
                or "free", "free"

            local card = CombiLogic.aiPickRoad(gs, p, role, "normal", enemies, ally)
                      or aiPickCard(p.hand, "road", "normal")  -- フォールバック
            if card then
                removeFromHand(p, card.id)
                gs.road[p.id] = card
                applyCardEffect(gs, p, card, "road")
            end
        end
    end

    -- 人間プレイヤーにロード選択を要求（コンビ戦アドバイス付き）
    for _, p in ipairs(gs.playerList) do
        -- noRoad: 既にロードが設定済み（封印 or AI済み）ならスキップ
        if gs.road[p.id] then
            -- 既に選択済み（noRoadやAI）
        elseif p.isHuman then
            local pl = Players:GetPlayerByUserId(p.id)
            if pl then
                -- コンビ戦用アドバイス生成
                local ally, enemies = nil, {}
                for _, op in ipairs(gs.playerList) do
                    if op.id ~= p.id then
                        if op.team == p.team then ally = op
                        else table.insert(enemies, op) end
                    end
                end
                local consultMsg = ally
                    and CombiLogic.buildConsultMessage(gs, p, ally, "road", enemies)
                    or {navigator = "ロードカードを選ぼう", partner = ""}

                -- 味方の手札・シールドを共有（コンビ戦仕様）
                local teamInfo = CombiLogic.buildTeamInfo(gs, p.id)

                -- 学習アドバイス：前回同じ状況でプレミがあれば通知
                if PartnerAdviceBindable then
                    local chipCount  = #p.chips
                    local maxColLen  = 0
                    for _, col in ipairs(p.columns) do
                        if #col > maxColLen then maxColLen = #col end
                    end
                    -- situation の簡易自動判定
                    local situation = "road_high"
                    if chipCount >= 4 then
                        situation = "chip_waste"
                    elseif maxColLen >= 5 then
                        situation = "col_miss"
                    end
                    pcall(function()
                        PartnerAdviceBindable:Fire(pl.UserId, situation, chipCount, gs.turn)
                    end)
                end

                -- アドバイス送信
                RE_PartnerAdvice:FireClient(pl, {
                    text      = consultMsg.navigator,
                    partnerMsg = consultMsg.partner,
                    role      = consultMsg.role,
                    phase     = "road",
                    teamInfo  = teamInfo,
                })
                -- ロード選択UIを開く
                RE_UpdateBoard:FireClient(pl, {
                    type      = "request_road",
                    roomId    = roomId,
                    hand      = p.hand,
                    highCardsLeft = CombiLogic.estimateHighCards(gs),
                })
            end
            -- 入力を待つ（coroutine停止）
            yieldForInput(roomId, p.id)
        end
    end

    -- 全員のロードが揃った → 最大値を持つプレイヤーが攻撃権獲得
    local maxRank = -1
    local activeId = nil
    for _, p in ipairs(gs.playerList) do
        local r = gs.road[p.id] and gs.road[p.id].rank or 0
        if r > maxRank then maxRank = r; activeId = p.id end
    end
    gs.activeId = activeId

    -- ♠ Spade info: TCG版かつspadeのプレイヤーには相手のロードが見える
    for _, pl in ipairs(gs.playerList) do
        local revealEnemy = nil
        if gs.isTCG and (pl.suit or "club") == "spade" then
            -- 敵チームのロードカードを公開
            revealEnemy = {}
            for _, ep in ipairs(gs.playerList) do
                if ep.team ~= pl.team and gs.road[ep.id] then
                    revealEnemy[ep.id] = gs.road[ep.id]
                end
            end
        end
        local target = game.Players:GetPlayerByUserId(pl.userId)
        if target then
            local re = game.ReplicatedStorage.Remotes:FindFirstChild("UpdateBoard")
            if re then
                re:FireClient(target, {
                    type        = "road_reveal",
                    road        = gs.road,
                    activeId    = activeId,
                    maxRank     = maxRank,
                    enemyRoad   = revealEnemy,  -- spadeのみ非nil
                })
            end
        end
    end

    task.wait(1.2)
end

-- バトルフェーズ
local function battlePhase(roomId, gs)
    gs.phase = "battle"
    gs.battle = {}

    -- 防御側はシールドが自動的にバトルカード
    local defender = gs.playerMap[gs.defId]
    if defender and #defender.shields > 0 then
        local shIdx = gs.targetShieldIdx or 1
        shIdx = math.min(shIdx, #defender.shields)
        local usedShield = table.remove(defender.shields, shIdx)
        gs.battle[defender.id] = usedShield
        -- SHIELD_BOOST効果: シールドとして使われた時手札に戻る
        if usedShield and (usedShield.effect == "shield_boost" or
           usedShield.effect == "SHIELD_BOOST") then
            applyCardEffect(gs, defender, usedShield, "shield")
        end
        -- シールド破壊通知
        broadcast(gs, {
            type = "shield_broken",
            defenderId = defender.id,
            shieldCard = gs.battle[defender.id],
        })
        -- ★ EXトリガー処理（ハルニアの鼓動）
        -- シールドが攻撃されるたびに効果発動：他EXを1枚削除 or 鼓動破壊→敗北
        if gs.isTCG and defender.isHalnia then
            local exResult = processShieldAttack(gs, defender, shIdx)
            gs._pendingEXResult = exResult  -- resultPhaseで参照する
            if exResult then
                if exResult.type == "kodou_consumed" then
                    -- 鼓動1枚消費（攻撃は普通に通る）
                    broadcast(gs, {
                        type      = "kodou_consumed",
                        defender  = defender.id,
                        remaining = exResult.remaining,
                    })
                elseif exResult.type == "halnia_defeat" then
                    -- 鼓動が全部消えた → 敗北
                    broadcast(gs, {
                        type   = "halnia_defeated",
                        player = defender.id,
                    })
                    gs.victory = (defender.team == "A") and "B" or "A"
                end
            end
        end
        broadcastEXState(gs)
        -- TCG版のみEXフェーズUIをクライアントに開かせる
        if gs.isTCG then
            gs.phase = "ex_phase"
            for _, p in ipairs(gs.playerList) do
                if p.isHuman then
                    local arcanaList = {}
                    for _, c in ipairs(p.arcana or {}) do
                        if not (p.arcanaUsed and p.arcanaUsed[c.n]) then
                            table.insert(arcanaList, {
                                id=c.id, n=c.n, name=c.name,
                                icon=c.icon, posDesc=c.posDesc, negDesc=c.negDesc,
                                effect=c.effect
                            })
                        end
                    end
                    -- techListはコーデカード(coord)とじゃんけん技カードを含む
                    local techList = {}
                    for _, c in ipairs(p.ex or {}) do
                        table.insert(techList, {
                            id=c.id, name=c.name, effect=c.effect,
                            part=c.part,   -- コーデカードの部位
                            hand=c.hand,   -- じゃんけん技の手
                            cost=c.cost,   -- MP消費
                            desc=c.desc,
                        })
                    end
                    local rp = Players:GetPlayerByUserId(p.id)
                    if rp then
                        RE_PhaseChanged:FireClient(rp, {
                            phase   = "ex_phase",
                            arcana  = arcanaList,
                            tech    = techList,
                            mp      = p._currentMP or 0,
                            coord   = getCoordState(p),  -- 現在の装着状況
                        })
                    end
                end
            end
        end
    end

    -- 防御側以外のAIがバトルカードを選択（CombiLogic適用）
    for _, p in ipairs(gs.playerList) do
        if p.isAI and p.id ~= gs.defId then
            local ally, enemies = nil, {}
            for _, op in ipairs(gs.playerList) do
                if op.id ~= p.id then
                    if op.team == p.team then ally = op
                    else table.insert(enemies, op) end
                end
            end
            local role = ally
                and CombiLogic.assignRoles(gs, p, ally)
                or "free"

            local card = CombiLogic.aiPickBattle(gs, p, role, "normal", enemies)
                      or aiPickCard(p.hand, "battle", "normal")
            if card then
                removeFromHand(p, card.id)
                gs.battle[p.id] = card
            end
        end
    end

    -- 人間プレイヤー（防御側以外）にバトルカード選択を要求
    for _, p in ipairs(gs.playerList) do
        if p.isHuman and p.id ~= gs.defId then
            local pl = Players:GetPlayerByUserId(p.id)
            if pl then
                RE_UpdateBoard:FireClient(pl, {
                    type = "request_battle",
                    roomId = roomId,
                    hand = p.hand,
                    defenderShield = gs.battle[gs.defId],
                    extraSlot = gs.extraBattleSlot and gs.extraBattleSlot[p.id] or false,
                })
            end
            yieldForInput(roomId, p.id)
        end
    end

    task.wait(0.5)
end

-- ターゲット選択フェーズ
local function targetPhase(roomId, gs)
    local active = gs.playerMap[gs.activeId]
    if not active then return end

    -- 敵リスト
    local enemies = {}
    for _, p in ipairs(gs.playerList) do
        if p.team ~= active.team then table.insert(enemies, p) end
    end

    if active.isAI then
        -- AI：列が一番多い相手を狙う
        local target = enemies[1]
        local maxCol = 0
        for _, e in ipairs(enemies) do
            local s = 0
            for _, col in ipairs(e.columns) do s = s + #col end
            if s > maxCol then maxCol = s; target = e end
        end
        gs.defId = target.id
        gs.targetShieldIdx = 1
    else
        -- 人間：クライアントにターゲット選択UIを要求
        local pl = Players:GetPlayerByUserId(active.id)
        if pl then
            RE_UpdateBoard:FireClient(pl, {
                type = "request_target",
                roomId = roomId,
                enemies = enemies,
            })
        end
        yieldForInput(roomId, active.id)
    end
end

-- 結果計算・適用フェーズ
local function resultPhase(gs)
    -- 合計計算
    local totals = {}
    for _, p in ipairs(gs.playerList) do
        totals[p.id] = calcTotal(gs, p)
    end

    -- ★ アルカナ特殊効果をresultPhaseで解決
    -- dimMode: 全員バトルカード2枚（低い方を参照）→ 既にbattleに格納済み
    -- cancelStack: 積み上げを1枚キャンセル（合計から最大列の末尾を除く）
    if gs.cancelStack then
        for userId, n in pairs(gs.cancelStack) do
            local p = gs.playerMap[userId]
            if p and n > 0 then
                -- 最大列の末尾を n 枚除去
                for _ = 1, n do
                    local maxIdx = 1
                    for i, col in ipairs(p.columns) do
                        if #col > #p.columns[maxIdx] then maxIdx = i end
                    end
                    if #p.columns[maxIdx] > 0 then
                        table.remove(p.columns[maxIdx])
                    end
                end
            end
        end
    end

    -- justiceUser: 自合計≥相手なら勝利確定
    if gs.justiceUser then
        local ju = gs.playerMap[gs.justiceUser]
        if ju then
            local myTotal = totals[ju.id] or 0
            local win = true
            for _, p in ipairs(gs.playerList) do
                if p.team ~= ju.team then
                    if myTotal < (totals[p.id] or 0) then win = false; break end
                end
            end
            if win then
                gs.justiceWin = ju.team
            end
        end
    end

    -- ★ EX効果: 蜜の消費（クライアントから消費枚数を受け取る前提。
    --            ここではAI/デフォルトとして「全蜜を消費」して合計に加算）
    if gs.isTCG then
        for _, p in ipairs(gs.playerList) do
            if p.suit == "club" then
                -- 蜜カードを全消費してパワーに変換
                local honeyBonus = consumeHoney(gs, p, 999)
                if honeyBonus > 0 then
                    totals[p.id] = totals[p.id] + honeyBonus
                    broadcast(gs, {
                        type    = "honey_consumed",
                        player  = p.id,
                        bonus   = honeyBonus,
                    })
                end
            end
        end

        -- ★ EX効果: ハルニア鼓動はライフカードのみ。将来のEX拡張用のスペース
        local battleResult = {exBonus=0, noDropFor={}, extraColFor={}}
        if gs._pendingEXResult then
            applyEXTrigger(gs, gs._pendingEXResult, battleResult)
            gs._pendingEXResult = nil
        end
        -- exBonusを防御側の合計に加算（防御側が受けた恩恵）
        local defender = gs.playerMap[gs.defId]
        if defender and battleResult.exBonus > 0 then
            totals[defender.id] = totals[defender.id] + battleResult.exBonus
        end
        gs._battleResult = battleResult  -- noDropFor/extraColFor用に保持
    end

    -- 勝者決定
    local winnerId = nil
    local maxTotal = -1

    -- justiceWin: 正義カードで勝利チーム確定
    if gs.justiceWin then
        for _, p in ipairs(gs.playerList) do
            if p.team == gs.justiceWin then
                winnerId = p.id; break
            end
        end
    end

    if not winnerId then
        for _, p in ipairs(gs.playerList) do
            if totals[p.id] > maxTotal then
                maxTotal = totals[p.id]
                winnerId = p.id
            end
        end
    end

    local winner = gs.playerMap[winnerId]
    local targetCol = gs.targetShieldIdx or 1
    targetCol = math.min(targetCol, 3)

    -- 勝者：使用カード＋チップを列へ積み上げ
    local stackCards = {}
    if gs.road[winnerId]   then table.insert(stackCards, gs.road[winnerId]) end
    if gs.battle[winnerId] then table.insert(stackCards, gs.battle[winnerId]) end
    if gs.extraBattle[winnerId] then
        for _, c in ipairs(gs.extraBattle[winnerId]) do
            table.insert(stackCards, c)
        end
    end
    for _, c in ipairs(winner.chips) do table.insert(stackCards, c) end
    winner.chips = {}

    -- アーケオ2倍
    if gs.archeoDouble == winnerId then
        local doubled = {}
        for _, c in ipairs(stackCards) do
            table.insert(doubled, c); table.insert(doubled, c)
        end
        stackCards = doubled
    end

    for _, c in ipairs(stackCards) do
        table.insert(winner.columns[targetCol], c)
    end

    -- amberUser: このターン敗者でも積み上げ可能
    if gs.amberUser and gs.amberUser ~= winnerId then
        local amberP = gs.playerMap[gs.amberUser]
        if amberP then
            local amberCards = {}
            if gs.road[gs.amberUser]   then table.insert(amberCards, gs.road[gs.amberUser]) end
            if gs.battle[gs.amberUser] then table.insert(amberCards, gs.battle[gs.amberUser]) end
            for _, c in ipairs(amberCards) do
                table.insert(amberP.columns[targetCol], c)
            end
        end
    end

    -- 敗者：チップへ（noDropForに含まれるプレイヤーはチップに行かず手札に戻る）
    local noDropSet = {}
    if gs._battleResult then
        for _, uid in ipairs(gs._battleResult.noDropFor or {}) do
            noDropSet[uid] = true
        end
    end
    for _, p in ipairs(gs.playerList) do
        if p.id ~= winnerId then
            if noDropSet[p.id] then
                -- EXトリガー効果: チップに行かず手札に戻す
                if gs.road[p.id]   then table.insert(p.hand, gs.road[p.id]) end
                if gs.battle[p.id] and p.id ~= gs.defId then
                    table.insert(p.hand, gs.battle[p.id])
                end
                broadcast(gs, {type="nodrop_fired", player=p.id})
            else
                if gs.road[p.id]   then table.insert(p.chips, gs.road[p.id]) end
                if gs.battle[p.id] and p.id ~= gs.defId then
                    table.insert(p.chips, gs.battle[p.id])
                end
            end
        end
    end
    -- extraColFor: 勝者が該当する場合、列に+2枚追加できるフラグを立てる
    if gs._battleResult then
        for _, uid in ipairs(gs._battleResult.extraColFor or {}) do
            if uid == winnerId then
                -- 追加2枚: 勝者の個別デッキから引いて列に積む
                for _ = 1, 2 do
                    if winner._deck and #winner._deck > 0 then
                        table.insert(winner.columns[targetCol], table.remove(winner._deck, 1))
                    end
                end
                broadcast(gs, {type="extra_col_fired", player=winnerId, col=targetCol})
            end
        end
        gs._battleResult = nil
    end

    -- 防御側シールド補充
    local defender = gs.playerMap[gs.defId]
    if defender and #defender.hand > 0 and #defender.shields < 3 then
        local c = table.remove(defender.hand, 1)
        table.insert(defender.shields, c)
    end

    -- 手札補充（各自の個別デッキから）
    for _, p in ipairs(gs.playerList) do
        local drawLimit = 3
        if gs.drawMinus and gs.drawMinus[p.id] and gs.drawMinus[p.id] > 0 then
            drawLimit = math.max(0, drawLimit - gs.drawMinus[p.id])
            gs.drawMinus[p.id] = 0
        end
        while #p.hand < drawLimit and p._deck and #p._deck > 0 do
            table.insert(p.hand, table.remove(p._deck, 1))
        end
        -- 山札切れで手札0: 自動的に最低1枚補充できないなら負け（ゲーム設計上は起きないはずだが安全弁）
        if #p.hand == 0 and p.isHuman then
            -- 警告のみ。手札0で選択フェーズに入ってもサーバーがnil対処する
            warn("[BattleServer] " .. (p.name or "?") .. " の手札が0枚です（山札切れ）")
        end
    end

    -- リプレイ記録
    -- 統計トラッキング
    for _, p in ipairs(gs.playerList) do
        if not gs._stats[p.id] then
            gs._stats[p.id] = {road=0, col=0, arcana=0, chips=0}
        end
        local s = gs._stats[p.id]
        if gs.road[p.id] then s.road = math.max(s.road, gs.road[p.id].rank or 0) end
        for _, col in ipairs(p.columns) do s.col = math.max(s.col, #col) end
        s.chips = s.chips + #p.chips
        p._maxRoadRank  = s.road
        p._maxColLength = s.col
        p._chipsGained  = s.chips
    end
    -- プレミ確認用に各プレイヤーの行動を詳細記録
    local playerLogs = {}
    for _, p in ipairs(gs.playerList) do
        local function cardInfo(c)
            if not c then return nil end
            return {id=c.id, rank=c.rank, name=c.name or c.id}
        end
        playerLogs[p.id] = {
            name      = p.name,
            team      = p.team,
            road      = cardInfo(gs.road[p.id]),
            battle    = cardInfo(gs.battle[p.id]),
            total     = totals[p.id] or 0,
            isWinner  = (p.id == winnerId),
            colState  = (function()
                local t = {}
                for ci, col in ipairs(p.columns) do t[ci] = #col end
                return t
            end)(),
            chipCount = #p.chips,
        }
    end
    local snapshot = {
        turn     = gs.turn,
        totals   = totals,
        winnerId = winnerId,
        players  = playerLogs,
    }
    table.insert(gs.replayData, snapshot)

    -- 勝利判定（列7枚 or ハルニアの鼓動破壊）
    for _, p in ipairs(gs.playerList) do
        -- 通常勝利：列7枚
        for _, col in ipairs(p.columns) do
            if #col >= 7 then gs.victory = p.team; break end
        end
        if gs.victory then break end
        -- ハルニア敗北：isHalnia=trueのプレイヤーのEXに鼓動がなくなった
        if p.isHalnia and not p.defeated then
            local hasKodou = false
            for _, c in ipairs(p.ex) do
                if c.effect == "ex_life" then hasKodou = true; break end
            end
            if not hasKodou then
                p.defeated = true
                gs.victory = (p.team == "A") and "B" or "A"
                broadcast(gs, {type="halnia_defeated", player=p.id})
                break
            end
        end
    end

    return winnerId, totals
end

-- ============================================
-- メインゲームループ（coroutineで動く）
-- ============================================
local function gameLoop(roomId, gs)
    while not gs.victory do
        gs.turn = gs.turn + 1

        -- フェーズ1：ターゲット選択（攻撃権が決まる前に候補を確認）
        -- フェーズ2：アルカナ選択
        arcanaPhase(roomId, gs)
        if gs.victory then break end

        -- フェーズ3：ロード
        roadPhase(roomId, gs)
        if gs.victory then break end

        -- フェーズ4：ターゲット選択（攻撃権獲得者が対象を選ぶ）
        targetPhase(roomId, gs)

        -- フェーズ4：バトル
        battlePhase(roomId, gs)

        -- フェーズ5：結果
        local winnerId, totals = resultPhase(gs)

        broadcast(gs, {
            type     = "battle_result",
            winnerId = winnerId,
            totals   = totals,
            columns  = (function()
                local t = {}
                for _, p in ipairs(gs.playerList) do
                    t[p.id] = {
                        col1 = #p.columns[1],
                        col2 = #p.columns[2],
                        col3 = #p.columns[3],
                        chips = #p.chips,
                    }
                end
                return t
            end)(),
            victory  = gs.victory,
        })

        -- カード効果 on_chip_draw + コーデボトムスドロー
        for _, p in ipairs(gs.playerList) do
            -- 通常のCHIP_DRAW
            for _, c in ipairs(p.chips) do
                if c.effect == "on_chip_draw" or c.effect == CardDataModule.FX.CHIP_DRAW then
                    if #p._deck > 0 then
                        table.insert(p.hand, table.remove(p._deck, 1))
                    end
                end
            end
            -- コーデ：ボトムス装着ドロー（チップになった時1枚引く）
            local drawBonus = p._coordDraw or 0
            if drawBonus > 0 and #p.chips > 0 then
                for _ = 1, drawBonus do
                    if #p._deck > 0 then
                        table.insert(p.hand, table.remove(p._deck, 1))
                    end
                end
                p._coordDraw = 0
            end
        end

        -- shieldReturn: シールドとして使われた後手札に戻るカード
        if gs.shieldReturn then
            for userId, card in pairs(gs.shieldReturn) do
                local rp = gs.playerMap[userId]
                if rp then table.insert(rp.hand, card) end
            end
            gs.shieldReturn = {}
        end

        -- リセット
        gs.road = {}; gs.battle = {}; gs.arcanaBonus = {}
        gs.extraBattle = {}; gs.roadOverride = {}
        gs.roadOnly = false; gs.amberUser = nil
        gs.archeoDouble = nil; gs.justiceUser = nil
        gs.activeId = nil; gs.defId = nil
        -- アルカナフラグリセット
        gs.nullPos = {}; gs.cancelStack = {}; gs.dimMode = false
        gs.noRoad = {}; gs.arcanaBan = gs.arcanaBan or {}  -- arcanaBanはデクリメント制なので保持
        gs.extraBattleSlot = {}; gs.drawMinus = {}; gs.shieldReturn = {}

        task.wait(1.5)
    end

    -- ゲーム終了
    local ComfortFunc   = ReplicatedStorage:FindFirstChild("NotifyBattleEnd")
    local BondAddFunc   = ReplicatedStorage:FindFirstChild("AddPartnerBond")
    local QuestFunc     = ReplicatedStorage:FindFirstChild("UpdateQuestProgress")

    for _, p in ipairs(gs.playerList) do
        if p.isHuman then
            local pl = Players:GetPlayerByUserId(p.id)
            if pl then
                local isWin = gs.victory == p.team
                -- バトル統計（褒め材料）
                local stats = {
                    isWin        = isWin,
                    maxRoadRank  = p._maxRoadRank  or 0,
                    maxColLength = p._maxColLength  or 0,
                    arcanaUsed   = p._arcanaUsed    or 0,
                    chipsGained  = p._chipsGained   or 0,
                    turns        = gs.turn or 0,
                }
                -- 褒め演出（敗北時も同じ）
                if ComfortFunc then
                    pcall(function() ComfortFunc:Invoke(pl, stats) end)
                end
                -- きずな+3（プレイしてくれただけで）
                if BondAddFunc then
                    pcall(function() BondAddFunc:Invoke(pl, isWin and 5 or 3) end)
                end
                -- クエスト進捗
                if QuestFunc then
                    pcall(function() QuestFunc:Invoke(pl, "play", 1) end)
                    if isWin then
                        pcall(function() QuestFunc:Invoke(pl, "win", 1) end)
                    end
                    -- アルカナ使用数・チップ数・列最大をクエストに報告
                    local arcUsed = p._arcanaUsed or 0
                    if arcUsed > 0 then
                        pcall(function() QuestFunc:Invoke(pl, "arcana", arcUsed) end)
                    end
                    local chipCount = #p.chips
                    if chipCount > 0 then
                        pcall(function() QuestFunc:Invoke(pl, "chip", chipCount) end)
                    end
                    local maxCol = 0
                    for _, col in ipairs(p.columns) do
                        if #col > maxCol then maxCol = #col end
                    end
                    if maxCol >= 7 then
                        pcall(function() QuestFunc:Invoke(pl, "7col", 1) end)
                    end
                end
                -- game_over はbattle_end_comfortの後に届くよう少し遅らせる
                task.delay(0.8, function()
                    RE_UpdateBoard:FireClient(pl, {
                        type       = "game_over",
                        victory    = gs.victory,
                        playerTeam = p.team,
                        replayData = gs.replayData,
                    })
                end)
            end
        end
    end
    ActiveGames[roomId] = nil
    WaitingFor[roomId]  = nil
    print("✅ Game " .. roomId .. " ended. Winner: Team " .. tostring(gs.victory))
end

-- ============================================
-- ゲーム開始
-- ============================================
local function startGame(playerDefs, mode, roomId)
    roomId = roomId or ("room_" .. os.time() .. "_" .. math.random(9999))
    local gs = createGameState(playerDefs, mode)
    -- フレンド対戦フラグ
    for _, pd in ipairs(playerDefs or {}) do
        if pd.isFriendMatch then gs.isFriendMatch = true; break end
    end

    -- coroutineでゲームループを起動
    local co = coroutine.create(function()
        gameLoop(roomId, gs)
    end)

    ActiveGames[roomId] = {gs = gs, co = co}
    WaitingFor[roomId]  = {}

    -- deckSlotsを収集して個別送信（スキン情報）
    local GachaSystem = require(ServerScriptService:WaitForChild("GachaSystem", 15))
    for _, pl in ipairs(gs.playerList) do
        if pl.isHuman then
            local rPlayer = Players:GetPlayerByUserId(pl.userId)
            if rPlayer then
                local slots = GachaSystem.GetDeckSlots(rPlayer)
                RE_UpdateBoard:FireClient(rPlayer, {
                    type      = "deck_slots",
                    roomId    = roomId,
                    suit      = pl.suit,   -- このプレイヤーの今回のスート
                    slots     = slots,
                })
            end
        end
    end

    -- 開始通知（isTCG・プレイヤー情報を含める）
    local rosterData = {}
    for _, pl in ipairs(gs.playerList) do
        table.insert(rosterData, {
            userId = pl.id,
            name   = pl.name,
            team   = pl.team,
            suit   = pl.suit,
        })
    end
    broadcast(gs, {
        type    = "game_start",
        roomId  = roomId,
        mode    = mode,
        isTCG   = gs.isTCG,
        players = rosterData,
    })
    task.wait(0.5)

    -- ループ開始
    coroutine.resume(co)
    return roomId
end

-- ============================================
-- RemoteEventコールバック（入力受信→coroutine再開）
-- ============================================

-- ロードカード受信
RE_RoadSelect.OnServerEvent:Connect(function(player, data)
    -- レート制限
    if not Security.checkRateLimit(player, "RoadSelect") then return end

    local roomId = data and data.roomId
    if not roomId then return end
    local gameData = ActiveGames[roomId]
    if not gameData then return end
    local gs = gameData.gs

    local p = gs.playerMap[player.UserId]
    if not p or p.id ~= player.UserId then return end
    if gs.phase ~= "road" then return end
    if gs.road[p.id] then return end  -- 既に選択済み

    -- カードが手札にあるか検証
    if not Security.validateCardInHand(player, gs, data.cardId) then
        Security.recordViolation(player, "road: card not in hand")
        return
    end

    local card = removeFromHand(p, data.cardId)
    if not card then return end

    gs.road[p.id] = card
    applyCardEffect(gs, p, card, "road")

    -- 待機中のcoroutineを再開
    local waiting = WaitingFor[roomId]
    if waiting and waiting[player.UserId] then
        local co = waiting[player.UserId]
        waiting[player.UserId] = nil
        coroutine.resume(co)
    end
end)

-- バトルカード受信
RE_BattleSelect.OnServerEvent:Connect(function(player, data)
    if not Security.checkRateLimit(player, "BattleSelect") then return end

    local roomId = data and data.roomId
    if not roomId then return end
    local gameData = ActiveGames[roomId]
    if not gameData then return end
    local gs = gameData.gs

    local p = gs.playerMap[player.UserId]
    if not p then return end
    if gs.phase ~= "battle" then return end
    if p.id == gs.defId then return end  -- 防御側は自動選択
    if gs.battle[p.id] then return end   -- 既に選択済み

    if not Security.validateCardInHand(player, gs, data.cardId) then
        Security.recordViolation(player, "battle: card not in hand")
        return
    end

    local card = removeFromHand(p, data.cardId)
    if not card then return end

    gs.battle[p.id] = card
    applyCardEffect(gs, p, card, "battle")

    local waiting = WaitingFor[roomId]
    if waiting and waiting[player.UserId] then
        local co = waiting[player.UserId]
        waiting[player.UserId] = nil
        coroutine.resume(co)
    end
end)

-- ターゲット選択受信
RE_TargetSelect.OnServerEvent:Connect(function(player, data)
    if not Security.checkRateLimit(player, "TargetSelect") then return end

    local roomId = data and data.roomId
    if not roomId then return end
    local gameData = ActiveGames[roomId]
    if not gameData then return end
    local gs = gameData.gs

    if gs.activeId ~= player.UserId then return end
    if gs.phase ~= "target" then return end

    gs.defId = data.targetUserId
    gs.targetShieldIdx = data.shieldIdx or 1

    local waiting = WaitingFor[roomId]
    if waiting and waiting[player.UserId] then
        local co = waiting[player.UserId]
        waiting[player.UserId] = nil
        coroutine.resume(co)
    end
end)


-- ============================================
-- アルカナカード受信ハンドラ
-- ============================================
RE_ArcanaSelect.OnServerEvent:Connect(function(player, data)
    if not Security.checkRateLimit(player, "ArcanaSelect") then return end

    local roomId = data and data.roomId
    if not roomId then return end
    local gameData = ActiveGames[roomId]
    if not gameData then return end
    local gs = gameData.gs

    local p = gs.playerMap[player.UserId]
    if not p then return end
    if gs.phase ~= "arcana" then return end

    -- 使用しない（スキップ）場合
    if data.skip then
        local waiting = WaitingFor[roomId]
        if waiting and waiting[player.UserId] then
            local co = waiting[player.UserId]
            waiting[player.UserId] = nil
            coroutine.resume(co)
        end
        return
    end

    -- アルカナカード検証
    local arcData = nil
    if data.arcanaNum ~= nil then
        for _, a in ipairs(p.arcana) do
            if a.n == data.arcanaNum then arcData = a; break end
        end
    end
    if not arcData then return end
    if p.arcanaUsed and p.arcanaUsed[arcData.n] then return end

    -- 対象プレイヤー
    local tgt = nil
    if data.targetId then tgt = gs.playerMap[data.targetId] end

    -- アルカナ適用
    local direction = data.direction or "pos"
    ArcanaSystem.applyArcana(arcData, direction, gs, p, tgt)

    -- coroutine再開
    local waiting = WaitingFor[roomId]
    if waiting and waiting[player.UserId] then
        local co = waiting[player.UserId]
        waiting[player.UserId] = nil
        coroutine.resume(co)
    end
end)

-- ============================================
-- デバッグ：テストゲームを起動
-- ============================================
game:GetService("RunService").Heartbeat:Connect(function()
    -- 本番では削除。Studio上でのテスト用に1人参加で起動する
end)

Players.PlayerAdded:Connect(function(player)
    print(player.Name .. " joined")
end)

Players.PlayerRemoving:Connect(function(player)
    -- ゲーム中の切断処理
    for roomId, gameData in pairs(ActiveGames) do
        local gs = gameData.gs
        if not gs then continue end
        -- このプレイヤーが参加しているか確認
        local found = false
        for _, p in ipairs(gs.playerList or {}) do
            if p.id == player.UserId then found = true; break end
        end
        if not found then continue end

        -- 切断勝利を設定して即座に残プレイヤーに通知
        gs.victory = "disconnect"
        for _, p in ipairs(gs.playerList or {}) do
            if p.isHuman and p.id ~= player.UserId then
                local pl = Players:GetPlayerByUserId(p.id)
                if pl then
                    RE_UpdateBoard:FireClient(pl, {
                        type       = "game_over",
                        victory    = "disconnect_win",
                        playerTeam = p.team,
                        message    = player.Name .. " が切断しました。あなたの勝利です！",
                    })
                end
            end
        end
        ActiveGames[roomId] = nil
        WaitingFor[roomId]  = nil
        break
    end

    -- マッチング待機中の場合はキューから除去
    for roomId, waiting in pairs(WaitingFor) do
        if waiting[player.UserId] then
            waiting[player.UserId] = nil
        end
    end
end)

print("✅ BattleServer_v2.lua loaded")

-- ══════════════════════════════════════════
-- デッキスロット RemoteEvent ハンドラ
-- ══════════════════════════════════════════
local RE_SetDeckSkin = Remotes:WaitForChild("SetDeckSkin", 10)
local RF_GetDeckSlots = Remotes:WaitForChild("GetDeckSlots", 10)

if RE_SetDeckSkin then
    RE_SetDeckSkin.OnServerEvent:Connect(function(player, suit, cardId, skinId)
        local GS = require(ServerScriptService:WaitForChild("GachaSystem", 15))
        GS.SetDeckSkin(player, suit, cardId, skinId)
        -- クライアントのグリッドを更新させるために通知
        local RE_UB = Remotes:FindFirstChild("UpdateBoard")
        if RE_UB then
            RE_UB:FireClient(player, {
                type   = "deck_skin_changed",
                suit   = suit,
                cardId = cardId,
                skinId = skinId,  -- nil = リセット
            })
        end
    end)
end

if RF_GetDeckSlots then
    RF_GetDeckSlots.OnServerInvoke = function(player)
        local GS = require(ServerScriptService:WaitForChild("GachaSystem", 15))
        return GS.GetDeckSlots(player)
    end
end

local RF_GetOwnedSkinsForCard = Remotes:WaitForChild("GetOwnedSkinsForCard", 10)
if RF_GetOwnedSkinsForCard then
    RF_GetOwnedSkinsForCard.OnServerInvoke = function(player, suit, cardId)
        local GS = require(ServerScriptService:WaitForChild("GachaSystem", 15))
        return GS.GetOwnedSkinsForCard(player, suit, cardId)
    end
end

-- ライブラリ全8枠のデッキ名を一括返却
-- 返却形式: {[1]="デッキ名", [2]="デッキ名", ...}  空枠はnil
local RF_GetLibraryNames = Remotes:WaitForChild("GetLibraryNames", 10)
if RF_GetLibraryNames then
    RF_GetLibraryNames.OnServerInvoke = function(player)
        local names = {}
        for i = 1, 8 do
            local key = "deck_" .. player.UserId .. "_lib" .. i
            local ok, result = pcall(function()
                return DeckStore:GetAsync(key)
            end)
            if ok and result and result.main and #result.main > 0 then
                -- oshi名 > 枚数 の順でラベルを決める
                if result.oshi then
                    names[i] = "推し:" .. tostring(result.oshi)
                else
                    names[i] = tostring(#result.main) .. "枚"
                end
            end
        end
        return names
    end
end


-- ══════════════════════════════════════════
-- EXセットフェーズ受信ハンドラ
-- EXセットフェーズ受信ハンドラ（ex_phase）
-- ══════════════════════════════════════════
local DinoSystem = require(ReplicatedStorage:WaitForChild("DinoSystem", 15))

local RE_EXSet = Remotes:WaitForChild("EXSet", 10)

if RE_EXSet then
    RE_EXSet.OnServerEvent:Connect(function(player, data)
        if not Security.checkRateLimit(player, "EXSet") then return end

        local roomId = nil
        for rid, gd in pairs(ActiveGames) do
            for _, p in ipairs(gd.gs.playerList or {}) do
                if p.id == player.UserId then
                    roomId = rid
                    break
                end
            end
            if roomId then break end
        end
        if not roomId then return end

        local gameData = ActiveGames[roomId]
        if not gameData then return end
        local gs = gameData.gs

        if gs.phase ~= "ex_phase" then return end

        -- プレイヤーのEX宣言を記録
        if not gs.exDeclarations then gs.exDeclarations = {} end
        -- コーデカード処理：宣言時に即座に装着
        if data.coordList and #data.coordList > 0 then
            local playerObj = gs.playerMap[player.UserId]
            if playerObj then
                for _, ci in ipairs(data.coordList) do
                    local coordState = getCoordState(playerObj)
                    if not coordState[ci.part] then
                        for k = #playerObj.ex, 1, -1 do
                            local c = playerObj.ex[k]
                            if c.effect == "coord" and c.part == ci.part then
                                coordState[ci.part] = true
                                table.remove(playerObj.ex, k)
                                -- 部位別効果
                                local bonus = ({tops=3, shoes=2, acc=2, bottoms=0})[ci.part] or 0
                                if bonus > 0 then
                                    gs.arcanaBonus[playerObj.id] = (gs.arcanaBonus[playerObj.id] or 0) + bonus
                                elseif ci.part == "bottoms" then
                                    playerObj._coordDraw = (playerObj._coordDraw or 0) + 1
                                end
                                broadcast(gs, {type="coord_worn", playerId=playerObj.id, part=ci.part})
                                break
                            end
                        end
                    end
                end
            end
        end

        gs.exDeclarations[player.UserId] = {
            arcanaId = data.arcanaId,
            techId   = data.techId,
            hand     = data.hand,
        }

        -- 全員宣言完了チェック
        local allDone = true
        for _, p in ipairs(gs.playerList or {}) do
            if p.isHuman and not gs.exDeclarations[p.id] then
                allDone = false
                break
            end
        end

        if allDone then
            -- じゃんけん処理（全ペア）
            if gs.exDeclarations then
                local playerIds = {}
                for uid in pairs(gs.exDeclarations) do
                    table.insert(playerIds, uid)
                end
                -- 全ペアでじゃんけん判定
                for i = 1, #playerIds do
                    for j = i+1, #playerIds do
                        local uid1 = playerIds[i]
                        local uid2 = playerIds[j]
                        local decl1 = gs.exDeclarations[uid1]
                        local decl2 = gs.exDeclarations[uid2]
                        local hand1 = decl1.hand
                        local hand2 = decl2.hand
                        -- 技カードから手を取得
                        if decl1.techId then
                            local CardData = require(ReplicatedStorage:WaitForChild("CardData", 15))
                            local tc = CardData.getCardById(decl1.techId)
                            if tc then hand1 = tc.hand end
                        end
                        if decl2.techId then
                            local CardData = require(ReplicatedStorage:WaitForChild("CardData", 15))
                            local tc = CardData.getCardById(decl2.techId)
                            if tc then hand2 = tc.hand end
                        end
                        -- じゃんけん判定
                        if hand1 and hand2 then
                            local result = DinoSystem.judgeJanken(hand1, hand2)
                            -- 勝者に効果適用（簡易）
                            if result == 1 then
                                gs.exWinners = gs.exWinners or {}
                                gs.exWinners[uid1] = (gs.exWinners[uid1] or 0) + 1
                            elseif result == 2 then
                                gs.exWinners = gs.exWinners or {}
                                gs.exWinners[uid2] = (gs.exWinners[uid2] or 0) + 1
                            end
                        end
                    end
                end
            end

            -- 次フェーズへ（ロードランク順で発動）
            local waiting = WaitingFor[roomId]
            if waiting then
                for uid, co in pairs(waiting) do
                    waiting[uid] = nil
                    coroutine.resume(co)
                end
            end
        else
            -- まだ全員そろっていない → coroutineで待機
            local waiting = WaitingFor[roomId] or {}
            WaitingFor[roomId] = waiting
            waiting[player.UserId] = coroutine.running()
            coroutine.yield()
        end
    end)
end

-- SaveDeck / LoadDeck ハンドラ
local RE_SaveDeck = Remotes:WaitForChild("SaveDeck", 10)
local RE_LoadDeck = Remotes:WaitForChild("LoadDeck", 10)
local RE_DeckLoaded = Remotes:WaitForChild("DeckLoaded", 10)

-- DataStoreService / DeckStore はファイル先頭で定義済み

if RE_SaveDeck then
    RE_SaveDeck.OnServerEvent:Connect(function(player, data)
        if not data or not data.libId then return end
        local libId = math.clamp(tonumber(data.libId) or 1, 1, 8)
        local key = "deck_"..player.UserId.."_lib"..libId
        local ok, err = pcall(function()
            DeckStore:SetAsync(key, {
                main  = data.main  or {},
                ex    = data.ex    or {},
                oshi  = data.oshi,
                saved = os.time(),
            })
        end)
        if not ok then
            warn("[SaveDeck] DataStore error: "..tostring(err))
        end
    end)
end

if RE_LoadDeck and RE_DeckLoaded then
    RE_LoadDeck.OnServerEvent:Connect(function(player, libId)
        local id = math.clamp(tonumber(libId) or 1, 1, 8)
        local key = "deck_"..player.UserId.."_lib"..id
        local ok, result = pcall(function()
            return DeckStore:GetAsync(key)
        end)
        if ok and result then
            RE_DeckLoaded:FireClient(player, result)
        else
            RE_DeckLoaded:FireClient(player, nil)
        end
    end)
end

-- CardVoteハンドラはVoteSystem.luaに統一済み（二重登録防止）

-- ─────────────────────────────────────────
-- バトルセット保存・ロード
-- バトルセット = ライブラリ(1〜8)から選んだ2枠のlibId
-- DataStoreキー: "battleset_{userId}"
-- ─────────────────────────────────────────
local BattleSetStore = DataStoreService:GetDataStore("GameRoad_BattleSet_v1")

local RE_SaveBattleSet  = Remotes:WaitForChild("SaveBattleSet", 10)
local RE_BattleSetLoaded = Remotes:WaitForChild("BattleSetLoaded", 10)

if RE_SaveBattleSet then
    RE_SaveBattleSet.OnServerEvent:Connect(function(player, data)
        if not data then return end
        local s1 = math.clamp(tonumber(data.slot1libId) or 1, 1, 8)
        local s2 = math.clamp(tonumber(data.slot2libId) or 2, 1, 8)
        local key = "battleset_" .. player.UserId
        pcall(function()
            BattleSetStore:SetAsync(key, {
                slot1libId = s1,
                slot2libId = s2,
                saved      = os.time(),
            })
        end)
        -- 保存後に最新状態を返す（UIに反映）
        if RE_BattleSetLoaded then
            RE_BattleSetLoaded:FireClient(player, {
                slot1libId = s1,
                slot2libId = s2,
            })
        end
    end)
end

-- バトルセット読み込み（クライアントから明示的に要求した時 / 画面オープン時）
-- SaveBattleSet を受け取った後は自動返却するので通常は不要だが念のため公開
local RE_LoadBattleSetReq = Remotes:WaitForChild("LoadBattleSet", 15)
if RE_LoadBattleSetReq then
    RE_LoadBattleSetReq.OnServerEvent:Connect(function(player)
        local key = "battleset_" .. player.UserId
        local ok, result = pcall(function() return BattleSetStore:GetAsync(key) end)
        if RE_BattleSetLoaded then
            RE_BattleSetLoaded:FireClient(player, (ok and result) or {slot1libId=1, slot2libId=2})
        end
    end)
end

print("✅ BattleServer_v2 EXPhase/Deck handlers loaded")

-- ============================================
-- StartGame BindableFunction（Matchmakingから呼ばれる）
-- ============================================
local RE_OpenBattleSet = Remotes:WaitForChild("OpenBattleSet", 15)

local StartGameFunc = Instance.new("BindableFunction")
StartGameFunc.Name   = "StartGame"
StartGameFunc.Parent = ReplicatedStorage
StartGameFunc.OnInvoke = function(playerDefs, mode, roomId)
    -- バトルセット選択画面を先に開く
    if RE_OpenBattleSet then
        for _, pd in ipairs(playerDefs) do
            if pd.isHuman then
                local pl = Players:GetPlayerByUserId(pd.userId)
                if pl then
                    RE_OpenBattleSet:FireClient(pl)
                end
            end
        end
    end
    -- 少し待ってからゲーム開始（クライアントがバトルセット確認する時間）
    task.wait(5)
    return startGame(playerDefs, mode, roomId)
end

-- ============================================
-- デッキレシピ公開システム
-- ============================================
local RecipeDS    = DataStoreService:GetDataStore("DeckRecipes_v1")
local RecipeCache = nil

local function loadRecipes()
    if RecipeCache then return RecipeCache end
    local ok, val = pcall(function() return RecipeDS:GetAsync("recipes") end)
    RecipeCache = (ok and val) or {}
    return RecipeCache
end

local function saveRecipes()
    if RecipeCache then
        pcall(function() RecipeDS:SetAsync("recipes", RecipeCache) end)
    end
end

local RE_DeckRecipe2 = Remotes:WaitForChild("DeckRecipe", 15)
if RE_DeckRecipe2 then
    RE_DeckRecipe2.OnServerEvent:Connect(function(player, data)
        if not data then return end
        local uid = player.UserId
        if data.type == "publish" then
            local recipes = loadRecipes()
            local found = false
            for i, r in ipairs(recipes) do
                if r.authorId == uid then
                    recipes[i].title = (data.title or ""):sub(1,20)
                    recipes[i].cards = data.cards or {}
                    recipes[i].updatedAt = os.time()
                    found = true; break
                end
            end
            if not found then
                table.insert(recipes, {
                    id=tostring(uid).."_"..tostring(os.time()),
                    title=(data.title or "名無しデッキ"):sub(1,20),
                    authorId=uid, authorName=player.Name,
                    cards=data.cards or {}, likes=0, updatedAt=os.time(),
                })
            end
            while #recipes > 100 do table.remove(recipes, 1) end
            RecipeCache = recipes; saveRecipes()
            RE_DeckRecipe2:FireClient(player, {type="published", message="デッキを公開しました！"})
        elseif data.type == "list" then
            local recipes = loadRecipes()
            table.sort(recipes, function(a,b) return (a.likes or 0) > (b.likes or 0) end)
            RE_DeckRecipe2:FireClient(player, {type="recipe_list", recipes=recipes})
        elseif data.type == "like" then
            local recipes = loadRecipes()
            for _, r in ipairs(recipes) do
                if r.id == data.id and r.authorId ~= uid then
                    r.likes = (r.likes or 0) + 1
                    RecipeCache = recipes; saveRecipes()
                    RE_DeckRecipe2:FireClient(player, {type="liked", id=data.id, likes=r.likes})
                    break
                end
            end
        elseif data.type == "copy" then
            local recipes = loadRecipes()
            for _, r in ipairs(recipes) do
                if r.id == data.id then
                    pcall(function() DeckStore:SetAsync("deck_"..uid, {mainDeck=r.cards, libId=1}) end)
                    RE_DeckRecipe2:FireClient(player, {
                        type="copied", cards=r.cards,
                        message=string.format("「%s」をコピーしました", r.title or "?"),
                    })
                    break
                end
            end
        end
    end)
end

-- StartBattleRoyaleMatch BindableFunction（BattleRoyale_4pから呼ばれる）
local BR4pMatchFunc = Instance.new("BindableFunction")
BR4pMatchFunc.Name   = "StartBattleRoyaleMatch"
BR4pMatchFunc.Parent = ReplicatedStorage
BR4pMatchFunc.OnInvoke = function(playerDefs, mode, roomId)
    -- アルカナフェーズ込みのゲームを実行して勝者を返す
    local gs = createGameState(playerDefs, mode or "br4p")
    gs.roomId = roomId

    -- アルカナデッキを各プレイヤーに配布
    for _, p in ipairs(gs.playerList) do
        p.arcana     = ArcanaSystem.buildArcana()
        p.arcanaUsed = {}
    end

    ActiveGames[roomId] = {gs=gs}

    -- coroutineでゲームループ実行（完了まで待つ）
    local done  = false
    local winner = nil
    local co = coroutine.create(function()
        gameLoop(roomId, gs)
        done   = true
        winner = gs.victory
    end)
    coroutine.resume(co)

    -- 完了を待つ（最大5分）
    local waited = 0
    while not done and waited < 300 do
        task.wait(1)
        waited = waited + 1
    end

    ActiveGames[roomId] = nil
    -- 勝利チームから代表プレイヤーIDを返す
    if winner then
        for _, p in ipairs(gs.playerList) do
            if p.team == winner then return p.id end
        end
    end
    return nil
end

-- 観戦モード Remote
local RE_Observe = Remotes:WaitForChild("Observe", 15)
if RE_Observe then
    RE_Observe.OnServerEvent:Connect(function(player, data)
        if not data then return end
        local uid = player.UserId
        if data.type == "join" then
            local roomId = data.roomId
            if not ActiveGames[roomId] then
                RE_UpdateBoard:FireClient(player, {type="observe_error", message="試合が見つかりません"})
                return
            end
            Observers[roomId] = Observers[roomId] or {}
            -- 重複チェック
            for _, id in ipairs(Observers[roomId]) do
                if id == uid then return end
            end
            table.insert(Observers[roomId], uid)
            -- 観戦開始: 現在の盤面状態を送信
            local gs = ActiveGames[roomId].gs
            RE_UpdateBoard:FireClient(player, {
                type       = "observe_start",
                roomId     = roomId,
                turn       = gs.turn,
                playerList = (function()
                    local t = {}
                    for _, p in ipairs(gs.playerList) do
                        table.insert(t, {id=p.id, name=p.name, team=p.team})
                    end
                    return t
                end)(),
            })
        elseif data.type == "leave" then
            for roomId, obs in pairs(Observers) do
                for i, id in ipairs(obs) do
                    if id == uid then table.remove(obs, i); break end
                end
            end
        elseif data.type == "list" then
            -- 現在進行中の試合一覧
            local games = {}
            for roomId, gd in pairs(ActiveGames) do
                if not gd.gs.isFriendMatch then  -- フレンド対戦は非公開
                    table.insert(games, {
                        roomId    = roomId,
                        turn      = gd.gs.turn or 0,
                        players   = (function()
                            local t = {}
                            for _, p in ipairs(gd.gs.playerList) do
                                table.insert(t, p.name)
                            end
                            return t
                        end)(),
                    })
                end
            end
            RE_UpdateBoard:FireClient(player, {type="game_list", games=games})
        end
    end)
end

print("✅ BattleServer_v2 StartGame BindableFunction registered")
