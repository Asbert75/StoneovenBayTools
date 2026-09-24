local _, SBT = ...

function SBT:getHelpMessage()
    return table.concat({
        "sbt help",
        "sbt status",
        "sbt professions",
        "sbt location",
        "sbt session"
    }, "\n")
end

SLASH_STONEOVENBAYTOOLS1 = "/sbt"
SLASH_STONEOVENBAYTOOLS2 = "/stoneovenbaytools"
SlashCmdList.STONEOVENBAYTOOLS = function(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    local database = SBT:GetProfileDB()

    if command == "on" or command == "enable" then
        database.enableAutoResponse = true
        SBT:PrettyPrint("Guild responses enabled.")
    elseif command == "off" or command == "disable" then
        database.enableAutoResponse = false
        SBT:PrettyPrint("Guild responses disabled.")
    elseif command == "status" or command == "config" then
        SBT:PrettyPrint(string.format(
            "Guild responses are %s. Cooldown: %d seconds.",
            database.enableAutoResponse and "enabled" or "disabled",
            database.responseCooldown
        ))
    elseif command == "ui" then
        SBT:ToggleMainFrame()
    elseif command == "minimap" then
        SBT:SetMinimapButtonHidden(not SBT:IsMinimapButtonHidden())
        SBT:PrettyPrint(string.format("Minimap button %s.", SBT:IsMinimapButtonHidden() and "hidden" or "shown"))
        if SBT.RefreshSettingsGUI then
            SBT:RefreshSettingsGUI()
        end
    else
        SBT:PrettyPrint("Local commands:\n/sbt on\n/sbt off\n/sbt status\n/sbt ui\n/sbt minimap\n\nGuild tools:\n" .. SBT:getHelpMessage())
    end
end
