$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ESC = [char]27
$GREEN  = "${ESC}[92m"
$RED    = "${ESC}[91m"
$CYAN   = "${ESC}[96m"
$BOLD   = "${ESC}[1m"
$NC     = "${ESC}[0m"

function Show-Logo {
    $logoUrl = "https://raw.githubusercontent.com/kairoooo-dev/krux-executor/master/gui-dotnet/KruxLogo.jpg"
    $tmpLogo = Join-Path $env:TEMP "krux_banner.jpg"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "KRUX")
        $wc.DownloadFile($logoUrl, $tmpLogo)

        Add-Type -AssemblyName System.Drawing
        $img = [System.Drawing.Bitmap]::FromFile($tmpLogo)
        $w = 56
        $h = [math]::Floor($img.Height * ($w / $img.Width) * 0.45)
        $resized = New-Object System.Drawing.Bitmap($img, $w, $h)

        Write-Host ""
        for ($y = 0; $y -lt $resized.Height; $y++) {
            $line = ""
            for ($x = 0; $x -lt $resized.Width; $x++) {
                $px = $resized.GetPixel($x, $y)
                $r = $px.R; $g = $px.G; $b = $px.B
                $bright = ($r + $g + $b) / 3
                if ($bright -lt 25) {
                    $line += " "
                } else {
                    $line += "${ESC}[38;2;${r};${g};${b}m${ESC}[48;2;${r};${g};${b}m  ${NC}"
                }
            }
            Write-Host $line
        }
        $resized.Dispose()
        $img.Dispose()
    } catch {
        Write-Host "${BOLD}${CYAN}"
        @"

       KKKKKKKKKKKKKKK   RRRRRRRRRRRRRRRRR   UUUUUUUUUUU   XXXXXXXXX
       KKKKKKKKKKKKKKK   RRRRRRRRRRRRRRRRR   UUUUUUUUUUU   XXXXXXXXX
       KKKKKK            RRRRRR    RRRRRR    UUUUUUUUUUU   XXXXXXXXX
       KKKKKK            RRRRRR    RRRRRR    UUUU   UUUU   XXXXXXXXX
       KKKKKK            RRRRRRRRRRRRRRR     UUU    UUUU   XXXXXXXXX
       KKKKKK            RRRRRR    RRRRR      UUUUUUUUUU   XXXXXXXXX
       KKKKKKKKKKKKKKK   RRRRRR    RRRRR       UUUUUUUUU   XXXXXXXXX
       KKKKKKKKKKKKKKK   RRRRRR    RRRRR        UUUUUUUU   XXXXXXXXX

"@ | Write-Host
    } finally {
        if (Test-Path $tmpLogo) { Remove-Item $tmpLogo -Force -ErrorAction SilentlyContinue }
    }
    Write-Host "${NC}"
    Write-Host "${BOLD}${CYAN}            ##%%@@%%##   K R U X   ##%%@@%%##${NC}"
    Write-Host ""
    Write-Host "${CYAN}    ================================================================${NC}"
    Write-Host "${CYAN}                   KRUX Executor Installer v3.0${NC}"
    Write-Host "${CYAN}    ================================================================${NC}"
    Write-Host ""
}

function Show-Bar {
    param([int]$Pct, [long]$Downloaded, [long]$Total)
    $filled = [math]::Floor($Pct / 2)
    $empty = 50 - $filled
    $bar = ("$" * $filled) + ("-" * $empty)
    $curMB = [math]::Round($Downloaded / 1MB, 1)
    $totalMB = [math]::Round($Total / 1MB, 1)
    Write-Host -NoNewline "`r    [$bar] $Pct%  $curMB/$totalMB MB"
}

# ═══ MAIN ═══
Clear-Host
Show-Logo

Write-Host "${CYAN}[~]${NC} Checking for updates..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$r = Invoke-RestMethod -Uri "https://api.github.com/repos/kairoooo-dev/krux-executor/releases/latest" -UseBasicParsing
$a = $r.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
$a2 = $r.assets | Where-Object { $_.name -like "Xeno.dll" } | Select-Object -First 1
if (-not $a) { Write-Host "${RED}[-] No exe found${NC}"; exit 1 }

$d = Join-Path $env:LOCALAPPDATA KRUX
New-Item -ItemType Directory -Path $d -Force | Out-Null
$f = Join-Path $env:TEMP "KruxExecutor.exe"
$f2 = Join-Path $env:TEMP "Xeno.dll"

Write-Host "${CYAN}[~]${NC} Version: $($r.tag_name)"
Write-Host "${CYAN}[~]${NC} Exe: $([math]::Round($a.size/1MB,1)) MB  DLL: $([math]::Round($a2.size/1KB,0)) KB"
Write-Host ""
Write-Host "${CYAN}[~]${NC} Downloading exe..."
Write-Host ""

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "KRUX")
$Global:totalBytes = $a.size
$Global:currentPct = 0
$Global:currentBytes = 0

$ev = Register-ObjectEvent -InputObject $wc -EventName DownloadProgressChanged -Action {
    $Global:currentPct = $Event.SourceEventArgs.ProgressPercentage
    $Global:currentBytes = [long]$Event.SourceEventArgs.ProgressPercentage * $Global:totalBytes / 100
}

$job = Start-Job -ScriptBlock {
    param($url, $out)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "KRUX")
    $wc.DownloadFile($url, $out)
} -ArgumentList $a.browser_download_url, $f

while ($job.State -eq "Running") {
    Show-Bar -Pct $Global:currentPct -Downloaded $Global:currentBytes -Total $a.size
    Start-Sleep -Milliseconds 200
}

Unregister-Event -SourceIdentifier $ev -ErrorAction SilentlyContinue
Show-Bar -Pct 100 -Downloaded $a.size -Total $a.size
Write-Host ""
Write-Host ""

if ($job.JobStateInfo.State -eq "Failed") {
    Write-Host "${RED}[-] Download failed${NC}"
    exit 1
}

Write-Host ""
Write-Host "${GREEN}[+] Download complete!${NC}"

# Download executor.dll
if ($a2) {
    Write-Host ""
    Write-Host "${CYAN}[~]${NC} Downloading Xeno.dll..."
    try {
        $wc2 = New-Object System.Net.WebClient
        $wc2.Headers.Add("User-Agent", "KRUX")
        $wc2.DownloadFile($a2.browser_download_url, $f2)
        Write-Host "${GREEN}[+] Xeno.dll downloaded!${NC}"
    } catch {
        Write-Host "${RED}[-] Failed to download Xeno.dll: $_${NC}"
    }
}

# Xeno engine runtime DLLs (MinGW, required next to Xeno.dll)
$runtimeDlls = @("libwinpthread-1.dll")
foreach ($dllName in $runtimeDlls) {
    $ra = $r.assets | Where-Object { $_.name -eq $dllName } | Select-Object -First 1
    if ($ra) {
        $rf = Join-Path $env:TEMP $dllName
        try {
            $wcx = New-Object System.Net.WebClient
            $wcx.Headers.Add("User-Agent", "KRUX")
            $wcx.DownloadFile($ra.browser_download_url, $rf)
            Copy-Item $rf (Join-Path $d $dllName) -Force
            Remove-Item $rf -Force -ErrorAction SilentlyContinue
            Write-Host "${GREEN}[+] $dllName installed!${NC}"
        } catch {
            Write-Host "${RED}[-] Failed to download $dllName (KRUX will crash on Attach without it): $_${NC}"
        }
    } else {
        Write-Host "${RED}[-] Release has no $dllName asset${NC}"
    }
}

# Install
Copy-Item $f (Join-Path $d "KruxExecutor.exe") -Force
Remove-Item $f -Force -ErrorAction SilentlyContinue
if (Test-Path $f2) {
    Copy-Item $f2 (Join-Path $d "Xeno.dll") -Force
    Remove-Item $f2 -Force -ErrorAction SilentlyContinue
}

# Desktop shortcut
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\KRUX Executor.lnk")
$lnk.TargetPath = Join-Path $d "KruxExecutor.exe"
$lnk.WorkingDirectory = $d
$lnk.Description = "KRUX Executor"
$lnk.Save()

# Start Menu shortcut
$lnk2 = $shell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk")
$lnk2.TargetPath = Join-Path $d "KruxExecutor.exe"
$lnk2.WorkingDirectory = $d
$lnk2.Description = "KRUX Executor"
$lnk2.Save()

Write-Host ""
Write-Host "${GREEN}[+] Installed to $d${NC}"
Write-Host "${GREEN}[+] Desktop shortcut created${NC}"
Write-Host "${GREEN}[+] Start Menu shortcut created${NC}"
Write-Host ""
Write-Host "${CYAN}[~]${NC} Starting KRUX..."
Start-Process (Join-Path $d "KruxExecutor.exe")
