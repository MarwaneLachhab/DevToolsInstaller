function Initialize-SettingsPage {
    param($content)
    
    Ensure-UserSettingsProperties
    
    $txtDownloadPath = $content.FindName("txtDownloadPath")
    if ($txtDownloadPath) { $txtDownloadPath.Text = $script:downloadPath }
    
    $chkAutoHealth = $content.FindName("chkAutoHealth")
    if ($chkAutoHealth) { $chkAutoHealth.IsChecked = [bool](Get-UserSettingValue -Name "AutoRunHealthAfterInstall" -Default $true) }
    
    $chkAutoUpdates = $content.FindName("chkAutoUpdates")
    if ($chkAutoUpdates) { $chkAutoUpdates.IsChecked = [bool](Get-UserSettingValue -Name "AutoCheckUpdates" -Default $false) }
    
    $cmbTheme = $content.FindName("cmbDefaultTheme")
    if ($cmbTheme) {
        $preferredTheme = Get-UserSettingValue -Name "PreferredTheme" -Default "Dark"
        $desired = if ($preferredTheme -eq "Light") { "Light" } else { "Dark" }
        foreach ($item in $cmbTheme.Items) {
            if ($item.Content -eq $desired) {
                $cmbTheme.SelectedItem = $item
                break
            }
        }
    }
    
    $statusText = $content.FindName("txtSettingsStatus")
    
    $btnBrowse = $content.FindName("btnBrowseDownloadPath")
    if ($btnBrowse -and $txtDownloadPath) {
        $btnBrowse.Add_Click({
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.SelectedPath = $txtDownloadPath.Text
            $dialog.ShowNewFolderButton = $true
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $txtDownloadPath.Text = $dialog.SelectedPath
                if ($statusText) { $statusText.Text = "Folder selection updated." }
            }
        }.GetNewClosure())
    }
    
    $btnSave = $content.FindName("btnSaveSettings")
    if ($btnSave) {
        $btnSave.Add_Click({
            if (-not $txtDownloadPath) {
                [System.Windows.MessageBox]::Show("Download path field is unavailable. Reload the Settings page and try again.", "Settings",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }
            $path = $txtDownloadPath.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($path)) {
                [System.Windows.MessageBox]::Show("Download path cannot be empty.", "Validation",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }
            
            Ensure-UserSettingsProperties
            
            if (-not (Test-Path $path)) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
            }
            
            $script:downloadPath = $path
            Set-UserSettingValue -Name "DownloadPath" -Value $path
            if ($chkAutoHealth) { Set-UserSettingValue -Name "AutoRunHealthAfterInstall" -Value ([bool]$chkAutoHealth.IsChecked) }
            if ($chkAutoUpdates) { Set-UserSettingValue -Name "AutoCheckUpdates" -Value ([bool]$chkAutoUpdates.IsChecked) }
            
            $selectedTheme = "Dark"
            if ($cmbTheme -and $cmbTheme.SelectedItem) {
                $selectedTheme = $cmbTheme.SelectedItem.Content
            }
            $currentTheme = Get-UserSettingValue -Name "PreferredTheme" -Default "Dark"
            $themeChanged = $selectedTheme -ne $currentTheme
            Set-UserSettingValue -Name "PreferredTheme" -Value $selectedTheme
            
            Ensure-DownloadPath
            Save-UserSettings
            
            if ($themeChanged) {
                $script:isDarkTheme = $selectedTheme -ne "Light"
                Set-Theme -Dark $script:isDarkTheme
            }
            
            if ($statusText) {
                $statusText.Text = "Settings saved at $(Get-Date -Format 'HH:mm:ss')."
            }
        }.GetNewClosure())
    }
    
    $btnReset = $content.FindName("btnResetSettings")
    if ($btnReset) {
        $btnReset.Add_Click({
            $defaults = Get-DefaultUserSettings
            if ($txtDownloadPath) { $txtDownloadPath.Text = $defaults.DownloadPath }
            if ($chkAutoHealth) { $chkAutoHealth.IsChecked = $defaults.AutoRunHealthAfterInstall }
            if ($chkAutoUpdates) { $chkAutoUpdates.IsChecked = $defaults.AutoCheckUpdates }
            if ($cmbTheme) {
                foreach ($item in $cmbTheme.Items) {
                    if ($item.Content -eq $defaults.PreferredTheme) {
                        $cmbTheme.SelectedItem = $item
                        break
                    }
                }
            }
            if ($statusText) { $statusText.Text = "Defaults restored. Click Save to apply." }
        }.GetNewClosure())
    }
}

function Initialize-ToolsPage {
    # Clear the processed checkboxes tracker so buttons rebuild correctly
    $script:processedToolCheckboxes = @{}
    
    # Rebuild page content to ensure clean state (prevents duplicate buttons on refresh)
    $content = [Windows.Markup.XamlReader]::Parse((Get-ToolsPageContent))
    $controls.mainContent.Content = $content
    
    # During operation, just show cached data without any refreshes
    if ($script:isInstalling) {
        $controls.txtStatus.Text = "Operation in progress..."
        # Still apply cached versions and installed indicators
        if ($script:versionInfo -and $script:versionInfo.NodeJS) {
            Apply-CachedVersions
        }
        # Use cached tool status (no refresh during operation)
        try { Add-UninstallButtons } catch { }
        return
    }
    
    # Use cached version info if available (only refresh manually or first load)
    if ($script:versionInfo -and $script:versionInfo.NodeJS) {
        # Apply cached versions immediately (no network call)
        Apply-CachedVersions
        $controls.txtStatus.Text = "Checking installed tools..."
    } else {
        # First load - fetch versions
        $controls.txtStatus.Text = "Fetching latest versions..."
        try {
            Update-VersionInfo
        } catch { }
    }
    
    # Add installed status indicators
    try {
        Add-UninstallButtons
    } catch { }
    
    $controls.txtStatus.Text = "Ready"
}

# Apply cached version info without network calls
function Apply-CachedVersions {
    $content = $controls.mainContent.Content
    if (-not $content -or -not $script:versionInfo) { return }
    
    $txtNode = $content.FindName("txtNodeVersion")
    $txtPython = $content.FindName("txtPythonVersion")
    $txtVSCode = $content.FindName("txtVSCodeVersion")
    $txtXAMPP = $content.FindName("txtXAMPPVersion")
    
    if ($txtNode -and $script:versionInfo.NodeJS) { $txtNode.Text = "Node.js - v$($script:versionInfo.NodeJS.Version)" }
    if ($txtPython -and $script:versionInfo.Python) { $txtPython.Text = "Python - v$($script:versionInfo.Python.Version)" }
    if ($txtVSCode -and $script:versionInfo.VSCode) { $txtVSCode.Text = "VS Code - v$($script:versionInfo.VSCode.Version)" }
    if ($txtXAMPP -and $script:versionInfo.XAMPP) { $txtXAMPP.Text = "XAMPP - v$($script:versionInfo.XAMPP.Version)" }
}
function Load-Page {
    param([string]$PageName)
    
    $script:currentPage = $PageName
    
    # Update sidebar active state
    $navButtons = @(
        $controls.btnNavTools,
        $controls.btnNavProfiles,
        $controls.btnNavExtensions,
        $controls.btnNavHealth,
        $controls.btnNavUpdate,
        $controls.btnNavSettings,
        $controls.btnNavAbout
    )
    
    foreach ($btn in $navButtons) {
        $btn.Background = "Transparent"
        $btn.BorderThickness = "0,0,0,0"
    }
    
    # If an operation is in progress, warn user but allow navigation
    if ($script:isInstalling) {
        $controls.txtStatus.Text = "Operation in progress... Please wait."
    }
    
    switch ($PageName) {
        "Tools" {
            $controls.btnNavTools.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavTools.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "Install Development Tools"
            $controls.txtPageSubtitle.Text = "Select tools to install automatically with latest versions"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-ToolsPageContent))
            $controls.mainContent.Content = $content
            
            # Set up action bar
            Set-ActionBar "Tools"
            
            # Load versions and installed-state indicators (skips if operation in progress)
            Initialize-ToolsPage
        }
        "Profiles" {
            $controls.btnNavProfiles.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavProfiles.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "Installation Profiles"
            $controls.txtPageSubtitle.Text = "Pre-configured bundles for quick setup"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-ProfilesPageContent))
            $controls.mainContent.Content = $content
            
            # Hide action bar for profiles (buttons are in content)
            $controls.actionBar.Visibility = "Collapsed"
            
            # Wire up profile buttons
            $content.FindName("btnProfileWeb").Add_Click({ Install-Profile "Web" })
            $content.FindName("btnProfilePHP").Add_Click({ Install-Profile "PHP" })
            $content.FindName("btnProfilePython").Add_Click({ Install-Profile "Python" })
            $content.FindName("btnProfileFull").Add_Click({ Install-Profile "Full" })
        }
        "Extensions" {
            $controls.btnNavExtensions.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavExtensions.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "VS Code Extensions"
            $controls.txtPageSubtitle.Text = "Enhance your coding experience with popular extensions"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-ExtensionsPageContent))
            $controls.mainContent.Content = $content
            
            # Set up action bar
            Set-ActionBar "Extensions"
        }
        "Health" {
            $controls.btnNavHealth.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavHealth.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "System Health Check"
            $controls.txtPageSubtitle.Text = "Verify installed tools and detect issues"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-HealthPageContent))
            $controls.mainContent.Content = $content
            $controls.actionBar.Visibility = "Collapsed"
            
            $runButton = $content.FindName("btnRunHealthCheck")
            if ($runButton) { $runButton.Add_Click({ Invoke-HealthCheck }) }
            
            $exportButton = $content.FindName("btnExportHealthReport")
            if ($exportButton) { $exportButton.Add_Click({ Export-HealthReport }) }
            
            if ($script:lastHealthResults -and $script:lastHealthResults.Count -gt 0) {
                Render-HealthResults -Results $script:lastHealthResults
            } else {
                Invoke-HealthCheck
            }
        }
        "Update" {
            $controls.btnNavUpdate.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavUpdate.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "Update Manager"
            $controls.txtPageSubtitle.Text = "Check for and install updates for installed tools"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-UpdatePageContent))
            $controls.mainContent.Content = $content
            $controls.actionBar.Visibility = "Collapsed"
            
            $btnCheck = $content.FindName("btnCheckUpdates")
            if ($btnCheck) { $btnCheck.Add_Click({ Invoke-UpdateCheck }) }
            
            $btnUpdate = $content.FindName("btnUpdateSelected")
            if ($btnUpdate) { $btnUpdate.Add_Click({ Install-SelectedUpdates }) }
            
            $btnExport = $content.FindName("btnExportUpdateReport")
            if ($btnExport) { $btnExport.Add_Click({ Export-UpdateReport }) }
            
            if ($script:lastUpdateResults -and $script:lastUpdateResults.Count -gt 0) {
                Render-UpdateResults -Results $script:lastUpdateResults
            } elseif ($script:userSettings.AutoCheckUpdates) {
                Invoke-UpdateCheck
            }
        }
        "Settings" {
            $controls.btnNavSettings.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavSettings.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "Settings"
            $controls.txtPageSubtitle.Text = "Configure installer preferences"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-SettingsPageContent))
            $controls.mainContent.Content = $content
            $controls.actionBar.Visibility = "Collapsed"
            Initialize-SettingsPage -content $content
        }
        "About" {
            $controls.btnNavAbout.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavAbout.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "About"
            $controls.txtPageSubtitle.Text = "Development Tools Installer V2.0"
            
            $content = New-Object System.Windows.Controls.StackPanel
            $content.Margin = "20"
            
            $about = @"
Created by: SPARO c 2025
Version: 2.0.0
License: MIT License

Features:
? 34 Development Tools (8 categories)
? Health Dashboard & Exportable Reports  
? Chocolatey Update Center
? Installation Profiles
? 22 VS Code Extensions
? Dark/Light Theme Toggle & Saved Settings
? Sidebar Navigation
? Chocolatey Integration & Silent Installs

Tools Included:
- Chocolatey, Node.js, Python, VS Code, Git, Docker
- Chrome, Postman, 7-Zip, Angular CLI, React, XAMPP, Composer, Laravel
- Azure CLI, AWS CLI, Terraform, kubectl, GitHub CLI
- MySQL Workbench, MongoDB Compass, DBeaver, pgAdmin 4, Redis
- IntelliJ IDEA, PyCharm, Android Studio, Sublime Text, Notepad++
- GitHub Desktop, Slack, Insomnia, Windows Terminal, PowerToys

For support and updates, visit:
https://github.com/sparo

MIT License - Free to use and modify
"@

            $txt = New-Object System.Windows.Controls.TextBlock
            $txt.Text = $about
            $txt.FontSize = 13
            $txt.FontFamily = "Segoe UI, Segoe UI Emoji, Segoe UI Symbol"
            $txt.Foreground = $window.Resources["TextColor"]
            $txt.TextWrapping = "Wrap"
            
            $content.Children.Add($txt)
            $controls.mainContent.Content = $content
        }
    }
}

function Update-VersionInfo {
    $controls.txtStatus.Text = "Fetching latest versions..."
    
    $script:versionInfo = @{
        NodeJS = Get-LatestNodeVersion
        Python = Get-LatestPythonVersion
        VSCode = Get-LatestVSCodeVersion
        XAMPP = Get-LatestXAMPPVersion
        Composer = Get-LatestComposerVersion
    }
    
    $content = $controls.mainContent.Content
    if ($content) {
        $txtNode = $content.FindName("txtNodeVersion")
        $txtPython = $content.FindName("txtPythonVersion")
        $txtVSCode = $content.FindName("txtVSCodeVersion")
        $txtXAMPP = $content.FindName("txtXAMPPVersion")
        
        if ($txtNode -and $script:versionInfo.NodeJS) { $txtNode.Text = "Node.js - v$($script:versionInfo.NodeJS.Version)" }
        if ($txtPython -and $script:versionInfo.Python) { $txtPython.Text = "Python - v$($script:versionInfo.Python.Version)" }
        if ($txtVSCode -and $script:versionInfo.VSCode) { $txtVSCode.Text = "VS Code - v$($script:versionInfo.VSCode.Version)" }
        if ($txtXAMPP -and $script:versionInfo.XAMPP) { $txtXAMPP.Text = "XAMPP - v$($script:versionInfo.XAMPP.Version)" }
    }
    
    $controls.txtStatus.Text = "Ready - Latest versions loaded"
}

function Get-AllToolNames {
    return @(
        "Chocolatey","NodeJS","Python","VSCode","Git","Angular","React","Docker","Postman",
        "XAMPP","Composer","Laravel","Chrome","7Zip",
        "AzureCLI","AWSCLI","Terraform","Kubectl","GitHubCLI",
        "MySQLWorkbench","MongoDBCompass","DBeaver","PgAdmin","Redis",
        "IntelliJ","PyCharm","AndroidStudio","Sublime","NotepadPP",
        "GitHubDesktop","Slack","Insomnia","WindowsTerminal","PowerToys"
    )
}
