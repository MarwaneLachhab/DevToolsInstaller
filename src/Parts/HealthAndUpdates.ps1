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
            VersionArgs = @("--version")
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
            if ($check.Command) {
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
                $details = "Healthy"
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
    
    if ($Silent) {
        if ($controls.txtStatus) { $controls.txtStatus.Text = "Running health scan..." }
        $results = Get-HealthCheckResults -OnProgress {
            param($component, $position, $total)
            if ($controls -and $controls.txtStatus) {
                $controls.txtStatus.Text = "Checking $component ($position/$total)..."
            }
        }.GetNewClosure()
        $script:lastHealthResults = $results
        $script:lastHealthRun = Get-Date
        if ($controls.txtStatus) { $controls.txtStatus.Text = "Silent health scan complete." }
        return $results
    }
    
    if ($script:healthScanWorker -and $script:healthScanWorker.IsBusy) {
        if ($controls.txtStatus) { $controls.txtStatus.Text = "Health scan already running..." }
        return
    }
    
    $content = $controls.mainContent.Content
    $runButton = if ($content) { $content.FindName("btnRunHealthCheck") } else { $null }
    $exportButton = if ($content) { $content.FindName("btnExportHealthReport") } else { $null }
    
    if ($runButton) { $runButton.IsEnabled = $false }
    if ($exportButton) { $exportButton.IsEnabled = $false }
    
    if ($controls.txtStatus) { $controls.txtStatus.Text = "Initializing health scan..." }
    
    if ($content) {
        $txtSummary = $content.FindName("txtHealthSummary")
        if ($txtSummary) { $txtSummary.Text = "Running diagnostics..." }
        $txtIssues = $content.FindName("txtHealthIssues")
        if ($txtIssues) { $txtIssues.Text = "Gathering results..." }
        $txtScore = $content.FindName("txtHealthScore")
        if ($txtScore) { $txtScore.Text = "--%" }
    }
    
    $dispatcher = $window.Dispatcher
    $progressCallback = {
        param($component, $position, $total)
        $dispatcher.Invoke([System.Action]{
            if ($controls.txtStatus) {
                $controls.txtStatus.Text = "Checking $component ($position/$total)..."
            }
        })
    }.GetNewClosure()
    
    $worker = New-Object System.ComponentModel.BackgroundWorker
    $worker.WorkerSupportsCancellation = $false
    $worker.add_DoWork({
        param($sender, $args)
        $args.Result = Get-HealthCheckResults -OnProgress $progressCallback
    }.GetNewClosure())
    
    $worker.add_RunWorkerCompleted({
        param($sender, $args)
        $dispatcher.Invoke([System.Action]{
            if ($runButton) { $runButton.IsEnabled = $true }
            if ($exportButton) { $exportButton.IsEnabled = $true }
            $script:healthScanWorker = $null
            
            if ($args.Error) {
                if ($controls.txtStatus) { $controls.txtStatus.Text = "Health scan failed." }
                [System.Windows.MessageBox]::Show(
                    "Health scan failed:`n$($args.Error.Message)",
                    "Health Scan",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                ) | Out-Null
                return
            }
            
            $results = if ($args.Result) { $args.Result } else { @() }
            $script:lastHealthResults = $results
            $script:lastHealthRun = Get-Date
            if ($script:currentPage -eq "Health") {
                Render-HealthResults -Results $results
            }
            if ($controls.txtStatus) { $controls.txtStatus.Text = "Health scan complete." }
        })
    }.GetNewClosure())
    
    $script:healthScanWorker = $worker
    $worker.RunWorkerAsync() | Out-Null
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
    
    $controls.txtStatus.Text = "Checking for Chocolatey updates..."
    $script:lastUpdateResults = Get-ChocolateyUpdates
    $script:lastUpdateRun = Get-Date
    
    Render-UpdateResults -Results $script:lastUpdateResults
    
    if (-not $script:lastUpdateResults -or $script:lastUpdateResults.Count -eq 0) {
        $controls.txtStatus.Text = "All packages are current."
        [System.Windows.MessageBox]::Show("All tracked packages are already up to date.", "Updates",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    } else {
        $controls.txtStatus.Text = "Updates available."
    }
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
    $content = $controls.mainContent.Content
    if (-not $content) { return }
    
    $list = $content.FindName("lvUpdates")
    if (-not $list -or $list.SelectedItems.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Select one or more packages from the list first.", "Nothing Selected",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    
    $packages = @()
    foreach ($item in $list.SelectedItems) {
        $packages += $item
    }
    
    $total = $packages.Count
    $current = 0
    foreach ($pkg in $packages) {
        $current++
        $controls.txtStatus.Text = "Updating $($pkg.Package) ($current/$total)..."
        Update-ChocoPackage -PackageName $pkg.Package | Out-Null
    }
    
    $controls.txtStatus.Text = "Updates installed."
    Invoke-UpdateCheck
}

