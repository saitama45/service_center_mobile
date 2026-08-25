# start_emulator.ps1
# Launches Pixel_6_API_35 and guarantees working internet before handing back
# control. Always launch the emulator through this script, not Android
# Studio's Device Manager play button — that skips the -dns-server flag and
# this fix never gets a chance to run. See docs/knowledge/Decisions.md and
# the "Emulator DNS breaks" note in Claude's project memory for the full
# diagnosis.
#
# Run from PowerShell: .\start_emulator.ps1

$emulator = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"
$adb      = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$avd      = "Pixel_6_API_35"

function Wait-BootCompleted {
    $boot = ""
    while ($boot -ne "1") {
        Start-Sleep -Seconds 3
        $boot = (& $adb shell getprop sys.boot_completed 2>&1).Trim()
    }
}

# QEMU's user-mode NAT maps the emulator's DNS proxy (10.0.2.3) to the
# host's *first* configured DNS server, which on this machine doesn't
# answer — and even the "correct" resolver at 10.0.2.3 has been observed to
# stop responding after ~15 minutes regardless. The durable fix is to
# transparently rewrite every DNS request bound for 10.0.2.3 to a public
# resolver instead, bypassing the flaky proxy entirely. `setprop net.dns*`
# is a dead end: Android 15 ignores it.
function Set-DnsRedirect {
    & $adb root | Out-Null
    Start-Sleep -Seconds 2
    & $adb wait-for-device
    Wait-BootCompleted

    foreach ($proto in @("udp", "tcp")) {
        $check = & $adb shell "iptables -t nat -C OUTPUT -p $proto -d 10.0.2.3 --dport 53 -j DNAT --to-destination 8.8.8.8:53" 2>&1
        if ($LASTEXITCODE -ne 0) {
            & $adb shell "iptables -t nat -A OUTPUT -p $proto -d 10.0.2.3 --dport 53 -j DNAT --to-destination 8.8.8.8:53" 2>&1 | Out-Null
        }
    }
}

# DNS resolution fails as "unknown host"; the ICMP echo itself always times
# out under QEMU's NAT even when DNS is fine, so only the resolution error
# text tells us anything — never treat ping's silence as proof of no
# internet.
function Test-DnsWorks {
    $out = & $adb shell "ping -c 1 -W 2 google.com" 2>&1
    return -not ($out -match "unknown host|bad address|Name or service not known")
}

Write-Host "[1/4] Starting emulator $avd ..."
Start-Process -FilePath $emulator -ArgumentList "-avd $avd -dns-server 8.8.8.8,8.8.4.4"

Write-Host "[2/4] Waiting for emulator to appear in adb ..."
do { Start-Sleep -Seconds 3 } until ((& $adb devices) -match "emulator")

Write-Host "[3/4] Waiting for Android boot to complete ..."
Wait-BootCompleted
Write-Host "       Boot complete."

Write-Host "[4/4] Redirecting DNS to 8.8.8.8 (bypassing QEMU's proxy) ..."
Set-DnsRedirect

if (Test-DnsWorks) {
    Write-Host ""
    Write-Host "Emulator is ready with working internet."
} else {
    Write-Host "       First attempt didn't take — retrying once ..."
    Start-Sleep -Seconds 3
    Set-DnsRedirect
    if (Test-DnsWorks) {
        Write-Host ""
        Write-Host "Emulator is ready with working internet."
    } else {
        Write-Host ""
        Write-Host "WARNING: DNS still not resolving after two attempts." -ForegroundColor Yellow
        Write-Host "Run this script again, or diagnose manually:" -ForegroundColor Yellow
        Write-Host "  $adb shell `"ping -c 1 -W 2 google.com`"" -ForegroundColor Yellow
    }
}

Write-Host "Run:  flutter run"
