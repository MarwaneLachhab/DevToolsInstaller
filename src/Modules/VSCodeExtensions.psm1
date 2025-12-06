# VSCodeExtensions.psm1
# Module for managing VS Code extensions

function Get-VSCodeExtensions {
    return @(
        @{ Id = "abusaidm.html-snippets"; Name = "HTML Snippets"; Description = "HTML code snippets" },
        @{ Id = "burkeholland.simple-react-snippets"; Name = "Simple React Snippets"; Description = "React code snippets" },
        @{ Id = "dsznajder.es7-react-js-snippets"; Name = "ES7+ React Snippets"; Description = "React/Redux/React-Native snippets" },
        @{ Id = "formulahendry.auto-close-tag"; Name = "Auto Close Tag"; Description = "Automatically close HTML/XML tags" },
        @{ Id = "formulahendry.auto-complete-tag"; Name = "Auto Complete Tag"; Description = "Auto complete HTML/XML tags" },
        @{ Id = "formulahendry.auto-rename-tag"; Name = "Auto Rename Tag"; Description = "Auto rename paired HTML/XML tags" },
        @{ Id = "github.copilot"; Name = "GitHub Copilot"; Description = "AI pair programmer" },
        @{ Id = "github.copilot-chat"; Name = "GitHub Copilot Chat"; Description = "AI chat assistant" },
        @{ Id = "ms-python.python"; Name = "Python"; Description = "Python language support" },
        @{ Id = "ms-python.vscode-pylance"; Name = "Pylance"; Description = "Python language server" },
        @{ Id = "ms-vscode-remote.remote-ssh"; Name = "Remote - SSH"; Description = "Connect to remote machines via SSH" },
        @{ Id = "ms-vscode.powershell"; Name = "PowerShell"; Description = "PowerShell language support" },
        @{ Id = "msjsdiag.vscode-react-native"; Name = "React Native Tools"; Description = "React Native debugging and tools" },
        @{ Id = "openai.chatgpt"; Name = "ChatGPT"; Description = "ChatGPT integration" }
    )
}

function Get-InstalledVSCodeExtensions {
    try {
        $codeCmd = Get-Command code -ErrorAction SilentlyContinue
        if (-not $codeCmd) {
            return @()
        }
        $output = & code --list-extensions 2>$null
        if ($output) {
            return $output | ForEach-Object { $_.Trim().ToLowerInvariant() }
        }
        return @()
    } catch {
        return @()
    }
}

function Test-VSCodeExtensionInstalled {
    param([string]$ExtensionId)
    $installed = Get-InstalledVSCodeExtensions
    return ($installed -contains $ExtensionId.ToLowerInvariant())
}

function Install-VSCodeExtension {
    param([string]$ExtensionId)
    try {
        $codeCmd = Get-Command code -ErrorAction SilentlyContinue
        if (-not $codeCmd) {
            Write-Host "VS Code CLI not found in PATH" -ForegroundColor Yellow
            return $false
        }
        Write-Host "Installing extension: $ExtensionId" -ForegroundColor Cyan
        
        # Use System.Diagnostics.Process for reliable execution in background jobs
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $codeCmd.Source
        $psi.Arguments = "--install-extension `"$ExtensionId`" --force"
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        
        $process = [System.Diagnostics.Process]::Start($psi)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        
        if ($stdout) { Write-Host $stdout }
        if ($stderr) { Write-Host $stderr -ForegroundColor Yellow }
        
        # VS Code returns 0 on success
        if ($process.ExitCode -eq 0) {
            Write-Host "Installed: $ExtensionId" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Failed: $ExtensionId (Exit code: $($process.ExitCode))" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Error installing ${ExtensionId}: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Uninstall-VSCodeExtension {
    param([string]$ExtensionId)
    try {
        $codeCmd = Get-Command code -ErrorAction SilentlyContinue
        if (-not $codeCmd) {
            Write-Host "VS Code CLI not found in PATH" -ForegroundColor Yellow
            return $false
        }
        Write-Host "Uninstalling extension: $ExtensionId" -ForegroundColor Cyan
        
        # Use System.Diagnostics.Process for reliable execution in background jobs
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $codeCmd.Source
        $psi.Arguments = "--uninstall-extension `"$ExtensionId`""
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        
        $process = [System.Diagnostics.Process]::Start($psi)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        
        if ($stdout) { Write-Host $stdout }
        if ($stderr -and $stderr -notmatch "FATAL ERROR") { Write-Host $stderr -ForegroundColor Yellow }
        
        # VS Code CLI sometimes crashes AFTER successful uninstall (V8 bug)
        # Check if output says "successfully uninstalled" OR verify extension is no longer installed
        $successInOutput = $stdout -match "successfully uninstalled"
        
        if ($process.ExitCode -eq 0 -or $successInOutput) {
            Write-Host "Uninstalled: $ExtensionId" -ForegroundColor Green
            return $true
        } else {
            # Double-check if extension was actually removed despite error
            Start-Sleep -Milliseconds 500
            $stillInstalled = Test-VSCodeExtensionInstalled -ExtensionId $ExtensionId
            if (-not $stillInstalled) {
                Write-Host "Uninstalled: $ExtensionId (with warnings)" -ForegroundColor Green
                return $true
            }
            Write-Host "Failed to uninstall: $ExtensionId (Exit code: $($process.ExitCode))" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Error uninstalling ${ExtensionId}: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Install-AllVSCodeExtensions {
    param([string[]]$ExtensionIds)
    Write-Host "`n=== Installing VS Code Extensions ===" -ForegroundColor Magenta
    if ($ExtensionIds -and $ExtensionIds.Count -gt 0) {
        $extensionsToInstall = $ExtensionIds
    } else {
        $allExtensions = Get-VSCodeExtensions
        $extensionsToInstall = $allExtensions | ForEach-Object { $_.Id }
    }
    $installed = 0
    $failed = 0
    foreach ($extId in $extensionsToInstall) {
        if (Install-VSCodeExtension -ExtensionId $extId) {
            $installed++
        } else {
            $failed++
        }
    }
    Write-Host "`nInstallation Complete!" -ForegroundColor Green
    Write-Host "Installed: $installed" -ForegroundColor Green
    Write-Host "Failed: $failed" -ForegroundColor $(if($failed -gt 0){"Red"}else{"Green"})
    return @{ Successful = $installed; Failed = $failed }
}

function Uninstall-AllVSCodeExtensions {
    param([string[]]$ExtensionIds)
    Write-Host "`n=== Uninstalling VS Code Extensions ===" -ForegroundColor Magenta
    if (-not $ExtensionIds -or $ExtensionIds.Count -eq 0) {
        Write-Host "No extensions specified for uninstall" -ForegroundColor Yellow
        return @{ Successful = 0; Failed = 0 }
    }
    $uninstalled = 0
    $failed = 0
    foreach ($extId in $ExtensionIds) {
        if (Uninstall-VSCodeExtension -ExtensionId $extId) {
            $uninstalled++
        } else {
            $failed++
        }
    }
    Write-Host "`nUninstall Complete!" -ForegroundColor Green
    Write-Host "Uninstalled: $uninstalled" -ForegroundColor Green
    Write-Host "Failed: $failed" -ForegroundColor $(if($failed -gt 0){"Red"}else{"Green"})
    return @{ Successful = $uninstalled; Failed = $failed }
}

Export-ModuleMember -Function Get-VSCodeExtensions, Get-InstalledVSCodeExtensions, Test-VSCodeExtensionInstalled, Install-VSCodeExtension, Uninstall-VSCodeExtension, Install-AllVSCodeExtensions, Uninstall-AllVSCodeExtensions
