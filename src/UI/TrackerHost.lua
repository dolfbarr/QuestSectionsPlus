local _, ns = ...
ns = ns or {}

local Compat = ns.Compat
local Store = ns.Store
local QuestCollector = ns.QuestCollector
local Classifier = ns.Classifier
local FilterBar = ns.FilterBar
local SectionModule = ns.SectionModule
local SecureItemOverlay = ns.SecureItemOverlay

local TrackerHost = {
    initialized = false,
    pendingReflow = false,
    pendingReason = nil,
    lastViewModel = nil,
    sectionPool = {},
    filterBar = nil,
    origEnumQuestWatchData = nil,
    nonQuestSuppressed = false,
    origNonQuestLayout = {},
}
ns.TrackerHost = TrackerHost

local function SuppressOrRestoreStockQuestList(suppress)
    if not QuestObjectiveTracker then
        return
    end
    if not TrackerHost.origEnumQuestWatchData then
        TrackerHost.origEnumQuestWatchData = QuestObjectiveTracker.EnumQuestWatchData
    end
    if suppress then
        QuestObjectiveTracker.EnumQuestWatchData = function() end
    elseif TrackerHost.origEnumQuestWatchData then
        QuestObjectiveTracker.EnumQuestWatchData = TrackerHost.origEnumQuestWatchData
    end
end

local function SetNonQuestModulesSuppressed(self, suppress)
    local targets = {
        Achievement = _G and _G.AchievementObjectiveTracker,
        Professions = _G and _G.ProfessionsRecipeTracker,
    }
    for key, mod in pairs(targets) do
        if type(mod) == "table" and type(mod.LayoutContents) == "function" then
            if not self.origNonQuestLayout[key] then
                self.origNonQuestLayout[key] = mod.LayoutContents
            end
            if suppress then
                mod.LayoutContents = function() end
            else
                mod.LayoutContents = self.origNonQuestLayout[key]
            end
            if mod.MarkDirty then
                mod:MarkDirty()
            end
        end
    end
    self.nonQuestSuppressed = suppress
end

function TrackerHost:Init()
    if self.initialized then
        return true
    end
    if not ObjectiveTrackerFrame or not ObjectiveTrackerManager then
        return false
    end
    if not ObjectiveTrackerManager.containers or not ObjectiveTrackerManager.containers[ObjectiveTrackerFrame] then
        return false
    end

    self.filterBar = FilterBar.Create(ObjectiveTrackerFrame, {
        onSelectFilter = function(mode)
            Store:SetFilterMode(mode)
            self:RequestReflow("filter_mode")
        end,
        onToggleHideGray = function()
            local ch = Store:GetChar()
            Store:SetHideGray(not ch.hideGray)
            self:RequestReflow("hide_gray")
        end,
        onSearchChanged = function()
            self:RequestReflow("search")
        end,
        onResetFilters = function()
            self:RequestReflow("reset_filters")
        end,
        onToggleFilterBar = function()
            self:RequestReflow("toggle_filter_bar")
        end,
    })

    ObjectiveTrackerManager:SetModuleContainer(self.filterBar, ObjectiveTrackerFrame)
    self.sectionPool = SectionModule.CreatePool(ObjectiveTrackerFrame)

    if QuestObjectiveTracker and hooksecurefunc then
        hooksecurefunc(QuestObjectiveTracker, "MarkDirty", function()
            self:MarkActiveSectionsDirty()
        end)
    end

    if ObjectiveTrackerFrame and hooksecurefunc then
        hooksecurefunc(ObjectiveTrackerFrame, "Update", function()
            self:SyncItemOverlays()
        end)
        if ObjectiveTrackerFrame.SetCollapsed then
            hooksecurefunc(ObjectiveTrackerFrame, "SetCollapsed", function()
                self:SyncItemOverlays()
            end)
        end
    end

    self.initialized = true
    self:RequestReflow("init")
    return true
end

function TrackerHost:MarkActiveSectionsDirty()
    for _, mod in ipairs(self.sectionPool) do
        if mod.assignedQuestIDs and #mod.assignedQuestIDs > 0 and mod.MarkDirty then
            mod.isDirty = true
        end
    end
end

function TrackerHost:SyncItemOverlays()
    local isCollapsed = ObjectiveTrackerFrame
        and ObjectiveTrackerFrame.IsCollapsed
        and ObjectiveTrackerFrame:IsCollapsed()
    SecureItemOverlay.SyncActiveModules(self.sectionPool, isCollapsed)
end

function TrackerHost:RequestReflow(reason)
    local acc = Store:GetAccount()
    local ch = Store:GetChar()
    local context = Compat.GetPlayerContext()
    local quests = QuestCollector.CollectWatchedQuests(context)
    local vm = Classifier.BuildViewModel(quests, context, acc, ch)
    self.lastViewModel = vm

    if Compat.InCombat() then
        self.pendingReflow = true
        self.pendingReason = reason or "combat"
        if self.filterBar then
            self.filterBar.pendingCombatReflow = true
            self.filterBar:RefreshVisualState()
        end
        return false, "queued_in_combat"
    end

    self.pendingReflow = false
    self.pendingReason = nil

    if not self.initialized then
        return true, "computed_headless"
    end

    if not acc.enabled then
        SuppressOrRestoreStockQuestList(false)
        SetNonQuestModulesSuppressed(self, false)
        for _, mod in ipairs(self.sectionPool) do
            mod:AssignSectionData(nil)
            mod:MarkDirty()
        end
        if self.filterBar then
            self.filterBar.totalWatched = 0
            self.filterBar.fallbackMessage = nil
            self.filterBar.pendingCombatReflow = false
            self.filterBar:MarkDirty()
        end
        SecureItemOverlay.HideAll()
        if QuestObjectiveTracker and QuestObjectiveTracker.MarkDirty then
            QuestObjectiveTracker:MarkDirty()
        end
        if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Update then
            ObjectiveTrackerFrame:Update()
        end
        return true, "disabled_passthrough"
    end

    SuppressOrRestoreStockQuestList(true)
    SetNonQuestModulesSuppressed(self, vm.hideNonQuestModules)

    if self.filterBar then
        self.filterBar.totalWatched = vm.totalWatched
        self.filterBar.fallbackMessage = vm.emptyFallbackText
        self.filterBar.pendingCombatReflow = false
        self.filterBar:MarkDirty()
    end

    local sectionCount = #vm.sections
    for i = 1, #self.sectionPool do
        local mod = self.sectionPool[i]
        if i <= sectionCount then
            mod:AssignSectionData(vm.sections[i])
        elseif i == sectionCount + 1 and sectionCount > #self.sectionPool then
            -- Overflow guard if >24 distinct zones somehow occur
            mod:AssignSectionData(vm.sections[i])
        else
            mod:AssignSectionData(nil)
        end
        mod:MarkDirty()
    end

    if QuestObjectiveTracker and QuestObjectiveTracker.MarkDirty then
        QuestObjectiveTracker:MarkDirty()
    end
    if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Update then
        ObjectiveTrackerFrame:Update()
    end
    self:SyncItemOverlays()
    return true, "applied"
end

function TrackerHost:FlushCombatQueue()
    if not self.pendingReflow then
        return false
    end
    if Compat.InCombat() then
        return false
    end
    return self:RequestReflow("combat_flush")
end

return TrackerHost
