$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "MeetThai Google Play AAB Builder"
Write-Host "-------------------------------"

$pubspecPath = "pubspec.yaml"

if (!(Test-Path $pubspecPath)) {
    throw "pubspec.yaml nicht gefunden. Bitte Script im Projekt-Hauptordner starten."
}

$pubspec = Get-Content $pubspecPath
$versionLine = $pubspec | Where-Object { $_ -match "^version:" } | Select-Object -First 1

if (!$versionLine) {
    throw "Keine version-Zeile in pubspec.yaml gefunden."
}

$currentVersion = $versionLine.Replace("version:", "").Trim()

if ($currentVersion -notmatch "^(\d+)\.(\d+)\.(\d+)\+(\d+)$") {
    throw "Version hat falsches Format. Erwartet: 1.0.0+1"
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]
$build = [int]$Matches[4]

$patch = $patch + 1
$build = $build + 1

$newVersion = "$major.$minor.$patch+$build"
$newVersionFileSafe = $newVersion.Replace("+", "_")

Write-Host "Aktuelle Version: $currentVersion"
Write-Host "Neue Version:     $newVersion"
Write-Host ""

$newPubspec = $pubspec -replace "^version:\s*.*$", "version: $newVersion"
Set-Content -Path $pubspecPath -Value $newPubspec -Encoding UTF8

Write-Host "pubspec.yaml wurde aktualisiert."
Write-Host ""

Write-Host "Flutter clean..."
flutter clean
if ($LASTEXITCODE -ne 0) {
    throw "flutter clean fehlgeschlagen."
}

Write-Host ""
Write-Host "Flutter pub get..."
flutter pub get
if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get fehlgeschlagen."
}

Write-Host ""
Write-Host "Flutter build appbundle..."
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) {
    throw "flutter build appbundle fehlgeschlagen."
}

$outputDir = "release_aab"

if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$sourceAab = "build\app\outputs\bundle\release\app-release.aab"
$targetAab = "$outputDir\meetthai-$newVersionFileSafe.aab"

if (!(Test-Path $sourceAab)) {
    throw "AAB wurde nicht gefunden: $sourceAab"
}

Copy-Item $sourceAab $targetAab -Force

Write-Host ""
Write-Host "Fertig!"
Write-Host "AAB liegt hier:"
Write-Host $targetAab
Write-Host ""
Write-Host "Google Play Version:"
Write-Host "Version Name: $major.$minor.$patch"
Write-Host "Version Code: $build"