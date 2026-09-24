local ADDON, ns = ...

ns.ADDON = ADDON
ns.PREFIX = "|cffe6c56cStoneovenBayTools|r: "

ns.DB_DEFAULTS = {
    enableAutoResponse = true,
    responseCooldown = 10
}

local frame = CreateFrame("Frame")
local tools = {}
local lastResponseAt = {}
local memberStatusCache
local sendChatMessage = (C_ChatInfo and C_ChatInfo.SendChatMessage) or rawget(_G, "SendChatMessage")

local function getDatabase()
    StoneovenBayToolsDB = StoneovenBayToolsDB or {}

    for key, defaultValue in pairs(ns.DB_DEFAULTS) do
        if StoneovenBayToolsDB[key] == nil then
            StoneovenBayToolsDB[key] = defaultValue
        end
    end

    StoneovenBayToolsDB.memberStatusCache = StoneovenBayToolsDB.memberStatusCache or {}
    memberStatusCache = StoneovenBayToolsDB.memberStatusCache
    ns.MemberStatusCache = memberStatusCache

    return StoneovenBayToolsDB
end

local function registerTool(command, channels, handler)
    tools[command] = {
        channels = channels,
        handler = handler
    }

    if channels.guild then
        frame:RegisterEvent("CHAT_MSG_GUILD")
    end

    if channels.whisper then
        frame:RegisterEvent("CHAT_MSG_WHISPER")
    end
end

local function cacheStatus(command, data)
    local playerName = UnitName("player")
    memberStatusCache[playerName] = memberStatusCache[playerName] or {}
    memberStatusCache[playerName][command] = data
    memberStatusCache[playerName].updatedAt = time()
end

local function sendResponse(command, channel, target, message, data)
    if channel == "guild" then
        sendChatMessage(message, "GUILD")
    else
        sendChatMessage(message, "WHISPER", nil, target)
    end

    cacheStatus(command, data or { message = message })
end

local function normalizeCommand(message)
    return message and message:lower():match("^%s*(.-)%s*$")
end

frame:RegisterEvent("PLAYER_LOGIN")

local function getPrimaryProfessions()
    local firstProfession, secondProfession = GetProfessions()
    local professions = {}

    for _, professionIndex in ipairs({ firstProfession, secondProfession }) do
        if professionIndex then
            local name, _, skillLevel, maxSkillLevel = GetProfessionInfo(professionIndex)
            if name then
                professions[#professions + 1] = string.format(
                    "%s %d/%d",
                    name,
                    skillLevel or 0,
                    maxSkillLevel or 0
                )
            end
        end
    end

    if #professions == 0 then
        return "No primary professions."
    end

    return table.concat(professions, ", ")
end

local function getLevelStatus()
    local level = UnitLevel("player")
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    return string.format("Level %d: %d/%dxp", level, currentXP, maxXP), {
        level = level,
        currentXP = currentXP,
        maxXP = maxXP
    }
end

local function getLocation()
    local mapID = C_Map.GetBestMapForUnit("player")
    local mapInfo = mapID and C_Map.GetMapInfo(mapID)
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")

    if not mapInfo or not position then
        return "Location unavailable.", {}
    end

    local x, y = position:GetXY()
    if not x or not y then
        return mapInfo.name, { zone = mapInfo.name }
    end

    return string.format("%s (%.1f, %.1f)", mapInfo.name, x * 100, y * 100), {
        zone = mapInfo.name,
        mapID = mapID,
        x = x,
        y = y
    }
end

local function getHelpMessage()
    return table.concat({
        "sbt help",
        "sbt status",
        "sbt professions",
        "sbt location"
    }, "\n")
end

registerTool("sbt help", { guild = true, whisper = true }, function()
    return getHelpMessage()
end)

registerTool("sbt status", { guild = true, whisper = true }, function()
    local levelStatus, levelData = getLevelStatus()
    return levelStatus, levelData
end)

registerTool("sbt professions", { guild = true, whisper = true }, function()
    return getPrimaryProfessions()
end)

registerTool("sbt location", { guild = true, whisper = true }, function()
    return getLocation()
end)

local function registerSlashCommands()
    SLASH_STONEOVENBAYTOOLS1 = "/sbt"
    SLASH_STONEOVENBAYTOOLS2 = "/stoneovenbaytools"
    SlashCmdList.STONEOVENBAYTOOLS = function(message)
        local command = (message or ""):lower():match("^%s*(.-)%s*$")
        local database = getDatabase()

        if command == "on" or command == "enable" then
            database.enableAutoResponse = true
            print(ns.PREFIX .. "Guild responses enabled.")
        elseif command == "off" or command == "disable" then
            database.enableAutoResponse = false
            print(ns.PREFIX .. "Guild responses disabled.")
        elseif command == "status" or command == "config" then
            print(ns.PREFIX .. string.format(
                "Guild responses are %s. Cooldown: %d seconds.",
                database.enableAutoResponse and "enabled" or "disabled",
                database.responseCooldown
            ))
        else
            print(ns.PREFIX .. "Local commands:\n/sbt on\n/sbt off\n/sbt status\n\nGuild tools:\n" .. getHelpMessage())
        end
    end
end

registerSlashCommands()

frame:SetScript("OnEvent", function(_, event, message, sender)
    if event == "PLAYER_LOGIN" then
        getDatabase()
        print(ns.PREFIX .. "Addon loaded.")
        return
    end

    local channel = event == "CHAT_MSG_GUILD" and "guild" or event == "CHAT_MSG_WHISPER" and "whisper"
    local command = normalizeCommand(message)
    local tool = channel and tools[command]

    if not tool or not tool.channels[channel] then
        return
    end

    local database = getDatabase()
    if not database.enableAutoResponse then
        return
    end

    local cooldownKey = channel .. ":" .. command
    local now = time()
    local lastResponse = lastResponseAt[cooldownKey] or 0
    if now - lastResponse < database.responseCooldown then
        return
    end

    local response, data = tool.handler()
    if response then
        lastResponseAt[cooldownKey] = now
        sendResponse(command, channel, sender, response, data)
    end
end)