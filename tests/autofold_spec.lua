local function RegisterAutoFoldSpecs(T, loadAddon)
    T:Test(
        "Smart Auto-Fold expands Ready and Current Zone, folds distant zones, and respects manual overrides",
        function(assert)
        local mockState, ns = loadAddon()
        mockState:LoadScreenshotFixtures()

        -- Player enters Stranglethorn Vale
        mockState.realZone = "Stranglethorn Vale"
        mockState.uiMapID = 1434

        local ctx = ns.Compat.GetPlayerContext()
        local quests = ns.QuestCollector.CollectWatchedQuests(ctx)
        local vm = ns.Classifier.BuildViewModel(quests, ctx, ns.Store:GetAccount(), ns.Store:GetChar())

        local byKey = {}
        for _, sec in ipairs(vm.sections) do
            byKey[sec.key] = sec
        end

        -- Ready for Turn-In and Stranglethorn Vale auto-expand; Duskwood and Dungeons auto-fold
        assert.IsFalse(byKey["READY"].isCollapsed)
        assert.IsFalse(byKey["ZONE:Stranglethorn Vale"].isCollapsed)
        assert.IsTrue(byKey["ZONE:Duskwood"].isCollapsed)
        assert.IsTrue(byKey["DUNGEON:Gnomeregan"].isCollapsed)
        assert.IsTrue(byKey["DUNGEON:City of Dalaran"].isCollapsed)

        -- Current zone Stranglethorn Vale sorts directly above Duskwood
        local stvIndex, duskwoodIndex
        for idx, sec in ipairs(vm.sections) do
            if sec.key == "ZONE:Stranglethorn Vale" then stvIndex = idx end
            if sec.key == "ZONE:Duskwood" then duskwoodIndex = idx end
        end
        assert.IsTrue(stvIndex < duskwoodIndex)

        -- User manually unfolds Duskwood and folds Stranglethorn Vale while still in Stranglethorn Vale
        ns.Store:SetManualCollapsed("ZONE:Duskwood", false)
        ns.Store:SetManualCollapsed("ZONE:Stranglethorn Vale", true)

        vm = ns.Classifier.BuildViewModel(quests, ctx, ns.Store:GetAccount(), ns.Store:GetChar())
        byKey = {}
        for _, sec in ipairs(vm.sections) do
            byKey[sec.key] = sec
        end
        assert.IsFalse(byKey["ZONE:Duskwood"].isCollapsed)
        assert.IsTrue(byKey["ZONE:Stranglethorn Vale"].isCollapsed)

        -- Entering City of Dalaran dungeon instance clears stale manual overrides and auto-expands that dungeon!
        mockState.inInstance = true
        mockState.instanceType = "party"
        mockState.realZone = "City of Dalaran"
        mockState.uiMapID = 2001

        ctx = ns.Compat.GetPlayerContext()
        quests = ns.QuestCollector.CollectWatchedQuests(ctx)
        vm = ns.Classifier.BuildViewModel(quests, ctx, ns.Store:GetAccount(), ns.Store:GetChar())
        byKey = {}
        for _, sec in ipairs(vm.sections) do
            byKey[sec.key] = sec
        end

        assert.IsFalse(byKey["READY"].isCollapsed)
        assert.IsFalse(byKey["DUNGEON:City of Dalaran"].isCollapsed)
        assert.IsTrue(byKey["DUNGEON:Gnomeregan"].isCollapsed)
        assert.IsTrue(byKey["ZONE:Duskwood"].isCollapsed)
        assert.IsTrue(byKey["ZONE:Stranglethorn Vale"].isCollapsed)
    end)
end

return RegisterAutoFoldSpecs
