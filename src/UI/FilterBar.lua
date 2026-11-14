local _, ns = ...
ns = ns or {}

local Store = ns.Store
local FilterBar = {}
ns.FilterBar = FilterBar

local TRACKER_WIDTH = 260
local LEFT_INSET = 7
local LINE_INSET = 14
local RIGHT_INSET = -3

local HEADER_HEIGHT = 26
local SEARCH_GAP_Y = 4
local SEARCH_ROW_HEIGHT = 22
local FALLBACK_GAP_Y = 4
local FALLBACK_ROW_HEIGHT = 20

local FILTER_LABELS = {
    ZONE = "Zone",
    DUNGEON = "Dungeon",
    READY = "Ready",
}

local FilterBarModuleMixin = {
    isModule = true,
    uiOrder = 3.5,
    leftMargin = 0,
    hasDisplayPriority = false,
    mustFit = false,
    isDirty = false,
    isCollapsed = false,
    contentsHeight = 0,
}

local function BuildActiveFilterTags(ch)
    local tags = {}
    local mode = ch.filterMode or "ALL"
    if FILTER_LABELS[mode] then
        tags[#tags + 1] = FILTER_LABELS[mode]
    end
    if ch.hideGray then
        tags[#tags + 1] = "!Gray"
    end
    if (ch.searchQuery or "") ~= "" then
        tags[#tags + 1] = "Search"
    end
    return tags
end

local function FormatMasterHeaderText(self, acc, ch)
    local baseLabel = TRACKER_HEADER_QUESTS or "Quests"
    local tags = BuildActiveFilterTags(ch)
    local tagSuffix = (#tags > 0) and table.concat(tags, ", ") or nil

    if acc.showCountBadges == false then
        if tagSuffix then
            return string.format("%s (%s)", baseLabel, tagSuffix)
        end
        return baseLabel
    end

    local totalWatched = self.totalWatched or 0
    local totalVisible = self.totalVisible
    if totalVisible == nil then
        totalVisible = totalWatched
    end

    if tagSuffix then
        return string.format("%s (%d/%d - %s)", baseLabel, totalVisible, totalWatched, tagSuffix)
    elseif totalVisible ~= totalWatched then
        return string.format("%s (%d/%d)", baseLabel, totalVisible, totalWatched)
    end
    return string.format("%s (%d)", baseLabel, totalWatched)
end

function FilterBarModuleMixin:SetContainer(container)
    self.parentContainer = container
    self:SetParent(container)
    self:SetWidth(TRACKER_WIDTH)
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

function FilterBarModuleMixin:ApplyCollapsedState(collapsed)
    self.isCollapsed = collapsed and true or false
    if self.Header and self.Header.SetCollapsed then
        self.Header:SetCollapsed(self.isCollapsed)
    end
end

function FilterBarModuleMixin:IsCollapsed()
    return self.isCollapsed == true
end

function FilterBarModuleMixin:SetCollapsed(collapsed)
    self:ApplyCollapsedState(collapsed)
    self:MarkDirty()
end

function FilterBarModuleMixin:ToggleCollapsed()
    local nextCollapsed = not self:IsCollapsed()
    Store:SetQuestsMasterCollapsed(nextCollapsed)
    if self.callbacks and self.callbacks.onToggleMasterCollapse then
        self.callbacks.onToggleMasterCollapse(nextCollapsed)
    else
        self:SetCollapsed(nextCollapsed)
    end
end

function FilterBarModuleMixin:ToggleSearchBox()
    local ch = Store:GetChar()
    local hasSearchText = (ch.searchQuery or "") ~= ""
    local currentlyOpen = ch.searchExpanded or hasSearchText
    local nextExpanded = not currentlyOpen

    if nextExpanded and self:IsCollapsed() then
        Store:SetQuestsMasterCollapsed(false)
        self:ApplyCollapsedState(false)
    end

    Store:SetSearchExpanded(nextExpanded)
    if not nextExpanded and hasSearchText then
        Store:SetSearchQuery("")
    end
    if self.callbacks and self.callbacks.onSearchChanged then
        self.callbacks.onSearchChanged()
    end
    if nextExpanded and self.searchBox and self.searchBox.SetFocus then
        self.searchBox:SetFocus()
    end
end

function FilterBarModuleMixin:ResetAllFilters()
    Store:SetFilterMode("ALL")
    Store:SetHideGray(false)
    Store:SetSearchQuery("")
    Store:SetSearchExpanded(false)
    if self.searchBox and self.searchBox.ClearFocus then
        self.searchBox:ClearFocus()
    end
    if self.callbacks and self.callbacks.onResetFilters then
        self.callbacks.onResetFilters()
    end
end

function FilterBarModuleMixin:PopulateFilterMenu(rootDescription)
    if not rootDescription then
        return
    end
    local callbacks = self.callbacks or {}

    if rootDescription.CreateTitle then
        rootDescription:CreateTitle("Quest Filter")
    end

    local radioItems = {
        { mode = "ALL", label = "All Tracked Quests" },
        { mode = "ZONE", label = "Current Zone" },
        { mode = "DUNGEON", label = "Dungeons & Raids" },
        { mode = "READY", label = "Ready for Turn-In" },
    }
    for _, item in ipairs(radioItems) do
        local mode = item.mode
        rootDescription:CreateRadio(
            item.label,
            function()
                return (Store:GetChar().filterMode or "ALL") == mode
            end,
            function()
                if callbacks.onSelectFilter then
                    callbacks.onSelectFilter(mode)
                else
                    Store:SetFilterMode(mode)
                end
            end
        )
    end

    if rootDescription.CreateDivider then
        rootDescription:CreateDivider()
    end

    rootDescription:CreateCheckbox(
        "Hide Trivial (Gray) Quests",
        function()
            return Store:GetChar().hideGray == true
        end,
        function()
            if callbacks.onToggleHideGray then
                callbacks.onToggleHideGray()
            else
                Store:SetHideGray(not Store:GetChar().hideGray)
            end
        end
    )

    rootDescription:CreateCheckbox(
        "Search Tracked Quests",
        function()
            local ch = Store:GetChar()
            return ch.searchExpanded == true or (ch.searchQuery or "") ~= ""
        end,
        function()
            self:ToggleSearchBox()
        end
    )

    if rootDescription.CreateDivider then
        rootDescription:CreateDivider()
    end

    rootDescription:CreateButton("Expand All Sections", function()
        if callbacks.onSetAllSectionsCollapsed then
            callbacks.onSetAllSectionsCollapsed(false)
        end
    end)

    rootDescription:CreateButton("Collapse All Sections", function()
        if callbacks.onSetAllSectionsCollapsed then
            callbacks.onSetAllSectionsCollapsed(true)
        end
    end)

    local ch = Store:GetChar()
    local hasActiveFilter = (ch.filterMode ~= "ALL")
        or ch.hideGray
        or ((ch.searchQuery or "") ~= "")
        or ch.searchExpanded
    if hasActiveFilter then
        if rootDescription.CreateDivider then
            rootDescription:CreateDivider()
        end
        rootDescription:CreateButton("Reset Filters", function()
            self:ResetAllFilters()
        end)
    end
end

function FilterBarModuleMixin:OpenFilterMenu(ownerRegion)
    if MenuUtil and MenuUtil.CreateContextMenu then
        return MenuUtil.CreateContextMenu(ownerRegion or self.Header, function(_, rootDescription)
            self:PopulateFilterMenu(rootDescription)
        end)
    end
    return nil
end

function FilterBarModuleMixin:ComputeLayoutSpec()
    local acc = Store:GetAccount()
    local ch = Store:GetChar()
    if not acc.enabled then
        return 0, false, false, 0, 0
    end

    local totalWatched = self.totalWatched or 0
    local hasNonDefaultState = (ch.filterMode ~= "ALL")
        or ch.hideGray
        or ((ch.searchQuery or "") ~= "")
        or ch.searchExpanded

    if totalWatched == 0 and not hasNonDefaultState then
        return 0, false, false, 0, 0
    end

    if self:IsCollapsed() then
        return HEADER_HEIGHT, false, false, 0, 0
    end

    local cursorY = HEADER_HEIGHT
    local hasSearchText = (ch.searchQuery or "") ~= ""
    local showSearch = ch.searchExpanded or hasSearchText
    local showFallback = (self.fallbackMessage ~= nil and self.fallbackMessage ~= "")

    local searchY = 0
    local fallbackY = 0

    if showSearch then
        cursorY = cursorY + SEARCH_GAP_Y
        searchY = -cursorY
        cursorY = cursorY + SEARCH_ROW_HEIGHT
    end

    if showFallback then
        cursorY = cursorY + FALLBACK_GAP_Y
        fallbackY = -cursorY
        cursorY = cursorY + FALLBACK_ROW_HEIGHT
    end

    return cursorY, showSearch, showFallback, searchY, fallbackY
end

function FilterBarModuleMixin:ComputeDesiredHeight()
    local desired = self:ComputeLayoutSpec()
    return desired
end

function FilterBarModuleMixin:RefreshVisualState()
    local acc = Store:GetAccount()
    local ch = Store:GetChar()

    if self.nativeFilterBtn then
        self.nativeFilterBtn:SetShown(acc.enabled and acc.showFilterBar ~= false)
    end

    if self.Header and self.Header.Text then
        self.Header.Text:SetText(FormatMasterHeaderText(self, acc, ch))
    end
    if self.Header and self.Header.SetCollapsed then
        self.Header:SetCollapsed(self:IsCollapsed())
    end

    if self.combatBadge then
        self.combatBadge:SetShown(self.pendingCombatReflow == true)
    end

    local _, showSearch, showFallback, searchY, fallbackY = self:ComputeLayoutSpec()

    if self.searchBox then
        if showSearch then
            self.searchBox:ClearAllPoints()
            self.searchBox:SetPoint("TOPLEFT", self, "TOPLEFT", LEFT_INSET, searchY)
            self.searchBox:SetPoint("TOPRIGHT", self, "TOPRIGHT", RIGHT_INSET, searchY)
            self.searchBox:Show()
            if self.searchBox:GetText() ~= (ch.searchQuery or "") then
                self.updatingSearchText = true
                self.searchBox:SetText(ch.searchQuery or "")
                self.updatingSearchText = false
            end
        else
            self.searchBox:Hide()
        end
    end

    if self.fallbackBtn then
        if showFallback then
            self.fallbackBtn.Text:SetText(self.fallbackMessage)
            self.fallbackBtn:ClearAllPoints()
            self.fallbackBtn:SetPoint("TOPLEFT", self, "TOPLEFT", LINE_INSET, fallbackY)
            self.fallbackBtn:SetPoint("TOPRIGHT", self, "TOPRIGHT", RIGHT_INSET, fallbackY)
            self.fallbackBtn:Show()
        else
            self.fallbackBtn:Hide()
        end
    end
end

function FilterBarModuleMixin:Update(availableHeight)
    self.isDirty = false
    local desired = self:ComputeDesiredHeight()
    if desired <= 0 or (availableHeight and availableHeight < HEADER_HEIGHT) then
        self.contentsHeight = 0
        self:Hide()
        return 0, false
    end

    self.contentsHeight = desired
    self:SetSize(TRACKER_WIDTH, desired)
    self:RefreshVisualState()

    local containerCollapsed = self.parentContainer
        and self.parentContainer.IsCollapsed
        and self.parentContainer:IsCollapsed()
    if containerCollapsed then
        self:Hide()
    else
        if self.Header then
            self.Header:Show()
        end
        self:Show()
    end

    return self.contentsHeight, false
end

function FilterBar.Create(parentContainer, callbacks)
    local frame = CreateFrame("Frame", "QuestSectionsPlusFilterBar", parentContainer)
    frame:SetSize(TRACKER_WIDTH, HEADER_HEIGHT)
    Mixin(frame, FilterBarModuleMixin)
    frame.callbacks = callbacks
    frame.totalWatched = 0
    frame.totalVisible = 0
    frame.fallbackMessage = nil
    frame.pendingCombatReflow = false
    frame.isCollapsed = Store:IsQuestsMasterCollapsed()

    -- Master foldable "Quests" category header (Blizzard ObjectiveTrackerModuleHeaderTemplate)
    local header = CreateFrame("Frame", nil, frame, "ObjectiveTrackerModuleHeaderTemplate")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:EnableMouse(true)
    header:SetScript("OnMouseUp", function(hdr, button)
        if button == "LeftButton" and hdr.OnToggle then
            hdr:OnToggle()
        elseif button == "RightButton" then
            frame:OpenFilterMenu(hdr)
        end
    end)
    if header.MinimizeButton and not header.MinimizeButton:GetScript("OnClick") then
        header.MinimizeButton:SetScript("OnClick", function()
            if header.OnToggle then
                header:OnToggle()
            end
        end)
    end
    frame.Header = header
    frame:ApplyCollapsedState(frame.isCollapsed)

    local combatBadge = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if header.MinimizeButton then
        combatBadge:SetPoint("RIGHT", header.MinimizeButton, "LEFT", -4, 0)
    else
        combatBadge:SetPoint("RIGHT", header, "RIGHT", -22, 0)
    end
    combatBadge:SetText("|cffff9900(Queued)|r")
    combatBadge:Hide()
    frame.combatBadge = combatBadge

    -- Native Blizzard SearchBoxNineSliceTemplate (common-searchbar-a + magnifying glass + clearButton)
    local searchBox = CreateFrame("EditBox", "QuestSectionsPlusSearchBox", frame, "SearchBoxNineSliceTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetHeight(SEARCH_ROW_HEIGHT)
    local defaultSearchY = -(HEADER_HEIGHT + SEARCH_GAP_Y)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT_INSET, defaultSearchY)
    searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", RIGHT_INSET, defaultSearchY)
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
    searchBox:SetScript("OnEditFocusGained", function(self)
        if SearchBoxTemplate_OnEditFocusGained then
            SearchBoxTemplate_OnEditFocusGained(self)
        end
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if SearchBoxTemplate_OnEditFocusLost then
            SearchBoxTemplate_OnEditFocusLost(self)
        end
    end)
    searchBox:SetScript("OnTextChanged", function(self)
        if SearchBoxTemplate_OnTextChanged then
            SearchBoxTemplate_OnTextChanged(self)
        end
        if frame.updatingSearchText then
            return
        end
        Store:SetSearchQuery(self:GetText() or "")
        if callbacks and callbacks.onSearchChanged then
            callbacks.onSearchChanged()
        end
    end)
    if searchBox.clearButton then
        searchBox.clearButton:SetScript("OnClick", function(btn)
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
            local parentBox = btn:GetParent() or searchBox
            Store:SetSearchExpanded(false)
            Store:SetSearchQuery("")
            if SearchBoxTemplate_ClearText then
                SearchBoxTemplate_ClearText(parentBox)
            else
                parentBox:SetText("")
                parentBox:ClearFocus()
            end
            if callbacks and callbacks.onSearchChanged then
                callbacks.onSearchChanged()
            end
        end)
    end
    searchBox:Hide()
    frame.searchBox = searchBox

    -- Native Blizzard Tracker-Line Empty Filter Fallback (zero custom box textures)
    local fallbackBtn = CreateFrame("Button", nil, frame)
    fallbackBtn:SetHeight(FALLBACK_ROW_HEIGHT)
    fallbackBtn:Hide()

    local lineFont = (_G and _G.ObjectiveTrackerLineFont and "ObjectiveTrackerLineFont") or "GameFontHighlightSmall"
    local fbText = fallbackBtn:CreateFontString(nil, "ARTWORK", lineFont)
    fbText:SetPoint("LEFT", fallbackBtn, "LEFT", 0, 0)
    fbText:SetPoint("RIGHT", fallbackBtn, "RIGHT", 0, 0)
    fbText:SetJustifyH("LEFT")
    fbText:SetTextColor(0.80, 0.80, 0.80)
    fallbackBtn.Text = fbText

    fallbackBtn:SetScript("OnEnter", function()
        fbText:SetTextColor(1.0, 0.82, 0.0)
    end)
    fallbackBtn:SetScript("OnLeave", function()
        fbText:SetTextColor(0.80, 0.80, 0.80)
    end)
    fallbackBtn:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
        frame:ResetAllFilters()
    end)
    frame.fallbackBtn = fallbackBtn

    -- Wire Blizzard's native Header.FilterButton on ObjectiveTrackerFrame ("All Objectives")
    if parentContainer and parentContainer.Header and parentContainer.Header.FilterButton then
        local nativeFilterBtn = parentContainer.Header.FilterButton
        frame.nativeFilterBtn = nativeFilterBtn
        nativeFilterBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        nativeFilterBtn:SetShown(Store:GetAccount().showFilterBar ~= false)
        nativeFilterBtn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                end
                frame:ToggleSearchBox()
            else
                frame:OpenFilterMenu(self)
            end
        end)
        nativeFilterBtn:SetScript("OnEnter", function(self)
            if GameTooltip then
                local ch = Store:GetChar()
                local tags = BuildActiveFilterTags(ch)
                local activeSummary = (#tags > 0) and table.concat(tags, ", ") or "All Tracked Quests"
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:SetText("Quest Filter & Options", 1, 0.82, 0)
                GameTooltip:AddLine("Active: " .. activeSummary, 1, 1, 1, true)
                GameTooltip:AddLine("Left-Click: Filter & section menu", 0.80, 0.80, 0.80, true)
                GameTooltip:AddLine("Right-Click: Toggle quest search", 0.80, 0.80, 0.80, true)
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
