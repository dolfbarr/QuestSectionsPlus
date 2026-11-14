local _, ns = ...
ns = ns or {}

local Compat = ns.Compat
local Store = ns.Store
local QuestBridge = ns.QuestBridge

local SectionModule = {}
ns.SectionModule = SectionModule

SectionModule.POOL_SIZE = 24
SectionModule.BASE_UI_ORDER = 4.001
SectionModule.UI_ORDER_STEP = 0.001

local function BuildSectionMixin()
    local mixin = CreateFromMixins(QuestObjectiveTrackerMixin)

    -- AutoQuest popups remain owned exclusively by stock QuestObjectiveTracker at uiOrder = 4.000
    mixin.events = {
        "QUEST_LOG_UPDATE",
        "QUEST_WATCH_LIST_CHANGED",
        "SUPER_TRACKING_CHANGED",
        "QUEST_TURNED_IN",
        "QUEST_POI_UPDATE",
        "SUPER_TRACKING_PATH_UPDATED",
    }

    function mixin:AssignSectionData(sectionData)
        if not sectionData then
            self.sectionKey = nil
            self.sectionTitle = ""
            self.headerDisplayText = ""
            self.stripDungeonTag = false
            self.assignedQuestIDs = {}
            return
        end
        self.sectionKey = sectionData.key
        self.sectionTitle = sectionData.title
        self.headerDisplayText = sectionData.headerText or sectionData.title
        self.stripDungeonTag = sectionData.stripDungeonTag and true or false
        self.assignedQuestIDs = sectionData.questIDs or {}
        self:ApplyCollapsedFlagSilently(sectionData.isCollapsed and true or false)
    end

    function mixin:ApplyCollapsedFlagSilently(collapsed)
        self.isCollapsed = collapsed
        if self.ContentsFrame then
            self.ContentsFrame:SetShown(not collapsed)
        end
        if self.Header and self.Header.SetCollapsed then
            self.Header:SetCollapsed(collapsed)
        end
    end

    function mixin:ToggleCollapsed()
        local nextCollapsed = not self:IsCollapsed()
        if self.sectionKey then
            Store:SetManualCollapsed(self.sectionKey, nextCollapsed)
        end
        if Compat.InCombat() then
            if ns.TrackerHost and ns.TrackerHost.RequestReflow then
                ns.TrackerHost:RequestReflow("manual_collapse_in_combat")
            end
            return
        end
        self:SetCollapsed(nextCollapsed)
        if ns.TrackerHost and ns.TrackerHost.SyncItemOverlays then
            ns.TrackerHost:SyncItemOverlays()
        end
    end

    function mixin:EnumQuestWatchData(func)
        if not self.assignedQuestIDs or #self.assignedQuestIDs == 0 then
            return
        end
        for _, questID in ipairs(self.assignedQuestIDs) do
            local quest = QuestCache and QuestCache:Get(questID)
            if quest and not func(self, quest) then
                return
            end
        end
    end

    function mixin:BuildQuestWatchInfos()
        local infos = {}
        if self.assignedQuestIDs then
            for idx, questID in ipairs(self.assignedQuestIDs) do
                local quest = QuestCache and QuestCache:Get(questID)
                if quest then
                    infos[#infos + 1] = { quest = quest, index = idx }
                end
            end
        end
        return infos
    end

    function mixin:GetQuestTagText(questID)
        local tagText = nil
        if QuestUtilsOverrides and QuestUtilsOverrides.GetQuestTagText then
            tagText = QuestUtilsOverrides.GetQuestTagText(questID)
        elseif QuestObjectiveTrackerMixin.GetQuestTagText then
            tagText = QuestObjectiveTrackerMixin.GetQuestTagText(self, questID)
        end

        if self.stripDungeonTag and tagText then
            local tagInfo = C_QuestLog and C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(questID)
            local dungeonTagID = Compat.QUEST_TAG.DUNGEON
            if (tagInfo and tagInfo.tagID == dungeonTagID)
                or tagText == "(Dungeon)"
                or (LFG_TYPE_DUNGEON and tagText == "(" .. LFG_TYPE_DUNGEON .. ")") then
                return nil
            end
        end
        return tagText
    end

    function mixin:LayoutContents()
        if IsInInstance then
            local _, instanceType = IsInInstance()
            if instanceType == "arena" then
                return
            end
        end

        local count = self.assignedQuestIDs and #self.assignedQuestIDs or 0
        if count == 0 then
            return
        end

        self:SetHeader(self.headerDisplayText or self.sectionTitle or TRACKER_HEADER_QUESTS or "Quests")
        self:WatchMoney(false)

        -- When collapsed, show the 25px header with badge without allocating hidden blocks
        if self:IsCollapsed() then
            if self.availableHeight >= (self.headerHeight or 25) then
                self.hasContents = true
            else
                self.hasTriedBlocks = true
            end
            return
        end

        self:EnumQuestWatchData(self.UpdateSingle)
    end

    function mixin:OnBlockHeaderClick(block, mouseButton)
        if mouseButton == "LeftButton" and IsControlKeyDown and IsControlKeyDown() then
            local questID = block and block.id
            if questID then
                local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
                QuestBridge.TriggerWaypoint(questID, title)
                return
            end
        end
        QuestObjectiveTrackerMixin.OnBlockHeaderClick(self, block, mouseButton)
    end

    -- Forward Enter/Leave to QuestObjectiveTracker singleton so ForeverQuestPins's
    -- right-click "Copy Wowhead URL" context hook continues receiving hovered quest IDs.
    function mixin:OnBlockHeaderEnter(block)
        if QuestObjectiveTracker and QuestObjectiveTracker.OnBlockHeaderEnter then
            QuestObjectiveTracker:OnBlockHeaderEnter(block)
        else
            QuestObjectiveTrackerMixin.OnBlockHeaderEnter(self, block)
        end
    end

    function mixin:OnBlockHeaderLeave(block)
        if QuestObjectiveTracker and QuestObjectiveTracker.OnBlockHeaderLeave then
            QuestObjectiveTracker:OnBlockHeaderLeave(block)
        else
            QuestObjectiveTrackerMixin.OnBlockHeaderLeave(self, block)
        end
    end

    return mixin
end

function SectionModule.CreatePool(container)
    local pool = {}
    if not CreateFrame or not QuestObjectiveTrackerMixin or not container then
        return pool
    end

    local sectionMixin = BuildSectionMixin()

    for i = 1, SectionModule.POOL_SIZE do
        local frameName = string.format("QuestSectionsPlusModule%02d", i)
        local mod = CreateFrame("Frame", frameName, container, "ObjectiveTrackerModuleTemplate")
        Mixin(mod, sectionMixin)
        mod.uiOrder = SectionModule.BASE_UI_ORDER + (i * SectionModule.UI_ORDER_STEP)
        mod.assignedQuestIDs = {}
        mod.sectionTitle = ""
        mod.headerDisplayText = ""
        mod:SetScript("OnEvent", mod.OnEvent)

        -- Allow clicking anywhere on the section header bar (not just the 16x16 '-' icon) to fold/unfold
        if mod.Header then
            mod.Header:EnableMouse(true)
            mod.Header:SetScript("OnMouseUp", function(hdr, button)
                if button == "LeftButton" and hdr.OnToggle then
                    hdr:OnToggle()
                end
            end)
        end

        if ObjectiveTrackerManager and ObjectiveTrackerManager.SetModuleContainer then
            ObjectiveTrackerManager:SetModuleContainer(mod, container)
        end

        pool[i] = mod
    end

    return pool
end

return SectionModule
