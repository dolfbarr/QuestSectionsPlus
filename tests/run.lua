local function ResolveRootDir()
    local src = debug and debug.getinfo and debug.getinfo(1, "S").source or ""
    if string.sub(src, 1, 1) == "@" then
        src = string.sub(src, 2)
    end
    local root = string.match(src, "^(.*)/tests/run%.lua$")
    if root and root ~= "" then
        return root .. "/"
    end
    return ""
end

local ROOT_DIR = ResolveRootDir()

local SOURCE_FILES = {
    "src/Compat.lua",
    "src/State/Store.lua",
    "src/Bridge/QuestBridge.lua",
    "src/Data/QuestCollector.lua",
    "src/Domain/Classifier.lua",
    "src/UI/SecureItemOverlay.lua",
    "src/UI/FilterBar.lua",
    "src/UI/SectionModule.lua",
    "src/UI/TrackerHost.lua",
    "src/UI/Diagnostics.lua",
    "src/Core/Bootstrap.lua",
}

local Mock = assert(loadfile(ROOT_DIR .. "tests/mocks/wow_api_mock.lua"))()

local function LoadAddonInstance()
    local mockState = Mock.Install()
    local ns = {}
    for _, relPath in ipairs(SOURCE_FILES) do
        local chunk, err = loadfile(ROOT_DIR .. relPath)
        if not chunk then
            error("Failed loading " .. relPath .. ": " .. tostring(err))
        end
        chunk("QuestSectionsPlus", ns)
    end
    ns.Store:Init()
    return mockState, ns
end

local T = {
    tests = {},
    passed = 0,
    failed = 0,
}

function T:Test(name, fn)
    self.tests[#self.tests + 1] = { name = name, fn = fn }
end

local Assertions = {}

function Assertions.Equal(expected, actual, msg)
    if expected ~= actual then
        error(string.format(
            "%sExpected %s, got %s",
            msg and (msg .. ": ") or "",
            tostring(expected),
            tostring(actual)
        ), 2)
    end
end

function Assertions.IsTrue(val, msg)
    if val ~= true then
        error((msg or "Assertion failed") .. ": expected true, got " .. tostring(val), 2)
    end
end

function Assertions.IsFalse(val, msg)
    if val ~= false then
        error((msg or "Assertion failed") .. ": expected false, got " .. tostring(val), 2)
    end
end

function Assertions.NotNil(val, msg)
    if val == nil then
        error((msg or "Assertion failed") .. ": expected non-nil value", 2)
    end
end

assert(loadfile(ROOT_DIR .. "tests/classifier_spec.lua"))()(T, LoadAddonInstance)
assert(loadfile(ROOT_DIR .. "tests/autofold_spec.lua"))()(T, LoadAddonInstance)
assert(loadfile(ROOT_DIR .. "tests/combat_and_store_spec.lua"))()(T, LoadAddonInstance)
assert(loadfile(ROOT_DIR .. "tests/ui_modules_spec.lua"))()(T, LoadAddonInstance)

for _, item in ipairs(T.tests) do
    local ok, err = pcall(item.fn, Assertions)
    if ok then
        T.passed = T.passed + 1
        print(string.format("[PASS] %s", item.name))
    else
        T.failed = T.failed + 1
        print(string.format("[FAIL] %s\n       %s", item.name, tostring(err)))
    end
end

print(string.format("\nSummary: %d passed, %d failed (%d total)", T.passed, T.failed, #T.tests))
if T.failed > 0 then
    os.exit(1)
end
