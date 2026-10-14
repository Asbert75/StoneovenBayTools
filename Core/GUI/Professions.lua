local _, SBT = ...

local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ROW_HEIGHT = 48

function SBT:InitializeProfessionPanel(panel)
    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", 12, -12)
    header:SetPoint("TOPRIGHT", -28, -12)
    header:SetHeight(22)

    local scrollFrame, content = SBT.Widgets:CreateScrollFrame(panel)
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 12)

    local rows = {}
    local headings = {}
    for index, title in ipairs({ "Character", "Primary professions", "Secondary professions" }) do
        local label = SBT.Widgets:CreateLabel(header, title, "GameFontNormalSmall")
        label:SetJustifyH("LEFT")
        headings[index] = label
    end

    local function layoutColumns(frame, cells)
        local width = math.max(1, frame:GetWidth() - 12)
        local starts = { 8, 8 + math.floor(width * 0.25), 8 + math.floor(width * 0.60) }
        local widths = { math.floor(width * 0.25), math.floor(width * 0.35), width - math.floor(width * 0.60) }
        for index, cell in ipairs(cells) do
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", frame, "TOPLEFT", starts[index], 0)
            cell:SetSize(widths[index], frame:GetHeight())
        end
    end

    header:HookScript("OnSizeChanged", function(self) layoutColumns(self, headings) end)

    local function createProfessionItem(parent, line)
        local icon = parent:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("TOPLEFT", 2, -3 - (line - 1) * 14)

        local label = SBT.Widgets:CreateLabel(parent, nil, "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", icon, "TOPRIGHT", 4, 0)
        label:SetPoint("RIGHT", parent, "RIGHT", -2, 0)
        label:SetHeight(14)
        label:SetJustifyH("LEFT")
        if label.SetWordWrap then label:SetWordWrap(false) end
        return { icon = icon, label = label }
    end

    local function getRow(index)
        if rows[index] then return rows[index] end

        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_HEIGHT)
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints()
        row.background:SetColorTexture(0.15, 0.16, 0.17, 0.45)
        row.cells = {}
        for cellIndex = 1, 3 do
            row.cells[cellIndex] = CreateFrame("Frame", nil, row)
        end

        row.name = SBT.Widgets:CreateLabel(row.cells[1], nil, "GameFontNormalSmall")
        row.name:SetPoint("TOPLEFT", 2, -7)
        row.name:SetPoint("RIGHT", row.cells[1], "RIGHT", -2, 0)
        row.name:SetHeight(15)
        row.name:SetJustifyH("LEFT")
        if row.name.SetWordWrap then row.name:SetWordWrap(false) end

        row.details = SBT.Widgets:CreateLabel(row.cells[1], nil, "GameFontNormalSmall")
        row.details:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.details:SetPoint("RIGHT", row.cells[1], "RIGHT", -2, 0)
        row.details:SetHeight(14)
        row.details:SetJustifyH("LEFT")
        if row.details.SetWordWrap then row.details:SetWordWrap(false) end

        row.primaryItems, row.secondaryItems = {}, {}
        for line = 1, 2 do
            row.primaryItems[line] = createProfessionItem(row.cells[2], line)
        end
        for line = 1, 3 do
            row.secondaryItems[line] = createProfessionItem(row.cells[3], line)
        end

        row:HookScript("OnSizeChanged", function(self) layoutColumns(self, self.cells) end)
        rows[index] = row
        return row
    end

    local emptyLabel = SBT.Widgets:CreateLabel(content, nil, "GameFontNormalSmall")
    emptyLabel:SetPoint("TOPLEFT", 8, -8)

    local function fillItems(items, professions, stale)
        for index, item in ipairs(items) do
            local profession = professions and professions[index]
            if type(profession) == "table" then
                item.icon:SetTexture(profession.icon or UNKNOWN_ICON)
                local tint = stale and 0.55 or 1
                item.icon:SetVertexColor(tint, tint, tint)
                item.label:SetText(string.format("%s %s/%s", profession.name or "Unknown",
                    tostring(profession.skillLevel or 0), tostring(profession.maxSkillLevel or 0)))
                item.label:SetTextColor(unpack(stale and SBT.Theme.textDisabled or SBT.Theme.text))
                item.icon:Show()
                item.label:Show()
            else
                item.icon:Hide()
                item.label:Hide()
            end
        end
    end

    function SBT:RefreshProfessionRoster()
        layoutColumns(header, headings)
        local cache = SBT:GetGuildProfessionCache()
        local statuses = SBT:GetGuildStatusCache() or {}
        local names = {}
        for name in pairs(cache or {}) do names[#names + 1] = name end
        table.sort(names)

        if not cache then
            emptyLabel:SetText("Join a guild to see shared profession data.")
        else
            emptyLabel:SetText("No professions saved yet. Click Refresh guild data or use !professions.")
        end
        emptyLabel:SetShown(#names == 0)

        for index, name in ipairs(names) do
            local entry = cache[name]
            local row = getRow(index)
            local ageText, age = SBT:FormatCacheAge(entry.updatedAt)
            local stale = not age or age > 30 * 86400
            local class = SBT:ResolveCharacterClass(name, entry.class or (statuses[name] and statuses[name].class))
            local nameColor = SBT:GetCharacterClassColor(class, stale) or
                (stale and SBT.Theme.textDisabled or SBT.Theme.text)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
            row.background:SetShown(index % 2 == 0)
            row.name:SetText(name)
            row.name:SetTextColor(unpack(nameColor))
            row.details:SetText((entry.level and "Lv " .. entry.level .. "  ·  " or "") .. ageText)
            row.details:SetTextColor(unpack(stale and SBT.Theme.textDisabled or SBT.Theme.text))

            local primary = entry.primaryProfessions or entry.professions or {}
            local secondary = entry.secondaryProfessions or {}
            fillItems(row.primaryItems, primary, stale)
            fillItems(row.secondaryItems, secondary, stale)
            layoutColumns(row, row.cells)
            row:Show()
        end

        for index = #names + 1, #rows do rows[index]:Hide() end
        content:SetHeight(math.max(40, #names * ROW_HEIGHT))
    end
end
