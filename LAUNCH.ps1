# LAUNCH.ps1
# Quick launcher for DevToolsInstaller V2 with automatic admin elevation
# This launcher closes immediately after starting the main app

$scriptPath = Join-Path $PSScriptRoot "src\DevToolsInstaller.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "Error: src\DevToolsInstaller.ps1 not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

try {
    # Launch the main app with admin privileges and exit this launcher immediately
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`""
    # Exit immediately - don't wait
    exit
} catch {
    Write-Host "Failed to launch: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
}
