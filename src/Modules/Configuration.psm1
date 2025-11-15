# Configuration.psm1
# Module for post-installation configuration

function Add-VSCodeContextMenu {
    <#
    .SYNOPSIS
    Adds "Open with VS Code" to the right-click context menu
    #>
    
    try {
        Write-Host "Adding VS Code to context menu..." -ForegroundColor Cyan
        
        # For files
        $fileKey = "HKEY_CLASSES_ROOT\*\shell\VSCode"
        reg add $fileKey /ve /d "Open with VS Code" /f | Out-Null
        reg add $fileKey /v "Icon" /d "`"C:\Program Files\Microsoft VS Code\Code.exe`"" /f | Out-Null
        reg add "$fileKey\command" /ve /d "`"C:\Program Files\Microsoft VS Code\Code.exe`" `"%1`"" /f | Out-Null
        
        # For folders
        $folderKey = "HKEY_CLASSES_ROOT\Directory\shell\VSCode"
        reg add $folderKey /ve /d "Open with VS Code" /f | Out-Null
        reg add $folderKey /v "Icon" /d "`"C:\Program Files\Microsoft VS Code\Code.exe`"" /f | Out-Null
        reg add "$folderKey\command" /ve /d "`"C:\Program Files\Microsoft VS Code\Code.exe`" `"%V`"" /f | Out-Null
        
        # For directory background
        $bgKey = "HKEY_CLASSES_ROOT\Directory\Background\shell\VSCode"
        reg add $bgKey /ve /d "Open with VS Code" /f | Out-Null
        reg add $bgKey /v "Icon" /d "`"C:\Program Files\Microsoft VS Code\Code.exe`"" /f | Out-Null
        reg add "$bgKey\command" /ve /d "`"C:\Program Files\Microsoft VS Code\Code.exe`" `"%V`"" /f | Out-Null
        
        Write-Host "VS Code context menu added successfully!" -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "Failed to add VS Code context menu: $_"
        return $false
    }
}

function Add-MySQLToPath {
    <#
    .SYNOPSIS
    Adds XAMPP MySQL bin directory to system PATH
    #>
    
    try {
        Write-Host "Configuring MySQL PATH..." -ForegroundColor Cyan
        
        $xamppPath = "C:\xampp\mysql\bin"
        
        if (Test-Path $xamppPath) {
            # Get current PATH
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            
            # Check if already in PATH
            if ($currentPath -notlike "*$xamppPath*") {
                $newPath = "$currentPath;$xamppPath"
                [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
                
                # Update current session
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                
                Write-Host "MySQL added to PATH successfully!" -ForegroundColor Green
                Write-Host "You can now use 'mysql' command from any terminal" -ForegroundColor Yellow
                return $true
            } else {
                Write-Host "MySQL is already in PATH" -ForegroundColor Yellow
                return $true
            }
        } else {
            Write-Warning "XAMPP MySQL not found at $xamppPath"
            return $false
        }
    } catch {
        Write-Warning "Failed to add MySQL to PATH: $_"
        return $false
    }
}

function Add-PHPToPath {
    <#
    .SYNOPSIS
    Adds XAMPP PHP directory to system PATH
    #>
    
    try {
        Write-Host "Configuring PHP PATH..." -ForegroundColor Cyan
        
        $phpPath = "C:\xampp\php"
        
        if (Test-Path $phpPath) {
            # Get current PATH
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            
            # Check if already in PATH
            if ($currentPath -notlike "*$phpPath*") {
                $newPath = "$currentPath;$phpPath"
                [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
                
                # Update current session
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                
                Write-Host "PHP added to PATH successfully!" -ForegroundColor Green
                return $true
            } else {
                Write-Host "PHP is already in PATH" -ForegroundColor Yellow
                return $true
            }
        } else {
            Write-Warning "XAMPP PHP not found at $phpPath"
            return $false
        }
    } catch {
        Write-Warning "Failed to add PHP to PATH: $_"
        return $false
    }
}

function Add-ComposerToPath {
    <#
    .SYNOPSIS
    Adds Composer global vendor bin to PATH
    #>
    
    try {
        Write-Host "Configuring Composer global bin PATH..." -ForegroundColor Cyan
        
        $composerPath = "$env:APPDATA\Composer\vendor\bin"
        
        # Get current PATH
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        
        # Check if already in PATH
        if ($currentPath -notlike "*$composerPath*") {
            $newPath = "$currentPath;$composerPath"
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            
            # Update current session
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            Write-Host "Composer global bin added to PATH!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Composer global bin is already in PATH" -ForegroundColor Yellow
            return $true
        }
    } catch {
        Write-Warning "Failed to add Composer to PATH: $_"
        return $false
    }
}

function Set-XAMPPServices {
    <#
    .SYNOPSIS
    Creates quick start scripts for XAMPP services
    #>
    
    try {
        Write-Host "Creating XAMPP service management scripts..." -ForegroundColor Cyan
        
        $xamppControl = "C:\xampp\xampp-control.exe"
        
        if (Test-Path $xamppControl) {
            # Create desktop shortcuts
            $shell = New-Object -ComObject WScript.Shell
            
            # XAMPP Control Panel shortcut
            $shortcut = $shell.CreateShortcut("$env:USERPROFILE\Desktop\XAMPP Control.lnk")
            $shortcut.TargetPath = $xamppControl
            $shortcut.WorkingDirectory = "C:\xampp"
            $shortcut.Save()
            
            Write-Host "XAMPP Control Panel shortcut created on desktop" -ForegroundColor Green
            return $true
        } else {
            Write-Warning "XAMPP Control Panel not found"
            return $false
        }
    } catch {
        Write-Warning "Failed to configure XAMPP services: $_"
        return $false
    }
}

function Test-AdminRights {
    <#
    .SYNOPSIS
    Checks if script is running with administrator privileges
    #>
    
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-AllConfigurations {
    <#
    .SYNOPSIS
    Runs all post-installation configurations
    #>
    
    if (-not (Test-AdminRights)) {
        Write-Warning "Administrator privileges required for configurations!"
        return $false
    }
    
    $results = @()
    
    Write-Host "`n=== Running Post-Installation Configurations ===" -ForegroundColor Magenta
    
    $results += Add-VSCodeContextMenu
    $results += Add-MySQLToPath
    $results += Add-PHPToPath
    $results += Add-ComposerToPath
    $results += Set-XAMPPServices
    
    $successCount = ($results | Where-Object { $_ -eq $true }).Count
    Write-Host "`n$successCount of $($results.Count) configurations completed successfully" -ForegroundColor $(if($successCount -eq $results.Count){"Green"}else{"Yellow"})
    
    return $true
}

Export-ModuleMember -Function Add-VSCodeContextMenu, Add-MySQLToPath, Add-PHPToPath, `
    Add-ComposerToPath, Set-XAMPPServices, Test-AdminRights, Invoke-AllConfigurations
