function Get-CodepointString {
    param([int]$Codepoint)
    if ($Codepoint -lt 0x10000) { return [string][char]$Codepoint }
    $cp = $Codepoint - 0x10000
    $high = [char](0xD800 + (($cp -shr 10) -band 0x3FF))
    $low = [char](0xDC00 + ($cp -band 0x3FF))
    return "$high$low"
}

# Helper function to deselect specific tool checkboxes by tool name
function Clear-ToolSelections {
    param([string[]]$ToolNames)
    
    $content = $controls.mainContent.Content
    if (-not $content -or -not $ToolNames) { return }
    
    # Map tool names to checkbox names
    $toolToCheckbox = @{
        "Chocolatey" = "chkChocolatey"
        "NodeJS" = "chkNodeJS"
        "Python" = "chkPython"
        "VSCode" = "chkVSCode"
        "Git" = "chkGit"
        "Angular" = "chkAngular"
        "React" = "chkReact"
        "Docker" = "chkDocker"
        "Postman" = "chkPostman"
        "XAMPP" = "chkXAMPP"
        "Composer" = "chkComposer"
        "Laravel" = "chkLaravel"
        "Chrome" = "chkChrome"
        "7Zip" = "chk7Zip"
        "AzureCLI" = "chkAzureCLI"
        "AWSCLI" = "chkAWSCLI"
        "Terraform" = "chkTerraform"
        "Kubectl" = "chkKubectl"
        "GitHubCLI" = "chkGitHubCLI"
        "MySQLWorkbench" = "chkMySQLWorkbench"
        "MongoDBCompass" = "chkMongoDBCompass"
        "DBeaver" = "chkDBeaver"
        "PgAdmin" = "chkPgAdmin"
        "Redis" = "chkRedis"
        "IntelliJ" = "chkIntelliJ"
        "PyCharm" = "chkPyCharm"
        "AndroidStudio" = "chkAndroidStudio"
        "Sublime" = "chkSublime"
        "NotepadPP" = "chkNotepadPP"
        "GitHubDesktop" = "chkGitHubDesktop"
        "Slack" = "chkSlack"
        "Insomnia" = "chkInsomnia"
        "WindowsTerminal" = "chkWindowsTerminal"
        "PowerToys" = "chkPowerToys"
    }
    
    foreach ($tool in $ToolNames) {
        if ($toolToCheckbox.ContainsKey($tool)) {
            $cb = $content.FindName($toolToCheckbox[$tool])
            if ($cb) { $cb.IsChecked = $false }
        }
    }
}

# Save current checkbox selections to a script variable
function Save-ToolSelections {
    $content = $controls.mainContent.Content
    if (-not $content) { return }
    
    $script:savedToolSelections = @()
    $checkboxNames = @(
        "chkChocolatey", "chkNodeJS", "chkPython", "chkVSCode", "chkGit",
        "chkAngular", "chkReact", "chkDocker", "chkPostman", "chkXAMPP",
        "chkComposer", "chkLaravel", "chkChrome", "chk7Zip", "chkAzureCLI",
        "chkAWSCLI", "chkTerraform", "chkKubectl", "chkGitHubCLI",
        "chkMySQLWorkbench", "chkMongoDBCompass", "chkDBeaver", "chkPgAdmin",
        "chkRedis", "chkIntelliJ", "chkPyCharm", "chkAndroidStudio",
        "chkSublime", "chkNotepadPP", "chkGitHubDesktop", "chkSlack",
        "chkInsomnia", "chkWindowsTerminal", "chkPowerToys"
    )
    foreach ($name in $checkboxNames) {
        $cb = $content.FindName($name)
        if ($cb -and $cb.IsChecked) { 
            $script:savedToolSelections += $name 
        }
    }
}

# Restore checkbox selections from saved state
function Restore-ToolSelections {
    $content = $controls.mainContent.Content
    if (-not $content -or -not $script:savedToolSelections) { return }
    
    foreach ($name in $script:savedToolSelections) {
        $cb = $content.FindName($name)
        if ($cb) { $cb.IsChecked = $true }
    }
    # Clear saved selections after restoring
    $script:savedToolSelections = @()
}

function Set-ActionBar {
    param([string]$PageName)
    
    $accentColor = "#007ACC"
    $controls.actionBarContent.Children.Clear()
    
    switch ($PageName) {
        "Tools" {
            $controls.actionBar.Visibility = "Visible"
            
            $btnInstall = New-Object System.Windows.Controls.Button
            $btnInstall.Background = $accentColor
            $btnInstall.Foreground = "White"
            $btnInstall.Padding = "20,10"
            $btnInstall.FontSize = 14
            $btnInstall.FontWeight = "SemiBold"
            $btnInstall.BorderThickness = 0
            $btnInstall.Cursor = "Hand"
            $btnInstall.Width = 220
            $btnInstall.Margin = "5"
            Set-EmojiContent -Control $btnInstall -Emoji (Get-CodepointString 0x1F680) -Text "Install Selected Tools"
            $btnInstall.Add_Click({ Start-Installation })
            $controls.actionBarContent.Children.Add($btnInstall) | Out-Null
            
            # Uninstall Selected Tools button
            $btnUninstallSelected = New-Object System.Windows.Controls.Button
            $btnUninstallSelected.Background = "#FFDC143C"  # Crimson red for uninstall
            $btnUninstallSelected.Foreground = "White"
            $btnUninstallSelected.Padding = "20,10"
            $btnUninstallSelected.FontSize = 14
            $btnUninstallSelected.FontWeight = "SemiBold"
            $btnUninstallSelected.BorderThickness = 0
            $btnUninstallSelected.Cursor = "Hand"
            $btnUninstallSelected.Width = 230
            $btnUninstallSelected.Margin = "5"
            Set-EmojiContent -Control $btnUninstallSelected -Emoji (Get-CodepointString 0x1F5D1) -Text "Uninstall Selected Tools"
            $btnUninstallSelected.Add_Click({ Start-SelectedUninstallation })
            $controls.actionBarContent.Children.Add($btnUninstallSelected) | Out-Null
            
            # Select All button
            $btnSelectAll = New-Object System.Windows.Controls.Button
            $btnSelectAll.Background = "#FF28A745"  # Green
            $btnSelectAll.Foreground = "White"
            $btnSelectAll.Padding = "20,10"
            $btnSelectAll.FontSize = 14
            $btnSelectAll.FontWeight = "SemiBold"
            $btnSelectAll.BorderThickness = 0
            $btnSelectAll.Cursor = "Hand"
            $btnSelectAll.Width = 130
            $btnSelectAll.Margin = "5"
            Set-EmojiContent -Control $btnSelectAll -Emoji (Get-CodepointString 0x2705) -Text "Select All"
            $btnSelectAll.Add_Click({
                $content = $controls.mainContent.Content
                $checkboxNames = @(
                    "chkChocolatey", "chkNodeJS", "chkPython", "chkVSCode", "chkGit",
                    "chkAngular", "chkReact", "chkDocker", "chkPostman", "chkXAMPP",
                    "chkComposer", "chkLaravel", "chkChrome", "chk7Zip", "chkAzureCLI",
                    "chkAWSCLI", "chkTerraform", "chkKubectl", "chkGitHubCLI",
                    "chkMySQLWorkbench", "chkMongoDBCompass", "chkDBeaver", "chkPgAdmin",
                    "chkRedis", "chkIntelliJ", "chkPyCharm", "chkAndroidStudio",
                    "chkSublime", "chkNotepadPP", "chkGitHubDesktop", "chkSlack",
                    "chkInsomnia", "chkWindowsTerminal", "chkPowerToys"
                )
                foreach ($name in $checkboxNames) {
                    $cb = $content.FindName($name)
                    if ($cb -and $cb.IsEnabled) { $cb.IsChecked = $true }
                }
            })
            $controls.actionBarContent.Children.Add($btnSelectAll) | Out-Null
            
            # Deselect All button
            $btnDeselectAll = New-Object System.Windows.Controls.Button
            $btnDeselectAll.Background = "#FF6C757D"  # Gray
            $btnDeselectAll.Foreground = "White"
            $btnDeselectAll.Padding = "20,10"
            $btnDeselectAll.FontSize = 14
            $btnDeselectAll.FontWeight = "SemiBold"
            $btnDeselectAll.BorderThickness = 0
            $btnDeselectAll.Cursor = "Hand"
            $btnDeselectAll.Width = 140
            $btnDeselectAll.Margin = "5"
            Set-EmojiContent -Control $btnDeselectAll -Emoji (Get-CodepointString 0x274C) -Text "Deselect All"
            $btnDeselectAll.Add_Click({
                $content = $controls.mainContent.Content
                $checkboxNames = @(
                    "chkChocolatey", "chkNodeJS", "chkPython", "chkVSCode", "chkGit",
                    "chkAngular", "chkReact", "chkDocker", "chkPostman", "chkXAMPP",
                    "chkComposer", "chkLaravel", "chkChrome", "chk7Zip", "chkAzureCLI",
                    "chkAWSCLI", "chkTerraform", "chkKubectl", "chkGitHubCLI",
                    "chkMySQLWorkbench", "chkMongoDBCompass", "chkDBeaver", "chkPgAdmin",
                    "chkRedis", "chkIntelliJ", "chkPyCharm", "chkAndroidStudio",
                    "chkSublime", "chkNotepadPP", "chkGitHubDesktop", "chkSlack",
                    "chkInsomnia", "chkWindowsTerminal", "chkPowerToys"
                )
                foreach ($name in $checkboxNames) {
                    $cb = $content.FindName($name)
                    if ($cb) { $cb.IsChecked = $false }
                }
            })
            $controls.actionBarContent.Children.Add($btnDeselectAll) | Out-Null
            
            $btnRefresh = New-Object System.Windows.Controls.Button
            $btnRefresh.Background = $accentColor
            $btnRefresh.Foreground = "White"
            $btnRefresh.Padding = "20,10"
            $btnRefresh.FontSize = 14
            $btnRefresh.FontWeight = "SemiBold"
            $btnRefresh.BorderThickness = 0
            $btnRefresh.Cursor = "Hand"
            $btnRefresh.Width = 200
            $btnRefresh.Margin = "5"
            Set-EmojiContent -Control $btnRefresh -Emoji (Get-CodepointString 0x1F501) -Text "Refresh Versions"
            $btnRefresh.Add_Click({ 
                if ($script:isInstalling) {
                    [System.Windows.MessageBox]::Show(
                        "Please wait for the current operation to complete.",
                        "Operation In Progress",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Warning
                    ) | Out-Null
                    return
                }
                # Clear all caches for a full refresh
                Clear-AllToolCaches
                $script:versionInfo = $null
                Initialize-ToolsPage
            })
            $controls.actionBarContent.Children.Add($btnRefresh) | Out-Null
        }
        "Extensions" {
            $controls.actionBar.Visibility = "Visible"
            
            $btnInstallExt = New-Object System.Windows.Controls.Button
            $btnInstallExt.Background = $accentColor
            $btnInstallExt.Foreground = "White"
            $btnInstallExt.Padding = "20,10"
            $btnInstallExt.FontSize = 14
            $btnInstallExt.FontWeight = "SemiBold"
            $btnInstallExt.BorderThickness = 0
            $btnInstallExt.Cursor = "Hand"
            $btnInstallExt.Width = 250
            $btnInstallExt.Margin = "5"
            Set-EmojiContent -Control $btnInstallExt -Emoji (Get-CodepointString 0x1F9E9) -Text "Install Selected Extensions"
            $btnInstallExt.Add_Click({ Install-SelectedExtensions })
            $controls.actionBarContent.Children.Add($btnInstallExt) | Out-Null
            
            $btnSelectAll = New-Object System.Windows.Controls.Button
            $btnSelectAll.Background = $accentColor
            $btnSelectAll.Foreground = "White"
            $btnSelectAll.Padding = "20,10"
            $btnSelectAll.FontSize = 14
            $btnSelectAll.FontWeight = "SemiBold"
            $btnSelectAll.BorderThickness = 0
            $btnSelectAll.Cursor = "Hand"
            $btnSelectAll.Width = 140
            $btnSelectAll.Margin = "5"
            Set-EmojiContent -Control $btnSelectAll -Emoji (Get-CodepointString 0x2705) -Text "Select All"
            $btnSelectAll.Add_Click({
                $content = $controls.mainContent.Content
                foreach ($child in $content.Children) {
                    if ($child -is [System.Windows.Controls.Border]) {
                        foreach ($stackChild in $child.Child.Children) {
                            if ($stackChild -is [System.Windows.Controls.CheckBox]) {
                                $stackChild.IsChecked = $true
                            }
                        }
                    }
                }
            })
            $controls.actionBarContent.Children.Add($btnSelectAll) | Out-Null
            
            $btnDeselect = New-Object System.Windows.Controls.Button
            $btnDeselect.Background = $accentColor
            $btnDeselect.Foreground = "White"
            $btnDeselect.Padding = "20,10"
            $btnDeselect.FontSize = 14
            $btnDeselect.FontWeight = "SemiBold"
            $btnDeselect.BorderThickness = 0
            $btnDeselect.Cursor = "Hand"
            $btnDeselect.Width = 160
            $btnDeselect.Margin = "5"
            Set-EmojiContent -Control $btnDeselect -Emoji (Get-CodepointString 0x2B1C) -Text "Deselect All"
            $btnDeselect.Add_Click({
                $content = $controls.mainContent.Content
                foreach ($child in $content.Children) {
                    if ($child -is [System.Windows.Controls.Border]) {
                        foreach ($stackChild in $child.Child.Children) {
                            if ($stackChild -is [System.Windows.Controls.CheckBox]) {
                                $stackChild.IsChecked = $false
                            }
                        }
                    }
                }
            })
            $controls.actionBarContent.Children.Add($btnDeselect) | Out-Null
        }
        default {
            $controls.actionBar.Visibility = "Collapsed"
        }
    }
}

# Cache-aware Chocolatey check
if (-not (Get-Variable -Name chocoCacheTimestamp -Scope Script -ErrorAction SilentlyContinue)) {
    $script:chocoCacheTimestamp = $null
}

function Refresh-ChocoPackageCache {
    param([switch]$Force)
    
    if (-not $script:chocoPackageCache) {
        $script:chocoPackageCache = @{}
    }
    
    $shouldRefresh = $Force -or (-not $script:chocoCacheTimestamp) -or (((Get-Date) - $script:chocoCacheTimestamp).TotalSeconds -gt 15)
    if (-not $shouldRefresh) { return }
    
    $script:chocoPackageCache.Clear()
    $script:chocoCacheTimestamp = Get-Date
    
    # Dynamically find Chocolatey lib folder
    $libPath = $null
    $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
    if ($chocoCmd) {
        $chocoRoot = Split-Path (Split-Path $chocoCmd.Source -Parent) -Parent
        $libPath = Join-Path $chocoRoot "lib"
    }
    if (-not $libPath -or -not (Test-Path $libPath)) {
        $libPath = Join-Path $env:ProgramData "chocolatey\lib"
    }
    if (-not $libPath -or -not (Test-Path $libPath)) {
        if ($env:ChocolateyInstall) {
            $libPath = Join-Path $env:ChocolateyInstall "lib"
        }
    }
    if (-not $libPath -or -not (Test-Path $libPath)) { return }
    
    try {
        Get-ChildItem -Path $libPath -Directory -ErrorAction Stop | ForEach-Object {
            $script:chocoPackageCache[$_.Name.ToLowerInvariant()] = $true
        }
    } catch {
        # If filesystem read fails, leave cache empty and allow callers to proceed gracefully
    }
}

function Test-ChocoPackageInstalled {
    param([string]$PackageName)
    
    if (-not $PackageName) { return $false }
    Refresh-ChocoPackageCache
    
    $key = $PackageName.ToLowerInvariant()
    
    # Direct match first
    if ($script:chocoPackageCache.ContainsKey($key)) {
        return $true
    }
    
    # Also check for partial matches (e.g., awscli might be installed as awscli.2.x.x)
    foreach ($cachedKey in $script:chocoPackageCache.Keys) {
        if ($cachedKey -like "$key*" -or $cachedKey -like "*$key*") {
            return $true
        }
    }
    
    return $false
}

function Supports-Uninstall {
    param([string]$ToolName)
    
    if ($script:toolPackageMap.ContainsKey($ToolName)) { return $true }
    switch ($ToolName) {
        "Angular" { return $true }
        "React" { return $true }
        "Laravel" { return $true }
        default { return $false }
    }
}

# Add uninstall buttons next to installed tool checkboxes
function Add-UninstallButtons {
    $content = $controls.mainContent.Content
    if (-not $content) { return }
    
    # Only clear cache on explicit refresh, not on every tab switch
    # if ($script:chocoPackageCache) { $script:chocoPackageCache.Clear() }
    
    # Track which checkboxes we've already processed to prevent duplicates
    if (-not $script:processedToolCheckboxes) {
        $script:processedToolCheckboxes = @{}
    }
    
    # Initialize tool install cache if not exists
    if (-not $script:toolInstallCache) {
        $script:toolInstallCache = @{}
        $script:toolInstallCacheTime = $null
    }
    
    # Refresh install cache if older than 30 seconds
    $shouldRefreshCache = (-not $script:toolInstallCacheTime) -or (((Get-Date) - $script:toolInstallCacheTime).TotalSeconds -gt 30)
    if ($shouldRefreshCache) {
        $script:toolInstallCache = @{}
        $script:toolInstallCacheTime = Get-Date
        # Pre-populate choco cache once
        try { Refresh-ChocoPackageCache } catch { }
    }
    
    $toolsList = @(
        @{Name="Chocolatey"; CheckBox="chkChocolatey"},
        @{Name="NodeJS"; CheckBox="chkNodeJS"},
        @{Name="Python"; CheckBox="chkPython"},
        @{Name="VSCode"; CheckBox="chkVSCode"},
        @{Name="Git"; CheckBox="chkGit"},
        @{Name="Angular"; CheckBox="chkAngular"},
        @{Name="React"; CheckBox="chkReact"},
        @{Name="Docker"; CheckBox="chkDocker"},
        @{Name="Postman"; CheckBox="chkPostman"},
        @{Name="XAMPP"; CheckBox="chkXAMPP"},
        @{Name="Composer"; CheckBox="chkComposer"},
        @{Name="Laravel"; CheckBox="chkLaravel"},
        @{Name="Chrome"; CheckBox="chkChrome"},
        @{Name="7Zip"; CheckBox="chk7Zip"},
        @{Name="AzureCLI"; CheckBox="chkAzureCLI"},
        @{Name="AWSCLI"; CheckBox="chkAWSCLI"},
        @{Name="Terraform"; CheckBox="chkTerraform"},
        @{Name="Kubectl"; CheckBox="chkKubectl"},
        @{Name="GitHubCLI"; CheckBox="chkGitHubCLI"},
        @{Name="MySQLWorkbench"; CheckBox="chkMySQLWorkbench"},
        @{Name="MongoDBCompass"; CheckBox="chkMongoDBCompass"},
        @{Name="DBeaver"; CheckBox="chkDBeaver"},
        @{Name="PgAdmin"; CheckBox="chkPgAdmin"},
        @{Name="Redis"; CheckBox="chkRedis"},
        @{Name="IntelliJ"; CheckBox="chkIntelliJ"},
        @{Name="PyCharm"; CheckBox="chkPyCharm"},
        @{Name="AndroidStudio"; CheckBox="chkAndroidStudio"},
        @{Name="Sublime"; CheckBox="chkSublime"},
        @{Name="NotepadPP"; CheckBox="chkNotepadPP"},
        @{Name="GitHubDesktop"; CheckBox="chkGitHubDesktop"},
        @{Name="Slack"; CheckBox="chkSlack"},
        @{Name="Insomnia"; CheckBox="chkInsomnia"},
        @{Name="WindowsTerminal"; CheckBox="chkWindowsTerminal"},
        @{Name="PowerToys"; CheckBox="chkPowerToys"}
    )
    
    # Cache was already refreshed above if needed - no need to force again
    
    foreach ($tool in $toolsList) {
        $checkbox = $content.FindName($tool.CheckBox)
        if (-not $checkbox) { continue }
        
        # Skip if already processed (prevents duplicate buttons on refresh)
        if ($script:processedToolCheckboxes.ContainsKey($tool.CheckBox)) { continue }
        
        $isInstalled = Test-ToolInstalled -ToolName $tool.Name
        
        if ($isInstalled) {
            # Mark as processed
            $script:processedToolCheckboxes[$tool.CheckBox] = $true
            
            # Keep checkbox enabled so user can select for uninstall
            $checkbox.IsChecked = $false
            $checkbox.IsEnabled = $true
            $checkbox.ToolTip = "$($tool.Name) is installed. Select to uninstall."
            
            $parentPanel = $checkbox.Parent
            if ($parentPanel -isnot [System.Windows.Controls.Panel]) { continue }
            
            # Check if parent is already a DockPanel with tag (already wrapped)
            if ($parentPanel -is [System.Windows.Controls.DockPanel] -and $parentPanel.Tag -eq "tool-row") {
                continue
            }
            
            $containerPanel = New-Object System.Windows.Controls.DockPanel
            $containerPanel.LastChildFill = $true
            $containerPanel.Tag = "tool-row"
            $containerPanel.Margin = $checkbox.Margin
            $checkbox.Margin = "0"
            
            $insertIndex = $parentPanel.Children.IndexOf($checkbox)
            $parentPanel.Children.Remove($checkbox)
            
            $statusLabel = New-Object System.Windows.Controls.TextBlock
            $statusLabel.Text = "[Installed]"
            $statusLabel.Foreground = "#FF6DD587"
            $statusLabel.FontWeight = "SemiBold"
            $statusLabel.FontSize = 11
            $statusLabel.VerticalAlignment = "Center"
            $statusLabel.Margin = "10,0,0,0"
            [System.Windows.Controls.DockPanel]::SetDock($statusLabel, [System.Windows.Controls.Dock]::Right)
            
            $canUninstall = Supports-Uninstall -ToolName $tool.Name
            if ($canUninstall) {
                $btnUninstall = New-Object System.Windows.Controls.Button
                $btnUninstall.Content = "Uninstall"
                $btnUninstall.Background = "#FFDC143C"
                $btnUninstall.Foreground = "White"
                $btnUninstall.Padding = "10,5"
                $btnUninstall.Margin = "10,0,0,0"
                $btnUninstall.FontSize = 11
                $btnUninstall.FontWeight = "SemiBold"
                $btnUninstall.BorderThickness = 0
                $btnUninstall.Cursor = "Hand"
                $btnUninstall.Width = 110
                [System.Windows.Controls.DockPanel]::SetDock($btnUninstall, [System.Windows.Controls.Dock]::Right)
                
                $toolName = $tool.Name
                $btnUninstall.Add_Click({
                    $result = [System.Windows.MessageBox]::Show(
                        "Are you sure you want to uninstall $toolName?",
                        "Confirm Uninstall",
                        [System.Windows.MessageBoxButton]::YesNo,
                        [System.Windows.MessageBoxImage]::Question)
                    
                    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                        Start-Uninstallation -ToolName $toolName
                    }
                }.GetNewClosure())
                
                $containerPanel.Children.Add($btnUninstall) | Out-Null
            } else {
                $statusLabel.Text = "[Installed - manual removal]"
                $statusLabel.Foreground = "#FFFFC857"
                $checkbox.ToolTip += " Uninstall manually from Apps & Features."
            }
            
            $containerPanel.Children.Add($statusLabel) | Out-Null
            $containerPanel.Children.Add($checkbox) | Out-Null
            $parentPanel.Children.Insert($insertIndex, $containerPanel)
        }
    }
}

# Tool detection helpers
function Test-ToolInstalled {
    param([string]$ToolName, [switch]$AllowFallback = $true, [switch]$ForceCheck)
    
    # Use cache if available and not forcing a check
    if (-not $ForceCheck -and $script:toolInstallCache -and $script:toolInstallCache.ContainsKey($ToolName)) {
        return $script:toolInstallCache[$ToolName]
    }
    
    # Refresh PATH only if not done recently
    if (-not $script:lastPathRefresh -or (((Get-Date) - $script:lastPathRefresh).TotalSeconds -gt 10)) {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        $script:lastPathRefresh = Get-Date
    }
    
    $result = $false
    
    if ($script:toolPackageMap.ContainsKey($ToolName)) {
        $package = $script:toolPackageMap[$ToolName]
        $isInstalled = Test-ChocoPackageInstalled $package
        if ($isInstalled -or -not $AllowFallback) {
            $result = $isInstalled
            if (-not $script:toolInstallCache) { $script:toolInstallCache = @{} }
            $script:toolInstallCache[$ToolName] = $result
            return $result
        }
    }
    
    if (-not $AllowFallback) { 
        if (-not $script:toolInstallCache) { $script:toolInstallCache = @{} }
        $script:toolInstallCache[$ToolName] = $false
        return $false 
    }
    
    $result = switch ($ToolName) {
        "Chocolatey" { (Get-Command choco -ErrorAction SilentlyContinue) -ne $null }
        "NodeJS" { (Get-Command node -ErrorAction SilentlyContinue) -ne $null }
        "Python" { (Get-Command python -ErrorAction SilentlyContinue) -ne $null }
        "VSCode" { (Get-Command code -ErrorAction SilentlyContinue) -ne $null }
        "Git" { (Get-Command git -ErrorAction SilentlyContinue) -ne $null }
        "Angular" { (Get-Command ng -ErrorAction SilentlyContinue) -ne $null }
        "React" { (Get-Command create-react-app -ErrorAction SilentlyContinue) -ne $null }
        "Docker" { (Get-Command docker -ErrorAction SilentlyContinue) -ne $null }
        "Postman" { (Test-Path "$env:LOCALAPPDATA\Postman\Postman.exe") }
        "XAMPP" { (Test-Path "C:\\xampp\\xampp-control.exe") }
        "Composer" { (Get-Command composer -ErrorAction SilentlyContinue) -ne $null }
        "Laravel" { (Get-Command laravel -ErrorAction SilentlyContinue) -ne $null }
        "Chrome" { (Test-Path "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe") -or (Test-Path "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe") }
        "7Zip" { (Test-Path "C:\\Program Files\\7-Zip\\7z.exe") -or (Test-Path "C:\\Program Files (x86)\\7-Zip\\7z.exe") }
        "AzureCLI" { (Get-Command az -ErrorAction SilentlyContinue) -ne $null }
        "AWSCLI" { 
            if ((Get-Command aws -ErrorAction SilentlyContinue) -ne $null) { $true }
            elseif (Test-Path "C:\Program Files\Amazon\AWSCLIV2\aws.exe") { $true }
            elseif (Test-Path "$env:LOCALAPPDATA\Programs\Amazon\AWSCLIV2\aws.exe") { $true }
            else { $false }
        }
        "Terraform" { (Get-Command terraform -ErrorAction SilentlyContinue) -ne $null }
        "Kubectl" { (Get-Command kubectl -ErrorAction SilentlyContinue) -ne $null }
        "GitHubCLI" { (Get-Command gh -ErrorAction SilentlyContinue) -ne $null }
        "MySQLWorkbench" { (Test-Path "C:\\Program Files\\MySQL\\MySQL Workbench*\\MySQLWorkbench.exe") }
        "MongoDBCompass" { (Test-Path "$env:LOCALAPPDATA\\MongoDBCompass\\MongoDBCompass.exe") }
        "DBeaver" { (Test-Path "C:\\Program Files\\DBeaver\\dbeaver.exe") -or (Get-Command dbeaver -ErrorAction SilentlyContinue) -ne $null }
        "PgAdmin" { (Test-Path "C:\\Program Files\\pgAdmin*\\runtime\\pgAdmin4.exe") }
        "Redis" { (Get-Command redis-server -ErrorAction SilentlyContinue) -ne $null }
        "IntelliJ" { (Test-Path "C:\\Program Files\\JetBrains\\IntelliJ*\\bin\\idea64.exe") }
        "PyCharm" { (Test-Path "C:\\Program Files\\JetBrains\\PyCharm*\\bin\\pycharm64.exe") }
        "AndroidStudio" { (Test-Path "C:\\Program Files\\Android\\Android Studio\\bin\\studio64.exe") }
        "Sublime" { (Test-Path "C:\\Program Files\\Sublime Text*\\sublime_text.exe") }
        "NotepadPP" { (Test-Path "C:\\Program Files\\Notepad++\\notepad++.exe") -or (Test-Path "C:\\Program Files (x86)\\Notepad++\\notepad++.exe") }
        "GitHubDesktop" { (Test-Path "$env:LOCALAPPDATA\\GitHubDesktop\\GitHubDesktop.exe") }
        "Slack" { (Test-Path "$env:LOCALAPPDATA\\slack\\slack.exe") }
        "Insomnia" { (Test-Path "$env:LOCALAPPDATA\\insomnia\\Insomnia.exe") }
        "WindowsTerminal" { (Get-Command wt -ErrorAction SilentlyContinue) -ne $null }
        "PowerToys" { (Test-Path "C:\\Program Files\\PowerToys\\PowerToys.exe") }
        default { $false }
    }
    
    # Cache the result
    if (-not $script:toolInstallCache) { $script:toolInstallCache = @{} }
    $script:toolInstallCache[$ToolName] = $result
    return $result
}

function Get-MissingInstalledTools {
    param([string[]]$Tools)
    $missing = @()
    if (-not $Tools) { return $missing }
    
    # Quick refresh - just update PATH and choco cache once (no long waits)
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Refresh-ChocoPackageCache -Force
    
    foreach ($tool in $Tools) {
        try {
            $isInstalled = Test-ToolInstalled -ToolName $tool -ForceCheck
            
            if (-not $isInstalled) {
                $missing += $tool
                Write-Log "$tool was not detected after installation finished." "ERROR"
            } else {
                Write-Log "$tool verified as installed." "SUCCESS"
            }
        } catch {
            Write-Log "Verification failed for ${tool}: $($_.Exception.Message)" "ERROR"
            $missing += $tool
        }
    }
    return $missing
}
