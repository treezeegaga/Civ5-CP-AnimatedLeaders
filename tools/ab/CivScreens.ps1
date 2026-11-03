# Recognises Civ V's setup screens by colour, for Run-Games.ps1.
#   . .\CivScreens.ps1; Get-CivScreen          -> name of the closest saved screen and its distance
#   . .\CivScreens.ps1; Save-CivScreen legal   -> save the current screen under that name (calibration)
# A screen is an 8x8 grid of average colours over Civ's window where it opens (963,63 to 2877,2097 on a
# 3840x2160 screen). Saved screens go to CivScreens.json next to this script.

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class AbDpi { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[AbDpi]::SetProcessDPIAware() | Out-Null

$script:CivScreensFile = Join-Path $PSScriptRoot "CivScreens.json"
$script:CivArea = @{ X = 963; Y = 106; W = 1914; H = 1990 }   # below the title bar
$script:MenuPanel = @(1740, 845, 2110, 1372)

function Get-CivScreenSignature {
    $a = $script:CivArea
    $bmp = New-Object System.Drawing.Bitmap $a.W, $a.H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($a.X, $a.Y, 0, 0, $bmp.Size)
    $g.Dispose()
    $sig = New-Object 'System.Collections.Generic.List[int]'
    $cw = [int]($a.W / 8); $ch = [int]($a.H / 8)
    for ($gy = 0; $gy -lt 8; $gy++) { for ($gx = 0; $gx -lt 8; $gx++) {
        $r = 0; $gg = 0; $b = 0; $n = 0
        for ($y = $gy * $ch + 4; $y -lt ($gy + 1) * $ch - 4; $y += 12) { for ($x = $gx * $cw + 4; $x -lt ($gx + 1) * $cw - 4; $x += 12) {
            $c = $bmp.GetPixel($x, $y); $r += $c.R; $gg += $c.G; $b += $c.B; $n++
        } }
        $sig.Add([int]($r / $n)); $sig.Add([int]($gg / $n)); $sig.Add([int]($b / $n))
    } }
    # The main menu and the Single Player menu differ only in their button text, so add single pixels on a
    # fine grid over the menu panel (screen 1740,845 to 2110,1372 on the first PC)
    $m = $script:MenuPanel
    for ($y = $m[1] - $a.Y; $y -lt $m[3] - $a.Y; $y += 11) { for ($x = $m[0] - $a.X; $x -lt $m[2] - $a.X; $x += 9) {
        $c = $bmp.GetPixel($x, $y); $sig.Add([int](($c.R + $c.G + $c.B) / 3))
    } }
    $bmp.Dispose()
    return ,$sig.ToArray()
}

function Get-SavedCivScreens {
    if (Test-Path $script:CivScreensFile) { return (Get-Content $script:CivScreensFile -Raw | ConvertFrom-Json) }
    return New-Object PSObject
}

function Save-CivScreen([string]$name) {
    $all = Get-SavedCivScreens
    $sig = Get-CivScreenSignature
    $all | Add-Member -NotePropertyName $name -NotePropertyValue $sig -Force
    $all | ConvertTo-Json -Depth 3 -Compress | Set-Content $script:CivScreensFile
    "saved $name"
}

# Brightness of single pixels on a grid over one screen rectangle, for things drawn the same over a changing
# background (the "Begin Your Journey" button over the map)
function Get-CivRegionSignature([int]$x1, [int]$y1, [int]$x2, [int]$y2) {
    $bmp = New-Object System.Drawing.Bitmap ($x2 - $x1), ($y2 - $y1)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($x1, $y1, 0, 0, $bmp.Size)
    $g.Dispose()
    $sig = New-Object 'System.Collections.Generic.List[int]'
    for ($y = 0; $y -lt $bmp.Height; $y += 3) { for ($x = 0; $x -lt $bmp.Width; $x += 4) {
        $c = $bmp.GetPixel($x, $y); $sig.Add([int](($c.R + $c.G + $c.B) / 3))
    } }
    $bmp.Dispose()
    return ,$sig.ToArray()
}

$script:BeginButton = @(1795, 1441, 2015, 1461)

# Another PC (lead, 2026-11-03): tools\ab\machines\<COMPUTERNAME>.json holds that screen's areas (CivArea as
# {X, Y, W, H}; MenuPanel and BeginButton as [x1, y1, x2, y2]), and its saved screens go to
# machines\<COMPUTERNAME>.screens.json. Without the file, everything is as on the first PC.
$script:MachineFile = Join-Path $PSScriptRoot "machines\$env:COMPUTERNAME.json"
if (Test-Path $script:MachineFile) {
    $script:CivScreensFile = Join-Path $PSScriptRoot "machines\$env:COMPUTERNAME.screens.json"
    $mm = Get-Content $script:MachineFile -Raw | ConvertFrom-Json
    if ($mm.CivArea) { $script:CivArea = @{ X = [int]$mm.CivArea.X; Y = [int]$mm.CivArea.Y; W = [int]$mm.CivArea.W; H = [int]$mm.CivArea.H } }
    if ($mm.MenuPanel) { $script:MenuPanel = @($mm.MenuPanel | ForEach-Object { [int]$_ }) }
    if ($mm.BeginButton) { $script:BeginButton = @($mm.BeginButton | ForEach-Object { [int]$_ }) }
}

function Save-CivBeginButton {
    $all = Get-SavedCivScreens
    $b = $script:BeginButton
    $all | Add-Member -NotePropertyName "_begin" -NotePropertyValue (Get-CivRegionSignature $b[0] $b[1] $b[2] $b[3]) -Force
    $all | ConvertTo-Json -Depth 3 -Compress | Set-Content $script:CivScreensFile
    "saved begin button"
}

# Mean brightness difference between the button area now and when "Begin Your Journey" was showing
function Get-CivBeginButtonDistance {
    $ref = @((Get-SavedCivScreens)._begin)
    if ($ref.Count -eq 0) { return 999 }
    $b = $script:BeginButton
    $sig = Get-CivRegionSignature $b[0] $b[1] $b[2] $b[3]
    $d = 0; for ($i = 0; $i -lt $sig.Count; $i++) { $d += [Math]::Abs($sig[$i] - $ref[$i]) }
    return [Math]::Round($d / $sig.Count, 1)
}

# Closest saved screen; Distance is the mean absolute colour difference per channel (0-255)
function Get-CivScreen {
    $sig = Get-CivScreenSignature
    $best = $null; $bestD = [double]::MaxValue
    foreach ($p in ((Get-SavedCivScreens).PSObject.Properties | Where-Object { $_.Name -notlike '_*' })) {
        $ref = @($p.Value); $d = 0
        for ($i = 0; $i -lt $sig.Count; $i++) { $d += [Math]::Abs($sig[$i] - $ref[$i]) }
        $d = $d / $sig.Count
        if ($d -lt $bestD) { $bestD = $d; $best = $p.Name }
    }
    return [pscustomobject]@{ Name = $best; Distance = [Math]::Round($bestD, 1) }
}
