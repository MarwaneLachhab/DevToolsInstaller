# Installer entrypoint that pulls in split installer pieces
$installersPath = Split-Path -Path $MyInvocation.MyCommand.Path

. (Join-Path $installersPath "Installers.Tools.ps1")
. (Join-Path $installersPath "Installers.Profiles.ps1")
. (Join-Path $installersPath "Installers.Uninstall.ps1")
. (Join-Path $installersPath "Installers.Extensions.ps1")
