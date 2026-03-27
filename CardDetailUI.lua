-- CardDetailUI.lua
-- StarterPlayerScripts/CardDetailUI
-- カード詳細ポップアップ（デッキ編集・バトル中共通）

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)
local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui", 15)

-- ═══════════════════════════════════════
-- 定数
-- ═══════════════════════════════════════
local VOTE_TARGET = 777

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
local SUIT_LABEL = {
    club="♧ クラディオン", heart="♥ ハルニア",
    diamond="♦ ダイノス", spade="♤ スペルニア"
}

-- ═══════════════════════════════════════
-- UI生成
-- ═══════════════════════════════════════
local screen = Instance.new("ScreenGui")
screen.Name = "CardDetailUI"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Enabled = false
screen.DisplayOrder = 100  -- 最前面
screen.Parent = playerGui

-- オーバーレイ（タップで閉じる）
local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.55
overlay.Text = ""
overlay.BorderSizePixel = 0
overlay.Parent = screen

-- メインパネル
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0.82, 0, 0.75, 0)
panel.Position = UDim2.new(0.09, 0, 0.125, 0)
panel.BackgroundColor3 = Color3.fromRGB(12, 10, 24)
panel.BorderSizePixel = 0
panel.Parent = screen

local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 14)
pc.Parent = panel

-- スート色の上部ライン
local topLine = Instance.new("Frame")
topLine.Name = "TopLine"
topLine.Size = UDim2.new(1, 0, 0.008, 0)
topLine.BackgroundColor3 = Color3.fromRGB(80, 40, 160)
topLine.BorderSizePixel = 0
topLine.Parent = panel

-- 閉じるボタン
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.1, 0, 0.07, 0)
closeBtn.Position = UDim2.new(0.88, 0, 0.01, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = panel

-- ── カード情報エリア ──
-- レアリティバッジ
local rarBadge = Instance.new("TextLabel")
rarBadge.Name = "RarBadge"
rarBadge.Size = UDim2.new(0.15, 0, 0.07, 0)
rarBadge.Position = UDim2.new(0.04, 0, 0.04, 0)
rarBadge.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
rarBadge.Text = "C"
rarBadge.TextColor3 = RARITY_COLOR.C
rarBadge.TextScaled = true
rarBadge.Font = Enum.Font.GothamBold
rarBadge.BorderSizePixel = 0
rarBadge.Parent = panel
local rbc = Instance.new("UICorner"); rbc.CornerRadius=UDim.new(0,6); rbc.Parent=rarBadge

-- スートラベル
local suitLabel = Instance.new("TextLabel")
suitLabel.Name = "SuitLabel"
suitLabel.Size = UDim2.new(0.4, 0, 0.07, 0)
suitLabel.Position = UDim2.new(0.21, 0, 0.04, 0)
suitLabel.BackgroundTransparency = 1
suitLabel.Text = "♧ クラディオン"
suitLabel.TextColor3 = SUIT_COLOR.club
suitLabel.TextScaled = true
suitLabel.Font = Enum.Font.GothamBold
suitLabel.TextXAlignment = Enum.TextXAlignment.Left
suitLabel.Parent = panel

-- ランク
local rankLabel = Instance.new("TextLabel")
rankLabel.Name = "RankLabel"
rankLabel.Size = UDim2.new(0.2, 0, 0.07, 0)
rankLabel.Position = UDim2.new(0.76, 0, 0.04, 0)
rankLabel.BackgroundTransparency = 1
rankLabel.Text = "R 7"
rankLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
rankLabel.TextScaled = true
rankLabel.Font = Enum.Font.GothamBold
rankLabel.TextXAlignment = Enum.TextXAlignment.Right
rankLabel.Parent = panel

-- カード名
local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "NameLabel"
nameLabel.Size = UDim2.new(0.92, 0, 0.1, 0)
nameLabel.Position = UDim2.new(0.04, 0, 0.12, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = "カード名"
nameLabel.TextColor3 = Color3.new(1, 1, 1)
nameLabel.TextScaled = true
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.Parent = panel

-- セパレーター
local sep1 = Instance.new("Frame")
sep1.Size = UDim2.new(0.92, 0, 0.005, 0)
sep1.Position = UDim2.new(0.04, 0, 0.23, 0)
sep1.BackgroundColor3 = Color3.fromRGB(50, 40, 70)
sep1.BorderSizePixel = 0
sep1.Parent = panel

-- 効果テキスト
local effectLabel = Instance.new("TextLabel")
effectLabel.Name = "EffectLabel"
effectLabel.Size = UDim2.new(0.92, 0, 0.28, 0)
effectLabel.Position = UDim2.new(0.04, 0, 0.245, 0)
effectLabel.BackgroundTransparency = 1
effectLabel.Text = "効果テキスト"
effectLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
effectLabel.TextScaled = true
effectLabel.Font = Enum.Font.Gotham
effectLabel.TextXAlignment = Enum.TextXAlignment.Left
effectLabel.TextYAlignment = Enum.TextYAlignment.Top
effectLabel.TextWrapped = true
effectLabel.Parent = panel

-- フレーバーテキスト（将来用・現在は非表示）
local flavorLabel = Instance.new("TextLabel")
flavorLabel.Name = "FlavorLabel"
flavorLabel.Size = UDim2.new(0.92, 0, 0.07, 0)
flavorLabel.Position = UDim2.new(0.04, 0, 0.52, 0)
flavorLabel.BackgroundTransparency = 1
flavorLabel.Text = ""
flavorLabel.TextColor3 = Color3.fromRGB(140, 130, 160)
flavorLabel.TextScaled = true
flavorLabel.Font = Enum.Font.GothamItalic
flavorLabel.TextXAlignment = Enum.TextXAlignment.Left
flavorLabel.TextWrapped = true
flavorLabel.Parent = panel

-- ── 投票エリア ──
local sep2 = Instance.new("Frame")
sep2.Size = UDim2.new(0.92, 0, 0.005, 0)
sep2.Position = UDim2.new(0.04, 0, 0.6, 0)
sep2.BackgroundColor3 = Color3.fromRGB(50, 40, 70)
sep2.BorderSizePixel = 0
sep2.Parent = panel

-- 投票ラベル
local voteTitle = Instance.new("TextLabel")
voteTitle.Size = UDim2.new(0.5, 0, 0.06, 0)
voteTitle.Position = UDim2.new(0.04, 0, 0.615, 0)
voteTitle.BackgroundTransparency = 1
voteTitle.Text = "転生投票（777票で確定）"
voteTitle.TextColor3 = Color3.fromRGB(180, 160, 220)
voteTitle.TextScaled = true
voteTitle.Font = Enum.Font.Gotham
voteTitle.TextXAlignment = Enum.TextXAlignment.Left
voteTitle.Parent = panel

-- 投票権残数
local voteTicketLabel = Instance.new("TextLabel")
voteTicketLabel.Name = "VoteTicketLabel"
voteTicketLabel.Size = UDim2.new(0.35, 0, 0.06, 0)
voteTicketLabel.Position = UDim2.new(0.61, 0, 0.615, 0)
voteTicketLabel.BackgroundTransparency = 1
voteTicketLabel.Text = "投票権: 0枚"
voteTicketLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
voteTicketLabel.TextScaled = true
voteTicketLabel.Font = Enum.Font.GothamBold
voteTicketLabel.TextXAlignment = Enum.TextXAlignment.Right
voteTicketLabel.Parent = panel

-- 👍ボタン
local upBtn = Instance.new("TextButton")
upBtn.Name = "UpBtn"
upBtn.Size = UDim2.new(0.4, 0, 0.12, 0)
upBtn.Position = UDim2.new(0.04, 0, 0.69, 0)
upBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
upBtn.Text = "👍  0"
upBtn.TextColor3 = Color3.fromRGB(100, 220, 100)
upBtn.TextScaled = true
upBtn.Font = Enum.Font.GothamBold
upBtn.BorderSizePixel = 0
upBtn.Parent = panel
local upc = Instance.new("UICorner"); upc.CornerRadius=UDim.new(0,8); upc.Parent=upBtn

-- 👎ボタン
local downBtn = Instance.new("TextButton")
downBtn.Name = "DownBtn"
downBtn.Size = UDim2.new(0.4, 0, 0.12, 0)
downBtn.Position = UDim2.new(0.56, 0, 0.69, 0)
downBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
downBtn.Text = "👎  0"
downBtn.TextColor3 = Color3.fromRGB(220, 100, 100)
downBtn.TextScaled = true
downBtn.Font = Enum.Font.GothamBold
downBtn.BorderSizePixel = 0
downBtn.Parent = panel
local dwnc = Instance.new("UICorner"); dwnc.CornerRadius=UDim.new(0,8); dwnc.Parent=downBtn

-- 票数プログレスバー
local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(0.92, 0, 0.03, 0)
barBg.Position = UDim2.new(0.04, 0, 0.83, 0)
barBg.BackgroundColor3 = Color3.fromRGB(20, 16, 36)
barBg.BorderSizePixel = 0
barBg.Parent = panel
local bbc = Instance.new("UICorner"); bbc.CornerRadius=UDim.new(0,4); bbc.Parent=barBg

local upBar = Instance.new("Frame")
upBar.Name = "UpBar"
upBar.Size = UDim2.new(0, 0, 1, 0)
upBar.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
upBar.BorderSizePixel = 0
upBar.Parent = barBg
local ubc = Instance.new("UICorner"); ubc.CornerRadius=UDim.new(0,4); ubc.Parent=upBar

local downBar = Instance.new("Frame")
downBar.Name = "DownBar"
downBar.Size = UDim2.new(0, 0, 1, 0)
downBar.AnchorPoint = Vector2.new(1, 0)
downBar.Position = UDim2.new(1, 0, 0, 0)
downBar.BackgroundColor3 = Color3.fromRGB(160, 60, 60)
downBar.BorderSizePixel = 0
downBar.Parent = barBg
local dbc = Instance.new("UICorner"); dbc.CornerRadius=UDim.new(0,4); dbc.Parent=downBar

-- 777達成バナー
local seishinBanner = Instance.new("TextLabel")
seishinBanner.Name = "SeishinBanner"
seishinBanner.Size = UDim2.new(0.92, 0, 0.06, 0)
seishinBanner.Position = UDim2.new(0.04, 0, 0.87, 0)
seishinBanner.BackgroundTransparency = 1
seishinBanner.Text = ""
seishinBanner.TextColor3 = Color3.fromRGB(255, 220, 80)
seishinBanner.TextScaled = true
seishinBanner.Font = Enum.Font.GothamBold
seishinBanner.Parent = panel

-- 🎨 スタイル変更ボタン（TCG版デッキ編集からのタップ時のみ表示）
-- fromDeckEdit=true の時: 投票エリアの代わりにこれを表示
local styleBtn = Instance.new("TextButton")
styleBtn.Name            = "StyleBtn"
styleBtn.Size            = UDim2.new(0.44, -4, 0.12, 0)
styleBtn.Position        = UDim2.new(0.04, 0, 0.69, 0)
styleBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 90)
styleBtn.Text            = "🎨 スタイル変更"
styleBtn.TextColor3      = Color3.fromRGB(200, 160, 255)
styleBtn.Font            = Enum.Font.GothamBold
styleBtn.TextScaled      = true
styleBtn.BorderSizePixel = 0
styleBtn.Visible         = false
styleBtn.Parent          = panel
local stc = Instance.new("UICorner"); stc.CornerRadius=UDim.new(0,8); stc.Parent=styleBtn

-- スタイル選択ポップアップ（styleBtn上に重ねて出す）
local stylePopup = Instance.new("Frame")
stylePopup.Name            = "StylePopup"
stylePopup.Size            = UDim2.new(0.92, 0, 0.35, 0)
stylePopup.Position        = UDim2.new(0.04, 0, 0.52, 0)
stylePopup.BackgroundColor3 = Color3.fromRGB(20, 14, 38)
stylePopup.BorderSizePixel = 0
stylePopup.Visible         = false
stylePopup.ZIndex          = 10
stylePopup.Parent          = panel
local spc = Instance.new("UICorner"); spc.CornerRadius=UDim.new(0,10); spc.Parent=stylePopup

local stylePopupTitle = Instance.new("TextLabel")
stylePopupTitle.Size             = UDim2.new(1, 0, 0.18, 0)
stylePopupTitle.BackgroundTransparency = 1
stylePopupTitle.Text             = "スタイルを選択"
stylePopupTitle.TextColor3       = Color3.fromRGB(200, 160, 255)
stylePopupTitle.Font             = Enum.Font.GothamBold
stylePopupTitle.TextScaled       = true
stylePopupTitle.Parent           = stylePopup

local styleList = Instance.new("ScrollingFrame")
styleList.Size            = UDim2.new(1, 0, 0.75, 0)
styleList.Position        = UDim2.new(0, 0, 0.2, 0)
styleList.BackgroundTransparency = 1
styleList.ScrollBarThickness = 4
styleList.CanvasSize      = UDim2.new(0, 0, 0, 0)
styleList.ZIndex          = 11
styleList.Parent          = stylePopup
local slul = Instance.new("UIListLayout")
slul.SortOrder = Enum.SortOrder.LayoutOrder
slul.Padding   = UDim.new(0, 4)
slul.Parent    = styleList

local styleCloseBtn = Instance.new("TextButton")
styleCloseBtn.Size            = UDim2.new(0.3, 0, 0.15, 0)
styleCloseBtn.Position        = UDim2.new(0.35, 0, 0.85, 0)
styleCloseBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
styleCloseBtn.Text            = "閉じる"
styleCloseBtn.TextColor3      = Color3.new(1,1,1)
styleCloseBtn.TextScaled      = true
styleCloseBtn.Font            = Enum.Font.Gotham
styleCloseBtn.BorderSizePixel = 0
styleCloseBtn.ZIndex          = 12
styleCloseBtn.Parent          = stylePopup
local scbc = Instance.new("UICorner"); scbc.CornerRadius=UDim.new(0,6); scbc.Parent=styleCloseBtn
styleCloseBtn.MouseButton1Click:Connect(function()
    stylePopup.Visible = false
end)

-- ═══════════════════════════════════════
-- 状態
-- ═══════════════════════════════════════
local currentCardId   = nil
local currentCardSuit = nil  -- スタイル変更用

-- ═══════════════════════════════════════
-- 更新関数
-- ═══════════════════════════════════════
local function updateVoteBar(upCount, downCount)
    local total = math.max(upCount + downCount, 1)
    local upRatio   = upCount   / total
    local downRatio = downCount / total

    TweenService:Create(upBar,
        TweenInfo.new(0.3),
        {Size = UDim2.new(upRatio * 0.92, 0, 1, 0)}
    ):Play()
    TweenService:Create(downBar,
        TweenInfo.new(0.3),
        {Size = UDim2.new(downRatio * 0.92, 0, 1, 0)}
    ):Play()

    upBtn.Text   = "👍  " .. upCount
    downBtn.Text = "👎  " .. downCount

    -- 777達成チェック
    if upCount >= VOTE_TARGET then
        seishinBanner.Text = "🎉 👍 777票達成！上方修正転生確定！"
        seishinBanner.TextColor3 = Color3.fromRGB(100, 255, 100)
    elseif downCount >= VOTE_TARGET then
        seishinBanner.Text = "⚠ 👎 777票達成！下方修正転生確定！"
        seishinBanner.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        seishinBanner.Text = ""
    end
end

local function openDetail(card, voteData, ticketCount, fromDeckEdit)
    currentCardId   = card.id
    currentCardSuit = card.suit

    -- スート色をトップラインに反映
    topLine.BackgroundColor3 = SUIT_COLOR[card.suit] or Color3.fromRGB(80, 40, 160)

    -- カード情報
    rarBadge.Text = card.rarity or "C"
    rarBadge.TextColor3 = RARITY_COLOR[card.rarity] or RARITY_COLOR.C
    suitLabel.Text = SUIT_LABEL[card.suit] or (card.suit or "")
    suitLabel.TextColor3 = SUIT_COLOR[card.suit] or Color3.new(1,1,1)
    rankLabel.Text = card.rank and ("R " .. card.rank) or ""
    nameLabel.Text = card.name or card.id
    effectLabel.Text = card.desc or card.effect or "（効果テキストなし）"
    flavorLabel.Text = card.flavor or ""

    -- デッキ編集からのタップ: スタイル変更を表示、投票エリアを隠す
    local inDeckEdit = fromDeckEdit == true
    upBtn.Visible         = not inDeckEdit
    downBtn.Visible       = not inDeckEdit
    barBg.Visible         = not inDeckEdit
    voteTicketLabel.Visible = not inDeckEdit
    seishinBanner.Visible = not inDeckEdit
    styleBtn.Visible      = inDeckEdit
    stylePopup.Visible    = false  -- 毎回閉じる

    if not inDeckEdit then
        -- 投票権・票数を更新
        voteTicketLabel.Text = "投票権: " .. (ticketCount or 0) .. "枚"
        local up   = voteData and voteData.up   or 0
        local down = voteData and voteData.down or 0
        updateVoteBar(up, down)
    end

    -- 表示
    screen.Enabled = true
    panel.Position = UDim2.new(0.09, 0, 0.2, 0)
    panel.BackgroundTransparency = 1
    TweenService:Create(panel, TweenInfo.new(0.2), {
        Position = UDim2.new(0.09, 0, 0.125, 0),
        BackgroundTransparency = 0
    }):Play()
end

local function closeDetail()
    TweenService:Create(panel, TweenInfo.new(0.15), {
        Position = UDim2.new(0.09, 0, 0.2, 0),
        BackgroundTransparency = 1
    }):Play()
    task.delay(0.15, function()
        screen.Enabled = false
        currentCardId = nil
    end)
end

-- ═══════════════════════════════════════
-- 投票処理
-- ═══════════════════════════════════════
local function doVote(voteType)
    if not currentCardId then return end
    -- 投票権チェックはサーバー側で行う
    Remotes.CardVote:FireServer(currentCardId, voteType)
end

upBtn.MouseButton1Click:Connect(function()
    doVote("up")
    -- 楽観的UI更新（サーバー応答前に見た目だけ更新）
    local upText  = upBtn.Text:match("%d+")
    local current = tonumber(upText) or 0
    upBtn.Text = "👍  " .. (current + 1)
    TweenService:Create(upBtn, TweenInfo.new(0.1),
        {BackgroundColor3 = Color3.fromRGB(60, 140, 60)}):Play()
    task.delay(0.1, function()
        TweenService:Create(upBtn, TweenInfo.new(0.1),
            {BackgroundColor3 = Color3.fromRGB(30, 80, 30)}):Play()
    end)
end)

downBtn.MouseButton1Click:Connect(function()
    doVote("down")
    local downText = downBtn.Text:match("%d+")
    local current  = tonumber(downText) or 0
    downBtn.Text = "👎  " .. (current + 1)
    TweenService:Create(downBtn, TweenInfo.new(0.1),
        {BackgroundColor3 = Color3.fromRGB(140, 60, 60)}):Play()
    task.delay(0.1, function()
        TweenService:Create(downBtn, TweenInfo.new(0.1),
            {BackgroundColor3 = Color3.fromRGB(80, 30, 30)}):Play()
    end)
end)

-- サーバーから票数更新
Remotes.VoteUpdated.OnClientEvent:Connect(function(cardId, voteData)
    if cardId == currentCardId then
        updateVoteBar(voteData.up or 0, voteData.down or 0)
    end
end)

-- 投票権更新
Remotes.TicketUpdated.OnClientEvent:Connect(function(count)
    voteTicketLabel.Text = "投票権: " .. count .. "枚"
end)

-- 閉じる
closeBtn.MouseButton1Click:Connect(closeDetail)
overlay.MouseButton1Click:Connect(closeDetail)

-- ─────────────────────────────────────────
-- スタイル変更ボタン：所持スキン一覧をポップアップ
-- ─────────────────────────────────────────
local RF_GetOwnedSkinsForCard = Remotes:WaitForChild("GetOwnedSkinsForCard", 10)

local function buildStylePopup(suit, cardId)
    -- 既存のリスト項目をクリア
    for _, c in ipairs(styleList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    -- 所持スキン取得（suit + cardId を渡して絞り込み）
    local ownedSkins = {}
    if RF_GetOwnedSkinsForCard then
        local ok, result = pcall(function()
            return RF_GetOwnedSkinsForCard:InvokeServer(suit, cardId)
        end)
        if ok and result then ownedSkins = result end
    end

    -- デフォルト（スキンなし）を先頭に追加
    local function makeStyleRow(label, skinIdValue, isDefault)
        local row = Instance.new("TextButton")
        row.Size            = UDim2.new(1, -8, 0, 44)
        row.BackgroundColor3 = isDefault
            and Color3.fromRGB(30, 24, 50)
            or  Color3.fromRGB(50, 35, 80)
        row.Text            = label
        row.TextColor3      = Color3.new(1,1,1)
        row.Font            = Enum.Font.Gotham
        row.TextScaled      = true
        row.BorderSizePixel = 0
        row.ZIndex          = 12
        row.Parent          = styleList
        local rc = Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,6); rc.Parent=row

        row.MouseButton1Click:Connect(function()
            -- nil送信でリセット、それ以外は skinId を送る
            Remotes.SetDeckSkin:FireServer(suit, cardId, skinIdValue)
            stylePopup.Visible = false
            -- ボタンにフラッシュ
            TweenService:Create(styleBtn, TweenInfo.new(0.1),
                {BackgroundColor3 = Color3.fromRGB(100, 60, 160)}):Play()
            task.delay(0.3, function()
                TweenService:Create(styleBtn, TweenInfo.new(0.15),
                    {BackgroundColor3 = Color3.fromRGB(50, 30, 90)}):Play()
            end)
        end)
        return row
    end

    makeStyleRow("🔲 デフォルト（変更なし）", nil, true)

    -- 所持スキン一覧を表示
    for _, skin in ipairs(ownedSkins) do
        local rarityMark = skin.rarity == "SSR" and "✦✦✦ "
                        or skin.rarity == "SR"  and "✦✦ "
                        or skin.rarity == "R"   and "✦ "
                        or ""
        makeStyleRow(rarityMark .. skin.name, skin.id, false)
    end

    -- canvasサイズ更新
    local count = #styleList:GetChildren() - 1  -- UIListLayout を除く
    styleList.CanvasSize = UDim2.new(0, 0, 0, count * 48)
    stylePopup.Visible = true
end

styleBtn.MouseButton1Click:Connect(function()
    if not currentCardId or not currentCardSuit then return end
    if stylePopup.Visible then
        stylePopup.Visible = false
    else
        buildStylePopup(currentCardSuit, currentCardId)
    end
end)

-- ═══════════════════════════════════════
-- 外部から呼び出す
-- Remotes.OpenCardDetail:FireClient(player, card, voteData, ticketCount)
-- fromDeckEdit=true を渡すと投票の代わりにスタイル変更ボタンが出る
-- ═══════════════════════════════════════
Remotes.OpenCardDetail.OnClientEvent:Connect(function(card, voteData, ticketCount)
    openDetail(card, voteData, ticketCount, false)
end)

-- _G経由で外部からも呼べるように公開
_G.OpenCardDetail  = function(card, voteData, ticketCount, fromDeckEdit)
    openDetail(card, voteData, ticketCount, fromDeckEdit)
end
_G.CloseCardDetail = closeDetail

return {
    open  = openDetail,
    close = closeDetail,
}
