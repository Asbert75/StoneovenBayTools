local _, SBT = ...

local tools = {}
local aliasToCommand = {}
local lastResponseAt = {}
local lastSnapshotRequestAt
local lastSnapshotResponseAt
local SNAPSHOT_COOLDOWN = 30
local sendChatMessage = (C_ChatInfo and C_ChatInfo.SendChatMessage) or rawget(_G, "SendChatMessage")

-- Chat text alone can't carry reliable mapID/x/y, so location data is also sent as a structured addon message.
local LOCATION_PREFIX = "SBTLOC"
if C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(LOCATION_PREFIX)
end

local PROFESSION_PREFIX = "SBTPROF"
if C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PROFESSION_PREFIX)
end

local STATUS_PREFIX = "SBTSTAT"
if C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(STATUS_PREFIX)
end

local REQUEST_PREFIX = "SBTREQ"
if C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(REQUEST_PREFIX)
end

local function sendLocationPing(channel, target, data)
    if not (data and data.mapID and data.x and data.y) then
        return
    end

    local payload = string.format("%d:%.6f:%.6f", data.mapID, data.x, data.y)
    if channel == "guild" then
        C_ChatInfo.SendAddonMessage(LOCATION_PREFIX, payload, "GUILD")
    elseif channel == "party" then
        C_ChatInfo.SendAddonMessage(LOCATION_PREFIX, payload, "PARTY")
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

local function decodeField(value)
    return (value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function encodeField(value)
    return (tostring(value):gsub("[%%,;]", function(character)
        return string.format("%%%02X", string.byte(character))
    end))
end

local function decodeProfessionData(message)
    local version, records = message:match("^(v[123]);(.*)$")
    if not version then
        return nil
    end

    local characterLevel, class, category
    if version == "v3" then
        local level
        level, class, category, records = records:match("^(%d+);([A-Z]+);([PS]);(.*)$")
        if not level then return nil end
        characterLevel = tonumber(level)
    elseif version == "v2" then
        local level
        level, records = records:match("^(%d+);(.*)$")
        if not level then
            return nil
        end
        characterLevel = tonumber(level)
    end

    local professions = {}

    if records == "" then
        return professions, characterLevel, class, category
    end

    for record in records:gmatch("[^;]+") do
        local name, skillLevel, maxSkillLevel, icon
        if version ~= "v1" then
            name, skillLevel, maxSkillLevel, icon = record:match("^([^,]+),(%d+),(%d+),([^,]*)$")
        else
            name, skillLevel, maxSkillLevel = record:match("^([^,]+),(%d+),(%d+)$")
        end

        skillLevel = tonumber(skillLevel)
        maxSkillLevel = tonumber(maxSkillLevel)

        if not name or not skillLevel or not maxSkillLevel then
            return nil
        end

        if version ~= "v1" then
            name = decodeField(name)
            icon = decodeField(icon)
            if version == "v3" and icon:sub(1, 1) == "~" then
                icon = "Interface\\Icons\\" .. icon:sub(2)
            end
            icon = icon ~= "" and (tonumber(icon) or icon) or nil
        end

        professions[#professions + 1] = {
            name = name,
            skillLevel = skillLevel,
            maxSkillLevel = maxSkillLevel,
            icon = icon,
        }
    end

    return professions, characterLevel, class, category
end

SBT.RegisterEvent("CHAT_MSG_ADDON", function(prefix, message, distribution, sender)
    if prefix ~= PROFESSION_PREFIX or distribution ~= "GUILD" then
        return
    end

    if Ambiguate(sender or "", "none") == UnitName("player") then
        return
    end

    local professions, characterLevel, class, category = decodeProfessionData(message)

    if not professions then
        return
    end

    SBT:SaveGuildProfessions(sender, professions, characterLevel, class, category)
end)

SBT.RegisterEvent("CHAT_MSG_ADDON", function(prefix, message, distribution, sender)
    if prefix ~= STATUS_PREFIX or distribution ~= "GUILD" then
        return
    end
    if Ambiguate(sender or "", "none") == UnitName("player") then
        return
    end

    local level, currentXP, maxXP, sessionElapsed, sessionXPGained, class
    if message:sub(1, 3) == "v3;" then
        class, level, currentXP, maxXP, sessionElapsed, sessionXPGained =
            message:match("^v3;([A-Z]+);(%d+);(%d+);(%d+);(%d+);(%d+)$")
    elseif message:sub(1, 3) == "v2;" then
        level, currentXP, maxXP, sessionElapsed, sessionXPGained =
            message:match("^v2;(%d+);(%d+);(%d+);(%d+);(%d+)$")
    else
        level, currentXP, maxXP = message:match("^v1;(%d+);(%d+);(%d+)$")
    end
    if not level then
        return
    end

    SBT:SaveGuildStatus(sender, {
        level = tonumber(level),
        currentXP = tonumber(currentXP),
        maxXP = tonumber(maxXP),
        sessionElapsed = sessionElapsed and tonumber(sessionElapsed),
        sessionXPGained = sessionXPGained and tonumber(sessionXPGained),
        class = class,
    })
end)

SBT.RegisterEvent("CHAT_MSG_ADDON", function(prefix, message, distribution, sender)
    if prefix ~= REQUEST_PREFIX or message ~= "v1" or distribution ~= "GUILD" then
        return
    end
    if Ambiguate(sender or "", "none") == UnitName("player") then
        return
    end

    local profile = SBT:GetProfileDB()
    if not profile or not profile.enableAutoResponse or not GetGuildInfo("player") then
        return
    end

    local now = time()
    if lastSnapshotResponseAt and now - lastSnapshotResponseAt < SNAPSHOT_COOLDOWN then
        return
    end

    if SBT:PublishGuildSnapshots() then
        lastSnapshotResponseAt = now
    end
end)

-- commands may be a single bare word or a list of aliases (e.g. "help" or { "professions", "profs" }); the "!" prefix
-- is always required in chat but only needs to be hard-coded here, not repeated in every tool definition. All aliases
-- share one cooldown/cache entry (the first/canonical name).
local COMMAND_PREFIX = "!"

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

        if channels.party then
            SBT.RegisterEvent("CHAT_MSG_PARTY", function(message, sender)
                SBT.HandleToolMessage("party", fullAlias, message, sender)
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

local function sendProfessionData(channel, data)
    if channel ~= "guild" or not data or not data.professions then
        return
    end

    for _, category in ipairs({ "P", "S" }) do
        local group = category == "P" and data.primaryProfessions or data.secondaryProfessions
        local entries = {}
        for _, profession in ipairs(group or {}) do
            local icon = profession.icon
            if type(icon) == "string" then
                icon = icon:gsub("^Interface\\Icons\\", "~")
            end
            entries[#entries + 1] = string.format("%s,%d,%d,%s",
                encodeField(profession.name), profession.skillLevel, profession.maxSkillLevel,
                icon and encodeField(icon) or "")
        end
        local header = string.format("v3;%d;%s;%s;", data.level or 0, data.class or "UNKNOWN", category)
        local payload = header .. table.concat(entries, ";")
        if #payload > 255 then
            for index, profession in ipairs(group or {}) do
                entries[index] = string.format("%s,%d,%d,", encodeField(profession.name),
                    profession.skillLevel, profession.maxSkillLevel)
            end
            payload = header .. table.concat(entries, ";")
        end
        if #payload <= 255 then
            C_ChatInfo.SendAddonMessage(PROFESSION_PREFIX, payload, "GUILD")
        end
    end
end

local function sendStatusData(channel, data)
    if channel ~= "guild" or not data or not (data.level and data.currentXP and data.maxXP) then
        return
    end

    local payload = string.format(
        "v3;%s;%d;%d;%d;%d;%d",
        data.class or "UNKNOWN", data.level, data.currentXP, data.maxXP,
        data.sessionElapsed or 0, data.sessionXPGained or 0
    )
    C_ChatInfo.SendAddonMessage(STATUS_PREFIX, payload, "GUILD")
end

local function sendResponse(command, channel, target, message, data)
    local prefixedMessage = "[SBT] " .. message

    if channel == "guild" or channel == "party" then
        sendChatMessage(prefixedMessage, channel:upper())
    else
        sendChatMessage(prefixedMessage, "WHISPER", nil, target)
    end

    if command == "!professions" then
        if data and data.professions then
            SBT:SaveGuildProfessions(UnitName("player"), data.primaryProfessions, data.level, data.class, "P")
            SBT:SaveGuildProfessions(UnitName("player"), data.secondaryProfessions, data.level, data.class, "S")
        end
        sendProfessionData(channel, data)
    elseif command == "!status" then
        if data then
            SBT:SaveGuildStatus(UnitName("player"), data)
        end
        sendStatusData(channel, data)
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
    local firstProfession, secondProfession, _, fishing, cooking, firstAid = GetProfessions()
    local professions = {}
    local primaryProfessions, secondaryProfessions = {}, {}
    local labels = {}

    local function addProfession(professionIndex, group)
        if professionIndex then
            local name, icon, skillLevel, maxSkillLevel = GetProfessionInfo(professionIndex)

            if name then
                local profession = {
                    name = name,
                    icon = icon,
                    skillLevel = skillLevel or 0,
                    maxSkillLevel = maxSkillLevel or 0,
                }

                professions[#professions + 1] = profession
                group[#group + 1] = profession
                labels[#labels + 1] = string.format(
                    "%s %d/%d",
                    profession.name,
                    profession.skillLevel,
                    profession.maxSkillLevel
                )
            end
        end
    end
    addProfession(firstProfession, primaryProfessions)
    addProfession(secondProfession, primaryProfessions)
    addProfession(fishing, secondaryProfessions)
    addProfession(cooking, secondaryProfessions)
    addProfession(firstAid, secondaryProfessions)

    local _, class = UnitClass("player")

    return #labels > 0 and table.concat(labels, ", ") or "No professions.", {
        professions = professions,
        primaryProfessions = primaryProfessions,
        secondaryProfessions = secondaryProfessions,
        level = UnitLevel("player"),
        class = class,
    }
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

-- Session XP is tracked as accumulated deltas rather than an absolute total, since UnitXP/UnitXPMax reset every level.
local sessionStartTime
local sessionXPGained = 0
local lastXP, lastMaxXP, lastLevel

local function getSessionSnapshot()
    local elapsed = sessionStartTime and math.max(0, time() - sessionStartTime) or 0
    return elapsed, sessionXPGained
end

local function getLevelStatus()
    local level = UnitLevel("player")
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local sessionElapsed, xpGained = getSessionSnapshot()
    local _, class = UnitClass("player")
    return string.format("Level %d: %s/%sxp", level, formatNumber(currentXP), formatNumber(maxXP)), {
        level = level,
        currentXP = currentXP,
        maxXP = maxXP,
        sessionElapsed = sessionElapsed,
        sessionXPGained = xpGained,
        class = class,
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

-- The daily record is per-character (SBT.db.char) and accumulates completed sessions so relogging the same day merges them.
local function getDailySessionRecord()
    local char = SBT.db and SBT.db.char
    if not char then
        return nil
    end

    local today = date("%Y-%m-%d")
    if type(char.dailySession) ~= "table" or char.dailySession.date ~= today then
        char.dailySession = { date = today, elapsed = 0, xpGained = 0 }
    end

    return char.dailySession
end

local function persistCurrentSessionIntoDailyRecord()
    local record = getDailySessionRecord()
    if not record or not sessionStartTime then
        return
    end

    record.elapsed = record.elapsed + math.max(0, time() - sessionStartTime)
    record.xpGained = record.xpGained + sessionXPGained
end

SBT.RegisterEvent("PLAYER_LOGIN", function()
    sessionStartTime = time()
    sessionXPGained = 0
    lastXP = UnitXP("player")
    lastMaxXP = UnitXPMax("player")
    lastLevel = UnitLevel("player")
    getDailySessionRecord()
end)

-- PLAYER_LOGOUT fires before SavedVariables are written, on both logout and /reload.
SBT.RegisterEvent("PLAYER_LOGOUT", persistCurrentSessionIntoDailyRecord)

SBT.RegisterEvent("PLAYER_XP_UPDATE", trackXPChange)
SBT.RegisterEvent("PLAYER_LEVEL_UP", trackXPChange)

local function getCurrentSessionStatus()
    local elapsed, xpGained = getSessionSnapshot()
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = elapsed % 60
    local xpPerHour = SBT:CalculateSessionXPRate(xpGained, elapsed)

    return string.format(
        "Session: %dh %dm %ds, XP gained: %s, XP/hour: %s",
        hours, minutes, seconds, formatNumber(xpGained), xpPerHour and formatNumber(xpPerHour) or "-"
    ), {
        elapsed = elapsed,
        xpGained = xpGained,
        xpPerHour = xpPerHour,
    }
end

local function getTodaySessionStatus()
    local record = getDailySessionRecord()
    local persistedElapsed = record and record.elapsed or 0
    local persistedXP = record and record.xpGained or 0

    local liveElapsed = sessionStartTime and math.max(0, time() - sessionStartTime) or 0
    local totalElapsed = persistedElapsed + liveElapsed
    local totalXP = persistedXP + sessionXPGained

    local hours = math.floor(totalElapsed / 3600)
    local minutes = math.floor((totalElapsed % 3600) / 60)
    local seconds = totalElapsed % 60
    local xpPerHour = SBT:CalculateSessionXPRate(totalXP, totalElapsed)

    return string.format(
        "Session (Today): %dh %dm %ds, XP gained: %s, XP/hour: %s",
        hours, minutes, seconds, formatNumber(totalXP), xpPerHour and formatNumber(xpPerHour) or "-"
    ), {
        elapsed = totalElapsed,
        xpGained = totalXP,
        xpPerHour = xpPerHour,
    }
end

local function getSessionStatus()
    local currentText, currentData = getCurrentSessionStatus()
    local todayText, todayData = getTodaySessionStatus()

    return currentText .. "; " .. todayText, {
        current = currentData,
        today = todayData,
    }
end

function SBT:PublishGuildSnapshots()
    if not SBT.db or not GetGuildInfo("player") then
        return false
    end

    local _, professionData = getPrimaryProfessions()
    local _, statusData = getLevelStatus()
    local playerName = UnitName("player")

    SBT:SaveGuildProfessions(playerName, professionData.primaryProfessions, professionData.level, professionData.class, "P")
    SBT:SaveGuildProfessions(playerName, professionData.secondaryProfessions, professionData.level, professionData.class, "S")
    SBT:SaveGuildStatus(playerName, statusData)
    sendProfessionData("guild", professionData)
    sendStatusData("guild", statusData)
    return true
end

function SBT:RequestGuildSnapshots()
    if not SBT.db or not GetGuildInfo("player") then
        return false, "Join a guild to refresh guild data."
    end

    local now = time()
    if lastSnapshotRequestAt and now - lastSnapshotRequestAt < SNAPSHOT_COOLDOWN then
        return false, string.format("Wait %d seconds before refreshing again.", SNAPSHOT_COOLDOWN - (now - lastSnapshotRequestAt))
    end

    if not SBT:PublishGuildSnapshots() then
        return false, "Guild data is not ready yet."
    end

    C_ChatInfo.SendAddonMessage(REQUEST_PREFIX, "v1", "GUILD")
    lastSnapshotRequestAt = now
    lastSnapshotResponseAt = now
    return true
end

registerTool("help", { guild = true, whisper = true, party = true }, function() return SBT:getHelpMessage() end)
registerTool("status", { guild = true, whisper = true, party = true }, getLevelStatus)
registerTool({ "professions", "proffs", "profs" }, { guild = true, whisper = true, party = true }, getPrimaryProfessions)
registerTool({ "location", "loc" }, { guild = true, whisper = true, party = true }, getLocation)
registerTool("session", { guild = true, whisper = true, party = true }, getSessionStatus)
registerTool({ "session today", "today" }, { guild = true, whisper = true, party = true }, getTodaySessionStatus)
