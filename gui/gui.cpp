// gui\gui.cpp  v2
// Solara-style executor UI rebuilt: real attach loop (auto-attach watcher),
// script hub (search over local stash + indexable remote corpus), tabs,
// drag-drop, Ctrl+Enter execution.
#include <windows.h>
#include <commctrl.h>
#include <winhttp.h>
#include <string>
#include <vector>
#include <algorithm>

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "winhttp.lib")
#pragma comment(linker,"/manifestdependency:\"type='win32' \
 name='Microsoft.Common-Controls' version='6.0.0.0' \
 processorArchitecture='*' publicKeyToken='6595b64144ccf1df' \
 language='*'\"")

// ---------------- colors / fonts ----------------
static const COLORREF BG_DARK   = RGB(16, 16, 22);
static const COLORREF BG_PANEL  = RGB(26, 26, 36);
static const COLORREF ACCENT    = RGB(96, 176, 255);
static const COLORREF GOLD      = RGB(240, 200, 90);
static const COLORREF TEXT_MAIN = RGB(232, 232, 242);
static const COLORREF TEXT_DIM  = RGB(150, 150, 168);
static const COLORREF EDIT_BG   = RGB(11, 11, 17);

static HINSTANCE gHInst;
static HWND gMain;
static HWND gTab;
static HWND gStatText;     // status bar label
static HWND gEdit, gLog;
static HWND gSearchEdit, gList;
static HWND gLabelSearch, gLabelConsole, gLabelHint;
static HWND gBtnAttach, gBtnExec, gBtnClear, gBtnAuto;
static HWND gBtnSearch, gBtnFetch, gBtnLoad, gBtnOpenFile;
static HFONT gFontTitle, gFontHead, gFontMono, gFontUi;
static HBRUSH gBrushBg, gBrushPanel, gBrushEdit;

static CRITICAL_SECTION gCs;      // guard shared script list
static std::string gLogText;
static bool gAttached = false;
static std::vector<DWORD> gPidsInjected;
static bool gAutoAttach = true;

// script hubs: {name, url-or-empty}. Empty url = local file.
struct Hub { std::string name; std::string url; };
static std::vector<Hub> gScripts;

static std::string gExeDir;

// custom messages
#define WM_APP_HUB    (WM_APP + 2)   // lParam = std::vector<Hub>*

static void setStatus(const std::string& text, COLORREF col)
{
    SetWindowTextA(gStatText, text.c_str());
}

static void logLine(const std::string& msg)
{
    gLogText += msg + "\r\n";
    SetWindowTextA(gLog, gLogText.c_str());
}

// ---------------- helpers ----------------
static std::string ws2s(const std::wstring& w)
{
    int n = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(),
                                NULL, 0, NULL, NULL);
    std::string s(n, 0);
    WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(),
                        &s[0], n, NULL, NULL);
    return s;
}

static void getExeDir()
{
    wchar_t buf[MAX_PATH];
    GetModuleFileNameW(NULL, buf, MAX_PATH);
    std::wstring p(buf);
    size_t slash = p.find_last_of(L"\\/");
    gExeDir = ws2s(p.substr(0, slash));
}

// ---------------- process hunt ----------------
static std::vector<DWORD> findPids(const wchar_t* name)
{
    std::vector<DWORD> pids;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return pids;
    PROCESSENTRY32W pe; pe.dwSize = sizeof(pe);
    if (Process32FirstW(snap, &pe)) {
        do {
            if (_wcsicmp(pe.szExeFile, name) == 0)
                pids.push_back(pe.th32ProcessID);
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);
    return pids;
}

static bool injectDll(DWORD pid, const std::wstring& dllPath)
{
    HANDLE proc = OpenProcess(PROCESS_CREATE_THREAD | PROCESS_VM_OPERATION |
                              PROCESS_VM_WRITE | PROCESS_QUERY_INFORMATION,
                              FALSE, pid);
    if (!proc) return false;

    size_t len = (dllPath.size() + 1) * sizeof(wchar_t);
    void* remote = VirtualAllocEx(proc, NULL, len, MEM_COMMIT | MEM_RESERVE,
                                  PAGE_READWRITE);
    if (!remote) { CloseHandle(proc); return false; }

    if (!WriteProcessMemory(proc, remote, dllPath.c_str(), len, NULL)) {
        VirtualFreeEx(proc, remote, 0, MEM_RELEASE);
        CloseHandle(proc);
        return false;
    }

    HMODULE k32 = GetModuleHandleA("kernel32.dll");
    FARPROC loadLib = GetProcAddress(k32, "LoadLibraryW");

    HANDLE thread = CreateRemoteThread(proc, NULL, 0,
        (LPTHREAD_START_ROUTINE)loadLib, remote, 0, NULL);
    if (!thread) {
        VirtualFreeEx(proc, remote, 0, MEM_RELEASE);
        CloseHandle(proc);
        return false;
    }
    WaitForSingleObject(thread, INFINITE);
    CloseHandle(thread);
    VirtualFreeEx(proc, remote, 0, MEM_RELEASE);
    CloseHandle(proc);
    return true;
}

// ---------------- pipe client ----------------
static std::string pipeRequest(const std::string& cmd)
{
    HANDLE pipe = CreateFileA("\\\\.\\pipe\\RobloxExecutor",
                              GENERIC_READ | GENERIC_WRITE, 0, NULL,
                              OPEN_EXISTING, 0, NULL);
    if (pipe == INVALID_HANDLE_VALUE) return "";
    DWORD mode = PIPE_READMODE_MESSAGE;
    SetNamedPipeHandleState(pipe, &mode, NULL, NULL);
    DWORD written = 0;
    WriteFile(pipe, cmd.data(), (DWORD)cmd.size(), &written, NULL);
    char buf[8192] = {0};
    DWORD read = 0;
    ReadFile(pipe, buf, sizeof(buf) - 1, &read, NULL);
    CloseHandle(pipe);
    return buf;
}

// attach one pid (inject + verify via ping)
static void attachPid(DWORD pid)
{
    for (DWORD done : gPidsInjected)
        if (done == pid) return;

    static const wchar_t* kDll = L"C:\\RobloxExecutor\\executor.dll";
    if (!injectDll(pid, kDll)) {
        char line[160];
        wsprintfA(line, "[!] PID %lu inject failed (run as admin?)", pid);
        logLine(line);
        return;
    }
    Sleep(500);
    std::string r = pipeRequest("ping");
    if (!r.empty()) {
        std::string vm = pipeRequest("info");
        logLine("[+] attached PID " + std::to_string(pid) + "  (" + r + ")");
        if (!vm.empty()) {
            std::string vm2 = vm;
            size_t nl2 = vm2.find('\n');
            if (nl2 != std::string::npos) vm2.erase(nl2);
            logLine("[*] vm: " + vm2);
        }
        gAttached = true;
        gPidsInjected.push_back(pid);
        setStatus("attached - " + std::to_string(pid), GOLD);
    } else {
        logLine("[!] PID " + std::to_string(pid) + ": pipe silent (VM unresolved?)");
    }
}

// one-shot: find all roblox procs, attach each
static void doAttachNow()
{
    std::vector<DWORD> pids = findPids(L"RobloxPlayerBeta.exe");
    if (pids.empty()) {
        logLine("[!] RobloxPlayerBeta.exe not running — waiting...");
        return;
    }
    for (DWORD pid : pids) attachPid(pid);
}

// background watcher: auto-attach on spawn
static DWORD WINAPI autoAttachThread(LPVOID)
{
    for (;;) {
        if (gAutoAttach) {
            std::vector<DWORD> pids = findPids(L"RobloxPlayerBeta.exe");
            for (DWORD pid : pids) {
                bool done = false;
                for (DWORD d : gPidsInjected)
                    if (d == pid) { done = true; break; }
                if (!done) attachPid(pid);
            }
        }
        Sleep(1500);
    }
    return 0;
}

// ---------------- http (WinHTTP, https) ----------------
static bool httpGetText(const std::wstring& url, std::string& out)
{
    bool secure = url.compare(0, 8, L"https://") == 0;
    size_t host0 = url.find(L"://") + 3;
    size_t host1 = url.find_first_of(L"/", host0);
    std::wstring host = url.substr(host0, host1 - host0);
    std::wstring path = (host1 == std::wstring::npos)
                        ? L"/" : url.substr(host1);

    HINTERNET h = WinHttpOpen(L"RobloxExecutor/2.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                              WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if (!h) return false;
    HINTERNET c = WinHttpConnect(h, host.c_str(),
                                 secure ? INTERNET_DEFAULT_HTTPS_PORT : INTERNET_DEFAULT_HTTP_PORT, 0);
    if (!c) { WinHttpCloseHandle(h); return false; }
    HINTERNET req = WinHttpOpenRequest(c, L"GET", path.c_str(), NULL,
                                       WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
                                       secure ? WINHTTP_FLAG_SECURE : 0);
    if (!req) { WinHttpCloseHandle(c); WinHttpCloseHandle(h); return false; }

    bool ok = WinHttpSendRequest(req, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
                                 WINHTTP_NO_REQUEST_DATA, 0, 0, 0) &&
              WinHttpReceiveResponse(req, NULL);
    out.clear();
    if (ok) {
        DWORD avail = 0, total = 0, read = 0;
        do {
            if (!WinHttpQueryDataAvailable(req, &avail)) break;
            std::vector<char> buf(avail + 1);
            if (!WinHttpReadData(req, &buf[0], avail, &read)) break;
            if (read == 0) break;
            out.append(buf.data(), read);
        } while (avail > 0);
    }
    WinHttpCloseHandle(req);
    WinHttpCloseHandle(c);
    WinHttpCloseHandle(h);
    return ok && !out.empty();
}

// parse a plain list: name<TAB>url per line (or name<SPACE>url)
static void parseHubText(const std::string& text, std::vector<Hub>& out)
{
    size_t pos = 0;
    while (pos < text.size()) {
        size_t nl = text.find('\n', pos);
        std::string line = text.substr(pos, nl == std::string::npos
                                        ? std::string::npos : nl - pos);
        pos = (nl == std::string::npos) ? text.size() : nl + 1;
        if (line.empty() || line[0] == '#') continue;
        size_t tab = line.find('\t');
        if (tab == std::string::npos) tab = line.find(' ');
        if (tab == std::string::npos) continue;
        Hub h;
        h.name = line.substr(0, tab);
        h.url  = line.substr(tab + 1);
        out.push_back(h);
    }
}

// ---------------- script hub ----------------
static void loadLocalStash()
{
    std::string dir = gExeDir + "\\..\\scripts";
    WIN32_FIND_DATAA fd;
    HANDLE f = FindFirstFileA((dir + "\\*.lua").c_str(), &fd);
    if (f == INVALID_HANDLE_VALUE) return;
    do {
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) continue;
        Hub h;
        h.name = fd.cFileName;
        h.url  = std::string();   // local
        gScripts.push_back(h);
    } while (FindNextFileA(f, &fd));
    FindClose(f);
}

// background worker: read hub.txt, fetch its index, refresh grid
static void doFetchHub(const std::string& cfgPath)
{
    std::string url;
    HANDLE f = CreateFileA(cfgPath.c_str(), GENERIC_READ, FILE_SHARE_READ,
                           NULL, OPEN_EXISTING, 0, NULL);
    if (f != INVALID_HANDLE_VALUE) {
        char buf[1024] = {};
        DWORD rd = 0;
        ReadFile(f, buf, sizeof(buf) - 1, &rd, NULL);
        CloseHandle(f);
        std::string all(buf, rd);
        size_t nl = all.find('\n');
        url = all.substr(0, nl == std::string::npos ? all.size() : nl);
        // trim whitespace
        while (!url.empty() && (url[0] == ' ' || url[0] == '\r'))
            url.erase(0, 1);
    }
    if (url.empty()) { logLine("[!] hub.txt empty or missing"); return; }

    logLine("[*] fetching " + url);
    std::vector<Hub>* results = new std::vector<Hub>();
    std::string text;
    std::wstring wurl(url.begin(), url.end());
    if (httpGetText(wurl, text)) {
        parseHubText(text, *results);
    } else {
        logLine("[!] fetch failed (network / proxy / bad URL)");
    }
    PostMessageA(gMain, WM_APP_HUB, 0, (LPARAM)results);
}

// filter current gScripts by query, refresh list
static void searchScripts(const std::string& q)
{
    ListView_DeleteAllItems(gList);
    std::vector<Hub> idxCopy;
    { EnterCriticalSection(&gCs); idxCopy = gScripts; LeaveCriticalSection(&gCs); }

    std::string ql = q;
    std::transform(ql.begin(), ql.end(), ql.begin(), ::tolower);

    int row = 0;
    for (const Hub& h : idxCopy) {
        if (!ql.empty()) {
            std::string nl = h.name;
            std::transform(nl.begin(), nl.end(), nl.begin(), ::tolower);
            if (nl.find(ql) == std::string::npos) continue;
        }
        LVITEMA it = {};
        it.mask = LVIF_TEXT;
        it.iItem = row;
        it.pszText = (LPSTR)h.name.c_str();
        ListView_InsertItemA(gList, &it);
        ListView_SetItemTextA(gList, row, 1, (LPSTR)h.url.c_str());
        row++;
    }
}

// ---------------- execute path ----------------
static void doExecute()
{
    if (!gAttached) { logLine("[!] not attached"); return; }
    int len = GetWindowTextLengthA(gEdit);
    if (len == 0) return;
    std::string script(len, 0);
    GetWindowTextA(gEdit, &script[0], len + 1);

    logLine(">> " + script.substr(0, 80));
    std::string reply = pipeRequest("execute " + script);
    if (reply.empty()) logLine("[!] no reply (VM died?)");
    else logLine("<= " + reply);
}

static void loadScriptIntoEditor(const std::string& urlOrName)
{
    std::string content;
    // absolute path (drive colon or UNC)?
    bool isPath = urlOrName.find(':') != std::string::npos ||
                  urlOrName.compare(0, 2, "\\\\") == 0;
    std::string open_path = isPath
        ? urlOrName
        : gExeDir + "\\..\\scripts\\" + urlOrName;

    HANDLE f = CreateFileA(open_path.c_str(), GENERIC_READ, FILE_SHARE_READ,
                           NULL, OPEN_EXISTING, 0, NULL);
    if (f != INVALID_HANDLE_VALUE) {
        DWORD sz = GetFileSize(f, NULL);
        std::vector<char> buf(sz + 1);
        DWORD rd = 0;
        ReadFile(f, &buf[0], sz, &rd, NULL);
        CloseHandle(f);
        content.assign(buf.data(), rd);
    } else if (urlOrName.compare(0, 4, "http") == 0) {
        httpGetText(ws2s(std::wstring(urlOrName.begin(), urlOrName.end())), content);
    } else {
        // treat as direct loadstring-style name from hub
        logLine("[!] no file and no URL for: " + urlOrName);
        return;
    }
    if (!content.empty()) {
        SetWindowTextA(gEdit, content.c_str());
        logLine("[*] loaded " + urlOrName + " (" + std::to_string(content.size()) + " b)");
    }
}

static void loadSelected()
{
    int sel = ListView_GetNextItem(gList, -1, LVNI_SELECTED);
    if (sel < 0) { logLine("[!] pick a script"); return; }
    char name[512]; char url[1024];
    ListView_GetItemTextA(gList, sel, 0, name, sizeof(name));
    ListView_GetItemTextA(gList, sel, 1, url, sizeof(url));
    std::string target = (url[0]) ? url : name;
    loadScriptIntoEditor(target);
}

static void openScriptFile()
{
    OPENFILENAMEA ofn = {};
    char file[MAX_PATH] = {};
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = gMain;
    ofn.lpstrFilter = "Lua scripts\0*.lua\0All files\0*.*\0";
    ofn.lpstrFile = file;
    ofn.nMaxFile = MAX_PATH;
    if (GetOpenFileNameA(&ofn)) {
        HANDLE f = CreateFileA(file, GENERIC_READ, FILE_SHARE_READ,
                               NULL, OPEN_EXISTING, 0, NULL);
        if (f != INVALID_HANDLE_VALUE) {
            DWORD sz = GetFileSize(f, NULL);
            std::vector<char> buf(sz + 1);
            DWORD rd = 0;
            ReadFile(f, &buf[0], sz, &rd, NULL);
            CloseHandle(f);
            SetWindowTextA(gEdit, std::string(buf.data(), rd).c_str());
            logLine(std::string("[*] opened ") + file);
        }
    }
}

// ---------------- UI construction ----------------
static HWND makeButton(HWND parent, const char* text, int id, int x, int y, int w, int h)
{
    return CreateWindowA("BUTTON", text, WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                         x, y, w, h, parent, (HMENU)(INT_PTR)id, gHInst, NULL);
}
static HWND makeStatic(HWND parent, const char* text, int x, int y, int w, int h)
{
    return CreateWindowA("STATIC", text, WS_CHILD | WS_VISIBLE | SS_LEFT,
                         x, y, w, h, parent, NULL, gHInst, NULL);
}

static void buildExecTab(HWND parent)
{
    gBtnAttach = makeButton(parent, "Attach", 1, 16, 88, 90, 30);
    gBtnAuto   = makeButton(parent, "Auto: ON", 4, 112, 88, 90, 30);
    gBtnExec   = makeButton(parent, "Execute  (Ctrl+Enter)", 2, 208, 88, 180, 30);
    gBtnClear  = makeButton(parent, "Clear Log", 3, 396, 88, 90, 30);

    gStatText = CreateWindowA("STATIC", "detached",
                              WS_CHILD | WS_VISIBLE | SS_RIGHT,
                              500, 94, 190, 20, parent, NULL, gHInst, NULL);
    SendMessageA(gStatText, WM_SETFONT, (WPARAM)gFontHead, TRUE);

    gEdit = CreateWindowExA(WS_EX_CLIENTEDGE, "EDIT", "",
                            WS_CHILD | WS_VISIBLE | WS_BORDER | ES_MULTILINE |
                            ES_AUTOVSCROLL | WS_VSCROLL | ES_LEFT,
                            16, 126, 674, 300, parent, NULL, gHInst, NULL);
    SendMessageA(gEdit, WM_SETFONT, (WPARAM)gFontMono, TRUE);

    gLabelConsole = makeStatic(parent, "CONSOLE", 16, 434, 200, 16);
    gLog = CreateWindowExA(WS_EX_CLIENTEDGE, "EDIT", "",
                           WS_CHILD | WS_VISIBLE | WS_BORDER | ES_MULTILINE |
                           ES_AUTOVSCROLL | WS_VSCROLL | ES_READONLY | ES_LEFT,
                           16, 452, 674, 190, parent, NULL, gHInst, NULL);
    SendMessageA(gLog, WM_SETFONT, (WPARAM)gFontMono, TRUE);
    logLine("robx-exec v2. hit Attach. auto-attach defaults ON.");
}

static void buildHubTab(HWND parent)
{
    gLabelSearch = makeStatic(parent, "Search:", 16, 88, 60, 20);
    gSearchEdit = CreateWindowExA(WS_EX_CLIENTEDGE, "EDIT", "",
                                  WS_CHILD | WS_VISIBLE | WS_BORDER,
                                  76, 86, 320, 22, parent, NULL, gHInst, NULL);
    SendMessageA(gSearchEdit, WM_SETFONT, (WPARAM)gFontUi, TRUE);
    gBtnSearch = makeButton(parent, "Search", 5, 404, 86, 80, 24);
    gBtnFetch  = makeButton(parent, "Fetch hub.txt", 6, 492, 86, 130, 24);

    gList = CreateWindowExA(WS_EX_CLIENTEDGE, WC_LISTVIEWA, "",
                            WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL |
                            LVS_SHOWSELALWAYS,
                            16, 120, 606, 330, parent, NULL, gHInst, NULL);
    ListView_SetExtendedListViewStyle(gList, LVS_EX_FULLROWSELECT |
                                      LVS_EX_GRIDLINES);
    LVCOLUMNA col = {};
    col.mask = LVCF_TEXT | LVCF_WIDTH;
    col.pszText = (LPSTR)"Name";   col.cx = 240; ListView_InsertColumnA(gList, 0, &col);
    col.pszText = (LPSTR)"Source"; col.cx = 340; ListView_InsertColumnA(gList, 1, &col);

    gBtnLoad = makeButton(parent, "Load -> editor", 7, 16, 460, 150, 28);
    gBtnOpenFile = makeButton(parent, "Open .lua file...", 8, 176, 460, 160, 28);
    gLabelHint = makeStatic(parent, "Shows: local ..\\scripts\\*.lua  +  hub.txt index. "
                       "Fetch pulls a remote list into the grid.", 16, 498, 576, 30);
}

static void refreshHubGrid()
{
    std::string q(128, 0);
    GetWindowTextA(gSearchEdit, &q[0], 128);
    searchScripts(q.c_str());
}

// ---------------- wndproc ----------------
static LRESULT CALLBACK wndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp)
{
    switch (msg) {
    case WM_CREATE: {
        gFontTitle = CreateFontA(22, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                                 DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                                 CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                                 DEFAULT_PITCH, "Segoe UI");
        gFontHead = CreateFontA(16, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                                DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                                CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                                DEFAULT_PITCH, "Segoe UI");
        gFontUi = CreateFontA(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                              DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                              CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                              DEFAULT_PITCH, "Segoe UI");
        gFontMono = CreateFontA(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                                DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                                CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                                FIXED_PITCH, "Consolas");
        gBrushBg = CreateSolidBrush(BG_DARK);
        gBrushPanel = CreateSolidBrush(BG_PANEL);
        gBrushEdit = CreateSolidBrush(EDIT_BG);

        // title header
        HWND title = makeStatic(hwnd, "ROBLOX EXECUTOR v2", 16, 10, 320, 28);
        SendMessageA(title, WM_SETFONT, (WPARAM)gFontTitle, TRUE);
        HWND sub = makeStatic(hwnd, "attach  /  execute  /  script hub  /  auto-bite",
                              16, 40, 420, 16);
        SendMessageA(sub, WM_SETFONT, (WPARAM)gFontUi, TRUE);

        // tabs
        gTab = CreateWindowA(WC_TABCONTROLA, "", WS_CHILD | WS_VISIBLE | TCS_FIXEDWIDTH,
                             10, 62, 700, 26, hwnd, NULL, gHInst, NULL);
        SendMessageA(gTab, WM_SETFONT, (WPARAM)gFontUi, TRUE);
        TCITEMA ti = {};
        ti.mask = TCIF_TEXT;
        ti.pszText = (LPSTR)"Execute";
        SendMessageA(gTab, TCM_INSERTITEMA, 0, (LPARAM)&ti);
        ti.pszText = (LPSTR)"Script Hub";
        SendMessageA(gTab, TCM_INSERTITEMA, 1, (LPARAM)&ti);

        // tab pages (children of main; toggled via show/hide)
        HWND execParent = hwnd;
        HWND hubParent  = hwnd;
        buildExecTab(execParent);
        // hub children get offset by tab bar
        buildHubTab(hubParent);
        ShowWindow(gBtnSearch, SW_HIDE);
        ShowWindow(gBtnFetch, SW_HIDE);
        ShowWindow(gSearchEdit, SW_HIDE);
        ShowWindow(gList, SW_HIDE);
        ShowWindow(gBtnLoad, SW_HIDE);
        ShowWindow(gBtnOpenFile, SW_HIDE);

        DragAcceptFiles(hwnd, TRUE);
        InitializeCriticalSection(&gCs);
        loadLocalStash();
        CreateThread(NULL, 0, autoAttachThread, NULL, 0, NULL);
        return 0;
    }
    case WM_NOTIFY: {
        NMHDR* h = (NMHDR*)lp;
        if (h->idFrom == (UINT_PTR)gTab && h->code == TCN_SELCHANGE) {
            int sel = TabCtrl_GetCurSel(gTab);
            // exec
            ShowWindow(gBtnAttach, sel == 0 ? SW_SHOW : SW_HIDE);
            ShowWindow(gBtnAuto,   sel == 0 ? SW_SHOW : SW_HIDE);
            ShowWindow(gBtnExec,   sel == 0 ? SW_SHOW : SW_HIDE);
            ShowWindow(gBtnClear,  sel == 0 ? SW_SHOW : SW_HIDE);
            ShowWindow(gStatText,  sel == 0 ? SW_SHOW : SW_HIDE);
            ShowWindow(gEdit,      sel == 0 ? SW_SHOW : SW_HIDE);
            ShowWindow(gLog,       sel == 0 ? SW_SHOW : SW_HIDE);
            ShowWindow(gLabelConsole, sel == 0 ? SW_SHOW : SW_HIDE);
            ShowWindow(gLabelSearch,  sel == 1 ? SW_SHOW : SW_HIDE);
            ShowWindow(gLabelHint,    sel == 1 ? SW_SHOW : SW_HIDE);
            // hub
            ShowWindow(gSearchEdit, sel == 1 ? SW_SHOW : SW_HIDE);
            ShowWindow(gBtnSearch,  sel == 1 ? SW_SHOW : SW_HIDE);
            ShowWindow(gBtnFetch,   sel == 1 ? SW_SHOW : SW_HIDE);
            ShowWindow(gList,       sel == 1 ? SW_SHOW : SW_HIDE);
            ShowWindow(gBtnLoad,    sel == 1 ? SW_SHOW : SW_HIDE);
            ShowWindow(gBtnOpenFile, sel == 1 ? SW_SHOW : SW_HIDE);
            if (sel == 1) refreshHubGrid();
        }
        break;
    }
    case WM_DROPFILES: {
        HDROP hd = (HDROP)wp;
        wchar_t file[MAX_PATH];
        DragQueryFileW(hd, 0, file, MAX_PATH);
        DragFinish(hd);
        loadScriptIntoEditor(ws2s(file));
        return 0;
    }
    case WM_APP_HUB: {
        std::vector<Hub>* got = (std::vector<Hub>*)lp;
        { EnterCriticalSection(&gCs);
          for (const Hub& h : *got) gScripts.push_back(h);
          LeaveCriticalSection(&gCs); }
        delete got;
        logLine("[+] hub refreshed (" + std::to_string(gScripts.size()) + " scripts)");
        refreshHubGrid();
        return 0;
    }
    case WM_ERASEBKGND: {
        HDC dc = (HDC)wp;
        RECT rc; GetClientRect(hwnd, &rc);
        FillRect(dc, &rc, gBrushBg);
        return 1;
    }
    case WM_CTLCOLORSTATIC:
    case WM_CTLCOLORBTN: {
        HDC dc = (HDC)wp;
        SetBkColor(dc, BG_PANEL);
        SetTextColor(dc, TEXT_MAIN);
        return (LRESULT)gBrushPanel;
    }
    case WM_CTLCOLOREDIT: {
        HDC dc = (HDC)wp;
        SetBkColor(dc, EDIT_BG);
        SetTextColor(dc, TEXT_MAIN);
        return (LRESULT)gBrushEdit;
    }
    case WM_COMMAND:
        switch (LOWORD(wp)) {
        case 1: doAttachNow(); break;
        case 2: doExecute();   break;
        case 3: { gLogText.clear();
                  SetWindowTextA(gLog, ""); break; }
        case 4: gAutoAttach = !gAutoAttach;
                SetWindowTextA(gBtnAuto, gAutoAttach ? "Auto: ON" : "Auto: OFF");
                break;
        case 5: { std::string q(256, 0);
                  GetWindowTextA(gSearchEdit, &q[0], 256);
                  searchScripts(q.c_str()); break; }
        case 6: doFetchHub(gExeDir + "\\..\\hub.txt"); break;
        case 7: loadSelected();   break;
        case 8: openScriptFile(); break;
        }
        return 0;
    case WM_KEYDOWN:
        if (wp == VK_RETURN && (GetKeyState(VK_CONTROL) & 0x8000)) {
            doExecute();
            return 0;
        }
        break;
    case WM_DESTROY:
        DeleteCriticalSection(&gCs);
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcA(hwnd, msg, wp, lp);
}

// tab pages: helpers to find children of exec/hub parents
// (simplified: all children are on main; show/hide handled in WM_NOTIFY)

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE, LPSTR, int)
{
    gHInst = hInst;
    getExeDir();

    INITCOMMONCONTROLSEX icc = {};
    icc.dwSize = sizeof(icc);
    icc.dwICC = ICC_WIN95_CLASSES | ICC_LISTVIEW_CLASSES | ICC_TAB_CLASSES;
    InitCommonControlsEx(&icc);

    WNDCLASSA wc = {};
    wc.lpfnWndProc = wndProc;
    wc.hInstance = hInst;
    wc.hCursor = LoadCursorA(NULL, (LPCSTR)IDC_ARROW);
    wc.hbrBackground = (HBRUSH)GetStockObject(NULL_BRUSH);
    wc.lpszClassName = "RobloxExecutorGUI";
    RegisterClassA(&wc);

    gMain = CreateWindowExA(0, "RobloxExecutorGUI", "Roblox Executor v2",
                            WS_OVERLAPPEDWINDOW,
                            CW_USEDEFAULT, CW_USEDEFAULT, 716, 690,
                            NULL, NULL, hInst, NULL);
    if (!gMain) return 1;
    ShowWindow(gMain, SW_SHOW);
    UpdateWindow(gMain);

    MSG msg;
    while (GetMessageA(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }
    return (int)msg.wParam;
}