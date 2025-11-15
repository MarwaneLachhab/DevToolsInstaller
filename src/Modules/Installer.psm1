# Installer.psm1
# Module for downloading and installing development tools

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = "$PSScriptRoot\..\Logs\install_$(Get-Date -Format 'yyyy-MM-dd').log"
    "$timestamp [$Level] $Message" | Out-File -FilePath $logFile -Append
    Write-Host "[$Level] $Message" -ForegroundColor $(if($Level -eq "ERROR"){"Red"}elseif($Level -eq "SUCCESS"){"Green"}else{"Cyan"})
}

function Get-InstallerFile {
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$ToolName
    )
    
    try {
        Write-Log "Downloading $ToolName from $Url"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        Write-Log "Downloaded $ToolName successfully" "SUCCESS"
        return $true
    } catch {
        Write-Log "Failed to download $ToolName : $_" "ERROR"
        return $false
    }
}

function Install-NodeJS {
    param([hashtable]$VersionInfo, [string]$DownloadPath)
    
    Write-Log "Installing Node.js $($VersionInfo.Version)"
    $installer = Join-Path $DownloadPath "nodejs_installer.msi"
    
    if (Get-InstallerFile -Url $VersionInfo.Url -OutputPath $installer -ToolName "Node.js") {
        try {
            $arguments = "/i `"$installer`" /qn /norestart ADDLOCAL=ALL"
            Start-Process "msiexec.exe" -ArgumentList $arguments -Wait -NoNewWindow
            Write-Log "Node.js installed successfully" "SUCCESS"
            
            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return $true
        } catch {
            Write-Log "Failed to install Node.js: $_" "ERROR"
            return $false
        }
    }
    return $false
}

function Install-Python {
    param([hashtable]$VersionInfo, [string]$DownloadPath)
    
    Write-Log "Installing Python $($VersionInfo.Version)"
    $installer = Join-Path $DownloadPath "python_installer.exe"
    
    if (Get-InstallerFile -Url $VersionInfo.Url -OutputPath $installer -ToolName "Python") {
        try {
            $arguments = "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0"
            Start-Process -FilePath $installer -ArgumentList $arguments -Wait -NoNewWindow
            Write-Log "Python installed successfully" "SUCCESS"
            
            # Refresh environment variables
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return $true
        } catch {
            Write-Log "Failed to install Python: $_" "ERROR"
            return $false
        }
    }
    return $false
}

function Install-VSCode {
    param([hashtable]$VersionInfo, [string]$DownloadPath)
    
    Write-Log "Installing Visual Studio Code $($VersionInfo.Version)"
    $installer = Join-Path $DownloadPath "vscode_installer.exe"
    
    if (Get-InstallerFile -Url $VersionInfo.Url -OutputPath $installer -ToolName "VS Code") {
        try {
            $arguments = "/VERYSILENT /NORESTART /MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,addtopath"
            Start-Process -FilePath $installer -ArgumentList $arguments -Wait -NoNewWindow
            Write-Log "VS Code installed successfully" "SUCCESS"
            return $true
        } catch {
            Write-Log "Failed to install VS Code: $_" "ERROR"
            return $false
        }
    }
    return $false
}

function Install-Composer {
    param([hashtable]$VersionInfo, [string]$DownloadPath)
    
    Write-Log "Installing Composer $($VersionInfo.Version)"
    $installer = Join-Path $DownloadPath "composer_installer.exe"
    
    if (Get-InstallerFile -Url $VersionInfo.Url -OutputPath $installer -ToolName "Composer") {
        try {
            Start-Process -FilePath $installer -ArgumentList "/VERYSILENT /NORESTART" -Wait -NoNewWindow
            Write-Log "Composer installed successfully" "SUCCESS"
            return $true
        } catch {
            Write-Log "Failed to install Composer: $_" "ERROR"
            return $false
        }
    }
    return $false
}

function Install-XAMPP {
    param([hashtable]$VersionInfo, [string]$DownloadPath)
    
    Write-Log "Installing XAMPP $($VersionInfo.Version)"
    $installer = Join-Path $DownloadPath "xampp_installer.exe"
    
    if (Get-InstallerFile -Url $VersionInfo.Url -OutputPath $installer -ToolName "XAMPP") {
        try {
            # XAMPP installer requires different arguments
            Start-Process -FilePath $installer -ArgumentList "--mode unattended --unattendedmodeui none" -Wait -NoNewWindow
            Write-Log "XAMPP installed successfully" "SUCCESS"
            return $true
        } catch {
            Write-Log "Failed to install XAMPP: $_" "ERROR"
            return $false
        }
    }
    return $false
}

function Install-AngularCLI {
    Write-Log "Installing Angular CLI"
    try {
        $process = Start-Process "npm" -ArgumentList "install -g @angular/cli" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Log "Angular CLI installed successfully" "SUCCESS"
            return $true
        } else {
            Write-Log "Angular CLI installation failed with exit code $($process.ExitCode)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Failed to install Angular CLI: $_" "ERROR"
        return $false
    }
}

function Install-LaravelInstaller {
    Write-Log "Installing Laravel Installer"
    try {
        $process = Start-Process "composer" -ArgumentList "global require laravel/installer" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Log "Laravel Installer installed successfully" "SUCCESS"
            return $true
        } else {
            Write-Log "Laravel Installer installation failed with exit code $($process.ExitCode)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Failed to install Laravel Installer: $_" "ERROR"
        return $false
    }
}

function Install-Chocolatey {
    Write-Log "Installing Chocolatey Package Manager"
    try {
        # Check if already installed
        $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
        if ($chocoCmd) {
            Write-Log "Chocolatey is already installed" "SUCCESS"
            return $true
        }
        
        # Install Chocolatey
        Write-Log "Downloading and installing Chocolatey..."
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Verify installation
        $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
        if ($chocoCmd) {
            Write-Log "Chocolatey installed successfully" "SUCCESS"
            return $true
        } else {
            Write-Log "Chocolatey installation verification failed" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Failed to install Chocolatey: $_" "ERROR"
        return $false
    }
}

function Install-ChocoPackage {
    param([string]$PackageName)
    
    Write-Log "Installing $PackageName via Chocolatey"
    try {
        # Check if choco is available
        $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
        if (-not $chocoCmd) {
            Write-Log "Chocolatey not found. Please install Chocolatey first." "ERROR"
            return $false
        }
        
        # Install package silently
        $process = Start-Process "choco" -ArgumentList "install $PackageName -y --no-progress" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Log "$PackageName installed successfully via Chocolatey" "SUCCESS"
            return $true
        } else {
            Write-Log "$PackageName installation failed with exit code $($process.ExitCode)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Failed to install ${PackageName}: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Update-ChocoPackage {
    param([string]$PackageName)
    
    Write-Log "Updating $PackageName via Chocolatey"
    try {
        $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
        if (-not $chocoCmd) {
            Write-Log "Chocolatey not found. Cannot update $PackageName." "ERROR"
            return $false
        }
        
        $process = Start-Process "choco" -ArgumentList "upgrade $PackageName -y --no-progress" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Log "$PackageName upgraded successfully via Chocolatey" "SUCCESS"
            return $true
        } else {
            Write-Log "$PackageName upgrade failed with exit code $($process.ExitCode)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Failed to upgrade ${PackageName}: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

Export-ModuleMember -Function Write-Log, Get-InstallerFile, Install-NodeJS, Install-Python, `
    Install-VSCode, Install-Composer, Install-XAMPP, Install-AngularCLI, Install-LaravelInstaller, Install-Chocolatey, Install-ChocoPackage, Update-ChocoPackage
