-- SetupRemotes_v2.lua
-- ReplicatedStorage/ に配置（ModuleScript型）
-- Initializerが require() → setup() で起動する

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function setup()
    local Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = ReplicatedStorage

    local function re(name)
        local r = Instance.new("RemoteEvent")
        r.Name = name
        r.Parent = Remotes
    end
    local function rf(name)
        local r = Instance.new("RemoteFunction")
        r.Name = name
        r.Parent = Remotes
    end

    -- ── バトル基本フロー ──
    re("BattleStart")           -- Server→Client  試合開始
    re("BattleEnd")             -- Server→Client  試合終了
    re("GameOver")              -- Server→Client  勝敗結果
    re("UpdateBoard")           -- Server→Client  盤面更新
    re("PhaseChanged")          -- Server→Client  フェーズ通知 {phase, ...}
    re("CardPlayed")            -- Server→Client  カード出した演出
    re("ShieldAttacked")        -- Server→Client  シールド攻撃演出
    re("ColumnUpdated")         -- Server→Client  列更新演出
    re("OpponentFX")            -- Server→Client  相手演出（デフォルトOFF）

    -- ── プレイヤー入力 ──
    re("RoadSelect")            -- Client→Server  ロードカード選択
    re("BattleSelect")          -- Client→Server  バトルカード選択
    re("ArcanaSelect")          -- Client→Server  アルカナ選択（旧・互換用）
    re("TargetSelect")          -- Client→Server  シールド攻撃対象選択
    re("EXSet")                 -- Client→Server  EXセット {arcanaId, techId, hand}
    re("DinoDeclare")           -- Client→Server  じゃんけん手宣言（将来用）

    -- ── マッチメイキング ──
    re("MatchmakingJoin")       -- Client→Server  キュー参加
    re("MatchmakingCancel")
    re("FriendRoom")              -- フレンド対戦（あいことば）
    re("Observe")                 -- 観戦モード
    re("DeckRecipe")              -- デッキレシピ公開     -- Client→Server  キュー離脱
    re("MatchFound")            -- Server→Client  マッチ成立通知

    -- ── デッキ管理 ──
    re("SaveDeck")              -- Client→Server  {libId, main[], ex[], oshi}
    re("LoadDeck")              -- Client→Server  libId番号
    re("DeckLoaded")            -- Server→Client  デッキデータ返却
    re("OpenDeckEdit")          -- Server→Client  デッキ編集画面を開く
    re("SaveBattleSet")
    re("LoadBattleSet")           -- Client→Server バトルセット要求         -- Client→Server  {slot1libId, slot2libId}
    re("BattleSetLoaded")       -- Server→Client  バトルセット返却 {slot1, slot2}
    re("OpenBattleSet")         -- Server→Client  バトルセット画面を開く
    re("SetDeckSkin")           -- Client→Server  スキン設定
    rf("GetDeckSlots")          -- Client→Server  デッキスロット取得（RemoteFunction）
    rf("GetLibraryNames")       -- Client→Server  ライブラリ1〜8のデッキ名取得（RemoteFunction）
    rf("GetOwnedSkinsForCard")  -- Client→Server  カード用所持スキン一覧取得（RemoteFunction）

    -- ── カード詳細・投票 ──
    re("OpenCardDetail")        -- Server→Client  {card, voteData, ticketCount}
    re("CardVote")              -- Client→Server  {cardId, dir:"up"/"down"}
    re("VoteUpdated")           -- Server→Client  {cardId, up, down}
    re("TicketUpdated")         -- Server→Client  投票権残数

    -- ── パートナー ──
    re("PartnerSpeak")          -- Server→Client  セリフ
    re("PartnerReaction")       -- Server→Client  リアクション種別
    re("PartnerAdvice")         -- Server→Client  アドバイス
    re("AmieInteract")          -- Client→Server  ふれあい操作
    re("ComfortRequest")        -- Client→Server  褒め要求
    re("PartnerAmie")           -- Client↔Server  パートナーふれあい
    re("PartnerComfort")        -- Server→Client  バトル後の褒め演出

    -- ── ガチャ ──
    re("GachaPull")             -- Client→Server  ガチャ実行
    re("GachaResult")           -- Server→Client  ガチャ結果

    -- ── クエスト ──
    re("QuestUpdate")           -- Server→Client  クエスト進捗
    re("QuestComplete")         -- Server→Client  クエスト達成
    re("QuestClaim")            -- Client→Server  報酬受け取り

    -- ── レーティング ──
    re("RatingUpdate")          -- Server→Client  レート変動

    -- ── コンビ戦 ──
    re("CombiSignal")           -- Client→Server  コンビ合図

    -- ── 課金 ──
    re("BuyProduct")            -- Client→Server  Developer Product購入
    re("EquipSkin")             -- Client→Server  スキン装備
    re("CheckPass")             -- Client→Server  ゲームパス所持確認
    re("SaveReplayChoice")      -- Client→Server  リプレイ選択保存
    re("GachaRoll")             -- Client→Server  ガチャ(課金)
    re("PetSystem")             -- Client↔Server ペット育成・化石発掘

    print("[SetupRemotes] 全RemoteEvent/Function作成完了")
end

return setup   -- ← Initializer が setup() として呼ぶ
