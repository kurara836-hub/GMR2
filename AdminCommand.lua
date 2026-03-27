-- AdminCommand.lua
-- 管理者専用コマンド（Server側）
-- 使い方: チャットで /givepack [UserID] [枚数]

local Players            = game:GetService("Players")
local ServerScriptService= game:GetService("ServerScriptService")

-- ══════════════════════════════════════════
-- 管理者UserID（自分のRobloxIDに変える）
-- ══════════════════════════════════════════
local ADMIN_IDS = {
    000000000,  -- ← 自分のRobloxUserIDに差し替え
}

local function isAdmin(userId)
    for _, id in ipairs(ADMIN_IDS) do
        if id == userId then return true end
    end
    return false
end

-- ══════════════════════════════════════════
-- コマンド処理
-- ══════════════════════════════════════════
local function handleCommand(player, message)
    if not isAdmin(player.UserId) then return end

    -- /givepack [UserID] [枚数]
    local targetId, amount = message:match("^/givepack%s+(%d+)%s+(%d+)")
    if targetId and amount then
        targetId = tonumber(targetId)
        amount   = tonumber(amount)
        if amount < 1 or amount > 100 then
            warn("[Admin] 枚数は1〜100の範囲で")
            return
        end

        local GachaSystem = require(ServerScriptService:WaitForChild("GachaSystem", 15))

        -- オンラインの場合は直接付与
        local targetPlayer = Players:GetPlayerByUserId(targetId)
        if targetPlayer then
            GachaSystem.AddTickets(targetPlayer, amount)
            print(("[Admin] %s (%d) にパック×%d を付与しました"):format(
                targetPlayer.Name, targetId, amount))
        else
            -- オフラインの場合はDataStoreに直接書き込む
            local DataStoreService = game:GetService("DataStoreService")
            local DS = DataStoreService:GetDataStore("PlayerData_v1")
            local ok, err = pcall(function()
                DS:UpdateAsync("player_" .. tostring(targetId), function(data)
                    if not data then
                        -- 初回ログイン前ならDEFAULT_DATAに乗っかれないので
                        -- voteTicketsだけ仮置きしてログイン時にマージされる
                        data = {voteTickets = 0}
                    end
                    data.voteTickets = (data.voteTickets or 0) + amount
                    return data
                end)
            end)
            if ok then
                print(("[Admin] オフラインユーザー %d にパック×%d をキューしました"):format(
                    targetId, amount))
            else
                warn("[Admin] DataStore書き込み失敗: " .. tostring(err))
            end
        end
        return
    end

    -- /whois [UserID] （確認用）
    local whoId = message:match("^/whois%s+(%d+)")
    if whoId then
        whoId = tonumber(whoId)
        local target = Players:GetPlayerByUserId(whoId)
        if target then
            print(("[Admin] %d = %s（オンライン）"):format(whoId, target.Name))
        else
            print(("[Admin] %d はオフラインまたは存在しないIDです"):format(whoId))
        end
        return
    end

    -- /startcontest [cardId]
    local contestCard = message:match("^/startcontest%s+(%S+)")
    if contestCard then
        local VS = ServerScriptService:WaitForChild("VoteSystem", 15)  -- スクリプト存在確認のみ
        VS.StartContest(contestCard)
        print("[Admin] コンテスト開始: " .. contestCard)
        return
    end

    -- /endcontest [cardId]
    local endCard = message:match("^/endcontest%s+(%S+)")
    if endCard then
        local VS = ServerScriptService:WaitForChild("VoteSystem", 15)  -- スクリプト存在確認のみ
        VS.EndContest(endCard)
        print("[Admin] コンテスト終了: " .. endCard)
        return
    end

    -- /adoptart [skinId] [suit] [rarity] [handdrawn/ai] [作者名(省略可)]
    -- 例: /adoptart kabu_fanart01 club R handdrawn きなこもち
    local adoptArgs = message:match("^/adoptart%s+(.+)")
    if adoptArgs then
        local parts = {}
        for w in adoptArgs:gmatch("%S+") do table.insert(parts, w) end
        local skinId   = parts[1]
        local suit     = parts[2] or "club"
        local rarity   = parts[3] or "R"
        local artType  = parts[4] or "handdrawn"
        local author   = parts[5]  -- nilでも可
        if skinId then
            local GS = require(ServerScriptService:WaitForChild("GachaSystem", 15))
            GS.RegisterFanArt(skinId, skinId, rarity, suit, artType, author)
            print(("[Admin] 採用: %s suit=%s rarity=%s type=%s author=%s"):format(
                skinId, suit, rarity, artType, tostring(author)))
        end
        return
    end

    -- ヘルプ
    if message:match("^/admin") then
        print("[Admin] コマンド一覧:")
        print("  /givepack [UserID] [枚数]          -- パック付与（1〜100）")
        print("  /whois [UserID]                    -- ユーザー確認")
        print("  /startcontest [cardId]             -- コンテスト開始")
        print("  /endcontest [cardId]               -- コンテスト終了")
        print("  /adoptart [id] [suit] [R] [type] [作者名] -- ファンアート採用")
    end
end

-- ══════════════════════════════════════════
-- チャット監視
-- ══════════════════════════════════════════
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        if message:sub(1,1) == "/" then
            handleCommand(player, message)
        end
    end)
end)

print("✅ AdminCommand.lua loaded")
