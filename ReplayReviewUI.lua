-- ============================================
-- ReplayReviewUI.lua
-- StarterPlayerScripts/ に配置（LocalScript）
--
-- プレミ登録システム
--  ① バトル後に「プレイ確認」ボタンが出る
--  ② ターンログを1ターンずつ確認
--  ③ 「これはプレミだった」ボタン → 正解行動を入力して登録
--  ④ 登録した内容はサーバー（PartnerSystem）に送信
--  ⑤ 次回バトルで似た状況が来ると
--       → 相方が表情差分付きフキダシでアドバイス
-- ============================================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui", 15)
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_Replay   = Remotes:WaitForChild("SaveReplayChoice", 10)
local RE_UpdateBoard = Remotes:WaitForChild("UpdateBoard", 10)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 表情テーブル（ImageID を差し替える）
-- 各状態で相方の顔画像が変わる
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 画像アセットIDは差し替え用プレースホルダー
-- Robloxにアップロード後に実IDを入れる
local FACE_IDS = {
    normal   = "rbxassetid://0",   -- 通常
    thinking = "rbxassetid://0",   -- 考え中
    happy    = "rbxassetid://0",   -- 嬉しい
    sad      = "rbxassetid://0",   -- 悔しい
    advice   = "rbxassetid://0",   -- アドバイス
    cheer    = "rbxassetid://0",   -- 応援
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 状態
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local CurrentReplay = nil   -- {turns=[...], myUserId=...}
local CurrentTurnIdx = 1
local IsOpen = false

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- UI ヘルパー
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function makeFrame(parent, size, pos, color, name, alpha)
    local f = Instance.new("Frame")
    f.Size            = size
    f.Position        = pos
    f.BackgroundColor3 = color or Color3.fromRGB(20, 20, 30)
    f.BackgroundTransparency = alpha or 0
    f.BorderSizePixel = 0
    if name then f.Name = name end
    f.Parent = parent
    return f
end

local function makeLabel(parent, text, size, pos, color, name, fontSize, wrap)
    local l = Instance.new("TextLabel")
    l.Size              = size
    l.Position          = pos
    l.Text              = text
    l.TextColor3        = color or Color3.fromRGB(230, 230, 230)
    l.BackgroundTransparency = 1
    l.TextScaled        = not fontSize
    l.TextSize          = fontSize or 14
    l.Font              = Enum.Font.GothamBold
    l.TextWrapped       = wrap or false
    l.TextXAlignment    = Enum.TextXAlignment.Left
    if name then l.Name = name end
    l.Parent = parent
    return l
end

local function makeBtn(parent, text, size, pos, bgColor, textColor)
    local b = Instance.new("TextButton")
    b.Size              = size
    b.Position          = pos
    b.Text              = text
    b.BackgroundColor3  = bgColor or Color3.fromRGB(60, 130, 200)
    b.TextColor3        = textColor or Color3.fromRGB(255, 255, 255)
    b.Font              = Enum.Font.GothamBold
    b.TextScaled        = true
    b.BorderSizePixel   = 0
    b.AutoButtonColor   = true
    b.Parent            = parent
    return b
end

local function makeCorner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = inst
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- バトル中の左端アドバイスフキダシ（表情差分付き）
-- BattleClient から _G.ShowPartnerAdvice(msg, face) で呼ぶ
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AdviceGui = nil
local AdviceFaceImg = nil
local AdviceText = nil
local AdviceTimer = 0
local ADVICE_DURATION = 4  -- 秒

local function buildAdviceWidget()
    if AdviceGui then return end

    -- 左端フキダシ（画面左端から少し入った位置）
    local sg = Instance.new("ScreenGui")
    sg.Name            = "PartnerAdviceGui"
    sg.ResetOnSpawn    = false
    sg.DisplayOrder    = 30
    sg.IgnoreGuiInset  = true
    sg.Parent          = PlayerGui
    AdviceGui = sg

    -- 土台（フキダシ背景）
    local frame = makeFrame(sg,
        UDim2.new(0, 240, 0, 72),
        UDim2.new(0, -250, 0.12, 0),   -- 最初は画面外左
        Color3.fromRGB(15, 20, 40), "AdviceFrame", 0.08)
    makeCorner(frame, 12)

    -- 細いボーダー
    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(80, 160, 255)
    stroke.Thickness = 1.5
    stroke.Parent    = frame

    -- 相方顔アイコン
    local faceFrame = makeFrame(frame,
        UDim2.new(0, 52, 0, 52),
        UDim2.new(0, 8, 0.5, -26),
        Color3.fromRGB(30, 40, 70), "FaceFrame")
    makeCorner(faceFrame, 26)
    local face = Instance.new("ImageLabel")
    face.Size   = UDim2.new(1, 0, 1, 0)
    face.Image  = FACE_IDS.normal
    face.BackgroundTransparency = 1
    face.Name   = "FaceImg"
    face.Parent = faceFrame
    AdviceFaceImg = face

    -- テキスト
    local label = makeLabel(frame,
        "", UDim2.new(0, 168, 1, -8),
        UDim2.new(0, 66, 0, 4),
        Color3.fromRGB(220, 235, 255), "AdviceText", 12, true)
    label.TextXAlignment = Enum.TextXAlignment.Left
    AdviceText = label

    frame.Name = "AdviceSlider"
end

-- スライドイン → 表示 → スライドアウト
local function slideAdvice(inBool)
    local frame = AdviceGui and AdviceGui:FindFirstChild("AdviceSlider")
    if not frame then return end
    local targetX = inBool and 8 or -250
    local tween = TweenService:Create(frame,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, targetX, 0.12, 0)})
    tween:Play()
end

_G.ShowPartnerAdvice = function(msg, faceKey)
    buildAdviceWidget()
    if AdviceText then AdviceText.Text = msg end
    if AdviceFaceImg then
        AdviceFaceImg.Image = FACE_IDS[faceKey or "advice"] or FACE_IDS.advice
    end
    slideAdvice(true)
    task.cancel(AdviceTimer)  -- 前のタイマーをキャンセル
    AdviceTimer = task.delay(ADVICE_DURATION, function()
        slideAdvice(false)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- プレミ確認ウィンドウ本体
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local ReviewGui = nil

local function closeReview()
    IsOpen = false
    if ReviewGui then ReviewGui:Destroy(); ReviewGui = nil end
end

local function renderTurn(sg, turnData, myId, onPremiMark)
    -- sg 内を一掃して再描画
    for _, c in ipairs(sg:GetChildren()) do
        if c:IsA("Frame") and c.Name == "TurnContent" then c:Destroy() end
    end

    local content = makeFrame(sg,
        UDim2.new(1, -20, 1, -110),
        UDim2.new(0, 10, 0, 55),
        Color3.fromRGB(18, 24, 40), "TurnContent", 0.2)
    makeCorner(content, 8)

    -- ターン番号
    makeLabel(content, "ターン " .. (turnData.turn or "?"),
        UDim2.new(1, -20, 0, 24),
        UDim2.new(0, 10, 0, 6),
        Color3.fromRGB(120, 200, 255), nil, 16)

    -- 各プレイヤーの行動を縦に並べる
    local yOff = 36
    for uid, pl in pairs(turnData.players or {}) do
        local isMe = (uid == tostring(myId))
        local color = isMe and Color3.fromRGB(100, 220, 140)
                            or Color3.fromRGB(200, 200, 200)
        local winMark = pl.isWinner and " 👑" or ""
        local roadName  = pl.road   and ("[R]"..pl.road.name  .."("..pl.road.rank..")")   or "-"
        local battleName = pl.battle and ("[B]"..pl.battle.name.."("..pl.battle.rank..")") or "-"
        local chipStr    = "チップ×"..tostring(pl.chipCount or 0)
        local colStr     = ""
        for i, n in ipairs(pl.colState or {}) do
            colStr = colStr .. (i>1 and "/" or "") .. n
        end
        local line = string.format("%s%s  合計%d  %s %s  列[%s]  %s",
            pl.name or uid, winMark,
            pl.total or 0,
            roadName, battleName,
            colStr, chipStr)

        makeLabel(content, line,
            UDim2.new(1, -20, 0, 20),
            UDim2.new(0, 10, 0, yOff),
            color, nil, 11, true)
        yOff = yOff + 28
    end

    -- プレミボタン（自分の行動が間違っていたと思う時）
    local myLog = turnData.players and turnData.players[tostring(myId)]
    if myLog then
        local premBtn = makeBtn(content,
            "⚡ このターンはプレミだった",
            UDim2.new(0, 200, 0, 38),
            UDim2.new(0.5, -100, 1, -46),
            Color3.fromRGB(200, 60, 60))
        makeCorner(premBtn, 8)
        premBtn.MouseButton1Click:Connect(function()
            onPremiMark(turnData, myLog)
        end)
    end
end

-- プレミ登録入力ダイアログ
local function openPremiInput(turnData, myLog, onConfirm)
    local overlay = makeFrame(ReviewGui,
        UDim2.new(1, 0, 1, 0),
        UDim2.new(0, 0, 0, 0),
        Color3.fromRGB(0, 0, 0), "PremiOverlay", 0.4)

    local dialog = makeFrame(overlay,
        UDim2.new(0, 320, 0, 260),
        UDim2.new(0.5, -160, 0.5, -130),
        Color3.fromRGB(20, 26, 50), "PremiDialog")
    makeCorner(dialog, 14)
    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(220, 80, 80)
    stroke.Thickness = 2
    stroke.Parent    = dialog

    makeLabel(dialog, "プレミを登録",
        UDim2.new(1, -20, 0, 28),
        UDim2.new(0, 10, 0, 8),
        Color3.fromRGB(255, 120, 120), nil, 16, false)

    -- ターン情報の要約
    local roadName = myLog.road   and myLog.road.name   or "なし"
    local batName  = myLog.battle and myLog.battle.name or "なし"
    makeLabel(dialog,
        string.format("ロード: %s  バトル: %s\nチップ%d枚  合計%d",
            roadName, batName,
            myLog.chipCount or 0, myLog.total or 0),
        UDim2.new(1, -20, 0, 40),
        UDim2.new(0, 10, 0, 40),
        Color3.fromRGB(200, 200, 200), nil, 11, true)

    -- 状況タグ選択（どの状況でプレミったか）
    makeLabel(dialog, "状況を選択：",
        UDim2.new(1, -20, 0, 18),
        UDim2.new(0, 10, 0, 88),
        Color3.fromRGB(170, 200, 255), nil, 12)

    local SITUATIONS = {
        {key="road_high",   label="ロードが高すぎた"},
        {key="road_low",    label="ロードが低すぎた"},
        {key="battle_miss", label="バトルカード選択ミス"},
        {key="chip_waste",  label="チップを無駄にした"},
        {key="col_miss",    label="狙う列を間違えた"},
    }
    local selectedSit = SITUATIONS[1].key
    local sitBtns = {}
    for i, sit in ipairs(SITUATIONS) do
        local xOff = ((i - 1) % 2) * 150 + 10
        local yOff = math.floor((i - 1) / 2) * 28 + 110
        local b = makeBtn(dialog, sit.label,
            UDim2.new(0, 140, 0, 24),
            UDim2.new(0, xOff, 0, yOff),
            Color3.fromRGB(50, 60, 90),
            Color3.fromRGB(180, 200, 255))
        makeCorner(b, 6)
        sitBtns[i] = {btn=b, key=sit.key}
        b.MouseButton1Click:Connect(function()
            selectedSit = sit.key
            for _, sb in ipairs(sitBtns) do
                sb.btn.BackgroundColor3 = Color3.fromRGB(50, 60, 90)
            end
            b.BackgroundColor3 = Color3.fromRGB(100, 60, 160)
        end)
    end

    -- 確定ボタン
    local okBtn = makeBtn(dialog, "✅ 登録する",
        UDim2.new(0, 130, 0, 36),
        UDim2.new(0, 10, 1, -46),
        Color3.fromRGB(40, 160, 80))
    makeCorner(okBtn, 8)
    okBtn.MouseButton1Click:Connect(function()
        onConfirm(selectedSit, turnData.turn)
        overlay:Destroy()
    end)

    local cancelBtn = makeBtn(dialog, "キャンセル",
        UDim2.new(0, 130, 0, 36),
        UDim2.new(0, 150, 1, -46),
        Color3.fromRGB(70, 70, 80))
    makeCorner(cancelBtn, 8)
    cancelBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
end

-- プレミ確認ウィンドウを開く
local function openReview(replayData)
    if IsOpen then closeReview() end
    if not replayData or #replayData == 0 then return end

    IsOpen = true
    local myId = tostring(LocalPlayer.UserId)

    local sg = Instance.new("ScreenGui")
    sg.Name           = "ReplayReviewGui"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 50
    sg.IgnoreGuiInset = true
    sg.Parent         = PlayerGui
    ReviewGui = sg

    -- 半透明背景
    local bg = makeFrame(sg,
        UDim2.new(1, 0, 1, 0),
        UDim2.new(0, 0, 0, 0),
        Color3.fromRGB(0, 0, 0), "BG", 0.55)

    -- メインウィンドウ（右よりに配置）
    local win = makeFrame(sg,
        UDim2.new(0, 360, 0, 520),
        UDim2.new(0.5, -180, 0.5, -260),
        Color3.fromRGB(14, 18, 35), "Window")
    makeCorner(win, 16)
    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(60, 120, 220)
    stroke.Thickness = 1.5
    stroke.Parent    = win

    -- タイトルバー
    makeLabel(win, "⚡ プレイ確認",
        UDim2.new(1, -60, 0, 36),
        UDim2.new(0, 12, 0, 6),
        Color3.fromRGB(100, 180, 255), nil, 18)

    local closeBtn = makeBtn(win, "✕",
        UDim2.new(0, 44, 0, 44),
        UDim2.new(1, -50, 0, 0),
        Color3.fromRGB(60, 30, 30),
        Color3.fromRGB(255, 120, 120))
    makeCorner(closeBtn, 8)
    closeBtn.MouseButton1Click:Connect(closeReview)

    -- ターン移動バー
    local navBar = makeFrame(win,
        UDim2.new(1, -20, 0, 44),
        UDim2.new(0, 10, 0, 44),
        Color3.fromRGB(22, 28, 50), "NavBar")
    makeCorner(navBar, 8)

    local prevBtn = makeBtn(navBar, "◀",
        UDim2.new(0, 44, 0, 36),
        UDim2.new(0, 4, 0, 4),
        Color3.fromRGB(40, 60, 100))
    makeCorner(prevBtn, 6)

    local nextBtn = makeBtn(navBar, "▶",
        UDim2.new(0, 44, 0, 36),
        UDim2.new(1, -50, 0, 4),
        Color3.fromRGB(40, 60, 100))
    makeCorner(nextBtn, 6)

    local turnLabel = makeLabel(navBar, "",
        UDim2.new(1, -100, 0, 36),
        UDim2.new(0, 52, 0, 4),
        Color3.fromRGB(200, 210, 230), "TurnLabel", 13, false)
    turnLabel.TextXAlignment = Enum.TextXAlignment.Center

    local function refreshTurn()
        local td = replayData[CurrentTurnIdx]
        if not td then return end
        turnLabel.Text = "ターン " .. td.turn .. " / " .. replayData[#replayData].turn
        renderTurn(win, td, myId, function(turnData, myLog)
            openPremiInput(turnData, myLog, function(situation, turnNum)
                -- サーバーに送信してpartnerSystemに学習させる
                if RE_Replay then
                    RE_Replay:FireServer({
                        turn      = turnNum,
                        situation = situation,
                        choice    = myLog.road and myLog.road.name or "不明",
                        wasGood   = false,  -- プレミ登録なのでfalse
                        roadCard  = myLog.road,
                        battleCard = myLog.battle,
                    })
                end
                -- ローカルに「良い行動ではなかった」として記録（逆に良かった行動を学習させる目的）
                _G.ShowPartnerAdvice and _G.ShowPartnerAdvice(
                    "プレミ登録したよ！次はもっとうまくやれるね",
                    "thinking")
            end)
        end)
    end

    prevBtn.MouseButton1Click:Connect(function()
        if CurrentTurnIdx > 1 then
            CurrentTurnIdx = CurrentTurnIdx - 1
            refreshTurn()
        end
    end)
    nextBtn.MouseButton1Click:Connect(function()
        if CurrentTurnIdx < #replayData then
            CurrentTurnIdx = CurrentTurnIdx + 1
            refreshTurn()
        end
    end)

    -- 「全ターンを良かった/良くなかったで一括評価」ボタン
    local allOkBtn = makeBtn(win, "🟢 このバトル全体を振り返る",
        UDim2.new(1, -20, 0, 40),
        UDim2.new(0, 10, 1, -52),
        Color3.fromRGB(30, 100, 60))
    makeCorner(allOkBtn, 8)
    allOkBtn.MouseButton1Click:Connect(function()
        -- 最後のターンを「全体として良い試合だった」としてサーバーに送る
        if RE_Replay and replayData[#replayData] then
            RE_Replay:FireServer({
                turn      = replayData[#replayData].turn,
                situation = "full_game_good",
                choice    = "general",
                wasGood   = true,
            })
        end
        closeReview()
        _G.ShowPartnerAdvice and _G.ShowPartnerAdvice(
            "お疲れ！次のバトルも一緒に頑張ろう", "happy")
    end)

    CurrentTurnIdx = 1
    refreshTurn()
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- バトル終了時に「プレイ確認」ボタンを出す
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function showReviewPrompt(replayData, didWin)
    -- ゲームオーバー画面に小さいボタンを追加
    task.delay(2.5, function()
        local sg = Instance.new("ScreenGui")
        sg.Name          = "ReviewPromptGui"
        sg.ResetOnSpawn  = false
        sg.DisplayOrder  = 22
        sg.IgnoreGuiInset = true
        sg.Parent        = PlayerGui

        -- 左端からスライドイン
        local btn = makeBtn(sg, "📋 プレイ確認",
            UDim2.new(0, 150, 0, 46),
            UDim2.new(0, -160, 0.88, 0),
            Color3.fromRGB(40, 60, 120))
        makeCorner(btn, 10)
        local stroke = Instance.new("UIStroke")
        stroke.Color     = Color3.fromRGB(100, 160, 255)
        stroke.Thickness = 1.5
        stroke.Parent    = btn

        -- スライドイン
        TweenService:Create(btn,
            TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = UDim2.new(0, 8, 0.88, 0)}
        ):Play()

        btn.MouseButton1Click:Connect(function()
            sg:Destroy()
            openReview(replayData)
        end)

        -- 15秒後に自動で消える
        task.delay(15, function()
            if sg and sg.Parent then
                TweenService:Create(btn,
                    TweenInfo.new(0.3),
                    {Position = UDim2.new(0, -160, 0.88, 0)}
                ):Play()
                task.delay(0.35, function()
                    if sg and sg.Parent then sg:Destroy() end
                end)
            end
        end)
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- PartnerSystem からのアドバイス受信
-- （バトル中に learnedMoves に一致する状況が来た時）
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RE_UpdateBoard.OnClientEvent:Connect(function(data)
    if data.type == "game_over" then
        if data.replayData and #data.replayData > 0 then
            showReviewPrompt(data.replayData, data.victory)
        end
    elseif data.type == "partner_advice" then
        -- 相方がlearnedMovesに基づいてアドバイスしてくれる
        local faceKey = "advice"
        if data.adviceType == "danger"  then faceKey = "sad"      end
        if data.adviceType == "cheer"   then faceKey = "cheer"    end
        if data.adviceType == "learned" then faceKey = "thinking" end
        _G.ShowPartnerAdvice(data.message or "気をつけよう！", faceKey)
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- グローバル公開
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
_G.OpenReplayReview   = openReview
_G.CloseReplayReview  = closeReview

print("✅ ReplayReviewUI.lua loaded")
