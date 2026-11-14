local _, ns = ...
ns = ns or {}

local Compat = ns.Compat
local Store = ns.Store
local Classifier = ns.Classifier
local QuestBridge = ns.QuestBridge
local TrackerHost = ns.TrackerHost

local Diagnostics = {}
ns.Diagnostics = Diagnostics

function Diagnostics.BuildReport()
    local acc = Store:GetAccount()
    local ch = Store:GetChar()
    local ctx = Compat.GetPlayerContext()
    local bridge = QuestBridge.GetDiagnostics()
    local vm = TrackerHost.lastViewModel

    local lines = {
        string.format(
            "Enabled=%s | Filter=%s | HideGray=%s | Search=\"%s\"",
            tostring(acc.enabled),
            tostring(ch.filterMode),
            tostring(ch.hideGray),
            tostring(ch.searchQuery or "")
        ),
        string.format(
            "SmartAutoFold=%s | HoistReady=%s | SplitDungeons=%s | StripDungeonTag=%s",
            tostring(acc.smartAutoFold),
            tostring(acc.hoistReadyForTurnIn),
            tostring(acc.splitDungeonsByInstance),
            tostring(acc.stripDungeonTag)
        ),
        string.format(
            "Zone=\"%s\" (MapID=%s, Instance=%s) | CombatLock=%s | PendingReflow=%s",
            tostring(ctx.zoneName),
            tostring(ctx.uiMapID or "nil"),
            tostring(ctx.inInstance),
            tostring(Compat.InCombat()),
            tostring(TrackerHost.pendingReflow)
        ),
        string.format(
            "Bridges: ForeverQuestPins=%s | Questie=%s | TomTom=%s",
            tostring(bridge.hasForeverQuestPins),
            tostring(bridge.hasQuestie),
            tostring(bridge.hasTomTom)
        ),
    }

    if vm then
        lines[#lines + 1] = string.format(
            "Tracked=%d | VisibleAfterFilter=%d | ActiveSections=%d",
            vm.totalWatched or 0,
            vm.totalAfterFilter or 0,
            #(vm.sections or {})
        )
        for idx, sec in ipairs(vm.sections or {}) do
            lines[#lines + 1] = string.format(
                "  [%d] %s (%s) -> %d quests [%s]",
                idx,
                sec.headerText or sec.title,
                sec.kind,
                #(sec.quests or {}),
                sec.isCollapsed and "folded" or "expanded"
            )
        end
    end

    for _, conflict in ipairs(bridge.conflicts) do
        lines[#lines + 1] = "|cffff6666Conflict:|r " .. conflict
    end

    return lines
end

local function CreateCheckbox(parent, yOffset, label, tooltip, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    if cb.Text then
        cb.Text:SetText(label)
    end
    cb:SetScript("OnShow", function(self)
        self:SetChecked(getter() and true or false)
    end)
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        setter(checked)
        TrackerHost:RequestReflow("settings_toggle")
    end)
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(label, 1, 0.82, 0)
                GameTooltip:AddLine(tooltip, 0.85, 0.85, 0.85, true)
                GameTooltip:Show()
            end
        end)
        cb:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
    end
    return cb
end

function Diagnostics.RegisterSettingsPanel()
    if Diagnostics.settingsCategory or not CreateFrame or not Settings then
        return
    end
    if not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
        return
    end

    local panel = CreateFrame("Frame", "QuestSectionsPlusSettingsPanel")
    panel.name = "QuestSectionsPlus"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("QuestSectionsPlus")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetText("Native Blizzard foldable quest sections, smart auto-fold, and zone/dungeon filters.")

    local y = -60
    CreateCheckbox(
        panel, y,
        "Enable QuestSectionsPlus",
        "Replaces the monolithic Quests header with categorized, foldable peer sections.",
        function() return Store:GetAccount().enabled end,
        function(v) Store:SetAccountOption("enabled", v) end
    )
    y = y - 30
    CreateCheckbox(
        panel, y,
        "Smart Auto-Fold on zone change",
        "Auto-expands Ready for Turn-In and your current zone/dungeon while folding distant zones.",
        function() return Store:GetAccount().smartAutoFold end,
        function(v) Store:SetAccountOption("smartAutoFold", v) end
    )
    y = y - 30
    CreateCheckbox(
        panel, y,
        "Hoist completed quests to 'Ready for Turn-In'",
        "Places completed quests into a dedicated top section.",
        function() return Store:GetAccount().hoistReadyForTurnIn end,
        function(v) Store:SetAccountOption("hoistReadyForTurnIn", v) end
    )
    y = y - 30
    CreateCheckbox(
        panel, y,
        "Split dungeon quests by dungeon instance",
        "Creates separate 'Dungeon: <Instance>' headers instead of one combined Dungeons list.",
        function() return Store:GetAccount().splitDungeonsByInstance end,
        function(v) Store:SetAccountOption("splitDungeonsByInstance", v) end
    )
    y = y - 30
    CreateCheckbox(
        panel, y,
        "Strip redundant '(Dungeon)' tag inside dungeon sections",
        "Prevents long dungeon quest names from wrapping onto a second line.",
        function() return Store:GetAccount().stripDungeonTag end,
        function(v) Store:SetAccountOption("stripDungeonTag", v) end
    )
    y = y - 30
    CreateCheckbox(
        panel, y,
        "Show quest count badges on section headers",
        "Displays counts such as 'Stranglethorn Vale (5)' on each section header.",
        function() return Store:GetAccount().showCountBadges end,
        function(v) Store:SetAccountOption("showCountBadges", v) end
    )
    y = y - 30
    CreateCheckbox(
        panel, y,
        "Show Filter button on 'All Objectives' header",
        "Shows Blizzard's native Filter icon on All Objectives for quest filtering and search.",
        function() return Store:GetAccount().showFilterBar end,
        function(v) Store:SetAccountOption("showFilterBar", v) end
    )
    y = y - 30
    CreateCheckbox(
        panel, y,
        "Hide trivial (gray) quests (per-character)",
        "Hides low-level gray quests without untracking them.",
        function() return Store:GetChar().hideGray end,
        function(v) Store:SetHideGray(v) end
    )

    local category = Settings.RegisterCanvasLayoutCategory(panel, "QuestSectionsPlus")
    Settings.RegisterAddOnCategory(category)
    Diagnostics.settingsCategory = category
end

function Diagnostics.HandleSlashCommand(rawMsg)
    local trimmed = Classifier.Trim(rawMsg or "")
    local cmd, rest = string.match(trimmed, "^(%S+)%s*(.-)$")
    cmd = Classifier.AsciiLower(cmd or "")

    if cmd == "" then
        if Diagnostics.settingsCategory and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(Diagnostics.settingsCategory:GetID())
            return
        end
        Compat.Print("Commands: /qsp filter <all|zone|dungeon|ready>, /qsp gray, /qsp autofold, /qsp diag, /qsp reset")
        return
    end

    if cmd == "diag" or cmd == "status" then
        for _, line in ipairs(Diagnostics.BuildReport()) do
            Compat.Print(line)
        end
    elseif cmd == "filter" then
        local mode = string.upper(Classifier.Trim(rest))
        if Store:SetFilterMode(mode) then
            TrackerHost:RequestReflow("slash_filter")
            Compat.Print("Filter set to " .. mode)
        else
            Compat.Print("Usage: /qsp filter <all|zone|dungeon|ready>")
        end
    elseif cmd == "gray" then
        local nextVal = not Store:GetChar().hideGray
        Store:SetHideGray(nextVal)
        TrackerHost:RequestReflow("slash_gray")
        Compat.Print("Hide trivial (gray) quests: " .. (nextVal and "ON" or "OFF"))
    elseif cmd == "autofold" then
        local nextVal = not Store:GetAccount().smartAutoFold
        Store:SetAccountOption("smartAutoFold", nextVal)
        TrackerHost:RequestReflow("slash_autofold")
        Compat.Print("Smart Auto-Fold: " .. (nextVal and "ON" or "OFF"))
    elseif cmd == "search" or cmd == "find" then
        local query = Classifier.Trim(rest)
        if query ~= "" then
            Store:SetSearchExpanded(true)
            Store:SetSearchQuery(query)
        else
            local nextExpanded = not Store:GetChar().searchExpanded
            Store:SetSearchExpanded(nextExpanded)
            if not nextExpanded then
                Store:SetSearchQuery("")
            end
        end
        TrackerHost:RequestReflow("slash_search")
    elseif cmd == "reset" then
        Store:ResetAll()
        TrackerHost:RequestReflow("slash_reset")
        Compat.Print("All settings and section fold overrides reset to defaults.")
    else
        Compat.Print("Commands: /qsp filter <all|zone|dungeon|ready>, /qsp gray, /qsp autofold, /qsp diag, /qsp reset")
    end
end

function Diagnostics.RegisterSlashCommands()
    if not SlashCmdList then
        return
    end
    SLASH_QUESTSECTIONSPLUS1 = "/qsp"
    SLASH_QUESTSECTIONSPLUS2 = "/questsections"
    SlashCmdList["QUESTSECTIONSPLUS"] = Diagnostics.HandleSlashCommand
end

function Diagnostics.WarnConflictsOnce()
    local ch = Store:GetChar()
    local bridge = QuestBridge.GetDiagnostics()
    for _, conflict in ipairs(bridge.conflicts) do
        if not ch.dismissedNotices[conflict] then
            ch.dismissedNotices[conflict] = true
            Compat.Print("|cffff9900Notice:|r " .. conflict)
        end
    end
end

return Diagnostics
