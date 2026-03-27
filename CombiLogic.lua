-- ============================================
-- GAMEROAD CombiLogic.lua
-- ReplicatedStorage/ に配置（ModuleScript型）
-- BattleServer_v2からrequireして使う
--
-- コンビ戦チャット用プログラムの設計を完全実装：
--   役割分担（キャリー/妨害役）
--   戦略的敗北（ドレイン）
--   露払い
--   チーム内情報共有（シールド・手札が味方に筒抜け）
--   高度推察（公開情報から敵手札を逆算）
--   3フェーズ相談式（Road相談→Battle相談）
--   ナビゲーター機能（P1支援・アドバイス生成）
-- ============================================

local CombiLogic = {}

-- ============================================
-- フェーズ判定（仕様準拠）
-- ============================================
-- 盤面0：全員H=0
-- 序盤：H+N<=4
-- 中盤：H+N=5~6
-- 最終盤：H+N>=7

function CombiLogic.getPhaseLabel(gs, player)
    local maxCol = 0
    local totalCards = 0
    for _, col in ipairs(player.columns) do
        if #col > maxCol then maxCol = #col end
        totalCards = totalCards + #col
    end
    local n = #gs.deck / 52  -- 残り山比率（近似）
    local hPlusN = maxCol + math.floor(#gs.deck / 13)

    if totalCards == 0 then
        return "board0"    -- 盤面0：最序盤
    elseif maxCol == 0 or hPlusN <= 4 then
        return "early"     -- 序盤：構築期
    elseif hPlusN <= 6 then
        return "mid"       -- 中盤：攻防期
    else
        return "final"     -- 最終盤：リーサル
    end
end

-- ============================================
-- 役割分担判定（3ターン目以降）
-- チームメンバーの盤面状況で「キャリー」か「妨害役」かを決める
-- ============================================
function CombiLogic.assignRoles(gs, myPlayer, allyPlayer)
    -- 3ターン目未満は役割なし
    if gs.turn < 3 then
        return "free", "free"
    end

    local myMaxCol  = 0
    local allyMaxCol = 0
    for _, col in ipairs(myPlayer.columns) do
        if #col > myMaxCol then myMaxCol = #col end
    end
    for _, col in ipairs(allyPlayer.columns) do
        if #col > allyMaxCol then allyMaxCol = #col end
    end

    -- 列が多い方がキャリー（7枚を目指す道役）
    if myMaxCol >= allyMaxCol then
        return "carry", "support"  -- 自分がキャリー、味方がサポート
    else
        return "support", "carry"
    end
end

-- ============================================
-- 戦略的敗北（ドレイン）の判断
-- サポート役が意図的に弱いカードで負けて
-- 敵のカードを不要な列に置かせる or 手を消費させる
-- ============================================
function CombiLogic.shouldDrain(gs, myRole, myPlayer, enemies)
    if myRole ~= "support" then return false end

    -- 盤面0や序盤はドレイン狙いより手札整理が優先
    local phase = CombiLogic.getPhaseLabel(gs, myPlayer)
    if phase == "board0" or phase == "early" then return false end

    -- 敵の最大列が自分のチームより低い時はドレイン狙い
    local enemyMaxCol = 0
    for _, e in ipairs(enemies) do
        for _, col in ipairs(e.columns) do
            if #col > enemyMaxCol then enemyMaxCol = #col end
        end
    end
    local myChipCount = #myPlayer.chips

    -- チップが4枚以上溜まっており、敵の進行が遅いならドレイン有効
    return myChipCount >= 4 and enemyMaxCol <= 3
end

-- ============================================
-- 露払い判断
-- 味方キャリーが確実に勝てるよう先に高ランクで敵の手を消費させる
-- ============================================
function CombiLogic.shouldPathclear(gs, myRole, myPlayer, allyPlayer, enemies)
    if myRole ~= "support" then return false end

    local allyMaxCol = 0
    for _, col in ipairs(allyPlayer.columns) do
        if #col > allyMaxCol then allyMaxCol = #col end
    end

    -- 味方キャリーが中盤以降で有利なら露払い検討
    local phase = CombiLogic.getPhaseLabel(gs, allyPlayer)
    if phase ~= "mid" and phase ~= "final" then return false end

    -- 敵のシールドが高ランクのカードを持っている可能性がある時
    -- （推察で高ランク未出が多い時）
    local highCardsLeft = CombiLogic.estimateHighCards(gs)
    return highCardsLeft >= 3 and allyMaxCol >= 4
end

-- ============================================
-- カードカウンティング（残り高ランク推算）
-- 公開情報（列・チップ・ロード）から13の残り枚数を推算
-- ============================================
function CombiLogic.estimateHighCards(gs)
    -- 13・12が何枚出たか数える
    local seen = {[13]=0, [12]=0, [11]=0}
    local function countInList(cards)
        for _, c in ipairs(cards) do
            if seen[c.rank] ~= nil then
                seen[c.rank] = seen[c.rank] + 1
            end
        end
    end

    for _, p in ipairs(gs.playerList) do
        countInList(p.chips)
        for _, col in ipairs(p.columns) do
            countInList(col)
        end
        if gs.road[p.id] then
            local r = gs.road[p.id].rank
            if seen[r] ~= nil then seen[r] = seen[r] + 1 end
        end
    end

    -- 各スートに1枚ずつ計4枚が上限
    local remaining = 0
    for rank, count in pairs(seen) do
        remaining = remaining + math.max(0, 4 - count)
    end
    return remaining
end

-- ============================================
-- AIロードカード選択（役割分担・戦術反映）
-- ============================================
function CombiLogic.aiPickRoad(gs, player, role, difficulty, enemies, ally)
    local hand   = player.hand
    if #hand == 0 then return nil end

    local sorted = {table.unpack(hand)}
    table.sort(sorted, function(a, b) return a.rank < b.rank end)

    -- 盤面0：手札の「掃除」→使いにくいカードを優先して出す
    if CombiLogic.getPhaseLabel(gs, player) == "board0" then
        -- 中間値を出して情報を出さない
        local mid = sorted[math.ceil(#sorted / 2)] or sorted[1]
        return mid
    end

    -- 戦略的敗北（ドレイン）：最小値を出す
    if CombiLogic.shouldDrain(gs, role, player, enemies) then
        return sorted[1]
    end

    -- 露払い：最大値を出して敵のカウンターを消費させる
    if CombiLogic.shouldPathclear(gs, role, player, ally, enemies) then
        return sorted[#sorted]
    end

    -- キャリー役：チップが多い時は高い値で勝ちに行く
    if role == "carry" then
        if #player.chips >= 4 then
            return sorted[#sorted]  -- 最大値
        else
            -- 勝てる最低限の値（効率的）
            return sorted[math.ceil(#sorted * 0.6)] or sorted[#sorted]
        end
    end

    -- サポート役：中間値
    return sorted[math.ceil(#sorted / 2)] or sorted[1]
end

-- ============================================
-- AIバトルカード選択（役割・状況反映）
-- ============================================
function CombiLogic.aiPickBattle(gs, player, role, difficulty, enemies)
    local hand = player.hand
    if #hand == 0 then return nil end

    local sorted = {table.unpack(hand)}
    table.sort(sorted, function(a, b) return a.rank > b.rank end)  -- 大→小

    -- 防御側：バトルカードは自動（シールド使用）なのでここは攻撃側のみ
    if gs.defId == player.id then return nil end

    -- ドレイン中：弱いカードで負ける
    if CombiLogic.shouldDrain(gs, role, player, enemies) then
        return sorted[#sorted]  -- 最小値
    end

    -- キャリー：勝てる最低限のカードを出す（手札節約）
    if role == "carry" then
        -- 敵の推定シールドを計算（相手の手札数から推算）
        local enemyEst = 0
        for _, e in ipairs(enemies) do
            if e.id == gs.defId then
                -- 相手の手札枚数 × 平均rank(7) で推算
                -- 手札が多いほど高いカードを持っている可能性が高い
                local handCount = e.handCount or 5
                enemyEst = math.floor(handCount * 1.4) + 3  -- 最低でも10前後
            end
        end
        local myRoad = gs.road[player.id] and gs.road[player.id].rank or 0
        local needed = math.max(1, enemyEst - myRoad + 1)

        -- neededを超える最小のカードを選ぶ（手札を節約）
        for i = #sorted, 1, -1 do
            if sorted[i].rank >= needed then
                return sorted[i]
            end
        end
    end

    -- デフォルト：最強を出す
    return sorted[1]
end

-- ============================================
-- ナビゲーターアドバイス生成
-- （P1=人間プレイヤーへの提案テキスト）
-- ============================================
function CombiLogic.generateNavigatorAdvice(gs, myPlayer, allyPlayer, enemies, phase)
    local role, _ = CombiLogic.assignRoles(gs, myPlayer, allyPlayer)
    local phaseLabel = CombiLogic.getPhaseLabel(gs, myPlayer)
    local highLeft   = CombiLogic.estimateHighCards(gs)
    local myChips    = #myPlayer.chips

    local advice = {}

    -- フェーズ別基本アドバイス
    if phaseLabel == "board0" then
        table.insert(advice, "序盤：中間値を出して手札を整えよう")
    elseif phaseLabel == "early" then
        table.insert(advice, "構築期：負けてチップを溜めるのも手")
    elseif phaseLabel == "mid" then
        if role == "carry" then
            table.insert(advice, "【キャリー役】" ..
                string.format("チップ%d枚！高いカードで攻めよう", myChips))
        else
            table.insert(advice, "【サポート役】味方を援護。あえて負けて相手の手を削ろう")
        end
    elseif phaseLabel == "final" then
        -- リーサル計算
        local myMaxCol = 0
        for _, col in ipairs(myPlayer.columns) do
            if #col > myMaxCol then myMaxCol = #col end
        end
        table.insert(advice, string.format(
            "【リーサル】あと%d枚！全力で！", 7 - myMaxCol))
    end

    -- 敵の天井警戒
    local enemyMax = 0
    for _, e in ipairs(enemies) do
        for _, col in ipairs(e.columns) do
            if #col > enemyMax then enemyMax = #col end
        end
    end
    if enemyMax >= 6 then
        table.insert(advice, "⚠ 敵が天井目前！今すぐ止める！")
    end

    -- カードカウンティング情報
    if phaseLabel == "mid" or phaseLabel == "final" then
        table.insert(advice, string.format(
            "【カウント】残り高ランク約%d枚", highLeft))
    end

    -- ドレイン提案
    if CombiLogic.shouldDrain(gs, role, myPlayer, enemies) then
        table.insert(advice, "💡 ドレイン戦略：弱いカードで負けて相手の手を無駄撃ちさせよう")
    end

    return table.concat(advice, "\n")
end

-- ============================================
-- チーム内情報共有データ生成
-- （仕様：チーム内ではシールド・手札が筒抜け）
-- ============================================
function CombiLogic.buildTeamInfo(gs, requestingPlayerId)
    local requester = gs.playerMap and gs.playerMap[requestingPlayerId]
    if not requester then return {} end

    local info = {}
    for _, p in ipairs(gs.playerList) do
        if p.team == requester.team and p.id ~= requestingPlayerId then
            -- 味方の情報（全公開）
            info[p.id] = {
                hand    = p.hand,    -- 手札も見える
                shields = p.shields, -- シールドも見える
                chips   = p.chips,
                columns = p.columns,
            }
        end
    end
    return info
end

-- ============================================
-- 3フェーズ相談式アドバイス（Road相談・Battle相談）
-- ============================================
function CombiLogic.buildConsultMessage(gs, myPlayer, allyPlayer, phase, enemies)
    local role, allyRole = CombiLogic.assignRoles(gs, myPlayer, allyPlayer)
    local nav = CombiLogic.generateNavigatorAdvice(
        gs, myPlayer, allyPlayer, enemies, phase)

    -- P2（AIパートナー）からの提案
    local p2Suggestion = ""
    if phase == "road" then
        if CombiLogic.shouldDrain(gs, allyRole, allyPlayer, enemies) then
            p2Suggestion = "P2提案：私はドレインで弱いカード出す。あなたは高いので攻めて"
        elseif CombiLogic.shouldPathclear(gs, allyRole, allyPlayer, myPlayer, enemies) then
            p2Suggestion = "P2提案：露払いで私が最大値出すから、あなたは次のターンに備えて"
        else
            p2Suggestion = "P2提案：それぞれ役割通りに行こう"
        end
    elseif phase == "battle" then
        local highLeft = CombiLogic.estimateHighCards(gs)
        p2Suggestion = string.format(
            "P2提案：残り高ランク約%d枚。%s",
            highLeft,
            highLeft >= 4 and "相手の手は厚い。慎重に" or "相手の高ランクは薄い。攻め時"
        )
    end

    return {
        navigator = nav,          -- ナビゲーター（P1補助AI）
        partner   = p2Suggestion, -- P2（AIパートナー）
        role      = role,
        allyRole  = allyRole,
        turn      = gs.turn,
    }
end

return CombiLogic
