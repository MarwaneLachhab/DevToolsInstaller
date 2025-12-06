function Install-SelectedExtensions {
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
    
    $content = $controls.mainContent.Content
    $extensions = Get-VSCodeExtensions
    $selectedExtensions = @()
    
    foreach ($ext in $extensions) {
        $checkBoxName = "chkExt_$($ext.Id.Replace('.', '_').Replace('-', '_'))"
        $checkbox = $content.FindName($checkBoxName)
        
        if ($checkbox -and $checkbox.IsChecked) {
            $selectedExtensions += $ext.Id
        }
    }
    
    if ($selectedExtensions.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please select at least one extension.", "No Selection",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    
    # Mark installation as in progress
    $script:isInstalling = $true
    
    $controls.txtStatus.Text = "Installing VS Code extensions..."
    $controls.progressBar.Value = 0

    # Enable cancel button
    $script:cancelRequested = $false
    if ($script:btnCancel) { $script:btnCancel.IsEnabled = $true }

    # Use PowerShell Job for async execution
    $script:currentJob = $null
    $script:extensionInstallResult = $null

    $script:installTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:installTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    
    $script:installTimer.Add_Tick({
        if ($script:cancelRequested) {
            # Installation cancelled
            if ($script:currentJob) {
                Stop-Job -Job $script:currentJob -ErrorAction SilentlyContinue
                Remove-Job -Job $script:currentJob -Force -ErrorAction SilentlyContinue
                $script:currentJob = $null
            }
            $script:installTimer.Stop()
            
            $controls.progressBar.Value = 100
            $controls.txtStatus.Text = "Extension installation cancelled."
            [System.Windows.MessageBox]::Show("Extension installation was cancelled.", "Installation Cancelled",
                [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null

            $script:isInstalling = $false
            if ($script:btnCancel) { $script:btnCancel.IsEnabled = $false }
            return
        }
        
        # Check if job exists and start it if not
        if (-not $script:currentJob) {
            $controls.progressBar.Value = 10
            $controls.txtStatus.Text = "Starting extension installation..."
            
            # Start job with full context
            # Note: $PSScriptRoot here is the Parts folder, so we need to go up one level to get to src
            $modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "Modules"
            $scriptRoot = $PSScriptRoot
            $script:currentJob = Start-Job -ScriptBlock {
                param($ExtIds, $ModulePath, $ScriptRoot)
                
                # Set working directory
                Set-Location $ScriptRoot
                $env:INSTALLER_LOG_PATH = Join-Path $ScriptRoot "Logs"
                $env:INSTALLER_SUPPRESS_CONSOLE = "1"
                $ProgressPreference = 'SilentlyContinue'
                
                # Import required modules
                Import-Module (Join-Path $ModulePath "VSCodeExtensions.psm1") -Force -ErrorAction Stop
                
                # Run installation
                Install-AllVSCodeExtensions -ExtensionIds $ExtIds
            } -ArgumentList $selectedExtensions, $modulePath, $scriptRoot
            return
        }
        
        # Check job status
        if ($script:currentJob.State -eq 'Completed') {
            $script:extensionInstallResult = Receive-Job -Job $script:currentJob
            Remove-Job -Job $script:currentJob -Force
            $script:currentJob = $null
            $script:installTimer.Stop()
            
            $controls.progressBar.Value = 100
            $controls.txtStatus.Text = "Extension installation complete!"
            
            if ($script:extensionInstallResult) {
                [System.Windows.MessageBox]::Show(
                    "Installed: $($script:extensionInstallResult.Successful)`nFailed: $($script:extensionInstallResult.Failed)", 
                    "Extensions Installed",
                    [System.Windows.MessageBoxButton]::OK, 
                    [System.Windows.MessageBoxImage]::Information) | Out-Null
            } else {
                [System.Windows.MessageBox]::Show(
                    "Extension installation completed.", 
                    "Extensions Installed",
                    [System.Windows.MessageBoxButton]::OK, 
                    [System.Windows.MessageBoxImage]::Information) | Out-Null
            }

            $script:isInstalling = $false
            if ($script:btnCancel) { $script:btnCancel.IsEnabled = $false }
        } elseif ($script:currentJob.State -eq 'Failed') {
            Remove-Job -Job $script:currentJob -Force
            $script:currentJob = $null
            $script:installTimer.Stop()
            
            $controls.progressBar.Value = 100
            $controls.txtStatus.Text = "Extension installation failed!"
            [System.Windows.MessageBox]::Show("Extension installation failed. Check logs for details.", "Installation Failed",
                [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null

            $script:isInstalling = $false
            if ($script:btnCancel) { $script:btnCancel.IsEnabled = $false }
        } else {
            # Job still running - update progress
            $controls.progressBar.Value = 50
            $controls.txtStatus.Text = "Installing VS Code extensions..."
        }
    })
    
    $script:installTimer.Start()
}
