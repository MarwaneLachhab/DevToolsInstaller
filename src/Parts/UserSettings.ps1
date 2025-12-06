# User settings, caching, and utility helpers
function Invalidate-ToolCache {
    param([string]$ToolName)
    
    # Clear the specific tool from install cache
    if ($script:toolInstallCache -and $script:toolInstallCache.ContainsKey($ToolName)) {
        $script:toolInstallCache.Remove($ToolName) | Out-Null
    }
    
    # Clear choco cache for this package
    if ($script:toolPackageMap.ContainsKey($ToolName)) {
        $package = $script:toolPackageMap[$ToolName]
        $lower = $package.ToLowerInvariant()
        foreach ($key in @($package, $lower)) {
            if ($script:chocoPackageCache -and $script:chocoPackageCache.ContainsKey($key)) {
                $script:chocoPackageCache.Remove($key) | Out-Null
            }
        }
    }
    
    if (Get-Variable -Name chocoCacheTimestamp -Scope Script -ErrorAction SilentlyContinue) {
        $script:chocoCacheTimestamp = $null
    }
}

# Clear all caches (call after install/uninstall completes)
function Clear-AllToolCaches {
    $script:toolInstallCache = @{}
    $script:toolInstallCacheTime = $null
    $script:chocoPackageCache = @{}
    $script:chocoCacheTimestamp = $null
    $script:lastPathRefresh = $null
}

function Ensure-DownloadPath {
    if ([string]::IsNullOrWhiteSpace($script:downloadPath)) {
        $script:downloadPath = $script:defaultDownloadPath
    }
    if (-not (Test-Path $script:downloadPath)) {
        New-Item -Path $script:downloadPath -ItemType Directory -Force | Out-Null
    }
}

function Get-DefaultUserSettings {
    return [pscustomobject]@{
        DownloadPath = $script:defaultDownloadPath
        ChocolateyPath = "C:\Apps\Chocolatey"
        AutoRunHealthAfterInstall = $true
        AutoCheckUpdates = $false
        PreferredTheme = "Dark"
    }
}

function Get-ChocolateyPath {
    Ensure-UserSettingsProperties
    $path = Get-UserSettingValue -Name "ChocolateyPath" -Default "C:\Apps\Chocolatey"
    if ([string]::IsNullOrWhiteSpace($path)) {
        $path = "C:\Apps\Chocolatey"
    }
    return $path
}

function Ensure-UserSettingsProperties {
    if (-not $script:userSettings) {
        $script:userSettings = Get-DefaultUserSettings
    }
    
    switch ($script:userSettings.GetType().FullName) {
        "System.String" {
            try {
                $script:userSettings = $script:userSettings | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $script:userSettings = $null
            }
        }
        "System.Collections.Hashtable" {
            $script:userSettings = [pscustomobject]$script:userSettings
        }
    }
    
    if ($script:userSettings -isnot [pscustomobject]) {
        $script:userSettings = Get-DefaultUserSettings
    }
    
    $defaults = Get-DefaultUserSettings
    foreach ($property in $defaults.PSObject.Properties.Name) {
        if (-not $script:userSettings.PSObject.Properties.Match($property)) {
            $script:userSettings | Add-Member -NotePropertyName $property -NotePropertyValue $defaults.$property
        } elseif ($property -eq "DownloadPath" -and [string]::IsNullOrWhiteSpace($script:userSettings.$property)) {
            $script:userSettings.$property = $defaults.$property
        }
    }
}

function Set-UserSettingValue {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(ValueFromPipeline)]
        $Value
    )
    
    Ensure-UserSettingsProperties
    $property = $script:userSettings.PSObject.Properties[$Name]
    if ($property) {
        $property.Value = $Value
    } else {
        $script:userSettings | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Get-UserSettingValue {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        $Default = $null
    )
    
    Ensure-UserSettingsProperties
    $property = $script:userSettings.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }
    return $Default
}

function Load-UserSettings {
    $settingsSource = $null
    try {
        if (Test-Path $script:settingsPath) {
            $settingsSource = $script:settingsPath
        } elseif (Test-Path $script:legacySettingsPath) {
            $settingsSource = $script:legacySettingsPath
        }

        if ($settingsSource) {
            $script:userSettings = Get-Content -Path $settingsSource -Raw | ConvertFrom-Json
        } else {
            $script:userSettings = Get-DefaultUserSettings
        }
    } catch {
        $script:userSettings = Get-DefaultUserSettings
    }
    
    if (-not $script:userSettings) {
        $script:userSettings = Get-DefaultUserSettings
    }
    
    Ensure-UserSettingsProperties
    
    $script:downloadPath = $script:userSettings.DownloadPath
    $script:isDarkTheme = if ($script:userSettings.PreferredTheme -eq "Light") { $false } else { $true }
    $script:currentTheme = if ($script:isDarkTheme) { "Dark" } else { "Light" }
    
    Ensure-DownloadPath

    if (($settingsSource -eq $script:legacySettingsPath) -and -not (Test-Path $script:settingsPath)) {
        Save-UserSettings
    }
}

function Save-UserSettings {
    if (-not $script:userSettings) { return }
    
    $script:userSettings.DownloadPath = $script:downloadPath
    try {
        if (-not (Test-Path $script:settingsDir)) {
            New-Item -Path $script:settingsDir -ItemType Directory -Force | Out-Null
        }
        $json = $script:userSettings | ConvertTo-Json -Depth 5
        $encoding = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($script:settingsPath, $json, $encoding)
        if ($script:legacySettingsPath) {
            [System.IO.File]::WriteAllText($script:legacySettingsPath, $json, $encoding)
        }
    } catch {
        Write-Warning "Failed to save user settings: $_"
    }
}

Load-UserSettings

$script:packageDisplayNames = @{
    "git" = "Git"
    "googlechrome" = "Google Chrome"
    "7zip" = "7-Zip"
    "docker-desktop" = "Docker Desktop"
    "postman" = "Postman"
    "azure-cli" = "Azure CLI"
    "awscli" = "AWS CLI v2"
    "terraform" = "Terraform"
    "kubernetes-cli" = "Kubernetes CLI"
    "github-cli" = "GitHub CLI"
    "mysql.workbench" = "MySQL Workbench"
    "mongodb-compass" = "MongoDB Compass"
    "dbeaver" = "DBeaver"
    "pgadmin4" = "pgAdmin 4"
    "redis-64" = "Redis (Windows)"
    "intellijidea-community" = "IntelliJ IDEA Community"
    "pycharm-community" = "PyCharm Community"
    "androidstudio" = "Android Studio"
    "sublimetext3" = "Sublime Text"
    "notepadplusplus" = "Notepad++"
    "github-desktop" = "GitHub Desktop"
    "slack" = "Slack"
    "insomnia-rest-api-client" = "Insomnia"
    "microsoft-windows-terminal" = "Windows Terminal"
    "powertoys" = "Microsoft PowerToys"
}

function Get-PackageDisplayName {
    param([string]$PackageName)
    
    if ($script:packageDisplayNames.ContainsKey($PackageName)) {
        return $script:packageDisplayNames[$PackageName]
    }
    return $PackageName
}

function Get-VersionFromCommand {
    param(
        [string]$Command,
        [string[]]$Arguments = @("--version"),
        [string]$Pattern,
        [int]$TimeoutSeconds = 8
    )
    
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Command
        if ($Arguments -and $Arguments.Count -gt 0) {
            $quotedArgs = $Arguments | ForEach-Object {
                if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
            }
            $psi.Arguments = ($quotedArgs -join ' ')
        } else {
            $psi.Arguments = ""
        }
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        
        $process = [System.Diagnostics.Process]::Start($psi)
        if (-not $process) { return $null }
        
        $timeoutMs = [Math]::Max(1, $TimeoutSeconds) * 1000
        if (-not $process.WaitForExit($timeoutMs)) {
            try { $process.Kill() } catch { }
            return $null
        }
        
        $output = $process.StandardOutput.ReadToEnd()
        if ([string]::IsNullOrWhiteSpace($output)) {
            $output = $process.StandardError.ReadToEnd()
        }
        if ([string]::IsNullOrWhiteSpace($output)) { return $null }
        if ($Pattern -and ($output -match $Pattern)) {
            return $matches[1]
        }
        return ($output -split "`r?`n")[0].Trim()
    } catch {
        return $null
    }
}
