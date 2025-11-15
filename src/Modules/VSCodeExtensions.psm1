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

function Install-VSCodeExtension {
    param([string]$ExtensionId)
    try {
        $codeCmd = Get-Command code -ErrorAction SilentlyContinue
        if (-not $codeCmd) {
            Write-Host "VS Code CLI not found in PATH" -ForegroundColor Yellow
            return $false
        }
        Write-Host "Installing extension: $ExtensionId" -ForegroundColor Cyan
        $process = Start-Process "code" -ArgumentList "--install-extension $ExtensionId --force" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "Installed: $ExtensionId" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Failed: $ExtensionId" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Error installing ${ExtensionId}: $($_.Exception.Message)" -ForegroundColor Red
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

Export-ModuleMember -Function Get-VSCodeExtensions, Install-VSCodeExtension, Install-AllVSCodeExtensions
