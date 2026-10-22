-- Infinite Stamina (UE4SS) for The Blood of Dawnwalker.
--
-- Gives the player the gameplay tag Effect.InfiniteStamina. The game's own code checks this tag before it uses
-- stamina (the player's Shadowstorm spell grants it for a few seconds), so the player never runs out of stamina.
-- Enemies are not changed. A timer checks every two seconds that the player still has the tag - after a new game, a
-- save load, a death or a change of form - and adds it again when it is missing.
--
-- How the tag is added: AbilitySystemBlueprintLibrary.AddLooseGameplayTags needs an FGameplayTagContainer. This
-- UE4SS build cannot pass one that Lua builds from a table: 1.0 passed an empty container, and 1.1 crashed the game
-- with a container that the game had returned as a table. So the script borrows a real container of the game: the
-- DefaultTags of the player's ability setup (DA_PlayerAbilityConfig, which holds Character.CreatureType.Human). For
-- the call it puts Effect.InfiniteStamina in place of its first tag and passes the container (UE4SS copies a real
-- struct with CopyCompleteValue); right after the call it puts the old tag back. So only Effect.InfiniteStamina
-- reaches the player, and the setup is unchanged afterwards.

local MOD_NAME = "Infinite Stamina (UE4SS)"
local VERSION = "1.2"
local TAG_NAME = "Effect.InfiniteStamina"
local PLAYER_CLASS_PATH = "/Script/Dawnwalker.DawnwalkerPlayerCharacter"
local ABILITY_LIBRARY_PATH = "/Script/GameplayAbilities.Default__AbilitySystemBlueprintLibrary"
local CHECK_INTERVAL_MS = 2000
-- At most this many failed tries per player object, so a failing call is not repeated every two seconds.
local MAX_FAILURES_PER_PLAYER = 3
-- Log at most this many error lines in total.
local MAX_ERROR_LOGS = 5

local UEHelpers = require("UEHelpers")

local cache = {}
-- UEHelpers.GetPlayerController() searches all objects; keep the controller until it becomes invalid (a new world).
local controller = nil
local playerAddress = nil
local failuresForPlayer = 0
local errors = 0

local function Log(message)
    print(string.format("[%s] %s\n", MOD_NAME, message))
end

local function LogError(message)
    errors = errors + 1
    if errors <= MAX_ERROR_LOGS then
        Log(message)
    end
end

local function Find(path)
    local object = cache[path]
    if object ~= nil and object:IsValid() then
        return object
    end
    object = StaticFindObject(path)
    if object ~= nil and object:IsValid() then
        cache[path] = object
        return object
    end
    return nil
end

-- Returns the player character, or nil in the main menu, during loading or while the player controls something else.
local function GetPlayerCharacter()
    local playerClass = Find(PLAYER_CLASS_PATH)
    if playerClass == nil then
        return nil
    end
    if controller == nil or not controller:IsValid() then
        controller = UEHelpers.GetPlayerController()
        if not controller:IsValid() then
            controller = nil
            return nil
        end
    end
    local pawn = controller.Pawn
    if pawn == nil or not pawn:IsValid() or not pawn:IsA(playerClass) then
        return nil
    end
    return pawn
end

local function HasTag(player)
    return player:HasMatchingGameplayTag({ TagName = FName(TAG_NAME) }) == true
end

-- Adds the tag as a loose tag through the borrowed DefaultTags container (see the top of the file).
local function AddTag(player)
    local abilityLibrary = Find(ABILITY_LIBRARY_PATH)
    if abilityLibrary == nil then
        return false, "AbilitySystemBlueprintLibrary not found"
    end
    local config = player.CharacterAbilityConfig
    if config == nil or not config:IsValid() then
        return false, "the player has no CharacterAbilityConfig"
    end
    local container = config.DefaultTags
    local tags = container.GameplayTags
    local count = #tags
    -- Reading tags[1] of an empty array would grow it (UE4SS adds missing entries), so check the count first. Keep
    -- the old tag as a string: a copy for sure, even if UE4SS returned a live view of the entry.
    local original = nil
    if count > 0 then
        original = tags[1].TagName:ToString()
    end
    tags[1] = { TagName = FName(TAG_NAME) }
    local ok, err = pcall(function()
        abilityLibrary:AddLooseGameplayTags(player, container, false)
    end)
    if original ~= nil then
        tags[1] = { TagName = FName(original) }
        local restored = tags[1].TagName:ToString()
        if restored ~= original then
            LogError(string.format("The first DefaultTags entry of %s is %s, not %s", config:GetFullName(), restored, original))
        end
    else
        tags:Empty()
    end
    if not ok then
        return false, "AddLooseGameplayTags: " .. tostring(err)
    end
    return HasTag(player), string.format("%s of %d tag(s) borrowed", config:GetFullName(), count)
end

local function EnsureTag()
    local player = GetPlayerCharacter()
    if player == nil or HasTag(player) then
        return
    end
    local address = player:GetAddress()
    if address ~= playerAddress then
        playerAddress = address
        failuresForPlayer = 0
    end
    if failuresForPlayer >= MAX_FAILURES_PER_PLAYER then
        return
    end
    local added, detail = AddTag(player)
    if added then
        Log(string.format("%s added to %s (%s)", TAG_NAME, player:GetFullName(), detail))
    else
        failuresForPlayer = failuresForPlayer + 1
        LogError(string.format("%s not added (try %d): %s", TAG_NAME, failuresForPlayer, tostring(detail)))
    end
end

Log(VERSION .. " loaded.")

LoopAsync(CHECK_INTERVAL_MS, function()
    ExecuteInGameThread(function()
        local ok, err = pcall(EnsureTag)
        if not ok then
            LogError("Error: " .. tostring(err))
        end
    end)
    -- false keeps the loop running.
    return false
end)
