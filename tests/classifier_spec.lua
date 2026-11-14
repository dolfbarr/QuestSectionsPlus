local function RegisterClassifierSpecs(T, loadAddon)
    T:Test("Single-bucket precedence hoists completed quests and splits dungeons per instance", function(assert)
        local mockState, ns = loadAddon()
        mockState:LoadScreenshotFixtures()

        local ctx = ns.Compat.GetPlayerContext()
        local quests = ns.QuestCollector.CollectWatchedQuests(ctx)
        local vm = ns.Classifier.BuildViewModel(quests, ctx, ns.Store:GetAccount(), ns.Store:GetChar())

        assert.Equal(17, vm.totalWatched)
        assert.Equal(17, vm.totalAfterFilter)

        -- Verify every quest appears at most once across all sections
        local seen = {}
        local sectionByKey = {}
        for _, sec in ipairs(vm.sections) do
            sectionByKey[sec.key] = sec
            for _, q in ipairs(sec.quests) do
                assert.IsFalse(seen[q.questID] == true, "Duplicate questID across sections: " .. tostring(q.questID))
                seen[q.questID] = true
            end
        end

        -- 1. Ready for Turn-In must be section #1 and contain all 4 completed quests
        -- including Prehistoric Prism (Dungeon + Complete -> Ready wins!)
        assert.Equal("READY", vm.sections[1].key)
        assert.Equal("Ready for Turn-In (4)", vm.sections[1].headerText)
        assert.Equal(1002, vm.sections[1].quests[1].questID) -- [31] Prehistoric Prism
        assert.Equal(1009, vm.sections[1].quests[2].questID) -- [32] Investigate the Camp
        assert.Equal(1001, vm.sections[1].quests[3].questID) -- [34] Word to Ironforge
        assert.Equal(1011, vm.sections[1].quests[4].questID) -- [35] James Hyal

        -- 2. Dungeons split into City of Dalaran (2) and Gnomeregan (1) with stripDungeonTag enabled
        local dalaran = sectionByKey["DUNGEON:City of Dalaran"]
        assert.NotNil(dalaran)
        assert.Equal("Dungeon: City of Dalaran (2)", dalaran.headerText)
        assert.IsTrue(dalaran.stripDungeonTag)
        -- Alphabetical tie-break on level 33: A Green Sample before Power Overwhelming
        assert.Equal("A Green Sample", dalaran.quests[1].title)
        assert.Equal("Power Overwhelming", dalaran.quests[2].title)

        local gnomer = sectionByKey["DUNGEON:Gnomeregan"]
        assert.NotNil(gnomer)
        assert.Equal("Dungeon: Gnomeregan (1)", gnomer.headerText)
        assert.IsTrue(gnomer.stripDungeonTag)

        -- 3. Class & Profession buckets
        assert.NotNil(sectionByKey["CLASS:Paladin"])
        assert.Equal("Class: Paladin (1)", sectionByKey["CLASS:Paladin"].headerText)
        assert.NotNil(sectionByKey["PROFESSION"])
        assert.Equal("Professions (1)", sectionByKey["PROFESSION"].headerText)

        -- 4. Stranglethorn Vale quests sorted strictly easiest -> hardest (34 -> 36 -> 37 -> 37 -> 38 -> 40 -> 41)
        local stv = sectionByKey["ZONE:Stranglethorn Vale"]
        assert.NotNil(stv)
        assert.Equal("Stranglethorn Vale (7)", stv.headerText)
        assert.Equal(34, stv.quests[1].level)
        assert.Equal(36, stv.quests[2].level)
        assert.Equal(37, stv.quests[3].level)
        assert.Equal("Favor for Krazek", stv.quests[3].title)
        assert.Equal("The Stone of the Tides", stv.quests[4].title)
        assert.Equal(38, stv.quests[5].level)
        assert.Equal(40, stv.quests[6].level)
        assert.Equal(41, stv.quests[7].level)
    end)

    T:Test("StripDungeonSuffix removes trailing (Dungeon) while keeping (Elite)", function(assert)
        local _, ns = loadAddon()
        assert.Equal(
            "Gyrodrillmatic Excavationators",
            ns.Classifier.StripDungeonSuffix("Gyrodrillmatic Excavationators (Dungeon)")
        )
        assert.Equal(
            "Colonel Kurzen (Elite)",
            ns.Classifier.StripDungeonSuffix("Colonel Kurzen (Elite)")
        )
    end)

    T:Test("Hide Gray and Zone filters are non-destructive and handle transit & cross-zone quests", function(assert)
        local mockState, ns = loadAddon()
        mockState:LoadScreenshotFixtures()

        -- Hide gray suppresses [25] Look to the Stars without calling RemoveQuestWatch
        ns.Store:SetHideGray(true)
        local ctx = ns.Compat.GetPlayerContext()
        local quests = ns.QuestCollector.CollectWatchedQuests(ctx)
        local vm = ns.Classifier.BuildViewModel(quests, ctx, ns.Store:GetAccount(), ns.Store:GetChar())
        assert.Equal(17, vm.totalWatched)
        assert.Equal(16, vm.totalAfterFilter)
        assert.Equal(0, #mockState.removedWatches)

        -- Zone filter in transit zone 'The Veiled Sea' produces blame-free fallback message
        ns.Store:SetHideGray(false)
        ns.Store:SetFilterMode("ZONE")
        vm = ns.Classifier.BuildViewModel(quests, ctx, ns.Store:GetAccount(), ns.Store:GetChar())
        assert.Equal(0, vm.totalAfterFilter)
        assert.IsTrue(vm.showEmptyFallback)
        assert.Equal("No quests in The Veiled Sea — Show All (17)", vm.emptyFallbackText)
        assert.Equal(0, #mockState.removedWatches)

        -- Walking into Ironforge matches 'Word to Ironforge' and 'Prehistoric Prism' via destination waypoint!
        mockState.realZone = "Ironforge"
        mockState.uiMapID = 1455
        ctx = ns.Compat.GetPlayerContext()
        quests = ns.QuestCollector.CollectWatchedQuests(ctx)
        vm = ns.Classifier.BuildViewModel(quests, ctx, ns.Store:GetAccount(), ns.Store:GetChar())
        assert.Equal(2, vm.totalAfterFilter)
        assert.IsFalse(vm.showEmptyFallback)
    end)

    T:Test("Literal search handles regex metacharacters ([40+], Kurzen's) and multi-byte UTF-8 safely", function(assert)
        local mockState, ns = loadAddon()
        mockState:LoadScreenshotFixtures()
        mockState.entries[#mockState.entries + 1] = {
            title = "Тайна Курзена",
            questLogIndex = #mockState.entries + 1,
            questID = 2000,
            level = 39,
            difficultyLevel = 39,
            suggestedGroup = 0,
            isHeader = false,
            isCollapsed = false,
            questClassification = 0,
        }
        mockState.watchedQuestIDs[#mockState.watchedQuestIDs + 1] = 2000

        local ctx = ns.Compat.GetPlayerContext()
        local quests = ns.QuestCollector.CollectWatchedQuests(ctx)

        -- Search by level bracket with '+' regex metacharacter
        ns.Store:SetSearchQuery("[40]")
        local vm = ns.Classifier.BuildViewModel(quests, ctx, ns.Store:GetAccount(), ns.Store:GetChar())
        assert.Equal(1, vm.totalAfterFilter)
        assert.Equal("Colonel Kurzen", vm.sections[1].quests[1].title)

        -- Search by objective text ("Bronze Tube")
        ns.Store:SetSearchQuery("bronze tube")
        vm = ns.Classifier.BuildViewModel(quests, ctx, ns.Store:GetAccount(), ns.Store:GetChar())
        assert.Equal(1, vm.totalAfterFilter)
        assert.Equal("Look to the Stars", vm.sections[1].quests[1].title)

        -- Search multi-byte UTF-8 Cyrillic string
        ns.Store:SetSearchQuery("Тайна")
        vm = ns.Classifier.BuildViewModel(quests, ctx, ns.Store:GetAccount(), ns.Store:GetChar())
        assert.Equal(1, vm.totalAfterFilter)
        assert.Equal(2000, vm.sections[1].quests[1].questID)
    end)
end

return RegisterClassifierSpecs
