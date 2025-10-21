<#
Generate Android keystore using keytool.

Usage: Run this in PowerShell from the project root (or this directory):
    cd android; .\generate_keystore.ps1

Requirements: Java JDK must be installed and `keytool` must be on PATH.

DO NOT commit the generated keystore or the resulting android/key.properties file.
#>

# === Configuration (paste your values or leave as-is) ===
$storeFile = "android\keystore.jks"
$storePassword = "Star234"
$keyPassword = "Star234"
$keyAlias = "key"
$dname = 'CN=Rhm Starboy, OU=AppDev, O=Speedgun, L=Sialkot, ST=Punjab, C=PK'

Write-Host "Checking for keytool..."
$kt = (Get-Command keytool -ErrorAction SilentlyContinue)
if (-not $kt) {
    Write-Error "keytool not found on PATH. Install a JDK and ensure keytool is available."
    exit 2
}

Write-Host "Generating keystore at $storeFile"
& keytool -genkeypair -v -keystore $storeFile -storetype JKS -alias $keyAlias -keyalg RSA -keysize 2048 -validity 10000 -storepass $storePassword -keypass $keyPassword -dname $dname

if (Test-Path $storeFile) {
    Write-Host "Keystore created: $storeFile"
    Write-Host "Make sure android/key.properties exists with the correct paths and is NOT committed."
} else {
    Write-Error "Keystore file not found after keytool execution."
    exit 1
}
