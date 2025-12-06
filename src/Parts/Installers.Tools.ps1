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

function Install-SingleTool {
    param([string]$ToolName)
    
    switch ($ToolName) {
        "Chocolatey" { return Install-Chocolatey }
        "NodeJS" { return Install-NodeJS -VersionInfo $script:versionInfo.NodeJS -DownloadPath $script:downloadPath }
        "Python" { return Install-Python -VersionInfo $script:versionInfo.Python -DownloadPath $script:downloadPath }
        "VSCode" { return Install-VSCode -VersionInfo $script:versionInfo.VSCode -DownloadPath $script:downloadPath }
        "Git" { return Install-ChocoPackage -PackageName "git" }
        "Angular" { return Install-AngularCLI }
        "React" {
            try {
                $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
                if (-not $npmCmd) {
                    Write-Warning "npm command not found. Please install Node.js first."
                    return $false
                }
                $process = Start-Process -FilePath $npmCmd.Source -ArgumentList "install -g create-react-app" -Wait -NoNewWindow -PassThru
                return ($process.ExitCode -eq 0)
            } catch {
                Write-Warning "Failed to install React tooling: $_"
                return $false
            }
        }
        "Docker" { return Install-ChocoPackage -PackageName "docker-desktop" }
        "Postman" { return Install-ChocoPackage -PackageName "postman" }
        "XAMPP" { return Install-XAMPP -VersionInfo $script:versionInfo.XAMPP -DownloadPath $script:downloadPath }
        "Composer" { return Install-Composer -VersionInfo $script:versionInfo.Composer -DownloadPath $script:downloadPath }
        "Laravel" { return Install-LaravelInstaller }
        "Chrome" { return Install-ChocoPackage -PackageName "googlechrome" }
        "7Zip" { return Install-ChocoPackage -PackageName "7zip" }
        "AzureCLI" { return Install-ChocoPackage -PackageName "azure-cli" }
        "AWSCLI" { return Install-ChocoPackage -PackageName "awscli" }
        "Terraform" { return Install-ChocoPackage -PackageName "terraform" }
        "Kubectl" { return Install-ChocoPackage -PackageName "kubernetes-cli" }
        "GitHubCLI" { return Install-ChocoPackage -PackageName "github-cli" }
        "MySQLWorkbench" { return Install-ChocoPackage -PackageName "mysql.workbench" }
        "MongoDBCompass" { return Install-ChocoPackage -PackageName "mongodb-compass" }
        "DBeaver" { return Install-ChocoPackage -PackageName "dbeaver" }
        "PgAdmin" { return Install-ChocoPackage -PackageName "pgadmin4" }
        "Redis" { return Install-ChocoPackage -PackageName "redis-64" }
        "IntelliJ" { return Install-ChocoPackage -PackageName "intellijidea-community" }
        "PyCharm" { return Install-ChocoPackage -PackageName "pycharm-community" }
        "AndroidStudio" { return Install-ChocoPackage -PackageName "androidstudio" }
        "Sublime" { return Install-ChocoPackage -PackageName "sublimetext3" }
        "NotepadPP" { return Install-ChocoPackage -PackageName "notepadplusplus" }
        "GitHubDesktop" { return Install-ChocoPackage -PackageName "github-desktop" }
        "Slack" { return Install-ChocoPackage -PackageName "slack" }
        "Insomnia" { return Install-ChocoPackage -PackageName "insomnia-rest-api-client" }
        "WindowsTerminal" { return Install-ChocoPackage -PackageName "microsoft-windows-terminal" }
        "PowerToys" { return Install-ChocoPackage -PackageName "powertoys" }
        default {
            Write-Warning "No installer registered for $ToolName"
            return $false
        }
    }
}

function Start-Installation {
    # Check if already installing - do this FIRST before any other operations
    if ($script:isInstalling) {
        [System.Windows.MessageBox]::Show(
            "Please wait - an installation or uninstallation is already in progress.`n`nWait for it to complete before starting another operation.",
            "Operation In Progress",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        ) | Out-Null
        return
    }

    # Mark as installing immediately to prevent double-clicks
    $script:isInstalling = $true
    $controls.txtStatus.Text = "Preparing installation..."
    $controls.progressBar.Value = 0

    $content = $controls.mainContent.Content
    Ensure-DownloadPath
    
    # These can be slow - only do if needed
    if (-not $script:versionInfo -or -not $script:versionInfo.NodeJS) { 
        try { Update-VersionInfo } catch { }
    }

    $toolsToInstall = @()

    if ($content.FindName("chkChocolatey").IsChecked) { $toolsToInstall += "Chocolatey" }
    if ($content.FindName("chkNodeJS").IsChecked) { $toolsToInstall += "NodeJS" }
    if ($content.FindName("chkPython").IsChecked) { $toolsToInstall += "Python" }
    if ($content.FindName("chkVSCode").IsChecked) { $toolsToInstall += "VSCode" }
    if ($content.FindName("chkGit").IsChecked) { $toolsToInstall += "Git" }
    if ($content.FindName("chkAngular").IsChecked) { $toolsToInstall += "Angular" }
    if ($content.FindName("chkReact").IsChecked) { $toolsToInstall += "React" }
    if ($content.FindName("chkDocker").IsChecked) { $toolsToInstall += "Docker" }
    if ($content.FindName("chkPostman").IsChecked) { $toolsToInstall += "Postman" }
    if ($content.FindName("chkXAMPP").IsChecked) { $toolsToInstall += "XAMPP" }
    if ($content.FindName("chkComposer").IsChecked) { $toolsToInstall += "Composer" }
    if ($content.FindName("chkLaravel").IsChecked) { $toolsToInstall += "Laravel" }
    if ($content.FindName("chkChrome").IsChecked) { $toolsToInstall += "Chrome" }
    if ($content.FindName("chk7Zip").IsChecked) { $toolsToInstall += "7Zip" }
    if ($content.FindName("chkAzureCLI").IsChecked) { $toolsToInstall += "AzureCLI" }
    if ($content.FindName("chkAWSCLI").IsChecked) { $toolsToInstall += "AWSCLI" }
    if ($content.FindName("chkTerraform").IsChecked) { $toolsToInstall += "Terraform" }
    if ($content.FindName("chkKubectl").IsChecked) { $toolsToInstall += "Kubectl" }
    if ($content.FindName("chkGitHubCLI").IsChecked) { $toolsToInstall += "GitHubCLI" }
    if ($content.FindName("chkMySQLWorkbench").IsChecked) { $toolsToInstall += "MySQLWorkbench" }
    if ($content.FindName("chkMongoDBCompass").IsChecked) { $toolsToInstall += "MongoDBCompass" }
    if ($content.FindName("chkDBeaver").IsChecked) { $toolsToInstall += "DBeaver" }
    if ($content.FindName("chkPgAdmin").IsChecked) { $toolsToInstall += "PgAdmin" }
    if ($content.FindName("chkRedis").IsChecked) { $toolsToInstall += "Redis" }
    if ($content.FindName("chkIntelliJ").IsChecked) { $toolsToInstall += "IntelliJ" }
    if ($content.FindName("chkPyCharm").IsChecked) { $toolsToInstall += "PyCharm" }
    if ($content.FindName("chkAndroidStudio").IsChecked) { $toolsToInstall += "AndroidStudio" }
    if ($content.FindName("chkSublime").IsChecked) { $toolsToInstall += "Sublime" }
    if ($content.FindName("chkNotepadPP").IsChecked) { $toolsToInstall += "NotepadPP" }
    if ($content.FindName("chkGitHubDesktop").IsChecked) { $toolsToInstall += "GitHubDesktop" }
    if ($content.FindName("chkSlack").IsChecked) { $toolsToInstall += "Slack" }
    if ($content.FindName("chkInsomnia").IsChecked) { $toolsToInstall += "Insomnia" }
    if ($content.FindName("chkWindowsTerminal").IsChecked) { $toolsToInstall += "WindowsTerminal" }
    if ($content.FindName("chkPowerToys").IsChecked) { $toolsToInstall += "PowerToys" }

    # IMMEDIATELY deselect only the captured tools - new selections during operation stay selected
    Clear-ToolSelections -ToolNames $toolsToInstall

    # Ensure Chocolatey is present when any Chocolatey-delivered tool is selected
    $chocoBackedSelections = $toolsToInstall | Where-Object { $_ -ne "Chocolatey" -and $script:toolPackageMap.ContainsKey($_) }
    if ($chocoBackedSelections.Count -gt 0 -and -not (Test-ToolInstalled -ToolName "Chocolatey")) {
        $toolsToInstall += "Chocolatey"
    }

    $toolsToInstall = $toolsToInstall | Select-Object -Unique
    $selectedCount = $toolsToInstall.Count
    
    # Check if nothing is selected
    if ($selectedCount -eq 0) {
        $script:isInstalling = $false
        $controls.txtStatus.Text = "Ready"
        [System.Windows.MessageBox]::Show("Please select at least one tool to install.", "No Selection", 
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    
    # Filter to only non-installed tools
    $alreadyInstalled = @()
    $toolsToInstall = $toolsToInstall | Where-Object {
        $tool = $_
        if (Test-ToolInstalled -ToolName $tool) {
            Write-Log "$tool is already installed. Skipping installation." "INFO"
            $alreadyInstalled += $tool
            $false
        } else {
            $true
        }
    }
    
    if ($toolsToInstall.Count -eq 0) {
        $script:isInstalling = $false
        $controls.txtStatus.Text = "Selected tools are already installed."
        [System.Windows.MessageBox]::Show(
            "All selected tools are already installed.`n`nTo uninstall them, use the 'Uninstall Selected Tools' button.",
            "Nothing To Install",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information) | Out-Null
        return
    } elseif ($alreadyInstalled.Count -gt 0) {
        $skippedList = $alreadyInstalled -join ", "
        Write-Log "Skipping already installed: $skippedList" "INFO"
        $controls.txtStatus.Text = "Installing $($toolsToInstall.Count) tools (skipping $($alreadyInstalled.Count) already installed)..."
    }
    
    # Installation will proceed - keep isInstalling = true
    $script:isInstalling = $true

    # Capture config checkboxes to run post-install steps inside background worker
    $doVSCodeContext = $false
    $doAddPaths = $false
    $doXAMPPShortcut = $false
    if ($content.FindName("chkVSCodeContext") -and $content.FindName("chkVSCodeContext").IsChecked) { $doVSCodeContext = $true }
    if ($content.FindName("chkAddPaths") -and $content.FindName("chkAddPaths").IsChecked) { $doAddPaths = $true }
    if ($content.FindName("chkXAMPPShortcut") -and $content.FindName("chkXAMPPShortcut").IsChecked) { $doXAMPPShortcut = $true }

    # Enable cancel button if present
    $script:cancelRequested = $false
    if ($script:btnCancel) { $script:btnCancel.IsEnabled = $true }

    # Use PowerShell Job for true async execution
    $script:installQueue = [System.Collections.ArrayList]::new()
    foreach ($tool in $toolsToInstall) {
        [void]$script:installQueue.Add($tool)
    }
    $script:installFailed = [System.Collections.ArrayList]::new()
    $script:installTotal = $toolsToInstall.Count
    $script:installIndex = 0
    $script:currentJob = $null
    
    # Store config for post-install
    $script:postInstallConfig = @{
        DoVSCodeContext = $doVSCodeContext
        DoAddPaths = $doAddPaths
        DoXAMPPShortcut = $doXAMPPShortcut
        ToolsToInstall = $toolsToInstall
    }

    $script:installTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:installTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    
    $script:installTimer.Add_Tick({
        # Check if cancelled
        if ($script:cancelRequested) {
            if ($script:currentJob) {
                Stop-Job -Job $script:currentJob -ErrorAction SilentlyContinue
                Remove-Job -Job $script:currentJob -Force -ErrorAction SilentlyContinue
                $script:currentJob = $null
            }
            $script:installTimer.Stop()
            
            $controls.progressBar.Value = 100
            $controls.txtStatus.Text = "Installation cancelled."
            [System.Windows.MessageBox]::Show("Installation was cancelled by the user.", "Installation Cancelled",
                [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            
            # Save selections before clearing caches and reloading
            Save-ToolSelections
            
            # Clear caches after cancel
            Clear-AllToolCaches
            
            $script:isInstalling = $false
            if ($script:btnCancel) { $script:btnCancel.IsEnabled = $false }
            try { Load-Page "Tools" } catch { }
            
            # Restore selections made during operation
            Restore-ToolSelections
            return
        }
        
        # Check if current job is done
        if ($script:currentJob) {
            if ($script:currentJob.State -eq 'Completed') {
                # Capture all output from the job
                $jobOutput = Receive-Job -Job $script:currentJob -ErrorAction SilentlyContinue -ErrorVariable jobErrors
                
                # Display job output in console (filter out the boolean return value)
                if ($jobOutput) {
                    $jobOutput | Where-Object { $_ -isnot [bool] } | ForEach-Object { Write-Host $_ }
                }
                
                # Display any errors from the job
                if ($jobErrors) {
                    $jobErrors | ForEach-Object {
                        Write-Warning $_
                        Write-Log "Installation job error for $($script:currentTool): $_" "ERROR"
                    }
                }
                
                Remove-Job -Job $script:currentJob -Force
                $script:currentJob = $null
                
                # Refresh environment PATH after each tool install (pick up changes from installer)
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                
                # Force clear and refresh the Chocolatey package cache
                $script:chocoPackageCache.Clear()
                $script:chocoCacheTimestamp = $null
                Refresh-ChocoPackageCache -Force
                
                # Extract ONLY the boolean result from job output
                $jobResult = $jobOutput | Where-Object { $_ -is [bool] } | Select-Object -Last 1
                if ($null -eq $jobResult) { $jobResult = $false }
                if ($jobResult -eq $false) {
                    try {
                        # Give a moment for filesystem to settle
                        Start-Sleep -Milliseconds 500
                        if (Test-ToolInstalled -ToolName $script:currentTool) {
                            Write-Log "$($script:currentTool) appears installed despite job failure. Marking as success." "INFO"
                            $jobResult = $true
                        }
                    } catch {}
                }
                Invalidate-ToolCache -ToolName $script:currentTool
                # Mark as failed only if explicitly returned $false
                if ($jobResult -eq $false) {
                    [void]$script:installFailed.Add($script:currentTool)
                }
            } elseif ($script:currentJob.State -eq 'Failed') {
                # Get error details
                $jobErrors = Receive-Job -Job $script:currentJob -ErrorAction SilentlyContinue
                if ($jobErrors) {
                    Write-Warning "Job failed for $($script:currentTool): $jobErrors"
                }
                
                [void]$script:installFailed.Add($script:currentTool)
                Remove-Job -Job $script:currentJob -Force
                $script:currentJob = $null
            } else {
                # Job still running, wait
                return
            }
        }
        
        # Start next installation or finish
        if ($script:installQueue.Count -eq 0 -and -not $script:currentJob) {
            # All done
            $script:installTimer.Stop()
            $controls.progressBar.Value = 100
            
            # Post-install configuration
            if ($script:postInstallConfig.DoVSCodeContext -and $script:postInstallConfig.ToolsToInstall -contains "VSCode") {
                try { Add-VSCodeContextMenu | Out-Null } catch { Write-Warning "Failed to add VS Code context menu: $_" }
            }
            if ($script:postInstallConfig.DoAddPaths -and $script:postInstallConfig.ToolsToInstall -contains "XAMPP") {
                try { Add-MySQLToPath | Out-Null; Add-PHPToPath | Out-Null } catch { Write-Warning "Failed to add paths: $_" }
            }
            if ($script:postInstallConfig.DoXAMPPShortcut -and $script:postInstallConfig.ToolsToInstall -contains "XAMPP") {
                try { Set-XAMPPServices | Out-Null } catch { Write-Warning "Failed to configure XAMPP services: $_" }
            }
            
            $missingAfterInstall = Get-MissingInstalledTools -Tools $script:postInstallConfig.ToolsToInstall
            if ($missingAfterInstall.Count -gt 0) {
                foreach ($tool in $missingAfterInstall) {
                    if (-not $script:installFailed.Contains($tool)) {
                        [void]$script:installFailed.Add($tool)
                    }
                }
            }
            
            if ($script:installFailed.Count -gt 0) {
                $controls.txtStatus.Text = "Completed with warnings."
                $failedTools = $script:installFailed -join ', '
                Write-Host "`n[WARNING] Installation completed with failures for: $failedTools" -ForegroundColor Yellow
                Write-Host "[INFO] Total failed: $($script:installFailed.Count)" -ForegroundColor Cyan
                [System.Windows.MessageBox]::Show(
                    "Completed with warnings. Review logs for: $failedTools.",
                    "Installation Complete (Warnings)",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning) | Out-Null
            } else {
                $controls.txtStatus.Text = "Installation complete!"
                Write-Host "`n[SUCCESS] All tools installed successfully!" -ForegroundColor Green
                [System.Windows.MessageBox]::Show("All selected tools have been installed successfully!", "Installation Complete",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            }
            
            # Save current selections before page reload
            Save-ToolSelections
            
            # Clear all caches for accurate detection on next page load
            Clear-AllToolCaches
            
            $script:isInstalling = $false
            if ($script:btnCancel) { $script:btnCancel.IsEnabled = $false }
            try { Load-Page "Tools" } catch { }
            
            # Restore selections that were made during the operation
            Restore-ToolSelections
            
            # Note: Auto health check disabled - it was causing UI freeze
            # Users can manually run health check from the Health tab
            return
        }
        
        # Start next tool installation
        if ($script:installQueue.Count -gt 0 -and -not $script:currentJob) {
            $script:currentTool = $script:installQueue[0]
            $script:installQueue.RemoveAt(0)
            $script:installIndex++
            
            $controls.txtStatus.Text = "Installing $($script:currentTool) ($($script:installIndex)/$($script:installTotal))..."
            $controls.progressBar.Value = ($script:installIndex / $script:installTotal) * 100
            
            # Start job with full context
            # Note: $PSScriptRoot here is the Parts folder, so we need to go up one level to get to src
            $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules"
            $scriptRoot = $PSScriptRoot
            $versionInfo = $script:versionInfo
            $downloadPath = $script:downloadPath
            
            $script:currentJob = Start-Job -ScriptBlock {
                param($ToolName, $ModulePath, $ScriptRoot, $VersionInfo, $DownloadPath)
                
                # Set working directory
                Set-Location $ScriptRoot
                $env:INSTALLER_LOG_PATH = Join-Path $ScriptRoot "Logs"
                $env:INSTALLER_SUPPRESS_CONSOLE = "1"
                $ProgressPreference = 'SilentlyContinue'
                
                # Import all required modules
                Import-Module (Join-Path $ModulePath "Configuration.psm1") -Force -ErrorAction Stop
                Import-Module (Join-Path $ModulePath "VersionFetcher.psm1") -Force -ErrorAction Stop
                Import-Module (Join-Path $ModulePath "Installer.psm1") -Force -ErrorAction Stop
                
                # Define installation logic (mirroring Install-SingleTool)
                $result = $false
                switch ($ToolName) {
                    "Chocolatey" { $result = Install-Chocolatey }
                    "NodeJS" { $result = Install-NodeJS -VersionInfo $VersionInfo.NodeJS -DownloadPath $DownloadPath }
                    "Python" { $result = Install-Python -VersionInfo $VersionInfo.Python -DownloadPath $DownloadPath }
                    "VSCode" { $result = Install-VSCode -VersionInfo $VersionInfo.VSCode -DownloadPath $DownloadPath }
                    "Git" { $result = Install-ChocoPackage -PackageName "git" }
                    "Angular" { $result = Install-AngularCLI }
                    "React" {
                        try {
                            $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
                            if (-not $npmCmd) {
                                Write-Warning "npm command not found. Please install Node.js first."
                                $result = $false
                            } else {
                                $process = Start-Process -FilePath $npmCmd.Source -ArgumentList "install -g create-react-app" -Wait -NoNewWindow -PassThru
                                $result = ($process.ExitCode -eq 0)
                            }
                        } catch { $result = $false }
                    }
                    "Docker" { $result = Install-ChocoPackage -PackageName "docker-desktop" }
                    "Postman" { $result = Install-ChocoPackage -PackageName "postman" }
                    "XAMPP" { $result = Install-XAMPP -VersionInfo $VersionInfo.XAMPP -DownloadPath $DownloadPath }
                    "Composer" { $result = Install-Composer -VersionInfo $VersionInfo.Composer -DownloadPath $DownloadPath }
                    "Laravel" { $result = Install-LaravelInstaller }
                    "Chrome" { $result = Install-ChocoPackage -PackageName "googlechrome" }
                    "7Zip" { $result = Install-ChocoPackage -PackageName "7zip" }
                    "AzureCLI" { $result = Install-ChocoPackage -PackageName "azure-cli" }
                    "AWSCLI" { $result = Install-ChocoPackage -PackageName "awscli" }
                    "Terraform" { $result = Install-ChocoPackage -PackageName "terraform" }
                    "Kubectl" { $result = Install-ChocoPackage -PackageName "kubernetes-cli" }
                    "GitHubCLI" { $result = Install-ChocoPackage -PackageName "github-cli" }
                    "MySQLWorkbench" { $result = Install-ChocoPackage -PackageName "mysql.workbench" }
                    "MongoDBCompass" { $result = Install-ChocoPackage -PackageName "mongodb-compass" }
                    "DBeaver" { $result = Install-ChocoPackage -PackageName "dbeaver" }
                    "PgAdmin" { $result = Install-ChocoPackage -PackageName "pgadmin4" }
                    "Redis" { $result = Install-ChocoPackage -PackageName "redis-64" }
                    "IntelliJ" { $result = Install-ChocoPackage -PackageName "intellijidea-community" }
                    "PyCharm" { $result = Install-ChocoPackage -PackageName "pycharm-community" }
                    "AndroidStudio" { $result = Install-ChocoPackage -PackageName "androidstudio" }
                    "Sublime" { $result = Install-ChocoPackage -PackageName "sublimetext3" }
                    "NotepadPP" { $result = Install-ChocoPackage -PackageName "notepadplusplus" }
                    "GitHubDesktop" { $result = Install-ChocoPackage -PackageName "github-desktop" }
                    "Slack" { $result = Install-ChocoPackage -PackageName "slack" }
                    "Insomnia" { $result = Install-ChocoPackage -PackageName "insomnia-rest-api-client" }
                    "WindowsTerminal" { $result = Install-ChocoPackage -PackageName "microsoft-windows-terminal" }
                    "PowerToys" { $result = Install-ChocoPackage -PackageName "powertoys" }
                    default { $result = $false }
                }
                return $result
            } -ArgumentList $script:currentTool, $modulePath, $scriptRoot, $versionInfo, $downloadPath
        }
    })
    
    $script:installTimer.Start()
}

