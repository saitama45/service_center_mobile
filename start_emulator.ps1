# start_emulator.ps1
# Launches Pixel_6_API_35 and automatically fixes DNS + default route.
# Run from PowerShell: .\start_emulator.ps1

$emulator = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"
$adb      = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$avd      = "Pixel_6_API_35"

Write-Host "[1/4] Starting emulator $avd ..."
Start-Process -FilePath $emulator -ArgumentList "-avd $avd -dns-server 8.8.8.8,8.8.4.4"

Write-Host "[2/4] Waiting for emulator to appear in adb ..."
do { Start-Sleep -Seconds 3 } until ((& $adb devices) -match "emulator")

Write-Host "[3/4] Waiting for Android boot to complete ..."
$boot = ""
while ($boot -ne "1") {
    Start-Sleep -Seconds 4
    $boot = (& $adb shell getprop sys.boot_completed 2>&1).Trim()
}
Write-Host "       Boot complete."

Write-Host "[4/4] Applying network fix (default route + DNS) ..."
& $adb shell ip route add default via 10.0.2.3 dev eth0 2>&1 | Out-Null
& $adb shell setprop net.dns1 8.8.8.8
& $adb shell setprop net.dns2 8.8.4.4

$dns = (& $adb shell getprop net.dns1).Trim()
Write-Host ""
Write-Host "Emulator is ready. DNS: $dns"
Write-Host "Run:  flutter run"
