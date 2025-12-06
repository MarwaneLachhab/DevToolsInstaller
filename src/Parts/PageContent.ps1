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
            <TextBlock Text="&#x1F310; Web Developer Starter" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <TextBlock Text="Essential tools for modern web development" FontSize="12" Foreground="$textSecondary" Margin="0,0,0,10" TextWrapping="Wrap"/>
            <TextBlock Foreground="$textColor" FontSize="12" Margin="0,5">
                <Run Text="&#x1F4E6; Includes: "/>
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
            <TextBlock Text="&#x1F418; PHP Full Stack" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <TextBlock Text="Complete PHP development environment with database" FontSize="12" Foreground="$textSecondary" Margin="0,0,0,10" TextWrapping="Wrap"/>
            <TextBlock Foreground="$textColor" FontSize="12" Margin="0,5">
                <Run Text="&#x1F4E6; Includes: "/>
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
            <TextBlock Text="&#x1F40D; Python Data Science" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <TextBlock Text="Python environment with essential data science tools" FontSize="12" Foreground="$textSecondary" Margin="0,0,0,10" TextWrapping="Wrap"/>
            <TextBlock Foreground="$textColor" FontSize="12" Margin="0,5">
                <Run Text="&#x1F4E6; Includes: "/>
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
            <TextBlock Text="&#x1F48E; Complete Developer Kit" FontSize="16" FontWeight="Bold" Foreground="$textColor" Margin="0,0,0,10"/>
            <TextBlock Text="Everything you need for full-stack development" FontSize="12" Foreground="$textSecondary" Margin="0,0,0,10" TextWrapping="Wrap"/>
            <TextBlock Foreground="$textColor" FontSize="12" Margin="0,5">
                <Run Text="&#x1F4E6; Includes: "/>
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
    
    <TextBlock Text="&#x26A0; Note: VS Code must be installed and in PATH for extensions to install properly" 
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





