-- EXPhaseClient.lua
-- StarterPlayerScripts/EXPhaseClient
-- EXセットフェーズUI（アルカナ+じゃんけん統合）

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)
-- DinoSystem はサーバー側で処理するためクライアントからrequire不要
local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui", 15)

local HAND_ICON  = {gu="✊", choki="✌", pa="✋", kakushi="★"}
local HAND_COLOR = {
    gu     = Color3.fromRGB(220, 80,  80),
    choki  = Color3.fromRGB(80,  180, 80),
    pa     = Color3.fromRGB(80,  120, 220),
    kakushi= Color3.fromRGB(220, 180, 40),
}

-- ─── UI生成 ───
local screen = Instance.new("ScreenGui")
screen.Name = "EXSetPanel"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Enabled = false
screen.DisplayOrder = 50
screen.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1,0,1,0)
overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
overlay.BackgroundTransparency = 0.5
overlay.BorderSizePixel = 0
overlay.Parent = screen

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0.85,0,0.7,0)
panel.Position = UDim2.new(0.075,0,0.15,0)
panel.BackgroundColor3 = Color3.fromRGB(15,15,30)
panel.BorderSizePixel = 0
panel.Parent = overlay
local pc = Instance.new("UICorner"); pc.CornerRadius=UDim.new(0,12); pc.Parent=panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0.09,0)
title.BackgroundTransparency = 1
title.Text = "✦ EXセットフェーズ ✦"
title.TextColor3 = Color3.fromRGB(212,160,255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = panel

-- 左: アルカナ
local arcanaLabel = Instance.new("TextLabel")
arcanaLabel.Size = UDim2.new(0.48,0,0.07,0)
arcanaLabel.Position = UDim2.new(0.01,0,0.1,0)
arcanaLabel.BackgroundTransparency = 1
arcanaLabel.Text = "アルカナ"
arcanaLabel.TextColor3 = Color3.fromRGB(200,200,255)
arcanaLabel.TextScaled = true
arcanaLabel.Font = Enum.Font.Gotham
arcanaLabel.Parent = panel

local arcanaScroll = Instance.new("ScrollingFrame")
arcanaScroll.Name = "ArcanaScroll"
arcanaScroll.Size = UDim2.new(0.30,0,0.72,0)
arcanaScroll.Position = UDim2.new(0.01,0,0.18,0)
arcanaScroll.BackgroundColor3 = Color3.fromRGB(10,10,20)
arcanaScroll.BorderSizePixel = 0
arcanaScroll.ScrollBarThickness = 4
arcanaScroll.Parent = panel
-- ── 中央: コーデカード列 ──
local coordLabel = Instance.new("TextLabel")
coordLabel.Size = UDim2.new(0.33,0,0.07,0)
coordLabel.Position = UDim2.new(0.32,0,0.10,0)
coordLabel.BackgroundTransparency = 1
coordLabel.Text = "コーデ"
coordLabel.TextColor3 = Color3.fromRGB(255,180,220)
coordLabel.TextScaled = true
coordLabel.Font = Enum.Font.GothamBold
coordLabel.Parent = panel

local coordScroll = Instance.new("ScrollingFrame")
coordScroll.Name = "CoordScroll"
coordScroll.Size = UDim2.new(0.33,0,0.72,0)
coordScroll.Position = UDim2.new(0.32,0,0.18,0)
coordScroll.BackgroundColor3 = Color3.fromRGB(10,8,18)
coordScroll.BorderSizePixel = 0
coordScroll.ScrollBarThickness = 4
coordScroll.CanvasSize = UDim2.new(0,0,0,0)
coordScroll.Parent = panel

local COORD_PART_COLORS = {
    tops    = Color3.fromRGB(220,80,120),
    bottoms = Color3.fromRGB(80,120,220),
    shoes   = Color3.fromRGB(80,200,120),
    acc     = Color3.fromRGB(220,180,60),
}
local COORD_PART_ICONS = {tops="👗", bottoms="👖", shoes="👟", acc="💍"}

local selectedCoordIds = {}  -- 部位ごとに選択


local ag = Instance.new("UIListLayout"); ag.Padding=UDim.new(0,3); ag.Parent=arcanaScroll

-- 右: じゃんけん（技カードありの場合）
local techLabel = Instance.new("TextLabel")
techLabel.Size = UDim2.new(0.48,0,0.07,0)
techLabel.Position = UDim2.new(0.51,0,0.1,0)
techLabel.BackgroundTransparency = 1
techLabel.Text = "じゃんけん"
techLabel.TextColor3 = Color3.fromRGB(255,200,100)
techLabel.TextScaled = true
techLabel.Font = Enum.Font.Gotham
techLabel.Parent = panel

local mpLabel = Instance.new("TextLabel")
mpLabel.Name = "MPLabel"
mpLabel.Size = UDim2.new(0.48,0,0.06,0)
mpLabel.Position = UDim2.new(0.68,0,0.18,0)
mpLabel.BackgroundTransparency = 1
mpLabel.Text = "MP: 0 / 10"
mpLabel.TextColor3 = Color3.fromRGB(100,220,255)
mpLabel.TextScaled = true
mpLabel.Font = Enum.Font.GothamBold
mpLabel.Parent = panel

-- 手ボタン（技カードなし時の直押し）
local handBtnFrame = Instance.new("Frame")
handBtnFrame.Name = "HandBtnFrame"
handBtnFrame.Size = UDim2.new(0.48,0,0.3,0)
handBtnFrame.Position = UDim2.new(0.68,0,0.25,0)
handBtnFrame.BackgroundTransparency = 1
handBtnFrame.Parent = panel

local techScroll = Instance.new("ScrollingFrame")
techScroll.Name = "TechScroll"
techScroll.Size = UDim2.new(0.30,0,0.56,0)
techScroll.Position = UDim2.new(0.68,0,0.25,0)
techScroll.BackgroundColor3 = Color3.fromRGB(10,10,20)
techScroll.BorderSizePixel = 0
techScroll.ScrollBarThickness = 4
techScroll.Visible = false
techScroll.Parent = panel
local tl = Instance.new("UIListLayout"); tl.Padding=UDim.new(0,3); tl.Parent=techScroll

-- セットボタン
local setBtn = Instance.new("TextButton")
setBtn.Name = "SetBtn"
setBtn.Size = UDim2.new(0.5,0,0.08,0)
setBtn.Position = UDim2.new(0.25,0,0.91,0)
setBtn.BackgroundColor3 = Color3.fromRGB(80,40,160)
setBtn.Text = "▶ セットする"
setBtn.TextColor3 = Color3.new(1,1,1)
setBtn.TextScaled = true
setBtn.Font = Enum.Font.GothamBold
setBtn.BorderSizePixel = 0
setBtn.Parent = panel
local sbc = Instance.new("UICorner"); sbc.CornerRadius=UDim.new(0,8); sbc.Parent=setBtn

-- ─── 状態 ───
local selectedArcanaId = nil
local selectedTechId   = nil
local selectedHand     = nil  -- 技カードなし時の手
local arcBtns = {}

local function reset()
    selectedArcanaId = nil
    selectedTechId   = nil
    selectedHand     = nil
    for _, b in ipairs(arcBtns) do
        b.BackgroundColor3 = Color3.fromRGB(30,20,50)
    end
end

-- ─── 手ボタン生成（技カードなし用）───
local hands = {"gu","choki","pa","kakushi"}
local handBtns = {}
for i, h in ipairs(hands) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.22,0,0.85,0)
    btn.Position = UDim2.new((i-1)*0.25,2,0.075,0)
    btn.BackgroundColor3 = Color3.fromRGB(20,20,35)
    btn.Text = HAND_ICON[h]
    btn.TextColor3 = HAND_COLOR[h]
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = handBtnFrame
    local hc = Instance.new("UICorner"); hc.CornerRadius=UDim.new(0,8); hc.Parent=btn
    handBtns[h] = btn

    btn.MouseButton1Click:Connect(function()
        selectedHand = h
        selectedTechId = nil
        for _, b in pairs(handBtns) do
            b.BackgroundColor3 = Color3.fromRGB(20,20,35)
        end
        btn.BackgroundColor3 = HAND_COLOR[h]
    end)
end

-- ─── フェーズ開始 ───
local function openEXPhase(arcanaList, techList, currentMP)
    reset()

    -- アルカナボタン生成
    for _, c in ipairs(arcanaScroll:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
    end
    arcBtns = {}
    for _, arc in ipairs(arcanaList or {}) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,-6,0,52)
        btn.BackgroundColor3 = Color3.fromRGB(30,20,50)
        btn.Text = (arc.icon or "✦").."  "..arc.name
        btn.TextColor3 = Color3.fromRGB(220,220,255)
        btn.TextScaled = true
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = arcanaScroll
        local bc = Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,6); bc.Parent=btn
        table.insert(arcBtns, btn)
        btn.MouseButton1Click:Connect(function()
            selectedArcanaId = arc.id
            for _, b in ipairs(arcBtns) do b.BackgroundColor3 = Color3.fromRGB(30,20,50) end
            btn.BackgroundColor3 = Color3.fromRGB(80,40,160)
        end)
    end
    arcanaScroll.CanvasSize = UDim2.new(0,0,0,#arcanaList*56)

    -- コーデカードをtechListから分離して表示
    for _, c in ipairs(coordScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    selectedCoordIds = {}
    local nonCoordTechs = {}
    for _, tech in ipairs(techList or {}) do
        if tech.effect == "coord" then
            -- コーデカードをcoordScrollに表示
            local part = tech.part or "tops"
            local col = COORD_PART_COLORS[part] or Color3.fromRGB(160,100,200)
            local icon = COORD_PART_ICONS[part] or "✦"
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1,-4,0,52)
            btn.BackgroundColor3 = Color3.fromRGB(25,15,40)
            btn.Text = icon .. "  " .. tech.name
            btn.TextColor3 = col
            btn.TextScaled = true
            btn.Font = Enum.Font.GothamBold
            btn.BorderSizePixel = 0
            btn.Parent = coordScroll
            local bc3 = Instance.new("UICorner"); bc3.CornerRadius=UDim.new(0,6); bc3.Parent=btn

            local techId = tech.id
            local techPart = part
            btn.MouseButton1Click:Connect(function()
                -- トグル選択
                if selectedCoordIds[techPart] == techId then
                    selectedCoordIds[techPart] = nil
                    btn.BackgroundColor3 = Color3.fromRGB(25,15,40)
                else
                    selectedCoordIds[techPart] = techId
                    btn.BackgroundColor3 = col
                    btn.BackgroundTransparency = 0.3
                end
            end)
        else
            table.insert(nonCoordTechs, tech)
        end
    end
    coordScroll.CanvasSize = UDim2.new(0,0,0, math.max(1, #(techList or {}) - #nonCoordTechs) * 56)

    -- 技カードがあるか（コーデ以外）
    local techList = nonCoordTechs
    if techList and #techList > 0 then
        techScroll.Visible = true
        handBtnFrame.Visible = false
        mpLabel.Text = "MP: "..(currentMP or 0).." / 10"

        for _, c in ipairs(techScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for _, tech in ipairs(techList) do
            local canUse = (currentMP or 0) >= tech.cost
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1,-6,0,52)
            btn.BackgroundColor3 = canUse
                and Color3.fromRGB(20,30,20)
                or  Color3.fromRGB(20,20,20)
            btn.Text = HAND_ICON[tech.hand].."  "..tech.name.."  MP"..tech.cost
            btn.TextColor3 = canUse
                and Color3.fromRGB(220,220,100)
                or  Color3.fromRGB(80,80,80)
            btn.TextScaled = true
            btn.Font = Enum.Font.GothamBold
            btn.BorderSizePixel = 0
            btn.Parent = techScroll
            local tc = Instance.new("UICorner"); tc.CornerRadius=UDim.new(0,6); tc.Parent=btn
            if canUse then
                btn.MouseButton1Click:Connect(function()
                    selectedTechId = tech.id
                    selectedHand   = nil
                    for _, c2 in ipairs(techScroll:GetChildren()) do
                        if c2:IsA("TextButton") then
                            c2.BackgroundColor3 = Color3.fromRGB(20,30,20)
                        end
                    end
                    btn.BackgroundColor3 = Color3.fromRGB(40,80,40)
                end)
            end
        end
        techScroll.CanvasSize = UDim2.new(0,0,0,#techList*56)
    else
        -- 技カードなし → 手を直押し
        techScroll.Visible = false
        handBtnFrame.Visible = true
        mpLabel.Text = "手を選んで参加"
    end

    screen.Enabled = true
end

local function closeEXPhase()
    screen.Enabled = false
end

-- セットボタン
setBtn.MouseButton1Click:Connect(function()
    -- 選択されたコーデカードIDリスト
    local coordList = {}
    for part, cid in pairs(selectedCoordIds) do
        table.insert(coordList, {part=part, cardId=cid})
    end
    Remotes.EXSet:FireServer({
        arcanaId  = selectedArcanaId,
        techId    = selectedTechId,
        hand      = selectedHand,
        coordList = coordList,  -- コーデカード選択
    })
    closeEXPhase()
end)

-- サーバーからフェーズ開始通知
local RE_PhaseChanged = Remotes:WaitForChild("PhaseChanged", 15)
if RE_PhaseChanged then
    RE_PhaseChanged.OnClientEvent:Connect(function(data)
        if data.phase == "ex_phase" then
            openEXPhase(data.arcana, data.tech, data.mp)
        end
    end)
end
