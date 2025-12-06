# UI layout entrypoint that loads split layout pieces
$layoutPath = Split-Path -Path $MyInvocation.MyCommand.Path

. (Join-Path $layoutPath "UiLayout.Layout.ps1")
. (Join-Path $layoutPath "UiLayout.Theme.ps1")
