-- CardData.lua
-- ReplicatedStorage/CardData
-- 全カード定義・デッキ構築ユーティリティ

local CardData = {}

-- ═══════════════════════════════════════
-- エフェクトタイプ定数
-- ═══════════════════════════════════════
CardData.FX = {
    CHIP_DRAW     = "on_chip_draw",
    POWER_IF_CHIP = "power_if_chip",
    SHIELD_BOOST  = "shield_boost",
    EX_TRIGGER    = "ex_trigger",
    DRAW          = "draw",
    REVIVE        = "revive",
}

-- ═══════════════════════════════════════
-- 全カード定義
-- ═══════════════════════════════════════
CardData.ALL_CARDS = {

    -- ♧ クラディオン（17種）
    {id="club_1",  suit="club", rank=1,  rarity="C",
     name="芽吹きの種",      desc="チップになった時、1枚引く",
     effect=CardData.FX.CHIP_DRAW},
    {id="club_2",  suit="club", rank=2,  rarity="C",
     name="苔むす石",        desc="チップが3枚以上の時、バトル+1"},
    {id="club_3",  suit="club", rank=3,  rarity="C",
     name="小さな根",        desc="特殊効果なし"},
    {id="club_4",  suit="club", rank=4,  rarity="C",
     name="森の実",          desc="特殊効果なし"},
    {id="club_5",  suit="club", rank=5,  rarity="C",
     name="若葉",            desc="チップになった時、1枚引く",
     effect=CardData.FX.CHIP_DRAW},
    {id="club_6",  suit="club", rank=6,  rarity="C",
     name="木漏れ日",        desc="特殊効果なし"},
    {id="club_7",  suit="club", rank=7,  rarity="C",
     name="樹液の雫",        desc="チップが3枚以上の時、バトル+2",
     effect=CardData.FX.POWER_IF_CHIP, value=2},
    {id="club_8",  suit="club", rank=8,  rarity="R",
     name="古木の守り",      desc="シールドとして使われた時、手札に戻る",
     effect=CardData.FX.SHIELD_BOOST},
    {id="club_9",  suit="club", rank=9,  rarity="R",
     name="蜜の泉",          desc="蜜を2追加する（クラディオン専用）"},
    {id="club_10", suit="club", rank=10, rarity="R",
     name="大樹の枝",        desc="チップが5枚以上の時、バトル+3",
     effect=CardData.FX.POWER_IF_CHIP, value=3},
    {id="club_J",  suit="club", rank=11, rarity="R",
     name="森の精霊",        desc="このカードを出した時、チップを1枚手札に戻す"},
    {id="club_Q",  suit="club", rank=12, rarity="SR",
     name="大森林の意志",    desc="チップを全て列に追加配置する。その後チップ0枚になる"},
    {id="club_K",  suit="club", rank=13, rarity="SR",
     name="世界樹",          desc="チップが7枚以上の時、この試合に勝利する"},
    {id="club_r1", suit="club", rank=1,  rarity="R",
     name="魂の叫び",        desc="チップの枚数分バトル+。最大+7"},
    {id="club_r5", suit="club", rank=5,  rarity="SR",
     name="情熱の逆転",      desc="負けても自分のカードを列に置ける。チップは払わない"},
    {id="club_r12a",suit="club",rank=12, rarity="SR",
     name="不屈の演奏家",    desc="このカードを出した時、追加でバトルをもう1回行う"},
    {id="club_r3", suit="club", rank=3,  rarity="R",
     name="じゃんけん道",    desc="EXのじゃんけん技コストを-1する（最小1）"},

    -- ♥ ハルニア（14種）
    {id="heart_1",  suit="heart", rank=1,  rarity="C",
     name="はじまりのリズム", desc="特殊効果なし"},
    {id="heart_2",  suit="heart", rank=2,  rarity="C",
     name="小さな歌声",      desc="特殊効果なし"},
    {id="heart_3",  suit="heart", rank=3,  rarity="C",
     name="踊る足音",        desc="特殊効果なし"},
    {id="heart_4",  suit="heart", rank=4,  rarity="C",
     name="春風のメロディ",  desc="チップになった時、1枚引く",
     effect=CardData.FX.CHIP_DRAW},
    {id="heart_5",  suit="heart", rank=5,  rarity="C",
     name="二人の合唱",      desc="コンビ戦時、バトル+2"},
    {id="heart_6",  suit="heart", rank=6,  rarity="C",
     name="ステップ",        desc="特殊効果なし"},
    {id="heart_7",  suit="heart", rank=7,  rarity="R",
     name="共鳴する魂",      desc="コンビ戦時、味方が勝った列に自分のカードも追加できる"},
    {id="heart_8",  suit="heart", rank=8,  rarity="R",
     name="鼓動の加速",      desc="1ターン目、ロード+2"},
    {id="heart_9",  suit="heart", rank=9,  rarity="R",
     name="ライブの熱狂",    desc="コンビ戦時、味方のチップを1枚引き取る"},
    {id="heart_10", suit="heart", rank=10, rarity="R",
     name="デュエット",      desc="コンビ戦時、2つの技が使える（EX効果2回）"},
    {id="heart_J",  suit="heart", rank=11, rarity="R",
     name="アンコール",      desc="勝利した列に追加で1枚置ける"},
    {id="heart_Q",  suit="heart", rank=12, rarity="SR",
     name="マッハ進化",      desc="このカードで勝利した時、列に3枚追加で置ける"},
    {id="heart_K",  suit="heart", rank=13, rarity="SR",
     name="ハートキング",    desc="コンビ戦時、自分と味方の合計値で判定する"},
    {id="heart_ex", suit="heart", rank=0,  rarity="SR",
     name="ハルニアの鼓動",  desc="EXカード。シールドを攻撃されるたびに他EXを1枚破壊する。他EXが0の時これが破壊されたらハルニア敗北",
     type="ex_life"},

    -- ♦ ダイノス（14種）
    {id="dino_1",  suit="diamond", rank=1,  rarity="C",
     name="化石のかけら",    desc="特殊効果なし"},
    {id="dino_2",  suit="diamond", rank=2,  rarity="C",
     name="砂漠の風",        desc="特殊効果なし"},
    {id="dino_3",  suit="diamond", rank=3,  rarity="C",
     name="古代の記憶",      desc="特殊効果なし"},
    {id="dino_4",  suit="diamond", rank=4,  rarity="C",
     name="地層の声",        desc="チップになった時、1枚引く",
     effect=CardData.FX.CHIP_DRAW},
    {id="dino_5",  suit="diamond", rank=5,  rarity="C",
     name="発掘",            desc="特殊効果なし"},
    {id="dino_6",  suit="diamond", rank=6,  rarity="C",
     name="石英の輝き",      desc="特殊効果なし"},
    {id="dino_7",  suit="diamond", rank=7,  rarity="R",
     name="隕石の記憶",      desc="相手のカードが見える（スペルニア特性と同効果・1ターン限定）"},
    {id="dino_8",  suit="diamond", rank=8,  rarity="R",
     name="覚醒の兆し",      desc="EXじゃんけんに勝った時、追加で1枚引く"},
    {id="dino_9",  suit="diamond", rank=9,  rarity="R",
     name="古代の咆哮",      desc="EXじゃんけんに勝った時、効果を2回適用する"},
    {id="dino_10", suit="diamond", rank=10, rarity="R",
     name="大地の鼓動",      desc="防御側の時、バトル+3"},
    {id="dino_J",  suit="diamond", rank=11, rarity="R",
     name="覚醒",            desc="EXにじゃんけん技カードがある時、バトル+2"},
    {id="dino_Q",  suit="diamond", rank=12, rarity="SR",
     name="恐竜王",          desc="EXじゃんけんで隠し手を使った時、勝敗に関わらず列に1枚追加"},
    {id="dino_K",  suit="diamond", rank=13, rarity="SR",
     name="太古の支配者",    desc="じゃんけんの手を後出しできる（相手の手を見てから選ぶ）"},
    {id="dino_r3", suit="diamond", rank=3,  rarity="SR",
     name="化石発掘",        desc="EXの恐竜本体カードをもう1枚選んで入れ替えられる（1試合1回）"},

    -- ── ファントムコーデ・アイドルカード（ダイアモンドスート固有）──
    -- 通常カードとして手札に来る。効果でEXからコーデを呼び出す。
    {id="diamond_idol_1", suit="diamond", rank=5,  rarity="R",
     name="輝きのアイドル",
     desc="このカードを出した時、EXから未装着のコーデカードを1枚選んで発動できる",
     effect="idol_call",   part=nil},  -- どの部位でも呼べる
    {id="diamond_idol_2", suit="diamond", rank=8,  rarity="SR",
     name="煌めきのプリマ",
     desc="このカードを出した時、EXから未装着のコーデを2枚まで発動できる",
     effect="idol_call_2", part=nil},
    {id="diamond_idol_3", suit="diamond", rank=11, rarity="SR",
     name="ファントムプリンセス",
     desc="このカードを出した時、EXから全ての未装着コーデを一度に発動できる（フルコーデ狙い）",
     effect="idol_call_all", part=nil},

    -- ♤ スペルニア（14種）
    {id="spade_1",  suit="spade", rank=1,  rarity="C",
     name="剣の誓い",        desc="特殊効果なし"},
    {id="spade_2",  suit="spade", rank=2,  rarity="C",
     name="鋼の意志",        desc="特殊効果なし"},
    {id="spade_3",  suit="spade", rank=3,  rarity="C",
     name="見切り",          desc="特殊効果なし"},
    {id="spade_4",  suit="spade", rank=4,  rarity="C",
     name="守護の盾",        desc="チップになった時、1枚引く",
     effect=CardData.FX.CHIP_DRAW},
    {id="spade_5",  suit="spade", rank=5,  rarity="C",
     name="戦術",            desc="特殊効果なし"},
    {id="spade_6",  suit="spade", rank=6,  rarity="C",
     name="陣形",            desc="特殊効果なし"},
    {id="spade_7",  suit="spade", rank=7,  rarity="R",
     name="情報戦",          desc="相手の手札1枚をこのターン見る"},
    {id="spade_8",  suit="spade", rank=8,  rarity="R",
     name="先読み",          desc="相手のロードカードを出す前に見る"},
    {id="spade_9",  suit="spade", rank=9,  rarity="R",
     name="無効化",          desc="相手のEX効果を1回無効にする"},
    {id="spade_10", suit="spade", rank=10, rarity="R",
     name="完全支配",        desc="相手の全手札を見る"},
    {id="spade_J",  suit="spade", rank=11, rarity="R",
     name="チェンジ",        desc="自分の手札1枚と相手の手札1枚を交換する"},
    {id="spade_Q",  suit="spade", rank=12, rarity="SR",
     name="デリートメテオ",  desc="相手のチップを全て破壊する。この効果を使ったターン、自分はバトルカードを出せない"},
    {id="spade_K",  suit="spade", rank=13, rarity="SR",
     name="蒼剣王",          desc="相手の手札が全て見えている時、このカードのランクは20になる"},
    {id="spade_r9", suit="spade", rank=9,  rarity="SR",
     name="鉄壁",            desc="このカードがシールドの時、破壊されない（1試合1回）"},

    -- 汎用（5種・全スート共通）
    {id="common_joker1", suit="all", rank=0, rarity="SR",
     name="ジョーカー",      desc="ロードカードとして出した時、ランクを任意の数字に変えられる"},
    {id="common_ace",    suit="all", rank=1, rarity="R",
     name="エース覚醒",      desc="チップが10枚以上の時、ランクは14になる"},
    {id="common_draw2",  suit="all", rank=2, rarity="C",
     name="補充の札",        desc="チップになった時、2枚引く",
     effect=CardData.FX.CHIP_DRAW, value=2},
    {id="common_mirror", suit="all", rank=5, rarity="R",
     name="鏡の盾",          desc="シールドとして破壊された時、相手のバトルカードを手札に加える"},
    {id="common_wild",   suit="all", rank=7, rarity="R",
     name="ワイルドカード",  desc="任意のスートのカードとして扱える"},
}

-- ═══════════════════════════════════════
-- EXカード定義（恐竜本体・技カード）
-- ═══════════════════════════════════════
CardData.EX_CARDS = {
    -- 恐竜本体
    {id="dino_trex",   name="ティラノサウルス", type="dino_body",
     rank=13, tech=1, rarity="SR",
     desc="ランク13・テクニック1。最強の恐竜。技は出しにくいが合算値が高い"},
    {id="dino_raptor", name="ヴェロキラプトル", type="dino_body",
     rank=8,  tech=2, rarity="R",
     desc="ランク8・テクニック2。バランス型"},
    {id="dino_ankylo", name="アンキロサウルス", type="dino_body",
     rank=4,  tech=4, rarity="R",
     desc="ランク4・テクニック4。技連発型"},
    {id="dino_para",   name="パラサウロロフス", type="dino_body",
     rank=2,  tech=5, rarity="C",
     desc="ランク2・テクニック5。最速MP回復"},

    -- 技カード
    {id="tech_kamitsuki",  name="かみつき",    type="dino_tech",
     hand="gu",      cost=3, rarity="C",
     effect="win:chip_break_1",
     desc="グー・MP3。勝つと相手チップ1枚破壊"},
    {id="tech_tackle",     name="タックル",    type="dino_tech",
     hand="pa",      cost=2, rarity="C",
     effect="win:col_add_1",
     desc="パー・MP2。勝つと自列に1枚追加配置"},
    {id="tech_scratch",    name="ひっかき",    type="dino_tech",
     hand="choki",   cost=1, rarity="C",
     effect="win:draw_1",
     desc="チョキ・MP1。勝つと1枚引く"},
    {id="tech_roar",       name="咆哮",        type="dino_tech",
     hand="choki",   cost=3, rarity="R",
     effect="win:shield_peek",
     desc="チョキ・MP3。勝つと相手シールド1枚見る"},
    {id="tech_stampede",   name="スタンピード", type="dino_tech",
     hand="pa",      cost=4, rarity="R",
     effect="win:col_add_2",
     desc="パー・MP4。勝つと自列に2枚追加配置"},
    {id="tech_tailblow",   name="テールブロー", type="dino_tech",
     hand="gu",      cost=5, rarity="R",
     effect="win:chip_break_2",
     desc="グー・MP5。勝つと相手チップ2枚破壊"},
    {id="tech_extinction", name="大絶滅",      type="dino_tech",
     hand="kakushi", cost=7, rarity="SR",
     effect="win:all_chip_break",
     desc="隠し手・MP7。勝つと相手チップ全破壊"},
    {id="tech_meteor",     name="隕石落下",    type="dino_tech",
     hand="kakushi", cost=6, rarity="SR",
     effect="win:ex_destroy_1",
     desc="隠し手・MP6。勝つと相手EX1枚破壊"},
    {id="tech_fossil",     name="化石覚醒",    type="dino_tech",
     hand="kakushi", cost=5, rarity="SR",
     effect="win:revive_chip_3",
     desc="隠し手・MP5。勝つとチップ3枚を手札に戻す"},

    -- ハルニアの鼓動（全スート入れられる高レアSR）
    {id="heart_ex", name="ハルニアの鼓動", type="ex_life",
     rarity="SR",
     desc="シールドを攻撃されるたびに他EXを1枚破壊する。他EXが0の時これが破壊されたらハルニア側敗北"},
}

-- ═══════════════════════════════════════
-- ヘルパー関数
-- ═══════════════════════════════════════
function CardData.getCardById(id)
    for _, card in ipairs(CardData.ALL_CARDS) do
        if card.id == id then return card end
    end
    for _, card in ipairs(CardData.EX_CARDS) do
        if card.id == id then return card end
    end
    return nil
end

function CardData.getCardsBySuit(suit)
    local result = {}
    for _, card in ipairs(CardData.ALL_CARDS) do
        if card.suit == suit or card.suit == "all" then
            table.insert(result, card)
        end
    end
    return result
end

-- ═══════════════════════════════════════
-- デッキ構築
-- mode: "trump"=52枚共通 / "tcg"=スート別個別
-- ═══════════════════════════════════════
function CardData.buildDeck(suit, mode)
    if mode == "trump" then
        -- トランプ版: 標準52枚シャッフル
        local deck = {}
        local suits = {"club","heart","diamond","spade"}
        for _, s in ipairs(suits) do
            for rank = 1, 13 do
                table.insert(deck, {
                    id   = s.."_"..rank,
                    suit = s,
                    rank = rank,
                })
            end
        end
        -- シャッフル
        for i = #deck, 2, -1 do
            local j = math.random(1, i)
            deck[i], deck[j] = deck[j], deck[i]
        end
        return deck
    else
        -- TCG版: スート別30枚
        -- GachaSystem側のコレクションから実際の所持カードで構築
        -- ここではデフォルトデッキを返す
        local cards = CardData.getCardsBySuit(suit)
        local deck = {}
        -- ランク順にソートして均等に30枚
        table.sort(cards, function(a,b) return (a.rank or 0) < (b.rank or 0) end)
        for i, card in ipairs(cards) do
            table.insert(deck, card)
            if #deck >= 30 then break end
        end
        -- 足りない場合は繰り返し
        local i = 1
        while #deck < 30 do
            table.insert(deck, cards[i])
            i = (i % #cards) + 1
        end
        -- シャッフル
        for i = #deck, 2, -1 do
            local j = math.random(1, i)
            deck[i], deck[j] = deck[j], deck[i]
        end
        return deck
    end
end

function CardData.buildEXDeck(suit, mode)
    if mode ~= "tcg" then return {} end
    -- デフォルトEXデッキ（ダイノスは恐竜本体+技）
    if suit == "diamond" then
        return {
            CardData.getCardById("dino_raptor"),
            CardData.getCardById("tech_kamitsuki"),
            CardData.getCardById("tech_tackle"),
            CardData.getCardById("tech_scratch"),
        }
    end
    return {}
end

return CardData
