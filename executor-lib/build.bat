@echo off
rem Builds executor.dll (x64, Release). Requires VS2022 Build Tools.
setlocal

call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" 2>nul
if errorlevel 1 call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

if not defined VSCMD_ARG_TGT_ARCH (
    echo [!] vcvars not found. Install VS2022 Build Tools with C++ workload.
    exit /b 1
)

if not exist "x64\Release" mkdir "x64\Release"
cl /nologo /O2 /EHsc /LD /Fe:x64\Release\executor.dll dllmain.cpp /link /DEF:executor.def >nul
echo [+] Built x64\Release\executor.dll
endlocal