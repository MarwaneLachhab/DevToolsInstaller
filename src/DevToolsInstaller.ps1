<#
================================================================================
    Development Tools Installer V2.0
    Created by: SPARO
    Date: November 2025
    License: MIT License - Free to use and modify
    
    Description: Enhanced GUI installer with sidebar navigation, theme toggle,
                 installation profiles, VS Code extensions, and more!
    
    Usage: Run as Administrator
           Double-click LAUNCH.ps1 or run src\DevToolsInstaller.ps1 directly
================================================================================
#>

# Set UTF-8 encoding for proper emoji display (console + WPF)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import modules
$modulePath = Join-Path $PSScriptRoot "Modules"
Import-Module (Join-Path $modulePath "VersionFetcher.psm1") -Force
Import-Module (Join-Path $modulePath "Installer.psm1") -Force
Import-Module (Join-Path $modulePath "Configuration.psm1") -Force
Import-Module (Join-Path $modulePath "VSCodeExtensions.psm1") -Force

# Check for admin rights
if (-not (Test-AdminRights)) {
    $result = [System.Windows.MessageBox]::Show(
        "This application requires Administrator privileges.`n`nWould you like to restart as Administrator?",
        "Administrator Rights Required",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )
    
    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
        Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    }
    exit
}

# Global variables
$script:selectedTools = @{}
$script:versionInfo = @{}
$script:defaultDownloadPath = Join-Path $PSScriptRoot "Downloads"
$script:legacySettingsPath = Join-Path $PSScriptRoot "user-settings.json"
$script:settingsDir = Join-Path ([Environment]::GetFolderPath("ApplicationData")) "DevToolsInstaller"
$script:settingsPath = Join-Path $script:settingsDir "user-settings.json"
$script:downloadPath = $script:defaultDownloadPath
$script:userSettings = $null
$script:isDarkTheme = $true
$script:currentTheme = "Dark"  # Track current theme
$script:currentPage = "Tools"
$script:lastHealthResults = @()
$script:lastUpdateResults = @()
$script:lastHealthRun = $null
$script:lastUpdateRun = $null
$script:isSidebarCollapsed = $false
$script:healthScanWorker = $null

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
        AutoRunHealthAfterInstall = $true
        AutoCheckUpdates = $false
        PreferredTheme = "Dark"
    }
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

# Theme colors
$script:themes = @{
    Dark = @{
        Background = "#FF0F141B"
        Panel = "#FF1A222C"
        Surface = "#FF1F2A37"
        Sidebar = "#FF131B24"
        SidebarHover = "#FF1F2733"
        SidebarActive = "#FF3A86FF"
        Text = "#FFFFFFFF"
        TextSecondary = "#FF9DB4D0"
        Accent = "#FF3A86FF"
        AccentHover = "#FF2F6FD2"
        Success = "#FF3DD598"
        Warning = "#FFFFB347"
        Error = "#FFFF6B81"
    }
    Light = @{
        Background = "#FFF7F9FC"
        Panel = "#FFFFFFFF"
        Surface = "#FFF0F4FA"
        Sidebar = "#FFE6ECF5"
        SidebarHover = "#FFD9E3F1"
        SidebarActive = "#FF2563EB"
        Text = "#FF0F172A"
        TextSecondary = "#FF475569"
        Accent = "#FF2563EB"
        AccentHover = "#FF1D4ED8"
        Success = "#FF0F9D58"
        Warning = "#FFF59E0B"
        Error = "#FFDC2626"
    }
}

# XAML for enhanced GUI with sidebar
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Development Tools Installer V2" 
        Height="800" Width="1200"
        WindowStartupLocation="CenterScreen"
        Background="{DynamicResource BgColor}"
        FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"
        SnapsToDevicePixels="True"
        TextOptions.TextFormattingMode="Ideal">
    
    <Window.Resources>
        <!-- Dynamic Theme Colors -->
        <SolidColorBrush x:Key="BgColor" Color="#FF0F141B"/>
        <SolidColorBrush x:Key="PanelColor" Color="#FF1A222C"/>
        <SolidColorBrush x:Key="SurfaceColor" Color="#FF1F2A37"/>
        <SolidColorBrush x:Key="SidebarColor" Color="#FF131B24"/>
        <SolidColorBrush x:Key="SidebarHoverColor" Color="#FF1F2733"/>
        <SolidColorBrush x:Key="SidebarActiveColor" Color="#FF3A86FF"/>
        <SolidColorBrush x:Key="TextColor" Color="#FFFFFFFF"/>
        <SolidColorBrush x:Key="TextSecondaryColor" Color="#FF9DB4D0"/>
        <SolidColorBrush x:Key="AccentColor" Color="#FF3A86FF"/>
        <SolidColorBrush x:Key="AccentHoverColor" Color="#FF2F6FD2"/>
        <LinearGradientBrush x:Key="HeaderGradient" StartPoint="0,0" EndPoint="1,1">
            <GradientStop Color="#FF1A222C" Offset="0"/>
            <GradientStop Color="#FF3A86FF" Offset="1"/>
        </LinearGradientBrush>
        <DropShadowEffect x:Key="CardShadow" Color="#AA000000" BlurRadius="18" ShadowDepth="0" Opacity="0.35"/>
        
        <!-- Sidebar Button Style -->
        <Style x:Key="SidebarButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{DynamicResource TextColor}"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Height" Value="48"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Padding" Value="20,0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Margin" Value="0,4"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border"
                                Background="{TemplateBinding Background}"
                                CornerRadius="14">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{DynamicResource SidebarHoverColor}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <!-- Main Button Style -->
        <Style x:Key="MainButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="{DynamicResource AccentColor}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="Margin" Value="10"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect Color="#80000000" BlurRadius="12" ShadowDepth="1" Opacity="0.35"/>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{DynamicResource AccentHoverColor}"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        
        <!-- Toggle style for dark/light switch -->
        <Style x:Key="ToggleSwitchStyle" TargetType="ToggleButton">
            <Setter Property="Width" Value="64"/>
            <Setter Property="Height" Value="30"/>
            <Setter Property="Background" Value="{DynamicResource SidebarHoverColor}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToggleButton">
                        <Grid>
                            <Border x:Name="Track"
                                    Background="{TemplateBinding Background}"
                                    CornerRadius="15"/>
                            <Border x:Name="Thumb"
                                    Width="26"
                                    Height="26"
                                    CornerRadius="13"
                                    Margin="2"
                                    Background="{DynamicResource TextColor}"
                                    HorizontalAlignment="Left"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Track" Property="Background" Value="{DynamicResource AccentColor}"/>
                                <Setter TargetName="Thumb" Property="HorizontalAlignment" Value="Right"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Track" Property="Opacity" Value="0.5"/>
                                <Setter TargetName="Thumb" Property="Opacity" Value="0.5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="IconButtonStyle" TargetType="Button">
            <Setter Property="Width" Value="44"/>
            <Setter Property="Height" Value="44"/>
            <Setter Property="Background" Value="{DynamicResource SurfaceColor}"/>
            <Setter Property="Foreground" Value="{DynamicResource TextColor}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource AccentColor}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontSize" Value="18"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="iconBorder"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="14">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="iconBorder" Property="Background" Value="{DynamicResource AccentHoverColor}"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    
    <Grid Margin="20">
        <Grid.ColumnDefinitions>
            <ColumnDefinition x:Name="SidebarColumn" Width="Auto"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        
        <!-- Sidebar -->
        <Border x:Name="sidebarContainer"
                Grid.Column="0"
                Width="260"
                MinWidth="72"
                Margin="0,0,20,0"
                Padding="16"
                Background="{DynamicResource SidebarColor}"
                CornerRadius="22"
                Effect="{DynamicResource CardShadow}">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <!-- Logo/Title -->
                <StackPanel x:Name="sidebarBranding" Grid.Row="0" Margin="0,0,0,8">
                    <TextBlock FontSize="20" FontWeight="Bold" 
                              Foreground="{DynamicResource TextColor}" 
                              Margin="0,6,0,4" HorizontalAlignment="Left">
                        <Run FontFamily="Segoe UI Emoji" Text="🚀 "/>
                        <Run Text="Dev Tools Hub"/>
                    </TextBlock>
                    <TextBlock Text="crafted by SPARO" FontSize="12" 
                              Foreground="{DynamicResource TextSecondaryColor}"
                              Margin="0,0,0,12"/>
                </StackPanel>
                
                <!-- Navigation Buttons -->
                <StackPanel Grid.Row="1">
                    <Button x:Name="btnNavTools" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="📦" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavTools" Text="Install Tools" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavProfiles" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="⭐" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavProfiles" Text="Profiles" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavExtensions" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="🧩" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavExtensions" Text="VS Code Ext" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavHealth" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="🏥" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavHealth" Text="Health Check" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavUpdate" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="🔄" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavUpdate" Text="Updates" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavSettings" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="⚙️" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavSettings" Text="Settings" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavAbout" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="ℹ️" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavAbout" Text="About" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                </StackPanel>
                
                <!-- Theme Toggle (Bottom) -->
                <Border x:Name="themeCard" Grid.Row="2" Background="{DynamicResource SurfaceColor}" CornerRadius="16" Padding="15" Margin="0,16,0,0">
                    <StackPanel x:Name="themeLayout" Orientation="Vertical" HorizontalAlignment="Stretch">
                        <TextBlock x:Name="txtThemeLabel" Text="Theme" FontSize="13" FontWeight="SemiBold"
                                   Foreground="{DynamicResource TextColor}" HorizontalAlignment="Center"/>
                        <StackPanel x:Name="themeSwitchPanel" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10,0,0" VerticalAlignment="Center">
                            <ToggleButton x:Name="btnThemeToggle"
                                          Style="{StaticResource ToggleSwitchStyle}"
                                          Background="{DynamicResource SidebarHoverColor}"
                                          IsChecked="True"
                                          Margin="0,0,12,0"/>
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <TextBlock x:Name="runThemeStatusIcon" FontFamily="Segoe UI Emoji" Text="🌙" Margin="0,0,6,0"/>
                                <TextBlock x:Name="runThemeStatusText" Text=" Dark Mode" Foreground="{DynamicResource TextSecondaryColor}" FontSize="12"/>
                            </StackPanel>
                        </StackPanel>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>
        
        <!-- Main Content Area -->
        <Grid Grid.Column="1">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <!-- Header -->
            <Border Grid.Row="0" Background="{DynamicResource HeaderGradient}" Padding="20" CornerRadius="20" Margin="0,0,0,16" Effect="{DynamicResource CardShadow}">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Button x:Name="btnSidebarToggle" Grid.Column="0" Style="{StaticResource IconButtonStyle}" Content="⟨" Margin="0,0,16,0"/>
                    <StackPanel Grid.Column="1">
                        <TextBlock x:Name="txtPageTitle" Text="Install Development Tools" 
                              FontSize="26" FontWeight="Bold" 
                              Foreground="{DynamicResource TextColor}"/>
                        <TextBlock x:Name="txtPageSubtitle" Text="Select tools to install automatically" 
                              FontSize="13" Foreground="{DynamicResource TextSecondaryColor}"
                              Margin="0,6,0,0"/>
                    </StackPanel>
                </Grid>
            </Border>
            
            <!-- Fixed Action Bar (Top Buttons) -->
            <Border Grid.Row="1" x:Name="actionBar" Background="{DynamicResource PanelColor}" 
                    Padding="18,14"
                    CornerRadius="18"
                    Margin="0,0,0,16"
                    Effect="{DynamicResource CardShadow}"
                    Visibility="Collapsed">
                <StackPanel x:Name="actionBarContent" Orientation="Horizontal" HorizontalAlignment="Center">
                    <!-- Buttons loaded dynamically per page -->
                </StackPanel>
            </Border>
            
            <!-- Main Content (MultiPage) -->
            <Border Grid.Row="2" Background="{DynamicResource PanelColor}" CornerRadius="22" Padding="10" Effect="{DynamicResource CardShadow}">
                <ScrollViewer x:Name="mainContent" VerticalScrollBarVisibility="Auto" Margin="0">
                    <!-- Content loaded dynamically -->
                </ScrollViewer>
            </Border>
            
            <!-- Status Bar -->
            <Border Grid.Row="3" Background="{DynamicResource PanelColor}" Padding="15" CornerRadius="18" Margin="0,16,0,0" Effect="{DynamicResource CardShadow}">
                <StackPanel>
                    <TextBlock x:Name="txtStatus" Foreground="{DynamicResource TextColor}" 
                              FontSize="13" Margin="0,0,0,5" Text="Ready"/>
                    <ProgressBar x:Name="progressBar" Height="22" Minimum="0" Maximum="100" Value="0"/>
                </StackPanel>
            </Border>
        </Grid>
    </Grid>
</Window>
"@

# Load XAML
$window = [Windows.Markup.XamlReader]::Parse($xaml)

# Get controls
$controls = @{
    # Sidebar
    sidebarContainer = $window.FindName("sidebarContainer")
    sidebarBranding = $window.FindName("sidebarBranding")
    themeCard = $window.FindName("themeCard")
    themeLayout = $window.FindName("themeLayout")
    themeSwitchPanel = $window.FindName("themeSwitchPanel")
    themeLabel = $window.FindName("txtThemeLabel")
    btnNavTools = $window.FindName("btnNavTools")
    btnNavProfiles = $window.FindName("btnNavProfiles")
    btnNavExtensions = $window.FindName("btnNavExtensions")
    btnNavHealth = $window.FindName("btnNavHealth")
    btnNavUpdate = $window.FindName("btnNavUpdate")
    btnNavSettings = $window.FindName("btnNavSettings")
    btnNavAbout = $window.FindName("btnNavAbout")
    btnThemeToggle = $window.FindName("btnThemeToggle")
    runThemeStatusIcon = $window.FindName("runThemeStatusIcon")
    runThemeStatusText = $window.FindName("runThemeStatusText")
    btnSidebarToggle = $window.FindName("btnSidebarToggle")
    lblNavTools = $window.FindName("lblNavTools")
    lblNavProfiles = $window.FindName("lblNavProfiles")
    lblNavExtensions = $window.FindName("lblNavExtensions")
    lblNavHealth = $window.FindName("lblNavHealth")
    lblNavUpdate = $window.FindName("lblNavUpdate")
    lblNavSettings = $window.FindName("lblNavSettings")
    lblNavAbout = $window.FindName("lblNavAbout")
    
    # Header
    txtPageTitle = $window.FindName("txtPageTitle")
    txtPageSubtitle = $window.FindName("txtPageSubtitle")
    
    # Action Bar
    actionBar = $window.FindName("actionBar")
    actionBarContent = $window.FindName("actionBarContent")
    
    # Content
    mainContent = $window.FindName("mainContent")
    
    # Status
    txtStatus = $window.FindName("txtStatus")
    progressBar = $window.FindName("progressBar")
}

$controls.sidebarButtons = @(
    $controls.btnNavTools,
    $controls.btnNavProfiles,
    $controls.btnNavExtensions,
    $controls.btnNavHealth,
    $controls.btnNavUpdate,
    $controls.btnNavSettings,
    $controls.btnNavAbout
) | Where-Object { $_ }

$controls.sidebarLabels = @(
    $controls.lblNavTools,
    $controls.lblNavProfiles,
    $controls.lblNavExtensions,
    $controls.lblNavHealth,
    $controls.lblNavUpdate,
    $controls.lblNavSettings,
    $controls.lblNavAbout
) | Where-Object { $_ }

# Helper to create SolidColorBrush from #AARRGGBB / #RRGGBB hex
function New-ThemeBrush {
    param([string]$ColorHex)

    if ([string]::IsNullOrWhiteSpace($ColorHex)) {
        return [System.Windows.Media.Brushes]::Transparent.CloneCurrentValue()
    }

    $hex = $ColorHex.Trim()
    if ($hex.StartsWith("#")) {
        $hex = $hex.Substring(1)
    }

    switch ($hex.Length) {
        6 {
            $a = 255
            $r = [Convert]::ToByte($hex.Substring(0,2),16)
            $g = [Convert]::ToByte($hex.Substring(2,2),16)
            $b = [Convert]::ToByte($hex.Substring(4,2),16)
        }
        8 {
            $a = [Convert]::ToByte($hex.Substring(0,2),16)
            $r = [Convert]::ToByte($hex.Substring(2,2),16)
            $g = [Convert]::ToByte($hex.Substring(4,2),16)
            $b = [Convert]::ToByte($hex.Substring(6,2),16)
        }
        default {
            throw "Cannot parse color hex value '$ColorHex'"
        }
    }

    $color = [System.Windows.Media.Color]::FromArgb($a,$r,$g,$b)
    $brush = New-Object System.Windows.Media.SolidColorBrush $color
    if ($brush.CanFreeze) {
        $brush.Freeze()
    }
    return $brush.CloneCurrentValue()
}

function New-GradientBrush {
    param(
        [string]$StartColor,
        [string]$EndColor
    )

    try {
        $start = [System.Windows.Media.ColorConverter]::ConvertFromString($StartColor)
        $end = [System.Windows.Media.ColorConverter]::ConvertFromString($EndColor)
    } catch {
        $start = [System.Windows.Media.Colors]::Transparent
        $end = [System.Windows.Media.Colors]::Transparent
    }

    $brush = New-Object System.Windows.Media.LinearGradientBrush
    $brush.StartPoint = [System.Windows.Point]::new(0,0)
    $brush.EndPoint = [System.Windows.Point]::new(1,1)
    $brush.GradientStops.Add([System.Windows.Media.GradientStop]::new($start, 0))
    $brush.GradientStops.Add([System.Windows.Media.GradientStop]::new($end, 1))
    if ($brush.CanFreeze) { $brush.Freeze() }
    return $brush.CloneCurrentValue()
}

# Function to apply theme
function Set-Theme {
    param([bool]$Dark)
    
    $theme = if ($Dark) { $script:themes.Dark } else { $script:themes.Light }
    $script:currentTheme = if ($Dark) { "Dark" } else { "Light" }
    
    $window.Resources["BgColor"] = New-ThemeBrush $theme.Background
    $window.Resources["PanelColor"] = New-ThemeBrush $theme.Panel
    $window.Resources["SurfaceColor"] = New-ThemeBrush $theme.Surface
    $window.Resources["SidebarColor"] = New-ThemeBrush $theme.Sidebar
    $window.Resources["SidebarHoverColor"] = New-ThemeBrush $theme.SidebarHover
    $window.Resources["SidebarActiveColor"] = New-ThemeBrush $theme.SidebarActive
    $window.Resources["TextColor"] = New-ThemeBrush $theme.Text
    $window.Resources["TextSecondaryColor"] = New-ThemeBrush $theme.TextSecondary
    $window.Resources["AccentColor"] = New-ThemeBrush $theme.Accent
    $window.Resources["AccentHoverColor"] = New-ThemeBrush $theme.AccentHover
    $window.Resources["HeaderGradient"] = New-GradientBrush -StartColor $theme.Panel -EndColor $theme.Accent
    
    if ($controls.btnThemeToggle -and $controls.btnThemeToggle.IsChecked -ne $Dark) {
        $controls.btnThemeToggle.IsChecked = $Dark
    }
        if ($controls.runThemeStatusIcon) {
            $controls.runThemeStatusIcon.Text = if ($Dark) { "🌙" } else { "☀️" }
        }
        if ($controls.runThemeStatusText) {
            $controls.runThemeStatusText.Text = if ($Dark) { " Dark Mode" } else { " Light Mode" }
        }
    # Reload current page to apply theme to dynamic content
    if ($script:currentPage) {
        Load-Page $script:currentPage
    }

    Update-SidebarVisualState -Collapsed:$script:isSidebarCollapsed
}
function Update-SidebarVisualState {
    param(
        [bool]$Collapsed,
        [switch]$Animate
    )

    $script:isSidebarCollapsed = $Collapsed
    $targetWidth = if ($Collapsed) { 72 } else { 260 }
    $labelVisibility = if ($Collapsed) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }

    if ($controls.sidebarContainer) {
        $controls.sidebarContainer.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $null)
        if ($Animate) {
            $animation = New-Object System.Windows.Media.Animation.DoubleAnimation
            $animation.To = $targetWidth
            $animation.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(240))
            $animation.EasingFunction = New-Object System.Windows.Media.Animation.QuadraticEase -Property @{ EasingMode = "EaseInOut" }
            $controls.sidebarContainer.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $animation)
        } else {
            $controls.sidebarContainer.Width = $targetWidth
        }
    }

    foreach ($label in $controls.sidebarLabels) {
        if ($label) { $label.Visibility = $labelVisibility }
    }

    foreach ($element in @($controls.sidebarBranding)) {
        if ($element) { $element.Visibility = $labelVisibility }
    }
    if ($controls.themeCard) {
        $controls.themeCard.Visibility = [System.Windows.Visibility]::Visible
        $controls.themeCard.Padding = if ($Collapsed) { "10" } else { "15" }
        $controls.themeCard.Margin = if ($Collapsed) { "0,8,0,0" } else { "0,16,0,0" }
    }
    if ($controls.themeLabel) {
        $controls.themeLabel.Visibility = if ($Collapsed) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
    }
    if ($controls.themeLayout) {
        $controls.themeLayout.HorizontalAlignment = if ($Collapsed) { "Center" } else { "Stretch" }
        $controls.themeLayout.Margin = if ($Collapsed) { "0" } else { "0" }
    }
    if ($controls.themeSwitchPanel) {
        $controls.themeSwitchPanel.Margin = if ($Collapsed) { "0" } else { "0,10,0,0" }
        $controls.themeSwitchPanel.HorizontalAlignment = if ($Collapsed) { "Center" } else { "Center" }
        $controls.themeSwitchPanel.Orientation = "Horizontal"
    }

    $padding = if ($Collapsed) { "10,0" } else { "20,0" }
    $contentAlignment = if ($Collapsed) { "Center" } else { "Left" }
    foreach ($button in $controls.sidebarButtons) {
        if ($button) {
            $button.Padding = $padding
            $button.HorizontalContentAlignment = $contentAlignment
        }
    }

    if ($controls.btnSidebarToggle) {
        $controls.btnSidebarToggle.Content = if ($Collapsed) { "☰" } else { "⟨" }
        $controls.btnSidebarToggle.ToolTip = if ($Collapsed) { "Expand sidebar" } else { "Collapse sidebar" }
    }
}

function Toggle-Sidebar {
    Update-SidebarVisualState -Collapsed:(-not $script:isSidebarCollapsed) -Animate
}

function Set-EmojiContent {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Controls.ContentControl]$Control,
        [Parameter(Mandatory = $true)]
        [string]$Emoji,
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [int]$FontSize = 14
    )
    
    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Orientation = "Horizontal"
    $panel.VerticalAlignment = "Center"
    $panel.Margin = "0"
    
    $icon = New-Object System.Windows.Controls.TextBlock
    $icon.Text = $Emoji
    $icon.FontFamily = "Segoe UI Emoji"
    $icon.Margin = "0,0,8,0"
    $icon.FontSize = $FontSize
    $icon.Foreground = $Control.Foreground
    
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $Text
    $label.FontSize = $FontSize
    $label.Foreground = $Control.Foreground
    
    $panel.Children.Add($icon) | Out-Null
    $panel.Children.Add($label) | Out-Null
    
    $Control.Content = $panel
}

# Function to create Tools page content
function Get-ToolsPageContent {
    # Get current theme colors from main window
    $bgColor = if ($script:currentTheme -eq "Dark") { "#2D2D30" } else { "#F3F3F3" }
    $textColor = if ($script:currentTheme -eq "Dark") { "White" } else { "Black" }
    $accentColor = "#007ACC"
    
    $xaml = @"
<StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" 
            TextElement.FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"
            Margin="20">
    <!-- Package Manager -->
    <Border Background="$bgColor" Padding="15" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="Package Manager" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <CheckBox x:Name="chkChocolatey" Foreground="$textColor" FontSize="13" Margin="0,5">
                <TextBlock><Run Text="Chocolatey"/><Run Text=" - Latest" Foreground="$accentColor"/></TextBlock>
            </CheckBox>
        </StackPanel>
    </Border>
    
    <!-- Core Development -->
    <Border Background="$bgColor" Padding="15" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="Core Development Tools" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <CheckBox x:Name="chkNodeJS" Foreground="$textColor" FontSize="13" Margin="0,5">
                <TextBlock><Run x:Name="txtNodeVersion" Text="Node.js - Checking..."/></TextBlock>
            </CheckBox>
            <CheckBox x:Name="chkPython" Foreground="$textColor" FontSize="13" Margin="0,5">
                <TextBlock><Run x:Name="txtPythonVersion" Text="Python - Checking..."/></TextBlock>
            </CheckBox>
            <CheckBox x:Name="chkVSCode" Foreground="$textColor" FontSize="13" Margin="0,5">
                <TextBlock><Run x:Name="txtVSCodeVersion" Text="VS Code - Checking..."/></TextBlock>
            </CheckBox>
            <CheckBox x:Name="chkGit" Foreground="$textColor" FontSize="13" Margin="0,5">
                <TextBlock><Run Text="Git"/><Run Text=" - Latest" Foreground="$accentColor"/></TextBlock>
            </CheckBox>
        </StackPanel>
    </Border>
    
    <!-- Web Frameworks -->
    <Border Background="$bgColor" Padding="15" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="Web Development" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <CheckBox x:Name="chkAngular" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Angular CLI (requires Node.js)"/>
            <CheckBox x:Name="chkReact" Foreground="$textColor" FontSize="13" Margin="0,5" Content="React (create-react-app)"/>
            <CheckBox x:Name="chkDocker" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Docker Desktop"/>
            <CheckBox x:Name="chkPostman" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Postman API Tool"/>
        </StackPanel>
    </Border>
    
    <!-- PHP Development -->
    <Border Background="$bgColor" Padding="15" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="PHP Development" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <CheckBox x:Name="chkXAMPP" Foreground="$textColor" FontSize="13" Margin="0,5">
                <TextBlock><Run x:Name="txtXAMPPVersion" Text="XAMPP - Checking..."/></TextBlock>
            </CheckBox>
            <CheckBox x:Name="chkComposer" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Composer (requires PHP)"/>
            <CheckBox x:Name="chkLaravel" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Laravel Installer"/>
        </StackPanel>
    </Border>
    
    <!-- Additional Tools -->
    <Border Background="$bgColor" Padding="15" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="Additional Tools" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <CheckBox x:Name="chkChrome" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Google Chrome"/>
            <CheckBox x:Name="chk7Zip" Foreground="$textColor" FontSize="13" Margin="0,5" Content="7-Zip"/>
        </StackPanel>
    </Border>
    
    <!-- Cloud & DevOps -->
    <Border Background="$bgColor" Padding="15" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="Cloud &amp; DevOps" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <CheckBox x:Name="chkAzureCLI" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Azure CLI (az)"/>
            <CheckBox x:Name="chkAWSCLI" Foreground="$textColor" FontSize="13" Margin="0,5" Content="AWS CLI v2"/>
            <CheckBox x:Name="chkTerraform" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Terraform"/>
            <CheckBox x:Name="chkKubectl" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Kubernetes CLI (kubectl)"/>
            <CheckBox x:Name="chkGitHubCLI" Foreground="$textColor" FontSize="13" Margin="0,5" Content="GitHub CLI (gh)"/>
        </StackPanel>
    </Border>
    
    <!-- Databases & Data Tools -->
    <Border Background="$bgColor" Padding="15" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="Database &amp; Data Tools" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <CheckBox x:Name="chkMySQLWorkbench" Foreground="$textColor" FontSize="13" Margin="0,5" Content="MySQL Workbench"/>
            <CheckBox x:Name="chkMongoDBCompass" Foreground="$textColor" FontSize="13" Margin="0,5" Content="MongoDB Compass"/>
            <CheckBox x:Name="chkDBeaver" Foreground="$textColor" FontSize="13" Margin="0,5" Content="DBeaver Community"/>
            <CheckBox x:Name="chkPgAdmin" Foreground="$textColor" FontSize="13" Margin="0,5" Content="pgAdmin 4"/>
            <CheckBox x:Name="chkRedis" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Redis (Windows port)"/>
        </StackPanel>
    </Border>
    
    <!-- IDEs & Editors -->
    <Border Background="$bgColor" Padding="15" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="IDEs &amp; Editors" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <CheckBox x:Name="chkIntelliJ" Foreground="$textColor" FontSize="13" Margin="0,5" Content="IntelliJ IDEA Community"/>
            <CheckBox x:Name="chkPyCharm" Foreground="$textColor" FontSize="13" Margin="0,5" Content="PyCharm Community"/>
            <CheckBox x:Name="chkAndroidStudio" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Android Studio"/>
            <CheckBox x:Name="chkSublime" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Sublime Text 3"/>
            <CheckBox x:Name="chkNotepadPP" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Notepad++"/>
        </StackPanel>
    </Border>
    
    <!-- Collaboration & Productivity -->
    <Border Background="$bgColor" Padding="15" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="Collaboration &amp; Productivity" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <CheckBox x:Name="chkGitHubDesktop" Foreground="$textColor" FontSize="13" Margin="0,5" Content="GitHub Desktop"/>
            <CheckBox x:Name="chkSlack" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Slack Desktop"/>
            <CheckBox x:Name="chkInsomnia" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Insomnia API Client"/>
            <CheckBox x:Name="chkWindowsTerminal" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Windows Terminal"/>
            <CheckBox x:Name="chkPowerToys" Foreground="$textColor" FontSize="13" Margin="0,5" Content="Microsoft PowerToys"/>
        </StackPanel>
    </Border>
    
    <!-- Configuration Options -->
    <Border Background="$bgColor" Padding="15" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="Configuration Options" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <CheckBox x:Name="chkVSCodeContext" Foreground="$textColor" FontSize="13" Margin="0,5" 
                     Content="Add VS Code to Right-Click Menu" IsChecked="True"/>
            <CheckBox x:Name="chkAddPaths" Foreground="$textColor" FontSize="13" Margin="0,5" 
                     Content="Add MySQL/PHP to PATH" IsChecked="True"/>
            <CheckBox x:Name="chkXAMPPShortcut" Foreground="$textColor" FontSize="13" Margin="0,5" 
                     Content="Create XAMPP Desktop Shortcut" IsChecked="True"/>
        </StackPanel>
    </Border>
</StackPanel>
"@
    return $xaml
}

# Function to create Profiles page content
function Get-ProfilesPageContent {
    # Get current theme colors
    $bgColor = if ($script:currentTheme -eq "Dark") { "#2D2D30" } else { "#F3F3F3" }
    $textColor = if ($script:currentTheme -eq "Dark") { "White" } else { "Black" }
    $textSecondary = if ($script:currentTheme -eq "Dark") { "#B0B0B0" } else { "#666666" }
    $accentColor = "#007ACC"
    
    $xaml = @"
<StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" 
            TextElement.FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"
            Margin="20">
    <TextBlock Text="Installation Profiles" FontSize="18" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
    <TextBlock Text="One-click installation bundles for common development scenarios" FontSize="12" 
              Foreground="$textSecondary" Margin="0,0,0,20" TextWrapping="Wrap"/>
    
    <!-- Web Developer Profile -->
    <Border Background="$bgColor" Padding="20" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="🌐 Web Developer Starter" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <TextBlock Text="Essential tools for modern web development" FontSize="12" Foreground="$textSecondary" Margin="0,0,0,10" TextWrapping="Wrap"/>
            <TextBlock Foreground="$textColor" FontSize="12" Margin="0,5">
                <Run Text="📦 Includes: "/>
                <Run Text="Node.js, VS Code, Git, Chrome, Postman, Angular CLI, React" Foreground="$accentColor"/>
            </TextBlock>
            <Button x:Name="btnProfileWeb" Content="Install Web Developer Bundle" 
                    Background="$accentColor" Foreground="White" 
                    Padding="15,8" FontSize="14" FontWeight="SemiBold" 
                    BorderThickness="0" Cursor="Hand" 
                    HorizontalAlignment="Left" Margin="0,10,0,0"/>
        </StackPanel>
    </Border>
    
    <!-- PHP Developer Profile -->
    <Border Background="$bgColor" Padding="20" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="🐘 PHP Full Stack" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <TextBlock Text="Complete PHP development environment with database" FontSize="12" Foreground="$textSecondary" Margin="0,0,0,10" TextWrapping="Wrap"/>
            <TextBlock Foreground="$textColor" FontSize="12" Margin="0,5">
                <Run Text="📦 Includes: "/>
                <Run Text="XAMPP, Composer, Laravel, VS Code, Git, Postman" Foreground="$accentColor"/>
            </TextBlock>
            <Button x:Name="btnProfilePHP" Content="Install PHP Full Stack" 
                    Background="$accentColor" Foreground="White" 
                    Padding="15,8" FontSize="14" FontWeight="SemiBold" 
                    BorderThickness="0" Cursor="Hand" 
                    HorizontalAlignment="Left" Margin="0,10,0,0"/>
        </StackPanel>
    </Border>
    
    <!-- Python Developer Profile -->
    <Border Background="$bgColor" Padding="20" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="🐍 Python Data Science" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <TextBlock Text="Python environment with essential data science tools" FontSize="12" Foreground="$textSecondary" Margin="0,0,0,10" TextWrapping="Wrap"/>
            <TextBlock Foreground="$textColor" FontSize="12" Margin="0,5">
                <Run Text="📦 Includes: "/>
                <Run Text="Python, VS Code, Git, Docker, Chrome" Foreground="$accentColor"/>
            </TextBlock>
            <Button x:Name="btnProfilePython" Content="Install Python Bundle" 
                    Background="$accentColor" Foreground="White" 
                    Padding="15,8" FontSize="14" FontWeight="SemiBold" 
                    BorderThickness="0" Cursor="Hand" 
                    HorizontalAlignment="Left" Margin="0,10,0,0"/>
        </StackPanel>
    </Border>
    
    <!-- Full Stack Profile -->
    <Border Background="$bgColor" Padding="20" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <TextBlock Text="💎 Complete Developer Kit" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <TextBlock Text="Everything you need for full-stack development" FontSize="12" Foreground="$textSecondary" Margin="0,0,0,10" TextWrapping="Wrap"/>
            <TextBlock Foreground="$textColor" FontSize="12" Margin="0,5">
                <Run Text="📦 Includes: "/>
                <Run Text="ALL TOOLS - Node.js, Python, XAMPP, VS Code, Git, Docker, Chrome, Postman, 7-Zip, and more!" Foreground="$accentColor"/>
            </TextBlock>
            <Button x:Name="btnProfileFull" Content="Install Everything" 
                    Background="$accentColor" Foreground="White" 
                    Padding="15,8" FontSize="14" FontWeight="SemiBold" 
                    BorderThickness="0" Cursor="Hand" 
                    HorizontalAlignment="Left" Margin="0,10,0,0"/>
        </StackPanel>
    </Border>
</StackPanel>
"@
    return $xaml
}

# Function to create VS Code Extensions page content
function Get-ExtensionsPageContent {
    $extensions = Get-VSCodeExtensions
    
    # Get current theme colors
    $bgColor = if ($script:currentTheme -eq "Dark") { "#2D2D30" } else { "#F3F3F3" }
    $textColor = if ($script:currentTheme -eq "Dark") { "White" } else { "Black" }
    $textSecondary = if ($script:currentTheme -eq "Dark") { "#B0B0B0" } else { "#666666" }
    $accentColor = "#007ACC"
    
    $xaml = @"
<StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" 
            TextElement.FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"
            Margin="20">
    <TextBlock Text="VS Code Extensions" FontSize="18" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
    <TextBlock Text="Popular extensions to enhance your VS Code experience (22 extensions)" FontSize="12" 
              Foreground="$textSecondary" Margin="0,0,0,20" TextWrapping="Wrap"/>
    
    <Border Background="$bgColor" Padding="15" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
"@
    
    foreach ($ext in $extensions) {
        $xaml += @"
            <CheckBox x:Name="chkExt_$($ext.Id.Replace('.', '_').Replace('-', '_'))" Foreground="$textColor" FontSize="13" Margin="0,5" IsChecked="True">
                <StackPanel>
                    <TextBlock Text="$($ext.Name)" FontWeight="Bold"/>
                    <TextBlock Text="$($ext.Description)" FontSize="11" Foreground="$textSecondary" TextWrapping="Wrap" Margin="0,2,0,0"/>
                </StackPanel>
            </CheckBox>
"@
    }
    
    $xaml += @"
        </StackPanel>
    </Border>
    
    <TextBlock Text="⚠️ Note: VS Code must be installed and in PATH for extensions to install properly" 
              FontSize="11" Foreground="$textSecondary" Margin="0,20,0,0" 
              HorizontalAlignment="Center" TextWrapping="Wrap"/>
</StackPanel>
"@
    return $xaml
}

function Get-HealthPageContent {
    $bgColor = if ($script:currentTheme -eq "Dark") { "#2D2D30" } else { "#F3F3F3" }
    $textColor = if ($script:currentTheme -eq "Dark") { "White" } else { "Black" }
    $textSecondary = if ($script:currentTheme -eq "Dark") { "#B0B0B0" } else { "#666666" }
    $accentColor = "#007ACC"
    $accentHoverColor = "#005A9E"
    
    $xaml = @"
<StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" 
            TextElement.FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"
            Margin="20">
    <StackPanel.Resources>
        <Style x:Key="PrimaryButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="$accentColor"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="Margin" Value="10"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$accentHoverColor"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </StackPanel.Resources>
    <TextBlock Text="System Health Dashboard" FontSize="18" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
    <TextBlock Text="Run diagnostics to verify installed tooling, detect missing dependencies, and export a shareable report."
              FontSize="12" Foreground="$textSecondary" Margin="0,0,0,15" TextWrapping="Wrap"/>
    
    <Border Background="$bgColor" Padding="20" Margin="0,0,0,15" CornerRadius="5">
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <StackPanel>
                <TextBlock Text="Overall Score" FontSize="14" FontWeight="Bold" Foreground="$textColor"/>
                <TextBlock x:Name="txtHealthScore" Text="--%" FontSize="32" FontWeight="ExtraBold" Foreground="#FF4EC9B0" Margin="0,10,0,0"/>
                <TextBlock x:Name="txtHealthSummary" Text="No scan run yet." FontSize="12" Foreground="$textSecondary" TextWrapping="Wrap"/>
            </StackPanel>
            <StackPanel Grid.Column="1">
                <TextBlock Text="Last Scan" FontSize="14" FontWeight="Bold" Foreground="$textColor"/>
                <TextBlock x:Name="txtHealthLastScan" Text="Not started" FontSize="16" FontWeight="SemiBold" Foreground="$textColor" Margin="0,10,0,0"/>
                <TextBlock x:Name="txtHealthIssues" Text="Issues detected: --" FontSize="12" Foreground="$textSecondary" Margin="0,5,0,0"/>
            </StackPanel>
        </Grid>
    </Border>
    
    <Border Background="$bgColor" Padding="20" Margin="0,0,0,15" CornerRadius="5">
        <StackPanel>
            <StackPanel Orientation="Horizontal">
                <Button x:Name="btnRunHealthCheck" Style="{StaticResource PrimaryButtonStyle}" Content="Run Health Scan"/>
                <Button x:Name="btnExportHealthReport" Style="{StaticResource PrimaryButtonStyle}" Content="Export Report"/>
            </StackPanel>
            <ListView x:Name="lvHealthResults" Margin="0,15,0,0">
                <ListView.View>
                    <GridView>
                        <GridViewColumn Header="Component" DisplayMemberBinding="{Binding Component}" Width="220"/>
                        <GridViewColumn Header="Status" DisplayMemberBinding="{Binding Status}" Width="110"/>
                        <GridViewColumn Header="Details" DisplayMemberBinding="{Binding Details}" Width="280"/>
                        <GridViewColumn Header="Recommendation" DisplayMemberBinding="{Binding Recommendation}" Width="280"/>
                    </GridView>
                </ListView.View>
            </ListView>
        </StackPanel>
    </Border>
</StackPanel>
"@
    return $xaml
}

function Get-UpdatePageContent {
    $bgColor = if ($script:currentTheme -eq "Dark") { "#2D2D30" } else { "#F3F3F3" }
    $textColor = if ($script:currentTheme -eq "Dark") { "White" } else { "Black" }
    $textSecondary = if ($script:currentTheme -eq "Dark") { "#B0B0B0" } else { "#666666" }
    $accentColor = "#007ACC"
    $accentHoverColor = "#005A9E"
    
    $xaml = @"
<StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" 
            TextElement.FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"
            Margin="20">
    <StackPanel.Resources>
        <Style x:Key="PrimaryButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="$accentColor"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="Margin" Value="10"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$accentHoverColor"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </StackPanel.Resources>
    <TextBlock Text="Update Center" FontSize="18" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
    <TextBlock Text="Check Chocolatey-managed packages for updates, select which items to upgrade, and export an audit trail."
              FontSize="12" Foreground="$textSecondary" Margin="0,0,0,15" TextWrapping="Wrap"/>
    
    <Border Background="$bgColor" Padding="20" CornerRadius="5" Margin="0,0,0,15">
        <StackPanel>
            <TextBlock x:Name="txtUpdatesSummary" Text="No checks performed." FontSize="13" Foreground="$textColor"/>
            <TextBlock x:Name="txtUpdatesLastRun" Text="Last run: --" FontSize="11" Foreground="$textSecondary" Margin="0,5,0,0"/>
        </StackPanel>
    </Border>
    
    <StackPanel Orientation="Horizontal">
        <Button x:Name="btnCheckUpdates" Style="{StaticResource PrimaryButtonStyle}" Content="Check for Updates"/>
        <Button x:Name="btnUpdateSelected" Style="{StaticResource PrimaryButtonStyle}" Content="Update Selected"/>
        <Button x:Name="btnExportUpdateReport" Style="{StaticResource PrimaryButtonStyle}" Content="Export Report"/>
    </StackPanel>
    
    <Border Background="$bgColor" Padding="15" CornerRadius="5" Margin="0,15,0,0">
        <ListView x:Name="lvUpdates" SelectionMode="Extended">
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="Tool" DisplayMemberBinding="{Binding Tool}" Width="220"/>
                    <GridViewColumn Header="Package" DisplayMemberBinding="{Binding Package}" Width="150"/>
                    <GridViewColumn Header="Installed" DisplayMemberBinding="{Binding CurrentVersion}" Width="120"/>
                    <GridViewColumn Header="Latest" DisplayMemberBinding="{Binding AvailableVersion}" Width="120"/>
                    <GridViewColumn Header="Source" DisplayMemberBinding="{Binding Source}" Width="100"/>
                </GridView>
            </ListView.View>
        </ListView>
    </Border>
    
    <TextBlock Text="Tip: Hold Ctrl or Shift to select multiple packages before clicking 'Update Selected'."
              FontSize="11" Foreground="$textSecondary" Margin="0,10,0,0"/>
</StackPanel>
"@
    return $xaml
}

function Get-SettingsPageContent {
    $bgColor = if ($script:currentTheme -eq "Dark") { "#2D2D30" } else { "#F3F3F3" }
    $textColor = if ($script:currentTheme -eq "Dark") { "White" } else { "Black" }
    $textSecondary = if ($script:currentTheme -eq "Dark") { "#B0B0B0" } else { "#666666" }
    $accentColor = "#007ACC"
    $accentHoverColor = "#005A9E"
    
    $xaml = @"
<StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" 
            TextElement.FontFamily="Segoe UI, Segoe UI Emoji, Segoe UI Symbol"
            Margin="20">
    <StackPanel.Resources>
        <Style x:Key="PrimaryButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="$accentColor"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="Margin" Value="10"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="$accentHoverColor"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </StackPanel.Resources>
    <TextBlock Text="Installer Settings" FontSize="18" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
    <TextBlock Text="Customize download locations, automation preferences, and the default theme. Settings are stored per device."
              FontSize="12" Foreground="$textSecondary" Margin="0,0,0,15" TextWrapping="Wrap"/>
    
    <Border Background="$bgColor" Padding="20" CornerRadius="5" Margin="0,0,0,15">
        <StackPanel>
            <TextBlock Text="Download Folder" FontSize="14" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,8"/>
            <DockPanel LastChildFill="False">
                <TextBox x:Name="txtDownloadPath" Width="520" Margin="0,0,10,0"/>
                <Button x:Name="btnBrowseDownloadPath" Style="{StaticResource PrimaryButtonStyle}" Content="Browse..." Width="140"/>
            </DockPanel>
            <TextBlock Text="All installers will be cached in this folder." FontSize="11" Foreground="$textSecondary" Margin="0,5,0,0"/>
        </StackPanel>
    </Border>
    
    <Border Background="$bgColor" Padding="20" CornerRadius="5" Margin="0,0,0,15">
        <StackPanel>
            <TextBlock Text="Automation" FontSize="14" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,8"/>
            <CheckBox x:Name="chkAutoHealth" Content="Run a silent health scan after each installation batch" 
                      Foreground="$textColor" FontSize="13" Margin="0,5"/>
            <CheckBox x:Name="chkAutoUpdates" Content="Automatically check for updates when opening the Update Center" 
                      Foreground="$textColor" FontSize="13" Margin="0,5"/>
        </StackPanel>
    </Border>
    
    <Border Background="$bgColor" Padding="20" CornerRadius="5" Margin="0,0,0,15">
        <StackPanel>
            <TextBlock Text="Theme Preference" FontSize="14" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,8"/>
            <ComboBox x:Name="cmbDefaultTheme" Width="220">
                <ComboBoxItem Content="Dark"/>
                <ComboBoxItem Content="Light"/>
            </ComboBox>
            <TextBlock Text="This theme loads on startup. You can still toggle it from the sidebar at any time." 
                      FontSize="11" Foreground="$textSecondary" Margin="0,8,0,0" TextWrapping="Wrap"/>
        </StackPanel>
    </Border>
    
    <StackPanel Orientation="Horizontal">
        <Button x:Name="btnSaveSettings" Style="{StaticResource PrimaryButtonStyle}" Content="Save Settings"/>
        <Button x:Name="btnResetSettings" Style="{StaticResource PrimaryButtonStyle}" Content="Reset to Defaults"/>
    </StackPanel>
    
    <TextBlock x:Name="txtSettingsStatus" Text="No pending changes." FontSize="11" Foreground="$textSecondary" Margin="0,10,0,0"/>
</StackPanel>
"@
    return $xaml
}

# Function to create action bar buttons
function Set-ActionBar {
    param([string]$PageName)
    
    $accentColor = "#007ACC"
    $controls.actionBarContent.Children.Clear()
    
    switch ($PageName) {
        "Tools" {
            $controls.actionBar.Visibility = "Visible"
            
            $btnInstall = New-Object System.Windows.Controls.Button
            $btnInstall.Background = $accentColor
            $btnInstall.Foreground = "White"
            $btnInstall.Padding = "20,10"
            $btnInstall.FontSize = 14
            $btnInstall.FontWeight = "SemiBold"
            $btnInstall.BorderThickness = 0
            $btnInstall.Cursor = "Hand"
            $btnInstall.Width = 220
            $btnInstall.Margin = "5"
            Set-EmojiContent -Control $btnInstall -Emoji "🚀" -Text "Install Selected Tools"
            $btnInstall.Add_Click({ Start-Installation })
            $controls.actionBarContent.Children.Add($btnInstall) | Out-Null
            
            $btnRefresh = New-Object System.Windows.Controls.Button
            $btnRefresh.Background = $accentColor
            $btnRefresh.Foreground = "White"
            $btnRefresh.Padding = "20,10"
            $btnRefresh.FontSize = 14
            $btnRefresh.FontWeight = "SemiBold"
            $btnRefresh.BorderThickness = 0
            $btnRefresh.Cursor = "Hand"
            $btnRefresh.Width = 200
            $btnRefresh.Margin = "5"
            Set-EmojiContent -Control $btnRefresh -Emoji "🔄" -Text "Refresh Versions"
            $btnRefresh.Add_Click({ Update-VersionInfo })
            $controls.actionBarContent.Children.Add($btnRefresh) | Out-Null
        }
        "Extensions" {
            $controls.actionBar.Visibility = "Visible"
            
            $btnInstallExt = New-Object System.Windows.Controls.Button
            $btnInstallExt.Background = $accentColor
            $btnInstallExt.Foreground = "White"
            $btnInstallExt.Padding = "20,10"
            $btnInstallExt.FontSize = 14
            $btnInstallExt.FontWeight = "SemiBold"
            $btnInstallExt.BorderThickness = 0
            $btnInstallExt.Cursor = "Hand"
            $btnInstallExt.Width = 250
            $btnInstallExt.Margin = "5"
            Set-EmojiContent -Control $btnInstallExt -Emoji "🧩" -Text "Install Selected Extensions"
            $btnInstallExt.Add_Click({ Install-SelectedExtensions })
            $controls.actionBarContent.Children.Add($btnInstallExt) | Out-Null
            
            $btnSelectAll = New-Object System.Windows.Controls.Button
            $btnSelectAll.Background = $accentColor
            $btnSelectAll.Foreground = "White"
            $btnSelectAll.Padding = "20,10"
            $btnSelectAll.FontSize = 14
            $btnSelectAll.FontWeight = "SemiBold"
            $btnSelectAll.BorderThickness = 0
            $btnSelectAll.Cursor = "Hand"
            $btnSelectAll.Width = 140
            $btnSelectAll.Margin = "5"
            Set-EmojiContent -Control $btnSelectAll -Emoji "✅" -Text "Select All"
            $btnSelectAll.Add_Click({
                $content = $controls.mainContent.Content
                foreach ($child in $content.Children) {
                    if ($child -is [System.Windows.Controls.Border]) {
                        foreach ($stackChild in $child.Child.Children) {
                            if ($stackChild -is [System.Windows.Controls.CheckBox]) {
                                $stackChild.IsChecked = $true
                            }
                        }
                    }
                }
            })
            $controls.actionBarContent.Children.Add($btnSelectAll) | Out-Null
            
            $btnDeselect = New-Object System.Windows.Controls.Button
            $btnDeselect.Background = $accentColor
            $btnDeselect.Foreground = "White"
            $btnDeselect.Padding = "20,10"
            $btnDeselect.FontSize = 14
            $btnDeselect.FontWeight = "SemiBold"
            $btnDeselect.BorderThickness = 0
            $btnDeselect.Cursor = "Hand"
            $btnDeselect.Width = 160
            $btnDeselect.Margin = "5"
            Set-EmojiContent -Control $btnDeselect -Emoji "⬜" -Text "Deselect All"
            $btnDeselect.Add_Click({
                $content = $controls.mainContent.Content
                foreach ($child in $content.Children) {
                    if ($child -is [System.Windows.Controls.Border]) {
                        foreach ($stackChild in $child.Child.Children) {
                            if ($stackChild -is [System.Windows.Controls.CheckBox]) {
                                $stackChild.IsChecked = $false
                            }
                        }
                    }
                }
            })
            $controls.actionBarContent.Children.Add($btnDeselect) | Out-Null
        }
        default {
            $controls.actionBar.Visibility = "Collapsed"
        }
    }
}

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

function Initialize-SettingsPage {
    param($content)
    
    Ensure-UserSettingsProperties
    
    $txtDownloadPath = $content.FindName("txtDownloadPath")
    if ($txtDownloadPath) { $txtDownloadPath.Text = $script:downloadPath }
    
    $chkAutoHealth = $content.FindName("chkAutoHealth")
    if ($chkAutoHealth) { $chkAutoHealth.IsChecked = [bool](Get-UserSettingValue -Name "AutoRunHealthAfterInstall" -Default $true) }
    
    $chkAutoUpdates = $content.FindName("chkAutoUpdates")
    if ($chkAutoUpdates) { $chkAutoUpdates.IsChecked = [bool](Get-UserSettingValue -Name "AutoCheckUpdates" -Default $false) }
    
    $cmbTheme = $content.FindName("cmbDefaultTheme")
    if ($cmbTheme) {
        $preferredTheme = Get-UserSettingValue -Name "PreferredTheme" -Default "Dark"
        $desired = if ($preferredTheme -eq "Light") { "Light" } else { "Dark" }
        foreach ($item in $cmbTheme.Items) {
            if ($item.Content -eq $desired) {
                $cmbTheme.SelectedItem = $item
                break
            }
        }
    }
    
    $statusText = $content.FindName("txtSettingsStatus")
    
    $btnBrowse = $content.FindName("btnBrowseDownloadPath")
    if ($btnBrowse -and $txtDownloadPath) {
        $btnBrowse.Add_Click({
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.SelectedPath = $txtDownloadPath.Text
            $dialog.ShowNewFolderButton = $true
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $txtDownloadPath.Text = $dialog.SelectedPath
                if ($statusText) { $statusText.Text = "Folder selection updated." }
            }
        }.GetNewClosure())
    }
    
    $btnSave = $content.FindName("btnSaveSettings")
    if ($btnSave) {
        $btnSave.Add_Click({
            if (-not $txtDownloadPath) {
                [System.Windows.MessageBox]::Show("Download path field is unavailable. Reload the Settings page and try again.", "Settings",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }
            $path = $txtDownloadPath.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($path)) {
                [System.Windows.MessageBox]::Show("Download path cannot be empty.", "Validation",
                    [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return
            }
            
            Ensure-UserSettingsProperties
            
            if (-not (Test-Path $path)) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
            }
            
            $script:downloadPath = $path
            Set-UserSettingValue -Name "DownloadPath" -Value $path
            if ($chkAutoHealth) { Set-UserSettingValue -Name "AutoRunHealthAfterInstall" -Value ([bool]$chkAutoHealth.IsChecked) }
            if ($chkAutoUpdates) { Set-UserSettingValue -Name "AutoCheckUpdates" -Value ([bool]$chkAutoUpdates.IsChecked) }
            
            $selectedTheme = "Dark"
            if ($cmbTheme -and $cmbTheme.SelectedItem) {
                $selectedTheme = $cmbTheme.SelectedItem.Content
            }
            $currentTheme = Get-UserSettingValue -Name "PreferredTheme" -Default "Dark"
            $themeChanged = $selectedTheme -ne $currentTheme
            Set-UserSettingValue -Name "PreferredTheme" -Value $selectedTheme
            
            Ensure-DownloadPath
            Save-UserSettings
            
            if ($themeChanged) {
                $script:isDarkTheme = $selectedTheme -ne "Light"
                Set-Theme -Dark $script:isDarkTheme
            }
            
            if ($statusText) {
                $statusText.Text = "Settings saved at $(Get-Date -Format 'HH:mm:ss')."
            }
        }.GetNewClosure())
    }
    
    $btnReset = $content.FindName("btnResetSettings")
    if ($btnReset) {
        $btnReset.Add_Click({
            $defaults = Get-DefaultUserSettings
            if ($txtDownloadPath) { $txtDownloadPath.Text = $defaults.DownloadPath }
            if ($chkAutoHealth) { $chkAutoHealth.IsChecked = $defaults.AutoRunHealthAfterInstall }
            if ($chkAutoUpdates) { $chkAutoUpdates.IsChecked = $defaults.AutoCheckUpdates }
            if ($cmbTheme) {
                foreach ($item in $cmbTheme.Items) {
                    if ($item.Content -eq $defaults.PreferredTheme) {
                        $cmbTheme.SelectedItem = $item
                        break
                    }
                }
            }
            if ($statusText) { $statusText.Text = "Defaults restored. Click Save to apply." }
        }.GetNewClosure())
    }
}
function Load-Page {
    param([string]$PageName)
    
    $script:currentPage = $PageName
    
    # Update sidebar active state
    $navButtons = @(
        $controls.btnNavTools,
        $controls.btnNavProfiles,
        $controls.btnNavExtensions,
        $controls.btnNavHealth,
        $controls.btnNavUpdate,
        $controls.btnNavSettings,
        $controls.btnNavAbout
    )
    
    foreach ($btn in $navButtons) {
        $btn.Background = "Transparent"
        $btn.BorderThickness = "0,0,0,0"
    }
    
    switch ($PageName) {
        "Tools" {
            $controls.btnNavTools.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavTools.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "Install Development Tools"
            $controls.txtPageSubtitle.Text = "Select tools to install automatically with latest versions"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-ToolsPageContent))
            $controls.mainContent.Content = $content
            
            # Set up action bar
            Set-ActionBar "Tools"
            
            # Load versions
            Update-VersionInfo
        }
        "Profiles" {
            $controls.btnNavProfiles.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavProfiles.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "Installation Profiles"
            $controls.txtPageSubtitle.Text = "Pre-configured bundles for quick setup"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-ProfilesPageContent))
            $controls.mainContent.Content = $content
            
            # Hide action bar for profiles (buttons are in content)
            $controls.actionBar.Visibility = "Collapsed"
            
            # Wire up profile buttons
            $content.FindName("btnProfileWeb").Add_Click({ Install-Profile "Web" })
            $content.FindName("btnProfilePHP").Add_Click({ Install-Profile "PHP" })
            $content.FindName("btnProfilePython").Add_Click({ Install-Profile "Python" })
            $content.FindName("btnProfileFull").Add_Click({ Install-Profile "Full" })
        }
        "Extensions" {
            $controls.btnNavExtensions.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavExtensions.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "VS Code Extensions"
            $controls.txtPageSubtitle.Text = "Enhance your coding experience with popular extensions"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-ExtensionsPageContent))
            $controls.mainContent.Content = $content
            
            # Set up action bar
            Set-ActionBar "Extensions"
        }
        "Health" {
            $controls.btnNavHealth.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavHealth.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "System Health Check"
            $controls.txtPageSubtitle.Text = "Verify installed tools and detect issues"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-HealthPageContent))
            $controls.mainContent.Content = $content
            $controls.actionBar.Visibility = "Collapsed"
            
            $runButton = $content.FindName("btnRunHealthCheck")
            if ($runButton) { $runButton.Add_Click({ Invoke-HealthCheck }) }
            
            $exportButton = $content.FindName("btnExportHealthReport")
            if ($exportButton) { $exportButton.Add_Click({ Export-HealthReport }) }
            
            if ($script:lastHealthResults -and $script:lastHealthResults.Count -gt 0) {
                Render-HealthResults -Results $script:lastHealthResults
            } else {
                Invoke-HealthCheck
            }
        }
        "Update" {
            $controls.btnNavUpdate.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavUpdate.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "Update Manager"
            $controls.txtPageSubtitle.Text = "Check for and install updates for installed tools"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-UpdatePageContent))
            $controls.mainContent.Content = $content
            $controls.actionBar.Visibility = "Collapsed"
            
            $btnCheck = $content.FindName("btnCheckUpdates")
            if ($btnCheck) { $btnCheck.Add_Click({ Invoke-UpdateCheck }) }
            
            $btnUpdate = $content.FindName("btnUpdateSelected")
            if ($btnUpdate) { $btnUpdate.Add_Click({ Install-SelectedUpdates }) }
            
            $btnExport = $content.FindName("btnExportUpdateReport")
            if ($btnExport) { $btnExport.Add_Click({ Export-UpdateReport }) }
            
            if ($script:lastUpdateResults -and $script:lastUpdateResults.Count -gt 0) {
                Render-UpdateResults -Results $script:lastUpdateResults
            } elseif ($script:userSettings.AutoCheckUpdates) {
                Invoke-UpdateCheck
            }
        }
        "Settings" {
            $controls.btnNavSettings.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavSettings.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "Settings"
            $controls.txtPageSubtitle.Text = "Configure installer preferences"
            
            $content = [Windows.Markup.XamlReader]::Parse((Get-SettingsPageContent))
            $controls.mainContent.Content = $content
            $controls.actionBar.Visibility = "Collapsed"
            Initialize-SettingsPage -content $content
        }
        "About" {
            $controls.btnNavAbout.Background = $window.Resources["SidebarActiveColor"]
            $controls.btnNavAbout.BorderThickness = "3,0,0,0"
            $controls.txtPageTitle.Text = "About"
            $controls.txtPageSubtitle.Text = "Development Tools Installer V2.0"
            
            $content = New-Object System.Windows.Controls.StackPanel
            $content.Margin = "20"
            
            $about = @"
Created by: SPARO c 2025
Version: 2.0.0
License: MIT License

Features:
? 34 Development Tools (8 categories)
? Health Dashboard & Exportable Reports  
? Chocolatey Update Center
? Installation Profiles
? 22 VS Code Extensions
? Dark/Light Theme Toggle & Saved Settings
? Sidebar Navigation
? Chocolatey Integration & Silent Installs

Tools Included:
- Chocolatey, Node.js, Python, VS Code, Git, Docker
- Chrome, Postman, 7-Zip, Angular CLI, React, XAMPP, Composer, Laravel
- Azure CLI, AWS CLI, Terraform, kubectl, GitHub CLI
- MySQL Workbench, MongoDB Compass, DBeaver, pgAdmin 4, Redis
- IntelliJ IDEA, PyCharm, Android Studio, Sublime Text, Notepad++
- GitHub Desktop, Slack, Insomnia, Windows Terminal, PowerToys

For support and updates, visit:
https://github.com/sparo

MIT License - Free to use and modify
"@

            $txt = New-Object System.Windows.Controls.TextBlock
            $txt.Text = $about
            $txt.FontSize = 13
            $txt.FontFamily = "Segoe UI, Segoe UI Emoji, Segoe UI Symbol"
            $txt.Foreground = $window.Resources["TextColor"]
            $txt.TextWrapping = "Wrap"
            
            $content.Children.Add($txt)
            $controls.mainContent.Content = $content
        }
    }
}

function Update-VersionInfo {
    $controls.txtStatus.Text = "Fetching latest versions..."
    
    $script:versionInfo = @{
        NodeJS = Get-LatestNodeVersion
        Python = Get-LatestPythonVersion
        VSCode = Get-LatestVSCodeVersion
        XAMPP = Get-LatestXAMPPVersion
        Composer = Get-LatestComposerVersion
    }
    
    $content = $controls.mainContent.Content
    if ($content) {
        $txtNode = $content.FindName("txtNodeVersion")
        $txtPython = $content.FindName("txtPythonVersion")
        $txtVSCode = $content.FindName("txtVSCodeVersion")
        $txtXAMPP = $content.FindName("txtXAMPPVersion")
        
        if ($txtNode -and $script:versionInfo.NodeJS) { $txtNode.Text = "Node.js - v$($script:versionInfo.NodeJS.Version)" }
        if ($txtPython -and $script:versionInfo.Python) { $txtPython.Text = "Python - v$($script:versionInfo.Python.Version)" }
        if ($txtVSCode -and $script:versionInfo.VSCode) { $txtVSCode.Text = "VS Code - v$($script:versionInfo.VSCode.Version)" }
        if ($txtXAMPP -and $script:versionInfo.XAMPP) { $txtXAMPP.Text = "XAMPP - v$($script:versionInfo.XAMPP.Version)" }
    }
    
    $controls.txtStatus.Text = "Ready - Latest versions loaded"
}

function Get-AllToolNames {
    return @(
        "Chocolatey","NodeJS","Python","VSCode","Git","Angular","React","Docker","Postman",
        "XAMPP","Composer","Laravel","Chrome","7Zip",
        "AzureCLI","AWSCLI","Terraform","Kubectl","GitHubCLI",
        "MySQLWorkbench","MongoDBCompass","DBeaver","PgAdmin","Redis",
        "IntelliJ","PyCharm","AndroidStudio","Sublime","NotepadPP",
        "GitHubDesktop","Slack","Insomnia","WindowsTerminal","PowerToys"
    )
}

function Install-SingleTool {
    param([string]$ToolName)
    
    switch ($ToolName) {
        "Chocolatey" { return Install-Chocolatey }
        "NodeJS" { return Install-NodeJS -VersionInfo $script:versionInfo.NodeJS -DownloadPath $script:downloadPath }
        "Python" { return Install-Python -VersionInfo $script:versionInfo.Python -DownloadPath $script:downloadPath }
        "VSCode" { return Install-VSCode -VersionInfo $script:versionInfo.VSCode -DownloadPath $script:downloadPath }
        "Git" { return Install-ChocoPackage -PackageName "git" }
        "Angular" { return Install-AngularCLI }
        "React" {
            try {
                $process = Start-Process "npm" -ArgumentList "install -g create-react-app" -Wait -NoNewWindow -PassThru
                return ($process.ExitCode -eq 0)
            } catch {
                Write-Warning "Failed to install React tooling: $_"
                return $false
            }
        }
        "Docker" { return Install-ChocoPackage -PackageName "docker-desktop" }
        "Postman" { return Install-ChocoPackage -PackageName "postman" }
        "XAMPP" { return Install-XAMPP -VersionInfo $script:versionInfo.XAMPP -DownloadPath $script:downloadPath }
        "Composer" { return Install-Composer -VersionInfo $script:versionInfo.Composer -DownloadPath $script:downloadPath }
        "Laravel" { return Install-LaravelInstaller }
        "Chrome" { return Install-ChocoPackage -PackageName "googlechrome" }
        "7Zip" { return Install-ChocoPackage -PackageName "7zip" }
        "AzureCLI" { return Install-ChocoPackage -PackageName "azure-cli" }
        "AWSCLI" { return Install-ChocoPackage -PackageName "awscli" }
        "Terraform" { return Install-ChocoPackage -PackageName "terraform" }
        "Kubectl" { return Install-ChocoPackage -PackageName "kubernetes-cli" }
        "GitHubCLI" { return Install-ChocoPackage -PackageName "github-cli" }
        "MySQLWorkbench" { return Install-ChocoPackage -PackageName "mysql.workbench" }
        "MongoDBCompass" { return Install-ChocoPackage -PackageName "mongodb-compass" }
        "DBeaver" { return Install-ChocoPackage -PackageName "dbeaver" }
        "PgAdmin" { return Install-ChocoPackage -PackageName "pgadmin4" }
        "Redis" { return Install-ChocoPackage -PackageName "redis-64" }
        "IntelliJ" { return Install-ChocoPackage -PackageName "intellijidea-community" }
        "PyCharm" { return Install-ChocoPackage -PackageName "pycharm-community" }
        "AndroidStudio" { return Install-ChocoPackage -PackageName "androidstudio" }
        "Sublime" { return Install-ChocoPackage -PackageName "sublimetext3" }
        "NotepadPP" { return Install-ChocoPackage -PackageName "notepadplusplus" }
        "GitHubDesktop" { return Install-ChocoPackage -PackageName "github-desktop" }
        "Slack" { return Install-ChocoPackage -PackageName "slack" }
        "Insomnia" { return Install-ChocoPackage -PackageName "insomnia-rest-api-client" }
        "WindowsTerminal" { return Install-ChocoPackage -PackageName "microsoft-windows-terminal" }
        "PowerToys" { return Install-ChocoPackage -PackageName "powertoys" }
        default {
            Write-Warning "No installer registered for $ToolName"
            return $false
        }
    }
}

function Start-Installation {
    $content = $controls.mainContent.Content
    Ensure-DownloadPath
    if (-not $script:versionInfo.NodeJS) { Update-VersionInfo }
    
    $controls.txtStatus.Text = "Starting installation..."
    $controls.progressBar.Value = 0
    
    $toolsToInstall = @()
    
    if ($content.FindName("chkChocolatey").IsChecked) { $toolsToInstall += "Chocolatey" }
    if ($content.FindName("chkNodeJS").IsChecked) { $toolsToInstall += "NodeJS" }
    if ($content.FindName("chkPython").IsChecked) { $toolsToInstall += "Python" }
    if ($content.FindName("chkVSCode").IsChecked) { $toolsToInstall += "VSCode" }
    if ($content.FindName("chkGit").IsChecked) { $toolsToInstall += "Git" }
    if ($content.FindName("chkAngular").IsChecked) { $toolsToInstall += "Angular" }
    if ($content.FindName("chkReact").IsChecked) { $toolsToInstall += "React" }
    if ($content.FindName("chkDocker").IsChecked) { $toolsToInstall += "Docker" }
    if ($content.FindName("chkPostman").IsChecked) { $toolsToInstall += "Postman" }
    if ($content.FindName("chkXAMPP").IsChecked) { $toolsToInstall += "XAMPP" }
    if ($content.FindName("chkComposer").IsChecked) { $toolsToInstall += "Composer" }
    if ($content.FindName("chkLaravel").IsChecked) { $toolsToInstall += "Laravel" }
    if ($content.FindName("chkChrome").IsChecked) { $toolsToInstall += "Chrome" }
    if ($content.FindName("chk7Zip").IsChecked) { $toolsToInstall += "7Zip" }
    if ($content.FindName("chkAzureCLI").IsChecked) { $toolsToInstall += "AzureCLI" }
    if ($content.FindName("chkAWSCLI").IsChecked) { $toolsToInstall += "AWSCLI" }
    if ($content.FindName("chkTerraform").IsChecked) { $toolsToInstall += "Terraform" }
    if ($content.FindName("chkKubectl").IsChecked) { $toolsToInstall += "Kubectl" }
    if ($content.FindName("chkGitHubCLI").IsChecked) { $toolsToInstall += "GitHubCLI" }
    if ($content.FindName("chkMySQLWorkbench").IsChecked) { $toolsToInstall += "MySQLWorkbench" }
    if ($content.FindName("chkMongoDBCompass").IsChecked) { $toolsToInstall += "MongoDBCompass" }
    if ($content.FindName("chkDBeaver").IsChecked) { $toolsToInstall += "DBeaver" }
    if ($content.FindName("chkPgAdmin").IsChecked) { $toolsToInstall += "PgAdmin" }
    if ($content.FindName("chkRedis").IsChecked) { $toolsToInstall += "Redis" }
    if ($content.FindName("chkIntelliJ").IsChecked) { $toolsToInstall += "IntelliJ" }
    if ($content.FindName("chkPyCharm").IsChecked) { $toolsToInstall += "PyCharm" }
    if ($content.FindName("chkAndroidStudio").IsChecked) { $toolsToInstall += "AndroidStudio" }
    if ($content.FindName("chkSublime").IsChecked) { $toolsToInstall += "Sublime" }
    if ($content.FindName("chkNotepadPP").IsChecked) { $toolsToInstall += "NotepadPP" }
    if ($content.FindName("chkGitHubDesktop").IsChecked) { $toolsToInstall += "GitHubDesktop" }
    if ($content.FindName("chkSlack").IsChecked) { $toolsToInstall += "Slack" }
    if ($content.FindName("chkInsomnia").IsChecked) { $toolsToInstall += "Insomnia" }
    if ($content.FindName("chkWindowsTerminal").IsChecked) { $toolsToInstall += "WindowsTerminal" }
    if ($content.FindName("chkPowerToys").IsChecked) { $toolsToInstall += "PowerToys" }
    
    if ($toolsToInstall.Count -eq 0) {
        [System.Windows.MessageBox]::Show("Please select at least one tool to install.", "No Selection", 
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    
    $totalSteps = $toolsToInstall.Count
    $currentStep = 0
    $failedTools = @()
    
    foreach ($tool in $toolsToInstall) {
        $currentStep++
        $controls.txtStatus.Text = "Installing $tool ($currentStep/$totalSteps)..."
        $controls.progressBar.Value = ($currentStep / $totalSteps) * 100
        
        if (-not (Install-SingleTool -ToolName $tool)) {
            $failedTools += $tool
        }
    }
    
    if ($content.FindName("chkVSCodeContext").IsChecked -and $toolsToInstall -contains "VSCode") {
        Add-VSCodeContextMenu | Out-Null
    }
    if ($content.FindName("chkAddPaths").IsChecked -and $toolsToInstall -contains "XAMPP") {
        Add-MySQLToPath | Out-Null
        Add-PHPToPath | Out-Null
    }
    if ($content.FindName("chkXAMPPShortcut").IsChecked -and $toolsToInstall -contains "XAMPP") {
        Set-XAMPPServices | Out-Null
    }
    
    $controls.progressBar.Value = 100
    if ($failedTools.Count -gt 0) {
        $controls.txtStatus.Text = "Completed with warnings."
        [System.Windows.MessageBox]::Show(
            "Completed with warnings. Review logs for: $($failedTools -join ', ').",
            "Installation Complete (Warnings)",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning) | Out-Null
    } else {
        $controls.txtStatus.Text = "Installation complete!"
        [System.Windows.MessageBox]::Show("All selected tools have been installed successfully!", "Installation Complete",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    }
    
    if ($script:userSettings.AutoRunHealthAfterInstall) {
        Invoke-HealthCheck -Silent | Out-Null
    }
}

function Install-Profile {
    param([string]$ProfileName)
    
    $result = [System.Windows.MessageBox]::Show(
        "This will install all tools in the $ProfileName profile.`n`nThis may take several minutes. Continue?",
        "Install Profile",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    
    if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }
    
    $profiles = @{
        Web = @("NodeJS", "VSCode", "Git", "Chrome", "Postman", "Angular", "React", "GitHubCLI")
        PHP = @("Chocolatey","XAMPP", "Composer", "Laravel", "VSCode", "Git", "Postman", "GitHubDesktop")
        Python = @("Python", "VSCode", "Git", "Docker", "Chrome", "AWSCLI", "AzureCLI")
        Full = Get-AllToolNames
    }
    
    if (-not $profiles.ContainsKey($ProfileName)) {
        [System.Windows.MessageBox]::Show("Unknown profile '$ProfileName'.", "Error",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        return
    }
    
    $tools = $profiles[$ProfileName]
    Ensure-DownloadPath
    if (-not $script:versionInfo.NodeJS) { Update-VersionInfo }
    $controls.txtStatus.Text = "Installing $ProfileName profile..."
    $controls.progressBar.Value = 0
    
    $failed = @()
    $index = 0
    foreach ($tool in $tools) {
        $index++
        $controls.txtStatus.Text = "Installing $tool ($index/$($tools.Count))..."
        $controls.progressBar.Value = ($index / $tools.Count) * 100
        if (-not (Install-SingleTool -ToolName $tool)) {
            $failed += $tool
        }
    }
    
    $controls.progressBar.Value = 100
    if ($failed.Count -gt 0) {
        $controls.txtStatus.Text = "$ProfileName profile completed with warnings."
        [System.Windows.MessageBox]::Show(
            "$ProfileName profile completed with warnings. Check logs for: $($failed -join ', ').",
            "Profile Complete (Warnings)",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning) | Out-Null
    } else {
        $controls.txtStatus.Text = "Profile installation complete!"
        [System.Windows.MessageBox]::Show("$ProfileName profile installed successfully!", "Success",
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
    }
}

function Install-SelectedExtensions {
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
    
    $controls.txtStatus.Text = "Installing VS Code extensions..."
    $controls.progressBar.Value = 0
    
    $result = Install-AllVSCodeExtensions -ExtensionIds $selectedExtensions
    
    $controls.progressBar.Value = 100
    $controls.txtStatus.Text = "Extension installation complete!"
    
    [System.Windows.MessageBox]::Show(
        "Installed: $($result.Successful)`nFailed: $($result.Failed)", 
        "Extensions Installed",
        [System.Windows.MessageBoxButton]::OK, 
        [System.Windows.MessageBoxImage]::Information) | Out-Null
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$controls.btnNavTools.Add_Click({ Load-Page "Tools" })
$controls.btnNavProfiles.Add_Click({ Load-Page "Profiles" })
$controls.btnNavExtensions.Add_Click({ Load-Page "Extensions" })
$controls.btnNavHealth.Add_Click({ Load-Page "Health" })
$controls.btnNavUpdate.Add_Click({ Load-Page "Update" })
$controls.btnNavSettings.Add_Click({ Load-Page "Settings" })
$controls.btnNavAbout.Add_Click({ Load-Page "About" })

$controls.btnThemeToggle.Add_Checked({
    if (-not $script:isDarkTheme) {
        $script:isDarkTheme = $true
        $script:userSettings.PreferredTheme = "Dark"
        Save-UserSettings
        Set-Theme -Dark $true
    }
})
$controls.btnThemeToggle.Add_Unchecked({
    if ($script:isDarkTheme) {
        $script:isDarkTheme = $false
        $script:userSettings.PreferredTheme = "Light"
        Save-UserSettings
        Set-Theme -Dark $false
    }
})

if ($controls.btnSidebarToggle) {
    $controls.btnSidebarToggle.Add_Click({ Toggle-Sidebar })
}

Set-Theme -Dark $script:isDarkTheme
Load-Page "Tools"

Write-Host "========================================" -ForegroundColor Green
Write-Host "Development Tools Installer V2.0" -ForegroundColor Cyan
Write-Host "Created by SPARO c 2025" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Sidebar Navigation + Profiles" -ForegroundColor Green
Write-Host "✅ Health Dashboard & Reports" -ForegroundColor Green
Write-Host "✅ Update Center (Chocolatey)" -ForegroundColor Green
Write-Host "✅ Saved Settings + Theme" -ForegroundColor Green
Write-Host "✅ 34 Development Tools + 22 VS Code Extensions" -ForegroundColor Green
Write-Host ""
Write-Host "Opening GUI..." -ForegroundColor Cyan

$window.ShowDialog() | Out-Null




