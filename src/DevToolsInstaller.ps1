<#
================================================================================
    Development Tools Installer V2.0
    Created by: SPARO
    Date: November 2025
    License: MIT License - Free to use and modify
    
    Description: Enhanced GUI installer with sidebar navigation, theme toggle,
                 installation profiles, VS Code extensions, and more!
    
    Usage: Run as Administrator
           Double-click LAUNCH.ps1 or run src\DevToolsInstaller.ps1 directly
================================================================================
#>

# Set UTF-8 encoding for proper emoji display (console + WPF)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import modules
$modulePath = Join-Path $PSScriptRoot "Modules"
Import-Module (Join-Path $modulePath "VersionFetcher.psm1") -Force
Import-Module (Join-Path $modulePath "Installer.psm1") -Force
Import-Module (Join-Path $modulePath "Configuration.psm1") -Force
Import-Module (Join-Path $modulePath "VSCodeExtensions.psm1") -Force

# Load shared helpers
$partsPath = Join-Path $PSScriptRoot "Parts"
. (Join-Path $partsPath "Security.ps1")
. (Join-Path $partsPath "ErrorLogging.ps1")

# Capture runtime errors to a log file and surface unhandled errors
Start-ErrorCapture | Out-Null
trap {
    Report-UnhandledError -ErrorRecord $_
    continue
}

# Check for admin rights
if (-not (Test-AdminRights)) {
    $result = [System.Windows.MessageBox]::Show(
        "This application requires Administrator privileges.`n`nWould you like to restart as Administrator?",
        "Administrator Rights Required",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    
    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        $args = @('-ExecutionPolicy','Bypass','-File', $PSCommandPath)
        Start-Process pwsh -Verb RunAs -ArgumentList $args
    }
    exit
}

# Global variables
$script:selectedTools = @{}
$script:versionInfo = @{}
$script:isInstalling = $false
$script:defaultDownloadPath = Join-Path $PSScriptRoot "Downloads"
$script:legacySettingsPath = Join-Path $PSScriptRoot "user-settings.json"
$script:settingsDir = Join-Path ([Environment]::GetFolderPath("ApplicationData")) "DevToolsInstaller"
$script:settingsPath = Join-Path $script:settingsDir "user-settings.json"
$script:cachedPages = @{}  # Cache parsed XAML pages to prevent lag
$script:downloadPath = $script:defaultDownloadPath
$script:userSettings = $null
$script:isDarkTheme = $true
$script:currentTheme = "Dark"  # Track current theme
$script:currentPage = "Tools"
$script:lastHealthResults = @()
$script:lastUpdateResults = @()
$script:lastHealthRun = $null
$script:lastUpdateRun = $null
$script:isSidebarCollapsed = $false
$script:healthScanWorker = $null
$script:profileInstallTargets = @()
$script:toolPackageMap = @{
    "Git" = "git"
    "Docker" = "docker-desktop"
    "Chrome" = "googlechrome"
    "7Zip" = "7zip"
    "AzureCLI" = "azure-cli"
    "AWSCLI" = "awscli"
    "Terraform" = "terraform"
    "Kubectl" = "kubernetes-cli"
    "GitHubCLI" = "github-cli"
    "MySQLWorkbench" = "mysql.workbench"
    "MongoDBCompass" = "mongodb-compass"
    "DBeaver" = "dbeaver"
    "PgAdmin" = "pgadmin4"
    "Redis" = "redis-64"
    "IntelliJ" = "intellijidea-community"
    "PyCharm" = "pycharm-community"
    "AndroidStudio" = "androidstudio"
    "Sublime" = "sublimetext3"
    "NotepadPP" = "notepadplusplus"
    "GitHubDesktop" = "github-desktop"
    "Slack" = "slack"
    "Insomnia" = "insomnia-rest-api-client"
    "WindowsTerminal" = "microsoft-windows-terminal"
    "PowerToys" = "powertoys"
    "Postman" = "postman"
    # Additional tools that can be uninstalled via Chocolatey
    "NodeJS" = "nodejs"
    "Python" = "python"
    "VSCode" = "vscode"
    "XAMPP" = "xampp-80"
    "Composer" = "composer"
}
$script:chocoPackageCache = @{}

# Load modularized components
. (Join-Path $partsPath "UserSettings.ps1")
. (Join-Path $partsPath "UiLayout.ps1")
. (Join-Path $partsPath "PageContent.ps1")
. (Join-Path $partsPath "HealthAndUpdates.ps1")
. (Join-Path $partsPath "Installers.ps1")
. (Join-Path $partsPath "Navigation.ps1")

$controls.btnNavTools.Add_Click({ Load-Page "Tools" })
$controls.btnNavProfiles.Add_Click({ Load-Page "Profiles" })
$controls.btnNavExtensions.Add_Click({ Load-Page "Extensions" })
$controls.btnNavHealth.Add_Click({ Load-Page "Health" })
$controls.btnNavUpdate.Add_Click({ Load-Page "Update" })
$controls.btnNavSettings.Add_Click({ Load-Page "Settings" })
$controls.btnNavAbout.Add_Click({ Load-Page "About" })

$controls.btnThemeToggle.Add_Checked({
    if (-not $script:isDarkTheme) {
        $script:isDarkTheme = $true
        $script:userSettings.PreferredTheme = "Dark"
        Save-UserSettings
        Set-Theme -Dark $true
    }
})
$controls.btnThemeToggle.Add_Unchecked({
    if ($script:isDarkTheme) {
        $script:isDarkTheme = $false
        $script:userSettings.PreferredTheme = "Light"
        Save-UserSettings
        Set-Theme -Dark $false
    }
})

if ($controls.btnSidebarToggle) {
    $controls.btnSidebarToggle.Add_Click({ Toggle-Sidebar })
}

Set-Theme -Dark $script:isDarkTheme
Load-Page "Tools"

# Use surrogate pair encoding for emojis (works in PowerShell 5.1)
function Get-EmojiString {
    param([int]$Codepoint)
    if ($Codepoint -lt 0x10000) { return [string][char]$Codepoint }
    $cp = $Codepoint - 0x10000
    $high = [char](0xD800 + (($cp -shr 10) -band 0x3FF))
    $low = [char](0xDC00 + ($cp -band 0x3FF))
    return "$high$low"
}

$checkMark = Get-EmojiString 0x2705   # ✅
$rocketEmoji = Get-EmojiString 0x1F680  # 🚀

Write-Host "========================================" -ForegroundColor Green
Write-Host "Development Tools Installer V2.0" -ForegroundColor Cyan
Write-Host "Created by SPARO c 2025" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "$checkMark Sidebar Navigation + Profiles" -ForegroundColor Green
Write-Host "$checkMark Health Dashboard & Reports" -ForegroundColor Green
Write-Host "$checkMark Update Center (Chocolatey)" -ForegroundColor Green
Write-Host "$checkMark Saved Settings + Theme" -ForegroundColor Green
Write-Host "$checkMark 34 Development Tools + 22 VS Code Extensions" -ForegroundColor Green
Write-Host ""
Write-Host "$rocketEmoji Opening GUI..." -ForegroundColor Cyan

$window.ShowDialog() | Out-Null

# Close transcript if it was started
Stop-ErrorCapture
