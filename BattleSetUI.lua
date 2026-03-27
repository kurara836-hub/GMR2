-- BattleSetUI.lua
-- バトル登録UI
-- ライブラリ(1〜8)から2枠を選んでバトルにセットする
-- デッキの中身編集は DeckEditUI で行う

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local RS            = game:GetService("ReplicatedStorage")
local Remotes       = RS:WaitForChild("Remotes", 10)
local RE_SaveBattleSet = Remotes:WaitForChild("SaveBattleSet", 15)

local player = Players.LocalPlayer

-- ═══════════════════════════════════════
-- 定数
-- ═══════════════════════════════════════
local LIB_COUNT   = 8   -- ライブラリ枠数
local BATTLE_SLOT = 2   -- バトル登録枠数（固定）

local COL_BG    = Color3.fromRGB(18, 12, 32)
local COL_PANEL = Color3.fromRGB(28, 20, 48)
local COL_SEL   = Color3.fromRGB(80, 40, 160)
local COL_SLOT  = {
    Color3.fromRGB(40, 120, 180),   -- スロット1: 青
    Color3.fromRGB(180, 80, 40),    -- スロット2: 橙
}

-- ═══════════════════════════════════════
-- 状態
-- ═══════════════════════════════════════
local state = {
    -- バトル登録中のlibId（0=未登録）
    battleSlots  = {0, 0},
    -- ライブラリのデッキ名キャッシュ（libId→名前文字列）
    libNames     = {},
    -- ドラッグ中のlibId（0=なし）
    dragging     = 0,
}

-- ═══════════════════════════════════════
-- UI構築
-- ═══════════════════════════════════════
local screen = Instance.new("ScreenGui")
screen.Name            = "BattleSetUI"
screen.ResetOnSpawn    = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screen.Enabled         = false
screen.Parent          = player.PlayerGui

local bg = Instance.new("Frame")
bg.Size              = UDim2.new(0.92, 0, 0.82, 0)
bg.Position          = UDim2.new(0.04, 0, 0.09, 0)
bg.BackgroundColor3  = COL_BG
bg.BorderSizePixel   = 0
bg.Parent            = screen
local bgc = Instance.new("UICorner"); bgc.CornerRadius=UDim.new(0,14); bgc.Parent=bg

-- タイトル
local title = Instance.new("TextLabel")
title.Size             = UDim2.new(1, -50, 0.07, 0)
title.Position         = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text             = "⚔ バトルデッキ登録"
title.TextColor3       = Color3.new(1,1,1)
title.Font             = Enum.Font.GothamBold
title.TextScaled       = true
title.TextXAlignment   = Enum.TextXAlignment.Left
title.Parent           = bg

-- 閉じるボタン
local closeBtn = Instance.new("TextButton")
closeBtn.Size            = UDim2.new(0, 44, 0, 44)
closeBtn.Position        = UDim2.new(1, -50, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(80,30,30)
closeBtn.Text            = "✕"
closeBtn.TextColor3      = Color3.new(1,1,1)
closeBtn.TextScaled      = true
closeBtn.Font            = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent          = bg
local cc = Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,8); cc.Parent=closeBtn
closeBtn.MouseButton1Click:Connect(function() screen.Enabled = false end)

-- 説明文
local hint = Instance.new("TextLabel")
hint.Size             = UDim2.new(1, -20, 0.06, 0)
hint.Position         = UDim2.new(0, 10, 0.07, 0)
hint.BackgroundTransparency = 1
hint.Text             = "バトルで使うデッキを2枠選んで登録。スート割り当てに合わせて自動で選ばれます。"
hint.TextColor3       = Color3.fromRGB(180, 170, 210)
hint.Font             = Enum.Font.Gotham
hint.TextScaled       = true
hint.TextXAlignment   = Enum.TextXAlignment.Left
hint.Parent           = bg

-- ── バトル登録枠（上段）──
local battleArea = Instance.new("Frame")
battleArea.Size            = UDim2.new(1, -20, 0.2, 0)
battleArea.Position        = UDim2.new(0, 10, 0.14, 0)
battleArea.BackgroundColor3 = Color3.fromRGB(12, 8, 24)
battleArea.BorderSizePixel = 0
battleArea.Parent          = bg
local bac = Instance.new("UICorner"); bac.CornerRadius=UDim.new(0,10); bac.Parent=battleArea

local battleSlotFrames = {}
for s = 1, BATTLE_SLOT do
    local f = Instance.new("Frame")
    f.Size            = UDim2.new(0.48, -6, 0.82, 0)
    f.Position        = UDim2.new((s-1)*0.5 + 0.01, 0, 0.09, 0)
    f.BackgroundColor3 = COL_PANEL
    f.BorderSizePixel = 0
    f.Parent          = battleArea
    local fc = Instance.new("UICorner"); fc.CornerRadius=UDim.new(0,8); fc.Parent=f

    -- 枠ラベル（スロット1 / スロット2）
    local label = Instance.new("TextLabel")
    label.Size             = UDim2.new(0.4, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text             = "登録枠 " .. s
    label.TextColor3       = COL_SLOT[s]
    label.Font             = Enum.Font.GothamBold
    label.TextScaled       = true
    label.TextXAlignment   = Enum.TextXAlignment.Left
    label.Position         = UDim2.new(0.02, 0, 0, 0)
    label.Parent           = f

    -- 登録中のデッキ名
    local deckName = Instance.new("TextLabel")
    deckName.Size             = UDim2.new(0.55, 0, 1, 0)
    deckName.Position         = UDim2.new(0.4, 0, 0, 0)
    deckName.BackgroundTransparency = 1
    deckName.Text             = "（未登録）"
    deckName.TextColor3       = Color3.fromRGB(160, 160, 160)
    deckName.Font             = Enum.Font.Gotham
    deckName.TextScaled       = true
    deckName.TextXAlignment   = Enum.TextXAlignment.Right
    deckName.Name             = "DeckName"
    deckName.Parent           = f

    battleSlotFrames[s] = f
end

-- ── ライブラリ一覧（下段）──
local libLabel = Instance.new("TextLabel")
libLabel.Size             = UDim2.new(1, -20, 0.05, 0)
libLabel.Position         = UDim2.new(0, 10, 0.36, 0)
libLabel.BackgroundTransparency = 1
libLabel.Text             = "▼ デッキライブラリ（タップして登録枠に追加）"
libLabel.TextColor3       = Color3.fromRGB(200,190,230)
libLabel.Font             = Enum.Font.GothamBold
libLabel.TextScaled       = true
libLabel.TextXAlignment   = Enum.TextXAlignment.Left
libLabel.Parent           = bg

local libGrid = Instance.new("Frame")
libGrid.Size            = UDim2.new(1, -20, 0.48, 0)
libGrid.Position        = UDim2.new(0, 10, 0.42, 0)
libGrid.BackgroundColor3 = Color3.fromRGB(12, 8, 24)
libGrid.BorderSizePixel = 0
libGrid.Parent          = bg
local lgc = Instance.new("UICorner"); lgc.CornerRadius=UDim.new(0,10); lgc.Parent=libGrid

-- 4列2行グリッドでライブラリカードを表示
local libCards = {}
for i = 1, LIB_COUNT do
    local row = math.floor((i-1) / 4)
    local col = (i-1) % 4

    local card = Instance.new("TextButton")
    card.Size            = UDim2.new(0.235, -4, 0.46, -4)
    card.Position        = UDim2.new(col * 0.25 + 0.005, 0, row * 0.5 + 0.02, 0)
    card.BackgroundColor3 = COL_PANEL
    card.BorderSizePixel = 0
    card.Text            = "デッキ " .. i .. "\n（空）"
    card.TextColor3      = Color3.fromRGB(140, 140, 160)
    card.Font            = Enum.Font.Gotham
    card.TextScaled      = true
    card.Name            = "lib_" .. i
    card.Parent          = libGrid
    local lcc = Instance.new("UICorner"); lcc.CornerRadius=UDim.new(0,8); lcc.Parent=card

    libCards[i] = card
end

-- ── 保存ボタン ──
local saveBtn = Instance.new("TextButton")
saveBtn.Size            = UDim2.new(0.6, 0, 0.07, 0)
saveBtn.Position        = UDim2.new(0.2, 0, 0.92, 0)
saveBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 40)
saveBtn.Text            = "💾 バトルセット確定"
saveBtn.TextColor3      = Color3.new(1,1,1)
saveBtn.Font            = Enum.Font.GothamBold
saveBtn.TextScaled      = true
saveBtn.BorderSizePixel = 0
saveBtn.Parent          = bg
local sbc = Instance.new("UICorner"); sbc.CornerRadius=UDim.new(0,10); sbc.Parent=saveBtn

-- ═══════════════════════════════════════
-- 表示更新
-- ═══════════════════════════════════════
local function refreshBattleSlots()
    for s = 1, BATTLE_SLOT do
        local libId = state.battleSlots[s]
        local nameLabel = battleSlotFrames[s]:FindFirstChild("DeckName")
        if libId > 0 then
            local name = state.libNames[libId] or ("デッキ " .. libId)
            if nameLabel then
                nameLabel.Text      = name
                nameLabel.TextColor3 = COL_SLOT[s]
            end
            battleSlotFrames[s].BackgroundColor3 = Color3.fromRGB(30, 24, 54)
        else
            if nameLabel then
                nameLabel.Text      = "（未登録）"
                nameLabel.TextColor3 = Color3.fromRGB(160,160,160)
            end
            battleSlotFrames[s].BackgroundColor3 = COL_PANEL
        end
    end
end

local function refreshLibCards()
    for i = 1, LIB_COUNT do
        local card = libCards[i]
        local name = state.libNames[i]
        -- バトル登録状態の色表示
        local inSlot = 0
        for s = 1, BATTLE_SLOT do
            if state.battleSlots[s] == i then inSlot = s; break end
        end
        if name then
            card.Text = "デッキ " .. i .. "\n" .. name
            if inSlot > 0 then
                card.BackgroundColor3 = COL_SLOT[inSlot]
                card.TextColor3 = Color3.new(1,1,1)
            else
                card.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
                card.TextColor3 = Color3.new(1,1,1)
            end
        else
            card.Text = "デッキ " .. i .. "\n（空）"
            card.BackgroundColor3 = COL_PANEL
            card.TextColor3 = Color3.fromRGB(100,100,120)
        end
    end
end

-- ═══════════════════════════════════════
-- ライブラリカードタップで登録
-- ─  未登録枠がある→そこに追加
-- ─  両枠埋まっている→スロット1を置き換え
-- ─  既に登録済み→解除（その枠をゼロに）
-- ═══════════════════════════════════════
for i, card in ipairs(libCards) do
    card.MouseButton1Click:Connect(function()
        -- 既に登録済みなら解除
        for s = 1, BATTLE_SLOT do
            if state.battleSlots[s] == i then
                state.battleSlots[s] = 0
                refreshBattleSlots()
                refreshLibCards()
                return
            end
        end
        -- 空き枠を探して登録
        for s = 1, BATTLE_SLOT do
            if state.battleSlots[s] == 0 then
                state.battleSlots[s] = i
                refreshBattleSlots()
                refreshLibCards()
                return
            end
        end
        -- 空き枠なし → スロット1を置き換え
        state.battleSlots[1] = i
        refreshBattleSlots()
        refreshLibCards()
    end)
end

-- ═══════════════════════════════════════
-- 保存
-- ═══════════════════════════════════════
saveBtn.MouseButton1Click:Connect(function()
    if state.battleSlots[1] == 0 and state.battleSlots[2] == 0 then return end
    RE_SaveBattleSet:FireServer({
        slot1libId = state.battleSlots[1],
        slot2libId = state.battleSlots[2],
    })
    -- 保存フラッシュ + カウントダウン表示
    TweenService:Create(saveBtn, TweenInfo.new(0.1),
        {BackgroundColor3 = Color3.fromRGB(100,200,100)}):Play()
    saveBtn.Text = "✅ 保存完了！まもなくバトル開始..."
    task.delay(0.4, function()
        TweenService:Create(saveBtn, TweenInfo.new(0.2),
            {BackgroundColor3 = Color3.fromRGB(40,120,40)}):Play()
    end)
    -- 5秒カウントダウン
    task.spawn(function()
        for i = 5, 1, -1 do
            saveBtn.Text = "⚔ バトル開始まで " .. i .. "秒..."
            task.wait(1)
        end
        screen.Enabled = false
    end)
end)

-- ═══════════════════════════════════════
-- サーバーからの返却処理
-- ═══════════════════════════════════════
-- バトルセット確定後に最新状態が返ってくる
local RE_BattleSetLoaded = Remotes:WaitForChild("BattleSetLoaded", 10)
if RE_BattleSetLoaded then
    RE_BattleSetLoaded.OnClientEvent:Connect(function(data)
        if not data then return end
        state.battleSlots[1] = data.slot1libId or 0
        state.battleSlots[2] = data.slot2libId or 0
        refreshBattleSlots()
        refreshLibCards()
    end)
end

-- デッキ名はDeckLoadedでキャッシュする（DeckEditUIとリモート共有）
local RE_DeckLoaded = Remotes:WaitForChild("DeckLoaded", 10)
if RE_DeckLoaded then
    RE_DeckLoaded.OnClientEvent:Connect(function(data)
        -- DeckEditUIが受け取ったデータのうちデッキ名をここでもキャッシュ
        -- data.libId が返却されていれば使う（将来拡張）
        -- 現状はDeckEditUI側のlibIdを参照できないため、
        -- 画面オープン時に全枠分ロードするアプローチを取る
    end)
end

-- ═══════════════════════════════════════
-- 画面オープン時：バトルセット + ライブラリ名を一括取得
-- ═══════════════════════════════════════
local RF_GetLibraryNames = Remotes:WaitForChild("GetLibraryNames", 10)

local function reloadAll()
    -- バトルセット取得
    local lbRemote = Remotes:FindFirstChild("LoadBattleSet")
    if lbRemote then lbRemote:FireServer() end
    -- ライブラリ名を一括取得（RemoteFunction）
    if RF_GetLibraryNames then
        task.spawn(function()
            local ok, names = pcall(function()
                return RF_GetLibraryNames:InvokeServer()
            end)
            if ok and names then
                for i = 1, LIB_COUNT do
                    state.libNames[i] = names[i]  -- nil は空枠
                end
                refreshLibCards()
            end
        end)
    end
end

local RE_OpenBattleSet = Remotes:WaitForChild("OpenBattleSet", 15)
if RE_OpenBattleSet then
    RE_OpenBattleSet.OnClientEvent:Connect(function()
        screen.Enabled = true
        reloadAll()
    end)
end
