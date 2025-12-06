# Navigation entrypoint that loads split navigation pieces
$navPath = Split-Path -Path $MyInvocation.MyCommand.Path

. (Join-Path $navPath "Navigation.Actions.ps1")
. (Join-Path $navPath "Navigation.Routing.ps1")
