local _, ns = ...
ns = ns or {}

local Store = ns.Store
local FilterBar = {}
ns.FilterBar = FilterBar

local ROW_HEIGHT = 22
local SEARCH_ROW_HEIGHT = 22
local FALLBACK_ROW_HEIGHT = 20

local PILLS = {
    { mode = "ALL", label = "All", width = 34 },
    { mode = "ZONE", label = "Zone", width = 44 },
    { mode = "DUNGEON", label = "Dung", width = 46 },
    { mode = "READY", label = "Ready", width = 48 },
}

local FilterBarModuleMixin = {
    isModule = true,
    uiOrder = 3.5,
    leftMargin = 0,
    hasDisplayPriority = false,
    mustFit = false,
    isDirty = false,
    contentsHeight = 0,
}

function FilterBarModuleMixin:SetContainer(container)
    self.parentContainer = container
    self:SetParent(container)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT")
end

function FilterBarModuleMixin:InitModule()
end

function FilterBarModuleMixin:MarkDirty()
    self.isDirty = true
    if self.parentContainer and self.parentContainer.MarkDirty then
        self.parentContainer:MarkDirty()
    end
end

function FilterBarModuleMixin:IsDirty()
    return self.isDirty
end

function FilterBarModuleMixin:IsTruncated()
    return false
end

function FilterBarModuleMixin:HasSkippedBlocks()
    return false
end

function FilterBarModuleMixin:IsComplete()
    return true
end

function FilterBarModuleMixin:MatchesTag()
    return false
end

function FilterBarModuleMixin:EnumerateActiveBlocks()
end

function FilterBarModuleMixin:EndSlide()
end

function FilterBarModuleMixin:GetContentsHeight()
    return self.contentsHeight or 0
end

function FilterBarModuleMixin:RefreshVisualState()
    local acc = Store:GetAccount()
    local ch = Store:GetChar()
    local activeMode = ch.filterMode or "ALL"

    for _, btn in ipairs(self.pillButtons or {}) do
        local isSelected = (btn.filterMode == activeMode)
        if isSelected then
            btn.Label:SetTextColor(1.0, 0.82, 0.0)
            btn.ActiveUnderline:Show()
            btn.Bg:SetColorTexture(0.28, 0.22, 0.06, 0.72)
        else
            btn.Label:SetTextColor(0.80, 0.80, 0.80)
            btn.ActiveUnderline:Hide()
            btn.Bg:SetColorTexture(0.08, 0.08, 0.08, 0.45)
        end
    end

    if self.grayBtn then
        if ch.hideGray then
            self.grayBtn.Label:SetTextColor(1.0, 0.82, 0.0)
            self.grayBtn.Bg:SetColorTexture(0.28, 0.22, 0.06, 0.72)
        else
            self.grayBtn.Label:SetTextColor(0.62, 0.62, 0.62)
            self.grayBtn.Bg:SetColorTexture(0.08, 0.08, 0.08, 0.45)
        end
    end

    local hasSearchText = (ch.searchQuery or "") ~= ""
    local showSearch = ch.searchExpanded or hasSearchText
    if self.searchBtn then
        if showSearch then
            self.searchBtn.Label:SetTextColor(1.0, 0.82, 0.0)
            self.searchBtn.Bg:SetColorTexture(0.28, 0.22, 0.06, 0.72)
        else
            self.searchBtn.Label:SetTextColor(0.80, 0.80, 0.80)
            self.searchBtn.Bg:SetColorTexture(0.08, 0.08, 0.08, 0.45)
        end
    end

    if self.searchRow then
        self.searchRow:SetShown(showSearch and acc.showFilterBar ~= false)
        if self.searchBox and self.searchBox:GetText() ~= (ch.searchQuery or "") then
            self.updatingSearchText = true
            self.searchBox:SetText(ch.searchQuery or "")
            self.updatingSearchText = false
        end
    end

    if self.combatBadge then
        self.combatBadge:SetShown(self.pendingCombatReflow == true)
    end

    local showFallback = self.fallbackMessage ~= nil and self.fallbackMessage ~= ""
    if self.fallbackBtn then
        if showFallback then
            self.fallbackBtn.Text:SetText(self.fallbackMessage)
            local topOffset = -(ROW_HEIGHT + (showSearch and SEARCH_ROW_HEIGHT or 0) + 2)
            if acc.showFilterBar == false then
                topOffset = -2
            end
            self.fallbackBtn:ClearAllPoints()
            self.fallbackBtn:SetPoint("TOPLEFT", self, "TOPLEFT", 6, topOffset)
            self.fallbackBtn:SetPoint("TOPRIGHT", self, "TOPRIGHT", -4, topOffset)
            self.fallbackBtn:Show()
        else
            self.fallbackBtn:Hide()
        end
    end
end

function FilterBarModuleMixin:ComputeDesiredHeight()
    local acc = Store:GetAccount()
    local ch = Store:GetChar()
    if not acc.enabled then
        return 0
    end

    local totalWatched = self.totalWatched or 0
    local hasNonDefaultState = (ch.filterMode ~= "ALL")
        or ch.hideGray
        or ((ch.searchQuery or "") ~= "")
        or ch.searchExpanded

    if totalWatched == 0 and not hasNonDefaultState then
        return 0
    end

    local height = 0
    if acc.showFilterBar ~= false then
        height = height + ROW_HEIGHT
        if ch.searchExpanded or ((ch.searchQuery or "") ~= "") then
            height = height + SEARCH_ROW_HEIGHT
        end
    end
    if self.fallbackMessage and self.fallbackMessage ~= "" then
        height = height + FALLBACK_ROW_HEIGHT + 2
    end
    return height
end

function FilterBarModuleMixin:Update(availableHeight)
    self.isDirty = false
    local desired = self:ComputeDesiredHeight()
    if desired <= 0 or (availableHeight and availableHeight < desired) then
        self.contentsHeight = 0
        self:Hide()
        return 0, false
    end

    self.contentsHeight = desired
    self:SetHeight(desired)
    self:RefreshVisualState()

    local containerCollapsed = self.parentContainer and self.parentContainer.IsCollapsed
        and self.parentContainer:IsCollapsed()
    if containerCollapsed then
        self:Hide()
    else
        local acc = Store:GetAccount()
        if self.topRow then
            self.topRow:SetShown(acc.showFilterBar ~= false)
        end
        self:Show()
    end

    return self.contentsHeight, false
end

local function CreatePillButton(parent, label, width, tooltipTitle, tooltipBody, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, 18)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.45)
    btn.Bg = bg

    local borderTop = btn:CreateTexture(nil, "BORDER")
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(0.45, 0.38, 0.20, 0.55)

    local underline = btn:CreateTexture(nil, "OVERLAY")
    underline:SetHeight(2)
    underline:SetPoint("BOTTOMLEFT", 1, 0)
    underline:SetPoint("BOTTOMRIGHT", -1, 0)
    underline:SetColorTexture(1.0, 0.82, 0.0, 0.95)
    underline:Hide()
    btn.ActiveUnderline = underline

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1.0, 0.85, 0.35, 0.16)

    local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText(label)
    btn.Label = fs

    btn:SetScript("OnClick", function(self)
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
        onClick(self)
    end)

    if tooltipTitle then
        btn:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:SetText(tooltipTitle, 1, 0.82, 0)
                if tooltipBody then
                    GameTooltip:AddLine(tooltipBody, 0.85, 0.85, 0.85, true)
                end
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
    end

    return btn
end

function FilterBar.Create(parentContainer, callbacks)
    local frame = CreateFrame("Frame", "QuestSectionsPlusFilterBar", parentContainer)
    frame:SetSize(260, ROW_HEIGHT)
    Mixin(frame, FilterBarModuleMixin)
    frame.pillButtons = {}
    frame.totalWatched = 0
    frame.fallbackMessage = nil
    frame.pendingCombatReflow = false

    local topRow = CreateFrame("Frame", nil, frame)
    topRow:SetHeight(ROW_HEIGHT)
    topRow:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, 0)
    topRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, 0)
    frame.topRow = topRow

    local xOffset = 0
    for _, spec in ipairs(PILLS) do
        local btn = CreatePillButton(
            topRow,
            spec.label,
            spec.width,
            "Filter: " .. spec.label,
            "Non-destructively filter displayed quests without untracking.",
            function()
                if callbacks and callbacks.onSelectFilter then
                    callbacks.onSelectFilter(spec.mode)
                end
            end
        )
        btn.filterMode = spec.mode
        btn:SetPoint("LEFT", topRow, "LEFT", xOffset, 0)
        xOffset = xOffset + spec.width + 3
        frame.pillButtons[#frame.pillButtons + 1] = btn
    end

    local grayBtn = CreatePillButton(
        topRow,
        "!Gray",
        40,
        "Hide Trivial (Gray) Quests",
        "Hides low-level gray quests from the tracker display.",
        function()
            if callbacks and callbacks.onToggleHideGray then
                callbacks.onToggleHideGray()
            end
        end
    )
    grayBtn:SetPoint("LEFT", topRow, "LEFT", xOffset, 0)
    xOffset = xOffset + 43
    frame.grayBtn = grayBtn

    local searchBtn = CreatePillButton(
        topRow,
        "Find",
        34,
        "Search Tracked Quests",
        "Filter quests by title, zone, level, or objective text.",
        function()
            local ch = Store:GetChar()
            local nextExpanded = not ch.searchExpanded
            Store:SetSearchExpanded(nextExpanded)
            if not nextExpanded and (ch.searchQuery or "") ~= "" then
                Store:SetSearchQuery("")
            end
            if callbacks and callbacks.onSearchChanged then
                callbacks.onSearchChanged()
            end
            if nextExpanded and frame.searchBox and frame.searchBox.SetFocus then
                frame.searchBox:SetFocus()
            end
        end
    )
    searchBtn:SetPoint("LEFT", topRow, "LEFT", xOffset, 0)
    frame.searchBtn = searchBtn

    local combatBadge = topRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    combatBadge:SetPoint("BOTTOMRIGHT", topRow, "TOPRIGHT", -2, 1)
    combatBadge:SetText("|cffff9900(Queued)|r")
    combatBadge:Hide()
    frame.combatBadge = combatBadge

    -- Expandable Search Row
    local searchRow = CreateFrame("Frame", nil, frame)
    searchRow:SetHeight(SEARCH_ROW_HEIGHT)
    searchRow:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -ROW_HEIGHT)
    searchRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -ROW_HEIGHT)
    searchRow:Hide()
    frame.searchRow = searchRow

    local searchBox = CreateFrame("EditBox", "QuestSectionsPlusSearchBox", searchRow, "InputBoxTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetHeight(18)
    searchBox:SetPoint("LEFT", searchRow, "LEFT", 4, 0)
    searchBox:SetPoint("RIGHT", searchRow, "RIGHT", -22, 0)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if (self:GetText() or "") == "" then
            Store:SetSearchExpanded(false)
            if callbacks and callbacks.onSearchChanged then
                callbacks.onSearchChanged()
            end
        end
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnTextChanged", function(self)
        if frame.updatingSearchText then
            return
        end
        Store:SetSearchQuery(self:GetText() or "")
        if callbacks and callbacks.onSearchChanged then
            callbacks.onSearchChanged()
        end
    end)
    frame.searchBox = searchBox

    local clearBtn = CreatePillButton(
        searchRow,
        "x",
        18,
        "Clear Search",
        nil,
        function()
            Store:SetSearchQuery("")
            Store:SetSearchExpanded(false)
            if frame.searchBox then
                frame.searchBox:ClearFocus()
            end
            if callbacks and callbacks.onSearchChanged then
                callbacks.onSearchChanged()
            end
        end
    )
    clearBtn:SetPoint("RIGHT", searchRow, "RIGHT", 0, 0)
    frame.clearBtn = clearBtn

    -- Blame-free Empty Filter Fallback Action Row
    local fallbackBtn = CreateFrame("Button", nil, frame)
    fallbackBtn:SetHeight(FALLBACK_ROW_HEIGHT)
    fallbackBtn:Hide()

    local fbBg = fallbackBtn:CreateTexture(nil, "BACKGROUND")
    fbBg:SetAllPoints()
    fbBg:SetColorTexture(0.12, 0.10, 0.04, 0.55)

    local fbHl = fallbackBtn:CreateTexture(nil, "HIGHLIGHT")
    fbHl:SetAllPoints()
    fbHl:SetColorTexture(1.0, 0.82, 0.0, 0.15)

    local fbText = fallbackBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fbText:SetPoint("LEFT", fallbackBtn, "LEFT", 6, 0)
    fbText:SetPoint("RIGHT", fallbackBtn, "RIGHT", -4, 0)
    fbText:SetJustifyH("LEFT")
    fbText:SetTextColor(0.90, 0.80, 0.50)
    fallbackBtn.Text = fbText

    fallbackBtn:SetScript("OnClick", function()
        Store:SetFilterMode("ALL")
        Store:SetSearchQuery("")
        Store:SetHideGray(false)
        if callbacks and callbacks.onResetFilters then
            callbacks.onResetFilters()
        end
    end)
    frame.fallbackBtn = fallbackBtn

    -- Wire Blizzard's native Header.FilterButton on ObjectiveTrackerFrame if available
    if parentContainer and parentContainer.Header and parentContainer.Header.FilterButton then
        local nativeFilterBtn = parentContainer.Header.FilterButton
        nativeFilterBtn:Show()
        nativeFilterBtn:SetScript("OnClick", function()
            local acc = Store:GetAccount()
            Store:SetAccountOption("showFilterBar", not acc.showFilterBar)
            if callbacks and callbacks.onToggleFilterBar then
                callbacks.onToggleFilterBar()
            end
        end)
        nativeFilterBtn:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:SetText("QuestSectionsPlus Filter Bar", 1, 0.82, 0)
                GameTooltip:AddLine("Click to show or hide the quick filter toolbar.", 0.85, 0.85, 0.85, true)
                GameTooltip:Show()
            end
        end)
        nativeFilterBtn:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
    end

    return frame
end

return FilterBar
