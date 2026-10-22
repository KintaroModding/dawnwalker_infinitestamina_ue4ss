"""Offline test of Scripts/main.lua with lupa (Lua 5.4) and small mocks of UE4SS and the game.

The mocks copy the UE4SS behaviour that the script depends on: a TArray grows when an index past its end is read or
written, a struct entry is set from a table, FName values have ToString(). The test checks that the script adds
Effect.InfiniteStamina as the only loose tag, puts the borrowed DefaultTags entry back, does not grow the array, and
does not add the tag again while the player has it.

Usage:
    python tests/test_main.py        (needs lupa: python -m pip install lupa)

Exit code: 0 = all checks passed, 1 = a check failed.
"""

import json
import sys
from pathlib import Path

from lupa import lua54

ROOT = Path(__file__).resolve().parent.parent
MAIN = ROOT / "src" / "dawnwalker_infinitestamina_ue4ss" / "Scripts" / "main.lua"
VERSION = json.loads((ROOT / "mod.json").read_text(encoding="utf-8"))["version"]

MOCKS = r"""
LOG = {}
print = function(...) LOG[#LOG + 1] = table.concat({...}, "") end

local FNameMeta = { __index = { ToString = function(self) return self.text end } }
function FName(text) return setmetatable({ text = text }, FNameMeta) end

LOOPS = {}
function LoopAsync(ms, callback) LOOPS[#LOOPS + 1] = callback end
function ExecuteInGameThread(callback) callback() end

-- A TArray of FGameplayTag as UE4SS shows it: 1-based, grows on access past the end.
local function NewTagArray(names)
    local data = {}
    for i, name in ipairs(names) do data[i] = { TagName = FName(name) } end
    local function grow(index) for i = #data + 1, index do data[i] = { TagName = FName("None") } end end
    local array = setmetatable({}, {
        __len = function() return #data end,
        __index = function(_, key)
            if key == "Empty" then return function() for i = #data, 1, -1 do data[i] = nil end end end
            grow(key)
            return data[key]
        end,
        __newindex = function(_, key, value)
            grow(key)
            data[key] = { TagName = FName(value.TagName:ToString()) }
        end,
    })
    return array, data
end

local function Valid() return true end

LOOSE = {}
TAGS, TAG_DATA = NewTagArray({ "Character.CreatureType.Human" })
CONFIG = {
    IsValid = Valid,
    GetFullName = function() return "PlayerCharacterAbilityConfig /Game/_Dawnwalker/Player/DA_PlayerAbilityConfig" end,
    DefaultTags = { GameplayTags = TAGS },
}
PLAYER = {
    IsValid = Valid,
    IsA = function() return true end,
    GetAddress = function() return 1 end,
    GetFullName = function() return "BP_PlayerCharacter_C /Game/Test.Test:PersistentLevel.BP_PlayerCharacter_C_1" end,
    CharacterAbilityConfig = CONFIG,
    HasMatchingGameplayTag = function(_, tag)
        local name = tag.TagName:ToString()
        if name == "Character.CreatureType.Human" then return true end
        return (LOOSE[name] or 0) > 0
    end,
}
LIBRARY = {
    IsValid = Valid,
    AddLooseGameplayTags = function(_, actor, container, replicate)
        assert(actor == PLAYER, "wrong actor")
        assert(replicate == false, "replicate must be false")
        for i = 1, #container.GameplayTags do
            local name = container.GameplayTags[i].TagName:ToString()
            LOOSE[name] = (LOOSE[name] or 0) + 1
        end
    end,
}
function StaticFindObject(path)
    if path:find("AbilitySystemBlueprintLibrary", 1, true) then return LIBRARY end
    return { IsValid = Valid }
end
package.preload["UEHelpers"] = function()
    return { GetPlayerController = function() return { IsValid = Valid, Pawn = PLAYER } end }
end
"""


def main() -> None:
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCKS)
    lua.execute(MAIN.read_text(encoding="utf-8"))
    g = lua.globals()
    failures = []

    def check(condition, text):
        print(("ok    " if condition else "FAIL  ") + text)
        if not condition:
            failures.append(text)

    check(len(g.LOOPS) == 1, "one LoopAsync timer")
    g.LOOPS[1]()
    check(g.LOOSE["Effect.InfiniteStamina"] == 1, "Effect.InfiniteStamina added once")
    check(g.LOOSE["Character.CreatureType.Human"] is None, "Character.CreatureType.Human not added as a loose tag")
    check(len(g.TAG_DATA) == 1, "DefaultTags still has one entry")
    check(g.TAG_DATA[1].TagName.text == "Character.CreatureType.Human", "DefaultTags entry put back")
    g.LOOPS[1]()
    check(g.LOOSE["Effect.InfiniteStamina"] == 1, "not added again while the player has it")
    log = [g.LOG[i] for i in range(1, len(g.LOG) + 1)]
    for line in log:
        print("      log: " + line.rstrip())
    check(any(f"{VERSION} loaded." in line for line in log), f"load line with the version {VERSION} of mod.json")
    check(any("added to" in line for line in log), "log line for the added tag")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
