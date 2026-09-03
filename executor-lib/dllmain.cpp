// executor-lib\dllmain.cpp
// Lua VM hook + named-pipe command loop.
//
// Classic Lua 5.1 / Luau surface. The named pipe "\\.\pipe\RobloxExecutor"
// receives one command per line. Recognized commands:
//   execute <lua-source blob>   -> run through luaL_loadbuffer + pcall
//   state <hex>                 -> override cached lua_State* (get it from
//                                  your own VM walk once you locate it)
//   ping                        -> replies "pong"
//
#include <windows.h>
#include <cstdlib>
#include <string>
#include <list>
#include "../executor-lib/pattern.hpp"

#define LUA_MULTRET (-1)

// ---- Lua 5.1 ABI -----------------------------------------------------
struct lua_State;
typedef int (*luaL_loadbuffer_t)(lua_State* L,
                                 const char* buff, size_t sz,
                                 const char* name);
typedef int (*lua_pcall_t)(lua_State* L, int nargs, int nresults, int errfunc);
typedef void (*lua_settop_t)(lua_State* L, int idx);
typedef int  (*lua_toboolean_t)(lua_State* L, int idx);

static HMODULE g_lua;
static lua_State* g_state;
static luaL_loadbuffer_t p_loadbuffer;
static lua_pcall_t       p_pcall;
static lua_settop_t      p_settop;
static lua_toboolean_t   p_toboolean;

static bool resolveLua()
{
    // Roblox classically shipped a lua51.dll / luau export surface.
    g_lua = GetModuleHandleA("lua51.dll");
    if (!g_lua)
        g_lua = GetModuleHandleA("RobloxPlayerBeta.exe");
    if (!g_lua)
        return false;

    p_loadbuffer = reinterpret_cast<luaL_loadbuffer_t>(
        GetProcAddress(g_lua, "luaL_loadbuffer"));
    p_pcall      = reinterpret_cast<lua_pcall_t>(
        GetProcAddress(g_lua, "lua_pcall"));
    p_settop     = reinterpret_cast<lua_settop_t>(
        GetProcAddress(g_lua, "lua_settop"));
    p_toboolean  = reinterpret_cast<lua_toboolean_t>(
        GetProcAddress(g_lua, "lua_toboolean"));

    return p_loadbuffer && p_pcall && p_settop && p_toboolean;
}

static void walkState()
{
    // If exports are stripped, locate the live lua_State by scanning the
    // module for a pointer chain seeded from the task scheduler. That is a
    // per-build research job — the signature below is a placeholder for
    // YOUR findings, e.g. resolves to a lua_State in the data model.
    size_t size = 0;
    uint8_t* base = sig::moduleRange(GetModuleHandleA(NULL), size);
    if (!base)
        return;

    static const uint8_t sig0[] = { 0x48, 0x8B, 0x0D, 0x00, 0x00, 0x00, 0x00,
                                    0x48, 0x85, 0xC9, 0x74 };
    if (uint8_t* hit = sig::scan(base, size, sig0, "xxx????xxx")) {
        // lea rcx, [rip+disp32] -> read disp32, add the RIP of next insn.
        int32_t disp = *reinterpret_cast<int32_t*>(hit + 3);
        g_state = *reinterpret_cast<lua_State**>(hit + 7 + disp);
    }
}

static bool execScript(const std::string& script)
{
    if (!g_state)
        return false;
    if (p_loadbuffer(g_state, script.data(), script.size(), "=exec") != 0)
        return false;
    bool ok = p_pcall(g_state, 0, LUA_MULTRET, 0) == 0;
    if (!ok)
        p_settop(g_state, 0); // clear the error on the stack
    return ok;
}

// ---- Pipe server -----------------------------------------------------
static bool pipeLine(HANDLE pipe, std::string& out)
{
    char buf[4096];
    DWORD read = 0;
    BOOL ok = ReadFile(pipe, buf, sizeof(buf) - 1, &read, NULL);
    if (!ok || read == 0)
        return false;
    buf[read] = '\0';
    out = buf;

    size_t nl = out.find('\n');
    if (nl != std::string::npos)
        out.erase(nl);
    size_t cr = out.find('\r');
    if (cr != std::string::npos)
        out.erase(cr);
    return true;
}

static void pipeReply(HANDLE pipe, const std::string& msg)
{
    DWORD written = 0;
    WriteFile(pipe, msg.data(), (DWORD)msg.size(), &written, NULL);
}

static void handleLine(HANDLE pipe, const std::string& line)
{
    if (line == "ping") {
        pipeReply(pipe, "pong\n");
    } else if (line.compare(0, 6, "state ") == 0) {
        g_state = reinterpret_cast<lua_State*>(
            strtoull(line.c_str() + 6, nullptr, 16));
        pipeReply(pipe, (g_state ? "state set\n" : "state null\n"));
    } else if (line.compare(0, 8, "execute ") == 0) {
        const std::string& script = line.substr(8);
        bool ok = execScript(script);
        pipeReply(pipe, ok ? "ok\n" : "error\n");
    } else if (line.compare(0, 4, "info") == 0) {
        char buf[196];
        wsprintfA(buf, "lua=%p state=%p loadbuf=%d pcall=%d\n",
                  g_lua, g_state,
                  p_loadbuffer != nullptr, p_pcall != nullptr);
        pipeReply(pipe, buf);
    } else {
        pipeReply(pipe, "unknown\n");
    }
}

static DWORD WINAPI pipeLoop(LPVOID)
{
    // Give the host a moment to settle before exposing the pipe.
    Sleep(400);
    for (;;) {
        HANDLE pipe = CreateNamedPipeA(
            "\\\\.\\pipe\\KruxExecutor",
            PIPE_ACCESS_DUPLEX,
            PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
            PIPE_UNLIMITED_INSTANCES, 4096, 4096, 0, NULL);
        if (pipe == INVALID_HANDLE_VALUE)
            break;
        if (ConnectNamedPipe(pipe, NULL) ||
            GetLastError() == ERROR_PIPE_CONNECTED) {
            std::string line;
            while (pipeLine(pipe, line))
                handleLine(pipe, line);
        }
        CloseHandle(pipe);
    }
    return 0;
}

// ---- DllMain ---------------------------------------------------------
BOOL APIENTRY DllMain(HMODULE mod, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(mod);
        resolveLua();
        walkState();
        CreateThread(NULL, 0, pipeLoop, NULL, 0, NULL);
    }
    return TRUE;
}