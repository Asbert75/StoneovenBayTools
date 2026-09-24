local _, SBT = ...

local tools = {}
local lastResponseAt = {}
local sendChatMessage = (C_ChatInfo and C_ChatInfo.SendChatMessage) or rawget(_G, "SendChatMessage")

local function registerTool(command, channels, handler)
    tools[command] = {
        channels = channels,
        handler = handler
    }

    if channels.guild then
        SBT.RegisterEvent("CHAT_MSG_GUILD", function(message, sender)
            SBT.HandleToolMessage("guild", command, message, sender)
        end)
    end

    if channels.whisper then
        SBT.RegisterEvent("CHAT_MSG_WHISPER", function(message, sender)
            SBT.HandleToolMessage("whisper", command, message, sender)
        end)
    end
end

local function cacheStatus(command, data)
    local playerName = UnitName("player")
    SBT.MemberStatusCache[playerName] = SBT.MemberStatusCache[playerName] or {}
    SBT.MemberStatusCache[playerName][command] = data
    SBT.MemberStatusCache[playerName].updatedAt = time()
end

local function sendResponse(command, channel, target, message, data)
    local prefixedMessage = "SBT: " .. message

    if channel == "guild" then
        sendChatMessage(prefixedMessage, "GUILD")
    else
        sendChatMessage(prefixedMessage, "WHISPER", nil, target)
    end

    cacheStatus(command, data or { message = message })
end

local function normalizeCommand(message)
    return message and message:lower():match("^%s*(.-)%s*$")
end

function SBT.HandleToolMessage(channel, command, message, sender)
    if normalizeCommand(message) ~= command then
        return
    end

    local tool = tools[command]
    if not tool or not tool.channels[channel] then
        return
    end

    local database = SBT.GetDatabase()
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
end

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

registerTool("sbt help", { guild = true, whisper = true }, getHelpMessage)
registerTool("sbt status", { guild = true, whisper = true }, getLevelStatus)
registerTool("sbt professions", { guild = true, whisper = true }, getPrimaryProfessions)
registerTool("sbt location", { guild = true, whisper = true }, getLocation)
