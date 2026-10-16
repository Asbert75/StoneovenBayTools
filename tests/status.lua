local events = {}
local addonMessages = {}
local chatMessages = {}
local chatChannels = {}
local now = 1000
local playerXP = 500

LibStub = function() return {} end
C_AddOns = { GetAddOnMetadata = function() return "StoneovenBayTools" end }
SlashCmdList = {}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() end,
    SendChatMessage = function(message, channel)
        chatMessages[#chatMessages + 1] = message
        chatChannels[#chatChannels + 1] = channel
    end,
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
UnitClass = function() return "Warrior", "WARRIOR" end
UnitXP = function() return playerXP end
UnitXPMax = function() return 1000 end
GetGuildInfo = function() return "Stoneoven Bay" end
GetRealmName = function() return "Forever" end
GetProfessions = function() return 1, nil end
GetProfessionInfo = function() return "Alchemy", 134567, 50, 75 end
time = function() return now end
date = function() return "2026-10-14" end

local SBT = {
    db = {
        profile = {
            enableAutoResponse = true,
            responseCooldown = 0,
            memberStatusCache = {},
        },
        global = { guildStatusCache = {} },
        char = {},
    },
}

function SBT.RegisterEvent(event, handler)
    events[event] = events[event] or {}
    events[event][#events[event] + 1] = handler
end

assert(loadfile("Core/Globals.lua"))("StoneovenBayTools", SBT)
assert(loadfile("Core/Settings.lua"))("StoneovenBayTools", SBT)
assert(loadfile("Modules/Tools.lua"))("StoneovenBayTools", SBT)
assert(loadfile("Core/GUI/Status.lua"))("StoneovenBayTools", SBT)

local function receive(payload, distribution, sender)
    for _, handler in ipairs(events.CHAT_MSG_ADDON) do
        handler("SBTSTAT", payload, distribution, sender)
    end
end

local function receiveRequest(payload, distribution, sender)
    for _, handler in ipairs(events.CHAT_MSG_ADDON) do
        handler("SBTREQ", payload, distribution, sender)
    end
end

SBT.HandleToolMessage("whisper", "!session", "!session", "Bob")
assert(chatMessages[#chatMessages]:find("XP/hour: -", 1, true))

for _, handler in ipairs(events.PLAYER_LOGIN) do
    handler()
end
now = 4600
playerXP = 700
for _, handler in ipairs(events.PLAYER_XP_UPDATE) do
    handler()
end

SBT.HandleToolMessage("guild", "!status", "!status", "Bob")
assert(#addonMessages == 1)
assert(addonMessages[1].prefix == "SBTSTAT")
assert(addonMessages[1].payload == "v3;WARRIOR;42;700;1000;3600;200")
assert(addonMessages[1].distribution == "GUILD")

local cache = SBT:GetGuildStatusCache()
assert(cache.Alice.level == 42)
assert(cache.Alice.currentXP == 700)
assert(cache.Alice.maxXP == 1000)
assert(cache.Alice.sessionElapsed == 3600)
assert(cache.Alice.sessionXPGained == 200)
assert(cache.Alice.updatedAt == 4600)
assert(cache.Alice.class == "WARRIOR")

now = 5000
receive("v2;43;900;1500;1800;450", "GUILD", "Bob-Forever")
now = 6000
receive("v1;40;200;400", "GUILD", "Charlie-Forever")
receive("v3;MAGE;41;100;500;600;50", "GUILD", "Eve-Forever")
assert(cache["Bob-Forever"].currentXP == 900)
assert(cache["Bob-Forever"].sessionXPGained == 450)
assert(cache["Charlie-Forever"].sessionElapsed == nil)
assert(cache["Charlie-Forever"].updatedAt == 6000)
assert(cache["Eve-Forever"].class == "MAGE")

receive("v2;42;bad;1000;3600;200", "GUILD", "Invalid-Forever")
receive("v2;42;700;1000;3600;200", "WHISPER", "Whisper-Forever")
assert(cache["Invalid-Forever"] == nil)
assert(cache["Whisper-Forever"] == nil)

assert(SBT:SortGuildStatusRows(cache, "name", true)[1].name == "Alice")
assert(SBT:SortGuildStatusRows(cache, "level", false)[1].name == "Bob-Forever")
assert(SBT:SortGuildStatusRows(cache, "currentXP", false)[1].name == "Bob-Forever")
assert(SBT:SortGuildStatusRows(cache, "maxXP", false)[1].name == "Bob-Forever")
assert(SBT:SortGuildStatusRows(cache, "progress", false)[1].name == "Alice")
assert(SBT:SortGuildStatusRows(cache, "remaining", false)[1].name == "Bob-Forever")
assert(SBT:SortGuildStatusRows(cache, "sessionElapsed", false)[1].name == "Alice")
assert(SBT:SortGuildStatusRows(cache, "sessionXPGained", false)[1].name == "Bob-Forever")
assert(SBT:SortGuildStatusRows(cache, "xpPerHour", false)[1].name == "Bob-Forever")
assert(SBT:SortGuildStatusRows(cache, "updatedAt", false)[1].name == "Charlie-Forever")
assert(SBT:SortGuildStatusRows(cache, "xpPerHour", false)[1].xpPerHour == 450)
assert(SBT:CalculateSessionXPRate(600, 900) == 600)
assert(SBT:CalculateSessionXPRate(600, 7200) == 300)
assert(SBT:CalculateSessionXPRate(600, 0) == nil)

cache.Dave = { level = 42, currentXP = 900, maxXP = 1000, updatedAt = 1000 }
assert(SBT:SortGuildStatusRows(cache, "level", false)[2].name == "Dave")

SBT.HandleToolMessage("whisper", "!status", "!status", "Bob")
assert(#addonMessages == 1)

now = 7000
playerXP = 700
for _, handler in ipairs(events.PLAYER_LOGOUT) do
    handler()
end
assert(SBT.db.char.dailySession.xpGained == 200)
for _, handler in ipairs(events.PLAYER_LOGIN) do
    handler()
end
now = 7900
playerXP = 900
for _, handler in ipairs(events.PLAYER_XP_UPDATE) do
    handler()
end
SBT.HandleToolMessage("whisper", "!session", "!session", "Bob")
assert(chatMessages[#chatMessages]:find("XP/hour: 200", 1, true))
assert(chatMessages[#chatMessages]:find("Session (Today):", 1, true))
SBT.HandleToolMessage("whisper", "!today", "!today", "Bob")
assert(chatMessages[#chatMessages]:find("Session (Today):", 1, true))
assert(SBT.db.char.dailySession.xpGained == 200)

SBT.HandleToolMessage("party", "!status", "!status", "Bob")
assert(chatChannels[#chatChannels] == "PARTY")

now = 8000
local chatCount = #chatMessages
local requested = SBT:RequestGuildSnapshots()
assert(requested)
assert(#addonMessages == 5)
assert(addonMessages[2].prefix == "SBTPROF")
assert(addonMessages[3].prefix == "SBTPROF")
assert(addonMessages[4].prefix == "SBTSTAT")
assert(addonMessages[5].prefix == "SBTREQ")
assert(cache.Alice.updatedAt == 8000)
assert(#chatMessages == chatCount)

local requestedAgain, waitMessage = SBT:RequestGuildSnapshots()
assert(not requestedAgain and waitMessage:find("Wait", 1, true))
assert(#addonMessages == 5)

now = 8031
receiveRequest("v1", "GUILD", "Bob-Forever")
assert(#addonMessages == 8)
assert(addonMessages[6].prefix == "SBTPROF")
assert(addonMessages[7].prefix == "SBTPROF")
assert(addonMessages[8].prefix == "SBTSTAT")
receiveRequest("v1", "GUILD", "Charlie-Forever")
assert(#addonMessages == 8)

SBT.db.profile.enableAutoResponse = false
now = 8062
receiveRequest("v1", "GUILD", "Charlie-Forever")
assert(#addonMessages == 8)

now = 4000000
local ageLabel, age = SBT:FormatCacheAge(now - 1860)
assert(ageLabel == "31m ago" and age == 1860)
ageLabel, age = SBT:FormatCacheAge(now - 31 * 86400)
assert(ageLabel == "31d ago" and age == 31 * 86400)

local previousChatCount = #chatMessages
SBT.HandleToolMessage("guild", "sbt status", "sbt status", "Bob")
assert(#chatMessages == previousChatCount)
SBT.db.profile.enableAutoResponse = true
SBT.HandleToolMessage("guild", "!help", "!help", "Bob")
assert(chatMessages[#chatMessages]:find("!status", 1, true))
SBT.HandleToolMessage("whisper", "!session today", "!session today", "Bob")
assert(chatMessages[#chatMessages]:find("Session (Today):", 1, true))

print("Guild status cache, messages, and sorting tests passed.")
