function Start-Uninstallation {
    param([string]$ToolName)
    
    # Check if already running an operation - do this FIRST
    if ($script:isInstalling) {
        [System.Windows.MessageBox]::Show(
            "Please wait - an installation or uninstallation is already in progress.`n`nWait for it to complete before starting another operation.",
            "Operation In Progress",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        ) | Out-Null
        return
    }
    
    $script:isInstalling = $true
    $controls.txtStatus.Text = "Uninstalling $ToolName..."
    $controls.progressBar.Value = 25
    
    # Clear cache for fresh state (no force refresh - just clear)
    try { 
        $script:chocoPackageCache.Clear()
        $script:chocoCacheTimestamp = $null
    } catch { }
    
    # Correct path: Modules is in parent folder (src), not in Parts
    $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules"
    $scriptRoot = Split-Path $PSScriptRoot -Parent
    $toolPackageMapCopy = $script:toolPackageMap.Clone()
    
    # Start background job for async uninstallation
    $script:uninstallJob = Start-Job -ScriptBlock {
        param($ToolName, $ModulePath, $ScriptRoot, $ToolPackageMap)
        
        Set-Location $ScriptRoot
        $env:INSTALLER_LOG_PATH = Join-Path $ScriptRoot "Logs"
        $env:INSTALLER_SUPPRESS_CONSOLE = "1"
        $ProgressPreference = 'SilentlyContinue'
        
        Import-Module (Join-Path $ModulePath "Installer.psm1") -Force -ErrorAction Stop
        
        $result = $false
        
        # Check if tool is in the package map (Chocolatey-based)
        if ($ToolPackageMap.ContainsKey($ToolName)) {
            $packageName = $ToolPackageMap[$ToolName]
            if ($packageName) {
                # Use the new Uninstall-ChocoPackage function
                $result = Uninstall-ChocoPackage -PackageName $packageName
            }
        } else {
            # Handle non-Chocolatey tools
            switch ($ToolName) {
                "NodeJS" {
                    Write-Log "Manual uninstall required for Node.js via Windows Settings." "INFO"
                    $result = $false
                }
                "Python" {
                    Write-Log "Manual uninstall required for Python via Windows Settings." "INFO"
                    $result = $false
                }
                "VSCode" {
                    Write-Log "Manual uninstall required for Visual Studio Code via Windows Settings." "INFO"
                    $result = $false
                }
                "Angular" {
                    try {
                        Write-Log "Uninstalling Angular CLI"
                        $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
                        if (-not $npmCmd) {
                            Write-Log "npm command not found." "ERROR"
                            $result = $false
                        } else {
                            & $npmCmd.Source uninstall -g @angular/cli 2>&1 | Out-Null
                            $result = $true
                            Write-Log "Angular CLI uninstalled successfully" "SUCCESS"
                        }
                    } catch {
                        Write-Log "Failed to uninstall Angular CLI: $($_.Exception.Message)" "ERROR"
                        $result = $false
                    }
                }
                "React" {
                    try {
                        Write-Log "Uninstalling Create React App"
                        $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
                        if (-not $npmCmd) {
                            Write-Log "npm command not found." "ERROR"
                            $result = $false
                        } else {
                            & $npmCmd.Source uninstall -g create-react-app 2>&1 | Out-Null
                            $result = $true
                            Write-Log "Create React App uninstalled successfully" "SUCCESS"
                        }
                    } catch {
                        Write-Log "Failed to uninstall React: $($_.Exception.Message)" "ERROR"
                        $result = $false
                    }
                }
                "Composer" {
                    Write-Log "Manual uninstall required for Composer." "INFO"
                    $result = $false
                }
                "Laravel" {
                    try {
                        Write-Log "Uninstalling Laravel Installer"
                        & composer global remove laravel/installer 2>&1 | Out-Null
                        $result = $true
                        Write-Log "Laravel Installer uninstalled successfully" "SUCCESS"
                    } catch {
                        Write-Log "Failed to uninstall Laravel: $($_.Exception.Message)" "ERROR"
                        $result = $false
                    }
                }
                default {
                    Write-Log "Uninstall not supported for $ToolName" "ERROR"
                    $result = $false
                }
            }
        }
        
        return $result
    } -ArgumentList $ToolName, $modulePath, $scriptRoot, $toolPackageMapCopy
    
    # Create timer for polling job status (async - won't freeze UI)
    $script:uninstallTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:uninstallTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    $script:uninstallToolName = $ToolName
    
    $script:uninstallTimer.Add_Tick({
        if (-not $script:uninstallJob) {
            $script:uninstallTimer.Stop()
            $script:isInstalling = $false
            return
        }
        
        if ($script:uninstallJob.State -eq 'Completed') {
            $jobOutput = Receive-Job -Job $script:uninstallJob -ErrorAction SilentlyContinue
            Remove-Job -Job $script:uninstallJob -Force
            $script:uninstallJob = $null
            $script:uninstallTimer.Stop()
            
            # Extract boolean result
            $jobResult = $jobOutput | Where-Object { $_ -is [bool] } | Select-Object -Last 1
            if ($null -eq $jobResult) { $jobResult = $false }
            
            # Force refresh all caches for accurate tool detection
            Clear-AllToolCaches
            
            $controls.progressBar.Value = 100
            $script:isInstalling = $false
            
            if ($jobResult -eq $true) {
                $controls.txtStatus.Text = "$($script:uninstallToolName) uninstalled successfully!"
                Write-Log "$($script:uninstallToolName) uninstall completed (UI confirmation)" "SUCCESS"
                [System.Windows.MessageBox]::Show(
                    "$($script:uninstallToolName) has been uninstalled successfully.",
                    "Uninstall Complete",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Information
                ) | Out-Null
            } else {
                $controls.txtStatus.Text = "Failed to uninstall $($script:uninstallToolName)"
                Write-Log "$($script:uninstallToolName) uninstall failed at UI stage. See earlier log entries for details." "ERROR"
                [System.Windows.MessageBox]::Show(
                    "Failed to uninstall $($script:uninstallToolName). Check the console output for details.",
                    "Uninstall Failed",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                ) | Out-Null
            }
            
            # Save selections, refresh page, restore selections
            Save-ToolSelections
            Load-Page "Tools"
            Restore-ToolSelections
            
        } elseif ($script:uninstallJob.State -eq 'Failed') {
            $jobErrors = Receive-Job -Job $script:uninstallJob -ErrorAction SilentlyContinue
            Remove-Job -Job $script:uninstallJob -Force
            $script:uninstallJob = $null
            $script:uninstallTimer.Stop()
            
            $controls.progressBar.Value = 100
            $script:isInstalling = $false
            $controls.txtStatus.Text = "Uninstall failed for $($script:uninstallToolName)"
            
            [System.Windows.MessageBox]::Show(
                "Uninstall failed for $($script:uninstallToolName). Check the console output for details.",
                "Uninstall Failed",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            ) | Out-Null
            
            # Save selections, refresh page, restore selections
            Save-ToolSelections
            Load-Page "Tools"
            Restore-ToolSelections
        } else {
            # Job still running, update progress
            $controls.progressBar.Value = [Math]::Min(90, $controls.progressBar.Value + 5)
        }
    })
    
    $script:uninstallTimer.Start()
}

# Batch uninstall selected tools
function Start-SelectedUninstallation {
    # Check if already running an operation - do this FIRST
    if ($script:isInstalling) {
        [System.Windows.MessageBox]::Show(
            "Please wait - an installation or uninstallation is already in progress.`n`nWait for it to complete before starting another operation.",
            "Operation In Progress",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        ) | Out-Null
        return
    }
    
    $content = $controls.mainContent.Content
    
    # Collect selected tools (same as Start-Installation)
    $selectedTools = @()
    if ($content.FindName("chkChocolatey").IsChecked) { $selectedTools += "Chocolatey" }
    if ($content.FindName("chkNodeJS").IsChecked) { $selectedTools += "NodeJS" }
    if ($content.FindName("chkPython").IsChecked) { $selectedTools += "Python" }
    if ($content.FindName("chkVSCode").IsChecked) { $selectedTools += "VSCode" }
    if ($content.FindName("chkGit").IsChecked) { $selectedTools += "Git" }
    if ($content.FindName("chkAngular").IsChecked) { $selectedTools += "Angular" }
    if ($content.FindName("chkReact").IsChecked) { $selectedTools += "React" }
    if ($content.FindName("chkDocker").IsChecked) { $selectedTools += "Docker" }
    if ($content.FindName("chkPostman").IsChecked) { $selectedTools += "Postman" }
    if ($content.FindName("chkXAMPP").IsChecked) { $selectedTools += "XAMPP" }
    if ($content.FindName("chkComposer").IsChecked) { $selectedTools += "Composer" }
    if ($content.FindName("chkLaravel").IsChecked) { $selectedTools += "Laravel" }
    if ($content.FindName("chkChrome").IsChecked) { $selectedTools += "Chrome" }
    if ($content.FindName("chk7Zip").IsChecked) { $selectedTools += "7Zip" }
    if ($content.FindName("chkAzureCLI").IsChecked) { $selectedTools += "AzureCLI" }
    if ($content.FindName("chkAWSCLI").IsChecked) { $selectedTools += "AWSCLI" }
    if ($content.FindName("chkTerraform").IsChecked) { $selectedTools += "Terraform" }
    if ($content.FindName("chkKubectl").IsChecked) { $selectedTools += "Kubectl" }
    if ($content.FindName("chkGitHubCLI").IsChecked) { $selectedTools += "GitHubCLI" }
    if ($content.FindName("chkMySQLWorkbench").IsChecked) { $selectedTools += "MySQLWorkbench" }
    if ($content.FindName("chkMongoDBCompass").IsChecked) { $selectedTools += "MongoDBCompass" }
    if ($content.FindName("chkDBeaver").IsChecked) { $selectedTools += "DBeaver" }
    if ($content.FindName("chkPgAdmin").IsChecked) { $selectedTools += "PgAdmin" }
    if ($content.FindName("chkRedis").IsChecked) { $selectedTools += "Redis" }
    if ($content.FindName("chkIntelliJ").IsChecked) { $selectedTools += "IntelliJ" }
    if ($content.FindName("chkPyCharm").IsChecked) { $selectedTools += "PyCharm" }
    if ($content.FindName("chkAndroidStudio").IsChecked) { $selectedTools += "AndroidStudio" }
    if ($content.FindName("chkSublime").IsChecked) { $selectedTools += "Sublime" }
    if ($content.FindName("chkNotepadPP").IsChecked) { $selectedTools += "NotepadPP" }
    if ($content.FindName("chkGitHubDesktop").IsChecked) { $selectedTools += "GitHubDesktop" }
    if ($content.FindName("chkSlack").IsChecked) { $selectedTools += "Slack" }
    if ($content.FindName("chkInsomnia").IsChecked) { $selectedTools += "Insomnia" }
    if ($content.FindName("chkWindowsTerminal").IsChecked) { $selectedTools += "WindowsTerminal" }
    if ($content.FindName("chkPowerToys").IsChecked) { $selectedTools += "PowerToys" }
    
    # Check if nothing is selected
    if ($selectedTools.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please select at least one tool to uninstall.", "No Selection", 
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    
    # IMMEDIATELY deselect only the captured tools - new selections during operation stay selected
    Clear-ToolSelections -ToolNames $selectedTools
    
    # Filter to only installed tools that can be uninstalled
    $notInstalled = @()
    $noAutoUninstall = @()
    $toolsToUninstall = $selectedTools | Where-Object {
        $tool = $_
        $isInstalled = Test-ToolInstalled -ToolName $tool
        $canUninstall = Supports-Uninstall -ToolName $tool
        if (-not $isInstalled) {
            Write-Log "$tool is not installed. Skipping uninstall." "INFO"
            $notInstalled += $tool
            $false
        } elseif (-not $canUninstall) {
            Write-Log "$tool does not support automated uninstall. Skipping." "INFO"
            $noAutoUninstall += $tool
            $false
        } else {
            $true
        }
    }
    
    if ($toolsToUninstall.Count -eq 0) {
        $controls.txtStatus.Text = "No tools to uninstall."
        $message = "No selected tools can be uninstalled."
        if ($notInstalled.Count -gt 0) {
            $message += "`n`nNot installed: $($notInstalled -join ', ')"
        }
        if ($noAutoUninstall.Count -gt 0) {
            $message += "`n`nManual removal required: $($noAutoUninstall -join ', ')"
        }
        [System.Windows.MessageBox]::Show(
            $message,
            "Nothing To Uninstall",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
        return
    } elseif ($notInstalled.Count -gt 0) {
        Write-Log "Skipping not installed: $($notInstalled -join ', ')" "INFO"
    }
    
    # Confirm uninstall
    $toolList = $toolsToUninstall -join ", "
    $confirmResult = [System.Windows.MessageBox]::Show(
        "Are you sure you want to uninstall the following tools?`n`n$toolList",
        "Confirm Uninstall",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    
    if ($confirmResult -ne [System.Windows.MessageBoxResult]::Yes) {
        return
    }
    
    # Initialize batch uninstall state
    $script:isInstalling = $true
    $script:uninstallQueue = [System.Collections.ArrayList]@($toolsToUninstall)
    $script:uninstallTotal = $toolsToUninstall.Count
    $script:uninstallIndex = 0
    $script:uninstallSuccessCount = 0
    $script:uninstallFailCount = 0
    $script:uninstallFailedTools = @()
    
    $controls.txtStatus.Text = "Preparing to uninstall $($script:uninstallTotal) tools..."
    $controls.progressBar.Value = 0
    
    # Start the batch uninstall timer
    $script:batchUninstallTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:batchUninstallTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    
    $script:batchUninstallTimer.Add_Tick({
        # Check if a job is running
        if ($script:uninstallJob) {
            if ($script:uninstallJob.State -eq 'Completed') {
                $jobOutput = Receive-Job -Job $script:uninstallJob -ErrorAction SilentlyContinue
                Remove-Job -Job $script:uninstallJob -Force
                $script:uninstallJob = $null
                
                # Extract boolean result
                $jobResult = $jobOutput | Where-Object { $_ -is [bool] } | Select-Object -Last 1
                if ($null -eq $jobResult) { $jobResult = $false }
                
                # Update counters
                if ($jobResult -eq $true) {
                    $script:uninstallSuccessCount++
                    Write-Log "$($script:currentUninstallTool) uninstalled successfully" "SUCCESS"
                } else {
                    $script:uninstallFailCount++
                    $script:uninstallFailedTools += $script:currentUninstallTool
                    Write-Log "$($script:currentUninstallTool) failed to uninstall" "ERROR"
                }
                
                # Clear caches for this tool
                $script:chocoPackageCache.Clear()
                $script:chocoCacheTimestamp = $null
                Invalidate-ToolCache -ToolName $script:currentUninstallTool
                
            } elseif ($script:uninstallJob.State -eq 'Failed') {
                Receive-Job -Job $script:uninstallJob -ErrorAction SilentlyContinue
                Remove-Job -Job $script:uninstallJob -Force
                $script:uninstallJob = $null
                $script:uninstallFailCount++
                $script:uninstallFailedTools += $script:currentUninstallTool
                Write-Log "$($script:currentUninstallTool) uninstall job failed" "ERROR"
            } else {
                # Job still running, update progress indicator
                $baseProgress = ($script:uninstallIndex / $script:uninstallTotal) * 100
                $controls.progressBar.Value = [Math]::Min($baseProgress + 10, ($script:uninstallIndex + 1) / $script:uninstallTotal * 100 - 5)
                return
            }
        }
        
        # Process next tool in queue
        if ($script:uninstallQueue.Count -gt 0 -and -not $script:uninstallJob) {
            $script:currentUninstallTool = $script:uninstallQueue[0]
            $script:uninstallQueue.RemoveAt(0)
            $script:uninstallIndex++
            
            $controls.txtStatus.Text = "Uninstalling $($script:currentUninstallTool) ($($script:uninstallIndex)/$($script:uninstallTotal))..."
            $controls.progressBar.Value = (($script:uninstallIndex - 1) / $script:uninstallTotal) * 100
            
            # Start uninstall job
            $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules"
            $scriptRoot = Split-Path $PSScriptRoot -Parent
            $toolPackageMapCopy = $script:toolPackageMap.Clone()
            $currentTool = $script:currentUninstallTool
            
            $script:uninstallJob = Start-Job -ScriptBlock {
                param($ToolName, $ModulePath, $ScriptRoot, $ToolPackageMap)
                
                Set-Location $ScriptRoot
                $env:INSTALLER_LOG_PATH = Join-Path $ScriptRoot "Logs"
                $env:INSTALLER_SUPPRESS_CONSOLE = "1"
                $ProgressPreference = 'SilentlyContinue'
                
                Import-Module (Join-Path $ModulePath "Installer.psm1") -Force -ErrorAction Stop
                
                $result = $false
                
                # Check if tool is in the package map (Chocolatey-based)
                if ($ToolPackageMap.ContainsKey($ToolName)) {
                    $packageName = $ToolPackageMap[$ToolName]
                    if ($packageName) {
                        $result = Uninstall-ChocoPackage -PackageName $packageName
                    }
                } else {
                    # Handle non-Chocolatey tools
                    switch ($ToolName) {
                        "Angular" {
                            try {
                                Write-Log "Uninstalling Angular CLI"
                                $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
                                if ($npmCmd) {
                                    & $npmCmd.Source uninstall -g @angular/cli 2>&1 | Out-Null
                                    $result = $true
                                    Write-Log "Angular CLI uninstalled successfully" "SUCCESS"
                                }
                            } catch { $result = $false }
                        }
                        "React" {
                            try {
                                Write-Log "Uninstalling Create React App"
                                $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
                                if ($npmCmd) {
                                    & $npmCmd.Source uninstall -g create-react-app 2>&1 | Out-Null
                                    $result = $true
                                    Write-Log "Create React App uninstalled successfully" "SUCCESS"
                                }
                            } catch { $result = $false }
                        }
                        "Laravel" {
                            try {
                                Write-Log "Uninstalling Laravel Installer"
                                & composer global remove laravel/installer 2>&1 | Out-Null
                                $result = $true
                                Write-Log "Laravel Installer uninstalled successfully" "SUCCESS"
                            } catch { $result = $false }
                        }
                        default { $result = $false }
                    }
                }
                
                return $result
            } -ArgumentList $currentTool, $modulePath, $scriptRoot, $toolPackageMapCopy
            
        } elseif ($script:uninstallQueue.Count -eq 0 -and -not $script:uninstallJob) {
            # All done
            $script:batchUninstallTimer.Stop()
            $script:isInstalling = $false
            $controls.progressBar.Value = 100
            
            # Clear all caches for accurate detection
            Clear-AllToolCaches
            
            # Show summary
            $summaryMessage = "Uninstall complete!`n`n"
            $summaryMessage += "Successfully uninstalled: $($script:uninstallSuccessCount)`n"
            $summaryMessage += "Failed: $($script:uninstallFailCount)"
            if ($script:uninstallFailedTools.Count -gt 0) {
                $summaryMessage += "`n`nFailed tools: $($script:uninstallFailedTools -join ', ')"
            }
            
            $controls.txtStatus.Text = "Uninstall complete: $($script:uninstallSuccessCount) succeeded, $($script:uninstallFailCount) failed"
            
            $icon = if ($script:uninstallFailCount -eq 0) { 
                [System.Windows.MessageBoxImage]::Information 
            } else { 
                [System.Windows.MessageBoxImage]::Warning 
            }
            
            [System.Windows.MessageBox]::Show(
                $summaryMessage,
                "Uninstall Complete",
                [System.Windows.MessageBoxButton]::OK,
                $icon
            ) | Out-Null
            
            # Save selections, refresh page, restore selections
            Save-ToolSelections
            Load-Page "Tools"
            Restore-ToolSelections
        }
    })
    
    $script:batchUninstallTimer.Start()
}