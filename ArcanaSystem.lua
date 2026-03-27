-- ============================================
-- GAMEROAD Arcana System (Lua)
-- 全22枚完全実装版（v5 dinosept_v5.html準拠）
-- ============================================

local ArcanaSystem = {}

-- ============================================
-- アルカナデータ（22枚）
-- ============================================
ArcanaSystem.ARCANA_DATA = {

    -- 0: 原初【エオ】
    {n=0, name="原初【エオ】", icon="🌑",
        posDesc="自ロードを手札に戻し山から新たに出す",
        negDesc="指定相手のロードを0にする",
        posEffect = function(gs, u, tgt)
            local rd = gs.road[u.id]
            if not rd then return end
            table.insert(u.hand, rd)
            gs.road[u.id] = #u._deck > 0 and table.remove(u._deck, 1) or nil
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            gs.roadOverride = gs.roadOverride or {}
            gs.roadOverride[tgt.id] = 0
        end,
    },

    -- 1: 魔術師
    {n=1, name="魔術師", icon="🎩",
        posDesc="+1",
        negDesc="相手シールドを表にし、そのランク以下のチップを全破壊",
        posEffect = function(gs, u, tgt)
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + 1
        end,
        negEffect = function(gs, u, tgt)
            if not tgt or #tgt.shields == 0 then return end
            local sh = tgt.shields[1]
            local limit = sh.rank
            local newChips = {}
            for _, c in ipairs(tgt.chips) do
                if c.rank > limit then table.insert(newChips, c) end
            end
            tgt.chips = newChips
        end,
    },

    -- 2: 女教皇
    {n=2, name="女教皇", icon="📖",
        posDesc="+2",
        negDesc="相手の手札1枚を山の底へ",
        posEffect = function(gs, u, tgt)
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + 2
        end,
        negEffect = function(gs, u, tgt)
            if not tgt or #tgt.hand == 0 then return end
            local c = table.remove(tgt.hand, 1)
            table.insert(tgt._deck, c)
        end,
    },

    -- 3: 女帝
    {n=3, name="女帝", icon="👑",
        posDesc="山から3枚見て1枚手札・1枚チップ・1枚山底へ",
        negDesc="相手手札1捨て1引き。チップ3以上なら発掘リヴァイブ",
        posEffect = function(gs, u, tgt)
            local draw3 = {}
            for i = 1, 3 do
                if #u._deck > 0 then
                    table.insert(draw3, table.remove(u._deck, 1))
                end
            end
            if #draw3 >= 1 then table.insert(u.hand, draw3[1]) end
            if #draw3 >= 2 then table.insert(u.chips, draw3[2]) end
            if #draw3 >= 3 then table.insert(u._deck, draw3[3]) end
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            -- 手札1捨て1引き
            if #tgt.hand > 0 then table.remove(tgt.hand, 1) end
            if #tgt._deck > 0 then table.insert(tgt.hand, table.remove(tgt._deck, 1)) end
            -- チップ3以上なら発掘リヴァイブ（相手のシールドからチップ1枚復活）
            if #u.chips >= 3 and #tgt.shields > 0 then
                local sh = table.remove(tgt.shields, 1)
                table.insert(u.chips, sh)
            end
        end,
    },

    -- 4: 皇帝
    {n=4, name="皇帝", icon="⚔️",
        posDesc="+4",
        negDesc="相手の今ターンの積み上げを1枚キャンセル",
        posEffect = function(gs, u, tgt)
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + 4
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            gs.cancelStack = gs.cancelStack or {}
            gs.cancelStack[tgt.id] = 1
        end,
    },

    -- 5: 鳳凰
    {n=5, name="鳳凰", icon="🔥",
        posDesc="このターンをロードのみで判定（バトルカード無効）",
        negDesc="相手の正位置効果を無効化",
        posEffect = function(gs, u, tgt)
            gs.roadOnly = true
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            gs.nullPos = gs.nullPos or {}
            gs.nullPos[tgt.id] = true
        end,
    },

    -- 6: 恋人
    {n=6, name="恋人", icon="💕",
        posDesc="+12",
        negDesc="-12",
        posEffect = function(gs, u, tgt)
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + 12
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            gs.arcanaBonus[tgt.id] = (gs.arcanaBonus[tgt.id] or 0) - 12
        end,
    },

    -- 7: 戦車
    {n=7, name="戦車", icon="🚂",
        posDesc="+7",
        negDesc="暴走ルーレット：ランダムで+7が誰かに発動",
        posEffect = function(gs, u, tgt)
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + 7
        end,
        negEffect = function(gs, u, tgt)
            if #gs.playerList == 0 then return end
            local lucky = gs.playerList[math.random(#gs.playerList)]
            gs.arcanaBonus[lucky.id] = (gs.arcanaBonus[lucky.id] or 0) + 7
        end,
    },

    -- 8: 力（バランス懸念あり・正位置は後で調整）
    {n=8, name="力", icon="💪",
        posDesc="バトルカードを2枚出せる（合計値）",
        negDesc="-8",
        posEffect = function(gs, u, tgt)
            -- extraBattleSlotフラグを立ててbattlePhaseで2枚受け付ける
            gs.extraBattleSlot = gs.extraBattleSlot or {}
            gs.extraBattleSlot[u.id] = true
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            gs.arcanaBonus[tgt.id] = (gs.arcanaBonus[tgt.id] or 0) - 8
        end,
    },

    -- 9: 隠者
    {n=9, name="隠者", icon="🕯️",
        posDesc="自シールド1枚確認→手札と入れ替え可",
        negDesc="発掘：相手シールド1枚表にしてそのランク以下のチップ1枚獲得",
        posEffect = function(gs, u, tgt)
            if #u.shields > 0 and #u.hand > 0 then
                local sh = table.remove(u.shields, 1)
                local hc = table.remove(u.hand, 1)
                table.insert(u.shields, 1, hc)
                table.insert(u.hand, sh)
            end
        end,
        negEffect = function(gs, u, tgt)
            if not tgt or #tgt.shields == 0 then return end
            local sh = tgt.shields[1]
            -- そのランク以下のチップ1枚獲得
            for i, c in ipairs(tgt.chips) do
                if c.rank <= sh.rank then
                    table.remove(tgt.chips, i)
                    table.insert(u.chips, c)
                    break
                end
            end
        end,
    },

    -- 10: 運命の輪
    {n=10, name="運命の輪", icon="🎡",
        posDesc="コスト：チップ1枚。使用済みアルカナを1枚再使用可にする",
        negDesc="相手の次ターンアルカナを封印",
        posEffect = function(gs, u, tgt)
            if #u.chips == 0 then return end
            table.remove(u.chips, 1)
            -- 使用済みアルカナを1枚解放
            for n, _ in pairs(u.arcanaUsed) do
                u.arcanaUsed[n] = nil
                break
            end
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            gs.arcanaBan = gs.arcanaBan or {}
            gs.arcanaBan[tgt.id] = (gs.arcanaBan[tgt.id] or 0) + 1
        end,
    },

    -- 11: 正義
    {n=11, name="正義", icon="⚖️",
        posDesc="自合計≥相手なら勝利確定",
        negDesc="相手合計から自ロードランク分を減算",
        posEffect = function(gs, u, tgt)
            gs.justiceUser = u.id
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            local rdRank = gs.road[u.id] and gs.road[u.id].rank or 0
            gs.arcanaBonus[tgt.id] = (gs.arcanaBonus[tgt.id] or 0) - rdRank
        end,
    },

    -- 12: アンバー
    {n=12, name="アンバー", icon="🪨",
        posDesc="このターン敗北してもカードを積み上げられる（チップ払わず）",
        negDesc="相手チップ枚数分を自分のバトル合計に加算",
        posEffect = function(gs, u, tgt)
            gs.amberUser = u.id
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + #tgt.chips
        end,
    },

    -- 13: レックス
    {n=13, name="レックス", icon="🦖",
        posDesc="自列最大枚数分加算＋相手列から1枚除去",
        negDesc="相手列最大枚数分を相手から減算",
        posEffect = function(gs, u, tgt)
            local maxCol = 0
            for _, col in ipairs(u.columns) do
                if #col > maxCol then maxCol = #col end
            end
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + maxCol
            if tgt then
                local tgtMaxIdx = 1
                for i, col in ipairs(tgt.columns) do
                    if #col > #tgt.columns[tgtMaxIdx] then tgtMaxIdx = i end
                end
                if #tgt.columns[tgtMaxIdx] > 0 then
                    local removed = table.remove(tgt.columns[tgtMaxIdx])
                    -- 墓地に送る
                    tgt.graveyard = tgt.graveyard or {}
                    if removed then table.insert(tgt.graveyard, removed) end
                end
            end
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            local maxCol = 0
            for _, col in ipairs(tgt.columns) do
                if #col > maxCol then maxCol = #col end
            end
            gs.arcanaBonus[tgt.id] = (gs.arcanaBonus[tgt.id] or 0) - maxCol
        end,
    },

    -- 14: 節制
    {n=14, name="節制", icon="⚗️",
        posDesc="自チップ枚数分を加算",
        negDesc="相手チップ枚数分を相手から減算",
        posEffect = function(gs, u, tgt)
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + #u.chips
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            gs.arcanaBonus[tgt.id] = (gs.arcanaBonus[tgt.id] or 0) - #tgt.chips
        end,
    },

    -- 15: 悪魔
    {n=15, name="悪魔", icon="😈",
        posDesc="自手札のランク合計分を加算",
        negDesc="相手手札のランク合計分を相手から減算",
        posEffect = function(gs, u, tgt)
            local sum = 0
            for _, c in ipairs(u.hand) do sum = sum + (c.rank or 0) end
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + sum
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            local sum = 0
            for _, c in ipairs(tgt.hand) do sum = sum + (c.rank or 0) end
            gs.arcanaBonus[tgt.id] = (gs.arcanaBonus[tgt.id] or 0) - sum
        end,
    },

    -- 16: ディメトロ
    {n=16, name="ディメトロ", icon="🗼",
        posDesc="モードA（チップ枚数加算）",
        negDesc="全員バトルカード2枚強制（低い方参照）",
        posEffect = function(gs, u, tgt)
            -- モードA: チップ枚数加算（最もシンプルで安定）
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + #u.chips
        end,
        negEffect = function(gs, u, tgt)
            gs.dimMode = true
        end,
    },

    -- 17: エラスモ
    {n=17, name="エラスモ", icon="🌊",
        posDesc="山から列最大枚数分見て1枚手札へ",
        negDesc="相手山からチップ枚数分を山底へ。次ターン補充-1",
        posEffect = function(gs, u, tgt)
            local maxCol = 1
            for _, col in ipairs(u.columns) do
                if #col > maxCol then maxCol = #col end
            end
            local drawn = {}
            for i = 1, maxCol do
                if #u._deck > 0 then
                    table.insert(drawn, table.remove(u._deck, 1))
                end
            end
            if #drawn > 0 then
                table.insert(u.hand, drawn[1])
                for i = 2, #drawn do
                    table.insert(u._deck, drawn[i])
                end
            end
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            local n = #u.chips
            for i = 1, n do
                if #tgt._deck > 0 then
                    local c = table.remove(tgt._deck, 1)
                    table.insert(tgt._deck, c)
                end
            end
            -- 次ターン補充-1フラグ
            gs.drawMinus = gs.drawMinus or {}
            gs.drawMinus[tgt.id] = (gs.drawMinus[tgt.id] or 0) + 1
        end,
    },

    -- 18: プテラノ
    {n=18, name="プテラノ", icon="🦅",
        posDesc="ロードランク分を追加加算（ロード2回参照）",
        negDesc="相手シールドをシャッフル＋次ターン相手ロード出せず",
        posEffect = function(gs, u, tgt)
            local rdRank = gs.road[u.id] and gs.road[u.id].rank or 0
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + rdRank
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            -- シールドシャッフル
            for i = #tgt.shields, 2, -1 do
                local j = math.random(i)
                tgt.shields[i], tgt.shields[j] = tgt.shields[j], tgt.shields[i]
            end
            -- 次ターンロード出せず
            gs.noRoad = gs.noRoad or {}
            gs.noRoad[tgt.id] = 1
        end,
    },

    -- 19: ドラゴン
    {n=19, name="ドラゴン", icon="🐉",
        posDesc="自＋味方のロード合計を自分のバトル合計に加算",
        negDesc="相手チームのロード合計をそれぞれの合計から減算",
        posEffect = function(gs, u, tgt)
            local sum = gs.road[u.id] and gs.road[u.id].rank or 0
            for _, p in ipairs(gs.playerList) do
                if p.team == u.team and p.id ~= u.id then
                    sum = sum + (gs.road[p.id] and gs.road[p.id].rank or 0)
                end
            end
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + sum
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            -- 相手チーム全員のロード合計を各自から減算
            local enemyTeam = tgt.team
            local sum = 0
            for _, p in ipairs(gs.playerList) do
                if p.team == enemyTeam then
                    sum = sum + (gs.road[p.id] and gs.road[p.id].rank or 0)
                end
            end
            for _, p in ipairs(gs.playerList) do
                if p.team == enemyTeam then
                    gs.arcanaBonus[p.id] = (gs.arcanaBonus[p.id] or 0) - sum
                end
            end
        end,
    },

    -- 20: シーラカンス
    {n=20, name="シーラカンス", icon="🐟",
        posDesc="発掘：相手シールドを表にし、そのランク以下のチップからリヴァイブ",
        negDesc="±0（数値変動なし）",
        posEffect = function(gs, u, tgt)
            if not tgt or #tgt.shields == 0 then return end
            local sh = tgt.shields[1]
            -- そのランク以下のチップをリヴァイブ（チップ→手札）
            for i, c in ipairs(u.chips) do
                if c.rank <= sh.rank then
                    table.remove(u.chips, i)
                    table.insert(u.hand, c)
                    break
                end
            end
        end,
        negEffect = function(gs, u, tgt)
            -- 効果なし（±0）
        end,
    },

    -- 21: アーケオ
    {n=21, name="アーケオ", icon="🌍",
        posDesc="全列の枚数合計を加算。このターン勝利なら積み上げ2倍",
        negDesc="相手の全列枚数合計分を相手から減算",
        posEffect = function(gs, u, tgt)
            local total = 0
            for _, col in ipairs(u.columns) do total = total + #col end
            gs.arcanaBonus[u.id] = (gs.arcanaBonus[u.id] or 0) + total
            gs.archeoDouble = u.id
        end,
        negEffect = function(gs, u, tgt)
            if not tgt then return end
            local total = 0
            for _, col in ipairs(tgt.columns) do total = total + #col end
            gs.arcanaBonus[tgt.id] = (gs.arcanaBonus[tgt.id] or 0) - total
        end,
    },
}

-- ============================================
-- アルカナデッキ生成（シャッフル）
-- ============================================
function ArcanaSystem.buildArcana()
    local deck = {}
    for _, a in ipairs(ArcanaSystem.ARCANA_DATA) do
        table.insert(deck, a)
    end
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- ============================================
-- アルカナ適用
-- ============================================
function ArcanaSystem.applyArcana(arcData, direction, gs, user, target)
    if not arcData then return end
    -- arcanaBan チェック（封印されていたら不発）
    if gs.arcanaBan and gs.arcanaBan[user.id] and gs.arcanaBan[user.id] > 0 then
        gs.arcanaBan[user.id] = gs.arcanaBan[user.id] - 1
        return
    end
    -- nullPos チェック（正位置無効化）
    if direction == "pos" and gs.nullPos and gs.nullPos[user.id] then
        return
    end
    local fn = direction == "pos" and arcData.posEffect or arcData.negEffect
    if fn then
        fn(gs, user, target)
    end
    -- 使用済みマーク
    user.arcanaUsed = user.arcanaUsed or {}
    user.arcanaUsed[arcData.n] = true
    -- 統計
    user._arcanaUsed = (user._arcanaUsed or 0) + 1
end

-- ============================================
-- AIアルカナ選択
-- ============================================
function ArcanaSystem.aiPickArcana(gs, p, difficulty)
    -- arcanaBan チェック
    if gs.arcanaBan and gs.arcanaBan[p.id] and gs.arcanaBan[p.id] > 0 then
        return nil
    end

    local unused = {}
    p.arcanaUsed = p.arcanaUsed or {}
    for _, a in ipairs(p.arcana or {}) do
        if not p.arcanaUsed[a.n] then
            table.insert(unused, a)
        end
    end
    if #unused == 0 then return nil end

    -- 難易度別スキップ率
    if difficulty == "easy"   and math.random(100) <= 60 then return nil end
    if difficulty == "normal" and math.random(100) <= 40 then return nil end

    local card = unused[1]
    local tgt = nil
    for _, ep in ipairs(gs.playerList) do
        if ep.team ~= p.team then tgt = ep; break end
    end

    local dir = "pos"
    if difficulty == "hard" then
        -- 自チームが不利なら逆位置で妨害
        local myScore, enemyScore = 0, 0
        for _, col in ipairs(p.columns) do myScore = myScore + #col end
        if tgt then
            for _, col in ipairs(tgt.columns) do enemyScore = enemyScore + #col end
        end
        if myScore < enemyScore then dir = "neg" end
    end

    return {card=card, direction=dir, target=tgt}
end

print("✅ ArcanaSystem.lua loaded: " .. #ArcanaSystem.ARCANA_DATA .. "枚")
return ArcanaSystem
