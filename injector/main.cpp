// injector\main.cpp
// Find RobloxPlayerBeta.exe and load executor.dll into it.
#include <windows.h>
#include <tlhelp32.h>
#include <iostream>
#include <string>

static DWORD findProc(const wchar_t* name)
{
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE)
        return 0;

    PROCESSENTRY32W pe;
    pe.dwSize = sizeof(pe);

    DWORD pid = 0;
    if (Process32FirstW(snap, &pe)) {
        do {
            if (_wcsicmp(pe.szExeFile, name) == 0) {
                pid = pe.th32ProcessID;
                break;
            }
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);
    return pid;
}

static bool inject(DWORD pid, const std::wstring& dllPath)
{
    HANDLE proc = OpenProcess(PROCESS_CREATE_THREAD |
                              PROCESS_VM_OPERATION |
                              PROCESS_VM_WRITE |
                              PROCESS_QUERY_INFORMATION, FALSE, pid);
    if (!proc)
        return false;

    size_t len = (dllPath.size() + 1) * sizeof(wchar_t);
    void* remote = VirtualAllocEx(proc, NULL, len,
                                  MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!remote) {
        CloseHandle(proc);
        return false;
    }

    SIZE_T written = 0;
    if (!WriteProcessMemory(proc, remote, dllPath.c_str(), len, &written)) {
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

int main(int argc, char** argv)
{
    std::wstring dll = L"C:\\RobloxExecutor\\executor.dll";
    if (argc >= 2) {
        std::string a = argv[1];
        dll.assign(a.begin(), a.end());
    }

    DWORD pid = findProc(L"RobloxPlayerBeta.exe");
    if (!pid) {
        std::cout << "[!] Roblox not running (RobloxPlayerBeta.exe).\n";
        return 1;
    }

    std::cout << "[*] Target PID: " << pid << "\n";
    if (inject(pid, dll))
        std::cout << "[+] Injected: " << dll << "\n";
    else
        std::cout << "[!] Injection failed.\n";
    return 0;
}