# Installer.psm1
# Module for downloading and installing development tools

if (-not (Get-Variable -Name LogEncodingCache -Scope Script -ErrorAction SilentlyContinue)) {
    $script:LogEncodingCache = @{}
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Use environment variable if set (for background jobs), otherwise use relative path
    $logDir = if ($env:INSTALLER_LOG_PATH) { $env:INSTALLER_LOG_PATH } else { "$PSScriptRoot\..\Logs" }
    $logFile = Join-Path $logDir "install_$(Get-Date -Format 'yyyy-MM-dd').log"
    
    # Ensure log directory exists
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    if (-not $script:LogEncodingCache.ContainsKey($logFile)) {
        $script:LogEncodingCache[$logFile] = $false
    }

    if (-not $script:LogEncodingCache[$logFile]) {
        try {
            if (Test-Path $logFile) {
                $bytes = [System.IO.File]::ReadAllBytes($logFile)
                $hasUtf16Bom = $bytes.Length -ge 2 -and (
                    ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or
                    ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF)
                )
                if ($hasUtf16Bom) {
                    $content = Get-Content -Path $logFile -Raw
                    Set-Content -Path $logFile -Value $content -Encoding UTF8
                }
            }
        } catch {
            # If conversion fails we proceed, future writes will still be UTF-8
        } finally {
            $script:LogEncodingCache[$logFile] = $true
        }
    }

    "$timestamp [$Level] $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
    if ($env:INSTALLER_SUPPRESS_CONSOLE -ne "1") {
        Write-Host "[$Level] $Message" -ForegroundColor $(if($Level -eq "ERROR"){"Red"}elseif($Level -eq "SUCCESS"){"Green"}else{"Cyan"})
    }
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
        $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
        if (-not $npmCmd) {
            Write-Log "npm command not found. Please install Node.js/NPM before installing Angular CLI." "ERROR"
            return $false
        }

        $process = Start-Process -FilePath $npmCmd.Source -ArgumentList "install -g @angular/cli" -Wait -NoNewWindow -PassThru
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
        
        # Find Chocolatey lib folder dynamically
        $chocoRoot = Split-Path (Split-Path $chocoCmd.Source -Parent) -Parent
        $chocoLibPath = Join-Path $chocoRoot "lib"
        
        # Some packages have checksum issues - use --ignore-checksums for known problematic ones
        $ignoreChecksumPackages = @("googlechrome", "firefox", "chromium", "brave", "vivaldi", "opera")
        $extraArgs = @()
        if ($ignoreChecksumPackages -contains $PackageName.ToLowerInvariant()) {
            $extraArgs += "--ignore-checksums"
            Write-Log "Using --ignore-checksums for $PackageName (auto-updating package)" "INFO"
        }
        
        Write-Log "Running: choco install $PackageName -y --no-progress --limit-output $($extraArgs -join ' ')" "INFO"
        
        # Run choco directly without output redirection (more reliable in jobs)
        $chocoPath = $chocoCmd.Source
        $allArgs = @("install", $PackageName, "-y", "--no-progress", "--limit-output") + $extraArgs
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $chocoPath
        $psi.Arguments = $allArgs -join " "
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $false
        $psi.RedirectStandardError = $false
        
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        $exitCode = $proc.ExitCode
        $proc.Dispose()
        
        Write-Log "Chocolatey exit code for $PackageName : $exitCode" "INFO"
        
        # Refresh environment PATH after installation
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Wait for Chocolatey shim to finalize
        Start-Sleep -Seconds 2
        
        # Verify installation by checking Chocolatey lib folder
        $installed = $false
        if (Test-Path $chocoLibPath) {
            $libFolders = Get-ChildItem -Path $chocoLibPath -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name.ToLowerInvariant() -eq $PackageName.ToLowerInvariant() -or $_.Name -like "$PackageName.*" }
            if ($libFolders) {
                Write-Log "$PackageName verified in lib folder (found: $($libFolders[0].Name))" "SUCCESS"
                $installed = $true
            }
        }
        
        if ($exitCode -eq 0 -or $installed) {
            Write-Log "$PackageName installed successfully via Chocolatey" "SUCCESS"
            return $true
        } else {
            Write-Log "$PackageName installation failed (exit: $exitCode, found in lib: $installed)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Failed to install ${PackageName}: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Uninstall-ChocoPackage {
    param([string]$PackageName)
    
    Write-Log "Uninstalling $PackageName via Chocolatey"
    try {
        $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
        if (-not $chocoCmd) {
            Write-Log "Chocolatey not found. Cannot uninstall $PackageName." "ERROR"
            return $false
        }
        
        # Find Chocolatey lib folder dynamically
        $chocoRoot = Split-Path (Split-Path $chocoCmd.Source -Parent) -Parent
        $chocoLibPath = Join-Path $chocoRoot "lib"
        
        # Check if package is installed
        $packageFolder = $null
        if (Test-Path $chocoLibPath) {
            $packageFolder = Get-ChildItem -Path $chocoLibPath -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name.ToLowerInvariant() -eq $PackageName.ToLowerInvariant() -or $_.Name -like "$PackageName.*" }
        }
        
        if (-not $packageFolder) {
            Write-Log "$PackageName is not installed via Chocolatey. Nothing to uninstall." "INFO"
            return $true
        }
        
        Write-Log "Found $PackageName at: $($packageFolder[0].FullName)" "INFO"
        Write-Log "Running: choco uninstall $PackageName -y --no-progress" "INFO"
        
        # Run choco uninstall using Process class (reliable in background jobs)
        $chocoPath = $chocoCmd.Source
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $chocoPath
        $psi.Arguments = "uninstall $PackageName -y --no-progress --remove-dependencies"
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $false
        $psi.RedirectStandardError = $false
        
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        $exitCode = $proc.ExitCode
        $proc.Dispose()
        
        Write-Log "Chocolatey uninstall exit code for $PackageName : $exitCode" "INFO"
        
        # Wait for filesystem
        Start-Sleep -Seconds 2
        
        # Verify uninstallation
        $stillExists = $false
        if (Test-Path $chocoLibPath) {
            $remainingFolder = Get-ChildItem -Path $chocoLibPath -Directory -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name.ToLowerInvariant() -eq $PackageName.ToLowerInvariant() -or $_.Name -like "$PackageName.*" }
            $stillExists = $null -ne $remainingFolder
        }
        
        if ($exitCode -eq 0 -and -not $stillExists) {
            Write-Log "$PackageName uninstalled successfully via Chocolatey" "SUCCESS"
            return $true
        } elseif (-not $stillExists) {
            Write-Log "$PackageName appears uninstalled (folder removed)" "SUCCESS"
            return $true
        } elseif ($stillExists) {
            # Chocolatey failed but folder still exists - try to clean up orphaned folder
            Write-Log "$PackageName uninstall returned exit code $exitCode but folder still exists. Attempting manual cleanup..." "INFO"
            try {
                $remainingFolder = Get-ChildItem -Path $chocoLibPath -Directory -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name.ToLowerInvariant() -eq $PackageName.ToLowerInvariant() -or $_.Name -like "$PackageName.*" }
                if ($remainingFolder) {
                    Remove-Item -Path $remainingFolder[0].FullName -Recurse -Force -ErrorAction Stop
                    Write-Log "$PackageName folder manually removed from lib" "SUCCESS"
                    return $true
                }
            } catch {
                Write-Log "Failed to manually remove $PackageName folder: $($_.Exception.Message)" "ERROR"
            }
            Write-Log "$PackageName uninstall failed (exit: $exitCode, still exists: $stillExists)" "ERROR"
            return $false
        } else {
            Write-Log "$PackageName uninstall failed (exit: $exitCode, still exists: $stillExists)" "ERROR"
            return $false
        }
    } catch {
        Write-Log "Failed to uninstall ${PackageName}: $($_.Exception.Message)" "ERROR"
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
        
        $arguments = "upgrade $PackageName -y --no-progress --limit-output"
        $process = Start-Process "choco" -ArgumentList $arguments -Wait -NoNewWindow -PassThru
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
    Install-VSCode, Install-Composer, Install-XAMPP, Install-AngularCLI, Install-LaravelInstaller, `
    Install-Chocolatey, Install-ChocoPackage, Uninstall-ChocoPackage, Update-ChocoPackage
