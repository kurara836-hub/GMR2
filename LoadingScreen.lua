-- ============================================
-- GAMEROAD LoadingScreen.lua
-- StarterPlayerScripts/ に配置（LocalScript型）
--
-- ・長いロード時間をパートナーとの時間に変換
-- ・目に優しい緑の森林
-- ・タッチするとパートナーが反応
-- ・ロード完了で自動フェードアウト
-- ============================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui", 15)
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)

-- PartnerComfort Remote（バトル後の褒め演出・ロード中コメント）
local RE_Comfort   = Remotes:WaitForChild("PartnerComfort", 15)
local RE_MMCancel  = Remotes:WaitForChild("MatchmakingCancel", 15)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ロード中のパートナーセリフ
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local LOADING_LINES = {
    "ちょっと待っててね",
    "もうすぐだよ",
    "待たせてごめんね",
    "その間、一緒にいるよ",
    "……ここにいるよ",
    "急がなくていいよ",
    "準備できたら行こうね",
    "ゆっくりしてて",
}

local TOUCH_LINES = {
    "きゃっ","えっ","ふふ","あはは","やー","もうっ","……","んっ",
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- UI構築
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local ScrGui = Instance.new("ScreenGui")
ScrGui.Name           = "LoadingScreenGui"
ScrGui.ResetOnSpawn   = false
ScrGui.DisplayOrder   = 999
ScrGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScrGui.IgnoreGuiInset = true
ScrGui.Parent         = PlayerGui

local Root = Instance.new("Frame")
Root.Name               = "Root"
Root.Size               = UDim2.new(1,0,1,0)
Root.BackgroundColor3   = Color3.fromRGB(40, 80, 40)
Root.BorderSizePixel    = 0
Root.Visible            = false
Root.Parent             = ScrGui

-- 森グラデーション
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(20,  60,  20)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(50, 110,  50)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(80, 150,  80)),
})
grad.Rotation = 180
grad.Parent = Root

-- 木のシルエット（装飾）
local function addTree(xScale, size)
    local tree = Instance.new("TextLabel")
    tree.Size = UDim2.new(0, size, 0, size * 1.6)
    tree.Position = UDim2.new(xScale, -size/2, 1, -(size*1.6 - 10))
    tree.BackgroundTransparency = 1
    tree.Text = "🌲"
    tree.TextSize = size
    tree.Font = Enum.Font.GothamBold
    tree.ZIndex = 2
    tree.Parent = Root
end
for _, t in ipairs({
    {0.05,60},{0.12,80},{0.22,55},{0.35,70},{0.5,90},
    {0.63,65},{0.74,75},{0.85,55},{0.92,80},{0.98,60},
}) do addTree(t[1], t[2]) end

-- パートナーキャラ（中央）
local charArea = Instance.new("Frame")
charArea.Name = "CharArea"
charArea.Size = UDim2.new(0.4,0,0.55,0)
charArea.Position = UDim2.new(0.3,0,0.18,0)
charArea.BackgroundTransparency = 1
charArea.ZIndex = 10
charArea.Parent = Root

local charLabel = Instance.new("TextLabel")
charLabel.Name = "Char"
charLabel.Size = UDim2.new(1,0,0.85,0)
charLabel.BackgroundTransparency = 1
charLabel.Text = "🧑"
charLabel.TextSize = 110
charLabel.Font = Enum.Font.GothamBold
charLabel.ZIndex = 10
charLabel.Parent = charArea

-- セリフバブル
local bubble = Instance.new("Frame")
bubble.Name = "Bubble"
bubble.Size = UDim2.new(0.55,0,0.12,0)
bubble.Position = UDim2.new(0.52,0,0.28,0)
bubble.BackgroundColor3 = Color3.fromRGB(245,245,255)
bubble.ZIndex = 15
bubble.Parent = Root
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0.15,0)
bc.Parent = bubble

local bubbleText = Instance.new("TextLabel")
bubbleText.Name = "BubbleText"
bubbleText.Size = UDim2.new(0.9,0,0.8,0)
bubbleText.Position = UDim2.new(0.05,0,0.1,0)
bubbleText.BackgroundTransparency = 1
bubbleText.Text = "ちょっと待っててね"
bubbleText.TextColor3 = Color3.fromRGB(30,30,60)
bubbleText.Font = Enum.Font.GothamBold
bubbleText.TextSize = 15
bubbleText.TextWrapped = true
bubbleText.ZIndex = 16
bubbleText.Parent = bubble

-- タッチでリアクション（透明ボタン）
local touchBtn = Instance.new("TextButton")
touchBtn.Size = UDim2.new(1,0,1,0)
touchBtn.BackgroundTransparency = 1
touchBtn.Text = ""
touchBtn.ZIndex = 20
touchBtn.Parent = charArea

local lastTap = 0
touchBtn.MouseButton1Click:Connect(function()
    local now = tick()
    if now - lastTap < 0.5 then return end
    lastTap = now

    local line = TOUCH_LINES[math.random(#TOUCH_LINES)]
    bubbleText.Text = line
    -- 揺れアニメ
    TweenService:Create(charLabel,
        TweenInfo.new(0.1),
        {TextSize = 120}
    ):Play()
    task.delay(0.15, function()
        TweenService:Create(charLabel,
            TweenInfo.new(0.15),
            {TextSize = 110}
        ):Play()
    end)
    -- ハートを1個出す
    local h = Instance.new("TextLabel")
    h.Size = UDim2.new(0,30,0,30)
    h.Position = UDim2.new(0.5+math.random()*0.15,0,0.1,0)
    h.BackgroundTransparency = 1
    h.Text = "💚"
    h.TextSize = 24
    h.Font = Enum.Font.GothamBold
    h.ZIndex = 25
    h.Parent = charArea
    TweenService:Create(h,
        TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(h.Position.X.Scale,0,-0.15,0), TextTransparency=1}
    ):Play()
    task.delay(1.1, function() h:Destroy() end)
end)

-- プログレスバー
local barBg = Instance.new("Frame")
barBg.Name = "BarBg"
barBg.Size = UDim2.new(0.5,0,0.03,0)
barBg.Position = UDim2.new(0.25,0,0.9,0)
barBg.BackgroundColor3 = Color3.fromRGB(20,50,20)
barBg.ZIndex = 10
barBg.Parent = Root
local bc2 = Instance.new("UICorner")
bc2.CornerRadius = UDim.new(0.5,0)
bc2.Parent = barBg

local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0,0,1,0)
barFill.BackgroundColor3 = Color3.fromRGB(100,220,100)
barFill.ZIndex = 11
barFill.Parent = barBg
local bc3 = Instance.new("UICorner")
bc3.CornerRadius = UDim.new(0.5,0)
bc3.Parent = barFill

local loadLabel = Instance.new("TextLabel")
loadLabel.Name = "LoadLabel"
loadLabel.Size = UDim2.new(0.5,0,0.04,0)
loadLabel.Position = UDim2.new(0.25,0,0.94,0)
loadLabel.BackgroundTransparency = 1
loadLabel.Text = "読み込み中..."
loadLabel.TextColor3 = Color3.fromRGB(180,240,180)
loadLabel.Font = Enum.Font.Gotham
loadLabel.TextSize = 12
loadLabel.ZIndex = 10
loadLabel.Parent = Root

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ロード画面の制御
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local lineIdx = 1
local lineTimer = nil
local isShowing = false
local simulatedProgress = 0

local function cycleLines()
    lineIdx = lineIdx % #LOADING_LINES + 1
    TweenService:Create(bubbleText,
        TweenInfo.new(0.3),
        {TextTransparency = 1}
    ):Play()
    task.delay(0.35, function()
        bubbleText.Text = LOADING_LINES[lineIdx]
        TweenService:Create(bubbleText,
            TweenInfo.new(0.3),
            {TextTransparency = 0}
        ):Play()
    end)
end

-- プログレスを外部から更新できる
local function setProgress(pct)
    simulatedProgress = math.clamp(pct, 0, 1)
    TweenService:Create(barFill,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad),
        {Size = UDim2.new(simulatedProgress, 0, 1, 0)}
    ):Play()
end

local function showLoading(progressSource)
    if isShowing then return end
    isShowing = true
    Root.Visible = true
    Root.BackgroundTransparency = 0
    bubbleText.Text = LOADING_LINES[1]

    -- セリフを3秒ごとに切り替え
    lineTimer = task.spawn(function()
        while isShowing do
            task.wait(3)
            if isShowing then cycleLines() end
        end
    end)

    -- progressSourceがあれば進捗に合わせてバーを動かす
    if progressSource then
        task.spawn(function()
            while isShowing do
                task.wait(0.1)
                local p = progressSource()
                setProgress(p)
                if p >= 1 then break end
            end
        end)
    end
end

local function hideLoading()
    if not isShowing then return end
    isShowing = false
    if lineTimer then task.cancel(lineTimer) end
    -- フェードアウト
    TweenService:Create(Root,
        TweenInfo.new(0.6, Enum.EasingStyle.Quad),
        {BackgroundTransparency = 1}
    ):Play()
    task.delay(0.7, function()
        Root.Visible = false
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- マッチング待ち中の表示（UpdateBoard受信で制御）
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local RE_UB = Remotes:WaitForChild("UpdateBoard", 15)
if RE_UB then
    RE_UB.OnClientEvent:Connect(function(data)
        local t = data and data.type
        if t == "matching_start" then
            -- マッチング開始→ロード画面表示
            showLoading(nil)
            loadLabel.Text = "対戦相手を探しています..."
            setProgress(0.1)
            -- パートナーコメントをリクエスト
            if RE_Comfort then
                RE_Comfort:FireServer({type = "loading_comment_request"})
            end
            -- キャンセルボタンを表示
            local cancelBtn = Instance.new("TextButton")
            cancelBtn.Name = "CancelMatchBtn"
            cancelBtn.Size = UDim2.new(0.4, 0, 0.08, 0)
            cancelBtn.Position = UDim2.new(0.3, 0, 0.78, 0)
            cancelBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
            cancelBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
            cancelBtn.Text = "✕ キャンセル"
            cancelBtn.Font = Enum.Font.GothamBold
            cancelBtn.TextSize = 14
            cancelBtn.BorderSizePixel = 0
            cancelBtn.ZIndex = 1001
            cancelBtn.Parent = ScrGui
            local cc = Instance.new("UICorner")
            cc.CornerRadius = UDim.new(0.2, 0)
            cc.Parent = cancelBtn
            cancelBtn.MouseButton1Click:Connect(function()
                if RE_MMCancel then RE_MMCancel:FireServer() end
                cancelBtn:Destroy()
                hideLoading()
                -- ロビーに戻る
                if _G.ShowLobby then _G.ShowLobby()
                elseif _G.HideLoading then _G.HideLoading() end
            end)
        elseif t == "match_found" then
            -- マッチング完了 → キャンセルボタン削除
            local cb = ScrGui:FindFirstChild("CancelMatchBtn")
            if cb then cb:Destroy() end
            loadLabel.Text = "対戦相手が見つかりました！"
            setProgress(0.8)
            task.delay(1, function()
                setProgress(1)
                task.delay(0.5, hideLoading)
            end)
        elseif t == "game_start" or t == "br4p_start" then
            hideLoading()
        elseif t == "game_over" or t == "br4p_end" then
            -- 試合後のロビー復帰時に軽くロード演出
            showLoading(nil)
            loadLabel.Text = "ロビーへ戻っています..."
            setProgress(0.3)
            task.delay(0.8, function()
                setProgress(1)
                task.delay(0.4, hideLoading)
            end)
        end
    end)
end

-- PartnerComfortからのコメント受信
if RE_Comfort then
    RE_Comfort.OnClientEvent:Connect(function(data)
        if data and data.type == "loading_comment" and data.message then
            bubbleText.Text = data.message
        end
    end)
end

-- 外部から呼べるように公開
_G.ShowLoading = showLoading
_G.HideLoading = hideLoading
_G.SetLoadProgress = setProgress

print("✅ LoadingScreen.lua loaded")
