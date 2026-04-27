$ErrorActionPreference = "Stop"

$versionLine = Select-String -Path "pubspec.yaml" -Pattern "^version:" | Select-Object -First 1
$versionRaw = $versionLine.Line.Replace("version:", "").Trim()
$versionFileSafe = $versionRaw.Replace("+", "_")

Write-Host "Building MeetThai Beta APK Version $versionRaw..."

flutter pub get

flutter build apk --release `
--dart-define=SUPABASE_URL="https://kmcykmpimhyculcnshmp.supabase.co" `
--dart-define=SUPABASE_ANON_KEY="DEIN_SUPABASE_ANON_KEY" `
--dart-define=REVENUECAT_PUBLIC_KEY="test_YunwSEZYuNOwuQcVZTgdzCEsDpE"

$outputDir = "release_apks"

if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$sourceApk = "build\app\outputs\flutter-apk\app-release.apk"
$targetApk = "$outputDir\meetthai-$versionFileSafe.apk"

Copy-Item $sourceApk $targetApk -Force

Write-Host ""
Write-Host "Fertig!"
Write-Host "APK liegt hier:"
Write-Host $targetApk