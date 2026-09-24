local _, SBT = ...

local tools = {}
local lastResponseAt = {}
local sendChatMessage = (C_ChatInfo and C_ChatInfo.SendChatMessage) or rawget(_G, "SendChatMessage")

-- Chat text alone can't carry reliable mapID/x/y, so location data is also sent as a structured addon message.
local LOCATION_PREFIX = "SBTLOC"
if C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(LOCATION_PREFIX)
end

local function sendLocationPing(channel, target, data)
    if not (data and data.mapID and data.x and data.y) then
        return
    end

    local payload = string.format("%d:%.6f:%.6f", data.mapID, data.x, data.y)
    if channel == "guild" then
        C_ChatInfo.SendAddonMessage(LOCATION_PREFIX, payload, "GUILD")
    else
        C_ChatInfo.SendAddonMessage(LOCATION_PREFIX, payload, "WHISPER", target)
    end
end

SBT.RegisterEvent("CHAT_MSG_ADDON", function(prefix, message, _, sender)
    if prefix ~= LOCATION_PREFIX or Ambiguate(sender or "", "none") == UnitName("player") then
        return
    end

    local tomtom = rawget(_G, "TomTom")
    if not (tomtom and tomtom.AddWaypoint) then
        return
    end

    local mapID, x, y = message:match("^(%d+):([%d%.]+):([%d%.]+)$")
    if not mapID then
        return
    end

    tomtom:AddWaypoint(tonumber(mapID), tonumber(x), tonumber(y), {
        title = string.format("%s (guild)", Ambiguate(sender, "none")),
        from = "StoneovenBayTools",
    })
end)

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
    local database = SBT:GetProfileDB()
    database.memberStatusCache[playerName] = database.memberStatusCache[playerName] or {}
    database.memberStatusCache[playerName][command] = data
    database.memberStatusCache[playerName].updatedAt = time()
end

local function sendResponse(command, channel, target, message, data)
    local prefixedMessage = "SBT: " .. message

    if channel == "guild" then
        sendChatMessage(prefixedMessage, "GUILD")
    else
        sendChatMessage(prefixedMessage, "WHISPER", nil, target)
    end

    sendLocationPing(channel, target, data)
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

    local database = SBT:GetProfileDB()
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
