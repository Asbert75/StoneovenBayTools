local ADDON, SBT = ...

SBT.DB_DEFAULTS = {
    enableAutoResponse = true,
    responseCooldown = 10,
    minimapButtonAngle = 220,
    memberStatusCache = {}
}

function SBT.GetDatabase()
    StoneovenBayToolsDB = StoneovenBayToolsDB or {}

    for key, defaultValue in pairs(SBT.DB_DEFAULTS) do
        if StoneovenBayToolsDB[key] == nil then
            StoneovenBayToolsDB[key] = defaultValue
        end
    end

    SBT.MemberStatusCache = StoneovenBayToolsDB.memberStatusCache
    return StoneovenBayToolsDB
end

local function getHelpMessage()
    return table.concat({
        "sbt help",
        "sbt status",
        "sbt professions",
        "sbt location"
    }, "\n")
end

SLASH_STONEOVENBAYTOOLS1 = "/sbt"
SLASH_STONEOVENBAYTOOLS2 = "/stoneovenbaytools"
SlashCmdList.STONEOVENBAYTOOLS = function(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    local database = SBT.GetDatabase()

    if command == "on" or command == "enable" then
        database.enableAutoResponse = true
        print(SBT.PREFIX .. "Guild responses enabled.")
    elseif command == "off" or command == "disable" then
        database.enableAutoResponse = false
        print(SBT.PREFIX .. "Guild responses disabled.")
    elseif command == "status" or command == "config" then
        print(SBT.PREFIX .. string.format(
            "Guild responses are %s. Cooldown: %d seconds.",
            database.enableAutoResponse and "enabled" or "disabled",
            database.responseCooldown
        ))
    elseif command == "ui" then
        SBT:ToggleMainFrame()
    else
        print(SBT.PREFIX .. "Local commands:\n/sbt on\n/sbt off\n/sbt status\n/sbt ui\n\nGuild tools:\n" .. getHelpMessage())
    end
end
