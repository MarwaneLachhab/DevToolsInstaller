function Get-HealthCheckResults {
    param(
        [scriptblock]$OnProgress
    )
    $checks = @(
        @{
            Component = "Administrator Mode"
            Category = "System"
            TestScript = { Test-AdminRights }
            SuccessDetail = "Running elevated"
            FailureDetail = "Not running with admin rights"
            Recommendation = "Restart Dev Tools Installer as Administrator."
        },
        @{
            Component = "Chocolatey"
            Category = "Package Manager"
            Command = "choco"
            VersionArgs = @("--version")
            Recommendation = "Install Chocolatey from the Tools tab."
        },
        @{
            Component = "Node.js"
            Category = "Core Runtime"
            Command = "node"
            VersionPattern = "v([\d\.]+)"
            Recommendation = "Install Node.js from the Tools tab."
        },
        @{
            Component = "Python"
            Category = "Core Runtime"
            Command = "python"
            VersionPattern = "Python ([\d\.]+)"
            Recommendation = "Install Python from the Tools tab."
        },
        @{
            Component = "Git"
            Category = "Core Tools"
            Command = "git"
            VersionArgs = @("--version")
            Recommendation = "Install Git from the Tools tab."
        },
        @{
            Component = "VS Code"
            Category = "IDE"
            Command = "code"
            SkipVersion = $true  # Don't run code --version as it can open VS Code window
            Recommendation = "Install VS Code from the Tools tab."
        },
        @{
            Component = "Docker"
            Category = "Containers"
            Command = "docker"
            VersionArgs = @("--version")
            Recommendation = "Install Docker Desktop from the Tools tab."
        },
        @{
            Component = "Angular CLI"
            Category = "Frameworks"
            Command = "ng"
            VersionArgs = @("--version")
            Recommendation = "Install Angular CLI from the Tools tab."
        },
        @{
            Component = "Composer"
            Category = "PHP Tooling"
            Command = "composer"
            VersionArgs = @("--version")
            Recommendation = "Install Composer from the Tools tab."
        },
        @{
            Component = "Laravel Installer"
            Category = "PHP Tooling"
            Command = "laravel"
            VersionPattern = "Laravel Installer ([\d\.]+)"
            Recommendation = "Install Laravel Installer via Composer using the Tools tab."
        },
        @{
            Component = "Azure CLI"
            Category = "Cloud"
            Command = "az"
            VersionArgs = @("--version")
            Recommendation = "Install Azure CLI from the Tools tab."
        },
        @{
            Component = "AWS CLI"
            Category = "Cloud"
            Command = "aws"
            VersionArgs = @("--version")
            Recommendation = "Install AWS CLI from the Tools tab."
        },
        @{
            Component = "Terraform"
            Category = "DevOps"
            Command = "terraform"
            VersionArgs = @("--version")
            Recommendation = "Install Terraform from the Tools tab."
        },
        @{
            Component = "kubectl"
            Category = "DevOps"
            Command = "kubectl"
            VersionArgs = @("version", "--client=true", "--short")
            Recommendation = "Install Kubernetes CLI from the Tools tab."
        },
        @{
            Component = "GitHub CLI"
            Category = "Collaboration"
            Command = "gh"
            VersionArgs = @("--version")
            Recommendation = "Install GitHub CLI from the Tools tab."
        },
        @{
            Component = "PHP in PATH"
            Category = "Environment"
            TestScript = {
                ($env:Path -split ';') -match "xampp\\php" | Select-Object -First 1
            }
            SuccessDetail = "PHP detected in PATH"
            FailureDetail = "PHP not detected in PATH"
            Recommendation = "Enable 'Add MySQL/PHP to PATH' during installation."
        },
        @{
            Component = "MySQL in PATH"
            Category = "Environment"
            TestScript = {
                ($env:Path -split ';') -match "xampp\\mysql\\bin" | Select-Object -First 1
            }
            SuccessDetail = "MySQL detected in PATH"
            FailureDetail = "MySQL not detected in PATH"
            Recommendation = "Enable 'Add MySQL/PHP to PATH' during installation."
        }
    )
    
    $results = @()
    $totalChecks = $checks.Count
    $index = 0
    foreach ($check in $checks) {
        $index++
        if ($OnProgress) {
            try {
                & $OnProgress -ArgumentList $check.Component, $index, $totalChecks
            } catch {
                # Ignore progress callback failures to keep scan running
            }
        }
        
        $isHealthy = $false
        $details = $check.FailureDetail
        try {
            if ($check.TestScript) {
                $isHealthy = [bool](& $check.TestScript)
            } elseif ($check.Command) {
                $cmd = Get-Command -Name $check.Command -ErrorAction SilentlyContinue -CommandType Application
                if ($cmd) {
                    $isHealthy = $true
                }
            }
        } catch {
            $isHealthy = $false
            $details = "Error: $($_.Exception.Message)"
        }
        
        if ($isHealthy) {
            if ($check.Command -and -not $check.SkipVersion) {
                $version = Get-VersionFromCommand -Command $check.Command -Arguments $check.VersionArgs -Pattern $check.VersionPattern
                if ($version) {
                    $details = "Detected v$version"
                } elseif ($check.SuccessDetail) {
                    $details = $check.SuccessDetail
                } else {
                    $details = "Detected"
                }
            } elseif ($check.SuccessDetail) {
                $details = $check.SuccessDetail
            } else {
                $details = "Detected"
            }
        } elseif (-not [string]::IsNullOrWhiteSpace($check.FailureDetail)) {
            $details = $check.FailureDetail
        }
        
        $results += [pscustomobject]@{
            Component = $check.Component
            Category = $check.Category
            Status = if ($isHealthy) { "Healthy" } else { "Action Needed" }
            Details = $details
            Recommendation = if ($isHealthy) { "No action required." } else { $check.Recommendation }
        }
    }
    
    return $results
}

function Render-HealthResults {
    param([array]$Results)
    
    $content = $controls.mainContent.Content
    if (-not $content) { return }
    
    $listView = $content.FindName("lvHealthResults")
    if ($listView) {
        $listView.ItemsSource = $null
        $listView.ItemsSource = $Results
    }
    
    $total = if ($Results) { $Results.Count } else { 0 }
    $healthy = if ($Results) { ($Results | Where-Object { $_.Status -eq "Healthy" }).Count } else { 0 }
    $issues = $total - $healthy
    $score = if ($total -gt 0) { [math]::Round(($healthy / $total) * 100) } else { 0 }
    
    $txtScore = $content.FindName("txtHealthScore")
    if ($txtScore) { $txtScore.Text = "{0}%" -f $score }
    
    $txtSummary = $content.FindName("txtHealthSummary")
    if ($txtSummary) {
        $txtSummary.Text = if ($total -eq 0) {
            "No scans completed yet."
        } elseif ($issues -eq 0) {
            "All $total checks look good."
        } else {
            "$issues issues detected across $total checks."
        }
    }
    
    $txtLast = $content.FindName("txtHealthLastScan")
    if ($txtLast -and $script:lastHealthRun) {
        $txtLast.Text = $script:lastHealthRun.ToString("MMM dd, HH:mm")
    }
    
    $txtIssues = $content.FindName("txtHealthIssues")
    if ($txtIssues) {
        $txtIssues.Text = "Issues detected: $issues"
    }
}

function Invoke-HealthCheck {
    param([switch]$Silent)
    
    # Disable buttons and show loading state
    if (-not $Silent) {
        $content = $controls.mainContent.Content
        $runButton = if ($content) { $content.FindName("btnRunHealthCheck") } else { $null }
        $exportButton = if ($content) { $content.FindName("btnExportHealthReport") } else { $null }
        
        if ($runButton) { $runButton.IsEnabled = $false }
        if ($exportButton) { $exportButton.IsEnabled = $false }
        
        if ($controls.txtStatus) { $controls.txtStatus.Text = "Running health scan..." }
        
        if ($content) {
            $txtSummary = $content.FindName("txtHealthSummary")
            if ($txtSummary) { $txtSummary.Text = "Running diagnostics..." }
            $txtScore = $content.FindName("txtHealthScore")
            if ($txtScore) { $txtScore.Text = "--%" }
        }
    }
    
    # Create a runspace to run health check in background
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()
    
    # Pass script root path to runspace
    $scriptRoot = $PSScriptRoot
    $runspace.SessionStateProxy.SetVariable("ScriptRoot", $scriptRoot)
    
    $powershell = [powershell]::Create()
    $powershell.Runspace = $runspace
    
    # Script to run in background - replicates Get-HealthCheckResults logic
    $script = {
        param($ScriptRoot)
        
        # Define checks inline to avoid module loading issues
        $checks = @(
            @{ Component = "Node.js"; Category = "Core Runtime"; Command = "node"; VersionArgs = @("--version") },
            @{ Component = "npm"; Category = "Core Runtime"; Command = "npm"; VersionArgs = @("--version") },
            @{ Component = "Python"; Category = "Core Runtime"; Command = "python"; VersionArgs = @("--version") },
            @{ Component = "Git"; Category = "Core Tools"; Command = "git"; VersionArgs = @("--version") },
            @{ Component = "VS Code"; Category = "IDE"; Command = "code"; SkipVersion = $true },
            @{ Component = "Docker"; Category = "Containers"; Command = "docker"; VersionArgs = @("--version") },
            @{ Component = "Angular CLI"; Category = "Frameworks"; Command = "ng"; VersionArgs = @("--version") },
            @{ Component = "Composer"; Category = "PHP Tooling"; Command = "composer"; VersionArgs = @("--version") },
            @{ Component = "Azure CLI"; Category = "Cloud"; Command = "az"; VersionArgs = @("--version") },
            @{ Component = "AWS CLI"; Category = "Cloud"; Command = "aws"; VersionArgs = @("--version") },
            @{ Component = "Terraform"; Category = "Infrastructure"; Command = "terraform"; VersionArgs = @("--version") },
            @{ Component = "kubectl"; Category = "Kubernetes"; Command = "kubectl"; VersionArgs = @("version","--client","--short") },
            @{ Component = "Helm"; Category = "Kubernetes"; Command = "helm"; VersionArgs = @("version","--short") },
            @{ Component = "Go"; Category = "Core Runtime"; Command = "go"; VersionArgs = @("version") },
            @{ Component = "Rust/Cargo"; Category = "Core Runtime"; Command = "cargo"; VersionArgs = @("--version") },
            @{ Component = "Java"; Category = "Core Runtime"; Command = "java"; VersionArgs = @("-version") },
            @{ Component = "Maven"; Category = "Build Tools"; Command = "mvn"; VersionArgs = @("--version") },
            @{ Component = "Gradle"; Category = "Build Tools"; Command = "gradle"; VersionArgs = @("--version") },
            @{ Component = ".NET SDK"; Category = "Core Runtime"; Command = "dotnet"; VersionArgs = @("--version") },
            @{ Component = "Ruby"; Category = "Core Runtime"; Command = "ruby"; VersionArgs = @("--version") }
        )
        
        $results = @()
        foreach ($check in $checks) {
            $isHealthy = $false
            $details = "Not installed"
            try {
                $cmd = Get-Command -Name $check.Command -ErrorAction SilentlyContinue -CommandType Application
                if ($cmd) {
                    $isHealthy = $true
                    if (-not $check.SkipVersion -and $check.VersionArgs) {
                        try {
                            $psi = New-Object System.Diagnostics.ProcessStartInfo
                            $psi.FileName = $check.Command
                            $psi.Arguments = ($check.VersionArgs -join ' ')
                            $psi.RedirectStandardOutput = $true
                            $psi.RedirectStandardError = $true
                            $psi.UseShellExecute = $false
                            $psi.CreateNoWindow = $true
                            $proc = [System.Diagnostics.Process]::Start($psi)
                            if ($proc -and $proc.WaitForExit(5000)) {
                                $output = $proc.StandardOutput.ReadToEnd()
                                if ([string]::IsNullOrWhiteSpace($output)) { $output = $proc.StandardError.ReadToEnd() }
                                if (-not [string]::IsNullOrWhiteSpace($output)) {
                                    $ver = ($output -split "`r?`n")[0].Trim()
                                    if ($ver.Length -gt 50) { $ver = $ver.Substring(0,50) + "..." }
                                    $details = "v$ver"
                                } else { $details = "Detected" }
                            } else { $details = "Detected" }
                        } catch { $details = "Detected" }
                    } else {
                        $details = "Detected"
                    }
                }
            } catch { $isHealthy = $false }
            
            $results += [pscustomobject]@{
                Component = $check.Component
                Category = $check.Category
                Status = if ($isHealthy) { "Healthy" } else { "Action Needed" }
                Details = $details
                Recommendation = if ($isHealthy) { "No action required." } else { "Install from the Tools tab." }
            }
        }
        return $results
    }
    
    $powershell.AddScript($script).AddArgument($scriptRoot) | Out-Null
    $asyncResult = $powershell.BeginInvoke()
    
    # Use a timer to poll for completion without blocking UI
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    
    # Store references for the timer callback
    $script:healthRunspace = $runspace
    $script:healthPowershell = $powershell
    $script:healthAsyncResult = $asyncResult
    $script:healthSilent = $Silent
    
    $timer.Add_Tick({
        if ($script:healthAsyncResult.IsCompleted) {
            $this.Stop()
            
            try {
                $rawResults = $script:healthPowershell.EndInvoke($script:healthAsyncResult)
                
                # Convert results to new PSCustomObjects with IsSelected for checkbox binding
                $results = @()
                if ($rawResults -and $rawResults.Count -gt 0) {
                    foreach ($r in $rawResults) {
                        $isIssue = $r.Status -eq "Action Needed"
                        $results += [PSCustomObject]@{
                            Component = [string]$r.Component
                            Category = [string]$r.Category
                            Status = [string]$r.Status
                            Details = [string]$r.Details
                            Recommendation = [string]$r.Recommendation
                            IsSelected = $isIssue  # Auto-select items with issues
                        }
                    }
                }
                
                $script:lastHealthResults = $results
                $script:lastHealthRun = Get-Date
                
                if (-not $script:healthSilent -and $script:currentPage -eq "Health") {
                    Render-HealthResults -Results $results
                }
                
                if ($controls.txtStatus) { $controls.txtStatus.Text = "Health scan complete." }
            } catch {
                if ($controls.txtStatus) { $controls.txtStatus.Text = "Health scan error." }
            } finally {
                # Cleanup
                try { $script:healthPowershell.Dispose() } catch {}
                try { $script:healthRunspace.Close(); $script:healthRunspace.Dispose() } catch {}
                
                # Re-enable buttons
                if (-not $script:healthSilent) {
                    $content = $controls.mainContent.Content
                    $runButton = if ($content) { $content.FindName("btnRunHealthCheck") } else { $null }
                    $exportButton = if ($content) { $content.FindName("btnExportHealthReport") } else { $null }
                    if ($runButton) { $runButton.IsEnabled = $true }
                    if ($exportButton) { $exportButton.IsEnabled = $true }
                }
            }
        }
    })
    
    $timer.Start()
}

function Export-HealthReport {
    if (-not $script:lastHealthResults -or $script:lastHealthResults.Count -eq 0) {
        Invoke-HealthCheck -Silent | Out-Null
    }
    
    $reportPath = Join-Path (Join-Path $PSScriptRoot "Logs") ("health_report_{0}.json" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    try {
        $script:lastHealthResults | ConvertTo-Json -Depth 4 | Set-Content -Path $reportPath -Encoding UTF8
        [System.Windows.MessageBox]::Show("Health report exported to:`n$reportPath", "Report Saved",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show("Failed to write report: $_", "Export Failed",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
    }
}

# Map component names to Chocolatey package names
$script:componentToPackage = @{
    "Node.js" = "nodejs"
    "Python" = "python"
    "Git" = "git"
    "VS Code" = "vscode"
    "Docker" = "docker-desktop"
    "Angular CLI" = $null  # npm install
    "Composer" = "composer"
    "Azure CLI" = "azure-cli"
    "AWS CLI" = "awscli"
    "Terraform" = "terraform"
    "kubectl" = "kubernetes-cli"
    "Helm" = "kubernetes-helm"
    "Go" = "golang"
    "Rust/Cargo" = "rust"
    "Java" = "openjdk"
    "Maven" = "maven"
    "Gradle" = "gradle"
    ".NET SDK" = "dotnet-sdk"
    "Ruby" = "ruby"
}

function Fix-AllHealthIssues {
    if (-not $script:lastHealthResults -or $script:lastHealthResults.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Run a health scan first to detect issues.", "No Results",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    
    $issues = $script:lastHealthResults | Where-Object { $_.Status -eq "Action Needed" }
    if (-not $issues -or $issues.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No issues to fix - all checks are healthy!", "All Good",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        return
    }
    
    $result = [System.Windows.MessageBox]::Show("Install $($issues.Count) missing tools?`n`n$($issues.Component -join ', ')", "Fix All Issues",
        [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    
    if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }
    
    Install-HealthIssues -Issues $issues
}

function Fix-SelectedHealthIssues {
    if (-not $script:lastHealthResults -or $script:lastHealthResults.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Run a health scan first.", "No Results",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    
    # Get items where checkbox is checked and status is Action Needed
    $issues = @($script:lastHealthResults | Where-Object { $_.IsSelected -eq $true -and $_.Status -eq "Action Needed" })
    
    if ($issues.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No issues selected. Check the boxes next to items you want to fix.", "Nothing Selected",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    
    Install-HealthIssues -Issues $issues
}

function Install-HealthIssues {
    param([array]$Issues)
    
    if (-not $Issues -or $Issues.Count -eq 0) { return }
    
    # Disable buttons
    $content = $controls.mainContent.Content
    $runBtn = if ($content) { $content.FindName("btnRunHealthCheck") } else { $null }
    $fixAllBtn = if ($content) { $content.FindName("btnFixAllIssues") } else { $null }
    $fixSelBtn = if ($content) { $content.FindName("btnFixSelected") } else { $null }
    $exportBtn = if ($content) { $content.FindName("btnExportHealthReport") } else { $null }
    
    if ($runBtn) { $runBtn.IsEnabled = $false }
    if ($fixAllBtn) { $fixAllBtn.IsEnabled = $false }
    if ($fixSelBtn) { $fixSelBtn.IsEnabled = $false }
    if ($exportBtn) { $exportBtn.IsEnabled = $false }
    
    # Build package list
    $packagesToInstall = @()
    $componentNames = @()
    foreach ($issue in $Issues) {
        $package = $script:componentToPackage[$issue.Component]
        if ($package) {
            $packagesToInstall += $package
            $componentNames += $issue.Component
        }
    }
    
    if ($packagesToInstall.Count -eq 0) {
        $controls.txtStatus.Text = "No packages to install."
        if ($runBtn) { $runBtn.IsEnabled = $true }
        if ($fixAllBtn) { $fixAllBtn.IsEnabled = $true }
        if ($fixSelBtn) { $fixSelBtn.IsEnabled = $true }
        if ($exportBtn) { $exportBtn.IsEnabled = $true }
        return
    }
    
    $controls.txtStatus.Text = "Installing $($packagesToInstall.Count) tools..."
    
    # Get choco path from user settings
    $chocoBasePath = Get-ChocolateyPath
    $chocoPath = Join-Path $chocoBasePath "bin\choco.exe"
    if (-not (Test-Path $chocoPath)) {
        $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
        if ($chocoCmd) { $chocoPath = $chocoCmd.Source }
    }
    
    # Create runspace
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()
    
    $powershell = [powershell]::Create()
    $powershell.Runspace = $runspace
    
    $script = {
        param($ChocoPath, $PackageNames, $ComponentNames)
        
        $results = @{
            Success = 0
            Failed = @()
        }
        
        for ($i = 0; $i -lt $PackageNames.Count; $i++) {
            $pkgName = $PackageNames[$i]
            $compName = $ComponentNames[$i]
            try {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $ChocoPath
                $psi.Arguments = "install $pkgName -y --no-progress"
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true
                
                $proc = [System.Diagnostics.Process]::Start($psi)
                if ($proc) {
                    $proc.WaitForExit(300000)
                    if ($proc.ExitCode -eq 0) {
                        $results.Success++
                    } else {
                        $results.Failed += $compName
                    }
                } else {
                    $results.Failed += $compName
                }
            } catch {
                $results.Failed += $compName
            }
        }
        
        return $results
    }
    
    $powershell.AddScript($script).AddArgument($chocoPath).AddArgument($packagesToInstall).AddArgument($componentNames) | Out-Null
    $asyncResult = $powershell.BeginInvoke()
    
    # Store references
    $script:fixRunspace = $runspace
    $script:fixPowershell = $powershell
    $script:fixAsyncResult = $asyncResult
    $script:fixTotal = $packagesToInstall.Count
    
    # Timer to poll for completion
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    
    $timer.Add_Tick({
        if ($script:fixAsyncResult.IsCompleted) {
            $this.Stop()
            
            $successCount = 0
            $failedList = @()
            
            try {
                $result = $script:fixPowershell.EndInvoke($script:fixAsyncResult)
                if ($result -and $result.Count -gt 0) {
                    $successCount = $result[0].Success
                    $failedList = $result[0].Failed
                }
            } catch {
                $failedList = @("Error during install")
            } finally {
                try { $script:fixPowershell.Dispose() } catch {}
                try { $script:fixRunspace.Close(); $script:fixRunspace.Dispose() } catch {}
            }
            
            $controls.txtStatus.Text = "Installed $successCount of $($script:fixTotal) tools."
            
            if ($failedList.Count -gt 0) {
                [System.Windows.MessageBox]::Show("Failed to install:`n$($failedList -join ', ')`n`nInstalled: $successCount", "Partial Success",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            } else {
                [System.Windows.MessageBox]::Show("Successfully installed $successCount tools!", "Complete",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            }
            
            # Re-enable buttons
            $content = $controls.mainContent.Content
            $runBtn = if ($content) { $content.FindName("btnRunHealthCheck") } else { $null }
            $fixAllBtn = if ($content) { $content.FindName("btnFixAllIssues") } else { $null }
            $fixSelBtn = if ($content) { $content.FindName("btnFixSelected") } else { $null }
            $exportBtn = if ($content) { $content.FindName("btnExportHealthReport") } else { $null }
            
            if ($runBtn) { $runBtn.IsEnabled = $true }
            if ($fixAllBtn) { $fixAllBtn.IsEnabled = $true }
            if ($fixSelBtn) { $fixSelBtn.IsEnabled = $true }
            if ($exportBtn) { $exportBtn.IsEnabled = $true }
            
            # Refresh health check
            Invoke-HealthCheck
        }
    })
    
    $timer.Start()
}

function Get-ChocolateyUpdates {
    $choco = Get-Command -Name choco -ErrorAction SilentlyContinue -CommandType Application
    if (-not $choco) {
        return @()
    }
    
    $updates = @()
    try {
        $output = choco outdated --limit-output 2>$null
        foreach ($line in $output) {
            if (-not $line -or $line.StartsWith("Chocolatey")) { continue }
            if ($line -match "^([^|]+)\|([^|]+)\|([^|]+)") {
                $package = $matches[1]
                $current = $matches[2]
                $available = $matches[3]
                $updates += [pscustomobject]@{
                    Tool = Get-PackageDisplayName $package
                    Package = $package
                    CurrentVersion = $current
                    AvailableVersion = $available
                    Source = "Chocolatey"
                }
            }
        }
    } catch {
        Write-Warning "Failed to query Chocolatey updates: $_"
    }
    
    return $updates
}

function Render-UpdateResults {
    param([array]$Results)
    
    $content = $controls.mainContent.Content
    if (-not $content) { return }
    
    $list = $content.FindName("lvUpdates")
    if ($list) {
        $list.ItemsSource = $null
        $list.ItemsSource = $Results
    }
    
    $summary = $content.FindName("txtUpdatesSummary")
    if ($summary) {
        if (-not $Results -or $Results.Count -eq 0) {
            $summary.Text = "Everything is up to date."
        } else {
            $summary.Text = "$($Results.Count) packages have updates available."
        }
    }
    
    $lastRun = $content.FindName("txtUpdatesLastRun")
    if ($lastRun -and $script:lastUpdateRun) {
        $lastRun.Text = "Last run: {0}" -f $script:lastUpdateRun.ToString("MMM dd, HH:mm")
    }
}

function Invoke-UpdateCheck {
    $choco = Get-Command -Name choco -ErrorAction SilentlyContinue -CommandType Application
    if (-not $choco) {
        $controls.txtStatus.Text = "Chocolatey not installed."
        [System.Windows.MessageBox]::Show("Install Chocolatey from the Tools page to enable update checks.", "Chocolatey Missing",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    
    # Disable buttons
    $content = $controls.mainContent.Content
    $checkBtn = if ($content) { $content.FindName("btnCheckUpdates") } else { $null }
    $installBtn = if ($content) { $content.FindName("btnInstallUpdates") } else { $null }
    $exportBtn = if ($content) { $content.FindName("btnExportUpdates") } else { $null }
    
    if ($checkBtn) { $checkBtn.IsEnabled = $false }
    if ($installBtn) { $installBtn.IsEnabled = $false }
    if ($exportBtn) { $exportBtn.IsEnabled = $false }
    
    $controls.txtStatus.Text = "Checking for Chocolatey updates..."
    
    $summary = if ($content) { $content.FindName("txtUpdatesSummary") } else { $null }
    if ($summary) { $summary.Text = "Scanning for updates..." }
    
    # Create runspace for background execution
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()
    
    # Get choco path from user settings
    $chocoBasePath = Get-ChocolateyPath
    $chocoPath = Join-Path $chocoBasePath "bin\choco.exe"
    if (-not (Test-Path $chocoPath)) {
        $chocoPath = (Get-Command choco -ErrorAction SilentlyContinue).Source
    }
    $runspace.SessionStateProxy.SetVariable("ChocoPath", $chocoPath)
    
    $powershell = [powershell]::Create()
    $powershell.Runspace = $runspace
    
    $script = {
        param($ChocoPath)
        $updates = @()
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $ChocoPath
            $psi.Arguments = "outdated --limit-output"
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $proc = [System.Diagnostics.Process]::Start($psi)
            if ($proc) {
                $output = $proc.StandardOutput.ReadToEnd()
                $proc.WaitForExit(60000)
                
                foreach ($line in ($output -split "`r?`n")) {
                    if (-not $line -or $line.StartsWith("Chocolatey")) { continue }
                    if ($line -match "^([^|]+)\|([^|]+)\|([^|]+)") {
                        $package = $matches[1]
                        $current = $matches[2]
                        $available = $matches[3]
                        $updates += [pscustomobject]@{
                            Tool = $package
                            Package = $package
                            CurrentVersion = $current
                            AvailableVersion = $available
                            Source = "Chocolatey"
                        }
                    }
                }
            }
        } catch {}
        return $updates
    }
    
    $powershell.AddScript($script).AddArgument($chocoPath) | Out-Null
    $asyncResult = $powershell.BeginInvoke()
    
    # Store references for timer
    $script:updateRunspace = $runspace
    $script:updatePowershell = $powershell
    $script:updateAsyncResult = $asyncResult
    
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    
    $timer.Add_Tick({
        if ($script:updateAsyncResult.IsCompleted) {
            $this.Stop()
            
            try {
                $rawResults = $script:updatePowershell.EndInvoke($script:updateAsyncResult)
                
                # Convert results to new PSCustomObjects in UI thread for proper WPF binding
                $results = @()
                if ($rawResults -and $rawResults.Count -gt 0) {
                    foreach ($r in $rawResults) {
                        $results += [PSCustomObject]@{
                            Package = [string]$r.Package
                            CurrentVersion = [string]$r.CurrentVersion
                            AvailableVersion = [string]$r.AvailableVersion
                            Source = [string]$r.Source
                            IsSelected = $true
                        }
                    }
                }
                
                $script:lastUpdateResults = $results
                $script:lastUpdateRun = Get-Date
                
                if ($script:currentPage -eq "Update") {
                    Render-UpdateResults -Results $results
                }
                
                if (-not $results -or $results.Count -eq 0) {
                    $controls.txtStatus.Text = "All packages are current."
                } else {
                    $controls.txtStatus.Text = "$($results.Count) updates available."
                }
            } catch {
                $controls.txtStatus.Text = "Update check failed."
            } finally {
                try { $script:updatePowershell.Dispose() } catch {}
                try { $script:updateRunspace.Close(); $script:updateRunspace.Dispose() } catch {}
                
                # Re-enable buttons
                $content = $controls.mainContent.Content
                $checkBtn = if ($content) { $content.FindName("btnCheckUpdates") } else { $null }
                $selectAllBtn = if ($content) { $content.FindName("btnSelectAllUpdates") } else { $null }
                $installBtn = if ($content) { $content.FindName("btnUpdateSelected") } else { $null }
                $updateAllBtn = if ($content) { $content.FindName("btnUpdateAll") } else { $null }
                $exportBtn = if ($content) { $content.FindName("btnExportUpdateReport") } else { $null }
                
                if ($checkBtn) { $checkBtn.IsEnabled = $true }
                if ($selectAllBtn) { $selectAllBtn.IsEnabled = $true }
                if ($installBtn) { $installBtn.IsEnabled = $true }
                if ($updateAllBtn) { $updateAllBtn.IsEnabled = $true }
                if ($exportBtn) { $exportBtn.IsEnabled = $true }
            }
        }
    })
    
    $timer.Start()
}

function Export-UpdateReport {
    if (-not $script:lastUpdateResults -or $script:lastUpdateResults.Count -eq 0) {
        Invoke-UpdateCheck
    }
    
    $reportPath = Join-Path (Join-Path $PSScriptRoot "Logs") ("updates_{0}.json" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    try {
        $script:lastUpdateResults | ConvertTo-Json -Depth 3 | Set-Content -Path $reportPath -Encoding UTF8
        [System.Windows.MessageBox]::Show("Update report exported to:`n$reportPath", "Report Saved",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show("Failed to write update report: $_", "Export Failed",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
    }
}

function Install-SelectedUpdates {
    if (-not $script:lastUpdateResults -or $script:lastUpdateResults.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No updates available. Click 'Check for Updates' first.", "No Updates",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    
    # Get items where checkbox is checked
    $packages = @($script:lastUpdateResults | Where-Object { $_.IsSelected -eq $true })
    
    if ($packages.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No packages selected. Check the boxes next to items you want to update.", "Nothing Selected",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    
    Install-UpdatePackages -Packages $packages
}

function Select-AllUpdates {
    if (-not $script:lastUpdateResults -or $script:lastUpdateResults.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No updates available. Click 'Check for Updates' first.", "No Updates",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        return
    }
    
    # Set all items as selected
    foreach ($item in $script:lastUpdateResults) {
        $item.IsSelected = $true
    }
    
    # Refresh the list
    Render-UpdateResults -Results $script:lastUpdateResults
    $controls.txtStatus.Text = "Selected all $($script:lastUpdateResults.Count) packages."
}

function Install-AllUpdates {
    if (-not $script:lastUpdateResults -or $script:lastUpdateResults.Count -eq 0) {
        [System.Windows.MessageBox]::Show("No updates available. Click 'Check for Updates' first.", "No Updates",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        return
    }
    
    $result = [System.Windows.MessageBox]::Show("Update all $($script:lastUpdateResults.Count) packages?", "Update All",
        [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    
    if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }
    
    Install-UpdatePackages -Packages $script:lastUpdateResults
}

function Install-UpdatePackages {
    param([array]$Packages)
    
    if (-not $Packages -or $Packages.Count -eq 0) { return }
    
    # Disable buttons
    $content = $controls.mainContent.Content
    $checkBtn = if ($content) { $content.FindName("btnCheckUpdates") } else { $null }
    $selectAllBtn = if ($content) { $content.FindName("btnSelectAllUpdates") } else { $null }
    $updateSelBtn = if ($content) { $content.FindName("btnUpdateSelected") } else { $null }
    $updateAllBtn = if ($content) { $content.FindName("btnUpdateAll") } else { $null }
    $exportBtn = if ($content) { $content.FindName("btnExportUpdateReport") } else { $null }
    
    if ($checkBtn) { $checkBtn.IsEnabled = $false }
    if ($selectAllBtn) { $selectAllBtn.IsEnabled = $false }
    if ($updateSelBtn) { $updateSelBtn.IsEnabled = $false }
    if ($updateAllBtn) { $updateAllBtn.IsEnabled = $false }
    if ($exportBtn) { $exportBtn.IsEnabled = $false }
    
    $controls.txtStatus.Text = "Updating $($Packages.Count) packages..."
    
    # Build package list as simple strings
    $packageNames = @()
    foreach ($pkg in $Packages) {
        $packageNames += [string]$pkg.Package
    }
    
    # Get choco path from user settings
    $chocoBasePath = Get-ChocolateyPath
    $chocoPath = Join-Path $chocoBasePath "bin\choco.exe"
    if (-not (Test-Path $chocoPath)) {
        $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
        if ($chocoCmd) { $chocoPath = $chocoCmd.Source }
    }
    
    # Create runspace
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()
    
    $powershell = [powershell]::Create()
    $powershell.Runspace = $runspace
    
    $script = {
        param($ChocoPath, $PackageNames)
        
        $results = @{
            Success = 0
            Failed = @()
        }
        
        foreach ($pkgName in $PackageNames) {
            try {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $ChocoPath
                $psi.Arguments = "upgrade $pkgName -y --no-progress"
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true
                
                $proc = [System.Diagnostics.Process]::Start($psi)
                if ($proc) {
                    $proc.WaitForExit(300000)
                    if ($proc.ExitCode -eq 0) {
                        $results.Success++
                    } else {
                        $results.Failed += $pkgName
                    }
                } else {
                    $results.Failed += $pkgName
                }
            } catch {
                $results.Failed += $pkgName
            }
        }
        
        return $results
    }
    
    $powershell.AddScript($script).AddArgument($chocoPath).AddArgument($packageNames) | Out-Null
    $asyncResult = $powershell.BeginInvoke()
    
    # Store references
    $script:pkgUpdateRunspace = $runspace
    $script:pkgUpdatePowershell = $powershell
    $script:pkgUpdateAsyncResult = $asyncResult
    $script:pkgUpdateTotal = $packageNames.Count
    
    # Timer to poll for completion
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    
    $timer.Add_Tick({
        if ($script:pkgUpdateAsyncResult.IsCompleted) {
            $this.Stop()
            
            $successCount = 0
            $failedList = @()
            
            try {
                $result = $script:pkgUpdatePowershell.EndInvoke($script:pkgUpdateAsyncResult)
                if ($result -and $result.Count -gt 0) {
                    $successCount = $result[0].Success
                    $failedList = $result[0].Failed
                }
            } catch {
                $failedList = @("Error during update")
            } finally {
                try { $script:pkgUpdatePowershell.Dispose() } catch {}
                try { $script:pkgUpdateRunspace.Close(); $script:pkgUpdateRunspace.Dispose() } catch {}
            }
            
            $controls.txtStatus.Text = "Updated $successCount of $($script:pkgUpdateTotal) packages."
            
            if ($failedList.Count -gt 0) {
                [System.Windows.MessageBox]::Show("Failed to update:`n$($failedList -join ', ')`n`nUpdated: $successCount", "Partial Success",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            } else {
                [System.Windows.MessageBox]::Show("Successfully updated $successCount packages!", "Complete",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            }
            
            # Re-enable buttons and refresh
            $content = $controls.mainContent.Content
            $checkBtn = if ($content) { $content.FindName("btnCheckUpdates") } else { $null }
            $selectAllBtn = if ($content) { $content.FindName("btnSelectAllUpdates") } else { $null }
            $updateSelBtn = if ($content) { $content.FindName("btnUpdateSelected") } else { $null }
            $updateAllBtn = if ($content) { $content.FindName("btnUpdateAll") } else { $null }
            $exportBtn = if ($content) { $content.FindName("btnExportUpdateReport") } else { $null }
            
            if ($checkBtn) { $checkBtn.IsEnabled = $true }
            if ($selectAllBtn) { $selectAllBtn.IsEnabled = $true }
            if ($updateSelBtn) { $updateSelBtn.IsEnabled = $true }
            if ($updateAllBtn) { $updateAllBtn.IsEnabled = $true }
            if ($exportBtn) { $exportBtn.IsEnabled = $true }
            
            # Refresh update list
            Invoke-UpdateCheck
        }
    })
    
    $timer.Start()
}

