-- ============================================
-- GAMEROAD PetAndFossil.lua
-- StarterPlayerScripts / LocalScript型
--
-- ペット育成UI + 化石発掘UI
-- ============================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui", 15)
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_Pet      = Remotes:WaitForChild("PetSystem", 15)

-- キャッシュ
local PetData     = nil
local FossilData  = nil
local PetTypes    = {}
local FossilTypes = {}

-- ============================================
-- UI ヘルパー
-- ============================================
local function makeGui(name, order)
    local sg = Instance.new("ScreenGui")
    sg.Name = name; sg.ResetOnSpawn = false
    sg.DisplayOrder = order or 75
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = PlayerGui
    return sg
end

local function makeFrm(parent, size, pos, col, name)
    local f = Instance.new("Frame")
    f.Size = size; f.Position = pos
    f.BackgroundColor3 = col or Color3.fromRGB(10,10,25)
    f.BorderSizePixel = 0
    if name then f.Name = name end
    f.Parent = parent
    return f
end

local function makeTxt(parent, text, size, pos, col, fontSize, bold)
    local l = Instance.new("TextLabel")
    l.Size = size; l.Position = pos
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = col or Color3.fromRGB(230,230,255)
    l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize = fontSize or 13
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function makeBtn(parent, text, size, pos, bg, fg)
    local b = Instance.new("TextButton")
    b.Size = size; b.Position = pos
    b.BackgroundColor3 = bg or Color3.fromRGB(40,40,80)
    b.TextColor3 = fg or Color3.fromRGB(220,220,255)
    b.Text = text; b.Font = Enum.Font.GothamBold
    b.TextScaled = true; b.BorderSizePixel = 0
    b.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.15,0); c.Parent = b
    return b
end

local function round(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(radius or 0.06, 0)
    c.Parent = parent
end

-- ============================================
-- ペット育成UI
-- ============================================
local function openPetUI()
    for _, c in ipairs(PlayerGui:GetChildren()) do
        if c.Name == "PetGui" then c:Destroy() end
    end

    local sg = makeGui("PetGui", 76)
    local bg = makeFrm(sg, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(5,8,22))
    bg.BackgroundTransparency = 0.05

    -- タイトルバー
    local bar = makeFrm(bg, UDim2.new(1,0,0.08,0), UDim2.new(0,0,0,0), Color3.fromRGB(60,30,100))
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7,0,1,0); title.BackgroundTransparency=1
    title.Text="🐾  ペット育成"; title.TextColor3=Color3.fromRGB(220,180,255)
    title.Font=Enum.Font.GothamBold; title.TextScaled=true; title.Parent=bar

    local closeB = makeBtn(bar,"✕",UDim2.new(0.10,0,0.8,0),UDim2.new(0.89,0,0.1,0),Color3.fromRGB(160,40,40))
    closeB.MouseButton1Click:Connect(function() sg:Destroy() end)

    -- タブ行（飼育中 / 新しく飼う）
    local tabRow = makeFrm(bg, UDim2.new(1,0,0.07,0), UDim2.new(0,0,0.08,0), Color3.fromRGB(20,12,40))
    local tabMine  = makeBtn(tabRow,"🏠 育てているペット",UDim2.new(0.49,0,0.9,0),UDim2.new(0.005,0,0.05,0),Color3.fromRGB(70,35,110))
    local tabAdopt = makeBtn(tabRow,"➕ 新しく迎える",     UDim2.new(0.49,0,0.9,0),UDim2.new(0.505,0,0.05,0),Color3.fromRGB(30,20,60))

    -- コンテンツエリア
    local content = makeFrm(bg, UDim2.new(0.98,0,0.82,0), UDim2.new(0.01,0,0.16,0), Color3.fromRGB(0,0,0,0))
    content.BackgroundTransparency = 1

    -- ── 育てているペット表示 ──
    local function showMyPets()
        content:ClearAllChildren()
        if not PetData or #(PetData.pets or {}) == 0 then
            makeTxt(content,"まだペットがいません。「新しく迎える」から始めよう！",
                UDim2.new(0.9,0,0.15,0),UDim2.new(0.05,0,0.3,0),Color3.fromRGB(180,160,200),14)
            return
        end

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1,0,1,0); scroll.BackgroundTransparency=1
        scroll.ScrollBarThickness=5; scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
        scroll.Parent = content
        local lay = Instance.new("UIListLayout"); lay.Padding=UDim.new(0,8); lay.Parent=scroll
        local pad = Instance.new("UIPadding"); pad.PaddingAll=UDim.new(0,6); pad.Parent=scroll

        for _, pet in ipairs(PetData.pets) do
            local ptype = nil
            for _, pt in ipairs(PetTypes) do if pt.id == pet.petId then ptype=pt; break end end
            if not ptype then continue end

            local card = makeFrm(scroll,UDim2.new(1,0,0,130),UDim2.new(0,0,0,0),Color3.fromRGB(20,12,40))
            round(card, 0.06); card.BackgroundTransparency=0.15

            -- アイコン + 名前
            local icon = makeTxt(card,ptype.icon,UDim2.new(0.15,0,0.5,0),UDim2.new(0.01,0,0.05,0),Color3.fromRGB(255,255,255),40)
            icon.TextXAlignment=Enum.TextXAlignment.Center; icon.TextScaled=true

            local nameL = makeTxt(card,ptype.name,UDim2.new(0.4,0,0.28,0),UDim2.new(0.17,0,0.04,0),Color3.fromRGB(230,210,255),14,true)
            local stageL = makeTxt(card,"【"..getPetStageName(ptype, pet.lv or 1).."】",
                UDim2.new(0.4,0,0.22,0),UDim2.new(0.17,0,0.32,0),Color3.fromRGB(170,150,220),12)

            -- Lvバー
            local lvFrm = makeFrm(card,UDim2.new(0.6,0,0.18,0),UDim2.new(0.17,0,0.55,0),Color3.fromRGB(30,20,50))
            round(lvFrm,0.5)
            local lvFill = makeFrm(lvFrm,UDim2.new((pet.exp or 0)/100,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(120,60,200))
            round(lvFill,0.5)
            makeTxt(lvFrm,string.format("Lv.%d  EXP:%d",pet.lv or 1, math.floor(pet.exp or 0)),
                UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(220,200,255),11,true)
                .TextXAlignment=Enum.TextXAlignment.Center

            -- ステータスバー（空腹度・幸福度）
            local function statBar(label, val, col, yPos)
                makeTxt(card,label,UDim2.new(0.12,0,0.2,0),UDim2.new(0.17,0,yPos,0),Color3.fromRGB(180,170,200),11)
                local bg2 = makeFrm(card,UDim2.new(0.48,0,0.18,0),UDim2.new(0.30,0,yPos+0.01,0),Color3.fromRGB(15,10,30))
                round(bg2,0.5)
                local fill = makeFrm(bg2,UDim2.new(math.max(0,math.min(1,(val or 0)/100)),0,1,0),UDim2.new(0,0,0,0),col)
                round(fill,0.5)
            end
            statBar("🍖空腹", pet.hunger,    Color3.fromRGB(220,150,50),  0.76)
            statBar("😊幸福", pet.happiness, Color3.fromRGB(100,200,120), 0.57)

            -- アクションボタン
            -- ペット名表示（タップで変更）
            local displayName = pet.petName or ptype.name
            local nameBtn = makeBtn(card, "✏ "..displayName,
                UDim2.new(0.38,0,0.24,0), UDim2.new(0.17,0,0.73,0),
                Color3.fromRGB(30,25,55), Color3.fromRGB(200,190,255))
            nameBtn.TextSize = 11

            local feedBtn = makeBtn(card,"🍖 えさ",UDim2.new(0.19,0,0.26,0),UDim2.new(0.79,0,0.05,0),Color3.fromRGB(180,100,20))
            local playBtn = makeBtn(card,"▶ あそぶ",UDim2.new(0.19,0,0.26,0),UDim2.new(0.79,0,0.35,0),Color3.fromRGB(30,120,60))

            local pid = pet.petId
            feedBtn.MouseButton1Click:Connect(function()
                RE_Pet:FireServer({type="feed_pet", petId=pid})
            end)
            playBtn.MouseButton1Click:Connect(function()
                RE_Pet:FireServer({type="play_pet", petId=pid})
            end)

            -- 名前変更（TextBoxを一時的に出す）
            nameBtn.MouseButton1Click:Connect(function()
                local inputFrm = makeFrm(sg, UDim2.new(0.7,0,0.2,0),
                    UDim2.new(0.15,0,0.40,0), Color3.fromRGB(20,15,40))
                round(inputFrm, 0.08); inputFrm.ZIndex = 200

                local title = makeTxt(inputFrm,"ペットに名前をつける",
                    UDim2.new(0.9,0,0.3,0), UDim2.new(0.05,0,0.02,0),
                    Color3.fromRGB(200,190,255), 13, true)
                title.TextXAlignment = Enum.TextXAlignment.Center

                local tb = Instance.new("TextBox")
                tb.Size = UDim2.new(0.88,0,0.3,0)
                tb.Position = UDim2.new(0.06,0,0.33,0)
                tb.BackgroundColor3 = Color3.fromRGB(35,28,60)
                tb.TextColor3 = Color3.fromRGB(230,220,255)
                tb.Font = Enum.Font.Gotham
                tb.TextSize = 14
                tb.PlaceholderText = displayName
                tb.Text = displayName
                tb.MaxVisibleGraphemes = 15
                tb.ZIndex = 201
                tb.Parent = inputFrm
                round(tb, 0.2)

                local confirmBtn = makeBtn(inputFrm, "決定",
                    UDim2.new(0.4,0,0.28,0), UDim2.new(0.05,0,0.68,0),
                    Color3.fromRGB(60,120,60))
                confirmBtn.ZIndex = 201
                local cancelBtn2 = makeBtn(inputFrm, "キャンセル",
                    UDim2.new(0.4,0,0.28,0), UDim2.new(0.55,0,0.68,0),
                    Color3.fromRGB(100,40,40))
                cancelBtn2.ZIndex = 201

                confirmBtn.MouseButton1Click:Connect(function()
                    local newName = tb.Text
                    if #newName > 0 then
                        RE_Pet:FireServer({type="rename_pet", petId=pid, petName=newName})
                        nameBtn.Text = "✏ "..newName
                    end
                    inputFrm:Destroy()
                end)
                cancelBtn2.MouseButton1Click:Connect(function()
                    inputFrm:Destroy()
                end)
            end)
        end
    end

    -- ── 新しく迎える ──
    local function showAdopt()
        content:ClearAllChildren()
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size=UDim2.new(1,0,1,0); scroll.BackgroundTransparency=1
        scroll.ScrollBarThickness=5; scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
        scroll.Parent=content
        local lay=Instance.new("UIListLayout"); lay.Padding=UDim.new(0,8); lay.FillDirection=Enum.FillDirection.Horizontal; lay.Wraps=true; lay.Parent=scroll
        local pad=Instance.new("UIPadding"); pad.PaddingAll=UDim.new(0,6); pad.Parent=scroll

        for _, pt in ipairs(PetTypes) do
            local tile = makeFrm(scroll,UDim2.new(0,140,0,160),UDim2.new(0,0,0,0),Color3.fromRGB(20,12,40))
            round(tile,0.06); tile.BackgroundTransparency=0.15

            local iconL = makeTxt(tile,pt.icon,UDim2.new(1,0,0.4,0),UDim2.new(0,0,0.02,0),Color3.fromRGB(255,255,255),48)
            iconL.TextXAlignment=Enum.TextXAlignment.Center; iconL.TextScaled=true

            makeTxt(tile,pt.name,UDim2.new(0.9,0,0.17,0),UDim2.new(0.05,0,0.43,0),Color3.fromRGB(220,205,255),13,true)
                .TextXAlignment=Enum.TextXAlignment.Center
            local rarCol = {C=Color3.fromRGB(140,140,160),R=Color3.fromRGB(60,130,220),
                SR=Color3.fromRGB(160,60,220),SSR=Color3.fromRGB(220,180,30)}
            makeTxt(tile,pt.rarity,UDim2.new(0.5,0,0.14,0),UDim2.new(0.25,0,0.60,0),rarCol[pt.rarity],12,true)
                .TextXAlignment=Enum.TextXAlignment.Center

            local ab = makeBtn(tile,"迎え入れる",UDim2.new(0.85,0,0.22,0),UDim2.new(0.075,0,0.76,0),Color3.fromRGB(80,40,130))
            local ptId = pt.id
            ab.MouseButton1Click:Connect(function()
                RE_Pet:FireServer({type="adopt_pet", petId=ptId})
            end)
        end
    end

    tabMine.MouseButton1Click:Connect(function()
        tabMine.BackgroundColor3 = Color3.fromRGB(70,35,110)
        tabAdopt.BackgroundColor3 = Color3.fromRGB(30,20,60)
        showMyPets()
    end)
    tabAdopt.MouseButton1Click:Connect(function()
        tabAdopt.BackgroundColor3 = Color3.fromRGB(70,35,110)
        tabMine.BackgroundColor3 = Color3.fromRGB(30,20,60)
        showAdopt()
    end)

    -- データ取得してから表示
    RE_Pet:FireServer({type="get_pet"})
    showMyPets()
end

-- ============================================
-- 化石発掘UI
-- ============================================
local function openDigUI()
    for _, c in ipairs(PlayerGui:GetChildren()) do
        if c.Name == "DigGui" then c:Destroy() end
    end

    local sg = makeGui("DigGui", 77)
    local bg = makeFrm(sg,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(15,10,5))
    bg.BackgroundTransparency=0.05

    -- タイトルバー
    local bar = makeFrm(bg,UDim2.new(1,0,0.08,0),UDim2.new(0,0,0,0),Color3.fromRGB(80,50,20))
    local tl = Instance.new("TextLabel"); tl.Size=UDim2.new(0.7,0,1,0); tl.BackgroundTransparency=1
    tl.Text="⛏  化石発掘"; tl.TextColor3=Color3.fromRGB(255,210,140)
    tl.Font=Enum.Font.GothamBold; tl.TextScaled=true; tl.Parent=bar
    local cb = makeBtn(bar,"✕",UDim2.new(0.10,0,0.8,0),UDim2.new(0.89,0,0.1,0),Color3.fromRGB(160,40,40))
    cb.MouseButton1Click:Connect(function() sg:Destroy() end)

    -- 発掘フィールド（地面イメージ）
    local field = makeFrm(bg,UDim2.new(0.96,0,0.40,0),UDim2.new(0.02,0,0.10,0),Color3.fromRGB(60,40,20))
    round(field, 0.04); field.BackgroundTransparency=0.2

    -- 地面テクスチャ的な装飾（ドットをランダム配置）
    local rng = Random.new()
    for i = 1, 20 do
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0,rng:NextInteger(4,12),0,rng:NextInteger(4,12))
        dot.Position = UDim2.new(rng:NextNumber(0.02,0.95),0,rng:NextNumber(0.05,0.90),0)
        dot.BackgroundColor3 = Color3.fromRGB(rng:NextInteger(40,90),rng:NextInteger(30,70),rng:NextInteger(10,40))
        dot.BackgroundTransparency = rng:NextNumber(0.2,0.7)
        dot.BorderSizePixel=0; dot.Parent=field
        local rc = Instance.new("UICorner"); rc.CornerRadius=UDim.new(0.5,0); rc.Parent=dot
    end

    -- 発掘ボタン（大きなツルハシ）
    local digBtn = makeBtn(field,"⛏ 発掘する！",
        UDim2.new(0.4,0,0.4,0),UDim2.new(0.30,0,0.30,0),Color3.fromRGB(120,70,20))
    digBtn.TextColor3=Color3.fromRGB(255,220,150); digBtn.ZIndex=3

    -- エネルギー表示
    local energyLabel = makeTxt(bg,"⚡? / 10  次のチャージ待ち中...",
        UDim2.new(0.65,0,0.06,0),UDim2.new(0.02,0,0.51,0),Color3.fromRGB(255,220,100),13,true)
    local totalLabel = makeTxt(bg,"累計発掘: 0回",
        UDim2.new(0.5,0,0.06,0),UDim2.new(0.52,0,0.51,0),Color3.fromRGB(180,160,120),12)

    -- 結果表示エリア
    local resultArea = makeFrm(bg,UDim2.new(0.96,0,0.22,0),UDim2.new(0.02,0,0.58,0),Color3.fromRGB(10,8,5))
    round(resultArea, 0.05); resultArea.BackgroundTransparency=0.3

    local resultLabel = makeTxt(resultArea,"発掘ボタンを押して化石を掘り出そう！",
        UDim2.new(0.9,0,0.8,0),UDim2.new(0.05,0,0.1,0),Color3.fromRGB(180,160,120),13)
    resultLabel.TextXAlignment=Enum.TextXAlignment.Center

    -- コレクション表示
    local collScroll = Instance.new("ScrollingFrame")
    collScroll.Size=UDim2.new(0.96,0,0.18,0)
    collScroll.Position=UDim2.new(0.02,0,0.81,0)
    collScroll.BackgroundTransparency=1
    collScroll.ScrollBarThickness=4
    collScroll.ScrollingDirection=Enum.ScrollingDirection.X
    collScroll.CanvasSize=UDim2.new(0,0,0,0)
    collScroll.AutomaticCanvasSize=Enum.AutomaticSize.X
    collScroll.Parent=bg
    local cLay=Instance.new("UIListLayout"); cLay.FillDirection=Enum.FillDirection.Horizontal; cLay.Padding=UDim.new(0,6); cLay.Parent=collScroll

    local function refreshCollection()
        collScroll:ClearAllChildren()
        local lay2=Instance.new("UIListLayout"); lay2.FillDirection=Enum.FillDirection.Horizontal; lay2.Padding=UDim.new(0,6); lay2.Parent=collScroll
        if not FossilData then return end
        for _, ft in ipairs(FossilTypes) do
            local count = (FossilData.collection and FossilData.collection[ft.id]) or 0
            if count > 0 then
                local tile = makeFrm(collScroll,UDim2.new(0,70,0,60),UDim2.new(0,0,0,0),Color3.fromRGB(25,18,10))
                round(tile,0.1)
                local ic = makeTxt(tile,ft.icon,UDim2.new(1,0,0.55,0),UDim2.new(0,0,0,0),Color3.fromRGB(255,255,255),24)
                ic.TextXAlignment=Enum.TextXAlignment.Center; ic.TextScaled=true
                makeTxt(tile,"×"..count,UDim2.new(1,0,0.35,0),UDim2.new(0,0,0.60,0),Color3.fromRGB(220,200,160),12,true)
                    .TextXAlignment=Enum.TextXAlignment.Center
            end
        end
    end

    -- 発掘アニメーション
    local digging = false
    digBtn.MouseButton1Click:Connect(function()
        if digging then return end
        digging = true
        -- ツルハシを振るアニメ
        for i = 1, 3 do
            TweenService:Create(digBtn,TweenInfo.new(0.1),{Rotation=15}):Play()
            task.wait(0.1)
            TweenService:Create(digBtn,TweenInfo.new(0.1),{Rotation=-15}):Play()
            task.wait(0.1)
        end
        TweenService:Create(digBtn,TweenInfo.new(0.1),{Rotation=0}):Play()
        RE_Pet:FireServer({type="dig"})
    end)

    -- データ更新関数
    local function updateUI()
        if FossilData then
            local status = FossilData.energyStatus or
                string.format("⚡%d/12", FossilData.energy or 0)
            energyLabel.Text = status .. "  （2時間で+1、1日最大12回）"
            totalLabel.Text  = string.format("累計発掘: %d回", FossilData.totalDigs or 0)
            refreshCollection()
        end
    end

    RE_Pet:FireServer({type="get_fossil"})

    -- 恐竜骨格進捗バー
    local boneBar = makeFrm(bg, UDim2.new(0.96,0,0.07,0), UDim2.new(0.02,0,0.73,0),
        Color3.fromRGB(30,20,10))
    round(boneBar, 0.3); boneBar.BackgroundTransparency=0.3
    makeTxt(boneBar, "🦕 恐竜骨格:",
        UDim2.new(0.22,0,1,0), UDim2.new(0,0,0,0),
        Color3.fromRGB(200,180,140), 12, true)
    local BONE_ICONS = {head="💀",spine="🦴",arm="🦾",leg="🦵",tail="〰"}
    local boneLabels = {}
    for i, part in ipairs({"head","spine","arm","leg","tail"}) do
        local lbl = makeTxt(boneBar, BONE_ICONS[part],
            UDim2.new(0.1,0,0.9,0), UDim2.new(0.22+i*0.13,0,0.05,0),
            Color3.fromRGB(80,70,60), 18)
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.TextScaled = true
        boneLabels[part] = lbl
    end

    -- 課金ボタン行
    local shopRow = makeFrm(bg, UDim2.new(0.96,0,0.09,0), UDim2.new(0.02,0,0.89,0),
        Color3.fromRGB(0,0,0,0))
    shopRow.BackgroundTransparency = 1

    local speedBtn = makeBtn(shopRow, "⚡ 成長2倍 24h
[Robux]",
        UDim2.new(0.47,0,0.9,0), UDim2.new(0.01,0,0.05,0),
        Color3.fromRGB(30,80,160))
    speedBtn.TextSize = 11
    local energyBtn = makeBtn(shopRow, "🔋 エネルギー+5
[Robux]",
        UDim2.new(0.47,0,0.9,0), UDim2.new(0.52,0,0.05,0),
        Color3.fromRGB(80,50,10))
    energyBtn.TextSize = 11

    -- 課金ボタンはMarketplaceService経由（DevProduct IDは後で設定）
    speedBtn.MouseButton1Click:Connect(function()
        local mps = game:GetService("MarketplaceService")
        local DEV_PRODUCT_SPEEDUP = 1111116   -- TODO: 実際のIDに変更
        pcall(function()
            mps:PromptProductPurchase(LocalPlayer, DEV_PRODUCT_SPEEDUP)
        end)
    end)
    energyBtn.MouseButton1Click:Connect(function()
        local mps = game:GetService("MarketplaceService")
        local DEV_PRODUCT_ENERGY = 1111117   -- TODO: 実際のIDに変更
        pcall(function()
            mps:PromptProductPurchase(LocalPlayer, DEV_PRODUCT_ENERGY)
        end)
    end)

    local function updateBoneBar(dinoBones)
        if not dinoBones then return end
        for part, lbl in pairs(boneLabels) do
            lbl.TextColor3 = dinoBones[part]
                and Color3.fromRGB(255,220,80)   -- 収集済み = 金色
                or  Color3.fromRGB(60,50,40)     -- 未収集 = 暗い
        end
    end

    RE_Pet:FireServer({type="get_pet"})

    -- イベント受信
    RE_Pet.OnClientEvent:Connect(function(d)
        if d.type == "fossil_data" then
            FossilData  = d.fossilData
            FossilTypes = d.fossilTypes or FossilTypes
            updateUI()

        elseif d.type == "dig_result" then
            digging = false
            FossilData = FossilData or {}
            FossilData.energy       = d.energy
            FossilData.energyStatus = d.energyStatus
            FossilData.totalDigs    = d.totalDigs
            FossilData.collection = FossilData.collection or {}
            FossilData.collection[d.fossil.id] = (FossilData.collection[d.fossil.id] or 0) + 1

            -- 発見演出
            local rarColors = {C=Color3.fromRGB(160,160,180),R=Color3.fromRGB(60,130,220),
                SR=Color3.fromRGB(160,60,220),SSR=Color3.fromRGB(220,180,30)}
            local fossil = d.fossil
            resultLabel.Text = string.format("%s  %s  [%s]  発見！",
                fossil.icon, fossil.name, fossil.rarity)
            resultLabel.TextColor3 = rarColors[fossil.rarity] or Color3.fromRGB(200,200,200)

            -- SR以上はフラッシュ
            if fossil.rarity == "SR" or fossil.rarity == "SSR" then
                local flash = Instance.new("Frame")
                flash.Size=UDim2.new(1,0,1,0); flash.BackgroundColor3=rarColors[fossil.rarity]
                flash.BackgroundTransparency=0.6; flash.ZIndex=200; flash.Parent=sg
                TweenService:Create(flash,TweenInfo.new(0.5),{BackgroundTransparency=1}):Play()
                task.delay(0.6,function() flash:Destroy() end)
            end

            updateUI()

            if d.extraMsg then
                task.delay(1, function()
                    resultLabel.Text = d.extraMsg
                    resultLabel.TextColor3 = Color3.fromRGB(100,220,100)
                end)
            end

        elseif d.type == "dig_fail" then
            digging = false
            resultLabel.Text = d.message or "エネルギー不足！"
            resultLabel.TextColor3 = Color3.fromRGB(220,100,100)

        elseif d.type == "bone_collected" then
            updateBoneBar(d.dinoBones)
            if d.restored then
                -- 恐竜復元演出
                resultLabel.Text = "🦖 恐竜が復元されました！ペット＆カードスキン解放！"
                resultLabel.TextColor3 = Color3.fromRGB(100,255,150)
                local flash = Instance.new("Frame")
                flash.Size=UDim2.new(1,0,1,0); flash.BackgroundColor3=Color3.fromRGB(80,200,100)
                flash.BackgroundTransparency=0.5; flash.ZIndex=200; flash.Parent=sg
                TweenService:Create(flash,TweenInfo.new(0.8),{BackgroundTransparency=1}):Play()
                task.delay(0.9,function() flash:Destroy() end)
            end

        elseif d.type == "speedup_active" then
            resultLabel.Text = d.message or "成長2倍！"
            resultLabel.TextColor3 = Color3.fromRGB(100,180,255)
            speedBtn.BackgroundColor3 = Color3.fromRGB(20,100,200)
            speedBtn.Text = "⚡ 2倍加速中！"

        elseif d.type == "energy_recharged" then
            if FossilData then FossilData.energy = d.energy end
            updateUI()
            resultLabel.Text = d.message or "エネルギー補充！"
            resultLabel.TextColor3 = Color3.fromRGB(255,200,80)

        elseif d.type == "pet_data" then
            PetData   = d.petData
            PetTypes  = d.petTypes or PetTypes
            -- 骨格進捗バーも更新
            if PetData and PetData.dinoBones then
                updateBoneBar(PetData.dinoBones)
            end
        end
    end)
end

-- ============================================
-- ステージ名取得（クライアント側ヘルパー）
-- ============================================
function getPetStageName(ptype, lv)
    local stages = ptype.stages or {"成長中"}
    local steps = math.max(1, (ptype.maxLv or 10) / #stages)
    local idx = math.min(#stages, math.ceil(lv / steps))
    return stages[idx]
end

-- ============================================
-- グローバル公開
-- ============================================
_G.OpenPetUI  = openPetUI
_G.OpenDigUI  = openDigUI

-- サーバーからの通知受信（きずな画面外でも機能）
RE_Pet.OnClientEvent:Connect(function(d)
    if d.type == "pet_data" then
        PetData  = d.petData
        PetTypes = d.petTypes or PetTypes
    elseif d.type == "fossil_data" then
        FossilData  = d.fossilData
        FossilTypes = d.fossilTypes or FossilTypes
    elseif d.type == "skin_unlocked" then
        -- スキン解放通知（ロビーでトースト表示）
        if _G.ShowToast then _G.ShowToast(d.message, 5) end
    elseif d.type == "pet_adopted" then
        if _G.ShowToast then _G.ShowToast(d.message, 4) end
    end
end)

print("OK PetAndFossil.lua loaded")
