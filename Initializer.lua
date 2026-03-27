-- Initializer.lua
-- ServerScriptService/ に配置（Script型）
-- 全システムの起動順を保証する

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- 1. まずRemoteEventsを作る（他のスクリプトがWaitForChildするので最優先）
local setup = require(ReplicatedStorage:WaitForChild("SetupRemotes_v2", 15))
setup()

-- 2. CardDataをロード（BattleServerが参照するので早めに）
require(ReplicatedStorage:WaitForChild("CardData", 15))

-- 3. SecurityValidatorをロード（BattleServerが使う）
require(ReplicatedStorage:WaitForChild("SecurityValidator", 15))

-- 4. ArcanaSystemをロード
require(ReplicatedStorage:WaitForChild("ArcanaSystem", 15))

-- 5. DinoSystemをロード
require(ReplicatedStorage:WaitForChild("DinoSystem", 15))

-- ここより後はServerScriptService内の各Scriptが自律起動する
print("[Initializer] 全システム起動完了")
