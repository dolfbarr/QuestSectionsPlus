local function RegisterCombatAndStoreSpecs(T, loadAddon)
    T:Test("InCombatLockdown queues structural reflows and flushes on PLAYER_REGEN_ENABLED", function(assert)
        local mockState, ns = loadAddon()
        mockState:LoadScreenshotFixtures()

        mockState.inCombat = true
        local applied, status = ns.TrackerHost:RequestReflow("filter_in_combat")
        assert.IsFalse(applied)
        assert.Equal("queued_in_combat", status)
        assert.IsTrue(ns.TrackerHost.pendingReflow)

        -- Flush while still in combat must remain blocked
        assert.IsFalse(ns.TrackerHost:FlushCombatQueue())
        assert.IsTrue(ns.TrackerHost.pendingReflow)

        -- Leaving combat flushes pending reflow cleanly
        mockState.inCombat = false
        local flushed = ns.TrackerHost:FlushCombatQueue()
        assert.IsTrue(flushed)
        assert.IsFalse(ns.TrackerHost.pendingReflow)
    end)

    T:Test("Store CVar backup restores settings if SavedVariables fail to flush on 16001", function(assert)
        local mockState, ns = loadAddon()

        ns.Store:SetAccountOption("smartAutoFold", false)
        ns.Store:SetFilterMode("DUNGEON")
        ns.Store:SetHideGray(true)

        local backupRaw = mockState.cvarStore[ns.Store.CVAR_BACKUP_NAME]
        assert.NotNil(backupRaw)

        -- Simulate fresh session where SavedVariables were nil, leaving only CVar backup
        _G.QuestSectionsPlusDB = nil
        _G.QuestSectionsPlusCharDB = nil
        ns.Store:Init()

        assert.IsFalse(ns.Store:GetAccount().smartAutoFold)
        assert.Equal("DUNGEON", ns.Store:GetChar().filterMode)
        assert.IsTrue(ns.Store:GetChar().hideGray)
    end)

    T:Test(
        "QuestBridge routes Ctrl+Click waypoints through ForeverQuestPins, TomTom, then Blizzard SuperTrack",
        function(assert)
        local mockState, ns = loadAddon()
        mockState:LoadScreenshotFixtures()

        -- 1. Fallback to Blizzard SuperTrack when no external addon is loaded
        local ok, provider = ns.QuestBridge.TriggerWaypoint(1001, "Word to Ironforge")
        assert.IsTrue(ok)
        assert.Equal("BlizzardSuperTrack", provider)
        assert.Equal(1001, mockState.superTrackedQuestID)

        -- 2. TomTom fallback when TomTom is present
        local tomtomAdded = nil
        _G.TomTom = {
            AddWaypoint = function(_, mapID, x, y, opts)
                tomtomAdded = { mapID = mapID, x = x, y = y, title = opts.title }
            end,
        }
        ok, provider = ns.QuestBridge.TriggerWaypoint(1001, "Word to Ironforge")
        assert.IsTrue(ok)
        assert.Equal("TomTom", provider)
        assert.NotNil(tomtomAdded)
        assert.Equal(1455, tomtomAdded.mapID)

        -- 3. ForeverQuestPins takes priority when installed
        local fqpTracked = nil
        _G.ForeverQuestPins = {
            TrackQuest = function(qID)
                fqpTracked = qID
                return true
            end,
        }
        ok, provider = ns.QuestBridge.TriggerWaypoint(1008, "Power Overwhelming")
        assert.IsTrue(ok)
        assert.Equal("ForeverQuestPins", provider)
        assert.Equal(1008, fqpTracked)
    end)
end

return RegisterCombatAndStoreSpecs
