local _, SBT = ...

function SBT:InitializeGUI()
    local THEME = SBT.Theme

    local MainFrame = CreateFrame("Frame", "StoneovenBayTools_MainFrame", UIParent, "BackdropTemplate")
    MainFrame:SetSize(1100, 700)
    MainFrame:SetPoint("CENTER")
    MainFrame:SetFrameStrata("HIGH")
    MainFrame:SetMovable(true)
    MainFrame:SetResizable(true)
    MainFrame:SetResizeBounds(760, 420, 1400, 900)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")

    local function clampFrameToScreen(frame)
        local width, height = frame:GetSize()
        local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
        local minVisibleW = width * 0.10
        local minVisibleH = height * 0.10

        local left = frame:GetLeft()
        local right = frame:GetRight()
        local top = frame:GetTop()
        local bottom = frame:GetBottom()

        if not left or not right or not top or not bottom then
            return
        end

        local needsClamp = false
        local clampedLeft, clampedTop = left, top

        if right < minVisibleW then
            clampedLeft = minVisibleW - width
            needsClamp = true
        elseif left > screenWidth - minVisibleW then
            clampedLeft = screenWidth - minVisibleW
            needsClamp = true
        end

        if top < minVisibleH then
            clampedTop = minVisibleH
            needsClamp = true
        elseif bottom > screenHeight - minVisibleH then
            clampedTop = screenHeight - minVisibleH + height
            needsClamp = true
        end

        if needsClamp then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedLeft, clampedTop)
        end
    end

    MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
    MainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        clampFrameToScreen(self)
    end)
    MainFrame:Hide()

    -- Standard Blizzard dialog chrome, present in every client build.
    MainFrame:SetBackdrop({
        bgFile = THEME.dialogBackground,
        edgeFile = THEME.dialogBorder,
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    table.insert(UISpecialFrames, MainFrame:GetName())

    MainFrame:SetScript("OnShow", function(self)
        clampFrameToScreen(self)
    end)

    local header = MainFrame:CreateTexture(nil, "ARTWORK")
    header:SetTexture(THEME.dialogHeader)
    header:SetSize(500, 64)
    header:SetPoint("TOP", MainFrame, "TOP", 0, 12)

    local title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", header, "TOP", 0, -13)
    title:SetTextColor(unpack(THEME.text))
    title:SetText("StoneovenBayTools")

    local closeButton = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -6, -6)

    local tabBar = CreateFrame("Frame", nil, MainFrame)
    tabBar:SetPoint("TOPLEFT", 20, -60)
    tabBar:SetSize(520, 32)

    local refreshButton = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    refreshButton:SetSize(160, 24)
    refreshButton:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -42, -66)
    refreshButton:SetText("Refresh guild data")
    refreshButton:SetScript("OnClick", function()
        local requested, message = SBT:RequestGuildSnapshots()
        SBT:PrettyPrint(requested and "Requested fresh data from online guild addon users." or message)
    end)

    local contentArea = CreateFrame("Frame", nil, MainFrame)
    contentArea:SetPoint("TOPLEFT", 20, -96)
    contentArea:SetPoint("BOTTOMRIGHT", -20, 20)

    local generalPanel = SBT.Widgets:CreatePanel(contentArea)
    generalPanel:SetAllPoints()

    local cachedDataPanel = SBT.Widgets:CreatePanel(contentArea)
    cachedDataPanel:SetAllPoints()

    local professionsPanel = SBT.Widgets:CreatePanel(contentArea)
    professionsPanel:SetAllPoints()
    SBT:InitializeProfessionPanel(professionsPanel)

    local statusPanel = SBT.Widgets:CreatePanel(contentArea)
    statusPanel:SetAllPoints()
    SBT:InitializeStatusPanel(statusPanel)

    local responseCheckbox = SBT.Widgets:CreateCheckbox(generalPanel, "Enable autoresponse to guild, party, and whisper queries", {
        getValue = function()
            local profile = SBT:GetProfileDB()
            return profile and profile.enableAutoResponse
        end,
        setValue = function(value)
            local profile = SBT:GetProfileDB()
            if profile then
                profile.enableAutoResponse = value
            end
        end,
    })
    responseCheckbox:SetPoint("TOPLEFT", 12, -12)

    local cooldownSlider, cooldownLabel = SBT.Widgets:CreateSlider(generalPanel, "Response cooldown", {
        min = 0,
        max = 60,
        step = 1,
        formatValue = function(value) return string.format("%d seconds", value) end,
        getValue = function()
            local profile = SBT:GetProfileDB()
            return profile and profile.responseCooldown or 0
        end,
        setValue = function(value)
            local profile = SBT:GetProfileDB()
            if profile then
                profile.responseCooldown = value
            end
        end,
    })
    cooldownLabel:SetPoint("TOPLEFT", 16, -52)
    cooldownSlider:SetPoint("TOPLEFT", 16, -76)

    local minimapCheckbox = SBT.Widgets:CreateCheckbox(generalPanel, "Show minimap button", {
        getValue = function()
            return not SBT:IsMinimapButtonHidden()
        end,
        setValue = function(value)
            SBT:SetMinimapButtonHidden(not value)
        end,
    })
    minimapCheckbox:SetPoint("TOPLEFT", 12, -116)

    local scrollFrame, scrollContent = SBT.Widgets:CreateScrollFrame(cachedDataPanel)
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local cacheRows = {}

    local function formatCachedEntry(command, data)
        if type(data) ~= "table" then
            return tostring(data)
        end

        if (command == "!status" or command == "sbt status") and data.level then
            return string.format("Level %d: %d/%dxp", data.level, data.currentXP or 0, data.maxXP or 0)
        elseif (command == "!professions" or command == "sbt professions") and type(data.professions) == "table" then
            local professions = {}
            for _, profession in ipairs(data.professions) do
                professions[#professions + 1] = string.format(
                    "%s %s/%s",
                    profession.name,
                    tostring(profession.skillLevel or 0),
                    tostring(profession.maxSkillLevel or 0)
                )
            end
            return #professions > 0 and table.concat(professions, ", ") or "No professions"
        elseif (command == "!location" or command == "sbt location") and data.zone then
            return string.format("%s (map %s)", data.zone, tostring(data.mapID))
        elseif data.current and data.today then
            return string.format("Current: %d XP; today: %d XP", data.current.xpGained or 0, data.today.xpGained or 0)
        elseif data.elapsed and data.xpGained then
            return string.format("%d XP in %dm", data.xpGained, math.floor(data.elapsed / 60))
        elseif data.message then
            return data.message
        end

        return "-"
    end

    function SBT:RefreshCachedDataTable()
        local offsetY = 0
        local rowCount = 0

        local function addRow(text, fontTemplate, indent, height, color)
            rowCount = rowCount + 1
            local row = cacheRows[rowCount]
            if not row then
                row = SBT.Widgets:CreateLabel(scrollContent)
                cacheRows[rowCount] = row
            end

            row:SetFontObject(_G[fontTemplate or "GameFontNormal"])
            row:SetTextColor(unpack(color or THEME.text))
            row:SetText(text)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 4 + (indent or 0), -offsetY)
            row:Show()
            offsetY = offsetY + (height or 16)
        end

        addRow("Guild professions", "GameFontNormal", 0, 22)

        local guildCache = SBT:GetGuildProfessionCache()
        if not guildCache then
            addRow("Join a guild to see shared profession data.", "GameFontNormalSmall", 12, 20)
        else
            local memberNames = {}
            for memberName in pairs(guildCache) do
                memberNames[#memberNames + 1] = memberName
            end
            table.sort(memberNames)

            if #memberNames == 0 then
                addRow("No guild professions received yet. Ask a guild member to use !professions.", "GameFontNormalSmall", 12, 20)
            end

            for _, memberName in ipairs(memberNames) do
                local entry = guildCache[memberName]
                local status = (SBT:GetGuildStatusCache() or {})[memberName]
                local class = SBT:ResolveCharacterClass(memberName,
                    (type(entry) == "table" and entry.class) or (status and status.class))
                addRow(memberName, "GameFontNormal", 12, 18, SBT:GetCharacterClassColor(class))

                local professions = type(entry) == "table" and entry.professions or nil
                if type(professions) ~= "table" or #professions == 0 then
                    addRow("No primary professions", "GameFontNormalSmall", 24, 16)
                else
                    for _, profession in ipairs(professions) do
                        addRow(string.format(
                            "%s %s/%s",
                            profession.name,
                            tostring(profession.skillLevel or 0),
                            tostring(profession.maxSkillLevel or 0)
                        ), "GameFontNormalSmall", 24, 16)
                    end
                end

                if type(entry) == "table" and type(entry.updatedAt) == "number" then
                    addRow("Updated " .. date("%Y-%m-%d %H:%M", entry.updatedAt), "GameFontNormalSmall", 24, 16)
                end
                offsetY = offsetY + 8
            end
        end

        offsetY = offsetY + 10
        addRow("Local command responses", "GameFontNormal", 0, 22)

        local profile = SBT:GetProfileDB()
        local cache = (profile and profile.memberStatusCache) or {}
        local playerNames = {}
        for playerName in pairs(cache) do
            playerNames[#playerNames + 1] = playerName
        end
        table.sort(playerNames)

        if #playerNames == 0 then
            addRow("No local responses cached yet.", "GameFontNormalSmall", 12, 20)
        end

        for _, playerName in ipairs(playerNames) do
            local entry = cache[playerName]
            local _, playerClass = UnitClass("player")
            addRow(playerName, "GameFontNormal", 12, 18, SBT:GetCharacterClassColor(playerClass))

            local commands = {}
            for command in pairs(entry) do
                if command ~= "updatedAt" then
                    table.insert(commands, command)
                end
            end
            table.sort(commands)

            for _, command in ipairs(commands) do
                addRow(
                    string.format("%s: %s", command, formatCachedEntry(command, entry[command])),
                    "GameFontNormalSmall", 24, 16
                )
            end

            offsetY = offsetY + 8
        end

        for index = rowCount + 1, #cacheRows do
            cacheRows[index]:Hide()
        end
        scrollContent:SetHeight(math.max(offsetY, 1))
    end

    SBT.Widgets:CreateTabGroup(tabBar, {
        { text = "General", panel = generalPanel },
        { text = "Guild Professions", panel = professionsPanel, onSelect = function() SBT:RefreshProfessionRoster() end },
        { text = "Guild Status", panel = statusPanel, onSelect = function() SBT:RefreshStatusTable() end },
        { text = "Cached Data", panel = cachedDataPanel, onSelect = function() SBT:RefreshCachedDataTable() end },
    })

    function SBT:RefreshSettingsGUI()
        responseCheckbox:Refresh()
        cooldownSlider:Refresh()
        minimapCheckbox:Refresh()
        SBT:RefreshProfessionRoster()
        SBT:RefreshStatusTable()
        SBT:RefreshCachedDataTable()
    end

    MainFrame:HookScript("OnShow", function()
        SBT:RefreshSettingsGUI()
    end)

    local ageRefreshElapsed = 0
    MainFrame:HookScript("OnUpdate", function(_, elapsed)
        ageRefreshElapsed = ageRefreshElapsed + elapsed
        if ageRefreshElapsed < 60 then
            return
        end
        ageRefreshElapsed = 0

        if professionsPanel:IsShown() then
            SBT:RefreshProfessionRoster()
        elseif statusPanel:IsShown() then
            SBT:RefreshStatusTable()
        end
    end)

    SBT.MainFrame = MainFrame
end
