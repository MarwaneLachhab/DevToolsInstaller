# VersionFetcher.psm1
# Module to fetch latest versions of development tools

function Get-LatestNodeVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://nodejs.org/dist/index.json" -UseBasicParsing
        $latest = $response | Where-Object { $_.lts -ne $false } | Select-Object -First 1
        return @{
            Version = $latest.version
            Url = "https://nodejs.org/dist/$($latest.version)/node-$($latest.version)-x64.msi"
        }
    } catch {
        Write-Warning "Failed to fetch Node.js version: $_"
        return $null
    }
}

function Get-LatestPythonVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://www.python.org/api/v2/downloads/release/?is_published=true" -UseBasicParsing
        $latest = $response | Where-Object { $_.name -match '^\d+\.\d+\.\d+$' } | Select-Object -First 1
        $version = $latest.name
        return @{
            Version = $version
            Url = "https://www.python.org/ftp/python/$version/python-$version-amd64.exe"
        }
    } catch {
        # Fallback to static version check
        try {
            $html = Invoke-WebRequest -Uri "https://www.python.org/downloads/" -UseBasicParsing
            if ($html.Content -match 'Python (\d+\.\d+\.\d+)') {
                $version = $matches[1]
                return @{
                    Version = $version
                    Url = "https://www.python.org/ftp/python/$version/python-$version-amd64.exe"
                }
            }
        } catch {}
        Write-Warning "Failed to fetch Python version: $_"
        return $null
    }
}

function Get-LatestVSCodeVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/vscode/releases/latest" -UseBasicParsing
        $version = $response.tag_name
        return @{
            Version = $version
            Url = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user"
        }
    } catch {
        Write-Warning "Failed to fetch VS Code version: $_"
        return @{
            Version = "latest"
            Url = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user"
        }
    }
}

function Get-LatestComposerVersion {
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/composer/composer/releases/latest" -UseBasicParsing
        return @{
            Version = $response.tag_name
            Url = "https://getcomposer.org/Composer-Setup.exe"
        }
    } catch {
        Write-Warning "Failed to fetch Composer version: $_"
        return @{
            Version = "latest"
            Url = "https://getcomposer.org/Composer-Setup.exe"
        }
    }
}

function Get-LatestXAMPPVersion {
    try {
        $html = Invoke-WebRequest -Uri "https://www.apachefriends.org/download.html" -UseBasicParsing
        if ($html.Content -match 'XAMPP for Windows (\d+\.\d+\.\d+)') {
            $version = $matches[1]
            # Get the download link
            if ($html.Content -match '(https://[^"]+/xampp-windows-x64-[^"]+\.exe)') {
                return @{
                    Version = $version
                    Url = $matches[1]
                }
            }
        }
        # Fallback to sourceforge
        return @{
            Version = "latest"
            Url = "https://sourceforge.net/projects/xampp/files/latest/download"
        }
    } catch {
        Write-Warning "Failed to fetch XAMPP version: $_"
        return @{
            Version = "latest"
            Url = "https://sourceforge.net/projects/xampp/files/latest/download"
        }
    }
}

function Get-LatestAngularCLI {
    try {
        $response = Invoke-RestMethod -Uri "https://registry.npmjs.org/@angular/cli/latest" -UseBasicParsing
        return @{
            Version = $response.version
            InstallCommand = "npm install -g @angular/cli@latest"
        }
    } catch {
        Write-Warning "Failed to fetch Angular CLI version: $_"
        return @{
            Version = "latest"
            InstallCommand = "npm install -g @angular/cli"
        }
    }
}

function Get-LatestReactInfo {
    try {
        $response = Invoke-RestMethod -Uri "https://registry.npmjs.org/react/latest" -UseBasicParsing
        return @{
            Version = $response.version
            InstallCommand = "npx create-react-app"
            Note = "Use 'npx create-react-app my-app' to create projects"
        }
    } catch {
        Write-Warning "Failed to fetch React version: $_"
        return @{
            Version = "latest"
            InstallCommand = "npx create-react-app"
            Note = "Use 'npx create-react-app my-app' to create projects"
        }
    }
}

function Get-LatestLaravelInstaller {
    try {
        $response = Invoke-RestMethod -Uri "https://registry.npmjs.org/laravel-installer/latest" -UseBasicParsing
        return @{
            Version = "latest (via Composer)"
            InstallCommand = "composer global require laravel/installer"
        }
    } catch {
        return @{
            Version = "latest"
            InstallCommand = "composer global require laravel/installer"
        }
    }
}

function Get-LatestChocolateyInfo {
    return @{
        Version = "latest"
        InstallCommand = "Official install script"
        Note = "Package manager for Windows - installs tools automatically"
    }
}

Export-ModuleMember -Function Get-LatestNodeVersion, Get-LatestPythonVersion, Get-LatestVSCodeVersion, `
    Get-LatestComposerVersion, Get-LatestXAMPPVersion, Get-LatestAngularCLI, Get-LatestReactInfo, Get-LatestLaravelInstaller, Get-LatestChocolateyInfo
