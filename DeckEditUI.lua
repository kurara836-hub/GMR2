-- DeckEditUI.lua
-- StarterPlayerScripts/DeckEditUI
-- デッキ編集画面（シャドバ式）

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)
local CardData    = require(ReplicatedStorage:WaitForChild("CardData", 15))
local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui", 15)

-- ═══════════════════════════════════════
-- 定数
-- ═══════════════════════════════════════
local MAIN_LIMIT = 30
local EX_LIMIT   = 7
local SAME_CARD_MAX = 2  -- 同名カード最大枚数

local SUIT_COLOR = {
    club    = Color3.fromRGB(40,  160, 40),
    heart   = Color3.fromRGB(200, 60,  80),
    diamond = Color3.fromRGB(200, 140, 30),
    spade   = Color3.fromRGB(60,  100, 200),
}
local RARITY_COLOR = {
    C  = Color3.fromRGB(160, 160, 160),
    R  = Color3.fromRGB(80,  160, 220),
    SR = Color3.fromRGB(220, 180, 40),
}

-- ═══════════════════════════════════════
-- 状態管理
-- ═══════════════════════════════════════
local state = {
    libId         = 1,           -- 編集中のデッキ番号（ライブラリ1〜8）
    mainDeck      = {},
    exDeck        = {},
    oshiCardId    = nil,
    filter        = {
        suit   = "all",
        rarity = "all",
        text   = "",
        zone   = "main",
    },
    allCards      = {},
}

-- ═══════════════════════════════════════
-- ヘルパー
-- ═══════════════════════════════════════
local function mainCount()
    local n = 0
    for _, e in ipairs(state.mainDeck) do n = n + e.count end
    return n
end

local function exCount() return #state.exDeck end

local function findMain(cardId)
    for i, e in ipairs(state.mainDeck) do
        if e.cardId == cardId then return i, e end
    end
    return nil
end

local function addMain(cardId)
    if mainCount() >= MAIN_LIMIT then return false, "デッキが30枚です" end
    local i, e = findMain(cardId)
    if e then
        if e.count >= SAME_CARD_MAX then return false, "同名カードは2枚まで" end
        e.count = e.count + 1
    else
        table.insert(state.mainDeck, {cardId=cardId, count=1})
    end
    return true
end

local function removeMain(cardId)
    local i, e = findMain(cardId)
    if not e then return end
    e.count = e.count - 1
    if e.count <= 0 then table.remove(state.mainDeck, i) end
end

-- EXカードのデッキ制限（deckLimit=1のカードIDリスト）
-- カードテキストで「このカードはEXに1枚まで」と書かれているカード
local EX_DECK_LIMIT_1 = {
    ["harnia_kodou"]  = true,  -- ハルニアの鼓動（必須1枚）
    ["coord_tops"]    = true,  -- コーデ：トップス
    ["coord_bottoms"] = true,  -- コーデ：ボトムス
    ["coord_shoes"]   = true,  -- コーデ：シューズ
    ["coord_acc"]     = true,  -- コーデ：アクセ
    -- DinoSystem EX恐竜カードも原則1枚制限
}

local function addEX(cardId)
    if exCount() >= EX_LIMIT then return false, "EXは7枚まで" end
    -- deckLimit=1チェック（同一カードが既に入っているか）
    if EX_DECK_LIMIT_1[cardId] then
        for _, id in ipairs(state.exDeck) do
            if id == cardId then
                return false, "このカードはEXに1枚まで（カードテキスト制限）"
            end
        end
    end
    table.insert(state.exDeck, cardId)
    return true
end

local function removeEX(index)
    table.remove(state.exDeck, index)
end

-- ═══════════════════════════════════════
-- UI生成
-- ═══════════════════════════════════════
local screen = Instance.new("ScreenGui")
screen.Name = "DeckEditUI"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Enabled = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- 背景
local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
bg.BorderSizePixel = 0
bg.Parent = screen

-- ── ヘッダー ──
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0.06, 0)
header.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
header.BorderSizePixel = 0
header.Parent = bg

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.3, 0, 1, 0)
titleLabel.Position = UDim2.new(0.35, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "デッキ編集"
titleLabel.TextColor3 = Color3.fromRGB(212, 160, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = header

-- 閉じるボタン
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.06, 0, 0.8, 0)
closeBtn.Position = UDim2.new(0.93, 0, 0.1, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header
local cc = Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,6); cc.Parent=closeBtn

-- ── デッキライブラリ選択（8枠）──
-- バトルへの登録は別画面（BattleSetUI）で行う
local slotBar = Instance.new("Frame")
slotBar.Size = UDim2.new(1, 0, 0.06, 0)
slotBar.Position = UDim2.new(0, 0, 0.06, 0)
slotBar.BackgroundColor3 = Color3.fromRGB(12, 8, 24)
slotBar.BorderSizePixel = 0
slotBar.Parent = bg

local slotBtns = {}
for i = 1, 8 do
    local sb = Instance.new("TextButton")
    sb.Size = UDim2.new(0.125, -3, 0.82, 0)
    sb.Position = UDim2.new((i-1)*0.125, 2, 0.09, 0)
    sb.BackgroundColor3 = i==1
        and Color3.fromRGB(80, 40, 160)
        or  Color3.fromRGB(30, 20, 50)
    sb.Text = tostring(i)
    sb.TextColor3 = Color3.new(1,1,1)
    sb.TextScaled = true
    sb.Font = Enum.Font.Gotham
    sb.BorderSizePixel = 0
    sb.Parent = slotBar
    local sc = Instance.new("UICorner"); sc.CornerRadius=UDim.new(0,5); sc.Parent=sb
    slotBtns[i] = sb
end

-- ── 3カラムレイアウト ──
-- 左: カードリスト（フィルター付き）
-- 中: デッキ内容（メイン/EX切替）
-- 右: 推しカード・カウンター・保存

local bodyY = 0.12

-- ─── 左カラム: カードリスト ───
local leftCol = Instance.new("Frame")
leftCol.Size = UDim2.new(0.5, -4, 1 - bodyY - 0.01, 0)
leftCol.Position = UDim2.new(0, 2, bodyY, 0)
leftCol.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
leftCol.BorderSizePixel = 0
leftCol.Parent = bg

-- フィルターバー
local filterBar = Instance.new("Frame")
filterBar.Size = UDim2.new(1, 0, 0.1, 0)
filterBar.BackgroundColor3 = Color3.fromRGB(15, 12, 28)
filterBar.BorderSizePixel = 0
filterBar.Parent = leftCol

-- ゾーン切替（メイン/EX）
local zoneMain = Instance.new("TextButton")
zoneMain.Size = UDim2.new(0.18, -2, 0.7, 0)
zoneMain.Position = UDim2.new(0, 2, 0.15, 0)
zoneMain.BackgroundColor3 = Color3.fromRGB(80, 40, 160)
zoneMain.Text = "メイン"
zoneMain.TextColor3 = Color3.new(1,1,1)
zoneMain.TextScaled = true
zoneMain.Font = Enum.Font.GothamBold
zoneMain.BorderSizePixel = 0
zoneMain.Parent = filterBar
local zmc = Instance.new("UICorner"); zmc.CornerRadius=UDim.new(0,4); zmc.Parent=zoneMain

local zoneEX = Instance.new("TextButton")
zoneEX.Size = UDim2.new(0.12, -2, 0.7, 0)
zoneEX.Position = UDim2.new(0.19, 2, 0.15, 0)
zoneEX.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
zoneEX.Text = "EX"
zoneEX.TextColor3 = Color3.fromRGB(180,180,180)
zoneEX.TextScaled = true
zoneEX.Font = Enum.Font.Gotham
zoneEX.BorderSizePixel = 0
zoneEX.Parent = filterBar
local zec = Instance.new("UICorner"); zec.CornerRadius=UDim.new(0,4); zec.Parent=zoneEX

-- テキスト検索
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(0.36, -4, 0.7, 0)
searchBox.Position = UDim2.new(0.32, 2, 0.15, 0)
searchBox.BackgroundColor3 = Color3.fromRGB(20, 16, 36)
searchBox.Text = ""
searchBox.PlaceholderText = "カード名で検索..."
searchBox.TextColor3 = Color3.new(1,1,1)
searchBox.PlaceholderColor3 = Color3.fromRGB(100,100,100)
searchBox.TextScaled = true
searchBox.Font = Enum.Font.Gotham
searchBox.BorderSizePixel = 0
searchBox.Parent = filterBar
local src = Instance.new("UICorner"); src.CornerRadius=UDim.new(0,4); src.Parent=searchBox

-- スートフィルター
local suitLabels = {"全","♧","♥","♦","♤"}
local suitKeys   = {"all","club","heart","diamond","spade"}
local suitFilterBtns = {}
for i, label in ipairs(suitLabels) do
    local fb = Instance.new("TextButton")
    fb.Size = UDim2.new(0.095, -2, 0.7, 0)
    fb.Position = UDim2.new(0.695 + (i-1)*0.06, 2, 0.15, 0)
    fb.BackgroundColor3 = i==1
        and Color3.fromRGB(60, 40, 100)
        or  Color3.fromRGB(20, 16, 36)
    fb.Text = label
    fb.TextColor3 = i > 1
        and SUIT_COLOR[suitKeys[i]]
        or  Color3.new(1,1,1)
    fb.TextScaled = true
    fb.Font = Enum.Font.GothamBold
    fb.BorderSizePixel = 0
    fb.Parent = filterBar
    local fc = Instance.new("UICorner"); fc.CornerRadius=UDim.new(0,4); fc.Parent=fb
    suitFilterBtns[i] = {btn=fb, key=suitKeys[i]}
end

-- カードリスト本体
local cardListScroll = Instance.new("ScrollingFrame")
cardListScroll.Name = "CardListScroll"
cardListScroll.Size = UDim2.new(1, 0, 0.9, 0)
cardListScroll.Position = UDim2.new(0, 0, 0.1, 0)
cardListScroll.BackgroundTransparency = 1
cardListScroll.BorderSizePixel = 0
cardListScroll.ScrollBarThickness = 4
cardListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
cardListScroll.Parent = leftCol

local cardListLayout = Instance.new("UIListLayout")
cardListLayout.Padding = UDim.new(0, 2)
cardListLayout.Parent = cardListScroll

-- ─── 右カラム: デッキ内容 + 情報 ───
local rightCol = Instance.new("Frame")
rightCol.Size = UDim2.new(0.5, -4, 1 - bodyY - 0.01, 0)
rightCol.Position = UDim2.new(0.5, 2, bodyY, 0)
rightCol.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
rightCol.BorderSizePixel = 0
rightCol.Parent = bg

-- カウンター
local counterFrame = Instance.new("Frame")
counterFrame.Size = UDim2.new(1, 0, 0.08, 0)
counterFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 28)
counterFrame.BorderSizePixel = 0
counterFrame.Parent = rightCol

local mainCountLabel = Instance.new("TextLabel")
mainCountLabel.Name = "MainCount"
mainCountLabel.Size = UDim2.new(0.4, 0, 1, 0)
mainCountLabel.BackgroundTransparency = 1
mainCountLabel.Text = "メイン 0/30"
mainCountLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
mainCountLabel.TextScaled = true
mainCountLabel.Font = Enum.Font.GothamBold
mainCountLabel.Parent = counterFrame

local exCountLabel = Instance.new("TextLabel")
exCountLabel.Name = "EXCount"
exCountLabel.Size = UDim2.new(0.3, 0, 1, 0)
exCountLabel.Position = UDim2.new(0.4, 0, 0, 0)
exCountLabel.BackgroundTransparency = 1
exCountLabel.Text = "EX 0/7"
exCountLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
exCountLabel.TextScaled = true
exCountLabel.Font = Enum.Font.GothamBold
exCountLabel.Parent = counterFrame

-- 推しカード枠
local oshiFrame = Instance.new("Frame")
oshiFrame.Size = UDim2.new(1, 0, 0.1, 0)
oshiFrame.Position = UDim2.new(0, 0, 0.08, 0)
oshiFrame.BackgroundColor3 = Color3.fromRGB(12, 10, 25)
oshiFrame.BorderSizePixel = 0
oshiFrame.Parent = rightCol

local oshiLabel = Instance.new("TextLabel")
oshiLabel.Size = UDim2.new(0.3, 0, 1, 0)
oshiLabel.BackgroundTransparency = 1
oshiLabel.Text = "推しカード"
oshiLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
oshiLabel.TextScaled = true
oshiLabel.Font = Enum.Font.GothamBold
oshiLabel.Parent = oshiFrame

local oshiSlot = Instance.new("TextButton")
oshiSlot.Name = "OshiSlot"
oshiSlot.Size = UDim2.new(0.65, -4, 0.8, 0)
oshiSlot.Position = UDim2.new(0.31, 2, 0.1, 0)
oshiSlot.BackgroundColor3 = Color3.fromRGB(40, 30, 10)
oshiSlot.Text = "未登録（メインデッキから選択）"
oshiSlot.TextColor3 = Color3.fromRGB(150, 150, 100)
oshiSlot.TextScaled = true
oshiSlot.Font = Enum.Font.Gotham
oshiSlot.BorderSizePixel = 0
oshiSlot.Parent = oshiFrame
local osc = Instance.new("UICorner"); osc.CornerRadius=UDim.new(0,6); osc.Parent=oshiSlot

-- デッキリスト
local deckListScroll = Instance.new("ScrollingFrame")
deckListScroll.Name = "DeckListScroll"
deckListScroll.Size = UDim2.new(1, 0, 0.7, 0)
deckListScroll.Position = UDim2.new(0, 0, 0.18, 0)
deckListScroll.BackgroundTransparency = 1
deckListScroll.BorderSizePixel = 0
deckListScroll.ScrollBarThickness = 4
deckListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
deckListScroll.Parent = rightCol

local deckListLayout = Instance.new("UIListLayout")
deckListLayout.Padding = UDim.new(0, 2)
deckListLayout.Parent = deckListScroll

-- 保存ボタン
local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(0.45, -4, 0.07, 0)
saveBtn.Position = UDim2.new(0.27, 2, 0.93, 0)
saveBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 40)
saveBtn.Text = "💾 保存する"
saveBtn.TextColor3 = Color3.new(1,1,1)
saveBtn.TextScaled = true
saveBtn.Font = Enum.Font.GothamBold
saveBtn.BorderSizePixel = 0
saveBtn.Parent = rightCol
local svc = Instance.new("UICorner"); svc.CornerRadius=UDim.new(0,8); svc.Parent=saveBtn

-- ═══════════════════════════════════════
-- カードリスト行生成
-- ═══════════════════════════════════════
local function makeCardRow(card, inDeckCount, isEX)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 48)
    row.BackgroundColor3 = Color3.fromRGB(16, 12, 28)
    row.BorderSizePixel = 0

    local rc = Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,4); rc.Parent=row

    -- スート色ライン
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0.004, 0, 1, 0)
    line.BackgroundColor3 = SUIT_COLOR[card.suit] or Color3.new(1,1,1)
    line.BorderSizePixel = 0
    line.Parent = row

    -- カード名
    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(0.5, 0, 0.55, 0)
    nameL.Position = UDim2.new(0.01, 0, 0.05, 0)
    nameL.BackgroundTransparency = 1
    nameL.Text = card.name or card.id
    nameL.TextColor3 = Color3.new(1,1,1)
    nameL.TextScaled = true
    nameL.Font = Enum.Font.GothamBold
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Parent = row

    -- レアリティ
    local rarL = Instance.new("TextLabel")
    rarL.Size = UDim2.new(0.12, 0, 0.4, 0)
    rarL.Position = UDim2.new(0.01, 0, 0.58, 0)
    rarL.BackgroundTransparency = 1
    rarL.Text = card.rarity or "C"
    rarL.TextColor3 = RARITY_COLOR[card.rarity] or RARITY_COLOR.C
    rarL.TextScaled = true
    rarL.Font = Enum.Font.GothamBold
    rarL.TextXAlignment = Enum.TextXAlignment.Left
    rarL.Parent = row

    -- ランク
    local rankL = Instance.new("TextLabel")
    rankL.Size = UDim2.new(0.15, 0, 0.4, 0)
    rankL.Position = UDim2.new(0.14, 0, 0.58, 0)
    rankL.BackgroundTransparency = 1
    rankL.Text = card.rank and ("R"..card.rank) or ""
    rankL.TextColor3 = Color3.fromRGB(180,180,180)
    rankL.TextScaled = true
    rankL.Font = Enum.Font.Gotham
    rankL.TextXAlignment = Enum.TextXAlignment.Left
    rankL.Parent = row

    -- + ボタン
    local addBtn = Instance.new("TextButton")
    addBtn.Size = UDim2.new(0.1, 0, 0.7, 0)
    addBtn.Position = UDim2.new(0.82, 0, 0.15, 0)
    addBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    addBtn.Text = "+"
    addBtn.TextColor3 = Color3.new(1,1,1)
    addBtn.TextScaled = true
    addBtn.Font = Enum.Font.GothamBold
    addBtn.BorderSizePixel = 0
    addBtn.Parent = row
    local ac = Instance.new("UICorner"); ac.CornerRadius=UDim.new(0,4); ac.Parent=addBtn

    -- 詳細ボタン（カード名領域タップ→CardDetailUI）
    local detailBtn = Instance.new("TextButton")
    detailBtn.Size = UDim2.new(0.62, 0, 1, 0)
    detailBtn.Position = UDim2.new(0.18, 0, 0, 0)
    detailBtn.BackgroundTransparency = 1
    detailBtn.Text = ""
    detailBtn.Parent = row
    detailBtn.MouseButton1Click:Connect(function()
        -- CardDetailUIは_G経由で呼ぶ
        if _G.OpenCardDetail then _G.OpenCardDetail(card, nil, nil, true) end
    end)

    -- デッキ内枚数バッジ
    local badge = Instance.new("TextLabel")
    badge.Name = "Badge"
    badge.Size = UDim2.new(0.1, 0, 0.5, 0)
    badge.Position = UDim2.new(0.71, 0, 0.25, 0)
    badge.BackgroundColor3 = Color3.fromRGB(80, 40, 160)
    badge.Text = inDeckCount > 0 and tostring(inDeckCount) or ""
    badge.TextColor3 = Color3.new(1,1,1)
    badge.TextScaled = true
    badge.Font = Enum.Font.GothamBold
    badge.Visible = inDeckCount > 0
    badge.BorderSizePixel = 0
    badge.Parent = row
    local bc = Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,10); bc.Parent=badge

    addBtn.MouseButton1Click:Connect(function()
        local ok, msg
        if isEX then
            ok, msg = addEX(card.id)
        else
            ok, msg = addMain(card.id)
        end
        if ok then
            refreshDeckList()
            refreshCardList()
            updateCounters()
        end
    end)

    return row
end

-- ═══════════════════════════════════════
-- デッキリスト行生成
-- ═══════════════════════════════════════
local function makeDeckRow(cardId, count, isEX, exIndex)
    local card = CardData.getCardById and CardData.getCardById(cardId)
        or {id=cardId, name=cardId, suit="club", rarity="C"}

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 40)
    row.BackgroundColor3 = isEX
        and Color3.fromRGB(20, 14, 10)
        or  Color3.fromRGB(14, 12, 24)
    row.BorderSizePixel = 0
    local rc = Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,4); rc.Parent=row

    -- スート色ライン
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0.005, 0, 1, 0)
    line.BackgroundColor3 = SUIT_COLOR[card.suit] or Color3.new(1,1,1)
    line.BorderSizePixel = 0
    line.Parent = row

    -- 枚数
    local countL = Instance.new("TextLabel")
    countL.Size = UDim2.new(0.1, 0, 1, 0)
    countL.Position = UDim2.new(0.01, 0, 0, 0)
    countL.BackgroundTransparency = 1
    countL.Text = isEX and "" or ("×"..count)
    countL.TextColor3 = Color3.fromRGB(200, 200, 100)
    countL.TextScaled = true
    countL.Font = Enum.Font.GothamBold
    countL.Parent = row

    -- 名前
    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(0.7, 0, 1, 0)
    nameL.Position = UDim2.new(0.12, 0, 0, 0)
    nameL.BackgroundTransparency = 1
    nameL.Text = (card.name or cardId) .. (isEX and " [EX]" or "")
    nameL.TextColor3 = isEX
        and Color3.fromRGB(255, 200, 100)
        or  Color3.new(1,1,1)
    nameL.TextScaled = true
    nameL.Font = Enum.Font.Gotham
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Parent = row

    -- 推し登録ボタン（メインのみ）
    if not isEX then
        local oshiBtn = Instance.new("TextButton")
        oshiBtn.Size = UDim2.new(0.08, 0, 0.65, 0)
        oshiBtn.Position = UDim2.new(0.75, 0, 0.175, 0)
        oshiBtn.BackgroundColor3 = state.oshiCardId == cardId
            and Color3.fromRGB(160, 120, 0)
            or  Color3.fromRGB(40, 30, 10)
        oshiBtn.Text = "★"
        oshiBtn.TextColor3 = Color3.fromRGB(255, 220, 80)
        oshiBtn.TextScaled = true
        oshiBtn.Font = Enum.Font.GothamBold
        oshiBtn.BorderSizePixel = 0
        oshiBtn.Parent = row
        local ob = Instance.new("UICorner"); ob.CornerRadius=UDim.new(0,4); ob.Parent=oshiBtn

        oshiBtn.MouseButton1Click:Connect(function()
            state.oshiCardId = (state.oshiCardId == cardId) and nil or cardId
            refreshDeckList()
            updateOshiSlot()
        end)
    end

    -- - ボタン
    local removeBtn = Instance.new("TextButton")
    removeBtn.Size = UDim2.new(0.08, 0, 0.65, 0)
    removeBtn.Position = UDim2.new(0.84, 0, 0.175, 0)
    removeBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
    removeBtn.Text = "−"
    removeBtn.TextColor3 = Color3.new(1,1,1)
    removeBtn.TextScaled = true
    removeBtn.Font = Enum.Font.GothamBold
    removeBtn.BorderSizePixel = 0
    removeBtn.Parent = row
    local rb = Instance.new("UICorner"); rb.CornerRadius=UDim.new(0,4); rb.Parent=removeBtn

    removeBtn.MouseButton1Click:Connect(function()
        if isEX then
            removeEX(exIndex)
        else
            removeMain(cardId)
            if state.oshiCardId == cardId and findMain(cardId) == nil then
                state.oshiCardId = nil
                updateOshiSlot()
            end
        end
        refreshDeckList()
        refreshCardList()
        updateCounters()
    end)

    return row
end

-- ═══════════════════════════════════════
-- 更新関数
-- ═══════════════════════════════════════
function updateCounters()
    local mc = mainCount()
    local ec = exCount()
    mainCountLabel.Text = "メイン " .. mc .. "/" .. MAIN_LIMIT
    mainCountLabel.TextColor3 = mc == MAIN_LIMIT
        and Color3.fromRGB(100, 255, 100)
        or  Color3.fromRGB(200, 200, 255)
    exCountLabel.Text = "EX " .. ec .. "/" .. EX_LIMIT
    exCountLabel.TextColor3 = ec == EX_LIMIT
        and Color3.fromRGB(255, 200, 100)
        or  Color3.fromRGB(200, 160, 80)
end

function updateOshiSlot()
    if state.oshiCardId then
        local card = CardData.getCardById and CardData.getCardById(state.oshiCardId)
        oshiSlot.Text = "★ " .. (card and card.name or state.oshiCardId)
        oshiSlot.TextColor3 = Color3.fromRGB(255, 220, 80)
        oshiSlot.BackgroundColor3 = Color3.fromRGB(60, 45, 10)
    else
        oshiSlot.Text = "未登録（メインデッキから選択）"
        oshiSlot.TextColor3 = Color3.fromRGB(150, 150, 100)
        oshiSlot.BackgroundColor3 = Color3.fromRGB(40, 30, 10)
    end
end

function refreshCardList()
    for _, child in ipairs(cardListScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local isEX = state.filter.zone == "ex"
    local totalH = 0

    for _, card in ipairs(state.allCards) do
        -- フィルター適用
        if state.filter.suit ~= "all" and card.suit ~= state.filter.suit then
            continue
        end
        if state.filter.rarity ~= "all" and card.rarity ~= state.filter.rarity then
            continue
        end
        if state.filter.text ~= "" then
            local name = (card.name or ""):lower()
            if not name:find(state.filter.text:lower(), 1, true) then
                continue
            end
        end

        local inDeck = 0
        if isEX then
            for _, id in ipairs(state.exDeck) do
                if id == card.id then inDeck = inDeck + 1 end
            end
        else
            local _, e = findMain(card.id)
            inDeck = e and e.count or 0
        end

        local row = makeCardRow(card, inDeck, isEX)
        row.Parent = cardListScroll
        totalH = totalH + 50
    end

    cardListScroll.CanvasSize = UDim2.new(0, 0, 0, totalH)
end

function refreshDeckList()
    for _, child in ipairs(deckListScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local totalH = 0

    -- メインデッキ（スート順でソート）
    local sorted = {}
    for _, e in ipairs(state.mainDeck) do table.insert(sorted, e) end
    table.sort(sorted, function(a, b)
        local ca = CardData.getCardById and CardData.getCardById(a.cardId)
        local cb = CardData.getCardById and CardData.getCardById(b.cardId)
        local sa = ca and ca.suit or ""
        local sb = cb and cb.suit or ""
        if sa ~= sb then return sa < sb end
        local ra = ca and (ca.rank or 0) or 0
        local rb = cb and (cb.rank or 0) or 0
        return ra > rb
    end)

    for _, e in ipairs(sorted) do
        local row = makeDeckRow(e.cardId, e.count, false, nil)
        row.Parent = deckListScroll
        totalH = totalH + 42
    end

    -- EXデッキ（セパレーター）
    if #state.exDeck > 0 then
        local sep = Instance.new("TextLabel")
        sep.Size = UDim2.new(1, -4, 0, 28)
        sep.BackgroundColor3 = Color3.fromRGB(30, 20, 8)
        sep.Text = "── EXデッキ ──"
        sep.TextColor3 = Color3.fromRGB(255, 200, 100)
        sep.TextScaled = true
        sep.Font = Enum.Font.GothamBold
        sep.BorderSizePixel = 0
        sep.Parent = deckListScroll
        totalH = totalH + 30

        for i, cardId in ipairs(state.exDeck) do
            local row = makeDeckRow(cardId, 1, true, i)
            row.Parent = deckListScroll
            totalH = totalH + 42
        end
    end

    deckListScroll.CanvasSize = UDim2.new(0, 0, 0, totalH)
end

-- ═══════════════════════════════════════
-- イベント接続
-- ═══════════════════════════════════════
closeBtn.MouseButton1Click:Connect(function()
    screen.Enabled = false
end)

-- レシピ公開ボタン
local pubBtn = Instance.new("TextButton")
pubBtn.Size = UDim2.new(0.20,0,0.05,0); pubBtn.Position = UDim2.new(0.78,0,0.94,0)
pubBtn.BackgroundColor3 = Color3.fromRGB(40,80,20); pubBtn.Text = "📤 公開"
pubBtn.TextColor3 = Color3.fromRGB(180,255,120); pubBtn.Font = Enum.Font.GothamBold
pubBtn.TextScaled = true; pubBtn.Parent = screen
local pubBtnC = Instance.new("UICorner"); pubBtnC.CornerRadius = UDim.new(0.2,0); pubBtnC.Parent = pubBtn

pubBtn.MouseButton1Click:Connect(function()
    if #state.mainDeck < 20 then
        -- タイトル入力
        local tBox = Instance.new("TextBox"); tBox.Size=UDim2.new(0.6,0,0.06,0)
        tBox.Position=UDim2.new(0.2,0,0.46,0); tBox.BackgroundColor3=Color3.fromRGB(15,20,40)
        tBox.TextColor3=Color3.fromRGB(220,220,255); tBox.PlaceholderText="デッキ名（20文字）"
        tBox.MaxVisibleGraphemes=20; tBox.Font=Enum.Font.Gotham; tBox.TextSize=13
        tBox.Parent=screen; local tBoxC=Instance.new("UICorner"); tBoxC.CornerRadius=UDim.new(0.2,0); tBoxC.Parent=tBox

        local confPub = Instance.new("TextButton"); confPub.Size=UDim2.new(0.22,0,0.05,0)
        confPub.Position=UDim2.new(0.39,0,0.53,0); confPub.BackgroundColor3=Color3.fromRGB(30,80,160)
        confPub.Text="公開する"; confPub.TextColor3=Color3.fromRGB(200,220,255)
        confPub.Font=Enum.Font.GothamBold; confPub.TextScaled=true; confPub.Parent=screen
        local confPubC=Instance.new("UICorner"); confPubC.CornerRadius=UDim.new(0.2,0); confPubC.Parent=confPub
        confPub.MouseButton1Click:Connect(function()
            local title = tBox.Text; if #title < 1 then title = "名無しデッキ" end
            if RE_DeckRecipeDE then
                RE_DeckRecipeDE:FireServer({type="publish", title=title, cards=state.mainDeck})
            end
            tBox:Destroy(); confPub:Destroy()
        end)
        return
    end
    -- デッキ未完成の場合のみ入力を出す（mainDeck >= 20 は常に公開可能）
    local title = "デッキ"..tostring(state.libId)
    if RE_DeckRecipeDE then
        RE_DeckRecipeDE:FireServer({type="publish", title=title, cards=state.mainDeck})
    end
end)

-- レシピ閲覧ボタン
local viewBtn = Instance.new("TextButton")
viewBtn.Size = UDim2.new(0.22,0,0.05,0); viewBtn.Position = UDim2.new(0.54,0,0.94,0)
viewBtn.BackgroundColor3 = Color3.fromRGB(20,50,100); viewBtn.Text = "📋 みんなのデッキ"
viewBtn.TextColor3 = Color3.fromRGB(180,210,255); viewBtn.Font = Enum.Font.GothamBold
viewBtn.TextScaled = true; viewBtn.Parent = screen
local viewBtnC = Instance.new("UICorner"); viewBtnC.CornerRadius = UDim.new(0.2,0); viewBtnC.Parent = viewBtn
viewBtn.MouseButton1Click:Connect(function()
    if RE_DeckRecipeDE then RE_DeckRecipeDE:FireServer({type="list"}) end
end)

-- レシピ受信（DeckEditUI内）
RE_DeckRecipeDE.OnClientEvent:Connect(function(d)
    if d.type == "published" then
        -- トースト表示（_G経由）
        if _G.ShowToast then _G.ShowToast("📤 " .. (d.message or ""), 3) end
    end
end)

saveBtn.MouseButton1Click:Connect(function()
    if mainCount() ~= MAIN_LIMIT then return end
    Remotes.SaveDeck:FireServer({
        libId = state.libId,    -- ライブラリ番号（1〜8）
        main  = state.mainDeck,
        ex    = state.exDeck,
        oshi  = state.oshiCardId,
    })
    -- 保存フラッシュ
    TweenService:Create(saveBtn,
        TweenInfo.new(0.1),
        {BackgroundColor3 = Color3.fromRGB(100, 200, 100)}
    ):Play()
    task.delay(0.4, function()
        TweenService:Create(saveBtn,
            TweenInfo.new(0.2),
            {BackgroundColor3 = Color3.fromRGB(40, 120, 40)}
        ):Play()
    end)
end)

-- ライブラリ番号切替
for i, sb in ipairs(slotBtns) do
    sb.MouseButton1Click:Connect(function()
        state.libId = i
        for j, b in ipairs(slotBtns) do
            b.BackgroundColor3 = j==i
                and Color3.fromRGB(80, 40, 160)
                or  Color3.fromRGB(30, 20, 50)
        end
        Remotes.LoadDeck:FireServer(i)
    end)
end

-- ゾーン切替
zoneMain.MouseButton1Click:Connect(function()
    state.filter.zone = "main"
    zoneMain.BackgroundColor3 = Color3.fromRGB(80, 40, 160)
    zoneEX.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
    zoneMain.TextColor3 = Color3.new(1,1,1)
    zoneEX.TextColor3 = Color3.fromRGB(180,180,180)
    refreshCardList()
end)

zoneEX.MouseButton1Click:Connect(function()
    state.filter.zone = "ex"
    zoneEX.BackgroundColor3 = Color3.fromRGB(80, 40, 160)
    zoneMain.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
    zoneEX.TextColor3 = Color3.new(1,1,1)
    zoneMain.TextColor3 = Color3.fromRGB(180,180,180)
    refreshCardList()
end)

-- 検索
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    state.filter.text = searchBox.Text
    refreshCardList()
end)

-- スートフィルター
for _, item in ipairs(suitFilterBtns) do
    item.btn.MouseButton1Click:Connect(function()
        state.filter.suit = item.key
        for _, it in ipairs(suitFilterBtns) do
            it.btn.BackgroundColor3 = it.key == item.key
                and Color3.fromRGB(60, 40, 100)
                or  Color3.fromRGB(20, 16, 36)
        end
        refreshCardList()
    end)
end

-- デッキデータ受信
Remotes.DeckLoaded.OnClientEvent:Connect(function(data)
    state.mainDeck   = data.main or {}
    state.exDeck     = data.ex   or {}
    state.oshiCardId = data.oshi or nil
    state.allCards   = data.allCards or {}
    refreshCardList()
    refreshDeckList()
    updateCounters()
    updateOshiSlot()
end)

-- デッキ編集画面を開く
local function openDeckEdit()
    screen.Enabled = true
    local loadRemote = Remotes:FindFirstChild("LoadDeck")
    if loadRemote then loadRemote:FireServer(state.libId) end
end

Remotes:WaitForChild("OpenDeckEdit", 15).OnClientEvent:Connect(openDeckEdit)

-- グローバル公開（BattleClientのナビゲーションボタンから呼べる）
_G.OpenDeckEdit = openDeckEdit

