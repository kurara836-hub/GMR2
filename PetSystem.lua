-- ============================================
-- GAMEROAD PetSystem.lua
-- ServerScriptService / Script型
--
-- 放置ペット育成 + 化石発掘
-- 相方が世話→プレイヤーも干渉できる
-- 育てたペットはスキン解放
-- ============================================

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes   = ReplicatedStorage:WaitForChild("Remotes", 15)
local RE_Pet    = Remotes:WaitForChild("PetSystem", 15)

local PetDS    = DataStoreService:GetDataStore("PetSystem_v1")
local FossilDS = DataStoreService:GetDataStore("FossilDigging_v1")

-- ============================================
-- ペット定義（相方が育てる）
-- ============================================
local PET_TYPES = {
    { id="kuwa",   name="クワガタ",   icon="🦌", maxLv=10, baseGrowth=1.0,
      unlockSkin="partner_kuwa",   rarity="R",
      stages={"卵","幼虫","サナギ","成虫","王者"} },
    { id="kabu",   name="カブトムシ", icon="🪲", maxLv=10, baseGrowth=1.2,
      unlockSkin="partner_kabu",   rarity="R",
      stages={"卵","幼虫","サナギ","成虫","王者"} },
    { id="dino",   name="恐竜",       icon="🦖", maxLv=15, baseGrowth=0.6,
      unlockSkin="partner_dino",   rarity="SR",
      stages={"化石","卵","子供","若竜","古代竜","王竜"} },
    { id="butterfly", name="ちょうちょ", icon="🦋", maxLv=8,  baseGrowth=1.5,
      unlockSkin="partner_butterfly", rarity="C",
      stages={"卵","毛虫","サナギ","成虫"} },
    { id="cat",    name="猫",         icon="🐱", maxLv=10, baseGrowth=1.0,
      unlockSkin="partner_cat",    rarity="R",
      stages={"子猫","元気","気まぐれ","大人","王様猫"} },
    { id="dog",    name="犬",         icon="🐶", maxLv=10, baseGrowth=1.3,
      unlockSkin="partner_dog",    rarity="R",
      stages={"子犬","やんちゃ","訓練中","番犬","忠犬"} },
    { id="raptor", name="猛禽類",     icon="🦅", maxLv=12, baseGrowth=0.8,
      unlockSkin="partner_raptor", rarity="SR",
      stages={"雛","巣立ち","狩人","王鷹","神鷹"} },
    { id="flower", name="お花",       icon="🌸", maxLv=8,  baseGrowth=1.8,
      unlockSkin="partner_flower", rarity="C",
      stages={"種","芽","つぼみ","満開","枯れぬ花"} },
}

local PET_MAP = {}
for _, p in ipairs(PET_TYPES) do PET_MAP[p.id] = p end

-- ============================================
-- 化石タイプ（発掘で出る）
-- ============================================
-- 恐竜骨部位（5部位コンプで復元→恐竜ペット獲得）
local DINO_BONES = {
    { id="bone_head",  name="恐竜の頭骨",  icon="💀", part="head"  },
    { id="bone_spine", name="恐竜の脊椎",  icon="🦴", part="spine" },
    { id="bone_arm",   name="恐竜の前肢",  icon="🦾", part="arm"   },
    { id="bone_leg",   name="恐竜の後肢",  icon="🦵", part="leg"   },
    { id="bone_tail",  name="恐竜の尻尾骨",icon="〰", part="tail"  },
}
local DINO_BONE_PARTS = {"head","spine","arm","leg","tail"}

local FOSSIL_TYPES = {
    { id="trilobite",  name="三葉虫",      icon="🦐", rarity="C",   gemValue=5  },
    { id="ammonite",   name="アンモナイト",icon="🌀", rarity="C",   gemValue=8  },
    { id="fish",       name="古代魚",      icon="🐟", rarity="R",   gemValue=15 },
    { id="plant",      name="化石植物",    icon="🌿", rarity="R",   gemValue=12 },
    { id="raptor_claw",name="猛禽の爪",    icon="🦅", rarity="SR",  gemValue=30 },
    { id="t_rex",      name="ティラノの歯",icon="🦷", rarity="SR",  gemValue=35 },
    { id="dino_egg",   name="恐竜の卵",    icon="🥚", rarity="SSR", gemValue=80,
      unlockPet="dino" },
    -- 恐竜骨部位（各R相当）
    { id="bone_head",  name="恐竜の頭骨",  icon="💀", rarity="R",   gemValue=20, isBone=true, part="head"  },
    { id="bone_spine", name="恐竜の脊椎",  icon="🦴", rarity="R",   gemValue=18, isBone=true, part="spine" },
    { id="bone_arm",   name="恐竜の前肢",  icon="🦾", rarity="SR",  gemValue=25, isBone=true, part="arm"   },
    { id="bone_leg",   name="恐竜の後肢",  icon="🦵", rarity="SR",  gemValue=25, isBone=true, part="leg"   },
    { id="bone_tail",  name="恐竜の尻尾骨",icon="〰", rarity="R",   gemValue=22, isBone=true, part="tail"  },
}

local FOSSIL_WEIGHTS = {C=60, R=30, SR=9, SSR=1}

local function rollFossil()
    local r = math.random(100)
    local rarity = r <= 1 and "SSR" or r <= 10 and "SR" or r <= 40 and "R" or "C"
    local pool = {}
    for _, f in ipairs(FOSSIL_TYPES) do
        if f.rarity == rarity then table.insert(pool, f) end
    end
    if #pool == 0 then return FOSSIL_TYPES[1] end
    return pool[math.random(#pool)]
end

-- ============================================
-- DataStore読み書き
-- ============================================
local PetCache    = {}
local FossilCache = {}

local function loadPet(userId)
    if PetCache[userId] then return PetCache[userId] end
    local ok, val = pcall(function() return PetDS:GetAsync("pet_"..userId) end)
    local data = (ok and val) or {
        pets     = {},   -- { petId, lv, exp, hunger, happiness, lastUpdated, adoptedAt, petName }
        active   = nil,  -- 現在メインで育てているペットID
        unlocked = {},   -- 解放済みカードスキンID（GachaSystem.ownedと統合予定）
        -- 恐竜骨部位収集
        dinoBones = { head=false, spine=false, arm=false, leg=false, tail=false },
        dinoRestored = false,
    }
    PetCache[userId] = data
    return data
end

local function savePet(userId)
    local d = PetCache[userId]
    if not d then return end
    pcall(function() PetDS:SetAsync("pet_"..userId, d) end)
end

local function loadFossil(userId)
    if FossilCache[userId] then return FossilCache[userId] end
    local ok, val = pcall(function() return FossilDS:GetAsync("fossil_"..userId) end)
    local data = (ok and val) or {
        collection   = {},   -- { fossilId: count }
        lastDigAt    = 0,
        totalDigs    = 0,
        energy       = 1,    -- 発掘エネルギー（最大12、2時間で1チャージ）
        lastEnergyAt = os.time(),
        dailyDigs    = {},   -- { "2026-03-24": 回数 } 1日1回が基本
        -- 時短課金フラグ
        speedUpUntil = 0,    -- Unixタイム、この時間まで成長2倍
    }
    FossilCache[userId] = data
    return data
end

local function saveFossil(userId)
    local d = FossilCache[userId]
    if not d then return end
    pcall(function() FossilDS:SetAsync("fossil_"..userId, d) end)
end

-- ============================================
-- ペット成長ロジック
-- ============================================
local EXP_PER_LV = 100  -- Lv1→2に必要なEXP基準

local function calcPetLv(exp, maxLv)
    local lv = 1
    local required = EXP_PER_LV
    while exp >= required and lv < maxLv do
        exp = exp - required
        lv = lv + 1
        required = EXP_PER_LV * lv  -- Lvが上がるほど必要EXP増加
    end
    return lv, exp
end

local function getPetStage(petType, lv)
    local stages = PET_MAP[petType] and PET_MAP[petType].stages or {"成長中"}
    local stepsPerStage = math.max(1, (PET_MAP[petType] and PET_MAP[petType].maxLv or 10) / #stages)
    local stageIdx = math.min(#stages, math.ceil(lv / stepsPerStage))
    return stages[stageIdx]
end

-- 時間経過による自動成長（相方が世話をしているイメージ）
local function applyAutoGrowth(petData)
    local now = os.time()
    for _, pet in ipairs(petData.pets) do
        local ptype = PET_MAP[pet.petId]
        if ptype then
            -- 最終更新から経過時間（分）×成長率でEXP付与
            local elapsed = math.floor((now - (pet.lastUpdated or now)) / 60)
            if elapsed > 0 then
                local hungerPenalty = (pet.hunger or 100) > 30 and 1.0 or 0.5
                -- 時短課金（成長2倍）
                local speedMult = 1.0
                local fd2 = FossilCache[userId]
                if fd2 and (fd2.speedUpUntil or 0) > now then
                    speedMult = 2.0
                end
                local growth = elapsed * ptype.baseGrowth * hungerPenalty * speedMult
                pet.exp = (pet.exp or 0) + growth
                pet.hunger = math.max(0, (pet.hunger or 100) - elapsed * 0.5)
                pet.happiness = math.max(0, (pet.happiness or 100) - elapsed * 0.2)
                -- Lvアップチェック
                local newLv, newExp = calcPetLv(pet.exp, ptype.maxLv)
                pet.lv  = newLv
                pet.exp = newExp
                pet.lastUpdated = now
            end
        end
    end
end

-- ============================================
-- 発掘エネルギー回復
-- ============================================
local function recoverEnergy(fossilData)
    local now = os.time()
    local CHARGE_SECS = 7200  -- 2時間で1チャージ（1日=12チャージ）
    local MAX_ENERGY  = 12    -- 最大12個（1日分）
    local elapsed = math.floor((now - (fossilData.lastEnergyAt or now)) / CHARGE_SECS)
    if elapsed > 0 then
        fossilData.energy = math.min(MAX_ENERGY, (fossilData.energy or 0) + elapsed)
        fossilData.lastEnergyAt = now - ((now - (fossilData.lastEnergyAt or now)) % CHARGE_SECS)
    end
end

-- 今日の残り発掘回数チェック（1日1回が基本、課金で追加可能）
-- 現在のエネルギー状況テキスト（クライアント表示用）
local function getEnergyStatus(fossilData)
    local e = fossilData.energy or 0
    if e >= 12 then
        return "⚡12/12  ✨ 1回無料発掘できます！"
    end
    -- 次のチャージまで何分か
    local now = os.time()
    local nextIn = 7200 - ((now - (fossilData.lastEnergyAt or now)) % 7200)
    return string.format("⚡%d/12  次チャージ: %d分後", e, math.ceil(nextIn/60))
end

-- ============================================
-- Remote受信
-- ============================================
RE_Pet.OnServerEvent:Connect(function(player, data)
    if not data then return end
    local uid = player.UserId

    -- ── ペット関連 ──────────────────────────
    if data.type == "get_pet" then
        local pd = loadPet(uid)
        applyAutoGrowth(pd)
        savePet(uid)
        RE_Pet:FireClient(player, {type="pet_data", petData=pd, petTypes=PET_TYPES})

    elseif data.type == "adopt_pet" then
        local petId = data.petId
        if not PET_MAP[petId] then return end
        local pd = loadPet(uid)
        -- 既に同じペットを飼っているか確認
        for _, p in ipairs(pd.pets) do
            if p.petId == petId then
                RE_Pet:FireClient(player, {type="error", message="すでにそのペットを飼っています"})
                return
            end
        end
        local newPet = {
            petId      = petId,
            lv         = 1,
            exp        = 0,
            hunger     = 100,
            happiness  = 100,
            lastUpdated = os.time(),
            adoptedAt  = os.time(),
        }
        table.insert(pd.pets, newPet)
        if not pd.active then pd.active = petId end
        savePet(uid)
        RE_Pet:FireClient(player, {type="pet_adopted", pet=newPet,
            message=string.format("%sを相方が迎え入れました！", PET_MAP[petId].name)})

    elseif data.type == "feed_pet" then
        local petId = data.petId
        local pd = loadPet(uid)
        applyAutoGrowth(pd)
        for _, p in ipairs(pd.pets) do
            if p.petId == petId then
                p.hunger    = math.min(100, (p.hunger or 0) + 30)
                p.happiness = math.min(100, (p.happiness or 0) + 10)
                p.exp       = (p.exp or 0) + 5
                local ptype = PET_MAP[petId]
                local newLv, newExp = calcPetLv(p.exp, ptype and ptype.maxLv or 10)
                local prevLv = p.lv
                p.lv = newLv; p.exp = newExp
                savePet(uid)
                RE_Pet:FireClient(player, {
                    type      = "feed_result",
                    petId     = petId,
                    hunger    = p.hunger,
                    happiness = p.happiness,
                    lv        = p.lv,
                    lvUp      = (newLv > prevLv),
                })
                -- Lvアップでスキン解放チェック
                if newLv > prevLv and ptype and newLv >= ptype.maxLv then
                    if ptype.unlockSkin and not pd.unlocked[ptype.unlockSkin] then
                        pd.unlocked[ptype.unlockSkin] = true
                        savePet(uid)
                        RE_Pet:FireClient(player, {
                            type    = "skin_unlocked",
                            skinId  = ptype.unlockSkin,
                            petName = ptype.name,
                            message = string.format("✦ %sを育て上げた！相方スキン「%s」解放！",
                                ptype.name, ptype.unlockSkin)
                        })
                    end
                end
                break
            end
        end

    elseif data.type == "rename_pet" then
        local petId  = data.petId
        local newName = (data.petName or ""):sub(1, 15):gsub("[<>]","")  -- 最大15文字
        if #newName < 1 then return end
        local pd = loadPet(uid)
        for _, p in ipairs(pd.pets) do
            if p.petId == petId then
                p.petName = newName
                savePet(uid)
                RE_Pet:FireClient(player, {type="rename_result", petId=petId, petName=newName})
                break
            end
        end

    elseif data.type == "play_pet" then
        local petId = data.petId
        local pd = loadPet(uid)
        applyAutoGrowth(pd)
        for _, p in ipairs(pd.pets) do
            if p.petId == petId then
                p.happiness = math.min(100, (p.happiness or 0) + 20)
                p.exp       = (p.exp or 0) + 8
                local ptype = PET_MAP[petId]
                local newLv, newExp = calcPetLv(p.exp, ptype and ptype.maxLv or 10)
                p.lv = newLv; p.exp = newExp
                savePet(uid)
                RE_Pet:FireClient(player, {
                    type="play_result", petId=petId,
                    happiness=p.happiness, lv=p.lv
                })
                break
            end
        end

    -- ── 化石発掘 ──────────────────────────
    elseif data.type == "get_fossil" then
        local fd = loadFossil(uid)
        recoverEnergy(fd)
        saveFossil(uid)
        RE_Pet:FireClient(player, {type="fossil_data", fossilData=fd, fossilTypes=FOSSIL_TYPES})

    elseif data.type == "dig" then
        local fd = loadFossil(uid)
        recoverEnergy(fd)
        -- エネルギーチェック（1時間で1チャージ、最大10蓄積）
        recoverEnergy(fd)
        if (fd.energy or 0) <= 0 then
            RE_Pet:FireClient(player, {type="dig_fail",
                message="エネルギー切れ！2時間に1回チャージ（1日12個まで）",
                energyStatus = getEnergyStatus(fd)})
            return
        end
        fd.energy = (fd.energy or 1) - 1
        fd.totalDigs = (fd.totalDigs or 0) + 1
        fd.lastDigAt = os.time()
        local found = rollFossil()
        fd.collection = fd.collection or {}
        fd.collection[found.id] = (fd.collection[found.id] or 0) + 1
        saveFossil(uid)

        -- 骨部位収集チェック
        local extraMsg = nil
        if found.isBone and found.part then
            local pd = loadPet(uid)
            pd.dinoBones = pd.dinoBones or {head=false,spine=false,arm=false,leg=false,tail=false}
            if not pd.dinoBones[found.part] then
                pd.dinoBones[found.part] = true
                extraMsg = string.format("🦴 恐竜の%sを発見！残り部位を集めよう！", found.name:gsub("恐竜の",""))
                -- 5部位コンプ → 恐竜復元
                local allFound = pd.dinoBones.head and pd.dinoBones.spine and
                                 pd.dinoBones.arm  and pd.dinoBones.leg   and pd.dinoBones.tail
                if allFound and not pd.dinoRestored then
                    pd.dinoRestored = true
                    -- 恐竜ペット追加（まだいなければ）
                    local hasDino = false
                    for _, p in ipairs(pd.pets) do
                        if p.petId == "dino" then hasDino=true; break end
                    end
                    if not hasDino then
                        table.insert(pd.pets, {
                            petId="dino", lv=1, exp=0, hunger=100, happiness=100,
                            lastUpdated=os.time(), adoptedAt=os.time(),
                            petName="復元恐竜"
                        })
                    end
                    -- 恐竜復元カードスキンも解放
                    pd.unlocked["card_dino_skin"] = true
                    extraMsg = "🦖✦ 恐竜の全骨格が揃った！復元完了！恐竜ペット＆カードスキン解放！"
                end
                savePet(uid)
                RE_Pet:FireClient(player, {
                    type     = "bone_collected",
                    part     = found.part,
                    dinoBones = pd.dinoBones,
                    restored = allFound and pd.dinoRestored or false,
                })
            end
        end

        -- 恐竜の卵→dinoペット開始（骨復元とは別経路）
        if found.unlockPet and not found.isBone then
            local pd = loadPet(uid)
            local alreadyHas = false
            for _, p in ipairs(pd.pets) do
                if p.petId == found.unlockPet then alreadyHas=true; break end
            end
            if not alreadyHas then
                table.insert(pd.pets, {
                    petId="dino", lv=1, exp=0, hunger=100, happiness=100,
                    lastUpdated=os.time(), adoptedAt=os.time(), petName="恐竜"
                })
                savePet(uid)
                extraMsg = "🥚 恐竜の卵を発見！相方が孵化の準備を始めました！"
            end
        end

        saveFossil(uid)
        RE_Pet:FireClient(player, {
            type         = "dig_result",
            fossil       = found,
            energy       = fd.energy,
            energyStatus = getEnergyStatus(fd),
            totalDigs    = fd.totalDigs,
            extraMsg     = extraMsg,
        })

    -- 課金: 時短加速（DevProduct→GachaSystem ProcessReceiptで verified=true付きで呼ぶ）
    elseif data.type == "purchase_speedup" then
        if not data.verified then return end
        local fd = loadFossil(uid)
        fd.speedUpUntil = os.time() + 86400
        saveFossil(uid)
        RE_Pet:FireClient(player, {type="speedup_active",
            message="✦ 24時間 成長2倍！"})

    elseif data.type == "purchase_energy" then
        if not data.verified then return end
        local fd = loadFossil(uid)
        -- 今日の追加発掘権を付与（+3回）
        fd.extraDigsToday = (fd.extraDigsToday or 0) + 3
        saveFossil(uid)
        local todayLeft = (1 + fd.extraDigsToday) - getTodayDigCount(fd)
        RE_Pet:FireClient(player, {type="energy_recharged",
            energy=fd.energy, todayLeft=todayLeft,
            message=string.format("⛏ 今日の発掘回数+3！（残り%d回）", todayLeft)})
    end
end)

-- 5分ごとにオートセーブ
task.spawn(function()
    while true do
        task.wait(300)
        for uid, _ in pairs(PetCache) do
            local pd = PetCache[uid]
            if pd then
                applyAutoGrowth(pd)
                savePet(uid)
            end
        end
        for uid, _ in pairs(FossilCache) do
            saveFossil(uid)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local uid = player.UserId
    savePet(uid)
    saveFossil(uid)
    PetCache[uid]    = nil
    FossilCache[uid] = nil
end)

print("OK PetSystem.lua loaded")
