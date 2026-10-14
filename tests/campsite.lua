local sent = {}
local printed = {}
local frame
local originalPrint = print

CreateFrame = function()
    frame = {
        RegisterEvent = function() end,
        SetScript = function(self, _, handler) self.onEvent = handler end,
    }
    return frame
end

C_ChatInfo = {
    RegisterAddonMessagePrefix = function() end,
    SendAddonMessage = function(prefix, payload, distribution)
        sent[#sent + 1] = { prefix = prefix, payload = payload, distribution = distribution }
    end,
}

IsInGroup = function() return true end
GetNumGroupMembers = function() return 2 end
UnitExists = function(unit) return unit == "party1" end
UnitName = function(unit) return unit == "player" and "Alice" or "Bob" end
UnitClass = function(unit) return unit == "player" and "Mage" or "Warrior" end
GetProfessions = function() return 1, nil, nil, 3, 4, 5 end
GetProfessionInfo = function(index)
    local names = { [1] = "Alchemy", [3] = "Fishing", [4] = "Cooking", [5] = "First Aid" }
    return names[index], nil, index * 10
end
Ambiguate = function(name) return name:match("^[^-]+") end
strsplit = function(delimiter, value)
    local position = value:find(delimiter, 1, true)
    if not position then return value end
    return value:sub(1, position - 1), value:sub(position + #delimiter)
end
print = function(message) printed[#printed + 1] = message end

local SBT = {}
assert(loadfile("Modules/CampsiteHelper/Campsite.lua"))("StoneovenBayTools", SBT)
SBT.Campsite:Initialize()

assert(#SBT.Campsite.Party == 2)
assert(sent[1].payload == "REQUEST_PROFS" and sent[1].distribution == "PARTY")

frame:onEvent("CHAT_MSG_ADDON", "SBTCAMPSITE", "REQUEST_PROFS", "PARTY", "Bob-Forever")
assert(sent[2].prefix == "SBTCAMPSITE")
assert(sent[2].payload:find("Fishing:30", 1, true))
assert(sent[2].payload:find("Cooking:40", 1, true))
assert(sent[2].payload:find("First Aid:50", 1, true))

frame:onEvent("CHAT_MSG_ADDON", "SBTCAMPSITE", "PROFS|Mining:225", "PARTY", "Bob-Forever")
assert(SBT.Campsite.Party[2].professions.Mining == 225)

SBT.Campsite:DumpData()
assert(printed[1]:find("Alice", 1, true))
assert(printed[2]:find("Bob", 1, true))

print = originalPrint
print("Campsite party-sharing tests passed.")
