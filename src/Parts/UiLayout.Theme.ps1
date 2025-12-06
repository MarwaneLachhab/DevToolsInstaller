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
        $controls.runThemeStatusIcon.Text = if ($Dark) { "*" } else { "+" }
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
        $controls.btnSidebarToggle.Content = if ($Collapsed) { ">" } else { "<" }
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
