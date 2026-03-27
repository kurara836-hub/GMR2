-- VoteSystem.lua
-- 転生投票システム
-- 👎777票でカード転生確定・Webhook通知・ガチャチケ自動配布
-- 👍777票で次弾確定収録フラグ

local DataStoreService = game:GetService("DataStoreService")
local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")

local VoteStore    = DataStoreService:GetDataStore("CardVotes_v1")
local HallStore    = DataStoreService:GetDataStore("HallOfFame_v1")   -- 殿堂入りフラグ
local GachaSystem  = require(game.ServerScriptService:WaitForChild("GachaSystem", 15))
local Remotes      = game.ReplicatedStorage:WaitForChild("Remotes", 15)

-- ══════════════════════════════════════════
-- 設定
-- ══════════════════════════════════════════
local THRESHOLD    = 777          -- 転生確定票数
local TICKET_GRANT = 1            -- 転生確定時に全所持者へ配布するガチャチケ数

-- Discord Webhook URL（公開後に差し替え）
local WEBHOOK_URL  = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"

-- カードマスタ（カードID → 表示名）
-- TCG版のカードが増えたらここに追記
local CARD_NAMES = {
    ["card_spade_A"]   = "♠A / スペードエース",
    ["card_heart_K"]   = "♥K / ハートキング",
    ["card_diamond_Q"] = "♦Q / ダイヤクイーン",
    ["card_club_J"]    = "♣J / クラブジャック",
    -- アルカナ
    ["arcana_0"]  = "アルカナ0 / 原初【エオ】",
    ["arcana_6"]  = "アルカナ6 / 恋人",
    ["arcana_13"] = "アルカナ13 / レックス",
    ["arcana_21"] = "アルカナ21 / アーケオ",
}

-- ══════════════════════════════════════════
-- 内部ユーティリティ
-- ══════════════════════════════════════════

-- DataStoreからカードの投票データを取得
local function getVoteData(cardId)
    local ok, data = pcall(function()
        return VoteStore:GetAsync(cardId)
    end)
    if ok and data then return data end
    return { up = 0, down = 0, rebirthConfirmed = false, upConfirmed = false }
end

-- 投票データを保存
local function saveVoteData(cardId, data)
    pcall(function()
        VoteStore:UpdateAsync(cardId, function() return data end)
    end)
end

-- 殿堂入りフラグを立てる
local function markHallOfFame(cardId)
    pcall(function()
        HallStore:SetAsync(cardId, {
            confirmedAt = os.time(),
            cardName    = CARD_NAMES[cardId] or cardId,
        })
    end)
end

-- 殿堂入り確認
local function isHallOfFame(cardId)
    local ok, data = pcall(function()
        return HallStore:GetAsync(cardId)
    end)
    return ok and data ~= nil
end

-- Discord Webhookに通知
local function sendWebhook(title, description, color)
    if not WEBHOOK_URL or WEBHOOK_URL == "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL" then
        warn("[VoteSystem] Webhook未設定 - コンソール出力のみ")
        print(string.format("[WEBHOOK] %s | %s", title, description))
        return
    end
    pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode({
            embeds = {{
                title       = title,
                description = description,
                color       = color or 16776960,
                timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }}
        }), Enum.HttpContentType.ApplicationJson)
    end)
end

-- オンラインの全プレイヤーにガチャチケを配布
local function grantTicketToAll(cardId)
    local cardName = CARD_NAMES[cardId] or cardId
    for _, player in ipairs(Players:GetPlayers()) do
        -- GachaSystem側にAddTickets関数があることを前提
        local ok, err = pcall(function()
            GachaSystem.AddTickets(player, TICKET_GRANT)
        end)
        if ok then
            -- クライアントに通知
            local re = Remotes:FindFirstChild("UpdateBoard")
            if re then
                re:FireClient(player, {
                    type      = "rebirth_ticket",
                    cardName  = cardName,
                    tickets   = TICKET_GRANT,
                    message   = string.format(
                        "【転生確定】%s が転生します！\nガチャチケット×%d を受け取りました",
                        cardName, TICKET_GRANT
                    ),
                })
            end
        else
            warn("[VoteSystem] チケット付与失敗:", player.Name, err)
        end
    end
    -- オフラインプレイヤーへの配布はDataStore経由（次回ログイン時に付与）
    -- → GachaSystem側のPendingRewards機構を使う（後述）
    local pendingKey = "PendingRebirth_" .. cardId
    pcall(function()
        VoteStore:SetAsync(pendingKey, {
            tickets   = TICKET_GRANT,
            cardName  = cardName,
            grantedAt = os.time(),
        })
    end)
end

-- ══════════════════════════════════════════
-- 転生確定処理
-- ══════════════════════════════════════════

local function confirmRebirth(cardId, data)
    if data.rebirthConfirmed then return end  -- 二重処理防止
    data.rebirthConfirmed = true
    saveVoteData(cardId, data)
    markHallOfFame(cardId)

    local cardName = CARD_NAMES[cardId] or cardId
    print(string.format("[VoteSystem] 転生確定: %s (%s)", cardName, cardId))

    -- Webhook通知
    sendWebhook(
        "🔄 転生確定！",
        string.format(
            "**%s** が転生カードとして確定しました。\n" ..
            "👎 票数: **%d** / %d\n" ..
            "旧カードは殿堂入り・全所持者にガチャチケ×%d を配布します。",
            cardName, data.down, THRESHOLD, TICKET_GRANT
        ),
        16711680  -- 赤
    )

    -- チケット配布
    grantTicketToAll(cardId)
end

local function confirmUpvote(cardId, data)
    if data.upConfirmed then return end
    data.upConfirmed = true
    saveVoteData(cardId, data)

    local cardName = CARD_NAMES[cardId] or cardId
    print(string.format("[VoteSystem] 次弾確定収録: %s (%s)", cardName, cardId))

    sendWebhook(
        "⭐ 次弾確定収録！",
        string.format(
            "**%s** が次弾ガチャに確定収録されます！\n" ..
            "👍 票数: **%d** / %d",
            cardName, data.up, THRESHOLD
        ),
        3329330  -- 緑
    )
    -- 次弾フラグはCardLibrary側で管理（将来拡張）
end

-- ══════════════════════════════════════════
-- 公開API
-- ══════════════════════════════════════════

local VoteSystem = {}

-- 投票処理（サーバーから呼ぶ）
-- direction: "up" | "down"
-- returns: ok, message
function VoteSystem.CastVote(player, cardId, direction)
    -- 殿堂入り済みカードは投票不可
    if isHallOfFame(cardId) then
        return false, "このカードは既に転生済みです"
    end

    -- カードIDの存在チェック
    if not CARD_NAMES[cardId] then
        return false, "不明なカードID"
    end

    -- 投票権消費（GachaSystemに委譲）
    local ok, err = pcall(function()
        GachaSystem.UseVoteTicket(player, 1)
    end)
    if not ok then
        return false, "投票権が不足しています"
    end

    -- 投票カウント更新
    local data = getVoteData(cardId)
    if direction == "down" then
        data.down = (data.down or 0) + 1
        if data.down >= THRESHOLD and not data.rebirthConfirmed then
            confirmRebirth(cardId, data)
        end
    elseif direction == "up" then
        data.up = (data.up or 0) + 1
        if data.up >= THRESHOLD and not data.upConfirmed then
            confirmUpvote(cardId, data)
        end
    else
        return false, "不正なdirection"
    end

    saveVoteData(cardId, data)

    return true, string.format(
        "%s: 👍%d / 👎%d",
        CARD_NAMES[cardId] or cardId, data.up, data.down
    )
end

-- 票数照会（UIに表示用）
function VoteSystem.GetVoteData(cardId)
    return getVoteData(cardId)
end

-- 殿堂入り確認
function VoteSystem.IsHallOfFame(cardId)
    return isHallOfFame(cardId)
end

-- ログイン時のPending報酬チェック（GachaSystemから呼ぶ）
function VoteSystem.CheckPendingRewards(player)
    -- PendingRebirth_* キーを全スキャンは高コストなので
    -- ログイン時にクライアントへ「確認してください」通知を出すだけにする
    -- 実際の付与タイミングは次回の転生確定時にオンラインの場合
    -- → シンプルさ優先・将来拡張ポイントとして残す
end

-- RemoteEvent経由の投票受付
local RE_Vote = Remotes:WaitForChild("CardVote", 15)

RE_Vote.OnServerEvent:Connect(function(player, cardId, direction)
    local ok, msg = VoteSystem.CastVote(player, cardId, direction)
    local re = Remotes:FindFirstChild("UpdateBoard")
    if re then
        re:FireClient(player, {
            type      = "vote_result",
            success   = ok,
            message   = msg,
            cardId    = cardId,
            direction = direction,
        })
    end
end)

print("✅ VoteSystem.lua loaded | 閾値:", THRESHOLD, "票")

-- ══════════════════════════════════════════
-- コンテスト開催フラグ（AdminCommandから操作）
-- 転生と独立しているので別途 /startcontest で手動管理
-- ══════════════════════════════════════════
local ContestActive = {}  -- {cardId = true} の形で管理

function VoteSystem.StartContest(cardId)
    ContestActive[cardId] = true
    print("[VoteSystem] コンテスト開始: " .. cardId)
end

function VoteSystem.EndContest(cardId)
    ContestActive[cardId] = nil
    print("[VoteSystem] コンテスト終了: " .. cardId)
end

function VoteSystem.IsContestActive(cardId)
    return ContestActive[cardId] == true
end

return VoteSystem

