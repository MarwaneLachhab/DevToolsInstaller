function Install-Profile {
    param([string]$ProfileName)
    
    # Check if already installing
    if ($script:isInstalling) {
        [System.Windows.MessageBox]::Show(
            "An installation is already in progress. Please wait for it to finish.",
            "Installation In Progress",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        ) | Out-Null
        return
    }
    
    $result = [System.Windows.MessageBox]::Show(
        "This will install all tools in the $ProfileName profile.`n`nThis may take several minutes. Continue?",
        "Install Profile",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    
    if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }
    
    # Mark installation as in progress
    $script:isInstalling = $true
    
    $profiles = @{
        Web = @("NodeJS", "VSCode", "Git", "Chrome", "Postman", "Angular", "React", "GitHubCLI")
        PHP = @("Chocolatey","XAMPP", "Composer", "Laravel", "VSCode", "Git", "Postman", "GitHubDesktop")
        Python = @("Python", "VSCode", "Git", "Docker", "Chrome", "AWSCLI", "AzureCLI")
        Full = Get-AllToolNames
    }
    
    if (-not $profiles.ContainsKey($ProfileName)) {
        $script:isInstalling = $false
        [System.Windows.MessageBox]::Show("Unknown profile '$ProfileName'.", "Error",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        return
    }
    
    $tools = $profiles[$ProfileName] | Select-Object -Unique
    $initialCount = $tools.Count
    $tools = $tools | Where-Object {
        if (Test-ToolInstalled -ToolName $_) {
            Write-Log "$_ already installed. Skipping profile reinstall." "INFO"
            $false
        } else {
            $true
        }
    }
    $script:profileInstallTargets = @($tools)
    if ($tools.Count -eq 0) {
        $script:isInstalling = $false
        [System.Windows.MessageBox]::Show(
            "Every tool in the $ProfileName profile is already installed.",
            "Nothing To Install",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information) | Out-Null
        return
    } elseif ($tools.Count -lt $initialCount) {
        Write-Log "Skipped $($initialCount - $tools.Count) already-installed tools from $ProfileName profile." "INFO"
    }
    Ensure-DownloadPath
    if (-not $script:versionInfo.NodeJS) { Update-VersionInfo }
    $controls.txtStatus.Text = "Installing $ProfileName profile..."
    $controls.progressBar.Value = 0

    # Enable cancel button
    $script:cancelRequested = $false
    if ($script:btnCancel) { $script:btnCancel.IsEnabled = $true }

    # Use PowerShell Job for true async execution
    $script:installQueue = [System.Collections.ArrayList]::new()
    foreach ($tool in $tools) {
        [void]$script:installQueue.Add($tool)
    }
    $script:installFailed = [System.Collections.ArrayList]::new()
    $script:installTotal = $tools.Count
    $script:installIndex = 0
    $script:currentJob = $null
    $script:profileName = $ProfileName

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
            $controls.txtStatus.Text = "Profile installation cancelled."
            [System.Windows.MessageBox]::Show("Profile installation was cancelled by the user.", "Installation Cancelled",
                [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            
            $script:isInstalling = $false
            if ($script:btnCancel) { $script:btnCancel.IsEnabled = $false }
            return
        }
        
        # Check if current job is done
        if ($script:currentJob) {
            if ($script:currentJob.State -eq 'Completed') {
                # Capture all output from the job
                $jobOutput = Receive-Job -Job $script:currentJob -ErrorAction SilentlyContinue -ErrorVariable jobErrors
                
                # Display job output in console
                if ($jobOutput) {
                    $jobOutput | ForEach-Object { Write-Host $_ }
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
                
                # Check the last output item for the result boolean
                $jobResult = if ($jobOutput) { ($jobOutput | Where-Object { $_ -is [bool] } | Select-Object -Last 1) } else { $null }
                if ($null -eq $jobResult) { $jobResult = $false }
                if ($jobResult -eq $false) {
                    try {
                        if (Test-ToolInstalled -ToolName $script:currentTool) {
                            Write-Log "$($script:currentTool) appears installed despite job failure. Marking as success." "INFO"
                            $jobResult = $true
                        }
                    } catch {}
                }
                Invalidate-ToolCache -ToolName $script:currentTool
                
                # Only mark as failed if explicitly returned $false (not $null or empty)
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
                # Job still running
                return
            }
        }
        
        # Start next installation or finish
        if ($script:installQueue.Count -eq 0 -and -not $script:currentJob) {
            # All done
            $script:installTimer.Stop()
            $controls.progressBar.Value = 100
            
            $profileMissing = Get-MissingInstalledTools -Tools $script:profileInstallTargets
            if ($profileMissing.Count -gt 0) {
                foreach ($tool in $profileMissing) {
                    if (-not $script:installFailed.Contains($tool)) {
                        [void]$script:installFailed.Add($tool)
                    }
                }
            }
            
            if ($script:installFailed.Count -gt 0) {
                $controls.txtStatus.Text = "$($script:profileName) profile completed with warnings."
                $failedTools = $script:installFailed -join ', '
                Write-Host "`n[WARNING] Profile installation completed with failures for: $failedTools" -ForegroundColor Yellow
                Write-Host "[INFO] Total failed: $($script:installFailed.Count)" -ForegroundColor Cyan
                [System.Windows.MessageBox]::Show(
                    "$($script:profileName) profile completed with warnings. Check logs for: $failedTools.",
                    "Profile Complete (Warnings)",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning) | Out-Null
            } else {
                $controls.txtStatus.Text = "Profile installation complete!"
                Write-Host "`n[SUCCESS] $($script:profileName) profile installed successfully!" -ForegroundColor Green
                [System.Windows.MessageBox]::Show("$($script:profileName) profile installed successfully!", "Success",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            }
            
            $script:isInstalling = $false
            if ($script:btnCancel) { $script:btnCancel.IsEnabled = $false }
            $script:profileInstallTargets = @()
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

# Function to uninstall a tool
