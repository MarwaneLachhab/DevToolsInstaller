# LAUNCH.ps1
# Quick launcher for DevToolsInstaller V2 with automatic admin elevation

# Ensure UTF-8 output so the console banner renders correctly
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Launch the unified installer inside /src
$scriptPath = Join-Path $PSScriptRoot "src\\DevToolsInstaller.ps1"
$version = "V2.0 (Enhanced)"

if (-not (Test-Path $scriptPath)) {
    Write-Host "Error: src\\DevToolsInstaller.ps1 not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "🚀 Development Tools Installer $version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Created by SPARO c 2025" -ForegroundColor Yellow
Write-Host ""
Write-Host "Launching with Administrator privileges..." -ForegroundColor Yellow
Write-Host ""

try {
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`""
    Write-Host "✅ Launched successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to launch: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
}
