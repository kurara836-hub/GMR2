-- DinoSystem.lua
-- ReplicatedStorage/DinoSystem
-- 恐竜じゃんけんEXシステム

local DinoSystem = {}

-- ═══════════════════════════════════════
-- 恐竜本体カード定義
-- rank: じゃんけん合算の基礎値
-- tech: 毎ターンMP回復量
-- ═══════════════════════════════════════
DinoSystem.DINO_CARDS = {
	-- 強恐竜（ランク高・テクニック低）
	{id="dino_trex",      name="ティラノサウルス", rank=13, tech=1},
	{id="dino_spino",     name="スピノサウルス",   rank=11, tech=1},
	{id="dino_carno",     name="カルノタウルス",   rank=10, tech=2},
	{id="dino_raptor",    name="ヴェロキラプトル", rank=8,  tech=2},
	-- 中恐竜
	{id="dino_stego",     name="ステゴサウルス",   rank=7,  tech=3},
	{id="dino_trike",     name="トリケラトプス",   rank=6,  tech=3},
	{id="dino_brachi",    name="ブラキオサウルス", rank=5,  tech=3},
	-- 弱恐竜（ランク低・テクニック高）
	{id="dino_ankylo",    name="アンキロサウルス", rank=4,  tech=4},
	{id="dino_pachy",     name="パキケファロ",     rank=3,  tech=4},
	{id="dino_para",      name="パラサウロロフス", rank=2,  tech=5},
	{id="dino_ptero",     name="プテラノドン",     rank=1,  tech=5},
}

-- ═══════════════════════════════════════
-- 技カード定義
-- hand: "gu"=グー / "choki"=チョキ / "pa"=パー / "kakushi"=隠し手
-- cost: MPコスト
-- ═══════════════════════════════════════
DinoSystem.TECH_CARDS = {
	-- グー系
	{id="tech_kamitsuki",   name="かみつき",       hand="gu",     cost=3,
	 effect="win:chip_break_1",  -- 勝ち: 相手チップ1枚破壊
	 desc="じゃんけんに勝つと相手のチップを1枚破壊する"},

	{id="tech_tailblow",    name="テールブロー",   hand="gu",     cost=5,
	 effect="win:chip_break_2",
	 desc="じゃんけんに勝つと相手のチップを2枚破壊する"},

	-- チョキ系
	{id="tech_scratch",     name="ひっかき",       hand="choki",  cost=1,
	 effect="win:draw_1",       -- 勝ち: 1枚ドロー
	 desc="じゃんけんに勝つと1枚引く"},

	{id="tech_roar",        name="咆哮",           hand="choki",  cost=3,
	 effect="win:shield_peek",  -- 勝ち: 相手シールド1枚公開
	 desc="じゃんけんに勝つと相手のシールドを1枚見る"},

	-- パー系
	{id="tech_tackle",      name="タックル",       hand="pa",     cost=2,
	 effect="win:col_add_1",    -- 勝ち: 自列に1枚追加配置
	 desc="じゃんけんに勝つと自分の列に追加でカードを1枚置ける"},

	{id="tech_stampede",    name="スタンピード",   hand="pa",     cost=4,
	 effect="win:col_add_2",
	 desc="じゃんけんに勝つと自分の列に追加で2枚置ける"},

	-- 隠し手（EXカード専用・高コスト・強力）
	{id="tech_extinction",  name="大絶滅",         hand="kakushi", cost=7,
	 effect="win:all_chip_break", -- 勝ち: 相手チップ全破壊
	 desc="隠し手。じゃんけんに勝つと相手のチップを全て破壊する"},

	{id="tech_meteor",      name="隕石落下",       hand="kakushi", cost=6,
	 effect="win:ex_destroy_1",  -- 勝ち: 相手EX1枚破壊
	 desc="隠し手。じゃんけんに勝つと相手のEXカードを1枚破壊する"},

	{id="tech_fossil",      name="化石覚醒",       hand="kakushi", cost=5,
	 effect="win:revive_chip_3", -- 勝ち: チップ3枚を手札に戻す
	 desc="隠し手。じゃんけんに勝つとチップを3枚手札に戻す"},
}

-- じゃんけん勝敗判定
-- 戻り値: "win" / "lose" / "draw"
function DinoSystem.judgeJanken(myHand, oppHand)
	if myHand == oppHand then return "draw" end
	-- 隠し手は通常手に勝つ（グー/チョキ/パー全てに勝つ）
	if myHand == "kakushi" and oppHand ~= "kakushi" then return "win" end
	if oppHand == "kakushi" and myHand ~= "kakushi" then return "lose" end
	-- 隠し手同士はdraw
	if myHand == "kakushi" and oppHand == "kakushi" then return "draw" end
	-- 通常じゃんけん
	local wins = {gu="choki", choki="pa", pa="gu"}
	if wins[myHand] == oppHand then return "win" end
	return "lose"
end

-- MP管理
-- ═══════════════════════════════════════
-- プレイヤーのMP状態を初期化
function DinoSystem.initMP(player)
	player.mp = 0
	player.mpMax = 10
	player.dinoCard = nil   -- 装備中の恐竜本体
	player.techHand = nil   -- 今ターン選択した技
end

-- ターン開始時にMP回復
function DinoSystem.recoverMP(player)
	if not player.dinoCard then return end
	local dino = DinoSystem.getDinoById(player.dinoCard)
	if not dino then return end
	player.mp = math.min(player.mp + dino.tech, player.mpMax)
end

-- 技カードのMPコスト消費
-- 戻り値: true=成功 / false=MP不足
function DinoSystem.consumeMP(player, techId)
	local tech = DinoSystem.getTechById(techId)
	if not tech then return false end
	if player.mp < tech.cost then return false end
	player.mp = player.mp - tech.cost
	return true
end

-- じゃんけん合計値計算（ランク + 技カードのランク相当）
-- 技カードは cost値をそのまま加算（DS版の攻撃力相当）
function DinoSystem.calcJankenPower(player, techId)
	local dino = DinoSystem.getDinoById(player.dinoCard)
	local tech = DinoSystem.getTechById(techId)
	if not dino or not tech then return 0 end
	return dino.rank + tech.cost
end

-- ヘルパー
function DinoSystem.getDinoById(id)
	for _, d in ipairs(DinoSystem.DINO_CARDS) do
		if d.id == id then return d end
	end
	return nil
end

function DinoSystem.getTechById(id)
	for _, t in ipairs(DinoSystem.TECH_CARDS) do
		if t.id == id then return t end
	end
	return nil
end

-- ═══════════════════════════════════════
-- じゃんけん効果適用
-- effect文字列をパースして盤面に反映
-- ═══════════════════════════════════════
function DinoSystem.applyEffect(effect, winner, loser, gameState)
	if effect == "win:chip_break_1" then
		if #loser.chip_area > 0 then
			table.remove(loser.chip_area, 1)
		end

	elseif effect == "win:chip_break_2" then
		for i = 1, 2 do
			if #loser.chip_area > 0 then
				table.remove(loser.chip_area, 1)
			end
		end

	elseif effect == "win:draw_1" then
		if #gameState.deck > 0 then
			table.insert(winner.hand, table.remove(gameState.deck, 1))
		end

	elseif effect == "win:shield_peek" then
		-- クライアントに通知（シールド公開UI）
		winner.peekShield = true

	elseif effect == "win:col_add_1" then
		winner.jankenColBonus = (winner.jankenColBonus or 0) + 1

	elseif effect == "win:col_add_2" then
		winner.jankenColBonus = (winner.jankenColBonus or 0) + 2

	elseif effect == "win:all_chip_break" then
		loser.chip_area = {}

	elseif effect == "win:ex_destroy_1" then
		if #loser.ex_zone > 0 then
			table.remove(loser.ex_zone, 1)
		end

	elseif effect == "win:revive_chip_3" then
		for i = 1, 3 do
			if #winner.chip_area > 0 then
				local card = table.remove(winner.chip_area, #winner.chip_area)
				table.insert(winner.hand, card)
			end
		end
	end
end

return DinoSystem
