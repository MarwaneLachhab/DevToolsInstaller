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
                        <Run FontFamily="Segoe UI Emoji" Text="&#x1F680; "/>
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
                            <TextBlock Text="&#x1F4E6;" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavTools" Text="Install Tools" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavProfiles" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="&#x2B50;" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavProfiles" Text="Profiles" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavExtensions" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="&#x1F9E9;" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavExtensions" Text="VS Code Ext" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavHealth" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="&#x1F3E5;" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavHealth" Text="Health Check" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavUpdate" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="&#x1F501;" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavUpdate" Text="Updates" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavSettings" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="&#x2699;" FontFamily="Segoe UI Emoji" Margin="0"/>
                            <TextBlock x:Name="lblNavSettings" Text="Settings" Margin="8,0,0,0"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="btnNavAbout" Style="{StaticResource SidebarButtonStyle}">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center"
                                    TextElement.Foreground="{DynamicResource TextColor}">
                            <TextBlock Text="&#x2139;" FontFamily="Segoe UI Emoji" Margin="0"/>
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
                                <TextBlock x:Name="runThemeStatusIcon" FontFamily="Segoe UI Emoji" Text="&#x1F319;" Margin="0,0,6,0"/>
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
                    <Button x:Name="btnSidebarToggle" Grid.Column="0" Style="{StaticResource IconButtonStyle}" Content="&#x2190;" Margin="0,0,16,0"/>
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
                <WrapPanel x:Name="actionBarContent" Orientation="Horizontal" HorizontalAlignment="Center">
                    <!-- Buttons loaded dynamically per page -->
                </WrapPanel>
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

