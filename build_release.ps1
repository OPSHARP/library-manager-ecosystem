# Builds signed RELEASE artifacts with Dart-level obfuscation + R8 enabled.
#
#   --obfuscate            renames Dart symbols so the Dart AOT snapshot is
#                          much harder to reverse engineer
#   --split-debug-info     writes the symbol mapping to build\symbols so
#                          Play Console can de-obfuscate stack traces
#
# R8 (Java/Kotlin minify + resource shrink) is enabled in
# android/app/build.gradle.kts (release build type).
param(
    [switch]$SkipApk
)

$ErrorActionPreference = "Stop"
$symbols = Join-Path (Get-Location) "build\symbols"

Write-Host "==> Building release AAB (obfuscated + minified)..." -ForegroundColor Cyan
flutter build appbundle --release --obfuscate --split-debug-info=$symbols --android-skip-build-dependency-validation
if (-not $?) { exit 1 }

if (-not $SkipApk) {
    Write-Host "==> Building release APK (obfuscated + minified)..." -ForegroundColor Cyan
    flutter build apk --release --obfuscate --split-debug-info=$symbols --android-skip-build-dependency-validation
    if (-not $?) { exit 1 }
}

Write-Host ""
Write-Host "Build complete." -ForegroundColor Green
Write-Host "Upload build\symbols to Play Console for de-obfuscated crash reports." -ForegroundColor Yellow
