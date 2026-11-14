local function InstallUIFrameMocks(mockState)
    local createdFrames = {}

    local function NewMockFontString()
        local fs = { _text = "", _shown = true }
        function fs:SetText(t) self._text = tostring(t or "") end
        function fs:GetText() return self._text end
        function fs:SetPoint() end
        function fs:ClearAllPoints() end
        function fs:SetWidth() end
        function fs:SetJustifyH() end
        function fs:SetTextColor() end
        function fs:Show() self._shown = true end
        function fs:Hide() self._shown = false end
        function fs:SetShown(flag) self._shown = flag and true or false end
        function fs:IsShown() return self._shown end
        return fs
    end

    local function NewMockTexture()
        local tex = { _shown = true }
        function tex:SetAllPoints() end
        function tex:SetPoint() end
        function tex:SetHeight() end
        function tex:SetWidth() end
        function tex:SetSize() end
        function tex:SetAlpha() end
        function tex:SetVertexColor() end
        function tex:SetTexture() end
        function tex:SetBlendMode() end
        function tex:SetColorTexture() end
        function tex:SetAtlas() end
        function tex:Show() self._shown = true end
        function tex:Hide() self._shown = false end
        return tex
    end

    local function NewMockFrame(frameType, name, parent, template)
        local f = {
            _type = frameType,
            _name = name,
            _parent = parent,
            _template = template,
            _shown = template ~= "ObjectiveTrackerModuleTemplate",
            _width = 260,
            _height = 25,
            _points = {},
            _scripts = {},
            _attrs = {},
            _text = "",
        }
        function f:SetSize(w, h)
            self._width = w or self._width
            self._height = h or self._height
        end
        function f:SetWidth(w) self._width = w end
        function f:GetWidth() return self._width end
        function f:SetHeight(h) self._height = h end
        function f:GetHeight() return self._height end
        function f:SetAlpha() end
        function f:SetTextInsets() end
        function f:SetFontObject() end
        function f:SetPoint(point, relTo, relPoint, x, y)
            if type(relTo) == "number" then
                y = relPoint
                x = relTo
                relTo = nil
                relPoint = nil
            end
            self._points[point] = { point = point, relTo = relTo, relPoint = relPoint, x = x or 0, y = y or 0 }
        end
        function f:ClearAllPoints() self._points = {} end
        function f:SetAllPoints() end
        function f:SetParent(p) self._parent = p end
        function f:GetParent() return self._parent end
        function f:SetFrameStrata() end
        function f:SetFrameLevel() end
        function f:RegisterForClicks() end
        function f:RegisterEvent() end
        function f:UnregisterEvent() end
        function f:EnableMouse() end
        function f:SetScript(evt, fn) self._scripts[evt] = fn end
        function f:GetScript(evt) return self._scripts[evt] end
        function f:SetAttribute(k, v) self._attrs[k] = v end
        function f:GetAttribute(k) return self._attrs[k] end
        function f:Show() self._shown = true end
        function f:Hide() self._shown = false end
        function f:SetShown(flag) self._shown = flag and true or false end
        function f:IsShown() return self._shown == true end
        function f:CreateTexture() return NewMockTexture() end
        function f:CreateFontString() return NewMockFontString() end
        function f:SetAutoFocus() end
        function f:SetFocus() end
        function f:ClearFocus() end
        function f:SetText(t)
            self._text = tostring(t or "")
            if self._scripts.OnTextChanged then
                self._scripts.OnTextChanged(self)
            end
        end
        function f:GetText() return self._text end
        function f:SetChecked(c) self._checked = c and true or false end
        function f:GetChecked() return self._checked == true end

        if template == "ObjectiveTrackerModuleHeaderTemplate" then
            f.Background = NewMockTexture()
            f.Text = NewMockFontString()
            f.MinimizeButton = NewMockFrame("Button", nil, f, nil)
            f.SetCollapsed = function(_, c) f._collapsed = c and true or false end
            f.PlayAddAnimation = function() end
            f.OnToggle = function(hdr)
                local mod = hdr:GetParent()
                if mod and mod.ToggleCollapsed then
                    mod:ToggleCollapsed()
                end
            end
        elseif template == "ObjectiveTrackerModuleTemplate" then
            f.usedBlocks = {}
            f.Header = NewMockFrame("Frame", nil, f, "ObjectiveTrackerModuleHeaderTemplate")
            f.ContentsFrame = NewMockFrame("Frame", nil, f, nil)
        elseif template == "SearchBoxNineSliceTemplate" then
            f.Background = NewMockTexture()
            f.searchIcon = NewMockTexture()
            f.Instructions = NewMockFontString()
            f.clearButton = NewMockFrame("Button", nil, f, nil)
            f.HasFocus = function() return false end
        end

        createdFrames[#createdFrames + 1] = f
        if name then
            _G[name] = f
        end
        return f
    end

    _G.CreateFrame = NewMockFrame
    _G.UIParent = NewMockFrame("Frame", "UIParent", nil, nil)
    _G.SlashCmdList = {}

    _G.MenuUtil = {
        CreateContextMenu = function(ownerRegion, generator)
            local items = {}
            local rootDesc = {
                CreateTitle = function(_, text)
                    items[#items + 1] = { kind = "title", text = text }
                end,
                CreateDivider = function()
                    items[#items + 1] = { kind = "divider" }
                end,
                CreateRadio = function(_, text, isSelected, setSelected)
                    items[#items + 1] = {
                        kind = "radio",
                        text = text,
                        isSelected = isSelected,
                        setSelected = setSelected,
                    }
                end,
                CreateCheckbox = function(_, text, isSelected, setSelected)
                    items[#items + 1] = {
                        kind = "checkbox",
                        text = text,
                        isSelected = isSelected,
                        setSelected = setSelected,
                    }
                end,
                CreateButton = function(_, text, callback)
                    items[#items + 1] = {
                        kind = "button",
                        text = text,
                        callback = callback,
                    }
                end,
            }
            generator(ownerRegion, rootDesc)
            mockState.lastContextMenu = { owner = ownerRegion, items = items }
            return mockState.lastContextMenu
        end,
    }

    _G.hooksecurefunc = function(tbl, key, hookFn)
        local orig = tbl[key]
        tbl[key] = function(...)
            local r1, r2, r3 = orig(...)
            hookFn(...)
            return r1, r2, r3
        end
    end

    _G.QuestUtilsOverrides = {
        GetQuestTagText = function(questID)
            local tag = mockState.questTags[questID]
            if tag and tag.tagName and tag.tagName ~= "" then
                return "(" .. tag.tagName .. ")"
            end
            return nil
        end,
    }

    _G.QuestCache = {
        Get = function(_, questID)
            for _, entry in ipairs(mockState.entries) do
                if not entry.isHeader and entry.questID == questID then
                    return {
                        questID = questID,
                        title = entry.title,
                        GetID = function() return questID end,
                        IsComplete = function() return mockState.questComplete[questID] == true end,
                        GetQuestLogIndex = function() return entry.questLogIndex end,
                    }
                end
            end
            return nil
        end,
    }

    _G.QuestObjectiveTrackerMixin = {
        headerHeight = 25,
        isCollapsed = false,
        SetContainer = function(self, c) self.parentContainer = c end,
        MarkDirty = function(self) self.isDirty = true end,
        SetHeader = function(self, text) self.Header.Text:SetText(text) end,
        WatchMoney = function() end,
        IsCollapsed = function(self) return self.isCollapsed == true end,
        SetCollapsed = function(self, c)
            self.isCollapsed = c and true or false
            self.ContentsFrame:SetShown(not self.isCollapsed)
            self.Header:SetCollapsed(self.isCollapsed)
            self:MarkDirty()
        end,
        OnEvent = function() end,
        LayoutContents = function(self)
            if self.EnumQuestWatchData then
                self:EnumQuestWatchData(self.UpdateSingle)
            end
        end,
        OnBlockHeaderClick = function(_, block, btn)
            mockState.lastDefaultClick = { id = block.id, button = btn }
        end,
        OnBlockHeaderEnter = function() end,
        OnBlockHeaderLeave = function() end,
        UpdateSingle = function(self, quest)
            self.renderedQuests = self.renderedQuests or {}
            self.renderedQuests[#self.renderedQuests + 1] = quest:GetID()
            self.hasContents = true
            return true
        end,
        Update = function(self, availableHeight)
            self.availableHeight = availableHeight or 800
            self.hasContents = false
            self.renderedQuests = {}
            self:LayoutContents()
            if self.hasContents then
                self:Show()
                return 40, false
            end
            self:Hide()
            return 0, false
        end,
        GetContentsHeight = function(self)
            return self.hasContents and 40 or 0
        end,
    }

    _G.QuestObjectiveTracker = NewMockFrame("Frame", "QuestObjectiveTracker", nil, "ObjectiveTrackerModuleTemplate")
    _G.Mixin(_G.QuestObjectiveTracker, _G.QuestObjectiveTrackerMixin)
    _G.QuestObjectiveTracker.uiOrder = 4
    _G.QuestObjectiveTracker.EnumQuestWatchData = function() end

    _G.AchievementObjectiveTracker = {
        uiOrder = 6,
        LayoutContents = function() return "stock_ach" end,
        MarkDirty = function() end,
        Update = function() return 0, false end,
        GetContentsHeight = function() return 0 end,
    }
    _G.ProfessionsRecipeTracker = {
        uiOrder = 9,
        LayoutContents = function() return "stock_prof" end,
        MarkDirty = function() end,
        Update = function() return 0, false end,
        GetContentsHeight = function() return 0 end,
    }

    local trackerFrame = NewMockFrame("Frame", "ObjectiveTrackerFrame", _G.UIParent, nil)
    trackerFrame.modules = {
        _G.QuestObjectiveTracker,
        _G.AchievementObjectiveTracker,
        _G.ProfessionsRecipeTracker,
    }
    trackerFrame.Header = NewMockFrame("Frame", nil, trackerFrame, nil)
    trackerFrame.Header.FilterButton = NewMockFrame("Button", nil, trackerFrame.Header, nil)
    trackerFrame.Header.FilterButton:Hide()
    trackerFrame._collapsed = false
    function trackerFrame:IsCollapsed() return self._collapsed end
    function trackerFrame:SetCollapsed(c) self._collapsed = c and true or false end
    function trackerFrame:MarkDirty() self.isDirty = true end
    function trackerFrame:AddModule(mod)
        self.modules[#self.modules + 1] = mod
        if mod.SetContainer then mod:SetContainer(self) end
    end
    function trackerFrame:Update()
        table.sort(self.modules, function(a, b) return (a.uiOrder or 99) < (b.uiOrder or 99) end)
        for _, m in ipairs(self.modules) do
            if m.Update then
                m:Update(800, false)
            end
        end
    end

    _G.ObjectiveTrackerFrame = trackerFrame
    _G.ObjectiveTrackerManager = {
        containers = { [trackerFrame] = true },
        Init = function() end,
        SetModuleContainer = function(_, mod, container)
            container:AddModule(mod)
        end,
    }

    return createdFrames
end

local function RegisterUIModuleSpecs(T, loadAddon)
    T:Test("TrackerHost populates peer section modules, strips (Dungeon) tag, and routes Ctrl+Click", function(assert)
        local mockState, ns = loadAddon()
        InstallUIFrameMocks(mockState)
        mockState:LoadScreenshotFixtures()
        mockState.realZone = "Stranglethorn Vale"
        mockState.uiMapID = 1434

        assert.IsTrue(ns.TrackerHost:Init())
        assert.Equal(24, #ns.TrackerHost.sectionPool)
        assert.IsTrue(_G.ObjectiveTrackerFrame.Header.FilterButton:IsShown())

        -- Slot 1 is Ready for Turn-In (expanded, 4 rendered quests)
        local mod1 = ns.TrackerHost.sectionPool[1]
        assert.Equal("READY", mod1.sectionKey)
        assert.Equal("Ready for Turn-In (4)", mod1.Header.Text:GetText())
        assert.IsFalse(mod1:IsCollapsed())
        assert.Equal(4, #mod1.renderedQuests)

        -- Slot 2 is Dungeon: City of Dalaran (folded due to Smart Auto-Fold, stripDungeonTag = true)
        local mod2 = ns.TrackerHost.sectionPool[2]
        assert.Equal("DUNGEON:City of Dalaran", mod2.sectionKey)
        assert.IsTrue(mod2:IsCollapsed())
        assert.Equal(0, #mod2.renderedQuests)
        -- GetQuestTagText suppresses "(Dungeon)" on quest 1008 inside Dungeon section
        assert.Equal(nil, mod2:GetQuestTagText(1008))

        -- Stranglethorn Vale section preserves "(Elite)" tag on Colonel Kurzen (1006)
        local stvMod = nil
        for _, m in ipairs(ns.TrackerHost.sectionPool) do
            if m.sectionKey == "ZONE:Stranglethorn Vale" then
                stvMod = m
                break
            end
        end
        assert.NotNil(stvMod)
        assert.Equal("(Elite)", stvMod:GetQuestTagText(1006))

        -- Ctrl+LeftClick on a block triggers waypoint instead of default click
        _G.IsControlKeyDown = function() return true end
        stvMod:OnBlockHeaderClick({ id = 1001 }, "LeftButton")
        assert.Equal(1001, mockState.superTrackedQuestID)
        assert.Equal(nil, mockState.lastDefaultClick)

        -- Normal LeftClick delegates to Blizzard's QuestObjectiveTrackerMixin.OnBlockHeaderClick
        _G.IsControlKeyDown = function() return false end
        stvMod:OnBlockHeaderClick({ id = 1007 }, "LeftButton")
        assert.Equal(1007, mockState.lastDefaultClick.id)
    end)

    T:Test(
        "Slash commands (/qsp filter, /qsp gray, /qsp diag, /qsp reset) update state and SuppressNonQuest",
        function(assert)
        local mockState, ns = loadAddon()
        InstallUIFrameMocks(mockState)
        mockState:LoadScreenshotFixtures()
        ns.TrackerHost:Init()
        ns.Diagnostics.RegisterSlashCommands()

        ns.Diagnostics.HandleSlashCommand("filter dungeon")
        assert.Equal("DUNGEON", ns.Store:GetChar().filterMode)
        assert.IsTrue(ns.TrackerHost.nonQuestSuppressed)

        ns.Diagnostics.HandleSlashCommand("gray")
        assert.IsTrue(ns.Store:GetChar().hideGray)

        mockState.chatMessages = {}
        ns.Diagnostics.HandleSlashCommand("diag")
        assert.IsTrue(#mockState.chatMessages >= 4)

        ns.Diagnostics.HandleSlashCommand("reset")
        assert.Equal("ALL", ns.Store:GetChar().filterMode)
        assert.IsFalse(ns.Store:GetChar().hideGray)
        assert.IsFalse(ns.TrackerHost.nonQuestSuppressed)
    end)

    T:Test(
        "SecureItemOverlay creates UIParent-parented type=item buttons out of combat and hides on disable",
        function(assert)
        local mockState, ns = loadAddon()
        InstallUIFrameMocks(mockState)
        mockState:LoadScreenshotFixtures()
        mockState.realZone = "Stranglethorn Vale"
        mockState.uiMapID = 1434
        ns.TrackerHost:Init()

        -- Attach a mock quest item button onto an active block in Ready module
        local readyMod = ns.TrackerHost.sectionPool[1]
        local itemBtn = _G.CreateFrame("Button", nil, readyMod, nil)
        itemBtn:SetAttribute("questLogIndex", 2)
        itemBtn:Show()
        local mockBlock = _G.CreateFrame("Frame", nil, readyMod, nil)
        mockBlock.id = 1001
        mockBlock.ItemButton = itemBtn
        mockBlock:Show()
        readyMod.usedBlocks = {
            ObjectiveTrackerQuestPOIBlockTemplate = { [1001] = mockBlock },
        }

        _G.GetQuestLogSpecialItemInfo = function(qLogIdx)
            if qLogIdx == 2 then
                return "|cff1eff00|Hitem:9999::::::::34:::::::::|h[Howin's Flare]|h|r", 134400, 1, false
            end
            return nil
        end

        assert.IsTrue(ns.SecureItemOverlay.SyncActiveModules(ns.TrackerHost.sectionPool, false))
        local overlay = _G["QuestSectionsPlusItemOverlay1"]
        assert.NotNil(overlay)
        assert.Equal(_G.UIParent, overlay:GetParent())
        assert.Equal("item", overlay:GetAttribute("type"))
        assert.Equal("Howin's Flare", overlay:GetAttribute("item"))
        assert.IsTrue(overlay:IsShown())

        -- Collapsing the parent tracker hides the overlay cleanly out of combat
        assert.IsTrue(ns.SecureItemOverlay.SyncActiveModules(ns.TrackerHost.sectionPool, true))
        assert.IsFalse(overlay:IsShown())
    end)

    T:Test(
        "Master Quests header folds quests panel and native FilterButton MenuUtil + SearchBoxNineSlice align cleanly",
        function(assert)
        local mockState, ns = loadAddon()
        InstallUIFrameMocks(mockState)
        mockState:LoadScreenshotFixtures()
        mockState.realZone = "Stormwind City"
        mockState.uiMapID = 1453
        ns.TrackerHost:Init()

        local fb = ns.TrackerHost.filterBar
        assert.NotNil(fb.Header, "Master Quests header is missing on FilterBar")
        assert.Equal("Quests (17)", fb.Header.Text:GetText())
        assert.IsFalse(fb:IsCollapsed())
        assert.Equal(26, fb:GetContentsHeight())
        assert.Equal(nil, fb.topRow, "Custom flat pill toolbar should not exist")
        assert.Equal("SearchBoxNineSliceTemplate", fb.searchBox._template)

        -- Left-clicking native Header.FilterButton opens Blizzard MenuUtil context menu
        local nativeFilterBtn = _G.ObjectiveTrackerFrame.Header.FilterButton
        local onClick = nativeFilterBtn:GetScript("OnClick")
        assert.NotNil(onClick)
        onClick(nativeFilterBtn, "LeftButton")
        assert.NotNil(mockState.lastContextMenu)

        local function FindMenuItem(label)
            for _, item in ipairs(mockState.lastContextMenu.items) do
                if item.text == label then
                    return item
                end
            end
            return nil
        end

        -- Select "Current Zone" in Stormwind City (0 local quests) -> Quests (0/17 - Zone) + fallback row
        local zoneRadio = FindMenuItem("Current Zone")
        assert.NotNil(zoneRadio)
        zoneRadio.setSelected()
        assert.Equal("Quests (0/17 - Zone)", fb.Header.Text:GetText())
        assert.IsTrue(fb.fallbackBtn:IsShown())

        -- Right-clicking native Header.FilterButton toggles native SearchBoxNineSliceTemplate within 7..-3 (250px) rail
        onClick(nativeFilterBtn, "RightButton")
        assert.IsTrue(fb.searchBox:IsShown())
        assert.Equal(7, fb.searchBox._points.TOPLEFT.x)
        assert.Equal(-3, fb.searchBox._points.TOPRIGHT.x)

        -- Reset Filters via MenuUtil restores All mode and hides search box
        onClick(nativeFilterBtn, "LeftButton")
        local resetBtn = FindMenuItem("Reset Filters")
        assert.NotNil(resetBtn)
        resetBtn.callback()
        assert.Equal("Quests (17)", fb.Header.Text:GetText())
        assert.IsFalse(fb.searchBox:IsShown())

        -- Collapse All / Expand All Sections via MenuUtil
        onClick(nativeFilterBtn, "LeftButton")
        FindMenuItem("Collapse All Sections").callback()
        assert.IsTrue(ns.TrackerHost.sectionPool[1]:IsCollapsed())
        FindMenuItem("Expand All Sections").callback()
        assert.IsFalse(ns.TrackerHost.sectionPool[1]:IsCollapsed())

        -- Collapsing master Quests header hides search, fallback, and all child quest sections
        fb.Header:OnToggle()
        assert.IsTrue(fb:IsCollapsed())
        assert.Equal(26, fb:GetContentsHeight())
        assert.Equal(nil, ns.TrackerHost.sectionPool[1].sectionKey)

        -- Expanding master Quests header restores all child sections
        fb.Header:OnToggle()
        assert.IsFalse(fb:IsCollapsed())
        assert.Equal("READY", ns.TrackerHost.sectionPool[1].sectionKey)
    end)
end

return RegisterUIModuleSpecs
