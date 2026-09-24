local _, SBT = ...

function SBT:InitializeGUI()
    local THEME = SBT.Theme

    local MainFrame = CreateFrame("Frame", "StoneovenBayTools_MainFrame", UIParent, "BackdropTemplate")
    MainFrame:SetSize(1100, 700)
    MainFrame:SetPoint("CENTER")
    MainFrame:SetFrameStrata("HIGH")
    MainFrame:SetMovable(true)
    MainFrame:SetResizable(true)
    MainFrame:SetResizeBounds(500, 420, 1400, 900)
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
    tabBar:SetSize(400, 32)

    local contentArea = CreateFrame("Frame", nil, MainFrame)
    contentArea:SetPoint("TOPLEFT", 20, -96)
    contentArea:SetPoint("BOTTOMRIGHT", -20, 20)

    local generalPanel = SBT.Widgets:CreatePanel(contentArea)
    generalPanel:SetAllPoints()

    local cachedDataPanel = SBT.Widgets:CreatePanel(contentArea)
    cachedDataPanel:SetAllPoints()

    local responseCheckbox = SBT.Widgets:CreateCheckbox(generalPanel, "Enable autoresponse to guild and whisper queries", {
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

    local scrollFrame, scrollContent = SBT.Widgets:CreateScrollFrame(cachedDataPanel)
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local cacheRows = {}

    local function formatCachedEntry(command, data)
        if type(data) ~= "table" then
            return tostring(data)
        end

        if command == "sbt status" and data.level then
            return string.format("Level %d: %d/%dxp", data.level, data.currentXP or 0, data.maxXP or 0)
        elseif command == "sbt location" and data.zone then
            return string.format("%s (map %s)", data.zone, tostring(data.mapID))
        elseif data.message then
            return data.message
        end

        return "-"
    end

    function SBT:RefreshCachedDataTable()
        for _, fontString in ipairs(cacheRows) do
            fontString:Hide()
        end
        wipe(cacheRows)

        local profile = SBT:GetProfileDB()
        local cache = (profile and profile.memberStatusCache) or {}

        local playerNames = {}
        for playerName in pairs(cache) do
            table.insert(playerNames, playerName)
        end
        table.sort(playerNames)

        local offsetY = 0

        if #playerNames == 0 then
            local emptyLabel = SBT.Widgets:CreateLabel(scrollContent, "No cached data yet. Guild tool queries will populate this list.")
            emptyLabel:SetPoint("TOPLEFT", 4, -offsetY)
            table.insert(cacheRows, emptyLabel)
            offsetY = offsetY + 20
        end

        for _, playerName in ipairs(playerNames) do
            local entry = cache[playerName]

            local nameLabel = SBT.Widgets:CreateLabel(scrollContent, playerName, "GameFontNormal")
            nameLabel:SetPoint("TOPLEFT", 4, -offsetY)
            table.insert(cacheRows, nameLabel)
            offsetY = offsetY + 18

            local commands = {}
            for command in pairs(entry) do
                if command ~= "updatedAt" then
                    table.insert(commands, command)
                end
            end
            table.sort(commands)

            for _, command in ipairs(commands) do
                local detailLabel = SBT.Widgets:CreateLabel(
                    scrollContent,
                    string.format("  %s: %s", command, formatCachedEntry(command, entry[command])),
                    "GameFontNormalSmall"
                )
                detailLabel:SetPoint("TOPLEFT", 4, -offsetY)
                table.insert(cacheRows, detailLabel)
                offsetY = offsetY + 16
            end

            offsetY = offsetY + 8
        end

        scrollContent:SetHeight(math.max(offsetY, 1))
    end

    SBT.Widgets:CreateTabGroup(tabBar, {
        { text = "General", panel = generalPanel },
        { text = "Cached Data", panel = cachedDataPanel, onSelect = function() SBT:RefreshCachedDataTable() end },
    })

    function SBT:RefreshSettingsGUI()
        responseCheckbox:Refresh()
        cooldownSlider:Refresh()
        SBT:RefreshCachedDataTable()
    end

    MainFrame:HookScript("OnShow", function()
        SBT:RefreshSettingsGUI()
    end)

    SBT.MainFrame = MainFrame
end
