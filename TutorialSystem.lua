-- ============================================
-- GAMEROAD TutorialSystem.lua
-- StarterPlayerScripts/ に配置（LocalScript型）
--
-- 設計思想（公式ガイドとRoblox調査から）：
--   「誰もチュートリアルを読まない」
--   「最初の2分で楽しいと思わせる」
--   「プレイヤーが自分で発見したと感じさせる」
--
-- 実装方針：
--   ハルト（パートナー）が全部決めてくれる最初の1試合
--   プレイヤーは光ってるカードをタップするだけ
--   徐々に自分で選ぶ部分が増える
-- ============================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui", 15)

local Remotes       = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_UpdateBoard = Remotes:WaitForChild("UpdateBoard", 15)

-- チュートリアル完了フラグ（ローカルに持つ・DataStoreと連動）
local TutorialDone = false

-- ============================================
-- チュートリアルのステップ定義
-- ============================================
local STEPS = {
    {
        id    = "welcome",
        title = "ようこそ！",
        body  = "ハルトだ！一緒に戦おう！\nまず1試合、俺が教えてやるよ。",
        wait  = 3.0,
        auto  = true,  -- 自動で次へ
    },
    {
        id    = "rule_road",
        title = "ロードカード",
        body  = "まず全員が1枚カードを出す。\n一番大きい数字を出した人が攻撃権を取る！",
        wait  = 4.5,
        auto  = true,
    },
    {
        id    = "rule_battle",
        title = "バトルカード",
        body  = "攻撃側はバトルカードを出す。\n守備側はシールドが自動で使われる。",
        wait  = 4.5,
        auto  = true,
    },
    {
        id    = "rule_column",
        title = "7枚積み上げたら勝利！",
        body  = "勝った時のカードは列に積み上がる。\nどれか1列に7枚積んだチームの勝ち！",
        wait  = 4.5,
        auto  = true,
    },
    {
        id    = "try_road",
        title = "やってみよう！",
        body  = "光ってるカードをタップ！\n（今回はハルトが選んでくれてる）",
        wait  = 0,
        auto  = false,  -- プレイヤーの行動待ち
    },
    {
        id    = "good_road",
        title = "いいね！",
        body  = "完璧！じゃあ次はバトルカードだ。",
        wait  = 2.0,
        auto  = true,
    },
    {
        id    = "finish",
        title = "チュートリアル完了！",
        body  = "ルールはわかった？\nあとは実戦で覚えていこう！",
        wait  = 3.0,
        auto  = true,
    },
}

-- ============================================
-- チュートリアルUIを構築
-- ============================================
local function makeTutorialUI()
    -- 既存があれば削除
    local existing = PlayerGui:FindFirstChild("TutorialUI")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name          = "TutorialUI"
    sg.ResetOnSpawn  = false
sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Global
    sg.Parent        = PlayerGui

    -- 会話ウィンドウ（下部中央）
    local win = Instance.new("Frame")
    win.Name              = "DialogWindow"
    win.Size              = UDim2.new(0.7, 0, 0.2, 0)
    win.Position          = UDim2.new(0.15, 0, 0.76, 0)
    win.BackgroundColor3  = Color3.fromRGB(10, 20, 40)
    win.BackgroundTransparency = 0.1
    win.BorderSizePixel   = 0
    win.Parent            = sg
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.06, 0)
    corner.Parent       = win

    -- キャラアイコン（左）
    local icon = Instance.new("Frame")
    icon.Size             = UDim2.new(0.12, 0, 0.9, 0)
    icon.Position         = UDim2.new(0.01, 0, 0.05, 0)
    icon.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    icon.BorderSizePixel  = 0
    icon.Parent           = win
    local ic = Instance.new("UICorner")
    ic.CornerRadius = UDim.new(0.5, 0)
    ic.Parent       = icon

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size        = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text        = "H"  -- ハルトの頭文字（後でImageに変える）
    iconLabel.TextColor3  = Color3.fromRGB(255, 255, 255)
    iconLabel.TextScaled  = true
    iconLabel.Font        = Enum.Font.GothamBold
    iconLabel.Parent      = icon

    -- タイトル
    local titleL = Instance.new("TextLabel")
    titleL.Name           = "TitleLabel"
    titleL.Size           = UDim2.new(0.8, 0, 0.3, 0)
    titleL.Position       = UDim2.new(0.14, 0, 0.02, 0)
    titleL.BackgroundTransparency = 1
    titleL.Text           = "ハルト"
    titleL.TextColor3     = Color3.fromRGB(100, 200, 255)
    titleL.TextScaled     = true
    titleL.Font           = Enum.Font.GothamBold
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent         = win

    -- 本文
    local bodyL = Instance.new("TextLabel")
    bodyL.Name            = "BodyLabel"
    bodyL.Size            = UDim2.new(0.84, 0, 0.62, 0)
    bodyL.Position        = UDim2.new(0.14, 0, 0.34, 0)
    bodyL.BackgroundTransparency = 1
    bodyL.Text            = "..."
    bodyL.TextColor3      = Color3.fromRGB(230, 240, 255)
    bodyL.TextScaled      = true
    bodyL.Font            = Enum.Font.Gotham
    bodyL.TextXAlignment  = Enum.TextXAlignment.Left
    bodyL.TextWrapped     = true
    bodyL.Parent          = win

    -- タップで次へ インジケーター
    local nextL = Instance.new("TextLabel")
    nextL.Name            = "NextLabel"
    nextL.Size            = UDim2.new(0.2, 0, 0.3, 0)
    nextL.Position        = UDim2.new(0.78, 0, 0.65, 0)
    nextL.BackgroundTransparency = 1
    nextL.Text            = "▶ タップ"
    nextL.TextColor3      = Color3.fromRGB(255, 215, 0)
    nextL.TextScaled      = true
    nextL.Font            = Enum.Font.GothamBold
    nextL.Parent          = win

    -- タップで進む（autoでないstepで点滅）
    local blink = false
    task.spawn(function()
        while sg.Parent do
            task.wait(0.5)
            blink = not blink
            nextL.Visible = blink
        end
    end)

    -- 進捗バー（上部）
    local progressBG = Instance.new("Frame")
    progressBG.Size             = UDim2.new(0.7, 0, 0.025, 0)
    progressBG.Position         = UDim2.new(0.15, 0, 0.74, 0)
    progressBG.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    progressBG.BorderSizePixel  = 0
    progressBG.Parent           = sg
    local pbc = Instance.new("UICorner")
    pbc.CornerRadius = UDim.new(1, 0)
    pbc.Parent       = progressBG

    local progressBar = Instance.new("Frame")
    progressBar.Name            = "ProgressBar"
    progressBar.Size            = UDim2.new(0, 0, 1, 0)
    progressBar.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
    progressBar.BorderSizePixel = 0
    progressBar.Parent          = progressBG
    local pbcc = Instance.new("UICorner")
    pbcc.CornerRadius = UDim.new(1, 0)
    pbcc.Parent       = progressBar

    -- スキップボタン
    local skipBtn = Instance.new("TextButton")
    skipBtn.Name             = "SkipButton"
    skipBtn.Size             = UDim2.new(0.12, 0, 0.06, 0)
    skipBtn.Position         = UDim2.new(0.87, 0, 0.92, 0)
    skipBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    skipBtn.BorderSizePixel  = 0
    skipBtn.Text             = "スキップ"
    skipBtn.TextColor3       = Color3.fromRGB(150, 150, 150)
    skipBtn.TextScaled       = true
    skipBtn.Font             = Enum.Font.Gotham
    skipBtn.Parent           = sg
    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(0.3, 0)
    sc.Parent       = skipBtn

    return sg, titleL, bodyL, nextL, progressBar, skipBtn, win
end

-- ============================================
-- テキストアニメーション（タイプライター効果）
-- ============================================
local function typewrite(label, text, speed)
    speed = speed or 0.04
    label.Text = ""
    for i = 1, #text do
        label.Text = string.sub(text, 1, i)
        task.wait(speed)
    end
end

-- ============================================
-- カードをハイライト（光らせて次にタップすべきカードを示す）
-- ============================================
local function highlightRecommendedCard(cardId)
    -- BattleClient_v2のCardContainerを探す
    local gameUI = PlayerGui:FindFirstChild("GameRoadUI")
    if not gameUI then return end
    local hand   = gameUI:FindFirstChild("HandFrame")
    if not hand  then return end
    local container = hand:FindFirstChild("CardContainer")
    if not container then return end

    local cardFrame = container:FindFirstChild("Card_" .. tostring(cardId))
    if not cardFrame then return end

    -- 金色に光らせる
    TweenService:Create(cardFrame,
        TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {BackgroundColor3 = Color3.fromRGB(255, 240, 80)}
    ):Play()

    -- 矢印（↑）をカードの上に表示
    local arrow = Instance.new("TextLabel")
    arrow.Name              = "TutArrow"
    arrow.Size              = UDim2.new(1, 0, 0.4, 0)
    arrow.Position          = UDim2.new(0, 0, -0.45, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text              = "👆"
    arrow.TextScaled        = true
    arrow.Font              = Enum.Font.GothamBold
    arrow.Parent            = cardFrame

    TweenService:Create(arrow,
        TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Position = UDim2.new(0, 0, -0.55, 0)}
    ):Play()
end

local function clearHighlights()
    local gameUI = PlayerGui:FindFirstChild("GameRoadUI")
    if not gameUI then return end
    local hand   = gameUI:FindFirstChild("HandFrame")
    if not hand  then return end
    local container = hand:FindFirstChild("CardContainer")
    if not container then return end

    for _, child in ipairs(container:GetChildren()) do
        local arrow = child:FindFirstChild("TutArrow")
        if arrow then arrow:Destroy() end
        -- ハイライトTweenを止める
        TweenService:Create(child,
            TweenInfo.new(0.2),
            {BackgroundColor3 = Color3.fromRGB(250, 248, 240)}
        ):Play()
    end
end

-- ============================================
-- チュートリアル実行
-- ============================================
local tutStep = 1
local waitForTap = false
local uiRef = nil

local function advanceStep()
    if not uiRef then return end
    local sg, titleL, bodyL, nextL, progressBar, skipBtn, win = table.unpack(uiRef)

    if tutStep > #STEPS then
        -- 完了
        TutorialDone = true
        TweenService:Create(sg,
            TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        task.wait(0.6)
        sg:Destroy()
        -- サーバーに完了通知
        RE_UpdateBoard:FireServer({type = "tutorial_complete"})
        -- チュートリアル後の自動ガイド（ロビーに戻ってからヒント表示）
        task.delay(1.5, function()
            if _G.ShowToast then
                _G.ShowToast("🎯 チュートリアル完了！まず1試合やってみよう！", 4)
            end
            -- ロビーを表示
            if _G.ShowLobby then _G.ShowLobby() end
        end)
        return
    end

    local step = STEPS[tutStep]

    -- 進捗バー更新
    TweenService:Create(progressBar,
        TweenInfo.new(0.3),
        {Size = UDim2.new(tutStep / #STEPS, 0, 1, 0)}
    ):Play()

    -- テキスト表示
    titleL.Text = "ハルト"
    task.spawn(function()
        typewrite(bodyL, step.body or "")
    end)

    nextL.Visible = not step.auto

    if step.auto then
        waitForTap = false
        task.delay(step.wait or 2.0, function()
            tutStep = tutStep + 1
            advanceStep()
        end)
    else
        waitForTap = true
    end
end

-- UIのタップで進む
local function onWindowTap()
    if not waitForTap then return end
    waitForTap = false
    clearHighlights()
    tutStep = tutStep + 1
    advanceStep()
end

-- ============================================
-- チュートリアルを開始する
-- ============================================
local function startTutorial()
    local sg, titleL, bodyL, nextL, progressBar, skipBtn, win =
        makeTutorialUI()

    uiRef = {sg, titleL, bodyL, nextL, progressBar, skipBtn, win}

    -- ウィンドウタップで進む
    local tapBtn = Instance.new("TextButton")
    tapBtn.Size              = UDim2.new(1, 0, 1, 0)
    tapBtn.BackgroundTransparency = 1
    tapBtn.Text              = ""
    tapBtn.Parent            = win
    tapBtn.MouseButton1Click:Connect(onWindowTap)

    -- スキップ
    skipBtn.MouseButton1Click:Connect(function()
        TutorialDone = true
        sg:Destroy()
        uiRef = nil
    end)

    -- 登場アニメ
    win.Position = UDim2.new(0.15, 0, 1.1, 0)
    TweenService:Create(win,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.15, 0, 0.76, 0)}
    ):Play()

    tutStep = 1
    advanceStep()
end

-- ============================================
-- BattleClientのイベントを傍受してヒントを出す
-- ============================================
-- request_road が来たらパートナーが推奨カードを光らせる
RE_UpdateBoard.OnClientEvent:Connect(function(data)
    if not data then return end

    if data.type == "player_data" then
        -- 初回プレイヤーか確認
        if data.tutorialDone then
            TutorialDone = true
        else
            task.delay(1.5, startTutorial)
        end

    elseif data.type == "request_road" and not TutorialDone then
        -- チュートリアル中：手札から最大値を光らせる
        local hand = data.hand
        if hand and #hand > 0 then
            local best = hand[1]
            for _, c in ipairs(hand) do
                if c.rank > best.rank then best = c end
            end
            highlightRecommendedCard(best.id)
        end
        -- step "try_road" を表示
        if uiRef and tutStep <= #STEPS then
            local step = STEPS[tutStep]
            if step and step.id == "try_road" then
                waitForTap = false  -- カードタップで進む
            end
        end

    elseif data.type == "road_reveal" and not TutorialDone then
        clearHighlights()
        -- "good_road" ステップへ
        if uiRef then
            tutStep = 6  -- "good_road"へ強制ジャンプ
            advanceStep()
        end

    elseif data.type == "game_start" and not TutorialDone then
        -- ゲーム開始後にルール説明を終わらせる
        if uiRef and tutStep <= 4 then
            tutStep = 5  -- try_roadへ
            advanceStep()
        end
    end
end)

-- ============================================
-- 次回からのヒント（チュートリアル完了後のコンテキストヒント）
-- ============================================
local CONTEXT_HINTS = {
    first_win  = "🏆 初勝利！経験値+200ボーナス！",
    first_arcana = "✦ アルカナを使えると更に有利に！",
    chips_full = "⚡ チップが4枚以上！今が勝負どころ！",
    col_danger = "⚠ 敵の列が6枚！すぐ止めないと負ける！",
    pity_near  = "✨ 天井まであと20回！SSRが近い！",
}

local ShownHints = {}

local function showContextHint(key)
    if ShownHints[key] then return end
    ShownHints[key] = true

    local msg = CONTEXT_HINTS[key]
    if not msg then return end

    local gameUI = PlayerGui:FindFirstChild("GameRoadUI")
    if not gameUI then return end

    local hint = Instance.new("Frame")
    hint.Size             = UDim2.new(0.5, 0, 0.07, 0)
    hint.Position         = UDim2.new(0.25, 0, -0.08, 0)  -- 画面上から降ってくる
    hint.BackgroundColor3 = Color3.fromRGB(20, 40, 80)
    hint.BackgroundTransparency = 0.1
    hint.BorderSizePixel  = 0
    hint.ZIndex           = 80
    hint.Parent           = gameUI
    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0.3, 0)
    hc.Parent       = hint

    local hl = Instance.new("TextLabel")
    hl.Size        = UDim2.new(1, 0, 1, 0)
    hl.BackgroundTransparency = 1
    hl.Text        = msg
    hl.TextColor3  = Color3.fromRGB(255, 240, 180)
    hl.TextScaled  = true
    hl.Font        = Enum.Font.GothamBold
    hl.Parent      = hint

    -- 降ってきて表示 → 3秒後に消える
    TweenService:Create(hint,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.25, 0, 0.01, 0)}
    ):Play()

    task.delay(3.5, function()
        TweenService:Create(hint,
            TweenInfo.new(0.3),
            {Position = UDim2.new(0.25, 0, -0.08, 0)}
        ):Play()
        task.wait(0.35)
        hint:Destroy()
    end)
end

-- ゲームイベントからコンテキストヒントを判断
RE_UpdateBoard.OnClientEvent:Connect(function(data)
    if not data or not TutorialDone then return end

    if data.type == "battle_result" then
        -- チップ警戒
        if data.columns then
            for uid, c in pairs(data.columns) do
                if uid ~= tostring(LocalPlayer.UserId) then
                    -- 敵の最大列
                    local maxC = math.max(c.col1 or 0, c.col2 or 0, c.col3 or 0)
                    if maxC >= 6 then showContextHint("col_danger") end
                end
                if uid == tostring(LocalPlayer.UserId) then
                    if (c.chips or 0) >= 4 then showContextHint("chips_full") end
                end
            end
        end
    elseif data.type == "gacha_result" then
        if data.pity and data.pity >= 80 then showContextHint("pity_near") end
    elseif data.type == "elo_update" and data.won and not ShownHints["first_win"] then
        showContextHint("first_win")
    end
end)

print("✅ TutorialSystem.lua loaded")
