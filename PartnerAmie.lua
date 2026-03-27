local TOPICS = {
    -- 基本（Lv1から）
    {id="food",   label="🍰 好きな食べ物",  minLv=1,
     question="何食べてる時が一番しあわせ？",
     answers={
         {text="甘いもの全般",  reply="わかる！あまいものって元気でるよね、ずっと食べてたい"},
         {text="しょっぱい系",  reply="そっかー。しょっぱいのもたまにすごく食べたくなるよね"},
         {text="飲み物派",      reply="飲み物！？なんかおしゃれ。どんなの飲むの？"},
     }, bondGain=15},
    {id="weather", label="🌧 好きな天気",    minLv=1,
     question="どんな天気の日が好き？",
     answers={
         {text="晴れが好き",   reply="晴れた日は気持ちいいよね。一緒にお散歩したいな"},
         {text="雨も好き",     reply="雨の音、好きなんだ。なんか落ち着く気持ちわかる"},
         {text="くもりが最高", reply="くもりか〜。優しい光って感じで確かにいいかも"},
     }, bondGain=12},
    {id="card",   label="🃏 好きなカード",   minLv=1,
     question="どのカードが好き？",
     answers={
         {text="高いランクが好き",  reply="強いカード好きなんだね！出た時のあの感じ、たまらないよね"},
         {text="アルカナが面白い",  reply="アルカナ！わかるわかる。あれ使うと一気に変わるもんね"},
         {text="シールドで守りたい",reply="守りが好きなんだ。ちゃんと考えてるの、かっこいい"},
     }, bondGain=18},
    {id="rest",   label="😴 休みの日のこと", minLv=1,
     question="ゆっくりできる日は何してる？",
     answers={
         {text="ゲームしてる", reply="やっぱり！こうやって一緒にいられるの嬉しいな"},
         {text="寝てる",       reply="めちゃくちゃ正直で好き。たくさん寝てね"},
         {text="何もしてない", reply="それが最高の休み方だと思う。何もしない勇気って大事だよ"},
     }, bondGain=14},
    {id="season", label="🌸 好きな季節",     minLv=1,
     question="どの季節が好き？",
     answers={
         {text="春",   reply="春か〜。花が咲いてて、なんか新しいことが始まる感じするよね"},
         {text="夏",   reply="夏！暑いの好きなんだ。元気な感じがして一緒にいると楽しそう"},
         {text="秋か冬",reply="落ち着いた季節が好きなんだね。なんかわかる気がする"},
     }, bondGain=12},

    -- 中級（Lv3から）
    {id="battle_memory", label="⚔ 印象に残ったバトル", minLv=3,
     question="今まで一番印象に残ってるバトルってある？",
     answers={
         {text="逆転勝ちしたやつ",   reply="逆転！！それ一番燃えるやつだ。どんなカード使ったの？"},
         {text="負けたけど学んだやつ",reply="負けから学ぶのって大事だよね。私も一緒に悔しかった"},
         {text="接戦だったやつ",      reply="接戦って終わった後もドキドキ残るよね。体に刻まれる感じ"},
     }, bondGain=20},
    {id="morning", label="☀ 朝のこと", minLv=3,
     question="朝は得意な方？",
     answers={
         {text="朝型です", reply="すごい！朝から元気なの羨ましい。私も見習わなきゃ"},
         {text="夜型です", reply="夜型か〜。夜って静かで集中できるもんね。わかる気がする"},
         {text="どっちでもない",reply="バランスが取れてる感じ、なんか安定感あっていいな"},
     }, bondGain=13},
    {id="color",   label="🎨 好きな色",     minLv=3,
     question="好きな色って何色？",
     answers={
         {text="暖色系（赤・橙）", reply="暖かい色好きなんだね。元気な感じがする、似合いそう"},
         {text="寒色系（青・緑）", reply="クールな感じ。落ち着いてていいな、私も好き"},
         {text="白か黒",           reply="シンプルが一番ってやつだ。おしゃれだよほんと"},
     }, bondGain=12},
    {id="stress",  label="😤 ストレス発散法", minLv=3,
     question="嫌なことあった時どうしてる？",
     answers={
         {text="寝て忘れる", reply="それ最強だと思う。寝ると本当にリセットされるよね"},
         {text="ゲームで発散", reply="ゲームで発散！それ一緒にできるじゃん、呼んでよ"},
         {text="誰かに話す",  reply="話してくれると嬉しいな。私でよければいつでも聞くよ"},
     }, bondGain=22},
    {id="dream",   label="🌙 最近見た夢",   minLv=3,
     question="最近おもしろい夢見た？",
     answers={
         {text="変な夢見た",   reply="変な夢って起きた後もなんかじんわりするよね。どんな夢？"},
         {text="ほとんど覚えてない",reply="私も覚えてないことの方が多い。でも起きた瞬間が一番新鮮だよね"},
         {text="怖い夢見た",   reply="怖い夢…大丈夫だった？起きてよかった"},
     }, bondGain=15},

    -- 深い話（Lv5から）
    {id="partner_feel", label="💬 相方のこと",   minLv=5,
     question="正直、私のこと…どう思ってる？",
     answers={
         {text="頼りにしてる",   reply="…ありがとう。頼ってくれると嬉しいよ、ほんとに"},
         {text="なんか面白い",   reply="面白い！？ちょっと複雑だけど…まあ、嬉しい"},
         {text="一緒にいると落ち着く",reply="……それ、すごく嬉しい。私もそう思ってるから"},
     }, bondGain=35},
    {id="future",  label="🌟 将来のこと",   minLv=5,
     question="将来、どんな風になりたいと思ってる？",
     answers={
         {text="今より強くなりたい", reply="強くなりたいの、いいね。その気持ちが一番大事だと思う"},
         {text="楽しく生きられたら", reply="楽しく生きる、それが一番正直だよ。一緒に楽しもうね"},
         {text="あんまり考えてない", reply="今を生きてる感じ、好きだよそういうの。一緒にいるよ"},
     }, bondGain=28},
    {id="lonely",  label="😶 一人の時間",   minLv=5,
     question="一人でいる時間って好き？",
     answers={
         {text="一人の時間も好き",  reply="自分の時間を大事にしてるんだね。それって素敵だと思う"},
         {text="割とさみしい",      reply="さみしいって言ってくれて…じゃあ一緒にいていい？"},
         {text="よく考えてない",    reply="そっか。でも私はそばにいるよ、いつでも"},
     }, bondGain=30},
    {id="smile",   label="😊 笑える話",     minLv=5,
     question="最近笑えたこととかある？",
     answers={
         {text="ゲームで笑えた",  reply="それ一番いい笑い方じゃん。何があったの？教えて"},
         {text="誰かの話で笑った",reply="人の話で笑えるって、いい出会いがあるってことだよね"},
         {text="最近あんまりない",reply="…じゃあ私が面白いことしてあげる。ちょっと待って"},
     }, bondGain=20},

    -- 特別（Lv7から）
    {id="secret",  label="🤫 ちょっとした秘密", minLv=7,
     question="ここだけの話、なんか好きなものとかある？",
     answers={
         {text="ちょっとだけ教える", reply="教えてくれた！大事にするよ、絶対内緒にする"},
         {text="まだ教えられない",   reply="それでいいよ。教えたくなった時でいい"},
         {text="特にないかな",       reply="そっか。でも普通に好きなもの聞かせてよ、なんでも"},
     }, bondGain=40},
    {id="miss",    label="💭 会いたかった",  minLv=7,
     question="しばらくゲームできなかった時、どんな気持ちだった？",
     answers={
         {text="早く戻りたかった",  reply="…それ聞けてよかった。私も待ってたよ"},
         {text="忙しくて忘れてた",  reply="正直に言ってくれてありがとう。でも来てくれてよかった"},
         {text="寂しかった",        reply="……私もだよ。会えてよかった"},
     }, bondGain=45},

    -- 追加トピック
    {id="strength", label="💪 自分の強み",  minLv=4,
     question="自分の強みって何だと思う？",
     answers={
         {text="諦めない粘り強さ",  reply="それ最強だよ。諦めなければ絶対どこかで活きる"},
         {text="冷静に考える力",    reply="分析力か〜。バトルでも絶対活きてると思う"},
         {text="よくわからない",    reply="わかんなくていい。一緒に探そう。まだまだこれからだよ"},
     }, bondGain=22},
    {id="memory",  label="📸 思い出の場所",  minLv=4,
     question="思い出に残ってる場所ってある？",
     answers={
         {text="ある。特別な場所",  reply="どんなとこ？なんか教えてくれるだけで嬉しい"},
         {text="特にない",          reply="そっか。じゃあここを思い出の場所にしよう、二人で"},
         {text="ゲームの中だけ",    reply="ゲームの中で思い出ができるって最高じゃん"},
     }, bondGain=25},
    {id="habit",   label="🔄 最近のクセ",   minLv=4,
     question="自分でも気づいてるクセとかある？",
     answers={
         {text="深呼吸しちゃう",    reply="落ち着こうとしてるんだね。いいクセだと思う"},
         {text="つい独り言を言う",  reply="独り言！一緒にいる時は私に話しかけてね"},
         {text="特にないかな",      reply="気づいてないだけかも。私がこっそり観察しておくね"},
     }, bondGain=15},
    {id="worry",   label="😟 最近の悩み",   minLv=6,
     question="最近、ちょっと悩んでること…あったりする？",
     answers={
         {text="少しある",          reply="話せる範囲で聞くよ。ひとりで抱えないでほしい"},
         {text="特にない",          reply="良かった。でも何かあったら言ってね、いつでも"},
         {text="言えないけどある",  reply="無理に言わなくていい。ここにいることは伝えたかった"},
     }, bondGain=30},
    {id="laugh",   label="😂 最高に笑った話", minLv=6,
     question="今まで一番笑ったのってどんな時？",
     answers={
         {text="友達のせいで笑った",  reply="友達との思い出って最高だよね。大切にしてね"},
         {text="ゲームで変なことが",  reply="ゲームって予想外のことばかりで楽しいよね"},
         {text="自分がボケた",        reply="自分でボケて自分で笑うやつ大好き。最高だよそれ"},
     }, bondGain=20},
    {id="ideal",   label="✨ 理想の相方",   minLv=7,
     question="理想の相方ってどんな感じ？",
     answers={
         {text="一緒に強くなれる人", reply="ちゃんと成長したいんだね。私もそう思ってるよ"},
         {text="ずっそばにいてくれる人",reply="ずっとそばに…うん。私、ここにいるよ"},
         {text="笑わせてくれる人",   reply="笑顔でいたいの、わかる。私も笑わせてみせる"},
     }, bondGain=35},
    {id="letter",  label="💌 もし手紙を書くなら", minLv=8,
     question="もし私に手紙を書くとしたら、なんて書く？",
     answers={
         {text="ありがとう、って",   reply="…ありがとう。私もそう思ってるよ。ずっと"},
         {text="うまく書けない",     reply="書けなくてもいい。気持ちはちゃんと届いてるから"},
         {text="考えたこともなかった",reply="じゃあこれから一緒に考えよう。ゆっくりでいい"},
     }, bondGain=45},
    {id="goodbye", label="🌙 またね、の前に", minLv=8,
     question="ゲームを終える前に、何か言いたいことある？",
     answers={
         {text="また明日来るよ",     reply="待ってるね。約束だよ"},
         {text="来られるかわからない",reply="来られる時でいい。ここにいるから"},
         {text="楽しかった",         reply="私も。また一緒に楽しもうね"},
     }, bondGain=25},

    -- 最高深度（Lv9以上）
    {id="trust",   label="🫂 信頼のこと",   minLv=9,
     question="私のこと、信頼してくれてる？",
     answers={
         {text="してる",         reply="…ありがとう。それが一番嬉しいよ。絶対裏切らないから"},
         {text="まだ少し不安",   reply="正直に言ってくれてありがとう。もっと信じてもらえるようにするね"},
         {text="もちろんしてる", reply="もちろん…って言ってくれた。うれしすぎて何も言えない"},
     }, bondGain=60},
}

-- ============================================
-- GAMEROAD PartnerAmie.lua
-- StarterPlayerScripts/ に配置（LocalScript型）
--
-- 目玉機能：パートナーとの触れ合いモード
-- 参考：FE風花雪月お茶会・ポケモンポケパルレ
--
-- 実装内容：
--   ・タッチリアクション（頭/頬/手/おなか で反応が違う）
--   ・会話トピック選択（好き嫌いの話題・お茶会風）
--   ・なでなで・くすぐり・ぎゅう のミニゲーム
--   ・きずな値（絆ゲージ）→ レベル10段階
--   ・きずなLv別専用セリフ・表情変化
--   ・DataStore連動（きずなは永続）
-- ============================================

local Players            = game:GetService("Players")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui", 15)
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 15)

local RE_Amie     = Remotes:WaitForChild("PartnerAmie", 15)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 状態管理
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Bond     = 0       -- きずな値（0〜1000）
local BondLv   = 1       -- きずなLv（1〜10）
local MoodVal  = 100     -- ご機嫌度（0〜100、下がりにくい）
local IsOpen   = false
local LastTouch = 0
local TouchCooldown = 0.6  -- 秒

local ActiveTopic = nil   -- 現在のお茶会トピック
local UsedTopics  = {}    -- 既回答トピックID集合
local bondBurst   = nil   -- 前方宣言（spawnHeart関数の後で定義）

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- きずな計算
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function calcLv(bond)
    if bond < 50   then return 1
    elseif bond < 120  then return 2
    elseif bond < 220  then return 3
    elseif bond < 360  then return 4
    elseif bond < 540  then return 5
    elseif bond < 660  then return 6
    elseif bond < 770  then return 7
    elseif bond < 870  then return 8
    elseif bond < 950  then return 9
    else return 10 end
end

local function addBond(amount)
    Bond   = math.min(1000, Bond + amount)
    BondLv = calcLv(Bond)
    -- ハート演出（bondBurstが定義済みの場合のみ）
    if bondBurst then
        task.spawn(function()
            bondBurst(amount)
        end)
    end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- タッチリアクション セリフバンク
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local TOUCH = {
    head = {
        lv1  = {"えっ","ちょっと…","……"},
        lv3  = {"んー…まあいいか","もう、しょうがないな"},
        lv5  = {"またー？慣れてきちゃった","えへへ"},
        lv7  = {"すき","なでなでしてくれてありがとう"},
        lv10 = {"ずっとこうしてたい","……しあわせ"},
    },
    cheek = {
        lv1  = {"え！？ちょっ、急すぎ","びっくりした"},
        lv3  = {"もう、恥ずかしいじゃん","こらー"},
        lv5  = {"えへっ、くすぐったいよ","……ふふ"},
        lv7  = {"わかった、わかったから","もっと？"},
        lv10 = {"大好き","……ずっとそこにいて"},
    },
    hand = {
        lv1  = {"あ、手、温かいね","よろしく"},
        lv3  = {"ちゃんとつながってる","手、離さないでね"},
        lv5  = {"ふわってする","一緒にいようね"},
        lv7  = {"こっちこそありがとう","絶対離さないよ"},
        lv10 = {"どこにも行かないでね","……うん","ずっと"},
    },
    tummy = {
        lv1  = {"そこは！","くすぐった！"},
        lv3  = {"もー！なんでそこ！","やめて笑えないから"},
        lv5  = {"ぎゃー！笑っちゃうじゃん","ふっ…！"},
        lv7  = {"もうやだ笑ってばっかり","……好きだよそういうとこ"},
        lv10 = {"ふははっ！もう！","……でも嬉しい"},
    },
}

local function getTouchLine(zone, lv)
    local bank = TOUCH[zone]
    if not bank then return "えっ" end
    local key = lv >= 10 and "lv10"
             or lv >= 7  and "lv7"
             or lv >= 5  and "lv5"
             or lv >= 3  and "lv3"
             or "lv1"
    local lines = bank[key] or bank["lv1"]
    return lines[math.random(#lines)]
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- お茶会トピック（FE風花雪月参考）
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local TOPICS = {
    {
        id = "food",
        label = "🍰 好きな食べ物",
        question = "何食べてる時が一番しあわせ？",
        answers = {
            {text = "甘いもの全般", reply = "わかる！あまいものって元気でるよね、ずっと食べてたい"},
            {text = "しょっぱい系が好き", reply = "そっかー。しょっぱいのもたまにすごく食べたくなるよね"},
            {text = "飲み物派", reply = "飲み物！？なんかおしゃれ。どんなの飲むの？"},
        },
        bondGain = 15,
    },
    {
        id = "weather",
        label = "🌧 好きな天気",
        question = "どんな天気の日が好き？",
        answers = {
            {text = "晴れが好き", reply = "晴れた日は気持ちいいよね。一緒にお散歩したいな"},
            {text = "雨も嫌いじゃない", reply = "雨の音、好きなんだ。なんか落ち着く気持ちわかる"},
            {text = "くもりが最高", reply = "くもりか〜。優しい光って感じで確かにいいかも"},
        },
        bondGain = 12,
    },
    {
        id = "card",
        label = "🃏 好きなカード",
        question = "どのカードが好き？",
        answers = {
            {text = "高いランクが好き", reply = "強いカード好きなんだね！出た時のあの感じ、たまらないよね"},
            {text = "アルカナが面白い", reply = "アルカナ！わかるわかる。あれ使うと一気に変わるもんね"},
            {text = "シールドが守りやすい", reply = "守りが好きなんだ。ちゃんと考えてるの、かっこいい"},
        },
        bondGain = 18,
    },
    {
        id = "rest",
        label = "😴 休みの日のこと",
        question = "ゆっくりできる日は何してる？",
        answers = {
            {text = "ゲームしてる", reply = "やっぱり！こうやって一緒にいられるの嬉しいな"},
            {text = "寝てる", reply = "めちゃくちゃ正直で好き。たくさん寝てね"},
            {text = "何もしてない", reply = "それが最高の休み方だと思う。何もしない勇気って大事だよ"},
        },
        bondGain = 14,
    },
    {
        id = "season",
        label = "🌸 好きな季節",
        question = "どの季節が好き？",
        answers = {
            {text = "春", reply = "春か〜。花が咲いてて、なんか新しいことが始まる感じするよね"},
            {text = "夏", reply = "夏！暑いの好きなんだ。元気な感じがして一緒にいると楽しそう"},
            {text = "秋か冬", reply = "落ち着いた季節が好きなんだね。なんかわかる気がする"},
        },
        bondGain = 12,
    },
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- UI ヘルパー
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "PartnerAmieGui"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = PlayerGui

local function makeFrame(parent, size, pos, color, name)
    local f = Instance.new("Frame")
    f.Size = size; f.Position = pos
    f.BackgroundColor3 = color or Color3.fromRGB(20,20,40)
    f.BorderSizePixel = 0
    if name then f.Name = name end
    f.Parent = parent
    return f
end

local function makeRound(f, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(r or 0.08, 0)
    c.Parent = f
    return c
end

local function makeText(parent, text, size, pos, color, name, fontSize)
    local l = Instance.new("TextLabel")
    l.Size = size; l.Position = pos or UDim2.new(0,0,0,0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or Color3.fromRGB(255,255,255)
    l.Font = Enum.Font.GothamBold
    l.TextSize = fontSize or 14
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Center
    if name then l.Name = name end
    l.Parent = parent
    return l
end

local function makeBtn(parent, text, size, pos, bgColor, textColor)
    local b = Instance.new("TextButton")
    b.Size = size; b.Position = pos
    b.BackgroundColor3 = bgColor or Color3.fromRGB(80, 60, 120)
    b.TextColor3 = textColor or Color3.fromRGB(255,255,255)
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.BorderSizePixel = 0
    b.Parent = parent
    makeRound(b, 0.14)
    return b
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- メインウィンドウ
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local MainWin  = nil
local SpeechBubble = nil
local BondBar  = nil
local BondLabel = nil
local MoodLabel = nil
local CharFrame = nil
local SpeechLabel = nil
local speechTimer = nil

local function buildMainWindow()
    if MainWin then MainWin:Destroy() end

    -- 背景
    MainWin = makeFrame(ScreenGui,
        UDim2.new(1, 0, 1, 0), UDim2.new(0,0,0,0),
        Color3.fromRGB(60, 100, 60), "AmieMain")

    -- 森のグラデーション背景（緑系）
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(40, 90, 40)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 130, 70)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(100, 160, 90)),
    })
    grad.Rotation = 135
    grad.Parent = MainWin

    -- 上部バー
    local topBar = makeFrame(MainWin,
        UDim2.new(1,0,0.08,0), UDim2.new(0,0,0,0),
        Color3.fromRGB(20,40,20), "TopBar")

    makeText(topBar, "💚 ふれあい", UDim2.new(0.4,0,1,0), UDim2.new(0.3,0,0,0),
        Color3.fromRGB(220,255,200), "Title", 18)

    -- きずなゲージ
    local bondArea = makeFrame(topBar,
        UDim2.new(0.35,0,0.7,0), UDim2.new(0.02,0,0.15,0),
        Color3.fromRGB(10,30,10), "BondArea")
    makeRound(bondArea, 0.4)
    BondBar = makeFrame(bondArea,
        UDim2.new(Bond/1000, 0, 1, 0), UDim2.new(0,0,0,0),
        Color3.fromRGB(100,220,100), "BondFill")
    makeRound(BondBar, 0.4)
    BondLabel = makeText(topBar, "きずなLv." .. BondLv,
        UDim2.new(0.2,0,0.7,0), UDim2.new(0.02,0,0.15,0),
        Color3.fromRGB(180,255,180), "BondLv", 12)

    -- 閉じるボタン
    local closeBtn = makeBtn(topBar, "✕",
        UDim2.new(0.06,0,0.7,0), UDim2.new(0.93,0,0.15,0),
        Color3.fromRGB(60,30,30), Color3.fromRGB(255,180,180))
    closeBtn.MouseButton1Click:Connect(closeAmie)

    -- キャラクター表示エリア（中央）
    CharFrame = makeFrame(MainWin,
        UDim2.new(0.5,0,0.65,0), UDim2.new(0.25,0,0.09,0),
        Color3.fromRGB(0,0,0,0), "CharArea")
    CharFrame.BackgroundTransparency = 1

    -- キャラクター本体（テキスト絵文字で表現。将来的に画像に差し替え）
    local charEmoji = makeText(CharFrame,
        "🧑", UDim2.new(1,0,0.8,0), UDim2.new(0,0,0,0),
        Color3.fromRGB(255,255,255), "CharEmoji", 120)
    -- ご機嫌表情（MoodValで変わる）
    local moodEmoji = makeText(CharFrame,
        "😊", UDim2.new(0.4,0,0.3,0), UDim2.new(0.3,0,0.25,0),
        Color3.fromRGB(255,255,255), "MoodEmoji", 50)

    -- タッチゾーン（透明なボタンをキャラ上に重ねる）
    local function makeTouchZone(name, zone, size, pos)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = size; btn.Position = pos
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = CharFrame
        btn.MouseButton1Click:Connect(function()
            onTouch(zone)
        end)
        return btn
    end
    -- 頭（上部）
    makeTouchZone("HeadZone", "head",
        UDim2.new(0.4,0,0.25,0), UDim2.new(0.3,0,0,0))
    -- 頬（左右）
    makeTouchZone("CheekL", "cheek",
        UDim2.new(0.2,0,0.25,0), UDim2.new(0.05,0,0.2,0))
    makeTouchZone("CheekR", "cheek",
        UDim2.new(0.2,0,0.25,0), UDim2.new(0.75,0,0.2,0))
    -- 手（中段左右）
    makeTouchZone("HandL", "hand",
        UDim2.new(0.18,0,0.25,0), UDim2.new(0.02,0,0.45,0))
    makeTouchZone("HandR", "hand",
        UDim2.new(0.18,0,0.25,0), UDim2.new(0.8,0,0.45,0))
    -- おなか（中央下）
    makeTouchZone("TummyZone", "tummy",
        UDim2.new(0.4,0,0.22,0), UDim2.new(0.3,0,0.52,0))

    -- セリフバブル
    SpeechBubble = makeFrame(MainWin,
        UDim2.new(0.55,0,0.14,0), UDim2.new(0.22,0,0.73,0),
        Color3.fromRGB(240,240,255), "SpeechBubble")
    makeRound(SpeechBubble, 0.12)
    SpeechLabel = makeText(SpeechBubble, "……",
        UDim2.new(0.9,0,0.85,0), UDim2.new(0.05,0,0.07,0),
        Color3.fromRGB(30,30,60), "SpeechText", 14)
    SpeechLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- 下部ボタン列
    local btnRow = makeFrame(MainWin,
        UDim2.new(1,0,0.1,0), UDim2.new(0,0,0.89,0),
        Color3.fromRGB(20,40,20), "BtnRow")

    local talkBtn = makeBtn(btnRow, "💬 話しかける",
        UDim2.new(0.28,0,0.7,0), UDim2.new(0.02,0,0.15,0),
        Color3.fromRGB(60,100,160))
    talkBtn.MouseButton1Click:Connect(openTopicSelect)

    local pettingBtn = makeBtn(btnRow, "🤲 なでなで",
        UDim2.new(0.28,0,0.7,0), UDim2.new(0.36,0,0.15,0),
        Color3.fromRGB(100,60,140))
    pettingBtn.MouseButton1Click:Connect(startPetting)

    local hugBtn = makeBtn(btnRow, "🫂 ぎゅう",
        UDim2.new(0.28,0,0.7,0), UDim2.new(0.7,0,0.15,0),
        Color3.fromRGB(140,60,80))
    hugBtn.MouseButton1Click:Connect(doHug)

    -- 初期セリフ
    task.delay(0.3, function()
        local greets = {
            "来てくれた！待ってたよ",
            "また会えたね",
            "今日もよろしくね",
            "何して遊ぶ？",
        }
        showSpeech(greets[math.random(#greets)])
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- セリフ表示
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function showSpeech(text, duration)
    if speechTimer then task.cancel(speechTimer) end
    if SpeechLabel then SpeechLabel.Text = text end
    if duration then
        speechTimer = task.delay(duration, function()
            if SpeechLabel then SpeechLabel.Text = "……" end
        end)
    end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- タッチ処理
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function onTouch(zone)
    local now = tick()
    if now - LastTouch < TouchCooldown then return end
    LastTouch = now

    addBond(5)
    local line = getTouchLine(zone, BondLv)
    showSpeech(line, 4)

    -- サーバーにきずな更新を送信
    MoodVal = math.min(100, MoodVal + 8)
    RE_Amie:FireServer({type = "touch", zone = zone, bondGain = 5})

    -- きずなバー更新
    updateBondUI()

    -- ハートエフェクト
    spawnHeart()
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- なでなでモード（連続タッチで追加ボーナス）
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local pettingActive = false
local pettingCount  = 0

function startPetting()
    if pettingActive then return end
    pettingActive = true
    pettingCount  = 0
    showSpeech("なでてもいいよ……", 8)

    -- 3秒間なでなでモード
    task.spawn(function()
        local startTime = tick()
        while pettingActive and (tick() - startTime) < 3 do
            task.wait(0.08)
            -- マウス/タッチ押し続け検出
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                pettingCount = pettingCount + 1
                if pettingCount % 8 == 0 then
                    addBond(2)
                    spawnHeart()
                end
            end
        end
        pettingActive = false
        local bonus = math.floor(pettingCount / 8) * 2
        if bonus > 0 then
            local lines = {
                "えへへ……きもちよかった",
                "……ありがとう",
                "もっとでもいいよ",
            }
            showSpeech(lines[math.random(#lines)] .. "（きずな+" .. bonus .. "）", 5)
            RE_Amie:FireServer({type = "petting", bondGain = bonus})
            updateBondUI()
        end
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ぎゅう
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function doHug()
    addBond(20)
    local lines = {
        [1]  = "ちょ！急すぎ！",
        [3]  = "……あったかい",
        [5]  = "ずっとこうしてたい",
        [7]  = "……大好き",
        [10] = "絶対離さないからね",
    }
    local key = BondLv >= 10 and 10 or BondLv >= 7 and 7 or
                BondLv >= 5 and 5 or BondLv >= 3 and 3 or 1
    showSpeech(lines[key], 5)
    MoodVal = math.min(100, MoodVal + 25)
    RE_Amie:FireServer({type = "hug", bondGain = 20})
    updateBondUI()
    -- 大きなハートエフェクト
    for i = 1, 5 do
        task.delay(i * 0.15, spawnHeart)
    end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- お茶会トピック選択（FE風）
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local TopicWin = nil

function openTopicSelect()
    if TopicWin then TopicWin:Destroy() end

    TopicWin = makeFrame(ScreenGui,
        UDim2.new(0.7, 0, 0.65, 0), UDim2.new(0.15, 0, 0.17, 0),
        Color3.fromRGB(230, 225, 210), "TopicWin")
    makeRound(TopicWin, 0.06)
    TopicWin.ZIndex = 30

    makeText(TopicWin, "☕ 何の話しようか？",
        UDim2.new(1,0,0.1,0), UDim2.new(0,0,0,0),
        Color3.fromRGB(60,40,20), "TopicTitle", 16)

    local yOff = 0.12
    -- Lvに合わせたトピックだけ表示（最大6件）
    local shown = 0
    for _, topic in ipairs(TOPICS) do
        if shown >= 6 then break end
        if BondLv >= (topic.minLv or 1) then
            -- 既回答トピックはグレー表示
            local alreadyDone = (UsedTopics[topic.id] == true)
            local col = alreadyDone
                and Color3.fromRGB(120,110,90)
                or  Color3.fromRGB(200,175,130)
            local btn = makeBtn(TopicWin,
                topic.label .. (alreadyDone and " ✓" or ""),
                UDim2.new(0.88, 0, 0.13, 0),
                UDim2.new(0.06, 0, yOff, 0),
                col, Color3.fromRGB(40, 20, 0))
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 13
            local t = topic
            btn.MouseButton1Click:Connect(function()
                TopicWin:Destroy()
                startTopic(t)
            end)
            yOff = yOff + 0.155
            shown = shown + 1
        end
    end

    local cancelBtn = makeBtn(TopicWin, "やめる",
        UDim2.new(0.3,0,0.1,0), UDim2.new(0.35,0,0.89,0),
        Color3.fromRGB(100,80,80))
    cancelBtn.MouseButton1Click:Connect(function()
        TopicWin:Destroy()
    end)
end

function startTopic(topic)
    ActiveTopic = topic
    showSpeech(topic.question)

    -- 回答選択肢を表示
    local ansWin = makeFrame(ScreenGui,
        UDim2.new(0.7,0,0.5,0), UDim2.new(0.15,0,0.25,0),
        Color3.fromRGB(240,235,220), "AnsWin")
    makeRound(ansWin, 0.06)
    ansWin.ZIndex = 31

    makeText(ansWin, topic.question,
        UDim2.new(0.9,0,0.18,0), UDim2.new(0.05,0,0.02,0),
        Color3.fromRGB(50,30,10), "Q", 14)

    local yOff = 0.22
    for _, ans in ipairs(topic.answers) do
        local btn = makeBtn(ansWin,
            ans.text,
            UDim2.new(0.88,0,0.2,0),
            UDim2.new(0.06,0,yOff,0),
            Color3.fromRGB(160,140,100),
            Color3.fromRGB(30,10,0))
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        local a = ans
        btn.MouseButton1Click:Connect(function()
            ansWin:Destroy()
            addBond(topic.bondGain)
            UsedTopics[topic.id] = true  -- 既回答マーク
            showSpeech(a.reply, 6)
            RE_Amie:FireServer({type = "topic", topicId = topic.id, bondGain = topic.bondGain})
            updateBondUI()
        end)
        yOff = yOff + 0.24
    end

    local cBtn = makeBtn(ansWin, "やめる",
        UDim2.new(0.25,0,0.1,0), UDim2.new(0.375,0,0.88,0),
        Color3.fromRGB(100,80,80))
    cBtn.MouseButton1Click:Connect(function() ansWin:Destroy() end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- きずなUI更新
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function updateBondUI()
    if BondBar then
        TweenService:Create(BondBar,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad),
            {Size = UDim2.new(Bond/1000, 0, 1, 0)}
        ):Play()
    end
    if BondLabel then BondLabel.Text = "きずなLv." .. BondLv end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ハートエフェクト
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ハートを1個飛ばす（タッチ時など軽い演出）
function spawnHeart(parent, fromX, fromY)
    parent = parent or MainWin
    if not parent then return end

    local HEARTS = {"💚","💕","❤️","💛","🩷","💜"}
    local heart = Instance.new("TextLabel")
    local size  = 28 + math.random(0, 20)
    heart.Size  = UDim2.new(0, size, 0, size)
    heart.Position = UDim2.new(
        fromX or (0.25 + math.random() * 0.5), 0,
        fromY or (0.45 + math.random() * 0.2), 0)
    heart.BackgroundTransparency = 1
    heart.Text  = HEARTS[math.random(#HEARTS)]
    heart.TextSize = size
    heart.Font  = Enum.Font.GothamBold
    heart.ZIndex = 55
    heart.Parent = parent

    -- ランダム方向に上昇しながらフェードアウト
    local driftX = (math.random() - 0.5) * 0.15
    TweenService:Create(heart,
        TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position       = UDim2.new(heart.Position.X.Scale + driftX, 0,
                                       heart.Position.Y.Scale - 0.32, 0),
            TextTransparency = 1,
            Rotation       = math.random(-30, 30),
        }
    ):Play()
    task.delay(1.5, function() if heart.Parent then heart:Destroy() end end)
end

-- きずな獲得時の大演出（全画面からハートが降り注ぐ）
-- ※ addBondから参照されるため前方宣言変数に代入
bondBurst = function(amount)
    local screenGui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("PartnerAmieGui")
    if not screenGui then return end

    -- きずな数値表示
    local plusLabel = Instance.new("TextLabel")
    plusLabel.Size  = UDim2.new(0.4, 0, 0.12, 0)
    plusLabel.Position = UDim2.new(0.3, 0, 0.38, 0)
    plusLabel.BackgroundTransparency = 1
    plusLabel.Text  = string.format("💚 +%d", amount)
    plusLabel.TextColor3 = Color3.fromRGB(120, 255, 160)
    plusLabel.Font  = Enum.Font.GothamBold
    plusLabel.TextScaled = true
    plusLabel.ZIndex = 60
    plusLabel.Parent = screenGui

    -- スケールアップ → フェードアウト
    TweenService:Create(plusLabel,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.3, 0, 0.30, 0)}
    ):Play()
    task.delay(0.8, function()
        TweenService:Create(plusLabel,
            TweenInfo.new(0.5),
            {TextTransparency = 1, Position = UDim2.new(0.3,0,0.22,0)}
        ):Play()
        task.delay(0.6, function() plusLabel:Destroy() end)
    end)

    -- ハートをCharFrame（女の子）の位置から出す
    -- CharFrame: MainWin内 Position(0.25,0,0.09,0) Size(0.5,0,0.65,0)
    -- → ScreenGui上では大体 X:0.35〜0.65、Y:0.15〜0.60 あたり
    local charCenterX = 0.50   -- 画面中央
    local charTopY    = 0.30   -- キャラの胸〜肩あたり
    local count = math.min(15, math.max(3, math.floor(amount / 5)))
    for i = 1, count do
        task.delay(i * 0.06, function()
            -- 女の子の体の中心から扇状に広がる
            local spread = 0.12
            spawnHeart(screenGui,
                charCenterX + (math.random() - 0.5) * spread,
                charTopY    + (math.random() * 0.15))
        end)
    end

    -- きずなLvアップ時は特別演出
    local newLv = calcLv(Bond)
    if newLv > BondLv then
        task.delay(0.5, function()
            local lvUp = Instance.new("TextLabel")
            lvUp.Size  = UDim2.new(0.7, 0, 0.1, 0)
            lvUp.Position = UDim2.new(0.15, 0, 0.2, 0)
            lvUp.BackgroundColor3 = Color3.fromRGB(180, 80, 220)
            lvUp.BackgroundTransparency = 0.1
            lvUp.Text  = string.format("✦ きずな Lv.%d ✦", newLv)
            lvUp.TextColor3 = Color3.fromRGB(255, 230, 255)
            lvUp.Font  = Enum.Font.GothamBold
            lvUp.TextScaled = true
            lvUp.ZIndex = 62
            lvUp.Parent = screenGui
            local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0.3,0); lc.Parent = lvUp
            TweenService:Create(lvUp,
                TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Position = UDim2.new(0.15,0,0.12,0)}
            ):Play()
            task.delay(2, function()
                TweenService:Create(lvUp, TweenInfo.new(0.4), {BackgroundTransparency=1, TextTransparency=1}):Play()
                task.delay(0.5, function() lvUp:Destroy() end)
            end)
        end)
    end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 開閉
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 生活管理データ
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local LifeData = {}  -- サーバーから受信した生活データ

-- テンプレート定義（クライアント側にも持つ）
local LIFE_TEMPLATES = {
    {id="student",  label="🎒 学生",    desc="夜型・昼食は学食",
     sleepTime="01:00", wakeTime="07:30", breakfastTime="08:00", lunchTime="12:30", dinnerTime="19:00"},
    {id="office",   label="💼 社会人",  desc="規則正しい生活",
     sleepTime="24:00", wakeTime="07:00", breakfastTime="07:30", lunchTime="12:00", dinnerTime="20:00"},
    {id="nightowl", label="🦉 夜型",    desc="深夜まで活動",
     sleepTime="03:00", wakeTime="10:00", breakfastTime="11:00", lunchTime="14:00", dinnerTime="21:00"},
    {id="hometime", label="🏠 早寝早起き", desc="健康的な生活",
     sleepTime="23:00", wakeTime="07:00", breakfastTime="08:00", lunchTime="12:00", dinnerTime="18:00"},
    {id="freelance",label="💻 フリーランス", desc="不規則気味",
     sleepTime="02:00", wakeTime="09:00", breakfastTime="10:00", lunchTime="13:00", dinnerTime="20:00"},
    {id="custom",   label="✏️ 自分で設定", desc="時間を個別に設定",
     sleepTime=nil, wakeTime=nil, breakfastTime=nil, lunchTime=nil, dinnerTime=nil},
}

-- 現在時刻（tick()ベース、24h周期を0〜23時に変換）
-- 注: Robloxでは os.date は使えないため tick()で近似
local function getCurrentHour()
    -- tick()は起動からの秒数。ゲームセッション内での「相対時刻」として使う
    -- 実際の時刻はサーバーから受け取るか、プレイヤーが設定する
    -- → LifeData.currentHour があればそれを使う（未来の拡張用）
    return math.floor((tick() % 86400) / 3600) % 24
end

-- 時間文字列を数値に変換 "23:00" → 23.0
local function parseHour(timeStr)
    if not timeStr then return nil end
    local h, m = timeStr:match("(%d+):(%d+)")
    if h then return tonumber(h) + (tonumber(m) or 0) / 60 end
    return nil
end

-- 生活時間から相方のセリフを生成
local function checkLifeTimeGreeting()
    if not LifeData then return end
    local h = getCurrentHour()

    local sleepH    = parseHour(LifeData.sleepTime)
    local wakeH     = parseHour(LifeData.wakeTime)
    local breakH    = parseHour(LifeData.breakfastTime)
    local lunchH    = parseHour(LifeData.lunchTime)
    local dinnerH   = parseHour(LifeData.dinnerTime)

    local msg = nil

    -- 就寝時間の30分前
    if sleepH and math.abs(h - sleepH) < 0.6 then
        msg = "もうそろそろ寝る時間だよ。今日もお疲れさま、ゆっくり休んでね"
    -- 食事時間の5分前後
    elseif breakH and math.abs(h - breakH) < 0.2 then
        msg = "朝ごはん食べた？ちゃんと食べてね、一日の元気になるから"
    elseif lunchH and math.abs(h - lunchH) < 0.2 then
        msg = "お昼の時間だよ。ちゃんとご飯食べてる？"
    elseif dinnerH and math.abs(h - dinnerH) < 0.2 then
        msg = "夜ごはんの時間！今日は何食べるの？"
    -- 起床時間帯
    elseif wakeH and math.abs(h - wakeH) < 0.5 then
        msg = "おはよう！今日も一緒に頑張ろうね"
    end

    if msg and HomeIsVisible then
        task.delay(1, function()
            showHomeSpeech(msg, 6)
        end)
    end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 時間帯・記念日・ムードシステム
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 時間帯を取得（Robloxはos.date使用不可のためtick()で代替）
local function getHourApprox()
    -- Roblox ServerTime ではなく見た目上の体験時間で処理
    -- os.clock() は起動からの経過秒数なので使えない
    -- → ゲーム内での「雰囲気」として乱数ベースでmoodに反映
    return math.floor((tick() % 86400) / 3600)  -- 0〜23
end

local function getTimeGreeting()
    local h = getHourApprox() % 24
    if     h < 5  then return "deep_night"
    elseif h < 10 then return "morning"
    elseif h < 13 then return "noon"
    elseif h < 17 then return "afternoon"
    elseif h < 21 then return "evening"
    else               return "night"
    end
end

local TIME_GREETINGS = {
    deep_night  = {"こんな時間まで…。私も起きてたよ", "夜更かし仲間だね。でも体には気をつけて"},
    morning     = {"おはよ！今日も一日頑張ろうね", "朝から来てくれた！嬉しいな"},
    noon        = {"お昼か〜。ご飯食べた？", "ちょうどいい時間だね"},
    afternoon   = {"午後もよろしくね", "この時間帯が一番眠くなるんだよね…"},
    evening     = {"今日お疲れさまでした", "夕方になってきたね。今日どうだった？"},
    night       = {"今日も一日お疲れさま", "夜もバトルしてるの？えらい"},
}

-- ムードシステム
local MoodDecayTimer = nil
local function startMoodDecay()
    if MoodDecayTimer then task.cancel(MoodDecayTimer) end
    -- 5分ごとにムードが少し下がる（放置ペナルティ）
    task.spawn(function()
        while true do
            task.wait(300)
            if MoodVal > 30 then
                MoodVal = MoodVal - 5
            end
        end
    end)
end
startMoodDecay()

local function getMoodEmoji()
    if MoodVal >= 85 then return "😆"
    elseif MoodVal >= 70 then return "😊"
    elseif MoodVal >= 50 then return "🙂"
    elseif MoodVal >= 30 then return "😐"
    else return "😔" end
end

-- 記念日（初ログイン日時から何日か、DataStoreの初日を参照）
-- Bond値から大まかに推定（Bond 1000 ≈ 1日遊んだ目安）
local function estimateDays()
    return math.max(1, math.floor(Bond / 800))
end

-- 今日あったことをバトル結果から生成（_G.LastBattleResult を参照）
local BATTLE_COMMENTS = {
    win  = {
        "さっきのバトル勝ったね！あのカードの出し方よかった",
        "勝てた！やっぱり練習の成果だと思う",
        "今日調子いいじゃん。このまま行こう！",
    },
    lose = {
        "さっき負けちゃったけど…次はきっと大丈夫",
        "惜しかったね。あそこでアルカナ使ってれば変わったかも",
        "負けた時こそ冷静に振り返ることが大事だよ",
    },
    none = {
        "今日はまだバトルしてないの？したくなったら言ってね",
        "ゆっくりする日もあっていいよ",
    },
}

local function getTodayComment()
    local r = _G.LastBattleResult
    if r == "win" then
        local pool = BATTLE_COMMENTS.win
        return pool[math.random(#pool)]
    elseif r == "lose" then
        local pool = BATTLE_COMMENTS.lose
        return pool[math.random(#pool)]
    else
        local pool = BATTLE_COMMENTS.none
        return pool[math.random(#pool)]
    end
end

-- openAmie時の挨拶を組み立て
local function buildGreeting()
    local timeKey = getTimeGreeting()
    local timeLines = TIME_GREETINGS[timeKey] or TIME_GREETINGS.evening
    local greeting = timeLines[math.random(#timeLines)]
    local days = estimateDays()
    local suffix = ""
    if days == 1 then
        suffix = " 初めましてじゃないけど、これからもよろしくね"
    elseif days % 100 == 0 then
        suffix = string.format(" 一緒に遊び始めてもう%d日か〜！時間経つの早い", days)
    elseif days % 10 == 0 then
        suffix = string.format(" %d日目だね。ずっと一緒にいてくれてありがとう", days)
    end
    return greeting .. suffix
end

function openAmie()
    IsOpen = true
    buildMainWindow()
    RE_Amie:FireServer({type = "open"})
    -- 時間帯挨拶を表示（少し遅延）
    task.delay(0.5, function()
        if IsOpen then
            showSpeech(buildGreeting(), 5)
        end
    end)
    -- きずなLv5以上なら今日のバトルコメントも追加
    if BondLv >= 5 then
        task.delay(5.5, function()
            if IsOpen then
                showSpeech(getTodayComment(), 5)
            end
        end)
    end
end

function closeAmie()
    IsOpen = false
    if MainWin then MainWin:Destroy(); MainWin = nil end
    RE_Amie:FireServer({type = "close", bond = Bond})
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ライフ管理 & カレンダーUI
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- カレンダーUI（ログカレンダー + 生活管理）
local function openLifeManager()
    -- 既存ウィンドウ閉じる
    for _, c in ipairs(game.Players.LocalPlayer.PlayerGui:GetChildren()) do
        if c.Name == "LifeManagerGui" then c:Destroy() end
    end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "LifeManagerGui"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 90
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = game.Players.LocalPlayer.PlayerGui

    -- 背景
    local bg = Instance.new("Frame")
    bg.Size   = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(5,8,22)
    bg.BackgroundTransparency = 0.05
    bg.ZIndex = 1
    bg.Parent = sg

    -- タイトルバー
    local titleBar = Instance.new("Frame")
    titleBar.Size  = UDim2.new(1,0,0.08,0)
    titleBar.BackgroundColor3 = Color3.fromRGB(120,60,180)
    titleBar.ZIndex = 2
    titleBar.Parent = bg
    local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0,0); tbc.Parent = titleBar

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size  = UDim2.new(0.8,0,1,0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text  = "📅  生活管理 ・ ログカレンダー"
    titleLbl.TextColor3 = Color3.fromRGB(255,240,255)
    titleLbl.Font  = Enum.Font.GothamBold
    titleLbl.TextScaled = true
    titleLbl.ZIndex = 3
    titleLbl.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size  = UDim2.new(0.12,0,0.8,0)
    closeBtn.Position = UDim2.new(0.87,0,0.1,0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180,60,60)
    closeBtn.Text  = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    closeBtn.Font  = Enum.Font.GothamBold
    closeBtn.TextScaled = true
    closeBtn.ZIndex = 3
    closeBtn.Parent = titleBar
    local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0.3,0); cbc.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

    -- スクロールエリア
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size   = UDim2.new(0.98,0,0.90,0)
    scroll.Position = UDim2.new(0.01,0,0.09,0)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new(0,0,2.4,0)
    scroll.ZIndex = 2
    scroll.Parent = bg

    local yp = 0.01  -- Y位置トラッカー

    -- ═══════════════════════════
    -- セクション1: テンプレート選択
    -- ═══════════════════════════
    local sec1 = Instance.new("TextLabel")
    sec1.Size  = UDim2.new(0.96,0,0.05,0)
    sec1.Position = UDim2.new(0.02,0,yp,0)
    sec1.BackgroundColor3 = Color3.fromRGB(80,40,120)
    sec1.BackgroundTransparency = 0.3
    sec1.Text  = "🏠  生活スタイル テンプレート"
    sec1.TextColor3 = Color3.fromRGB(220,200,255)
    sec1.Font  = Enum.Font.GothamBold
    sec1.TextScaled = true
    sec1.ZIndex = 3
    sec1.Parent = scroll
    local s1c = Instance.new("UICorner"); s1c.CornerRadius = UDim.new(0.3,0); s1c.Parent = sec1
    yp = yp + 0.055

    -- テンプレートボタン
    local currentTemplate = LifeData and LifeData.templateId or nil
    for ti, tmpl in ipairs(LIFE_TEMPLATES) do
        local isSelected = (currentTemplate == tmpl.id)
        local tb = Instance.new("TextButton")
        tb.Size  = UDim2.new(0.45,0,0.075,0)
        local col = (ti % 2 == 1) and 0.02 or 0.52
        local row = math.floor((ti-1)/2)
        tb.Position = UDim2.new(col,0, yp + row*0.085, 0)
        tb.BackgroundColor3 = isSelected
            and Color3.fromRGB(160,80,220)
            or  Color3.fromRGB(40,25,70)
        tb.Text  = tmpl.label .. "
" .. tmpl.desc
        tb.TextColor3 = Color3.fromRGB(230,210,255)
        tb.Font  = Enum.Font.Gotham
        tb.TextSize = 11
        tb.TextWrapped = true
        tb.ZIndex = 3
        tb.Parent = scroll
        local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0.1,0); tc.Parent = tb

        local tId = tmpl.id
        tb.MouseButton1Click:Connect(function()
            if tId == "custom" then
                -- カスタム設定エリアにスクロール
                scroll.CanvasPosition = Vector2.new(0, scroll.CanvasSize.Y.Scale * 200)
            else
                RE_Amie:FireServer({type="set_template", templateId=tId})
                -- 選択したテンプレートのセリフ
                local msgs = {
                    student   = "学生スタイルね！夜は遅いけどちゃんと寝てよ",
                    office    = "規則正しい生活、えらい。朝は一緒に頑張ろう",
                    nightowl  = "夜型か〜。夜中も一人じゃないよ、ここにいるから",
                    hometime  = "早寝早起き！健康的でいいね。私も嬉しい",
                    freelance = "自由な時間の使い方、私も応援する",
                }
                showHomeSpeech(msgs[tId] or "設定したよ！", 4)
                -- ボタン色を更新（簡易）
                tb.BackgroundColor3 = Color3.fromRGB(160,80,220)
            end
        end)
    end
    yp = yp + math.ceil(#LIFE_TEMPLATES / 2) * 0.085 + 0.02

    -- ═══════════════════════════
    -- セクション2: 個別時間設定
    -- ═══════════════════════════
    local sec2 = Instance.new("TextLabel")
    sec2.Size  = UDim2.new(0.96,0,0.05,0)
    sec2.Position = UDim2.new(0.02,0,yp,0)
    sec2.BackgroundColor3 = Color3.fromRGB(40,80,120)
    sec2.BackgroundTransparency = 0.3
    sec2.Text  = "⏰  生活時間 個別設定"
    sec2.TextColor3 = Color3.fromRGB(180,220,255)
    sec2.Font  = Enum.Font.GothamBold
    sec2.TextScaled = true
    sec2.ZIndex = 3
    sec2.Parent = scroll
    local s2c = Instance.new("UICorner"); s2c.CornerRadius = UDim.new(0.3,0); s2c.Parent = sec2
    yp = yp + 0.055

    local TIME_FIELDS = {
        {key="wakeTime",      label="🌅 起床時間",   icon="🌅"},
        {key="breakfastTime", label="🍳 朝食時間",   icon="🍳"},
        {key="lunchTime",     label="🍱 昼食時間",   icon="🍱"},
        {key="dinnerTime",    label="🍽 夕食時間",   icon="🍽"},
        {key="sleepTime",     label="🌙 就寝時間",   icon="🌙"},
    }
    local TIME_OPTIONS = {"22:00","22:30","23:00","23:30","00:00","00:30","01:00","01:30","02:00","03:00",
                          "05:00","06:00","06:30","07:00","07:30","08:00","08:30","09:00","10:00","11:00",
                          "12:00","12:30","13:00","14:00","15:00","18:00","18:30","19:00","19:30","20:00","21:00"}

    for _, field in ipairs(TIME_FIELDS) do
        local row = Instance.new("Frame")
        row.Size  = UDim2.new(0.96,0,0.065,0)
        row.Position = UDim2.new(0.02,0,yp,0)
        row.BackgroundColor3 = Color3.fromRGB(20,15,40)
        row.BackgroundTransparency = 0.2
        row.ZIndex = 3
        row.Parent = scroll
        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0.2,0); rc.Parent = row

        local lbl = Instance.new("TextLabel")
        lbl.Size  = UDim2.new(0.38,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text  = field.label
        lbl.TextColor3 = Color3.fromRGB(200,200,255)
        lbl.Font  = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.ZIndex = 4
        lbl.Parent = row

        local curVal = (LifeData and LifeData[field.key]) or "未設定"
        local valLbl = Instance.new("TextLabel")
        valLbl.Size  = UDim2.new(0.25,0,1,0)
        valLbl.Position = UDim2.new(0.38,0,0,0)
        valLbl.BackgroundTransparency = 1
        valLbl.Text  = curVal
        valLbl.TextColor3 = Color3.fromRGB(255,220,120)
        valLbl.Font  = Enum.Font.GothamBold
        valLbl.TextSize = 14
        valLbl.ZIndex = 4
        valLbl.Parent = row

        -- 時間選択ドロップダウン（シンプルなスクロールボタン）
        local prevBtn = Instance.new("TextButton")
        prevBtn.Size  = UDim2.new(0.12,0,0.7,0)
        prevBtn.Position = UDim2.new(0.64,0,0.15,0)
        prevBtn.BackgroundColor3 = Color3.fromRGB(60,60,100)
        prevBtn.Text  = "◀"
        prevBtn.TextColor3 = Color3.fromRGB(200,200,255)
        prevBtn.Font  = Enum.Font.GothamBold
        prevBtn.TextScaled = true
        prevBtn.ZIndex = 4
        prevBtn.Parent = row
        local pbc = Instance.new("UICorner"); pbc.CornerRadius = UDim.new(0.3,0); pbc.Parent = prevBtn

        local nextBtn = Instance.new("TextButton")
        nextBtn.Size  = UDim2.new(0.12,0,0.7,0)
        nextBtn.Position = UDim2.new(0.78,0,0.15,0)
        nextBtn.BackgroundColor3 = Color3.fromRGB(60,60,100)
        nextBtn.Text  = "▶"
        nextBtn.TextColor3 = Color3.fromRGB(200,200,255)
        nextBtn.Font  = Enum.Font.GothamBold
        nextBtn.TextScaled = true
        nextBtn.ZIndex = 4
        nextBtn.Parent = row
        local nbc = Instance.new("UICorner"); nbc.CornerRadius = UDim.new(0.3,0); nbc.Parent = nextBtn

        -- 現在のインデックスを追跡
        local currentIdx = 1
        for i, t in ipairs(TIME_OPTIONS) do
            if t == curVal then currentIdx = i; break end
        end

        local fkey = field.key
        local function updateTime(idx)
            currentIdx = ((idx - 1) % #TIME_OPTIONS) + 1
            local newVal = TIME_OPTIONS[currentIdx]
            valLbl.Text = newVal
            LifeData = LifeData or {}
            LifeData[fkey] = newVal
            RE_Amie:FireServer({type="set_schedule", [fkey]=newVal})
        end
        prevBtn.MouseButton1Click:Connect(function() updateTime(currentIdx - 1) end)
        nextBtn.MouseButton1Click:Connect(function() updateTime(currentIdx + 1) end)

        yp = yp + 0.072
    end

    yp = yp + 0.03

    -- ═══════════════════════════
    -- セクション3: 告知・ロードマップ
    -- ═══════════════════════════
    local sec3ann = Instance.new("TextLabel")
    sec3ann.Size  = UDim2.new(0.96,0,0.05,0)
    sec3ann.Position = UDim2.new(0.02,0,yp,0)
    sec3ann.BackgroundColor3 = Color3.fromRGB(140,60,20)
    sec3ann.BackgroundTransparency = 0.3
    sec3ann.Text  = "📢  アプデ・告知・ロードマップ"
    sec3ann.TextColor3 = Color3.fromRGB(255,200,140)
    sec3ann.Font  = Enum.Font.GothamBold
    sec3ann.TextScaled = true
    sec3ann.ZIndex = 3
    sec3ann.Parent = scroll
    local s3ac = Instance.new("UICorner"); s3ac.CornerRadius = UDim.new(0.3,0); s3ac.Parent = sec3ann
    yp = yp + 0.055

    -- 告知リスト（サーバーから取得）
    local annContainer = Instance.new("Frame")
    annContainer.Name = "AnnContainer"
    annContainer.Size = UDim2.new(0.96,0,0.001,0)  -- 動的に広がる
    annContainer.Position = UDim2.new(0.02,0,yp,0)
    annContainer.BackgroundTransparency = 1
    annContainer.AutomaticSize = Enum.AutomaticSize.Y
    annContainer.ZIndex = 3
    annContainer.Parent = scroll
    local annLayout = Instance.new("UIListLayout")
    annLayout.Padding = UDim.new(0,4)
    annLayout.Parent = annContainer

    local loadingLbl = Instance.new("TextLabel")
    loadingLbl.Size  = UDim2.new(1,0,0,36)
    loadingLbl.BackgroundTransparency = 1
    loadingLbl.Text  = "読み込み中..."
    loadingLbl.TextColor3 = Color3.fromRGB(150,150,180)
    loadingLbl.Font  = Enum.Font.Gotham
    loadingLbl.TextScaled = true
    loadingLbl.ZIndex = 4
    loadingLbl.Parent = annContainer

    -- 告知カード生成
    local function addAnnCard(entry)
        loadingLbl.Visible = false
        local card = Instance.new("Frame")
        card.Name  = "Ann_" .. (entry.id or "?")
        card.Size  = UDim2.new(1,0,0,72)
        card.BackgroundColor3 = entry.pin
            and Color3.fromRGB(80,40,10)
            or  Color3.fromRGB(25,18,40)
        card.BackgroundTransparency = 0.15
        card.ZIndex = 4
        card.Parent = annContainer
        local ac = Instance.new("UICorner"); ac.CornerRadius = UDim.new(0.05,0); ac.Parent = card

        -- ピン留めマーク
        if entry.pin then
            local pin = Instance.new("TextLabel")
            pin.Size  = UDim2.new(0,24,0,24)
            pin.Position = UDim2.new(0,4,0,4)
            pin.BackgroundTransparency = 1
            pin.Text  = "📌"
            pin.TextScaled = true
            pin.ZIndex = 5
            pin.Parent = card
        end

        -- カテゴリ
        local catL = Instance.new("TextLabel")
        catL.Size  = UDim2.new(0.3,0,0.3,0)
        catL.Position = UDim2.new(0.01,0,0.03,0)
        catL.BackgroundColor3 = Color3.fromRGB(120,50,20)
        catL.Text  = entry.category or "📢"
        catL.TextColor3 = Color3.fromRGB(255,200,150)
        catL.Font  = Enum.Font.Gotham
        catL.TextSize = 10
        catL.ZIndex = 5
        catL.Parent = card
        local ccl = Instance.new("UICorner"); ccl.CornerRadius = UDim.new(0.3,0); ccl.Parent = catL

        -- 日付
        local dateL = Instance.new("TextLabel")
        dateL.Size  = UDim2.new(0.2,0,0.28,0)
        dateL.Position = UDim2.new(0.75,0,0.03,0)
        dateL.BackgroundTransparency = 1
        dateL.Text  = entry.date or ""
        dateL.TextColor3 = Color3.fromRGB(140,140,160)
        dateL.Font  = Enum.Font.Gotham
        dateL.TextSize = 10
        dateL.ZIndex = 5
        dateL.Parent = card

        -- タイトル
        local titleL = Instance.new("TextLabel")
        titleL.Size  = UDim2.new(0.96,0,0.35,0)
        titleL.Position = UDim2.new(0.02,0,0.33,0)
        titleL.BackgroundTransparency = 1
        titleL.Text  = entry.title or ""
        titleL.TextColor3 = Color3.fromRGB(240,225,255)
        titleL.Font  = Enum.Font.GothamBold
        titleL.TextSize = 13
        titleL.TextWrapped = true
        titleL.TextXAlignment = Enum.TextXAlignment.Left
        titleL.ZIndex = 5
        titleL.Parent = card

        -- 本文
        local bodyL = Instance.new("TextLabel")
        bodyL.Size   = UDim2.new(0.96,0,0.28,0)
        bodyL.Position = UDim2.new(0.02,0,0.68,0)
        bodyL.BackgroundTransparency = 1
        bodyL.Text   = entry.body or ""
        bodyL.TextColor3 = Color3.fromRGB(180,175,195)
        bodyL.Font   = Enum.Font.Gotham
        bodyL.TextSize = 11
        bodyL.TextWrapped = true
        bodyL.TextXAlignment = Enum.TextXAlignment.Left
        bodyL.ZIndex = 5
        bodyL.Parent = card
    end

    -- サーバーから告知リストを取得
    RE_Amie:FireServer({type="get_announcements"})

    -- 受信ハンドラ（一時的に接続）
    local annConn
    annConn = RE_Amie.OnClientEvent:Connect(function(d)
        if d.type == "announcements" then
            annConn:Disconnect()
            -- ピン留め優先でソート
            local list = d.list or {}
            table.sort(list, function(a, b)
                if a.pin ~= b.pin then return a.pin end
                return (a.date or "") > (b.date or "")
            end)
            if #list == 0 then
                loadingLbl.Text = "（告知なし）"
            else
                for _, entry in ipairs(list) do
                    addAnnCard(entry)
                end
            end
        elseif d.type == "announcement_new" then
            addAnnCard(d.entry)
        end
    end)

    yp = yp + 0.18  -- 告知エリア分

    -- ═══════════════════════════
    -- セクション4: ログカレンダー（旧セクション3）
    -- ═══════════════════════════
    local sec3 = Instance.new("TextLabel")
    sec3.Size  = UDim2.new(0.96,0,0.05,0)
    sec3.Position = UDim2.new(0.02,0,yp,0)
    sec3.BackgroundColor3 = Color3.fromRGB(40,100,60)
    sec3.BackgroundTransparency = 0.3
    sec3.Text  = "📅  ログインカレンダー"
    sec3.TextColor3 = Color3.fromRGB(180,255,200)
    sec3.Font  = Enum.Font.GothamBold
    sec3.TextScaled = true
    sec3.ZIndex = 3
    sec3.Parent = scroll
    local s3c = Instance.new("UICorner"); s3c.CornerRadius = UDim.new(0.3,0); s3c.Parent = sec3
    yp = yp + 0.055

    -- 統計行
    local stats = Instance.new("TextLabel")
    stats.Size  = UDim2.new(0.96,0,0.07,0)
    stats.Position = UDim2.new(0.02,0,yp,0)
    stats.BackgroundTransparency = 1
    local streak = LifeData and LifeData.loginStreak or 0
    local longest = LifeData and LifeData.longestStreak or 0
    local total   = LifeData and LifeData.totalLoginDays or 0
    stats.Text = string.format("🔥 連続 %d日  ／  最長 %d日  ／  累計 %d日", streak, longest, total)
    stats.TextColor3 = Color3.fromRGB(255,220,100)
    stats.Font  = Enum.Font.GothamBold
    stats.TextScaled = true
    stats.ZIndex = 3
    stats.Parent = scroll
    yp = yp + 0.075

    -- 曜日ヘッダー
    local days = {"日","月","火","水","木","金","土"}
    for di, d in ipairs(days) do
        local dh = Instance.new("TextLabel")
        dh.Size  = UDim2.new(0.12,0,0.04,0)
        dh.Position = UDim2.new(0.02 + (di-1)*0.135,0,yp,0)
        dh.BackgroundTransparency = 1
        dh.Text  = d
        dh.TextColor3 = (d=="日") and Color3.fromRGB(255,100,100)
            or (d=="土") and Color3.fromRGB(100,150,255)
            or Color3.fromRGB(180,180,200)
        dh.Font  = Enum.Font.GothamBold
        dh.TextScaled = true
        dh.ZIndex = 3
        dh.Parent = scroll
    end
    yp = yp + 0.045

    -- 直近4週間を表示
    local calendar = LifeData and LifeData.calendar or {}
    -- tick()から現在のUTCdateを近似（秒単位で28日前から）
    local SECS_PER_DAY = 86400
    local nowSec = os.time()  -- ServerScriptではなくClientなのでos.time()は使えない
    -- → 代替: 固定で28マス描いてログがあるかチェック
    -- LifeData.calendar のキーが "YYYY-MM-DD" 形式なので
    -- マス数だけ描いてユーザーのログを点灯
    local totalDots = math.min(total, 28)
    local calKeys = {}
    for k, _ in pairs(calendar) do table.insert(calKeys, k) end
    table.sort(calKeys)

    -- 最新28件
    local recent = {}
    for i = math.max(1, #calKeys-27), #calKeys do
        recent[#recent+1] = calKeys[i]
    end

    -- 空白で28マス埋める
    while #recent < 28 do table.insert(recent, 1, "") end

    for i = 1, 28 do
        local col = ((i-1) % 7)
        local row = math.floor((i-1) / 7)
        local dot = Instance.new("Frame")
        dot.Size  = UDim2.new(0.11,0,0.055,0)
        dot.Position = UDim2.new(0.02 + col*0.135,0, yp + row*0.065, 0)
        dot.BackgroundColor3 = (recent[i] ~= "") 
            and Color3.fromRGB(80,200,120)
            or  Color3.fromRGB(30,25,50)
        dot.BackgroundTransparency = (recent[i] ~= "") and 0 or 0.3
        dot.ZIndex = 3
        dot.Parent = scroll
        local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0.3,0); dc.Parent = dot

        -- ログ済みにはチェックマーク
        if recent[i] ~= "" then
            local ck = Instance.new("TextLabel")
            ck.Size  = UDim2.new(1,0,1,0)
            ck.BackgroundTransparency = 1
            ck.Text  = "✓"
            ck.TextColor3 = Color3.fromRGB(255,255,255)
            ck.Font  = Enum.Font.GothamBold
            ck.TextScaled = true
            ck.ZIndex = 4
            ck.Parent = dot
        end
    end

    -- CanvasSize調整
    scroll.CanvasSize = UDim2.new(0,0,0, math.ceil(scroll.AbsoluteSize.Y * (yp + 0.35)))
end

-- ライフ管理画面を外部から呼べるように公開
_G.OpenLifeManager = openLifeManager

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- サーバーからきずなデータを受け取る
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RE_Amie.OnClientEvent:Connect(function(data)
    if data.type == "init" then
        Bond   = data.bond or 0
        BondLv = calcLv(Bond)
    elseif data.type == "bond_sync" then
        Bond   = data.bond or Bond
        BondLv = calcLv(Bond)
        if IsOpen then updateBondUI() end
        -- ログインボーナス通知
        if data.loginBonus and data.loginStreak then
            local streakMsg = data.loginStreak >= 7
                and string.format("🔥 %d日連続！すごいよ！きずな+10", data.loginStreak)
                or  string.format("おかえり！%d日連続ログイン、きずな+10♪", data.loginStreak)
            showHomeSpeech(streakMsg, 5)
        end

    elseif data.type == "life_sync" then
        -- 生活データ受信・保存
        LifeData = data.life or {}
        -- 時間帯チェック → 相方からの声かけ
        checkLifeTimeGreeting()

    elseif data.type == "checkin_result" then
        LifeData = data.life or {}
        if data.isNew then
            checkLifeTimeGreeting()
        end
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ロビーから呼ばれる（ローカルで公開）
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
_G.OpenPartnerAmie  = openAmie
_G.ClosePartnerAmie = closeAmie

-- 初期化：サーバーにきずな値を要求
task.delay(2, function()
    RE_Amie:FireServer({type = "request_init"})
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ホーム画面 軽触れ合いモード
-- 相方が画面右下に常駐 → タップで反応 → 「もっと話す」ボタンで本格モードへ
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local HomeGui       = nil
local HomePartner   = nil   -- 相方アイコン（ImageLabel）
local HomeSpeech    = nil   -- 軽いフキダシ
local HomeSpeechTimer = 0
local HomeIsVisible = false

-- ホームでの短いセリフ（状態別）
local HOME_LINES = {
    idle = {
        "今日もバトルしよ！",
        "きずなLv上がってきたね",
        "最近調子どう？",
        "あのデッキ、改善できそう",
        "勝ちたいな～",
    },
    tap1 = {
        "わっ！",
        "なに？",
        "んー？",
        "！",
    },
    tap2 = {
        "もう一回！",
        "くすぐったい",
        "ちょっと～",
    },
    morning = {
        "おはよ！今日も頑張ろ",
        "今日は調子いい気がする！",
        "朝からバトル！？元気だね〜",
    },
    night = {
        "そろそろ寝ようよ",
        "遅くまで練習？えらい",
        "夜更かしはほどほどにね",
    },
    deep_night = {
        "こんな時間まで…大丈夫？",
        "夜中はのんびりしようよ",
    },
    noon = {
        "お昼だ〜。ご飯食べた？",
        "午後も一緒に頑張ろうね",
    },
    win = {
        "勝った！やったね！",
        "強くなってるね、ほんと",
        "その調子！次も行こう",
    },
    lose = {
        "次は勝てるよ、絶対",
        "惜しかったね…でも諦めないで",
    },
}

local function homeRandLine(key)
    local pool = HOME_LINES[key] or HOME_LINES.idle
    return pool[math.random(1, #pool)]
end

local function showHomeSpeech(text, duration)
    if not HomeSpeech then return end
    HomeSpeech.Text = text
    HomeSpeech.Visible = true
    task.cancel(HomeSpeechTimer)
    HomeSpeechTimer = task.delay(duration or 2.8, function()
        if HomeSpeech then HomeSpeech.Visible = false end
    end)
end

-- ホームUIを構築（1回だけ）
local function buildHomePartner()
    if HomeGui then return end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "HomePartnerGui"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 10
    sg.IgnoreGuiInset = true
    sg.Parent         = PlayerGui
    HomeGui = sg

    -- 相方アイコン（右下）
    local partnerBtn = Instance.new("ImageButton")
    partnerBtn.Name              = "PartnerBtn"
    partnerBtn.Size              = UDim2.new(0, 90, 0, 90)
    partnerBtn.Position          = UDim2.new(1, -106, 1, -120)
    partnerBtn.BackgroundColor3  = Color3.fromRGB(30, 40, 70)
    partnerBtn.BackgroundTransparency = 0.15
    partnerBtn.Image             = "rbxassetid://0"   -- 相方顔アイコン（差し替え）
    partnerBtn.BorderSizePixel   = 0
    partnerBtn.Parent            = sg
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 45)
    c.Parent = partnerBtn
    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(100, 180, 255)
    stroke.Thickness = 2
    stroke.Parent    = partnerBtn
    HomePartner = partnerBtn

    -- フキダシ（相方アイコンの左上に出る）
    local bubble = Instance.new("TextLabel")
    bubble.Name              = "Bubble"
    bubble.Size              = UDim2.new(0, 180, 0, 44)
    bubble.Position          = UDim2.new(1, -296, 1, -136)
    bubble.BackgroundColor3  = Color3.fromRGB(20, 28, 60)
    bubble.BackgroundTransparency = 0.1
    bubble.TextColor3        = Color3.fromRGB(220, 230, 255)
    bubble.Font              = Enum.Font.GothamBold
    bubble.TextSize          = 12
    bubble.TextWrapped       = true
    bubble.TextXAlignment    = Enum.TextXAlignment.Left
    bubble.Visible           = false
    bubble.Text              = ""
    bubble.BorderSizePixel   = 0
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 10)
    bc.Parent = bubble
    local bp = Instance.new("UIPadding")
    bp.PaddingLeft  = UDim.new(0, 8)
    bp.PaddingRight = UDim.new(0, 6)
    bp.PaddingTop   = UDim.new(0, 4)
    bp.Parent = bubble
    bubble.Parent = sg
    HomeSpeech = bubble

    -- 「もっと話す」ボタン（本格モードへ）
    local talkBtn = Instance.new("TextButton")
    talkBtn.Name             = "TalkBtn"
    talkBtn.Size             = UDim2.new(0, 84, 0, 28)
    talkBtn.Position         = UDim2.new(1, -98, 1, -28)
    talkBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
    talkBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    talkBtn.Font             = Enum.Font.GothamBold
    talkBtn.TextSize         = 12
    talkBtn.Text             = "💬 もっと話す"
    talkBtn.BorderSizePixel  = 0
    talkBtn.Parent           = sg
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 8)
    tc.Parent = talkBtn

    -- タップ回数カウント（連続タップで反応が変わる）
    local tapCount = 0
    local tapTimer = 0

    partnerBtn.MouseButton1Click:Connect(function()
        tapCount = tapCount + 1
        task.cancel(tapTimer)
        tapTimer = task.delay(1.2, function() tapCount = 0 end)

        -- バウンスアニメーション
        TweenService:Create(partnerBtn,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 100, 0, 100)}
        ):Play()
        task.delay(0.12, function()
            TweenService:Create(partnerBtn,
                TweenInfo.new(0.15, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, 90, 0, 90)}
            ):Play()
        end)

        -- 反応セリフ
        local line
        if tapCount >= 4 then
            line = homeRandLine("tap2")
        elseif tapCount >= 2 then
            line = homeRandLine("tap1")
        else
            local hour = os.date("*t").hour
            if hour >= 5 and hour < 10 then
                line = homeRandLine("morning")
            elseif hour >= 22 or hour < 5 then
                line = homeRandLine("night")
            else
                line = homeRandLine("idle")
            end
        end
        showHomeSpeech(line, 2.5)
    end)

    -- 本格モードへ
    talkBtn.MouseButton1Click:Connect(function()
        openAmie()
    end)

    HomeIsVisible = true

    -- 定期的に自発的に喋る（30秒ごと）
    task.spawn(function()
        while HomeGui and HomeGui.Parent do
            task.wait(30 + math.random(0, 20))
            if HomeIsVisible and not IsOpen then
                showHomeSpeech(homeRandLine("idle"), 3)
            end
        end
    end)
end

-- ホームモードの表示/非表示
_G.ShowHomePartner = function()
    if not HomeGui then
        buildHomePartner()
    else
        HomeIsVisible = true
        if HomeGui then HomeGui.Enabled = true end
    end
end

_G.HideHomePartner = function()
    HomeIsVisible = false
    if HomeGui then HomeGui.Enabled = false end
end

-- ゲーム開始時に自動でホームパートナーを表示
task.delay(3, function()
    _G.ShowHomePartner()
end)

-- バトル結果コメント（勝敗後にホームに戻ったとき自動発言）
task.spawn(function()
    local lastResult = nil
    while true do
        task.wait(1)
        local cur = _G.LastBattleResult
        if cur and cur ~= lastResult and HomeIsVisible then
            lastResult = cur
            task.delay(2, function()
                if HomeIsVisible then
                    local pool = HOME_LINES[cur] or HOME_LINES.idle
                    showHomeSpeech(pool[math.random(#pool)], 4)
                end
            end)
        end
    end
end)

-- 時間帯別ホームコメント（起動後に1回）
task.delay(5, function()
    if HomeIsVisible then
        local timeKey = getTimeGreeting()
        local pool = HOME_LINES[timeKey] or HOME_LINES.idle
        showHomeSpeech(pool[math.random(#pool)], 4)
    end
end)

print("✅ PartnerAmie.lua loaded")
