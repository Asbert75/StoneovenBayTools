local _, SBT = ...

local columns = {
    { key = "name", label = "Character", width = 0.16, left = true },
    { key = "level", label = "Level", width = 0.05 },
    { key = "currentXP", label = "Cur XP", width = 0.10 },
    { key = "maxXP", label = "Max XP", width = 0.10 },
    { key = "progress", label = "Progress", width = 0.08 },
    { key = "remaining", label = "XP left", width = 0.09 },
    { key = "sessionElapsed", label = "Session", width = 0.09 },
    { key = "sessionXPGained", label = "Gained", width = 0.10 },
    { key = "xpPerHour", label = "XP/hour", width = 0.09 },
    { key = "updatedAt", label = "Updated", width = 0.14 },
}

local function formatNumber(value)
    local reversed = tostring(math.floor(value or 0)):reverse():gsub("(%d%d%d)", "%1 ")
    return (reversed:reverse():gsub("^ ", ""))
end

local function formatDuration(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    end
    return string.format("%dm %02ds", minutes, seconds % 60)
end

local function makeRows(cache)
    local rows = {}
    for name, status in pairs(cache or {}) do
        if type(status) == "table" then
            local currentXP = tonumber(status.currentXP) or 0
            local maxXP = tonumber(status.maxXP) or 0
            local sessionElapsed = tonumber(status.sessionElapsed)
            local sessionXPGained = tonumber(status.sessionXPGained)
            rows[#rows + 1] = {
                name = name,
                level = tonumber(status.level) or 0,
                currentXP = currentXP,
                maxXP = maxXP,
                progress = maxXP > 0 and math.min(1, math.max(0, currentXP / maxXP)) or 1,
                remaining = maxXP > 0 and math.max(0, maxXP - currentXP) or 0,
                sessionElapsed = sessionElapsed,
                sessionXPGained = sessionXPGained,
                xpPerHour = SBT:CalculateSessionXPRate(sessionXPGained, sessionElapsed),
                class = status.class,
                updatedAt = tonumber(status.updatedAt) or 0,
            }
        end
    end
    return rows
end

function SBT:SortGuildStatusRows(cache, sortKey, ascending)
    local rows = makeRows(cache)
    table.sort(rows, function(a, b)
        local left = a[sortKey]
        local right = b[sortKey]
        if left == nil or right == nil then
            if left == nil and right == nil then
                return a.name < b.name
            end
            return right == nil
        end
        if sortKey == "name" then
            left, right = left:lower(), right:lower()
        end
        if left == right then
            if sortKey == "level" and a.progress ~= b.progress then
                return a.progress > b.progress
            end
            return a.name < b.name
        end
        if ascending then
            return left < right
        end
        return left > right
    end)
    return rows
end

function SBT:InitializeStatusPanel(panel)
    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", 12, -12)
    header:SetPoint("TOPRIGHT", -28, -12)
    header:SetHeight(32)

    local scrollFrame, content = SBT.Widgets:CreateScrollFrame(panel)
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 12)

    local sortKey, ascending = "level", false
    local headerButtons = {}
    local displayRows = {}
    local emptyLabel = SBT.Widgets:CreateLabel(content, nil, "GameFontNormal")
    emptyLabel:SetPoint("TOPLEFT", 8, -10)

    local function layoutCells(frame, cells)
        local available = math.max(1, frame:GetWidth() - 16)
        local x = 8
        for index, column in ipairs(columns) do
            local width = index == #columns and available - (x - 8) or math.floor(available * column.width)
            local cell = cells[index]
            cell:ClearAllPoints()
            cell:SetPoint("LEFT", frame, "LEFT", x, 0)
            cell:SetSize(math.max(1, width), frame:GetHeight())
            x = x + width
        end
    end

    for index, column in ipairs(columns) do
        local button = CreateFrame("Button", nil, header)
        local label = SBT.Widgets:CreateLabel(button, nil, "GameFontNormalSmall")
        label:SetAllPoints()
        label:SetJustifyH(column.left and "LEFT" or "RIGHT")
        if label.SetWordWrap then
            label:SetWordWrap(false)
        end
        button.label = label
        button:SetScript("OnClick", function()
            if sortKey == column.key then
                ascending = not ascending
            else
                sortKey = column.key
                ascending = sortKey == "name"
            end
            SBT:RefreshStatusTable()
        end)
        headerButtons[index] = button
    end
    header:HookScript("OnSizeChanged", function(self)
        layoutCells(self, headerButtons)
    end)

    local function getDisplayRow(index)
        if displayRows[index] then
            return displayRows[index]
        end

        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(30)
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints()
        row.background:SetColorTexture(0.15, 0.16, 0.17, 0.45)
        row.cells = {}

        for columnIndex, column in ipairs(columns) do
            local cell = SBT.Widgets:CreateLabel(row, nil, "GameFontNormalSmall")
            cell:SetJustifyH(column.left and "LEFT" or "RIGHT")
            if cell.SetWordWrap then
                cell:SetWordWrap(false)
            end
            row.cells[columnIndex] = cell
        end

        row:HookScript("OnSizeChanged", function(self)
            layoutCells(self, self.cells)
        end)
        displayRows[index] = row
        return row
    end

    function SBT:RefreshStatusTable()
        for index, column in ipairs(columns) do
            headerButtons[index].label:SetText(column.label .. (sortKey == column.key and (ascending and " ^" or " v") or ""))
        end
        layoutCells(header, headerButtons)

        local cache = SBT:GetGuildStatusCache()
        local professionCache = SBT:GetGuildProfessionCache() or {}
        local rows = SBT:SortGuildStatusRows(cache, sortKey, ascending)
        if not cache then
            emptyLabel:SetText("Join a guild to see shared status data.")
        else
            emptyLabel:SetText("No guild status saved yet. Ask a guild member to use !status.")
        end
        emptyLabel:SetShown(#rows == 0)

        for index, status in ipairs(rows) do
            local row = getDisplayRow(index)
            local ageText, age = SBT:FormatCacheAge(status.updatedAt)
            local color = (not age or age > 1800) and SBT.Theme.textDisabled or SBT.Theme.text
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * 30)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(index - 1) * 30)
            row.background:SetShown(index % 2 == 0)
            row.cells[1]:SetText(status.name)
            row.cells[2]:SetText(tostring(status.level))
            row.cells[3]:SetText(status.maxXP > 0 and formatNumber(status.currentXP) or "-")
            row.cells[4]:SetText(status.maxXP > 0 and formatNumber(status.maxXP) or "-")
            row.cells[5]:SetText(status.maxXP > 0 and string.format("%.0f%%", status.progress * 100) or "Max")
            row.cells[6]:SetText(status.maxXP > 0 and formatNumber(status.remaining) or "-")
            row.cells[7]:SetText(status.sessionElapsed and formatDuration(status.sessionElapsed) or "-")
            row.cells[8]:SetText(status.sessionXPGained and formatNumber(status.sessionXPGained) or "-")
            row.cells[9]:SetText(status.xpPerHour and formatNumber(math.floor(status.xpPerHour + 0.5)) or "-")
            row.cells[10]:SetText(ageText)
            for _, cell in ipairs(row.cells) do
                cell:SetTextColor(unpack(color))
            end
            local professionEntry = professionCache[status.name]
            local class = SBT:ResolveCharacterClass(status.name, status.class or
                (professionEntry and professionEntry.class))
            row.cells[1]:SetTextColor(unpack(SBT:GetCharacterClassColor(class, not age or age > 1800) or color))
            layoutCells(row, row.cells)
            row:Show()
        end

        for index = #rows + 1, #displayRows do
            displayRows[index]:Hide()
        end
        content:SetHeight(math.max(40, #rows * 30))
    end
end
