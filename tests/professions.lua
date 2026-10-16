local events = {}
local addonMessages = {}

LibStub = function() return {} end
C_AddOns = { GetAddOnMetadata = function() return "StoneovenBayTools" end }
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() end,
    SendChatMessage = function() end,
    SendAddonMessage = function(prefix, payload, distribution)
        addonMessages[#addonMessages + 1] = {
            prefix = prefix,
            payload = payload,
            distribution = distribution,
        }
    end,
}

Ambiguate = function(name) return name:match("^[^-]+") end
UnitName = function() return "Alice" end
UnitLevel = function() return 42 end
UnitClass = function() return "Mage", "MAGE" end
GetGuildInfo = function() return "Stoneoven Bay" end
GetRealmName = function() return "Forever" end
GetNumGuildMembers = function() return 1 end
GetGuildRosterInfo = function() return "Oldtimer-Forever", nil, nil, nil, nil, nil, nil, nil, nil, nil, "DRUID" end
GetProfessions = function() return 1, 2, nil, 3, 4, 5 end
GetProfessionInfo = function(index)
    if index == 1 then
        return "Alchemy, Master", "Interface\\Icons\\Trade_Alchemy", 75, 100
    elseif index == 2 then
        return "Herbalism", 134567, 50, 75
    elseif index == 3 then
        return "Fishing", "Interface\\Icons\\Trade_Fishing", 120, 150
    elseif index == 4 then
        return "Cooking", "Interface\\Icons\\INV_Misc_Food_15", 80, 150
    end
    return "First Aid", "Interface\\Icons\\Spell_Holy_SealOfSacrifice", 100, 150
end
time = function() return 1000 end

local SBT = {
    db = {
        profile = {
            enableAutoResponse = true,
            responseCooldown = 0,
            memberStatusCache = {},
        },
        global = { guildProfessionCache = {} },
    },
}

function SBT.RegisterEvent(event, handler)
    events[event] = events[event] or {}
    events[event][#events[event] + 1] = handler
end

assert(loadfile("Core/Globals.lua"))("StoneovenBayTools", SBT)
assert(loadfile("Modules/Tools.lua"))("StoneovenBayTools", SBT)

local function receive(prefix, payload, distribution, sender)
    for _, handler in ipairs(events.CHAT_MSG_ADDON) do
        handler(prefix, payload, distribution, sender)
    end
end

SBT.HandleToolMessage("guild", "!professions", "!professions", "Bob")
assert(#addonMessages == 2)
assert(addonMessages[1].prefix == "SBTPROF")
assert(addonMessages[1].distribution == "GUILD")
assert(addonMessages[1].payload:find("v3;42;MAGE;P;", 1, true) == 1)
assert(addonMessages[1].payload:find("Alchemy%2C Master", 1, true))
assert(addonMessages[2].payload:find("v3;42;MAGE;S;", 1, true) == 1)
assert(#addonMessages[1].payload <= 255 and #addonMessages[2].payload <= 255)

local cache = SBT:GetGuildProfessionCache()
assert(cache.Alice.level == 42)
assert(cache.Alice.professions[1].icon == "Interface\\Icons\\Trade_Alchemy")
assert(cache.Alice.class == "MAGE")
assert(#cache.Alice.primaryProfessions == 2)
assert(#cache.Alice.secondaryProfessions == 3)
assert(cache.Alice.secondaryProfessions[3].name == "First Aid")

receive("SBTPROF", addonMessages[1].payload, "GUILD", "Bob-Forever")
receive("SBTPROF", addonMessages[2].payload, "GUILD", "Bob-Forever")
assert(cache["Bob-Forever"].level == 42)
assert(cache["Bob-Forever"].class == "MAGE")
assert(cache["Bob-Forever"].professions[1].name == "Alchemy, Master")
assert(cache["Bob-Forever"].professions[2].icon == 134567)
assert(cache["Bob-Forever"].secondaryProfessions[1].icon == "Interface\\Icons\\Trade_Fishing")
assert(#cache["Bob-Forever"].professions == 5)

receive("SBTPROF", "v1;Mining,100,225", "GUILD", "Charlie-Forever")
assert(cache["Charlie-Forever"].professions[1].name == "Mining")
assert(cache["Charlie-Forever"].level == nil)
assert(cache["Charlie-Forever"].primaryProfessions[1].name == "Mining")

receive("SBTPROF", "v2;bad;Mining,100,225,1", "GUILD", "Invalid-Forever")
receive("SBTPROF", "v2;42;Mining,100,225,1", "WHISPER", "Whisper-Forever")
assert(cache["Invalid-Forever"] == nil)
assert(cache["Whisper-Forever"] == nil)

receive("SBTPROF", "v2;40;Skinning,100,225,134567", "GUILD", "Legacy-Forever")
assert(cache["Legacy-Forever"].primaryProfessions[1].name == "Skinning")
assert(#cache["Legacy-Forever"].secondaryProfessions == 0)
assert(SBT:ResolveCharacterClass("Oldtimer-Forever") == "DRUID")
local classColor = SBT:GetCharacterClassColor("MAGE")
assert(classColor[1] == 0.25 and classColor[2] == 0.78)

SBT.HandleToolMessage("whisper", "!professions", "!professions", "Bob")
assert(#addonMessages == 2)

print("Profession cache and addon-message tests passed.")
