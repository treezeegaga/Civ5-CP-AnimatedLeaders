# Switches which CvGameCore_Expansion2.dll Community Patch loads. Close Civ V first.
#   powershell -ExecutionPolicy Bypass -File CPLeaderheads\swapdll.ps1 msvc       (patched, MSVC build)
#   powershell -ExecutionPolicy Bypass -File CPLeaderheads\swapdll.ps1 clang      (patched, clang build)
#   powershell -ExecutionPolicy Bypass -File CPLeaderheads\swapdll.ps1 original   (stock CP 5.4.8)
param([Parameter(Mandatory = $true)][ValidateSet("msvc", "clang", "original")][string]$Build)

$target = "C:\Users\itstr\Documents\My Games\Sid Meier's Civilization 5\MODS\(1) Community Patch\CvGameCore_Expansion2.dll"
$source = @{
    msvc     = Join-Path $PSScriptRoot "build\CvGameCore_Expansion2.msvc.dll"
    clang    = Join-Path $PSScriptRoot "build\CvGameCore_Expansion2.clang.dll"
    original = Join-Path $PSScriptRoot "backup\CvGameCore_Expansion2.dll"
}[$Build]

if (Get-Process -Name CivilizationV_DX11, CivilizationV, CivilizationV_Tablet -ErrorAction SilentlyContinue) {
    Write-Error "Civ V is running. Close it first."
    exit 1
}
Copy-Item $source $target -Force
Write-Output "Community Patch now uses the $Build DLL."
