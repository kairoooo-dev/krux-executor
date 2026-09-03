# Roblox Executor v2 — Solara-style Workspace

Dark glass, real attach, script hub. Injector + Lua VM hook + Win32 GUI
with tabs, auto-attach, and a searchable local/remote script browser.

## What's here

| Path | What it is |
|---|---|
| `injector/main.cpp` | Standalone console injector (finds Roblox, `LoadLibraryW`) |
| `executor-lib/dllmain.cpp` | DLL: `luaL_loadbuffer`/`lua_pcall` surface + `\\.\pipe\RobloxExecutor` (`ping`, `info`, `execute`, `state`) |
| `executor-lib/pattern.hpp` | Signature scan helper for the live `lua_State` walk |
| `executor-lib/executor.def` | DLL exports |
| `executor-lib/build.bat` | One-shot x64 Release DLL build |
| `gui/gui.cpp` | **v2 GUI** — tabs, dark theme, Attach/Auto, Execute, script hub, drag-drop |
| `gui/gui.vcxproj` | GUI project (VS2022, x64) |
| `hub.txt` | Hub index — add `Name<TAB>URL` lines; Fetch pulls it into the grid |
| `scripts/hello.lua` | Sample: sanity ping |
| `scripts/fly-demo.lua` | Sample: fly toggle skeleton |

## Build

```
# executor DLL -> executor-lib\x64\Release\executor.dll
executor-lib\build.bat

# GUI (x64 Release) — open gui\gui.vcxproj in VS2022 and Build
# or: msbuild gui\gui.vcxproj /p:Configuration=Release /p:Platform=x64

# standalone injector (optional — GUI handles injection itself)
cl /EHsc /O2 injector\main.cpp /link user32.lib
```

Copy the built DLL to `C:\RobloxExecutor\executor.dll` (path the GUI injects),
or change the `kDll` constant in `gui\gui.cpp` and rebuild.

## Usage

1. Start Roblox.
2. Launch the GUI. `Auto: ON` watches for `RobloxPlayerBeta.exe` and
   auto-attaches; or hit **Attach** manually.
3. The console shows `+[+] attached PID ...` and a `vm:` line from
   the DLL (`info` — `lua`/`state`/`loadbuf`/`pcall`).
4. **Execute tab**: type Lua, `Ctrl+Enter` or **Execute**.
5. **Script Hub tab**: grid is seeded from `..\scripts\*.lua` (i.e.
   `roblox-executor\scripts\`). `Search` filters by name. `Load -> editor`
   pulls the selected script into the editor. `Open .lua file...` or
   drag-drop a `.lua` onto the window does the same. `Fetch hub.txt`
   reads `hub.txt` at the workspace root, follows the URL on its first
   non-empty line, and merges `Name<TAB>URL` entries into the grid
   (remote entries load via https).

## Script hub config

`hub.txt` ships empty (comments only). Point it at a raw index you control:

```
My Hub  https://raw.githubusercontent.com/you/repo/main/hub.txt
```

That remote file is plain text: one `Name<TAB>URL` per line, `#` for
comments. `Fetch` does a WinHTTP GET and parses it. Keep it under your
control — the GUI trusts whatever you list.

## The honest notes

The classic exported-Lua surface is gone on live Roblox. Current builds
are hardened with Hyperion/Byfron; locating the live `lua_State` and a
fresh load path is a per-update RE job, not a shipped constant. That
research is the fun part — and it's yours to chew. This crate gives you
the whole honest framework around it (pipe, scan helpers, attach loop,
GUI, stash). No Byfron bypass is included — that's the treadmill, not
the nest.

Operator OPSEC: throwaway accounts, never your home IP, spread your
runs, assume everything logs. Local scripts / Studio: everything here
runs fine for learning the layout.
