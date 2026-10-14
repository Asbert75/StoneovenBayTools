local _, SBT = ...

SBT.LSM = LibStub("LibSharedMedia-3.0", true)
SBT.AG = LibStub("AceGUI-3.0")

SBT.ADDON_NAME = C_AddOns.GetAddOnMetadata("StoneovenBayTools", "Title")

SBT.DefaultFont = "";

function SBT:PrettyPrint(msg)
    print("|cff8c1616" .. SBT.ADDON_NAME .. ":|r " .. msg)
end

function SBT:GetProfileDB()
    if not SBT.db then
        return nil
    end

    return SBT.db.profile
end

function SBT:GetDB(key, default)
    local profile = SBT:GetProfileDB()
    if not profile then
        return default
    end

    if key and type(key) == "string" then
        return profile[key] ~= nil and profile[key] or default
    end

    return profile
end

function SBT:SetDB(key, value)
    local profile = SBT:GetProfileDB()
    if not profile then
        return
    end

    if key and type(key) == "string" then
        profile[key] = value
    end
end

-- "/SBT" collides case-insensitively with the "/sbt" command in Settings.lua; toggle exposed as a subcommand instead.
function SBT:ToggleMainFrame()
    if not SBT.MainFrame then
        SBT:PrettyPrint("Settings UI is not ready yet.")
        return
    end

    if SBT.MainFrame:IsShown() then
        SBT.MainFrame:Hide()
    else
        SBT.MainFrame:Show()
    end
end

function SBT:PixelPerfect(value)
    if not value then return 0 end
    local _, screenHeight = GetPhysicalScreenSize()
    local uiScale = UIParent:GetEffectiveScale()
    local pixelSize = 768 / screenHeight / uiScale
    return pixelSize * math.floor((value / pixelSize) + 0.5333)
end

function SBT:SaveGuildProfessions(sender, professions, characterLevel, class, category)
    local guildName = GetGuildInfo("player")

    if not SBT.db or not guildName or type(sender) ~= "string" then
        return
    end

    local guildKey = guildName .. "-" .. (GetRealmName() or "unknown")
    local global = SBT.db.global

    global.guildProfessionCache = global.guildProfessionCache or {}
    global.guildProfessionCache[guildKey] =
        global.guildProfessionCache[guildKey] or { members = {} }

    local previous = global.guildProfessionCache[guildKey].members[sender] or {}
    local primary = category == "S" and (previous.primaryProfessions or previous.professions or {}) or professions
    local secondary = category == "P" and (previous.secondaryProfessions or {}) or
        (category == "S" and professions or {})
    local combined = {}
    for _, profession in ipairs(primary) do combined[#combined + 1] = profession end
    for _, profession in ipairs(secondary) do combined[#combined + 1] = profession end

    global.guildProfessionCache[guildKey].members[sender] = {
        professions = combined,
        primaryProfessions = primary,
        secondaryProfessions = secondary,
        level = characterLevel or previous.level,
        class = class or previous.class,
        updatedAt = time(),
    }

    if SBT.MainFrame and SBT.MainFrame:IsShown() and SBT.RefreshCachedDataTable then
        SBT:RefreshCachedDataTable()
    end
    if SBT.MainFrame and SBT.MainFrame:IsShown() and SBT.RefreshProfessionRoster then
        SBT:RefreshProfessionRoster()
    end
end

function SBT:GetGuildProfessionCache()
    local guildName = GetGuildInfo("player")
    if not SBT.db or not guildName then
        return nil
    end

    local guildKey = guildName .. "-" .. (GetRealmName() or "unknown")
    local cache = SBT.db.global.guildProfessionCache
    local guildCache = cache and cache[guildKey]
    return (guildCache and guildCache.members) or {}
end

function SBT:SaveGuildStatus(sender, status)
    local guildName = GetGuildInfo("player")
    if not SBT.db or not guildName or type(sender) ~= "string" or type(status) ~= "table" then
        return
    end

    local guildKey = guildName .. "-" .. (GetRealmName() or "unknown")
    local global = SBT.db.global
    global.guildStatusCache = global.guildStatusCache or {}
    global.guildStatusCache[guildKey] = global.guildStatusCache[guildKey] or { members = {} }
    global.guildStatusCache[guildKey].members[sender] = {
        level = status.level,
        currentXP = status.currentXP,
        maxXP = status.maxXP,
        sessionElapsed = status.sessionElapsed,
        sessionXPGained = status.sessionXPGained,
        class = status.class or (global.guildStatusCache[guildKey].members[sender] or {}).class,
        updatedAt = time(),
    }

    if SBT.MainFrame and SBT.MainFrame:IsShown() and SBT.RefreshStatusTable then
        SBT:RefreshStatusTable()
    end
end

local CLASS_COLORS = {
    DEATHKNIGHT = { 0.77, 0.12, 0.23 }, DEMONHUNTER = { 0.64, 0.19, 0.79 },
    DRUID = { 1.00, 0.49, 0.04 }, EVOKER = { 0.20, 0.58, 0.50 },
    HUNTER = { 0.67, 0.83, 0.45 }, MAGE = { 0.25, 0.78, 0.92 },
    MONK = { 0.00, 1.00, 0.60 }, PALADIN = { 0.96, 0.55, 0.73 },
    PRIEST = { 1.00, 1.00, 1.00 }, ROGUE = { 1.00, 0.96, 0.41 },
    SHAMAN = { 0.00, 0.44, 0.87 }, WARLOCK = { 0.53, 0.53, 0.93 },
    WARRIOR = { 0.78, 0.61, 0.43 },
}

function SBT:ResolveCharacterClass(name, knownClass)
    if knownClass then return knownClass end
    if not (GetNumGuildMembers and GetGuildRosterInfo) then return nil end
    for index = 1, GetNumGuildMembers() do
        local rosterName, _, _, _, _, _, _, _, _, _, classFile = GetGuildRosterInfo(index)
        if rosterName == name or (Ambiguate and Ambiguate(rosterName or "", "none") ==
            Ambiguate(name or "", "none")) then
            return classFile
        end
    end
    return nil
end

function SBT:GetCharacterClassColor(class, stale)
    local color = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or CLASS_COLORS[class]
    if not color then return nil end
    local factor = stale and 0.6 or 1
    return { (color.r or color[1]) * factor, (color.g or color[2]) * factor,
        (color.b or color[3]) * factor, 1 }
end

function SBT:GetGuildStatusCache()
    local guildName = GetGuildInfo("player")
    if not SBT.db or not guildName then
        return nil
    end

    local guildKey = guildName .. "-" .. (GetRealmName() or "unknown")
    local cache = SBT.db.global.guildStatusCache
    local guildCache = cache and cache[guildKey]
    return (guildCache and guildCache.members) or {}
end

function SBT:CalculateSessionXPRate(xpGained, elapsedSeconds)
    if type(xpGained) ~= "number" or type(elapsedSeconds) ~= "number" or elapsedSeconds <= 0 then
        return nil
    end
    return math.max(0, xpGained) * 3600 / math.max(3600, elapsedSeconds)
end

function SBT:FormatCacheAge(updatedAt)
    if type(updatedAt) ~= "number" or updatedAt <= 0 then
        return "Unknown age", nil
    end

    local age = math.max(0, time() - updatedAt)
    if age < 60 then
        return "Just now", age
    elseif age < 3600 then
        return string.format("%dm ago", math.floor(age / 60)), age
    elseif age < 86400 then
        return string.format("%dh ago", math.floor(age / 3600)), age
    end
    return string.format("%dd ago", math.floor(age / 86400)), age
end
