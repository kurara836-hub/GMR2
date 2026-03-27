-- ============================================
-- GAMEROAD BattleClient_v2.lua
-- StarterPlayerScripts に配置
-- Scaleサイズ統一でモバイル/PC両対応
-- ============================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService     = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui", 15)

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_RoadSelect    = Remotes:WaitForChild("RoadSelect", 15)
local RE_BattleSelect  = Remotes:WaitForChild("BattleSelect", 15)
local RE_TargetSelect  = Remotes:WaitForChild("TargetSelect", 15)
local RE_UpdateBoard   = Remotes:WaitForChild("UpdateBoard", 15)
local RE_ArcanaSelect  = Remotes:WaitForChild("ArcanaSelect", 15)
local RE_GachaRoll     = Remotes:WaitForChild("GachaRoll", 15)
local RE_EquipSkin     = Remotes:WaitForChild("EquipSkin", 15)
local RE_BuyProduct    = Remotes:WaitForChild("BuyProduct", 15)

-- ローカル状態
local CurrentRoomId   = nil
local CurrentPhase    = nil
local CurrentIsTCG    = false   -- TCG版かトランプ版か
local PlayerRoster    = {}      -- {userId, name, team, suit} × 4
local PlayerGems      = 0
local PlayerData      = {}
local SelectedCard    = nil  -- 選択中のカード

-- ============================================
-- UIファクトリ（コード生成でStudio不要）
-- ============================================
local function makeFrame(parent, size, pos, color, name)
    local f = Instance.new("Frame")
    f.Name             = name or "Frame"
    f.Size             = size
    f.Position         = pos
    f.BackgroundColor3 = color or Color3.fromRGB(20, 20, 30)
    f.BorderSizePixel  = 0
    f.Parent           = parent
    return f
end

local function makeText(parent, text, size, pos, textColor, name, fontSize)
    local t = Instance.new("TextLabel")
    t.Name            = name or "Label"
    t.Size            = size
    t.Position        = pos
    t.BackgroundTransparency = 1
    t.Text            = text
    t.TextColor3      = textColor or Color3.fromRGB(255, 255, 255)
    t.TextScaled      = true
    t.Font            = Enum.Font.GothamBold
    t.Parent          = parent
    return t
end

local function makeButton(parent, text, size, pos, bgColor, name)
    local b = Instance.new("TextButton")
    b.Name            = name or "Button"
    b.Size            = size
    b.Position        = pos
    b.BackgroundColor3 = bgColor or Color3.fromRGB(80, 120, 200)
    b.BorderSizePixel = 0
    b.Text            = text
    b.TextColor3      = Color3.fromRGB(255, 255, 255)
    b.TextScaled      = true
    b.Font            = Enum.Font.GothamBold
    b.Parent          = parent
    -- 角丸
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.15, 0)
    corner.Parent = b
    return b
end

local function makeRound(frame, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(radius or 0.1, 0)
    c.Parent = frame
    return c
end

-- ============================================
-- メインScreenGui構築
-- ============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "GameRoadUI"
ScreenGui.ResetOnSpawn   = false  -- リスポーンしてもUI消えない
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.DisplayOrder   = 10     -- デフォルトUIより前面
ScreenGui.IgnoreGuiInset = true   -- SafeArea無視で全画面表示
ScreenGui.Parent         = PlayerGui

-- ============================================
-- ViewportFrame: カード3D演出ヘルパー
-- ============================================
local function playCardViewport(rarity, skinName)
    -- ViewportFrame（2D画面内の3D空間）でカードを回転表示
    local vf = Instance.new("ViewportFrame")
    vf.Size = UDim2.new(0.5, 0, 0.5, 0)
    vf.Position = UDim2.new(0.25, 0, 0.25, 0)
    vf.BackgroundTransparency = 1
    vf.ZIndex = 210
    vf.Parent = ScreenGui

    -- カメラ設定
    local cam = Instance.new("Camera")
    cam.CFrame = CFrame.new(Vector3.new(0, 0, 5), Vector3.new(0, 0, 0))
    vf.CurrentCamera = cam
    cam.Parent = vf

    -- カード代わりのPart
    local part = Instance.new("Part")
    part.Size = Vector3.new(3, 4, 0.1)
    part.Anchored = true
    part.CFrame = CFrame.new(0, 0, 0)

    -- レアリティカラー
    local rarityColors = {
        SSR = BrickColor.new("Bright yellow"),
        SR  = BrickColor.new("Medium lilac"),
        R   = BrickColor.new("Bright blue"),
        N   = BrickColor.new("Medium stone grey"),
    }
    part.BrickColor = rarityColors[rarity] or rarityColors.N
    part.Material = Enum.Material.SmoothPlastic
    part.Parent = vf

    -- カード名テキスト（BillboardGui）
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 40)
    bb.StudsOffset = Vector3.new(0, 0, 0.1)
    bb.AlwaysOnTop = true
    bb.Parent = part

    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundTransparency = 1
    tl.Text = skinName or "???"
    tl.TextColor3 = Color3.fromRGB(255, 255, 255)
    tl.Font = Enum.Font.GothamBold
    tl.TextScaled = true
    tl.Parent = bb

    -- 回転アニメーション
    local angle = 0
    local conn
    conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
        angle = angle + dt * 120  -- 120°/秒で回転
        part.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(angle), 0)
    end)

    -- 2秒後に消す
    task.delay(2.2, function()
        conn:Disconnect()
        TweenService:Create(vf, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play()
        task.delay(0.5, function() vf:Destroy() end)
    end)
end

-- ============================================
-- SE定義（Roblox無料サウンドID使用）
-- ============================================
local function makeSound(id, vol, pitch)
    local s = Instance.new("Sound")
    s.SoundId    = "rbxassetid://" .. tostring(id)
    s.Volume     = vol or 0.5
    s.PlayOnRemove = false
    s.RollOffMaxDistance = 0
    s.Parent     = SoundService
    return s
end

-- Roblox無料SE（差し替え可能なデフォルトID）
local SE = {
    click   = makeSound(6042053626, 0.4),   -- UIクリック音
    match   = makeSound(4612332557, 0.6),   -- マッチング開始
    start   = makeSound(1837695891, 0.7),   -- バトル開始
    win     = makeSound(4612332557, 0.8),   -- 勝利
    lose    = makeSound(2375411638, 0.5),   -- 敗北
    card    = makeSound(3139810796, 0.4),   -- カードプレイ
    gacha   = makeSound(4612332557, 0.6),   -- ガチャ
}

local function playse(name)
    local s = SE[name]
    if s then s:Play() end
end

-- ============================================
-- カメラ固定 & キャラ非表示（シャドウバース式2D UI）
-- 3Dワールドが一切見えないようにする
-- ============================================
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local function lockCamera()
    local cam = Workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Scriptable
    -- 真っ暗な位置にカメラを向ける（地面の下）
    cam.CFrame = CFrame.new(Vector3.new(0, -9999, 0), Vector3.new(0, -9998, 0))
end

local function hideCharacter()
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.Transparency = 1
            end
        end
        -- アニメーション停止・コリジョン無効
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 0
            hum.JumpPower = 0
        end
    end
end

-- 即座に実行
lockCamera()
hideCharacter()

-- キャラクターがリスポーンしたときも再適用
LocalPlayer.CharacterAdded:Connect(function()
    task.wait()  -- 1フレーム待ってからパーツが揃う
    lockCamera()
    hideCharacter()
end)

-- ============================================
-- パートナーウィンドウ（左上）
-- ============================================
local PartnerWin = makeFrame(ScreenGui,
    UDim2.new(0.28, 0, 0.18, 0),
    UDim2.new(0.01, 0, 0.01, 0),
    Color3.fromRGB(10, 15, 30), "PartnerWindow")
PartnerWin.BackgroundTransparency = 0.15
makeRound(PartnerWin, 0.08)

-- パートナーアイコン
local PartnerIcon = makeFrame(PartnerWin,
    UDim2.new(0.25, 0, 0.9, 0),
    UDim2.new(0.02, 0, 0.05, 0),
    Color3.fromRGB(40, 60, 100), "Icon")
makeRound(PartnerIcon, 0.5)

local PartnerNameLabel = makeText(PartnerWin,
    "ハルト", UDim2.new(0.7, 0, 0.35, 0),
    UDim2.new(0.28, 0, 0.0, 0),
    Color3.fromRGB(180, 220, 255), "PartnerName")
PartnerNameLabel.TextXAlignment = Enum.TextXAlignment.Left

local PartnerMsgLabel = makeText(PartnerWin,
    "カードを選ぼう！", UDim2.new(0.98, 0, 0.55, 0),
    UDim2.new(0.01, 0, 0.38, 0),
    Color3.fromRGB(220, 240, 220), "PartnerMsg")
PartnerMsgLabel.TextXAlignment = Enum.TextXAlignment.Left
PartnerMsgLabel.TextWrapped    = true

-- ============================================
-- ジェム表示（右上）
-- ============================================
local GemFrame = makeFrame(ScreenGui,
    UDim2.new(0.18, 0, 0.07, 0),
    UDim2.new(0.81, 0, 0.01, 0),
    Color3.fromRGB(20, 10, 40), "GemFrame")
makeRound(GemFrame, 0.3)
local GemLabel = makeText(GemFrame,
    "💎 50", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(255, 215, 0), "GemLabel")

-- ============================================
-- 盤面表示（中央）
-- ============================================
local BoardFrame = makeFrame(ScreenGui,
    UDim2.new(0.98, 0, 0.42, 0),
    UDim2.new(0.01, 0, 0.21, 0),
    Color3.fromRGB(15, 25, 15), "BoardFrame")
makeRound(BoardFrame, 0.03)

-- プレイヤー列表示を作る関数
local ColumnFrames = {}  -- [playerId][col]

local function buildPlayerPanel(parent, pos, name)
    local pf = makeFrame(parent,
        UDim2.new(0.23, 0, 0.96, 0),
        pos,
        Color3.fromRGB(25, 35, 25), name)
    makeRound(pf, 0.06)

    local nameL = makeText(pf, name,
        UDim2.new(1, 0, 0.12, 0), UDim2.new(0, 0, 0, 0),
        Color3.fromRGB(200, 255, 200), "NameLabel", 14)

    -- 3列の積み上げバー
    local cols = {}
    for i = 1, 3 do
        local col = makeFrame(pf,
            UDim2.new(0.3, 0, 0.6, 0),
            UDim2.new((i-1)*0.33, 0, 0.2, 0),
            Color3.fromRGB(30, 50, 30), "Col"..i)
        makeRound(col, 0.1)
        local bar = makeFrame(col,
            UDim2.new(1, 0, 0, 0),  -- 高さ0で開始→更新時に変える
            UDim2.new(0, 0, 1, 0),
            Color3.fromRGB(80, 200, 80), "Bar")
        bar.AnchorPoint = Vector2.new(0, 1)
        local cnt = makeText(col, "0",
            UDim2.new(1, 0, 0.2, 0), UDim2.new(0, 0, 0, 0),
            Color3.fromRGB(255, 255, 255), "Count")
        cols[i] = {frame = col, bar = bar, count = cnt}
    end

    -- シールド表示
    local shieldRow = makeFrame(pf,
        UDim2.new(0.96, 0, 0.12, 0),
        UDim2.new(0.02, 0, 0.83, 0),
        Color3.fromRGB(0,0,0,0), "ShieldRow")
    shieldRow.BackgroundTransparency = 1
    local shields = {}
    for i = 1, 3 do
        local s = makeFrame(shieldRow,
            UDim2.new(0.3, 0, 1, 0),
            UDim2.new((i-1)*0.33, 0, 0, 0),
            Color3.fromRGB(50, 80, 120), "S"..i)
        makeRound(s, 0.15)
        shields[i] = s
    end

    return {panel=pf, name=nameL, cols=cols, shields=shields}
end

-- 4人分パネル（後から動的に構築するが、仮で2チーム分の位置を決める）
-- チームB（敵）上段、チームA（味方）下段
local PanelRefs = {}

-- ============================================
-- 手札（画面下部）
-- ============================================
-- スートバッジ（バトル中・左上に表示）
local SuitBadge = makeFrame(ScreenGui,
    UDim2.new(0.18, 0, 0.05, 0),
    UDim2.new(0.01, 0, 0.08, 0))
SuitBadge.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
SuitBadge.BackgroundTransparency = 0.3
SuitBadge.Visible = false

local SuitBadgeLabel = Instance.new("TextLabel")
SuitBadgeLabel.Name = "SuitText"
SuitBadgeLabel.Size = UDim2.new(1,0,1,0)
SuitBadgeLabel.BackgroundTransparency = 1
SuitBadgeLabel.Font = Enum.Font.GothamBold
SuitBadgeLabel.TextSize = 14
SuitBadgeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SuitBadgeLabel.Text = "♣ club"
SuitBadgeLabel.Parent = SuitBadge

local HandFrame = makeFrame(ScreenGui,
    UDim2.new(0.98, 0, 0.22, 0),
    UDim2.new(0.01, 0, 0.64, 0),
    Color3.fromRGB(10, 10, 20), "HandFrame")
makeRound(HandFrame, 0.05)

local PhaseLabel = makeText(HandFrame,
    "待機中...",
    UDim2.new(1, 0, 0.18, 0),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(200, 255, 200), "PhaseLabel")

local CardContainer = makeFrame(HandFrame,
    UDim2.new(1, 0, 0.75, 0),
    UDim2.new(0, 0, 0.22, 0),
    Color3.fromRGB(0,0,0), "CardContainer")
CardContainer.BackgroundTransparency = 1

-- ============================================
-- カードUI生成
-- ============================================
local SUIT_COLORS = {
    heart   = Color3.fromRGB(220, 60, 80),
    diamond = Color3.fromRGB(220, 100, 40),
    club    = Color3.fromRGB(60, 200, 100),
    spade   = Color3.fromRGB(80, 120, 220),
}
local SUIT_SYMBOLS = {heart="♥", diamond="♦", club="♣", spade="♠"}
local RANK_STR = {[1]="A",[11]="J",[12]="Q",[13]="K"}
local function rankStr(r)
    return RANK_STR[r] or tostring(r)
end

local function makeCardFrame(parent, card, pos, size, clickable)
    size = size or UDim2.new(0.12, 0, 0.85, 0)
    local cf = makeFrame(parent, size, pos,
        Color3.fromRGB(250, 248, 240), "Card_"..card.id)
    makeRound(cf, 0.1)
    cf.BackgroundColor3 = Color3.fromRGB(250, 248, 240)

    local color = SUIT_COLORS[card.suit] or Color3.fromRGB(50,50,50)
    local sym   = SUIT_SYMBOLS[card.suit] or "?"

    local rankL = makeText(cf, rankStr(card.rank),
        UDim2.new(1, 0, 0.35, 0), UDim2.new(0, 0, 0.02, 0),
        color, "Rank")
    local suitL = makeText(cf, sym,
        UDim2.new(1, 0, 0.35, 0), UDim2.new(0, 0, 0.35, 0),
        color, "Suit")

    if clickable then
        local btn = Instance.new("TextButton")
        btn.Size               = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text               = ""
        btn.Parent             = cf

        -- ホバー演出
        btn.MouseEnter:Connect(function()
            TweenService:Create(cf,
                TweenInfo.new(0.1), {Position = pos - UDim2.new(0, 0, 0.05, 0)}
            ):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(cf,
                TweenInfo.new(0.1), {Position = pos}
            ):Play()
        end)

        return cf, btn
    end
    return cf
end

-- ============================================
-- 手札描画
-- ============================================
local CurrentHand = {}

local function drawHand(hand, phase, roomId)
    -- 既存カードを全削除
    for _, c in ipairs(CardContainer:GetChildren()) do c:Destroy() end
    CurrentHand = hand

    if not hand or #hand == 0 then return end

    local count = #hand
    local spacing = math.min(0.12, 0.85 / count)

    for i, card in ipairs(hand) do
        local pos = UDim2.new((i-1)*spacing + 0.05, 0, 0.05, 0)
        local cf, btn = makeCardFrame(CardContainer, card, pos,
            UDim2.new(spacing*0.9, 0, 0.88, 0), true)

        btn.MouseButton1Click:Connect(function()
            if not phase then return end
            -- 選択中の強調
            if SelectedCard then
                local prev = CardContainer:FindFirstChild("Card_"..SelectedCard.id)
                if prev then
                    TweenService:Create(prev, TweenInfo.new(0.1),
                        {BackgroundColor3 = Color3.fromRGB(250, 248, 240)}):Play()
                end
            end
            SelectedCard = card
            TweenService:Create(cf, TweenInfo.new(0.1),
                {BackgroundColor3 = Color3.fromRGB(255, 240, 100)}):Play()

            -- フェーズに応じてサーバーに送信
            if phase == "road" then
                RE_RoadSelect:FireServer({roomId = roomId, cardId = card.id})
            elseif phase == "battle" then
                playse("card")
                -- 高ランクカード演出
                if (card.rank or 0) >= 9 then
                    local flash = Instance.new("Frame")
                    flash.Size = UDim2.new(1,0,1,0)
                    flash.BackgroundColor3 = Color3.fromRGB(255,220,50)
                    flash.BackgroundTransparency = 0.6
                    flash.ZIndex = 150
                    flash.Parent = ScreenGui
                    TweenService:Create(flash, TweenInfo.new(0.3), {BackgroundTransparency=1}):Play()
                    task.delay(0.35, function() flash:Destroy() end)
                elseif (card.rank or 0) >= 7 then
                    local flash = Instance.new("Frame")
                    flash.Size = UDim2.new(1,0,1,0)
                    flash.BackgroundColor3 = Color3.fromRGB(100,150,255)
                    flash.BackgroundTransparency = 0.75
                    flash.ZIndex = 150
                    flash.Parent = ScreenGui
                    TweenService:Create(flash, TweenInfo.new(0.2), {BackgroundTransparency=1}):Play()
                    task.delay(0.25, function() flash:Destroy() end)
                end
                RE_BattleSelect:FireServer({roomId = roomId, cardId = card.id})
            end
            SelectedCard = nil
        end)
    end
end

-- ============================================
-- 盤面更新
-- ============================================
local function updateBoardView(data)
    -- data.columns = {[userId] = {col1=N, col2=N, col3=N, chips=N}}
    for _, panel in pairs(PanelRefs) do
        local uid = panel.userId
        if data.columns and data.columns[uid] then
            local c = data.columns[uid]
            local vals = {c.col1 or 0, c.col2 or 0, c.col3 or 0}
            for i = 1, 3 do
                local n = vals[i]
                panel.cols[i].count.Text = tostring(n)
                local pct = n / 7
                TweenService:Create(panel.cols[i].bar,
                    TweenInfo.new(0.3, Enum.EasingStyle.Quad),
                    {Size = UDim2.new(1, 0, pct, 0)}
                ):Play()
                -- 7枚に近づくと色が変わる
                local r = math.floor(pct * 200)
                TweenService:Create(panel.cols[i].bar,
                    TweenInfo.new(0.3),
                    {BackgroundColor3 = Color3.fromRGB(80+r, 200-r, 80)}
                ):Play()
            end
        end
    end
end

-- ============================================
-- ガチャUI
-- ============================================
local GachaScreen = makeFrame(ScreenGui,
    UDim2.new(1, 0, 1, 0),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(5, 5, 20), "GachaScreen")
GachaScreen.ZIndex = 50
GachaScreen.Visible = false

-- 背景グラデーション
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 5, 40)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 20, 50)),
})
grad.Rotation = 135
grad.Parent = GachaScreen

-- ガチャタイトル
makeText(GachaScreen, "✦ ガチャ ✦",
    UDim2.new(0.5, 0, 0.1, 0),
    UDim2.new(0.25, 0, 0.02, 0),
    Color3.fromRGB(255, 215, 0), "GachaTitle")

-- ピティ表示
local PityLabel = makeText(GachaScreen, "天井: 0/100",
    UDim2.new(0.3, 0, 0.06, 0),
    UDim2.new(0.35, 0, 0.13, 0),
    Color3.fromRGB(200, 200, 255), "PityLabel")

-- ジェム表示
local GachaGemLabel = makeText(GachaScreen, "💎 0",
    UDim2.new(0.3, 0, 0.06, 0),
    UDim2.new(0.35, 0, 0.2, 0),
    Color3.fromRGB(255, 215, 0), "GachaGemLabel")

-- 結果表示エリア
local ResultArea = makeFrame(GachaScreen,
    UDim2.new(0.9, 0, 0.35, 0),
    UDim2.new(0.05, 0, 0.27, 0),
    Color3.fromRGB(10, 10, 30), "ResultArea")
makeRound(ResultArea, 0.05)

-- 1回・10回ボタン
local Roll1Btn = makeButton(GachaScreen, "1回引く（150💎）",
    UDim2.new(0.35, 0, 0.09, 0),
    UDim2.new(0.08, 0, 0.65, 0),
    Color3.fromRGB(60, 100, 180), "Roll1Btn")

local Roll10Btn = makeButton(GachaScreen, "10回引く（1350💎）",
    UDim2.new(0.35, 0, 0.09, 0),
    UDim2.new(0.57, 0, 0.65, 0),
    Color3.fromRGB(120, 60, 180), "Roll10Btn")

-- 閉じるボタン
local CloseGachaBtn = makeButton(GachaScreen, "✕ 閉じる",
    UDim2.new(0.25, 0, 0.07, 0),
    UDim2.new(0.375, 0, 0.77, 0),
    Color3.fromRGB(80, 30, 30), "CloseGacha")

-- ============================================
-- ガチャ演出
-- ============================================
local RARITY_COLORS = {
    SSR = Color3.fromRGB(255, 215, 0),
    SR  = Color3.fromRGB(180, 100, 220),
    R   = Color3.fromRGB(100, 150, 255),
    N   = Color3.fromRGB(160, 160, 160),
}

-- ============================================
-- レアリティ別ガチャ演出
-- ============================================
local function playGachaRevelAnimation(rarity, onDone)
    local overlay = Instance.new("Frame")
    overlay.Name   = "GachaReveal"
    overlay.Size   = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
    overlay.BackgroundTransparency = 1
    overlay.ZIndex = 200
    overlay.Parent = ScreenGui

    local label = Instance.new("TextLabel")
    label.Size   = UDim2.new(1,0,0.3,0)
    label.Position = UDim2.new(0,0,0.35,0)
    label.BackgroundTransparency = 1
    label.ZIndex = 201
    label.Parent = overlay

    if rarity == "SSR" then
        -- 金フラッシュ → テキスト出現
        overlay.BackgroundColor3 = Color3.fromRGB(255,215,0)
        overlay.BackgroundTransparency = 0
        label.Text = "✦✦✦  S S R  ✦✦✦"
        label.TextColor3 = Color3.fromRGB(255,255,200)
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        -- 点滅3回
        for i = 1, 3 do
            TweenService:Create(overlay, TweenInfo.new(0.12), {BackgroundTransparency=0.9}):Play()
            task.wait(0.15)
            TweenService:Create(overlay, TweenInfo.new(0.12), {BackgroundTransparency=0}):Play()
            task.wait(0.15)
        end
        task.wait(0.5)
        -- パーティクル的な星を複数生成
        for i = 1, 8 do
            local star = Instance.new("TextLabel")
            star.Size = UDim2.new(0,40,0,40)
            star.Position = UDim2.new(math.random(10,90)/100, 0, math.random(10,90)/100, 0)
            star.BackgroundTransparency = 1
            star.Text = "✦"
            star.TextColor3 = Color3.fromRGB(255,255,150)
            star.TextScaled = true
            star.ZIndex = 202
            star.Parent = overlay
            TweenService:Create(star, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {TextTransparency=1, Position=UDim2.new(star.Position.X.Scale, 0, star.Position.Y.Scale-0.2, 0)}):Play()
        end
        task.wait(1.0)

    elseif rarity == "SR" then
        -- 紫グロー
        overlay.BackgroundColor3 = Color3.fromRGB(80,0,180)
        overlay.BackgroundTransparency = 0.1
        label.Text = "✦✦  S R  ✦✦"
        label.TextColor3 = Color3.fromRGB(220,180,255)
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        TweenService:Create(overlay, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
            {BackgroundColor3=Color3.fromRGB(140,40,255)}):Play()
        task.wait(1.0)

    elseif rarity == "R" then
        -- 青い短いフラッシュ
        overlay.BackgroundColor3 = Color3.fromRGB(20,80,200)
        overlay.BackgroundTransparency = 0.4
        label.Text = "✦  R a r e  ✦"
        label.TextColor3 = Color3.fromRGB(180,210,255)
        label.Font = Enum.Font.GothamBold
        label.TextScaled = true
        task.wait(0.5)
    end

    -- フェードアウト
    TweenService:Create(overlay, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play()
    TweenService:Create(label, TweenInfo.new(0.4), {TextTransparency=1}):Play()
    task.delay(0.5, function()
        overlay:Destroy()
        if onDone then onDone() end
    end)
end

local function showGachaResults(results)
    for _, c in ipairs(ResultArea:GetChildren()) do c:Destroy() end

    -- 最高レアリティを検出して演出
    local topRarity = "N"
    local rarityOrder = {SSR=4, SR=3, R=2, N=1}
    for _, res in ipairs(results) do
        local r = res.skin and res.skin.rarity or "N"
        if (rarityOrder[r] or 0) > (rarityOrder[topRarity] or 0) then
            topRarity = r
        end
    end
    -- SR以上は演出を挟む
    if topRarity == "SSR" or topRarity == "SR" or topRarity == "R" then
        task.spawn(function()
            playGachaRevelAnimation(topRarity, nil)
        end)
        -- SSRはさらにViewportFrame演出
        if topRarity == "SSR" then
            local ssrSkin = nil
            for _, res in ipairs(results) do
                if res.skin and res.skin.rarity == "SSR" then
                    ssrSkin = res.skin; break
                end
            end
            task.spawn(function()
                task.wait(0.5)
                playCardViewport("SSR", ssrSkin and ssrSkin.name or "SSR")
            end)
        end
        task.wait(topRarity == "SSR" and 2.0 or topRarity == "SR" and 1.2 or 0.6)
    end

    local count = #results
    local cols  = math.min(count, 5)
    local rows  = math.ceil(count / cols)

    for i, res in ipairs(results) do
        local col = ((i-1) % cols)
        local row = math.floor((i-1) / cols)
        local skin = res.skin

        local card = makeFrame(ResultArea,
            UDim2.new(0.18, 0, 0.42, 0),
            UDim2.new(col*0.19+0.02, 0, row*0.48+0.04, 0),
            Color3.fromRGB(20, 20, 40), "Result"..i)
        makeRound(card, 0.1)
        card.BackgroundTransparency = 1

        -- フリップアニメーション：最初は非表示→タイムラグ後に出す
        task.delay(i * 0.12, function()
            -- 出現
            TweenService:Create(card,
                TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {BackgroundTransparency = 0}
            ):Play()
            card.BackgroundColor3 = RARITY_COLORS[skin.rarity] or Color3.fromRGB(60,60,60)

            makeText(card, skin.rarity,
                UDim2.new(1, 0, 0.25, 0),
                UDim2.new(0, 0, 0.02, 0),
                Color3.fromRGB(255,255,255), "Rarity")

            makeText(card, skin.name,
                UDim2.new(0.95, 0, 0.45, 0),
                UDim2.new(0.025, 0, 0.3, 0),
                Color3.fromRGB(255,255,255), "Name").TextWrapped = true

            if res.isDupe then
                makeText(card, "✦共鳴",
                    UDim2.new(1, 0, 0.2, 0),
                    UDim2.new(0, 0, 0.78, 0),
                    Color3.fromRGB(255, 160, 50), "DupeLabel")
            end

            -- SSRだと背景光りエフェクト
            if skin.rarity == "SSR" then
                TweenService:Create(card,
                    TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true),
                    {BackgroundColor3 = Color3.fromRGB(255, 240, 100)}
                ):Play()
            end
        end)
    end
end

-- ガチャボタン処理
Roll1Btn.MouseButton1Click:Connect(function()
    playse("gacha")
    RE_GachaRoll:FireServer(1)
end)
Roll10Btn.MouseButton1Click:Connect(function()
    RE_GachaRoll:FireServer(10)
end)
CloseGachaBtn.MouseButton1Click:Connect(function()
    GachaScreen.Visible = false
end)

-- ============================================
-- ロビー（メインメニュー）
-- ============================================
local LobbyScreen = makeFrame(ScreenGui,
    UDim2.new(1, 0, 1, 0),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(8, 12, 25), "LobbyScreen")
LobbyScreen.ZIndex = 40

-- タイトル
makeText(LobbyScreen, "GAME ROAD",
    UDim2.new(0.7, 0, 0.15, 0),
    UDim2.new(0.15, 0, 0.05, 0),
    Color3.fromRGB(255, 215, 0), "Title")

-- ステータスバー（タイトル下：ジェム / ELO / 戦績）
local StatusBar = Instance.new("Frame")
StatusBar.Name              = "StatusBar"
StatusBar.Size              = UDim2.new(0.96, 0, 0.05, 0)
StatusBar.Position          = UDim2.new(0.02, 0, 0.11, 0)
StatusBar.BackgroundColor3  = Color3.fromRGB(12, 18, 40)
StatusBar.BackgroundTransparency = 0.3
StatusBar.BorderSizePixel   = 0
StatusBar.ZIndex            = 41
StatusBar.Parent            = LobbyScreen
local sbc = Instance.new("UICorner"); sbc.CornerRadius = UDim.new(0.4,0); sbc.Parent = StatusBar

local LobbyGemLabel = Instance.new("TextLabel")
LobbyGemLabel.Name          = "LobbyGemLabel"
LobbyGemLabel.Size          = UDim2.new(0.33, 0, 1, 0)
LobbyGemLabel.Position      = UDim2.new(0, 0, 0, 0)
LobbyGemLabel.BackgroundTransparency = 1
LobbyGemLabel.Text          = "💎 --"
LobbyGemLabel.TextColor3    = Color3.fromRGB(255, 215, 0)
LobbyGemLabel.Font          = Enum.Font.GothamBold
LobbyGemLabel.TextScaled    = true
LobbyGemLabel.ZIndex        = 42
LobbyGemLabel.Parent        = StatusBar

local LobbyEloLabel = Instance.new("TextLabel")
LobbyEloLabel.Name          = "LobbyEloLabel"
LobbyEloLabel.Size          = UDim2.new(0.33, 0, 1, 0)
LobbyEloLabel.Position      = UDim2.new(0.33, 0, 0, 0)
LobbyEloLabel.BackgroundTransparency = 1
LobbyEloLabel.Text          = "ELO --"
LobbyEloLabel.TextColor3    = Color3.fromRGB(180, 160, 255)
LobbyEloLabel.Font          = Enum.Font.GothamBold
LobbyEloLabel.TextScaled    = true
LobbyEloLabel.ZIndex        = 42
LobbyEloLabel.Parent        = StatusBar

local LobbyRecordLabel = Instance.new("TextLabel")
LobbyRecordLabel.Name       = "LobbyRecordLabel"
LobbyRecordLabel.Size       = UDim2.new(0.34, 0, 1, 0)
LobbyRecordLabel.Position   = UDim2.new(0.66, 0, 0, 0)
LobbyRecordLabel.BackgroundTransparency = 1
LobbyRecordLabel.Text       = "0勝 0敗"
LobbyRecordLabel.TextColor3 = Color3.fromRGB(160, 220, 160)
LobbyRecordLabel.Font       = Enum.Font.Gotham
LobbyRecordLabel.TextScaled = true
LobbyRecordLabel.ZIndex     = 42
LobbyRecordLabel.Parent     = StatusBar

-- ══════════════════════════════════════════
-- モード選択ボタン
-- トランプ版 / TCG版 で別キューに入る
-- ══════════════════════════════════════════

-- セクションラベル
local function makeSectionLabel(parent, text, posY)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.80, 0, 0.05, 0)
    lbl.Position = UDim2.new(0.10, 0, posY, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(160,220,160)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
end

makeSectionLabel(LobbyScreen, "🃏 トランプ版（リアル同ルール）", 0.19)
makeSectionLabel(LobbyScreen, "✦ TCG版（スート特性あり）", 0.39)

local MODE_DEFS = {
    -- トランプ版
    { text="⚔ タッグ戦
2vs2",    pos=UDim2.new(0.05,0,0.24,0), color=Color3.fromRGB(40,80,160),  mode="tag_trump" },
    { text="🏆 バトロワ
4人",     pos=UDim2.new(0.54,0,0.24,0), color=Color3.fromRGB(140,60,40),  mode="battle_trump" },
    -- TCG版
    { text="⚔ タッグ戦
2vs2 ✦",  pos=UDim2.new(0.05,0,0.44,0), color=Color3.fromRGB(60,60,180),  mode="tag_tcg" },
    { text="🏆 バトロワ
4人 ✦",   pos=UDim2.new(0.54,0,0.44,0), color=Color3.fromRGB(160,40,40),  mode="battle_tcg" },
    -- 共通
    { text="🤖 AI練習
ソロ",       pos=UDim2.new(0.05,0,0.64,0), color=Color3.fromRGB(40,120,80),  mode="solo" },
    { text="✦ ガチャ
パートナー",  pos=UDim2.new(0.54,0,0.64,0), color=Color3.fromRGB(120,40,160), mode="gacha" },
}

local RE_MMJoin   = Remotes:WaitForChild("MatchmakingJoin", 10)
local RE_MMCancel   = Remotes:WaitForChild("MatchmakingCancel", 15)
local RE_FriendRoom = Remotes:WaitForChild("FriendRoom", 15)
local RE_Observe     = Remotes:WaitForChild("Observe", 15)
local RE_DeckRecipe  = Remotes:WaitForChild("DeckRecipe", 15)

-- ══════════════════════════════════════════
-- マッチング待機画面（ロビーを隠す専用画面）
-- ══════════════════════════════════════════
local MatchScreen = Instance.new("Frame")
MatchScreen.Name              = "MatchScreen"
MatchScreen.Size              = UDim2.new(1, 0, 1, 0)
MatchScreen.BackgroundColor3  = Color3.fromRGB(5, 8, 20)
MatchScreen.BorderSizePixel   = 0
MatchScreen.ZIndex            = 50
MatchScreen.Visible           = false
MatchScreen.Parent            = ScreenGui

local matchTitle = Instance.new("TextLabel")
matchTitle.Size               = UDim2.new(0.8, 0, 0.1, 0)
matchTitle.Position           = UDim2.new(0.1, 0, 0.35, 0)
matchTitle.BackgroundTransparency = 1
matchTitle.Text               = "対戦相手を探しています..."
matchTitle.TextColor3         = Color3.fromRGB(200, 220, 255)
matchTitle.Font               = Enum.Font.GothamBold
matchTitle.TextScaled         = true
matchTitle.ZIndex             = 51
matchTitle.Parent             = MatchScreen

-- くるくるアニメ用ラベル
local matchDots = Instance.new("TextLabel")
matchDots.Size                = UDim2.new(0.4, 0, 0.08, 0)
matchDots.Position            = UDim2.new(0.3, 0, 0.46, 0)
matchDots.BackgroundTransparency = 1
matchDots.Text                = "●"
matchDots.TextColor3          = Color3.fromRGB(100, 180, 255)
matchDots.Font                = Enum.Font.GothamBold
matchDots.TextScaled          = true
matchDots.ZIndex              = 51
matchDots.Parent              = MatchScreen

-- ドットアニメーション
task.spawn(function()
    local dots = {"●  ○  ○", "○  ●  ○", "○  ○  ●", "○  ●  ○"}
    local i = 1
    while true do
        if MatchScreen.Visible then
            matchDots.Text = dots[i]
            i = (i % #dots) + 1
        end
        task.wait(0.4)
    end
end)

-- モード名表示
local matchModeLabel = Instance.new("TextLabel")
matchModeLabel.Name           = "MatchModeLabel"
matchModeLabel.Size           = UDim2.new(0.6, 0, 0.06, 0)
matchModeLabel.Position       = UDim2.new(0.2, 0, 0.56, 0)
matchModeLabel.BackgroundTransparency = 1
matchModeLabel.Text           = ""
matchModeLabel.TextColor3     = Color3.fromRGB(150, 200, 150)
matchModeLabel.Font           = Enum.Font.Gotham
matchModeLabel.TextScaled     = true
matchModeLabel.ZIndex         = 51
matchModeLabel.Parent         = MatchScreen

-- キャンセルボタン
local cancelBtn = Instance.new("TextButton")
cancelBtn.Size                = UDim2.new(0.4, 0, 0.07, 0)
cancelBtn.Position            = UDim2.new(0.3, 0, 0.67, 0)
cancelBtn.BackgroundColor3    = Color3.fromRGB(80, 30, 30)
cancelBtn.TextColor3          = Color3.fromRGB(255, 180, 180)
cancelBtn.Text                = "✕ キャンセル"
cancelBtn.Font                = Enum.Font.GothamBold
cancelBtn.TextScaled          = true
cancelBtn.BorderSizePixel     = 0
cancelBtn.ZIndex              = 52
cancelBtn.Parent              = MatchScreen
local cancelCorner = Instance.new("UICorner")
cancelCorner.CornerRadius     = UDim.new(0.3, 0)
cancelCorner.Parent           = cancelBtn

cancelBtn.MouseButton1Click:Connect(function()
    if RE_MMCancel then RE_MMCancel:FireServer() end
    MatchScreen.Visible  = false
    LobbyScreen.Visible  = true
    matchTitle.Text      = "対戦相手を探しています..."
end)

local function showMatchScreen(modeName)
    LobbyScreen.Visible         = false
    MatchScreen.Visible         = true
    matchModeLabel.Text         = "モード: " .. (modeName or "")
    matchTitle.Text             = "対戦相手を探しています..."
end

for _, m in ipairs(MODE_DEFS) do
    local btn = makeButton(LobbyScreen, m.text,
        UDim2.new(0.38, 0, 0.16, 0),
        m.pos, m.color)
    btn.TextWrapped = true
    btn.TextSize    = 13

    btn.MouseButton1Click:Connect(function()
        if m.mode == "gacha" then
            GachaScreen.Visible = true
            return
        end
        -- マッチングキューに参加
        if RE_MMJoin then
            RE_MMJoin:FireServer(m.mode)
        end
        playse("match")  -- マッチング開始SE
        showMatchScreen(m.text:gsub("\n", " "))
    end)
end

-- 購入ボタン（Robux）
local ShopFrame = makeFrame(LobbyScreen,
    UDim2.new(0.8, 0, 0.08, 0),
    UDim2.new(0.1, 0, 0.89, 0),
    Color3.fromRGB(20, 15, 40), "ShopFrame")
makeRound(ShopFrame, 0.08)
makeText(ShopFrame, "💎 ジェムをRobuxで購入",
    UDim2.new(1, 0, 0.5, 0),
    UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(220, 220, 255), "ShopTitle")

local shopItems = {
    {name="x100", productId=1111111, pos=UDim2.new(0.02,0,0.52,0)},
    {name="x600", productId=1111112, pos=UDim2.new(0.35,0,0.52,0)},
    {name="x1300",productId=1111113, pos=UDim2.new(0.68,0,0.52,0)},
}
for _, item in ipairs(shopItems) do
    local btn = makeButton(ShopFrame, "💎"..item.name,
        UDim2.new(0.28, 0, 0.42, 0),
        item.pos, Color3.fromRGB(60, 40, 100))
    local pid = item.productId
    btn.MouseButton1Click:Connect(function()
        RE_BuyProduct:FireServer(pid)
    end)
end

-- ============================================
-- サーバーからのイベント受信
-- ============================================
RE_UpdateBoard.OnClientEvent:Connect(function(data)
    if not data or not data.type then return end
    local t = data.type

    if t == "player_data" then
        PlayerData = data
        PlayerGems = data.gems or 0
        GemLabel.Text = "💎 " .. PlayerGems
        GachaGemLabel.Text = "💎 " .. PlayerGems
        -- ロビーステータスバー更新
        local pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
        local sb = pg and pg:FindFirstChild("GameRoadUI") and
                   pg.GameRoadUI:FindFirstChild("LobbyScreen") and
                   pg.GameRoadUI.LobbyScreen:FindFirstChild("StatusBar")
        if LobbyGemLabel then LobbyGemLabel.Text = "💎 " .. PlayerGems end
        local stats = data.stats or {}
        if LobbyRecordLabel then
            LobbyRecordLabel.Text = string.format("%d勝 %d敗", stats.wins or 0, stats.losses or 0)
        end
        if LobbyEloLabel then
            local elo = (stats and stats.elo) or 1000
            LobbyEloLabel.Text = "ELO " .. elo
        end

    elseif t == "daily_login" then
        -- ログインボーナス：左端スライドイン
        GemLabel.Text = "💎 " .. data.totalGems
        GachaGemLabel.Text = "💎 " .. data.totalGems
        local toast = Instance.new("Frame")
        toast.Name = "LoginToast"
        toast.Size = UDim2.new(0, 220, 0, 48)
        toast.Position = UDim2.new(0, -230, 0.88, 0)  -- 画面外（左）からスタート
        toast.BackgroundColor3 = Color3.fromRGB(20, 50, 20)
        toast.BackgroundTransparency = 0.15
        toast.BorderSizePixel = 0
        toast.ZIndex = 90
        toast.Parent = ScreenGui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = toast
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -8, 1, 0)
        label.Position = UDim2.new(0, 8, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = "🎁 +" .. data.bonus .. "💎 ログインボーナス"
        label.TextColor3 = Color3.fromRGB(220, 255, 180)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 91
        label.Parent = toast
        -- スライドイン
        TweenService:Create(toast,
            TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = UDim2.new(0, 8, 0.88, 0)}
        ):Play()
        -- 2.5秒後にスライドアウト→削除
        task.delay(2.5, function()
            TweenService:Create(toast,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Position = UDim2.new(0, -230, 0.88, 0)}
            ):Play()
            task.delay(0.35, function() toast:Destroy() end)
        end)

    elseif t == "game_start" then
        CurrentRoomId  = data.roomId
        CurrentIsTCG   = data.isTCG or false
        PlayerRoster   = data.players or {}
        playse("start")  -- バトル開始SE
        if MatchScreen then MatchScreen.Visible = false end
        LobbyScreen.Visible = false
        PhaseLabel.Text = "ゲーム開始！"

        -- TCG版/トランプ版でUIを切り替え
        SuitBadge.Visible = CurrentIsTCG

        -- スートバッジ更新（TCG版のみ自分のスートを表示）
        if CurrentIsTCG then
            local myUserId = game.Players.LocalPlayer.UserId
            for _, p in ipairs(PlayerRoster) do
                if p.userId == myUserId then
                    local suitNames = {heart="♥ハルニア", diamond="♦ダイノス", club="♣クラディオン", spade="♠スペルニア"}
                    local suitColors = {
                        heart   = Color3.fromRGB(220, 60, 80),
                        diamond = Color3.fromRGB(220, 140, 40),
                        club    = Color3.fromRGB(40, 160, 80),
                        spade   = Color3.fromRGB(60, 100, 200),
                    }
                    SuitBadgeLabel.Text = suitNames[p.suit] or p.suit
                    SuitBadgeLabel.TextColor3 = suitColors[p.suit] or Color3.fromRGB(200,200,200)
                    break
                end
            end
        end

        -- プレイヤーパネルを動的に構築（名前を正しく表示）
        for _, ref in pairs(PanelRefs) do
            ref.panel:Destroy()
        end
        PanelRefs = {}
        -- チームA（味方：下段）、チームB（敵：上段）
        local teamA, teamB = {}, {}
        for _, p in ipairs(PlayerRoster) do
            if p.team == "A" then table.insert(teamA, p)
            else table.insert(teamB, p) end
        end
        local function buildPanels(list, baseY)
            for i, p in ipairs(list) do
                local xPos = (i == 1) and 0.01 or 0.52
                local ref = buildPlayerPanel(BoardFrame,
                    UDim2.new(0, 0, baseY, 0),
                    p.name or "プレイヤー")
                ref.panel.Position = UDim2.new(xPos, 0, baseY, 0)
                PanelRefs[p.userId] = ref
            end
        end
        buildPanels(teamB, 0.01)   -- 敵：上
        buildPanels(teamA, 0.52)   -- 自分チーム：下
        -- バトルUI表示
        BoardFrame.Visible = true
        HandFrame.Visible  = true
        GemFrame.Visible   = true
        PartnerWin.Visible = true

    elseif t == "request_arcana" then
        -- アルカナ選択UI（バトルUI上にオーバーレイ）
        local available = data.available or {}
        local banned    = data.banned or false
        local roomId    = data.roomId

        -- 既存のアルカナUIを削除
        for _, child in ipairs(ScreenGui:GetChildren()) do
            if child.Name == "ArcanaOverlay" then child:Destroy() end
        end

        local overlay = Instance.new("Frame")
        overlay.Name              = "ArcanaOverlay"
        overlay.Size              = UDim2.new(1, 0, 0.45, 0)
        overlay.Position          = UDim2.new(0, 0, 0.28, 0)
        overlay.BackgroundColor3  = Color3.fromRGB(10, 5, 30)
        overlay.BackgroundTransparency = 0.1
        overlay.ZIndex            = 80
        overlay.Parent            = ScreenGui

        local title = Instance.new("TextLabel")
        title.Size     = UDim2.new(1, 0, 0.15, 0)
        title.BackgroundTransparency = 1
        title.Text     = banned and "🚫 アルカナ封印中" or "✦ アルカナ選択（スキップ可）"
        title.TextColor3 = banned and Color3.fromRGB(200,100,100) or Color3.fromRGB(200,180,255)
        title.Font     = Enum.Font.GothamBold
        title.TextScaled = true
        title.ZIndex   = 81
        title.Parent   = overlay

        -- スキップボタン
        local skipBtn = Instance.new("TextButton")
        skipBtn.Size  = UDim2.new(0.25, 0, 0.18, 0)
        skipBtn.Position = UDim2.new(0.375, 0, 0.78, 0)
        skipBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        skipBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        skipBtn.Text  = "スキップ"
        skipBtn.Font  = Enum.Font.GothamBold
        skipBtn.TextScaled = true
        skipBtn.ZIndex = 82
        skipBtn.Parent = overlay
        local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0.3,0); sc.Parent = skipBtn
        skipBtn.MouseButton1Click:Connect(function()
            overlay:Destroy()
            RE_ArcanaSelect:FireServer({roomId=roomId, skip=true})
        end)

        -- アルカナカードボタン
        if not banned then
            local scroll = Instance.new("ScrollingFrame")
            scroll.Size  = UDim2.new(0.96, 0, 0.58, 0)
            scroll.Position = UDim2.new(0.02, 0, 0.17, 0)
            scroll.BackgroundTransparency = 1
            scroll.ScrollBarThickness = 4
            scroll.ZIndex = 81
            scroll.Parent = overlay
            local layout = Instance.new("UIListLayout")
            layout.FillDirection = Enum.FillDirection.Horizontal
            layout.Padding = UDim.new(0, 6)
            layout.Parent = scroll

            for _, arc in ipairs(available) do
                local btn = Instance.new("TextButton")
                btn.Size  = UDim2.new(0, 90, 0, 100)
                btn.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
                btn.TextColor3 = Color3.fromRGB(220, 200, 255)
                btn.Text  = arc.icon .. "
" .. arc.name
                btn.Font  = Enum.Font.Gotham
                btn.TextSize = 12
                btn.TextWrapped = true
                btn.ZIndex = 82
                btn.Parent = scroll
                local bc2 = Instance.new("UICorner"); bc2.CornerRadius = UDim.new(0.08,0); bc2.Parent = btn

                local arcNum = arc.n
                btn.MouseButton1Click:Connect(function()
                    -- 正位置/逆位置 選択ダイアログ
                    local dirFrame = Instance.new("Frame")
                    dirFrame.Size = UDim2.new(0.5, 0, 0.3, 0)
                    dirFrame.Position = UDim2.new(0.25, 0, 0.35, 0)
                    dirFrame.BackgroundColor3 = Color3.fromRGB(20, 10, 50)
                    dirFrame.ZIndex = 90
                    dirFrame.Parent = ScreenGui
                    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0.08,0); dc.Parent = dirFrame

                    local dlabel = Instance.new("TextLabel")
                    dlabel.Size = UDim2.new(1,0,0.35,0)
                    dlabel.BackgroundTransparency = 1
                    dlabel.Text = arc.icon .. " " .. arc.name
                    dlabel.TextColor3 = Color3.fromRGB(220,200,255)
                    dlabel.Font = Enum.Font.GothamBold
                    dlabel.TextScaled = true
                    dlabel.ZIndex = 91
                    dlabel.Parent = dirFrame

                    local targets = data.targets or {}
                    local tgtId = #targets > 0 and targets[1].id or nil

                    local function fireArcana(dir)
                        dirFrame:Destroy()
                        overlay:Destroy()
                        RE_ArcanaSelect:FireServer({
                            roomId    = roomId,
                            arcanaNum = arcNum,
                            direction = dir,
                            targetId  = tgtId,
                        })
                    end

                    local posBtn = Instance.new("TextButton")
                    posBtn.Size = UDim2.new(0.44,0,0.35,0)
                    posBtn.Position = UDim2.new(0.03,0,0.60,0)
                    posBtn.BackgroundColor3 = Color3.fromRGB(40,80,160)
                    posBtn.Text = "✦ 正位置
" .. (arc.posDesc or ""):sub(1,20)
                    posBtn.TextColor3 = Color3.fromRGB(200,220,255)
                    posBtn.Font = Enum.Font.Gotham
                    posBtn.TextSize = 10
                    posBtn.TextWrapped = true
                    posBtn.ZIndex = 91
                    posBtn.Parent = dirFrame
                    local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0.1,0); pc.Parent = posBtn
                    posBtn.MouseButton1Click:Connect(function() fireArcana("pos") end)

                    local negBtn = Instance.new("TextButton")
                    negBtn.Size = UDim2.new(0.44,0,0.35,0)
                    negBtn.Position = UDim2.new(0.53,0,0.60,0)
                    negBtn.BackgroundColor3 = Color3.fromRGB(120,30,60)
                    negBtn.Text = "▼ 逆位置
" .. (arc.negDesc or ""):sub(1,20)
                    negBtn.TextColor3 = Color3.fromRGB(255,180,200)
                    negBtn.Font = Enum.Font.Gotham
                    negBtn.TextSize = 10
                    negBtn.TextWrapped = true
                    negBtn.ZIndex = 91
                    negBtn.Parent = dirFrame
                    local nc = Instance.new("UICorner"); nc.CornerRadius = UDim.new(0.1,0); nc.Parent = negBtn
                    negBtn.MouseButton1Click:Connect(function() fireArcana("neg") end)
                end)
            end
            scroll.CanvasSize = UDim2.new(0, (#available * 96), 0, 0)
        end

        -- 15秒タイマー
        task.spawn(function()
            for i = 15, 1, -1 do
                if not overlay.Parent then return end
                task.wait(1)
            end
            if overlay.Parent then
                overlay:Destroy()
                RE_ArcanaSelect:FireServer({roomId=roomId, skip=true})
            end
        end)

    elseif t == "request_road" then
        CurrentPhase = "road"
        PhaseLabel.Text = "▶ ロードカードを選んでください"
        PartnerMsgLabel.Text = "ロードを出そう！高い方が攻撃権を取れるよ！"
        drawHand(data.hand, "road", CurrentRoomId)

    elseif t == "request_battle" then
        CurrentPhase = "battle"
        PhaseLabel.Text = "⚔ バトルカードを選んでください"
        local defCard = data.defenderShield
        local msg = defCard
            and ("相手のシールドは" .. rankStr(defCard.rank) .. "！それより高いカードを出そう！")
            or  ("バトルカードを選ぼう！")
        PartnerMsgLabel.Text = msg
        drawHand(data.hand, "battle", CurrentRoomId)

    elseif t == "request_target" then
        -- ターゲット選択UI（簡易版：敵プレイヤーのシールドをボタンで選ぶ）
        CurrentPhase = "target"
        PhaseLabel.Text = "🎯 攻撃する相手のシールドを選んでください"
        PartnerMsgLabel.Text = "どの相手を狙う？列が多い相手を崩すのがおすすめ！"
        -- CardContainerに敵シールドボタンを表示
        for _, c in ipairs(CardContainer:GetChildren()) do c:Destroy() end
        for _, enemy in ipairs(data.enemies or {}) do
            for si, shield in ipairs(enemy.shields or {}) do
                local pos = UDim2.new((si-1)*0.15 + 0.05, 0, 0.05, 0)
                local sf = makeFrame(CardContainer,
                    UDim2.new(0.12, 0, 0.85, 0),
                    pos, Color3.fromRGB(60, 40, 40), "Shield"..si)
                makeRound(sf, 0.1)
                makeText(sf, enemy.name.."\nシールド"..si,
                    UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
                    Color3.fromRGB(255,200,200), "SLabel").TextWrapped = true
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1,0,1,0)
                btn.BackgroundTransparency = 1
                btn.Text = ""
                btn.Parent = sf
                local eid, sidx = enemy.id, si
                btn.MouseButton1Click:Connect(function()
                    RE_TargetSelect:FireServer({
                        roomId = CurrentRoomId,
                        targetUserId = eid,
                        shieldIdx = sidx,
                    })
                    CurrentPhase = nil
                    for _, c in ipairs(CardContainer:GetChildren()) do c:Destroy() end
                    PhaseLabel.Text = "待機中..."
                end)
            end
        end

    elseif t == "road_reveal" then
        PhaseLabel.Text = "ロード公開！"
        -- ♠ Spade info: 相手のロードが見える
        if data.enemyRoad then
            local msgs = {}
            for uid, card in pairs(data.enemyRoad) do
                table.insert(msgs, string.format("👁 相手ロード: %s%s",
                    card.suit or "?", tostring(card.rank or "?")))
            end
            if #msgs > 0 then
                PartnerMsgLabel.Text = table.concat(msgs, "  ")
                task.delay(2.5, function() PartnerMsgLabel.Text = "" end)
            end
        end

    elseif t == "battle_result" then
        updateBoardView(data)
        local winner = data.winnerId == LocalPlayer.UserId
        if data.victory then
            local isWin = data.victory == PlayerData.team
            if isWin then
                PhaseLabel.Text = "🏆 やったね！"
                PartnerMsgLabel.Text = "一緒に勝てた！"
            else
                PhaseLabel.Text = ""
                PartnerMsgLabel.Text = "今日もよくやったよ"
            end
        end

    elseif t == "battle_end_comfort" then
        PhaseLabel.Text = ""
        local lines = data.lines or {}
        if data.greeting then
            PartnerMsgLabel.Text = data.greeting
            if lines[1] then task.delay(2.5, function() PartnerMsgLabel.Text = lines[1] end) end
            if lines[2] then task.delay(5.5, function() PartnerMsgLabel.Text = lines[2] end) end
        else
            if lines[1] then PartnerMsgLabel.Text = lines[1] end
            if lines[2] then task.delay(3, function() PartnerMsgLabel.Text = lines[2] end) end
        end

    elseif t == "game_over" then
        -- 勝敗トースト（左端スライドイン）
        -- disconnect_win = 相手切断による勝利
        if MatchScreen then MatchScreen.Visible = false end
        local isWin = (data and data.victory == "disconnect_win") or
                      (data and data.victory == data.playerTeam)
        playse(isWin and "win" or "lose")
        -- パートナーホームコメント用にバトル結果を記録
        _G.LastBattleResult = isWin and "win" or "lose"
        -- ホームパートナーに勝敗コメントを出す
        task.delay(4, function()
            if _G.ShowHomePartner then _G.ShowHomePartner() end
            -- homeRandLineはPartnerAmie内にあるが_G経由でアクセスできない
            -- UpdateBoard経由でpartner_result通知を送る
        end)
        local toastColor = isWin and Color3.fromRGB(20,60,20) or Color3.fromRGB(60,20,20)
        local toastText  = isWin and "🏆 勝利！" or "💀 敗北…"
        local toast2 = Instance.new("Frame")
        toast2.Name = "GameOverToast"
        toast2.Size = UDim2.new(0, 200, 0, 52)
        toast2.Position = UDim2.new(0, -210, 0.42, 0)
        toast2.BackgroundColor3 = toastColor
        toast2.BackgroundTransparency = 0.1
        toast2.BorderSizePixel = 0
        toast2.ZIndex = 90
        toast2.Parent = ScreenGui
        local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(0,8); c2.Parent = toast2
        local l2 = Instance.new("TextLabel")
        l2.Size = UDim2.new(1,0,1,0)
        l2.BackgroundTransparency = 1
        l2.Text = toastText
        l2.TextColor3 = Color3.fromRGB(230,255,230)
        l2.Font = Enum.Font.GothamBold
        l2.TextSize = 20
        l2.ZIndex = 91
        l2.Parent = toast2
        TweenService:Create(toast2,
            TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = UDim2.new(0, 8, 0.42, 0)}
        ):Play()
        task.wait(2.5)
        TweenService:Create(toast2,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0, -210, 0.42, 0)}
        ):Play()
        task.delay(0.35, function() toast2:Destroy() end)
        task.wait(0.5)
        -- バトルUI非表示
        BoardFrame.Visible = false
        HandFrame.Visible  = false
        GemFrame.Visible   = false
        PartnerWin.Visible = false
        LobbyScreen.Visible = true

    elseif t == "gacha_result" then
        PlayerGems = data.totalGems or PlayerGems
        GemLabel.Text = "💎 " .. PlayerGems
        GachaGemLabel.Text = "💎 " .. PlayerGems
        if data.pity then
            PityLabel.Text = "天井: " .. data.pity .. "/100"
        end
        showGachaResults(data.results or {})

    elseif t == "purchase_complete" then
        PlayerGems = data.totalGems or PlayerGems
        GemLabel.Text = "💎 " .. PlayerGems
        GachaGemLabel.Text = "💎 " .. PlayerGems
        -- 購入成功通知
        local notif = makeFrame(ScreenGui,
            UDim2.new(0.5, 0, 0.1, 0),
            UDim2.new(0.25, 0, 0.44, 0),
            Color3.fromRGB(20, 50, 20), "PurchaseNotif")
        makeRound(notif, 0.1)
        notif.ZIndex = 100
        makeText(notif, "✅ " .. (data.productName or "購入") .. "完了！",
            UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
            Color3.fromRGB(200,255,200), "NotifText")
        if data.gachaResults then showGachaResults(data.gachaResults) end
        task.delay(2.5, function() notif:Destroy() end)

    elseif t == "gacha_error" then
        PartnerMsgLabel.Text = "⚠ " .. (data.message or "エラー")

    elseif t == "shield_broken" then
        PartnerMsgLabel.Text = "シールドを破壊！"

    -- ★ EXゾーン系イベント
    elseif t == "ex_state" then
        if not exZoneFrame then
            local sg = game.Players.LocalPlayer and
                       game.Players.LocalPlayer.PlayerGui
            local bg = sg and sg:FindFirstChild("BattleGui")
            buildEXZoneUI(bg)
        end
        updateEXZoneUI(data.myEX or {}, data.exCounts or {})

    elseif t == "kodou_consumed" then
        -- ハルニアの鼓動1枚消費（残り枚数表示）
        local remaining = data.remaining or 0
        PhaseLabel.Text = string.format("💔 ハルニアの鼓動 残り%d枚", remaining)
        -- EXステートも更新（broadcastEXStateが別途届く）

    elseif t == "ex_trigger_fired" then
        -- 旧イベント互換（将来削除）
        PhaseLabel.Text = "✦ EXトリガー発動！"

    elseif t == "halnia_defeated" then
        PartnerMsgLabel.Text = "💜 ハルニアの鼓動が失われた…"

    elseif t == "honey_added" then
        PartnerMsgLabel.Text = "🍯 蜜 +" .. (data.count or 1) ..
                               "（計" .. (data.total or 0) .. "枚）"

    elseif t == "honey_consumed" then
        PartnerMsgLabel.Text = "🍯 蜜を消費！ +" .. (data.bonus or 0) .. " パワー"

    elseif t == "nodrop_fired" then
        PartnerMsgLabel.Text = "↩ チップに行かず手札へ！"

    elseif t == "extra_col_fired" then
        PartnerMsgLabel.Text = "✦ 列に追加配置！"

    -- 4人バトロワ
    elseif t == "br4p_start" then
        LobbyScreen.Visible = false
        PhaseLabel.Text = string.format("🀄 バトルロワイヤル開始！%d ラウンド制", data.totalRounds or 4)
        PartnerMsgLabel.Text = "全員が最後まで参加。合計ポイント最多で優勝！"

    elseif t == "br4p_round_start" then
        PhaseLabel.Text = string.format("🀄 ラウンド %d / %d", data.round, data.totalRounds)

    elseif t == "br4p_round_result" then
        local ptText = data.ptGained >= 0 and ("+" .. data.ptGained) or tostring(data.ptGained)
        PhaseLabel.Text = string.format("ラウンド%d結果：%d位 %spt（合計%dpt）",
            data.round, data.rank, ptText, data.totalPoints)
        local msgs = {[1]="ラウンド制覇！",[2]="2位！",[3]="3位",[4]="最下位…次で巻き返そう"}
        PartnerMsgLabel.Text = msgs[data.rank] or ""

    elseif t == "br4p_end" then
        local isChamp = data.champion and data.champion.userId == LocalPlayer.UserId
        PhaseLabel.Text = isChamp and "🏆 優勝！" or "試合終了"
        if data.champion then
            PartnerMsgLabel.Text = "優勝：" .. data.champion.name .. " (" .. data.champion.points .. "pt)"
        end
        task.wait(6)
        LobbyScreen.Visible = true

    -- クエスト
    elseif t == "quest_update" then
        -- 受け取りボタン付きで表示（ロビー時のみ）
        if LobbyScreen and LobbyScreen.Visible then
            for _, c in ipairs(LobbyScreen:GetChildren()) do
                if c.Name == "QuestPanel" then c:Destroy() end
            end
            local panel = Instance.new("Frame")
            panel.Name = "QuestPanel"
            panel.Size = UDim2.new(0.28, 0, 0.5, 0)
            panel.Position = UDim2.new(0.01, 0, 0.47, 0)
            panel.BackgroundColor3 = Color3.fromRGB(15, 15, 35)
            panel.Parent = LobbyScreen
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.04, 0)
            corner.Parent = panel

            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, 0, 0.1, 0)
            title.BackgroundTransparency = 1
            title.Text = "📋 クエスト"
            title.TextColor3 = Color3.fromRGB(255, 220, 100)
            title.Font = Enum.Font.GothamBold
            title.TextSize = 14
            title.Parent = panel

            local yOff = 0.1
            for _, q in ipairs(data.quests or {}) do
                if yOff > 0.86 then break end
                local done = q.progress >= q.required
                local pct  = math.min(1, q.progress / math.max(1, q.required))
                local row  = Instance.new("Frame")
                row.Size = UDim2.new(0.94, 0, 0.15, 0)
                row.Position = UDim2.new(0.03, 0, yOff, 0)
                row.BackgroundColor3 = done and Color3.fromRGB(20,50,20) or Color3.fromRGB(25,25,50)
                row.Parent = panel
                local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0.1,0); rc.Parent = row
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1,0,0.6,0)
                lbl.BackgroundTransparency = 1
                lbl.Text = q.name .. string.format("  %d/%d", q.progress, q.required)
                lbl.TextColor3 = done and Color3.fromRGB(100,255,150) or Color3.fromRGB(200,200,200)
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 12
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = row
                -- バーBG
                local bg = Instance.new("Frame")
                bg.Size = UDim2.new(0.92,0,0.2,0)
                bg.Position = UDim2.new(0.04,0,0.72,0)
                bg.BackgroundColor3 = Color3.fromRGB(40,40,60)
                bg.Parent = row
                local brc = Instance.new("UICorner"); brc.CornerRadius = UDim.new(0.5,0); brc.Parent = bg
                local bar = Instance.new("Frame")
                bar.Size = UDim2.new(pct,0,1,0)
                bar.BackgroundColor3 = done and Color3.fromRGB(80,200,100) or Color3.fromRGB(80,120,200)
                bar.Parent = bg
                local brc2 = Instance.new("UICorner"); brc2.CornerRadius = UDim.new(0.5,0); brc2.Parent = bar
                -- 受け取りボタン
                if done then
                    local btn = Instance.new("TextButton")
                    btn.Size = UDim2.new(0.22,0,0.5,0)
                    btn.Position = UDim2.new(0.76,0,0.25,0)
                    btn.Text = "受け取る"
                    btn.TextSize = 12
                    btn.BackgroundColor3 = Color3.fromRGB(200,150,30)
                    btn.TextColor3 = Color3.fromRGB(0,0,0)
                    btn.Font = Enum.Font.GothamBold
                    btn.Parent = row
                    local brc3 = Instance.new("UICorner"); brc3.CornerRadius = UDim.new(0.2,0); brc3.Parent = btn
                    local qid = q.id
                    btn.MouseButton1Click:Connect(function()
                        local rc2 = Remotes:FindFirstChild("QuestClaim")
                        if rc2 then rc2:FireServer({questId = qid}) end
                    end)
                end
                yOff = yOff + 0.17
            end
        end

    elseif t == "quest_claim_result" then
        -- クエスト報酬受け取り結果をトースト表示
        local msg = data.success
            and ("🎁 " .. (data.questName or "クエスト") .. " 達成！ +" .. (data.gems or 0) .. " 💎")
            or  ("⚠️ " .. (data.message or "受け取り失敗"))
        local toast = Instance.new("TextLabel")
        toast.Size = UDim2.new(0.7, 0, 0.06, 0)
        toast.Position = UDim2.new(0.15, 0, 0.08, 0)
        toast.BackgroundColor3 = data.success and Color3.fromRGB(30,80,30) or Color3.fromRGB(80,30,30)
        toast.TextColor3 = Color3.fromRGB(220,255,220)
        toast.Text = msg
        toast.Font = Enum.Font.GothamBold
        toast.TextSize = 13
        toast.TextWrapped = true
        toast.BackgroundTransparency = 0.1
        toast.ZIndex = 100
        toast.Parent = ScreenGui
        local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0.2,0); tc.Parent = toast
        game:GetService("TweenService"):Create(toast,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 2.5),
            {}):Play()
        task.delay(3.2, function()
            game:GetService("TweenService"):Create(toast,
                TweenInfo.new(0.4), {BackgroundTransparency=1, TextTransparency=1}):Play()
            task.delay(0.5, function() toast:Destroy() end)
        end)

    elseif t == "mm_status" then
        -- マッチングステータス更新（キャンセル含む）
        local msg = data.message or ""
        if msg:find("キャンセル") or msg:find("cancel") then
            -- キャンセル確認 → ロビーに戻す
            if _G.ShowLobby then _G.ShowLobby() end
        elseif msg:find("バトルセット") or msg:find("デッキ") or msg:find("⚠️") then
            -- エラー → MatchScreen非表示 + ロビーに戻してエラートースト表示
            if _G.ShowLobby then _G.ShowLobby() end
            -- エラートースト
            local errToast = Instance.new("TextLabel")
            errToast.Size = UDim2.new(0.9, 0, 0.07, 0)
            errToast.Position = UDim2.new(0.05, 0, 0.06, 0)
            errToast.BackgroundColor3 = Color3.fromRGB(80, 30, 10)
            errToast.BackgroundTransparency = 0.1
            errToast.TextColor3 = Color3.fromRGB(255, 220, 180)
            errToast.Text = msg
            errToast.Font = Enum.Font.GothamBold
            errToast.TextSize = 13
            errToast.TextWrapped = true
            errToast.ZIndex = 100
            errToast.Parent = ScreenGui
            local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(0.15,0); ec.Parent = errToast
            task.delay(4, function()
                game:GetService("TweenService"):Create(errToast,
                    TweenInfo.new(0.4), {BackgroundTransparency=1, TextTransparency=1}):Play()
                task.delay(0.5, function() errToast:Destroy() end)
            end)
        elseif MatchScreen and MatchScreen.Visible then
            -- マッチング中のステータス更新
            matchTitle.Text = msg
        end

    elseif t == "achievement_unlocked" then
        -- 実績バッジ演出（画面右下からスライドイン）
        local pg = game.Players.LocalPlayer.PlayerGui
        local ach = Instance.new("Frame")
        ach.Name = "AchievementPopup_"..data.id
        ach.Size = UDim2.new(0.55,0,0.10,0)
        ach.Position = UDim2.new(0.44,0,1.02,0)  -- 画面下に隠れた位置
        ach.BackgroundColor3 = Color3.fromRGB(30,20,55)
        ach.BackgroundTransparency = 0.1; ach.ZIndex = 95
        ach.Parent = ScreenGui
        local ac = Instance.new("UICorner"); ac.CornerRadius = UDim.new(0.15,0); ac.Parent = ach

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0.18,0,1,0); icon.BackgroundTransparency = 1
        icon.Text = data.icon or "🏅"; icon.TextScaled = true
        icon.Font = Enum.Font.GothamBold; icon.ZIndex = 96; icon.Parent = ach

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(0.78,0,0.5,0); nameL.Position = UDim2.new(0.18,0,0,0)
        nameL.BackgroundTransparency = 1
        nameL.Text = "✦ 実績解除: "..( data.name or "?")
        nameL.TextColor3 = Color3.fromRGB(255,220,80)
        nameL.Font = Enum.Font.GothamBold; nameL.TextSize = 12
        nameL.TextXAlignment = Enum.TextXAlignment.Left; nameL.ZIndex = 96; nameL.Parent = ach

        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(0.78,0,0.45,0); desc.Position = UDim2.new(0.18,0,0.52,0)
        desc.BackgroundTransparency = 1
        desc.Text = (data.desc or "")..(data.reward and data.reward.gems and
            string.format("  💚+%d", data.reward.gems) or "")
        desc.TextColor3 = Color3.fromRGB(180,170,220)
        desc.Font = Enum.Font.Gotham; desc.TextSize = 11
        desc.TextXAlignment = Enum.TextXAlignment.Left; desc.ZIndex = 96; desc.Parent = ach

        -- スライドイン
        TweenService:Create(ach, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0.44,0,0.88,0)}):Play()
        -- 4秒後にスライドアウト
        task.delay(4, function()
            TweenService:Create(ach, TweenInfo.new(0.3),
                {Position = UDim2.new(0.44,0,1.02,0)}):Play()
            task.delay(0.35, function() if ach.Parent then ach:Destroy() end end)
        end)

    elseif t == "login_bonus" then
        -- ログインボーナスポップアップ
        local streak  = data.streak  or 1
        local gems    = data.gems    or 50
        local special = data.special or false

        local popup = Instance.new("Frame")
        popup.Name  = "LoginBonusPopup"
        popup.Size  = UDim2.new(0.78,0,0.62,0)
        popup.Position = UDim2.new(0.11,0,0.19,0)
        popup.BackgroundColor3 = Color3.fromRGB(8,12,30)
        popup.BackgroundTransparency = 0.04
        popup.ZIndex = 100
        popup.Parent = ScreenGui
        local popc = Instance.new("UICorner"); popc.CornerRadius = UDim.new(0.05,0); popc.Parent = popup

        -- キラキラ背景
        if special then
            popup.BackgroundColor3 = Color3.fromRGB(25,15,50)
            local flash = Instance.new("Frame")
            flash.Size = UDim2.new(1,0,1,0); flash.BackgroundColor3 = Color3.fromRGB(200,150,255)
            flash.BackgroundTransparency = 0.7; flash.ZIndex = 99; flash.Parent = popup
            local flashc = Instance.new("UICorner"); flashc.CornerRadius = UDim.new(0.05,0); flashc.Parent = flash
            TweenService:Create(flash,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),
                {BackgroundTransparency=0.95}):Play()
        end

        -- タイトル
        local streakLabel = Instance.new("TextLabel")
        streakLabel.Size = UDim2.new(0.9,0,0.18,0); streakLabel.Position = UDim2.new(0.05,0,0.04,0)
        streakLabel.BackgroundTransparency = 1
        streakLabel.Text = special
            and string.format("🎉 %d日連続ログイン！", streak)
            or  string.format("📅 %d日連続ログイン", streak)
        streakLabel.TextColor3 = special
            and Color3.fromRGB(255,220,80)
            or  Color3.fromRGB(200,210,255)
        streakLabel.Font = Enum.Font.GothamBold; streakLabel.TextScaled = true
        streakLabel.ZIndex = 101; streakLabel.Parent = popup

        -- ジェム表示
        local gemLabel = Instance.new("TextLabel")
        gemLabel.Size = UDim2.new(0.8,0,0.22,0); gemLabel.Position = UDim2.new(0.10,0,0.25,0)
        gemLabel.BackgroundTransparency = 1
        gemLabel.Text = string.format("💚 +%d ジェム", gems)
        gemLabel.TextColor3 = Color3.fromRGB(100,255,150)
        gemLabel.Font = Enum.Font.GothamBold; gemLabel.TextScaled = true
        gemLabel.ZIndex = 101; gemLabel.Parent = popup

        -- 特別報酬テキスト
        if data.bonusText then
            local bonusL = Instance.new("TextLabel")
            bonusL.Size = UDim2.new(0.8,0,0.14,0); bonusL.Position = UDim2.new(0.10,0,0.49,0)
            bonusL.BackgroundTransparency = 1
            bonusL.Text = data.bonusText
            bonusL.TextColor3 = Color3.fromRGB(255,200,100)
            bonusL.Font = Enum.Font.Gotham; bonusL.TextScaled = true
            bonusL.ZIndex = 101; bonusL.Parent = popup
        end

        -- 連続日数バー（7日制）
        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(0.85,0,0.10,0); barBg.Position = UDim2.new(0.075,0,0.64,0)
        barBg.BackgroundColor3 = Color3.fromRGB(20,20,40); barBg.ZIndex = 101; barBg.Parent = popup
        local brc = Instance.new("UICorner"); brc.CornerRadius = UDim.new(0.5,0); brc.Parent = barBg
        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new(math.min(1,(streak%7)/7),0,1,0)
        barFill.BackgroundColor3 = special
            and Color3.fromRGB(255,200,50)
            or  Color3.fromRGB(80,200,120)
        barFill.ZIndex = 102; barFill.Parent = barBg
        local bfc = Instance.new("UICorner"); bfc.CornerRadius = UDim.new(0.5,0); bfc.Parent = barFill
        TweenService:Create(barFill,TweenInfo.new(0.8,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
            {Size=UDim2.new(math.min(1,(streak%7)/7),0,1,0)}):Play()

        local barLabel = Instance.new("TextLabel")
        barLabel.Size = UDim2.new(0.85,0,0.08,0); barLabel.Position = UDim2.new(0.075,0,0.75,0)
        barLabel.BackgroundTransparency = 1
        barLabel.Text = string.format("次の7日ボーナスまで: %d日", 7-(streak%7))
        barLabel.TextColor3 = Color3.fromRGB(160,160,200); barLabel.Font = Enum.Font.Gotham
        barLabel.TextSize = 11; barLabel.ZIndex = 101; barLabel.Parent = popup

        -- OKボタン
        local okBtn = Instance.new("TextButton")
        okBtn.Size = UDim2.new(0.4,0,0.11,0); okBtn.Position = UDim2.new(0.30,0,0.86,0)
        okBtn.BackgroundColor3 = Color3.fromRGB(40,100,200); okBtn.Text = "OK！"
        okBtn.TextColor3 = Color3.fromRGB(220,235,255); okBtn.Font = Enum.Font.GothamBold
        okBtn.TextScaled = true; okBtn.ZIndex = 101; okBtn.Parent = popup
        local okc = Instance.new("UICorner"); okc.CornerRadius = UDim.new(0.3,0); okc.Parent = okBtn
        okBtn.MouseButton1Click:Connect(function()
            TweenService:Create(popup,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play()
            task.delay(0.35, function() popup:Destroy() end)
        end)

        -- 5秒後に自動で消える
        task.delay(6, function()
            if popup.Parent then
                TweenService:Create(popup,TweenInfo.new(0.4),{BackgroundTransparency=1}):Play()
                task.delay(0.45, function() if popup.Parent then popup:Destroy() end end)
            end
        end)

    elseif t == "game_list" then
        -- 観戦可能な試合一覧を表示
        for _, child in ipairs(ScreenGui:GetChildren()) do
            if child.Name == "ObserveUI" then child:Destroy() end
        end
        local og = Instance.new("Frame")
        og.Name = "ObserveUI"; og.Size = UDim2.new(0.8,0,0.6,0)
        og.Position = UDim2.new(0.1,0,0.2,0)
        og.BackgroundColor3 = Color3.fromRGB(5,10,25)
        og.BackgroundTransparency = 0.05; og.ZIndex = 75
        og.Parent = ScreenGui
        local oc = Instance.new("UICorner"); oc.CornerRadius = UDim.new(0.04,0); oc.Parent = og

        local otitle = Instance.new("TextLabel")
        otitle.Size = UDim2.new(0.85,0,0.12,0); otitle.BackgroundTransparency = 1
        otitle.Text = "👁 観戦モード"; otitle.TextColor3 = Color3.fromRGB(180,210,255)
        otitle.Font = Enum.Font.GothamBold; otitle.TextScaled = true
        otitle.ZIndex = 76; otitle.Parent = og

        local ocClose = Instance.new("TextButton")
        ocClose.Size = UDim2.new(0.12,0,0.1,0); ocClose.Position = UDim2.new(0.87,0,0.01,0)
        ocClose.BackgroundColor3 = Color3.fromRGB(140,40,40); ocClose.Text = "✕"
        ocClose.TextColor3 = Color3.fromRGB(255,255,255); ocClose.TextScaled = true
        ocClose.Font = Enum.Font.GothamBold; ocClose.ZIndex = 76; ocClose.Parent = og
        local occ = Instance.new("UICorner"); occ.CornerRadius = UDim.new(0.3,0); occ.Parent = ocClose
        ocClose.MouseButton1Click:Connect(function() og:Destroy() end)

        local games = data.games or {}
        if #games == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(0.9,0,0.2,0); empty.Position = UDim2.new(0.05,0,0.4,0)
            empty.BackgroundTransparency = 1; empty.Text = "現在進行中の試合はありません"
            empty.TextColor3 = Color3.fromRGB(140,140,160); empty.TextScaled = true
            empty.Font = Enum.Font.Gotham; empty.ZIndex = 76; empty.Parent = og
        else
            for i, game in ipairs(games) do
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(0.9,0,0.12,0)
                row.Position = UDim2.new(0.05,0,0.14+i*0.13,0)
                row.BackgroundColor3 = Color3.fromRGB(20,30,60)
                row.Text = string.format("⚔ Turn%d: %s", game.turn, table.concat(game.players or {}, " vs "))
                row.TextColor3 = Color3.fromRGB(200,220,255)
                row.Font = Enum.Font.Gotham; row.TextSize = 12; row.TextWrapped = true
                row.ZIndex = 76; row.Parent = og
                local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0.15,0); rc.Parent = row
                local roomId = game.roomId
                row.MouseButton1Click:Connect(function()
                    og:Destroy()
                    RE_Observe:FireServer({type="join", roomId=roomId})
                    PhaseLabel.Text = "👁 観戦中..."
                    LobbyScreen.Visible = false
                end)
            end
        end

    elseif t == "observe_start" then
        PhaseLabel.Text = string.format("👁 観戦: Turn%d", data.turn or 0)

    elseif t == "observe_error" then
        if _G.ShowToast then _G.ShowToast("❌ " .. (data.message or ""), 3) end

    elseif t == "recipe_list" then
        -- デッキレシピ一覧UI
        for _, c in ipairs(ScreenGui:GetChildren()) do
            if c.Name == "RecipeUI" then c:Destroy() end
        end
        local rg = Instance.new("Frame")
        rg.Name = "RecipeUI"; rg.Size = UDim2.new(0.92,0,0.82,0)
        rg.Position = UDim2.new(0.04,0,0.09,0)
        rg.BackgroundColor3 = Color3.fromRGB(6,10,24)
        rg.BackgroundTransparency = 0.05; rg.ZIndex = 73
        rg.Parent = ScreenGui
        local rgc = Instance.new("UICorner"); rgc.CornerRadius = UDim.new(0.03,0); rgc.Parent = rg

        local rt = Instance.new("TextLabel"); rt.Size=UDim2.new(0.75,0,0.08,0)
        rt.BackgroundTransparency=1; rt.Text="📤 公開デッキランキング"
        rt.TextColor3=Color3.fromRGB(220,200,255); rt.Font=Enum.Font.GothamBold
        rt.TextScaled=true; rt.ZIndex=74; rt.Parent=rg

        local rcBtn = Instance.new("TextButton"); rcBtn.Size=UDim2.new(0.10,0,0.07,0)
        rcBtn.Position=UDim2.new(0.89,0,0.01,0); rcBtn.BackgroundColor3=Color3.fromRGB(140,40,40)
        rcBtn.Text="✕"; rcBtn.TextColor3=Color3.fromRGB(255,255,255)
        rcBtn.Font=Enum.Font.GothamBold; rcBtn.TextScaled=true; rcBtn.ZIndex=74; rcBtn.Parent=rg
        local rcc=Instance.new("UICorner"); rcc.CornerRadius=UDim.new(0.3,0); rcc.Parent=rcBtn
        rcBtn.MouseButton1Click:Connect(function() rg:Destroy() end)

        local rs2 = Instance.new("ScrollingFrame")
        rs2.Size=UDim2.new(0.96,0,0.88,0); rs2.Position=UDim2.new(0.02,0,0.10,0)
        rs2.BackgroundTransparency=1; rs2.ScrollBarThickness=5
        rs2.AutomaticCanvasSize=Enum.AutomaticSize.Y; rs2.ZIndex=74; rs2.Parent=rg
        local rsl=Instance.new("UIListLayout"); rsl.Padding=UDim.new(0,5); rsl.Parent=rs2
        local rsp=Instance.new("UIPadding"); rsp.PaddingAll=UDim.new(0,4); rsp.Parent=rs2

        local recipes = data.recipes or {}
        if #recipes == 0 then
            local empty = Instance.new("TextLabel"); empty.Size=UDim2.new(1,0,0,50)
            empty.BackgroundTransparency=1; empty.Text="まだ公開デッキがありません"
            empty.TextColor3=Color3.fromRGB(130,130,160); empty.TextScaled=true
            empty.Font=Enum.Font.Gotham; empty.ZIndex=75; empty.Parent=rs2
        end
        for i, recipe in ipairs(recipes) do
            local row = Instance.new("Frame"); row.Size=UDim2.new(1,0,0,60)
            row.BackgroundColor3=Color3.fromRGB(15,20,45)
            row.BackgroundTransparency=0.2; row.ZIndex=75; row.Parent=rs2
            local rowc=Instance.new("UICorner"); rowc.CornerRadius=UDim.new(0.05,0); rowc.Parent=row

            local rankL=Instance.new("TextLabel"); rankL.Size=UDim2.new(0.06,0,1,0)
            rankL.BackgroundTransparency=1; rankL.Text="#"..i
            rankL.TextColor3=Color3.fromRGB(200,180,100); rankL.Font=Enum.Font.GothamBold
            rankL.TextSize=14; rankL.ZIndex=76; rankL.Parent=row

            local nameL=Instance.new("TextLabel"); nameL.Size=UDim2.new(0.45,0,0.55,0)
            nameL.Position=UDim2.new(0.07,0,0.03,0); nameL.BackgroundTransparency=1
            nameL.Text=recipe.title or "名無し"; nameL.TextColor3=Color3.fromRGB(225,220,255)
            nameL.Font=Enum.Font.GothamBold; nameL.TextSize=13; nameL.ZIndex=76; nameL.Parent=row

            local authL=Instance.new("TextLabel"); authL.Size=UDim2.new(0.35,0,0.38,0)
            authL.Position=UDim2.new(0.07,0,0.58,0); authL.BackgroundTransparency=1
            authL.Text="by "..( recipe.authorName or "?")
            authL.TextColor3=Color3.fromRGB(140,140,180); authL.Font=Enum.Font.Gotham
            authL.TextSize=11; authL.ZIndex=76; authL.Parent=row

            local likeL=Instance.new("TextLabel"); likeL.Size=UDim2.new(0.15,0,1,0)
            likeL.Position=UDim2.new(0.52,0,0,0); likeL.BackgroundTransparency=1
            likeL.Text="♥ "..(recipe.likes or 0)
            likeL.TextColor3=Color3.fromRGB(220,100,140); likeL.Font=Enum.Font.GothamBold
            likeL.TextSize=13; likeL.ZIndex=76; likeL.Parent=row

            -- いいね・コピーボタン
            local likeBtn=Instance.new("TextButton"); likeBtn.Size=UDim2.new(0.14,0,0.7,0)
            likeBtn.Position=UDim2.new(0.68,0,0.15,0); likeBtn.BackgroundColor3=Color3.fromRGB(120,30,60)
            likeBtn.Text="♥ いいね"; likeBtn.TextColor3=Color3.fromRGB(255,180,200)
            likeBtn.Font=Enum.Font.GothamBold; likeBtn.TextSize=11; likeBtn.ZIndex=76; likeBtn.Parent=row
            local lbc2=Instance.new("UICorner"); lbc2.CornerRadius=UDim.new(0.2,0); lbc2.Parent=likeBtn
            local rid = recipe.id
            likeBtn.MouseButton1Click:Connect(function()
                if RE_DeckRecipe then RE_DeckRecipe:FireServer({type="like", id=rid}) end
            end)

            local copyBtn=Instance.new("TextButton"); copyBtn.Size=UDim2.new(0.14,0,0.7,0)
            copyBtn.Position=UDim2.new(0.84,0,0.15,0); copyBtn.BackgroundColor3=Color3.fromRGB(30,80,40)
            copyBtn.Text="📋 コピー"; copyBtn.TextColor3=Color3.fromRGB(180,255,180)
            copyBtn.Font=Enum.Font.GothamBold; copyBtn.TextSize=11; copyBtn.ZIndex=76; copyBtn.Parent=row
            local cbc3=Instance.new("UICorner"); cbc3.CornerRadius=UDim.new(0.2,0); cbc3.Parent=copyBtn
            copyBtn.MouseButton1Click:Connect(function()
                if RE_DeckRecipe then RE_DeckRecipe:FireServer({type="copy", id=rid, libId=1}) end
                if _G.ShowToast then _G.ShowToast("コピー中...", 2) end
            end)
        end

    elseif t == "published" then
        if _G.ShowToast then _G.ShowToast("📤 " .. (data.message or "公開しました"), 3) end

    elseif t == "copied" then
        rg = ScreenGui:FindFirstChild("RecipeUI")
        if rg then rg:Destroy() end
        if _G.ShowToast then _G.ShowToast("✅ " .. (data.message or "コピーしました"), 3) end

    elseif t == "liked" then
        if _G.ShowToast then _G.ShowToast("♥ いいね！（計 " .. (data.likes or 0) .. " いいね）", 2) end

    elseif t == "friendroom_created" then
        -- 部屋作成成功 → コード表示
        local code = data.code or "?"
        showMatchScreen("フレンド対戦 部屋: " .. code)
        matchTitle.Text = string.format("あいことば: %s\n相手に教えて入ってもらおう", code)
        -- キャンセルでFriendRoomにも通知
        cancelBtn.MouseButton1Click:Connect(function()
            RE_FriendRoom:FireServer({type="cancel"})
        end)

    elseif t == "friendroom_joined" then
        if MatchScreen and MatchScreen.Visible then
            matchTitle.Text = string.format("✅ %s が入室！ゲーム開始します", data.joinerName or "相手")
        end

    elseif t == "friendroom_start" then
        if MatchScreen then MatchScreen.Visible = false end
        LobbyScreen.Visible = false
        PhaseLabel.Text = "🤝 フレンド対戦開始！（ELO変動なし）"

    elseif t == "friendroom_error" then
        if _G.ShowToast then _G.ShowToast("❌ " .. (data.message or "エラー"), 3) end

    elseif t == "friendroom_cancelled" then
        if _G.ShowLobby then _G.ShowLobby() end
        if _G.ShowToast then _G.ShowToast("部屋を解散しました", 2) end

    elseif t == "season_rank_up" then
        PhaseLabel.Text = string.format("⭐ シーズンランク %d 到達！", data.newRank or 0)

    elseif t == "elo_update" then
        local diff = (data.newElo or 0) - (data.oldElo or 0)
        local sign = diff >= 0 and "+" or ""
        local col  = diff >= 0 and Color3.fromRGB(80,200,120) or Color3.fromRGB(200,80,80)
        local t3 = Instance.new("TextLabel")
        t3.Size = UDim2.new(0.5,0,0.05,0)
        t3.Position = UDim2.new(0.25,0,0.35,0)
        t3.BackgroundTransparency = 1
        t3.Text = string.format("ELO %d → %d (%s%d)", data.oldElo or 0, data.newElo or 0, sign, diff)
        t3.TextColor3 = col
        t3.Font = Enum.Font.GothamBold
        t3.TextSize = 16
        t3.ZIndex = 92
        t3.Parent = ScreenGui
        task.delay(4, function() t3:Destroy() end)

    elseif t == "elo_info" then
        PhaseLabel.Text = string.format("ELO: %d  (%s)", data.elo or 1000, data.rank or "-")

    elseif t == "leaderboard_update" then
        if LobbyScreen and LobbyScreen.Visible then
            local rankLabel = LobbyScreen:FindFirstChild("RankLabel")
            if not rankLabel then
                rankLabel = Instance.new("TextLabel")
                rankLabel.Name = "RankLabel"
                rankLabel.Size = UDim2.new(0.45,0,0.04,0)
                rankLabel.Position = UDim2.new(0.52,0,0.14,0)
                rankLabel.BackgroundTransparency = 1
                rankLabel.TextColor3 = Color3.fromRGB(200,180,255)
                rankLabel.Font = Enum.Font.Gotham
                rankLabel.TextSize = 12
                rankLabel.TextXAlignment = Enum.TextXAlignment.Right
                rankLabel.Parent = LobbyScreen
            end
            local board = data.board or data.entries or {}
            if #board > 0 then
                local top = board[1]
                rankLabel.Text = string.format("👑 1位: %s (%d)", top.name or "?", top.elo or 0)
            end
        end

    elseif t == "quest_auto_complete" then
        handleAutoComplete(data)

    elseif t == "deck_slots" then
        -- 自分のスートとデッキスロット情報を受信
        CurrentSuit = data.suit or "club"
        CurrentDeckSlots = data.slots and data.slots[CurrentSuit] or {}
        -- スート確認バッジを表示
        local suitSymbols = {heart="♥", diamond="♦", club="♣", spade="♠"}
        local suitColors  = {
            heart   = Color3.fromRGB(220, 60, 80),
            diamond = Color3.fromRGB(220, 140, 40),
            club    = Color3.fromRGB(40, 160, 80),
            spade   = Color3.fromRGB(60, 100, 200),
        }
        if SuitBadgeLabel then
            SuitBadgeLabel.Text = (suitSymbols[CurrentSuit] or "?") .. " " .. CurrentSuit
            SuitBadgeLabel.TextColor3 = suitColors[CurrentSuit] or Color3.fromRGB(200,200,200)
        end

    elseif t == "vote_result" then
        local msg = data.success and data.message or ("❌ " .. (data.message or "エラー"))
        if data.cardId then
            -- カードIDに対応するステータスラベルを更新
            local pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                local label = pg:FindFirstChild("VoteStatus_" .. data.cardId, true)
                if label then label.Text = msg end
            end
        end

    elseif t == "rebirth_ticket" then
        -- 転生確定チケット受け取り通知
        local notice = data.message or "転生確定！ガチャチケットを受け取りました"
        if PhaseLabel then PhaseLabel.Text = notice end

    elseif t == "deck_skin_changed" then
        -- スタイル変更完了→トランプ版デッキ編集グリッドを更新
        if data.suit and data.cardId then
            deckSlotData[data.suit] = deckSlotData[data.suit] or {}
            deckSlotData[data.suit][data.cardId] = data.skinId  -- nil でリセット
            if DeckEditScreen and DeckEditScreen.Visible then
                refreshDeckEditGrid(data.suit)
            end
        end

    end
end)

-- コンビ戦：P2アドバイスをPartnerAdviceで受信
local RE_PA2 = Remotes:FindFirstChild("PartnerAdvice")
if RE_PA2 then
    RE_PA2.OnClientEvent:Connect(function(data)
        if type(data) == "table" then
            if data.text then
                PartnerMsgLabel.Text =
                    (data.role == "carry" and "【キャリー】" or
                     data.role == "support" and "【サポート】" or "") .. data.text
            end
            if data.partnerMsg and data.partnerMsg ~= "" then
                -- P2の提案を3秒間小さく表示
                local w = Instance.new("Frame")
                w.Size = UDim2.new(0.3,0,0.08,0)
                w.Position = UDim2.new(0.01,0,0.86,0)
                w.BackgroundColor3 = Color3.fromRGB(20,40,60)
                w.ZIndex = 15
                w.Parent = ScreenGui
                local wc = Instance.new("UICorner"); wc.CornerRadius = UDim.new(0.12,0); wc.Parent = w
                local wl = Instance.new("TextLabel")
                wl.Size = UDim2.new(1,0,1,0)
                wl.BackgroundTransparency = 1
                wl.Text = "🤝 " .. data.partnerMsg
                wl.TextColor3 = Color3.fromRGB(180,220,255)
                wl.Font = Enum.Font.Gotham
                wl.TextSize = 12
                wl.TextWrapped = true
                wl.ZIndex = 16
                wl.Parent = w
                task.delay(5, function() w:Destroy() end)
            end
        elseif type(data) == "string" then
            PartnerMsgLabel.Text = data
        end
    end)
end






-- quest_auto_complete：パートナーがさりげなく報告する
-- (UpdateBoard重複接続を削除済み)

-- quest_auto_completeはPartnerComfortの受信と別に管理
local function handleAutoComplete(data)
    if data.type ~= "quest_auto_complete" then return end
    -- 小さなトースト通知（邪魔しない）
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0.35,0,0.06,0)
    toast.Position = UDim2.new(0.63,0,0.01,0)
    toast.BackgroundColor3 = Color3.fromRGB(20,50,20)
    toast.BorderSizePixel = 0
    toast.ZIndex = 40
    toast.Parent = ScreenGui
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0.15,0)
    tc.Parent = toast
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1,0,1,0)
    tl.BackgroundTransparency = 1
    tl.Text = "💚 " .. (data.text or "クエスト達成") ..
              (data.gemsGiven > 0 and ("  +" .. data.gemsGiven .. "💎") or "")
    tl.TextColor3 = Color3.fromRGB(180,255,180)
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 12
    tl.ZIndex = 41
    tl.Parent = toast
    -- PartnerMsgもさりげなく更新
    if PartnerMsgLabel then
        PartnerMsgLabel.Text = "クエスト達成してた！えらいね"
    end
    game:GetService("TweenService"):Create(toast,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,0,false,2.5),
        {}
    ):Play()
    task.delay(3.5, function()
        game:GetService("TweenService"):Create(toast,
            TweenInfo.new(0.4),
            {BackgroundTransparency=1}
        ):Play()
        task.delay(0.5, function() toast:Destroy() end)
    end)
end



-- ロビーに「ふれあい」ボタンを追加
-- ============================================
-- 初期表示状態の設定（ロビーのみ表示、バトルUIは非表示）
-- ============================================
BoardFrame.Visible  = false
HandFrame.Visible   = false
GemFrame.Visible    = false
PartnerWin.Visible  = false
DeckEditScreen.Visible = false
GachaScreen.Visible = false
LobbyScreen.Visible = true

-- グローバルトースト表示（他スクリプトから呼べる）
_G.ShowToast = function(msg, duration)
    local toast = Instance.new("TextLabel")
    toast.Size = UDim2.new(0.88,0,0.07,0)
    toast.Position = UDim2.new(0.06,0,0.06,0)
    toast.BackgroundColor3 = Color3.fromRGB(30,20,60)
    toast.BackgroundTransparency = 0.1
    toast.TextColor3 = Color3.fromRGB(220,205,255)
    toast.Text = msg
    toast.Font = Enum.Font.GothamBold
    toast.TextSize = 13
    toast.TextWrapped = true
    toast.ZIndex = 120
    toast.Parent = ScreenGui
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0.2,0); tc.Parent = toast
    task.delay(duration or 3, function()
        TweenService:Create(toast,TweenInfo.new(0.4),{BackgroundTransparency=1,TextTransparency=1}):Play()
        task.delay(0.5, function() if toast.Parent then toast:Destroy() end end)
    end)
end

-- ロビーナビ用ペットボタン接続
_G.OpenPetFromLobby = function()
    if _G.OpenPetUI then _G.OpenPetUI() end
end
_G.OpenDigFromLobby = function()
    if _G.OpenDigUI then _G.OpenDigUI() end
end

-- グローバル公開（LoadingScreen等から呼べる）
_G.ShowLobby = function()
    if MatchScreen then MatchScreen.Visible = false end
    BoardFrame.Visible  = false
    HandFrame.Visible   = false
    GemFrame.Visible    = false
    PartnerWin.Visible  = false
    DeckEditScreen.Visible = false
    GachaScreen.Visible = false
    LobbyScreen.Visible = true
end

if LobbyScreen then
    -- ── ナビゲーション行（Y=0.62〜0.71） ──
    local NAV_COLOR = Color3.fromRGB(30, 30, 50)

    local function makeNavBtn(text, xPos, w, yPos, color, onClick)
        local btn = Instance.new("TextButton")
        btn.Size          = UDim2.new(w, -4, 0.08, 0)
        btn.Position      = UDim2.new(xPos, 2, yPos, 0)
        btn.BackgroundColor3 = color or NAV_COLOR
        btn.TextColor3    = Color3.fromRGB(230, 230, 255)
        btn.Text          = text
        btn.Font          = Enum.Font.GothamBold
        btn.TextSize      = 12
        btn.TextWrapped   = true
        btn.BorderSizePixel = 0
        btn.Parent        = LobbyScreen
        local c = Instance.new("UICorner")
        c.CornerRadius    = UDim.new(0.15, 0)
        c.Parent          = btn
        btn.MouseButton1Click:Connect(onClick)
        return btn
    end

    -- 🎴 デッキ編集
    makeNavBtn("🎴 イラスト変更", 0.35, 0.30, 0.62,
        Color3.fromRGB(50, 80, 130),
        function()
            local rf = Remotes:FindFirstChild("GetDeckSlots")
            if rf then
                local ok, slots = pcall(function() return rf:InvokeServer() end)
                if ok and slots then deckSlotData = slots end
            end
            refreshDeckEditGrid(currentDeckSuit)
            LobbyScreen.Visible = false
            DeckEditScreen.Visible = true
        end)

    -- 🃏 TCGデッキ編集（カード構築）
    makeNavBtn("🃏 TCGデッキ\nカード構築", 0.01, 0.32, 0.62,
        Color3.fromRGB(40, 60, 110),
        function()
            if _G.OpenDeckEdit then
                LobbyScreen.Visible = false
                _G.OpenDeckEdit()
            else
                -- フォールバック: スキン変更画面
                local rf = Remotes:FindFirstChild("GetDeckSlots")
                if rf then
                    local ok, slots = pcall(function() return rf:InvokeServer() end)
                    if ok and slots then deckSlotData = slots end
                end
                refreshDeckEditGrid(currentDeckSuit)
                LobbyScreen.Visible = false
                DeckEditScreen.Visible = true
            end
        end)

    -- 📅 生活管理（行2右）
    makeNavBtn("📅 生活管理
カレンダー", 0.52, 0.47, 0.71,
        Color3.fromRGB(40,90,60),
        function()
            if _G.OpenLifeManager then _G.OpenLifeManager() end
        end)

    -- 3行目ナビ（Y=0.80）
    -- フレンド対戦UI（ローカル関数）
    local function openFriendUI()
        for _, c in ipairs(ScreenGui:GetChildren()) do
            if c.Name == "FriendUI" then c:Destroy() end
        end
        local fg = Instance.new("Frame")
        fg.Name = "FriendUI"; fg.Size = UDim2.new(0.84,0,0.58,0)
        fg.Position = UDim2.new(0.08,0,0.21,0)
        fg.BackgroundColor3 = Color3.fromRGB(8,14,32)
        fg.BackgroundTransparency = 0.05; fg.ZIndex = 72
        fg.Parent = ScreenGui
        local fgc = Instance.new("UICorner"); fgc.CornerRadius = UDim.new(0.04,0); fgc.Parent = fg

        local t = Instance.new("TextLabel"); t.Size=UDim2.new(0.8,0,0.14,0)
        t.BackgroundTransparency=1; t.Text="🤝 フレンド対戦（ELO変動なし）"
        t.TextColor3=Color3.fromRGB(180,220,255); t.Font=Enum.Font.GothamBold
        t.TextScaled=true; t.ZIndex=73; t.Parent=fg

        local cb2 = Instance.new("TextButton"); cb2.Size=UDim2.new(0.12,0,0.12,0)
        cb2.Position=UDim2.new(0.87,0,0.01,0); cb2.BackgroundColor3=Color3.fromRGB(140,40,40)
        cb2.Text="✕"; cb2.TextColor3=Color3.fromRGB(255,255,255)
        cb2.Font=Enum.Font.GothamBold; cb2.TextScaled=true; cb2.ZIndex=73; cb2.Parent=fg
        local cb2c=Instance.new("UICorner"); cb2c.CornerRadius=UDim.new(0.3,0); cb2c.Parent=cb2
        cb2.MouseButton1Click:Connect(function() fg:Destroy() end)

        -- 部屋を作る
        local cBtn = Instance.new("TextButton"); cBtn.Size=UDim2.new(0.82,0,0.18,0)
        cBtn.Position=UDim2.new(0.09,0,0.18,0); cBtn.BackgroundColor3=Color3.fromRGB(25,75,155)
        cBtn.Text="🏠 部屋を作る（あいことばを発行）"
        cBtn.TextColor3=Color3.fromRGB(200,220,255); cBtn.Font=Enum.Font.GothamBold
        cBtn.TextScaled=true; cBtn.ZIndex=73; cBtn.Parent=fg
        local cBtnC=Instance.new("UICorner"); cBtnC.CornerRadius=UDim.new(0.2,0); cBtnC.Parent=cBtn
        cBtn.MouseButton1Click:Connect(function()
            if RE_FriendRoom then RE_FriendRoom:FireServer({type="create", mode="battle_tcg"}) end
            fg:Destroy(); showMatchScreen("🏠 部屋作成中…相手にあいことばを教えよう")
        end)

        -- あいことばで入る
        local tb2 = Instance.new("TextBox"); tb2.Size=UDim2.new(0.56,0,0.15,0)
        tb2.Position=UDim2.new(0.09,0,0.43,0); tb2.BackgroundColor3=Color3.fromRGB(18,24,48)
        tb2.TextColor3=Color3.fromRGB(220,220,255); tb2.PlaceholderText="あいことば（6文字）"
        tb2.Font=Enum.Font.Gotham; tb2.TextSize=13; tb2.MaxVisibleGraphemes=6
        tb2.ZIndex=73; tb2.Parent=fg
        local tb2c=Instance.new("UICorner"); tb2c.CornerRadius=UDim.new(0.2,0); tb2c.Parent=tb2

        local jBtn2 = Instance.new("TextButton"); jBtn2.Size=UDim2.new(0.28,0,0.15,0)
        jBtn2.Position=UDim2.new(0.67,0,0.43,0); jBtn2.BackgroundColor3=Color3.fromRGB(25,115,55)
        jBtn2.Text="入室"; jBtn2.TextColor3=Color3.fromRGB(200,255,200)
        jBtn2.Font=Enum.Font.GothamBold; jBtn2.TextScaled=true; jBtn2.ZIndex=73; jBtn2.Parent=fg
        local jBtn2C=Instance.new("UICorner"); jBtn2C.CornerRadius=UDim.new(0.2,0); jBtn2C.Parent=jBtn2
        jBtn2.MouseButton1Click:Connect(function()
            local code = tb2.Text:upper():gsub("%s","")
            if #code < 4 then
                if _G.ShowToast then _G.ShowToast("あいことばを入力してください",2) end; return
            end
            if RE_FriendRoom then RE_FriendRoom:FireServer({type="join", code=code}) end
            fg:Destroy(); showMatchScreen("🔑 入室中… "..code)
        end)

        local info = Instance.new("TextLabel"); info.Size=UDim2.new(0.82,0,0.12,0)
        info.Position=UDim2.new(0.09,0,0.82,0); info.BackgroundTransparency=1
        info.Text="※ ELOレーティングは変動しません（練習対戦モード）"
        info.TextColor3=Color3.fromRGB(130,150,180); info.Font=Enum.Font.Gotham
        info.TextSize=11; info.TextWrapped=true; info.ZIndex=73; info.Parent=fg
    end

    makeNavBtn("🐾 ペット育成", 0.01, 0.24, 0.80,
        Color3.fromRGB(80,40,100),
        function()
            if _G.OpenPetUI then _G.OpenPetUI() end
        end)
    makeNavBtn("⛏ 化石発掘",   0.27, 0.24, 0.80,
        Color3.fromRGB(80,50,20),
        function()
            if _G.OpenDigUI then _G.OpenDigUI() end
        end)
    makeNavBtn("🤝 フレンド",   0.53, 0.23, 0.80,
        Color3.fromRGB(20,80,120), openFriendUI)
    makeNavBtn("👁 観戦",        0.78, 0.20, 0.80,
        Color3.fromRGB(40,60,80),
        function()
            if RE_Observe then RE_Observe:FireServer({type="list"}) end
        end)

    -- 🛍 ショップUI
    local function openShop()
        for _, c in ipairs(ScreenGui:GetChildren()) do
            if c.Name == "ShopUI" then c:Destroy() end
        end
        local sg2 = Instance.new("Frame")
        sg2.Name = "ShopUI"; sg2.Size = UDim2.new(0.92,0,0.85,0)
        sg2.Position = UDim2.new(0.04,0,0.08,0)
        sg2.BackgroundColor3 = Color3.fromRGB(6,10,28)
        sg2.BackgroundTransparency = 0.04; sg2.ZIndex = 80
        sg2.Parent = ScreenGui
        local sg2c = Instance.new("UICorner"); sg2c.CornerRadius = UDim.new(0.03,0); sg2c.Parent = sg2

        local st = Instance.new("TextLabel"); st.Size=UDim2.new(0.75,0,0.08,0)
        st.BackgroundTransparency=1; st.Text="🛍 ショップ"
        st.TextColor3=Color3.fromRGB(255,220,120); st.Font=Enum.Font.GothamBold
        st.TextScaled=true; st.ZIndex=81; st.Parent=sg2

        local sc = Instance.new("TextButton"); sc.Size=UDim2.new(0.10,0,0.07,0)
        sc.Position=UDim2.new(0.89,0,0.01,0); sc.BackgroundColor3=Color3.fromRGB(140,40,40)
        sc.Text="✕"; sc.TextColor3=Color3.fromRGB(255,255,255)
        sc.Font=Enum.Font.GothamBold; sc.TextScaled=true; sc.ZIndex=81; sc.Parent=sg2
        local scc=Instance.new("UICorner"); scc.CornerRadius=UDim.new(0.3,0); scc.Parent=sc
        sc.MouseButton1Click:Connect(function() sg2:Destroy() end)

        local scroll3 = Instance.new("ScrollingFrame")
        scroll3.Size=UDim2.new(0.96,0,0.88,0); scroll3.Position=UDim2.new(0.02,0,0.10,0)
        scroll3.BackgroundTransparency=1; scroll3.ScrollBarThickness=4
        scroll3.AutomaticCanvasSize=Enum.AutomaticSize.Y; scroll3.ZIndex=81; scroll3.Parent=sg2
        local sl3=Instance.new("UIListLayout"); sl3.Padding=UDim.new(0,8)
        sl3.FillDirection=Enum.FillDirection.Horizontal; sl3.Wraps=true; sl3.Parent=scroll3
        local sp3=Instance.new("UIPadding"); sp3.PaddingAll=UDim.new(0,6); sp3.Parent=scroll3

        local function makeShopItem(icon, name, desc, price, color, onClick)
            local tile = Instance.new("Frame")
            tile.Size=UDim2.new(0,150,0,180)
            tile.BackgroundColor3=Color3.fromRGB(15,20,45)
            tile.BackgroundTransparency=0.15; tile.ZIndex=82; tile.Parent=scroll3
            local tc=Instance.new("UICorner"); tc.CornerRadius=UDim.new(0.06,0); tc.Parent=tile

            local iconL=Instance.new("TextLabel"); iconL.Size=UDim2.new(1,0,0.35,0)
            iconL.BackgroundTransparency=1; iconL.Text=icon; iconL.TextScaled=true
            iconL.Font=Enum.Font.GothamBold; iconL.ZIndex=83; iconL.Parent=tile

            local nameL=Instance.new("TextLabel"); nameL.Size=UDim2.new(0.9,0,0.20,0)
            nameL.Position=UDim2.new(0.05,0,0.35,0); nameL.BackgroundTransparency=1
            nameL.Text=name; nameL.TextColor3=Color3.fromRGB(225,220,255)
            nameL.Font=Enum.Font.GothamBold; nameL.TextSize=12; nameL.TextWrapped=true
            nameL.ZIndex=83; nameL.Parent=tile

            local descL=Instance.new("TextLabel"); descL.Size=UDim2.new(0.9,0,0.22,0)
            descL.Position=UDim2.new(0.05,0,0.55,0); descL.BackgroundTransparency=1
            descL.Text=desc; descL.TextColor3=Color3.fromRGB(160,160,200)
            descL.Font=Enum.Font.Gotham; descL.TextSize=10; descL.TextWrapped=true
            descL.ZIndex=83; descL.Parent=tile

            local buyBtn=Instance.new("TextButton"); buyBtn.Size=UDim2.new(0.85,0,0.18,0)
            buyBtn.Position=UDim2.new(0.075,0,0.79,0); buyBtn.BackgroundColor3=color
            buyBtn.Text=price; buyBtn.TextColor3=Color3.fromRGB(255,255,255)
            buyBtn.Font=Enum.Font.GothamBold; buyBtn.TextScaled=true; buyBtn.ZIndex=83; buyBtn.Parent=tile
            local bbc=Instance.new("UICorner"); bbc.CornerRadius=UDim.new(0.2,0); bbc.Parent=buyBtn
            buyBtn.MouseButton1Click:Connect(onClick)
        end

        local MPS = game:GetService("MarketplaceService")
        local LP  = game.Players.LocalPlayer
        -- ジェムパック（DevProduct）
        makeShopItem("💚","ジェム150","ガチャ1回分","150円相当 💴",Color3.fromRGB(30,120,60),
            function() pcall(function() MPS:PromptProductPurchase(LP, 1111111) end) end)
        makeShopItem("💚💚","ジェム800","ガチャ5回+お得","800円相当 💴",Color3.fromRGB(30,120,60),
            function() pcall(function() MPS:PromptProductPurchase(LP, 1111112) end) end)
        makeShopItem("💚💚💚","ジェム1800","ガチャ12回+特別枠","1800円相当 💴",Color3.fromRGB(30,120,60),
            function() pcall(function() MPS:PromptProductPurchase(LP, 1111113) end) end)
        -- GamePass
        makeShopItem("👑","VIP パス","毎日ジェム+20
バトル経験値1.5倍","GamePass 🔑",Color3.fromRGB(120,80,20),
            function() pcall(function() MPS:PromptGamePassPurchase(LP, 2222221) end) end)
        makeShopItem("⚡","成長加速 24h","ペット成長速度2倍
24時間","課金アイテム ⚡",Color3.fromRGB(30,60,140),
            function() pcall(function() MPS:PromptProductPurchase(LP, 1111116) end) end)
        makeShopItem("🔋","発掘エネルギー+5","化石発掘エネルギー
即時+5","課金アイテム 🔋",Color3.fromRGB(80,50,20),
            function() pcall(function() MPS:PromptProductPurchase(LP, 1111117) end) end)
    end

    makeNavBtn("🛍 ショップ",   0.01, 0.32, 0.91,
        Color3.fromRGB(100,70,10), openShop)

    -- 📋 バトルセット
    local RE_OBS = Remotes:WaitForChild("OpenBattleSet", 15)
    makeNavBtn("📋 バトルセット\nデッキ選択", 0.01, 0.48, 0.71,
        Color3.fromRGB(60, 50, 120),
        function()
            if RE_OBS then RE_OBS:FireClient(game.Players.LocalPlayer) end
        end)

    -- 💚 パートナー
    makeNavBtn("💚 パートナー\nふれあい", 0.51, 0.48, 0.71,
        Color3.fromRGB(40, 100, 60),
        function()
            if _G.OpenPartnerAmie then _G.OpenPartnerAmie() end
        end)
end


-- ══════════════════════════════════════════
-- 投票UI（ロビー画面のデッキ詳細エリア）
-- カード名をクリック → 詳細パネル + 👍👎ボタン
-- ══════════════════════════════════════════
local RE_Vote = Remotes:WaitForChild("CardVote", 10)

local CARD_VOTE_LIST = {
    { id = "arcana_0",  name = "原初【エオ】" },
    { id = "arcana_6",  name = "恋人" },
    { id = "arcana_13", name = "レックス" },
    { id = "arcana_21", name = "アーケオ" },
    { id = "card_spade_A",   name = "♠A エース" },
    { id = "card_heart_K",   name = "♥K キング" },
    { id = "card_diamond_Q", name = "♦Q クイーン" },
    { id = "card_club_J",    name = "♣J ジャック" },
}

local function buildVotePanel(parent)
    local panel = Instance.new("Frame")
    panel.Name = "VotePanel"
    panel.Size = UDim2.new(0.96,0,0.14,0)
    panel.Position = UDim2.new(0.02,0,0.73,0)
    panel.BackgroundColor3 = Color3.fromRGB(10,22,10)
    panel.BackgroundTransparency = 0.2
    panel.BorderSizePixel = 0
    panel.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.03,0)
    corner.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,0.18,0)
    title.Position = UDim2.new(0,0,0,0)
    title.BackgroundTransparency = 1
    title.Text = "🗳 転生投票（投票権消費）"
    title.TextColor3 = Color3.fromRGB(180,255,150)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.Parent = panel

    -- スクロールリスト
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,0,0.80,0)
    scroll.Position = UDim2.new(0,0,0.20,0)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,4)
    layout.Parent = scroll

    for _, card in ipairs(CARD_VOTE_LIST) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,-8,0,38)
        row.BackgroundColor3 = Color3.fromRGB(20,40,20)
        row.BackgroundTransparency = 0.3
        row.BorderSizePixel = 0
        row.Parent = scroll

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(0.50,0,1,0)
        nameL.Position = UDim2.new(0,6,0,0)
        nameL.BackgroundTransparency = 1
        nameL.Text = card.name
        nameL.TextColor3 = Color3.fromRGB(220,255,200)
        nameL.Font = Enum.Font.Gotham
        nameL.TextSize = 12
        nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.Parent = row

        -- 👍ボタン
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.new(0.20,0,0.8,0)
        upBtn.Position = UDim2.new(0.52,0,0.10,0)
        upBtn.BackgroundColor3 = Color3.fromRGB(20,100,40)
        upBtn.Text = "👍"
        upBtn.TextSize = 16
        upBtn.Font = Enum.Font.GothamBold
        upBtn.TextColor3 = Color3.fromRGB(200,255,200)
        upBtn.BorderSizePixel = 0
        upBtn.Parent = row
        local uc = Instance.new("UICorner"); uc.CornerRadius=UDim.new(0.2,0); uc.Parent=upBtn
        upBtn.MouseButton1Click:Connect(function()
            if RE_Vote then RE_Vote:FireServer(card.id, "up") end
        end)

        -- 👎ボタン
        local dnBtn = Instance.new("TextButton")
        dnBtn.Size = UDim2.new(0.20,0,0.8,0)
        dnBtn.Position = UDim2.new(0.75,0,0.10,0)
        dnBtn.BackgroundColor3 = Color3.fromRGB(100,20,20)
        dnBtn.Text = "👎"
        dnBtn.TextSize = 16
        dnBtn.Font = Enum.Font.GothamBold
        dnBtn.TextColor3 = Color3.fromRGB(255,200,200)
        dnBtn.BorderSizePixel = 0
        dnBtn.Parent = row
        local dc = Instance.new("UICorner"); dc.CornerRadius=UDim.new(0.2,0); dc.Parent=dnBtn
        dnBtn.MouseButton1Click:Connect(function()
            if RE_Vote then RE_Vote:FireServer(card.id, "down") end
        end)

        -- 投票結果フィードバック
        local statusL = Instance.new("TextLabel")
        statusL.Name = "VoteStatus_" .. card.id
        statusL.Size = UDim2.new(1,0,0,18)
        statusL.AnchorPoint = Vector2.new(0,1)
        statusL.Position = UDim2.new(0,6,1,-2)
        statusL.BackgroundTransparency = 1
        statusL.Text = ""
        statusL.TextColor3 = Color3.fromRGB(160,200,160)
        statusL.Font = Enum.Font.Gotham
        statusL.TextSize = 12
        statusL.TextXAlignment = Enum.TextXAlignment.Left
        statusL.Parent = row
    end

    -- CanvasSizeを自動調整
    layout.Changed:Connect(function()
        scroll.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y + 8)
    end)
    return panel
end

-- 投票結果のUI更新
local function updateVoteStatus(cardId, message)
    local pg = game.Players.LocalPlayer:WaitForChild("PlayerGui", 15)
    local label = pg:FindFirstChild("VoteStatus_" .. cardId, true)
    if label then label.Text = message end
end

-- LobbyScreenに投票パネルを追加
if LobbyScreen then
    buildVotePanel(LobbyScreen)
end

-- vote_result受信時に表示更新
-- （UpdateBoardのOnClientEventで type == "vote_result" を処理済み）



-- ══════════════════════════════════════════
-- デッキ編集画面（4スート別イラスト選択）
-- ══════════════════════════════════════════
local DeckEditScreen = makeFrame(ScreenGui,
    UDim2.new(1,0,1,0), UDim2.new(0,0,0,0))
DeckEditScreen.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
DeckEditScreen.Visible = false
DeckEditScreen.ZIndex = 20

-- タイトル
local DeckTitle = Instance.new("TextLabel")
DeckTitle.Size = UDim2.new(1,0,0.07,0)
DeckTitle.Position = UDim2.new(0,0,0.02,0)
DeckTitle.BackgroundTransparency = 1
DeckTitle.Text = "🎴 デッキ編集 ── スートを選んでカードイラストを変更"
DeckTitle.TextColor3 = Color3.fromRGB(200, 220, 255)
DeckTitle.Font = Enum.Font.GothamBold
DeckTitle.TextSize = 14
DeckTitle.Parent = DeckEditScreen

-- 4スートタブ
local SUIT_NAMES = {
    {id="heart",   label="♥ ハルニア",   color=Color3.fromRGB(200,60,80)},
    {id="diamond", label="♦ ダイノス",    color=Color3.fromRGB(200,140,40)},
    {id="club",    label="♣ クラディオン",color=Color3.fromRGB(40,160,80)},
    {id="spade",   label="♠ スペルニア",  color=Color3.fromRGB(60,100,200)},
}

local currentDeckSuit = "heart"
local deckSlotData = {}  -- サーバーから取得したデッキスロット

-- タブボタン
local tabY = 0.11
for i, s in ipairs(SUIT_NAMES) do
    local tab = makeButton(DeckEditScreen, s.label,
        UDim2.new(0.22, -4, 0.06, 0),
        UDim2.new((i-1)*0.245, 0, tabY, 0),
        s.color)
    tab.TextSize = 12
    tab.Name = "SuitTab_" .. s.id

    tab.MouseButton1Click:Connect(function()
        currentDeckSuit = s.id
        refreshDeckEditGrid(s.id)
        -- タブのハイライト更新
        for _, sn in ipairs(SUIT_NAMES) do
            local t = DeckEditScreen:FindFirstChild("SuitTab_" .. sn.id)
            if t then
                t.BackgroundTransparency = (sn.id == s.id) and 0 or 0.5
            end
        end
    end)
end

-- カードグリッド（スクロール）
local DeckScroll = Instance.new("ScrollingFrame")
DeckScroll.Size = UDim2.new(0.96, 0, 0.72, 0)
DeckScroll.Position = UDim2.new(0.02, 0, 0.19, 0)
DeckScroll.BackgroundColor3 = Color3.fromRGB(12, 18, 30)
DeckScroll.BorderSizePixel = 0
DeckScroll.ScrollBarThickness = 8
DeckScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
DeckScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
DeckScroll.Parent = DeckEditScreen

local DeckGrid = Instance.new("UIGridLayout")
DeckGrid.CellSize = UDim2.new(0, 90, 0, 120)
DeckGrid.CellPadding = UDim2.new(0, 8, 0, 8)
DeckGrid.Parent = DeckScroll

-- カードスロットを描画する関数
local CARD_RANKS = {"A","2","3","4","5","6","7","8","9","10","J","Q","K"}

function refreshDeckEditGrid(suit)
    -- 既存カードを削除
    for _, c in ipairs(DeckScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    local suitData = deckSlotData[suit] or {}

    for _, rank in ipairs(CARD_RANKS) do
        local cardId = "card_" .. rank
        local skinId = suitData[cardId]  -- nil = デフォルト

        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 90, 0, 120)
        card.BackgroundColor3 = Color3.fromRGB(240, 235, 220)
        card.BorderSizePixel = 0
        card.Parent = DeckScroll

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = card

        -- カード番号
        local rankLbl = Instance.new("TextLabel")
        rankLbl.Size = UDim2.new(1,0,0.3,0)
        rankLbl.Position = UDim2.new(0,0,0.1,0)
        rankLbl.BackgroundTransparency = 1
        rankLbl.Text = rank
        rankLbl.Font = Enum.Font.GothamBold
        rankLbl.TextSize = 22
        rankLbl.TextColor3 = Color3.fromRGB(20,20,40)
        rankLbl.Parent = card

        -- スキン表示
        local skinLbl = Instance.new("TextLabel")
        skinLbl.Size = UDim2.new(1,0,0.25,0)
        skinLbl.Position = UDim2.new(0,0,0.60,0)
        skinLbl.BackgroundTransparency = 1
        skinLbl.Text = skinId and "✦ " .. skinId or "デフォルト"
        skinLbl.Font = Enum.Font.Gotham
        skinLbl.TextSize = 12
        skinLbl.TextColor3 = skinId and Color3.fromRGB(255,200,50) or Color3.fromRGB(120,120,120)
        skinLbl.TextWrapped = true
        skinLbl.Parent = card

        -- タップでデフォルトに戻す（簡易実装・将来はスキン選択ダイアログに）
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,1,0)
        btn.Position = UDim2.new(0,0,0,0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = card

        btn.MouseButton1Click:Connect(function()
            -- CardDetailUI経由でスタイル変更（所持スキン選択含む）
            -- CardDetailUIはLocalScriptなので_G経由で呼ぶ
            if _G.OpenCardDetail then
                -- トランプ版カードとして最小限のcard情報を渡す
                local cardInfo = {
                    id     = cardId,
                    suit   = suit,
                    rank   = rank,
                    name   = suit:upper() .. " " .. rank,
                    rarity = "C",
                }
                _G.OpenCardDetail(cardInfo, nil, nil, true)  -- fromDeckEdit=true でスタイル変更UI
            end
        end)
    end
end

-- 閉じるボタン
local DeckCloseBtn = makeButton(DeckEditScreen, "✕ 閉じる",
    UDim2.new(0.25, 0, 0.06, 0),
    UDim2.new(0.375, 0, 0.93, 0),
    Color3.fromRGB(80, 80, 80))
DeckCloseBtn.MouseButton1Click:Connect(function()
    DeckEditScreen.Visible = false
    LobbyScreen.Visible = true
end)

-- デッキ編集ボタンはナビゲーション行に統合済み


-- ============================================
-- EXゾーン UI
-- ============================================
local exZoneFrame = nil
local function buildEXZoneUI(screenGui)
    if exZoneFrame then exZoneFrame:Destroy() end
    local f = Instance.new("Frame")
    f.Name = "EXZone"
    f.Size = UDim2.new(0, 200, 0, 80)
    f.Position = UDim2.new(0.5, -100, 1, -180)
    f.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
    f.BackgroundTransparency = 0.3
    f.BorderSizePixel = 0
    f.Parent = screenGui

    local label = Instance.new("TextLabel")
    label.Name = "EXLabel"
    label.Size = UDim2.new(1, 0, 0.4, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(200, 160, 255)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Text = "⟨ EXゾーン ⟩"
    label.Parent = f

    local cards = Instance.new("TextLabel")
    cards.Name = "EXCards"
    cards.Size = UDim2.new(1, 0, 0.6, 0)
    cards.Position = UDim2.new(0, 0, 0.4, 0)
    cards.BackgroundTransparency = 1
    cards.TextColor3 = Color3.fromRGB(255, 255, 255)
    cards.Font = Enum.Font.Gotham
    cards.TextScaled = true
    cards.Text = "--"
    cards.Parent = f

    exZoneFrame = f
end

local function updateEXZoneUI(myEX, exCounts)
    if not exZoneFrame then return end
    local cards = exZoneFrame:FindFirstChild("EXCards")
    if not cards then return end
    -- 自分のEXカードを表示
    local parts = {}
    for _, c in ipairs(myEX) do
        local icon = (c.effect == "honey") and "🍯" or
                     (c.effect == "ex_life") and "💜" or "✦"
        table.insert(parts, icon .. c.name)
    end
    cards.Text = #parts > 0 and table.concat(parts, " ") or "（なし）"
end


print("✅ BattleClient_v2.lua loaded")
