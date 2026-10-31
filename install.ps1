# Switches which pseudo-DLC is installed. Only one is installed at a time, because the
# 2D backdrop would hide a working 3D leader scene during probe runs.
#   powershell -ExecutionPolicy Bypass -File install.ps1 install    (2D leader screens)
#   powershell -ExecutionPolicy Bypass -File install.ps1 probe      (3D investigation probe)
#   powershell -ExecutionPolicy Bypass -File install.ps1 uninstall
param([ValidateSet("install", "probe", "uninstall")][string]$Action = "install")

$dlcRoot = "C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V\Assets\DLC"

foreach ($name in "MPLeaderProbe", "MPLeaderScreens") {
    $old = Join-Path $dlcRoot $name
    if (Test-Path $old) { Remove-Item -Recurse -Force $old; Write-Output "Removed $old" }
}

$package = @{ install = "MPLeaderScreens"; probe = "MPLeaderProbe" }[$Action]
if ($package) {
    Copy-Item -Recurse (Join-Path $PSScriptRoot $package) (Join-Path $dlcRoot $package)
    Write-Output "Installed $package"
}
