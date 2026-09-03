# KRUX internal DLL base (NOT shipped — reference only)

Vendored from **TaaprWare V3** by plusgiant5 (see `LICENSE.TaaprWare.txt`).
Upstream: https://github.com/plusgiant5/TaaprWareV3

KRUX-side changes in `dllmain.cpp`:
- `USE_PIPE` enabled so the GUI can send scripts over `\\.\pipe\KruxInternal`
- Pipe renamed from `TaaprWareV3` to `KruxInternal`

## Why this is not built or shipped

1. **32-bit.** The project targets Release x86 with hardcoded x86 base+offsets
   (`roblox.h`). Modern `RobloxPlayerBeta.exe` is 64-bit — every address is wrong.
2. **Stale offsets.** `getscheduler`, `task_defer`, `luavm_load`, hook addresses,
   the `ScriptContext` encryption (`get_scriptstate`), and Luau `top` offset all
   change with Roblox updates (author notes: "every week"). They must be
   re-dumped per Roblox version with a disassembler/offset dumper.
3. **No MSVC here.** The `.vcxproj` needs Visual Studio C++ build tools.
   A MinGW i686 (`mingw-w64-i686-gcc`) rebuild is possible but untested.
4. **Injection.** Classic `LoadLibrary` injection into Roblox is killed by
   Hyperion. Shipping this needs a Hyperion-safe injection method first —
   that is the actual hard part, not the DLL.

## What it would take to revive

- Dump fresh x64 offsets for the current Roblox build
   (`getscheduler`, `luavm_load`, `task_defer`, state/context offsets)
- Port structs to x64, rebuild as x86_64 DLL
- Hyperion-safe loader, then point the KRUX GUI at `KruxInternal` pipe

Until then, the supported path is the **external Xeno bytecode engine**
(`Xeno.dll`, built from `krux-xeno/`).
