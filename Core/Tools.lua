local _, SBT = ...

local tools = {}
local aliasToCommand = {}
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

-- commands may be a single bare word or a list of aliases (e.g. "help" or { "professions", "profs" }); the "sbt " prefix
-- is always required in chat but only needs to be hard-coded here, not repeated in every tool definition. All aliases
-- share one cooldown/cache entry (the first/canonical name).
local COMMAND_PREFIX = "sbt "

local function registerTool(commands, channels, handler)
    if type(commands) == "string" then
        commands = { commands }
    end

    local command = COMMAND_PREFIX .. commands[1]
    tools[command] = {
        channels = channels,
        handler = handler
    }

    for _, alias in ipairs(commands) do
        local fullAlias = COMMAND_PREFIX .. alias
        aliasToCommand[fullAlias] = command

        if channels.guild then
            SBT.RegisterEvent("CHAT_MSG_GUILD", function(message, sender)
                SBT.HandleToolMessage("guild", fullAlias, message, sender)
            end)
        end

        if channels.whisper then
            SBT.RegisterEvent("CHAT_MSG_WHISPER", function(message, sender)
                SBT.HandleToolMessage("whisper", fullAlias, message, sender)
            end)
        end
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
    local prefixedMessage = "[SBT] " .. message

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

function SBT.HandleToolMessage(channel, alias, message, sender)
    if normalizeCommand(message) ~= alias then
        return
    end

    local command = aliasToCommand[alias]
    local tool = command and tools[command]
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

-- Swedish-style number grouping: space as the thousands separator (e.g. 17000 -> "17 000").
local function formatNumber(value)
    local negative = value < 0
    value = math.floor(math.abs(value) + 0.5)

    local digits = tostring(value)
    local firstGroupLength = #digits % 3
    if firstGroupLength == 0 then
        firstGroupLength = 3
    end

    local result = digits:sub(1, firstGroupLength)
    for index = firstGroupLength + 1, #digits, 3 do
        result = result .. " " .. digits:sub(index, index + 2)
    end

    return (negative and "-" or "") .. result
end

local function getLevelStatus()
    local level = UnitLevel("player")
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    return string.format("Level %d: %s/%sxp", level, formatNumber(currentXP), formatNumber(maxXP)), {
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

-- Session XP is tracked as accumulated deltas rather than an absolute total, since UnitXP/UnitXPMax reset every level.
local sessionStartTime
local sessionXPGained = 0
local lastXP, lastMaxXP, lastLevel

local function trackXPChange()
    local currentXP = UnitXP("player")
    local currentLevel = UnitLevel("player")

    if lastLevel and currentLevel > lastLevel then
        -- Leveled up since the last update: count what was earned to cap the old level, then progress into the new one.
        sessionXPGained = sessionXPGained + (lastMaxXP - lastXP) + currentXP
    elseif lastXP then
        sessionXPGained = sessionXPGained + math.max(0, currentXP - lastXP)
    end

    lastXP = currentXP
    lastMaxXP = UnitXPMax("player")
    lastLevel = currentLevel
end

SBT.RegisterEvent("PLAYER_LOGIN", function()
    sessionStartTime = time()
    sessionXPGained = 0
    lastXP = UnitXP("player")
    lastMaxXP = UnitXPMax("player")
    lastLevel = UnitLevel("player")
end)

SBT.RegisterEvent("PLAYER_XP_UPDATE", trackXPChange)
SBT.RegisterEvent("PLAYER_LEVEL_UP", trackXPChange)

local function getSessionStatus()
    local elapsed = sessionStartTime and math.max(0, time() - sessionStartTime) or 0
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = elapsed % 60
    local xpPerHour = elapsed > 0 and (sessionXPGained / (elapsed / 3600)) or 0

    return string.format(
        "Session: %dh %dm %ds, XP gained: %s, XP/hour: %s",
        hours, minutes, seconds, formatNumber(sessionXPGained), formatNumber(xpPerHour)
    ), {
        elapsed = elapsed,
        xpGained = sessionXPGained,
        xpPerHour = xpPerHour,
    }
end

registerTool("help", { guild = true, whisper = true }, function() return SBT:getHelpMessage() end)
registerTool("status", { guild = true, whisper = true }, getLevelStatus)
registerTool({ "professions", "proffs", "profs" }, { guild = true, whisper = true }, getPrimaryProfessions)
registerTool({ "location", "loc" }, { guild = true, whisper = true }, getLocation)
registerTool("session", { guild = true, whisper = true }, getSessionStatus)
