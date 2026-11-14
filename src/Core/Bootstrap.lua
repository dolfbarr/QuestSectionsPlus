local addonName, ns = ...
ns = ns or {}
QuestSectionsPlus = ns

local Store = ns.Store
local TrackerHost = ns.TrackerHost
local Diagnostics = ns.Diagnostics

local Bootstrap = {}
ns.Bootstrap = Bootstrap

local refetchPending = false

local function RequestCoalescedReflow(reason)
    if C_Timer and C_Timer.After then
        if refetchPending then
            return
        end
        refetchPending = true
        C_Timer.After(0, function()
            refetchPending = false
            TrackerHost:RequestReflow(reason)
        end)
    else
        TrackerHost:RequestReflow(reason)
    end
end

function Bootstrap.InitRuntime()
    Store:Init()
    Diagnostics.RegisterSlashCommands()
    Diagnostics.RegisterSettingsPanel()

    if ObjectiveTrackerManager then
        if ObjectiveTrackerManager.containers
            and ObjectiveTrackerFrame
            and ObjectiveTrackerManager.containers[ObjectiveTrackerFrame] then
            TrackerHost:Init()
        end
        if hooksecurefunc then
            hooksecurefunc(ObjectiveTrackerManager, "Init", function()
                TrackerHost:Init()
            end)
        end
    end
end

if CreateFrame then
    local eventFrame = CreateFrame("Frame", "QuestSectionsPlusEventFrame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    eventFrame:RegisterEvent("QUEST_ACCEPTED")
    eventFrame:RegisterEvent("QUEST_REMOVED")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == (addonName or "QuestSectionsPlus") then
                Bootstrap.InitRuntime()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            TrackerHost:Init()
            Diagnostics.WarnConflictsOnce()
            RequestCoalescedReflow("entering_world")
        elseif event == "PLAYER_REGEN_ENABLED" then
            if not TrackerHost:FlushCombatQueue() then
                TrackerHost:SyncItemOverlays()
            end
        elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
            RequestCoalescedReflow(event)
        elseif event == "QUEST_LOG_UPDATE"
            or event == "QUEST_WATCH_LIST_CHANGED"
            or event == "QUEST_ACCEPTED"
            or event == "QUEST_REMOVED"
            or event == "PLAYER_LEVEL_UP" then
            RequestCoalescedReflow(event)
        end
    end)
end

return Bootstrap
