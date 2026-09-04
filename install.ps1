$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ESC = [char]27
$GREEN  = "${ESC}[92m"
$RED    = "${ESC}[91m"
$CYAN   = "${ESC}[96m"
$BOLD   = "${ESC}[1m"
$NC     = "${ESC}[0m"

function Show-Logo {
    Write-Host "${NC}"
    Write-Host "${BOLD}${CYAN}            ##%%@@%%##   K R U X   ##%%@@%%##${NC}"
    Write-Host ""
    Write-Host "${CYAN}    ================================================================${NC}"
    Write-Host "${CYAN}                   KRUX Executor Installer v3.3${NC}"
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
$zipAsset = $r.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
if (-not $zipAsset) { Write-Host "${RED}[-] No zip found in release${NC}"; exit 1 }

$d = Join-Path $env:LOCALAPPDATA KRUX
New-Item -ItemType Directory -Path $d -Force | Out-Null
$zipPath = Join-Path $env:TEMP "KRUX.zip"

Write-Host "${CYAN}[~]${NC} Version: $($r.tag_name)"
Write-Host "${CYAN}[~]${NC} Downloading KRUX.zip ($([math]::Round($zipAsset.size/1MB,1)) MB)..."
Write-Host ""

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "KRUX")
$Global:totalBytes = $zipAsset.size
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
} -ArgumentList $zipAsset.browser_download_url, $zipPath

while ($job.State -eq "Running") {
    Show-Bar -Pct $Global:currentPct -Downloaded $Global:currentBytes -Total $zipAsset.size
    Start-Sleep -Milliseconds 200
}

Unregister-Event -SourceIdentifier $ev -ErrorAction SilentlyContinue
Show-Bar -Pct 100 -Downloaded $zipAsset.size -Total $zipAsset.size
Write-Host ""
Write-Host ""

if ($job.JobStateInfo.State -eq "Failed") {
    Write-Host "${RED}[-] Download failed${NC}"
    exit 1
}

Write-Host "${GREEN}[+] Download complete!${NC}"
Write-Host ""

# Extract zip
Write-Host "${CYAN}[~]${NC} Extracting..."
Expand-Archive -Path $zipPath -DestinationPath $d -Force
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

# Deploy UNC compat layer to Xeno autoexec (runs on every attach)
$compatSrc = Join-Path $d "00_krux_compat.lua"
if (Test-Path $compatSrc) {
    $axDir = Join-Path $env:LOCALAPPDATA "Xeno\autoexec"
    New-Item -ItemType Directory -Path $axDir -Force | Out-Null
    Copy-Item $compatSrc (Join-Path $axDir "00_krux_compat.lua") -Force
    Remove-Item $compatSrc -Force -ErrorAction SilentlyContinue
    Write-Host "${GREEN}[+] UNC compat layer deployed${NC}"
}

Write-Host "${GREEN}[+] Extracted to $d${NC}"



# License activation (offline RSA check, key from Discord/admin)
$modB64 = "rAQjwctuyoc6eSGdxmTNs1xyIWwXGgx2gWoFl+kspuAt5uXMC6c42u7VON4TqFxwHYju/9kkv/W36/V2FZQuuI/qwp7+3TGaGMNHcQhBkHflYpMWO6ajXrgbtvVQMwkPDPAhd3BwZgGC3mU8fTk1kVmYhyf+3RsSuLo9KEcVXrPKtpxbCgW12lfGOyowXNxDq+wcFGkTBBB9HssGWEONBAXMf1+fOSnzkicWO1itm1/zrQwt4js7u+j9plOzLEbDyjvzCNZmUIxc86i9DQPzOTlheri35Q2UFTEqjClvUt9dlrxH2tGs6mX+vcoeF9jHJZBxtqIJbZsUJUPw7rT0aQ=="
$expB64 = "AQAB"
function Test-KruxLicense {
    param([string]$Key)
    try {
        $p = $Key.Trim().Split('.')
        if ($p.Count -ne 4 -or $p[0] -ne 'KRUX1') { return $false }
        $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider
        $rp = New-Object System.Security.Cryptography.RSAParameters
        $rp.Modulus = [Convert]::FromBase64String($modB64)
        $rp.Exponent = [Convert]::FromBase64String($expB64)
        $rsa.ImportParameters($rp)
        $data = [Text.Encoding]::ASCII.GetBytes($p[1] + '.' + $p[2])
        if (-not $rsa.VerifyData($data, "SHA256", [Convert]::FromBase64String($p[3]))) { return $false }
        return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt [long]$p[2]
    } catch { return $false }
}
Write-Host ""
do {
    $lkey = Read-Host "License key (get one in Discord)"
    if (Test-KruxLicense $lkey) {
        Set-Content -Path (Join-Path $d 'license.dat') -Value $lkey.Trim() -NoNewline -Encoding Ascii
        Write-Host "${GREEN}[+] License activated${NC}"
        break
    }
    Write-Host "${RED}[-] Invalid or expired key, try again${NC}"
} while ($true)

# Desktop shortcut
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\KRUX Executor.lnk")
$lnk.TargetPath = Join-Path $d "KRUX.exe"
$lnk.WorkingDirectory = $d
$lnk.Description = "KRUX Executor"
$lnk.Save()

# Start Menu shortcut
$lnk2 = $shell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk")
$lnk2.TargetPath = Join-Path $d "KRUX.exe"
$lnk2.WorkingDirectory = $d
$lnk2.Description = "KRUX Executor"
$lnk2.Save()

Write-Host ""
Write-Host "${GREEN}[+] Installed to $d${NC}"
Write-Host "${GREEN}[+] Desktop shortcut created${NC}"
Write-Host "${GREEN}[+] Start Menu shortcut created${NC}"
Write-Host ""
Write-Host "${CYAN}[~]${NC} Starting KRUX..."
Start-Process (Join-Path $d "KRUX.exe")
