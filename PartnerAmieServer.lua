-- ============================================
-- GAMEROAD PartnerAmieServer.lua
-- ServerScriptService/ に配置（Script型）
--
-- PartnerAmie.lua（クライアント）のサーバー側
-- きずな値をDataStoreに永続保存する
-- ============================================

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_Amie = Remotes:WaitForChild("PartnerAmie", 15)

local BondDS  = DataStoreService:GetDataStore("PartnerBond_v1")
local LifeDS        = DataStoreService:GetDataStore("PartnerLifeData_v1")
local AnnouncementDS = DataStoreService:GetDataStore("Announcements_v1")

-- 告知キャッシュ
local AnnouncementCache = nil

local function loadAnnouncements()
    if AnnouncementCache then return AnnouncementCache end
    local ok, val = pcall(function() return AnnouncementDS:GetAsync("list") end)
    AnnouncementCache = (ok and val) or {}
    return AnnouncementCache
end

local function saveAnnouncements()
    if not AnnouncementCache then return end
    pcall(function() AnnouncementDS:SetAsync("list", AnnouncementCache) end)
end

-- デフォルト生活データ
local DEFAULT_LIFE = {
    -- 予定テンプレートID（設定済みかどうか）
    templateId   = nil,
    -- カスタム設定
    sleepTime    = nil,   -- "23:00" 形式
    wakeTime     = nil,   -- "07:00" 形式
    breakfastTime = nil,  -- "08:00" 形式
    lunchTime    = nil,   -- "12:00" 形式
    dinnerTime   = nil,   -- "18:00" 形式
    -- ログインカレンダー（日付→ログイン済みフラグ）
    calendar     = {},    -- {"2026-03-23": true, ...}
    -- 連続ログイン日数
    loginStreak  = 0,
    longestStreak = 0,
    firstLoginDate = nil,
    totalLoginDays  = 0,
}

-- メモリキャッシュ
local BondCache = {}   -- userId -> bond値
local LifeCache = {}   -- userId -> life data

local function loadLife(userId)
    if LifeCache[userId] then return LifeCache[userId] end
    local ok, val = pcall(function()
        return LifeDS:GetAsync("life_" .. userId)
    end)
    local life = {}
    if ok and val then
        -- マージ
        for k, v in pairs(DEFAULT_LIFE) do life[k] = v end
        for k, v in pairs(val) do life[k] = v end
    else
        for k, v in pairs(DEFAULT_LIFE) do life[k] = v end
    end
    LifeCache[userId] = life
    return life
end

local function saveLife(userId)
    local life = LifeCache[userId]
    if not life then return end
    pcall(function()
        LifeDS:SetAsync("life_" .. userId, life)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 読み込み・保存
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function loadBond(userId)
    if BondCache[userId] then return BondCache[userId] end
    local ok, val = pcall(function()
        return BondDS:GetAsync("bond_" .. userId)
    end)
    local bond = (ok and val) or 0
    BondCache[userId] = bond
    return bond
end

local function saveBond(userId, bond)
    BondCache[userId] = bond
    pcall(function()
        BondDS:SetAsync("bond_" .. userId, bond)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- クライアントからのイベント受信
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RE_Amie.OnServerEvent:Connect(function(player, data)
    local userId = player.UserId
    if not data then return end

    if data.type == "request_init" then
        -- 初期化：きずな値をクライアントに送る
        local bond = loadBond(userId)
        RE_Amie:FireClient(player, {type = "init", bond = bond})

    elseif data.type == "touch" or data.type == "petting"
        or data.type == "hug" or data.type == "topic" then
        -- きずな値を加算して保存
        local bond = loadBond(userId)
        bond = math.min(1000, bond + (data.bondGain or 0))
        saveBond(userId, bond)
        -- 確認として同期
        RE_Amie:FireClient(player, {type = "bond_sync", bond = bond})

    elseif data.type == "close" then
        -- 閉じる時に最終値を保存
        if data.bond then
            saveBond(userId, math.min(1000, data.bond))
        end

    elseif data.type == "open" then
        -- 生活データも一緒に返す
        local life = loadLife(userId)
        RE_Amie:FireClient(player, {
            type = "life_sync",
            life = life,
        })

    elseif data.type == "set_template" then
        -- テンプレート選択
        local life = loadLife(userId)
        local tmplId = data.templateId
        local TEMPLATES = {
            student  = {sleepTime="01:00", wakeTime="07:30", breakfastTime="08:00", lunchTime="12:30", dinnerTime="19:00"},
            office   = {sleepTime="24:00", wakeTime="07:00", breakfastTime="07:30", lunchTime="12:00", dinnerTime="20:00"},
            nightowl = {sleepTime="03:00", wakeTime="10:00", breakfastTime="11:00", lunchTime="14:00", dinnerTime="21:00"},
            hometime = {sleepTime="23:00", wakeTime="07:00", breakfastTime="08:00", lunchTime="12:00", dinnerTime="18:00"},
            freelance = {sleepTime="02:00", wakeTime="09:00", breakfastTime="10:00", lunchTime="13:00", dinnerTime="20:00"},
        }
        if TEMPLATES[tmplId] then
            life.templateId = tmplId
            for k, v in pairs(TEMPLATES[tmplId]) do life[k] = v end
            saveLife(userId)
        end
        RE_Amie:FireClient(player, {type = "life_sync", life = life})

    elseif data.type == "set_schedule" then
        -- 個別スケジュール設定
        local life = loadLife(userId)
        local allowed = {"sleepTime","wakeTime","breakfastTime","lunchTime","dinnerTime"}
        for _, key in ipairs(allowed) do
            if data[key] then life[key] = data[key] end
        end
        saveLife(userId)
        RE_Amie:FireClient(player, {type = "life_sync", life = life})

    -- 告知取得（全ユーザー）
    elseif data.type == "get_announcements" then
        local list = loadAnnouncements()
        RE_Amie:FireClient(player, {type="announcements", list=list})

    -- 告知投稿（管理者のみ）
    elseif data.type == "post_announcement" then
        local ADMIN_IDS = {000000000}  -- AdminCommand.luaと同じID
        local isAdmin = false
        for _, id in ipairs(ADMIN_IDS) do
            if uid == id then isAdmin = true; break end
        end
        if not isAdmin then
            RE_Amie:FireClient(player, {type="error", message="権限がありません"})
            return
        end
        local list = loadAnnouncements()
        local entry = {
            id       = tostring(uid) .. "_" .. tostring(os.time()),
            title    = (data.title or ""):sub(1, 50),
            body     = (data.body  or ""):sub(1, 200),
            category = data.category or "📢 お知らせ",
            date     = data.date or os.date("!%Y-%m-%d"),
            pin      = data.pin or false,   -- trueなら常に最上位
        }
        table.insert(list, entry)
        AnnouncementCache = list
        saveAnnouncements()
        -- 全プレイヤーに通知
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            RE_Amie:FireClient(p, {type="announcement_new", entry=entry})
        end

    -- 告知削除（管理者のみ）
    elseif data.type == "delete_announcement" then
        local ADMIN_IDS = {000000000}
        local isAdmin = false
        for _, id in ipairs(ADMIN_IDS) do
            if uid == id then isAdmin = true; break end
        end
        if not isAdmin then return end
        local list = loadAnnouncements()
        local newList = {}
        for _, e in ipairs(list) do
            if e.id ~= data.id then table.insert(newList, e) end
        end
        AnnouncementCache = newList
        saveAnnouncements()
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            RE_Amie:FireClient(p, {type="announcement_deleted", id=data.id})
        end

    elseif data.type == "checkin" then
        -- ログインチェックイン（カレンダー）
        local life = loadLife(userId)
        local today = os.date("!%Y-%m-%d")
        life.calendar = life.calendar or {}
        local isNew = not life.calendar[today]
        if isNew then
            life.calendar[today] = true
            life.totalLoginDays = (life.totalLoginDays or 0) + 1
            if not life.firstLoginDate then
                life.firstLoginDate = today
            end
            -- 連続ログイン計算
            local yesterday = os.date("!%Y-%m-%d", os.time() - 86400)
            if life.calendar[yesterday] then
                life.loginStreak = (life.loginStreak or 0) + 1
            else
                life.loginStreak = 1
            end
            life.longestStreak = math.max(life.longestStreak or 0, life.loginStreak)
            saveLife(userId)
        end
        RE_Amie:FireClient(player, {
            type     = "checkin_result",
            life     = life,
            isNew    = isNew,
        })
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ゲームプレイ報酬：バトル終了でもきずなを少し増やす
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local BondAutoFunc = Instance.new("BindableFunction")
BondAutoFunc.Name  = "AddPartnerBond"
BondAutoFunc.Parent = ReplicatedStorage
BondAutoFunc.OnInvoke = function(player, amount)
    local bond = loadBond(player.UserId)
    bond = math.min(1000, bond + (amount or 3))
    saveBond(player.UserId, bond)
    RE_Amie:FireClient(player, {type = "bond_sync", bond = bond})
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ログインボーナス：毎日初回ログインできずな+10
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local LoginDS = DataStoreService:GetDataStore("LoginBonus_v1")

Players.PlayerAdded:Connect(function(player)
    task.wait(3)  -- 初期化が終わるのを待つ

    -- きずなをロードして初期化
    local bond = loadBond(player.UserId)
    RE_Amie:FireClient(player, {type = "init", bond = bond})

    -- ログインボーナス確認 + カレンダーチェックイン
    local today = os.date("!%Y-%m-%d")
    local life = loadLife(player.UserId)
    life.calendar = life.calendar or {}
    local isNewDay = not life.calendar[today]

    if isNewDay then
        -- カレンダー更新
        life.calendar[today] = true
        life.totalLoginDays = (life.totalLoginDays or 0) + 1
        if not life.firstLoginDate then life.firstLoginDate = today end
        local yesterday = os.date("!%Y-%m-%d", os.time() - 86400)
        life.loginStreak = life.calendar[yesterday] and (life.loginStreak or 0) + 1 or 1
        life.longestStreak = math.max(life.longestStreak or 0, life.loginStreak)
        saveLife(player.UserId)
        -- きずな+10
        bond = math.min(1000, bond + 10)
        saveBond(player.UserId, bond)
        RE_Amie:FireClient(player, {
            type        = "bond_sync",
            bond        = bond,
            loginBonus  = true,
            loginStreak = life.loginStreak,
        })
    end
    -- 生活データ送信
    RE_Amie:FireClient(player, {type = "life_sync", life = life})
end)

Players.PlayerRemoving:Connect(function(player)
    -- 退出時に保存
    local bond = BondCache[player.UserId]
    if bond then saveBond(player.UserId, bond) end
    BondCache[player.UserId] = nil
end)

-- 5分ごとにオートセーブ
task.spawn(function()
    while true do
        task.wait(300)
        for userId, bond in pairs(BondCache) do
            pcall(function() BondDS:SetAsync("bond_" .. userId, bond) end)
        end
    end
end)

print("✅ PartnerAmieServer.lua loaded")
