from __future__ import annotations

from pathlib import Path

from lupa import lua51

REPO_ROOT = Path(__file__).resolve().parent.parent


def test_all_lua_files_compile_cleanly_in_lua51() -> None:
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua_files = sorted(
        list((REPO_ROOT / "src").rglob("*.lua")) + list((REPO_ROOT / "tests").rglob("*.lua"))
    )
    assert len(lua_files) >= 16

    assert_loadfile = lua.eval("function(path) return assert(loadfile(path)) end")
    for path in lua_files:
        chunk = assert_loadfile(str(path))
        assert chunk is not None


def test_lua51_headless_addon_specs() -> None:
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    run_lua = REPO_ROOT / "tests" / "run.lua"
    escaped = str(run_lua).replace("\\", "\\\\").replace('"', '\\"')
    lua.execute(f'assert(loadfile("{escaped}"))()')
