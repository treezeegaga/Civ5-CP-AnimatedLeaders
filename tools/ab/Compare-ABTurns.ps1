# Do early standings predict later ones? For every test game that logged both turns, compares the test group's
# strength share (techs, population, land, military and cities, averaged; 50% = even) at -Early and -Late:
# correlation, slope, how often the side that's ahead changes, and the per-game spread within each build.
# Lead job 8 (see RESULTS.md); run it again once games under the current setup have piled up.
#
#   powershell -ExecutionPolicy Bypass -File tools\ab\Compare-ABTurns.ps1 [-Folder tools\ab\results] [-Early 100] [-Late 150]
param(
    [string]$Folder = (Join-Path $PSScriptRoot "results"),
    [int]$Early = 100,
    [int]$Late = 150
)
$ErrorActionPreference = "Stop"
$metrics = 'Techs', 'Population', 'Land', 'Military', 'Cities'

function Get-Share($civs) {
    $sum = 0.0
    foreach ($m in $metrics) {
        $all = ($civs | ForEach-Object { [double]$_.$m } | Measure-Object -Sum).Sum
        $mine = ($civs | Where-Object { $_.Group -eq 'new' -or $_.Group -eq 'c' } | ForEach-Object { [double]$_.$m } | Measure-Object -Sum).Sum
        $sum += if ($all -le 0) { 0.5 } else { $mine / $all }
    }
    return 100.0 * $sum / $metrics.Count - 50
}
function Get-Rows($game, [int]$turn) {
    @($game | Where-Object { [int]$_.Turn -eq $turn -and $_.Final -ne '1' } | Group-Object Player | ForEach-Object { $_.Group[-1] })
}

$pairs = @()
foreach ($f in Get-ChildItem $Folder -Filter "AIABTest*.csv") {
    foreach ($g in (Import-Csv $f.FullName | Group-Object GameId)) {
        $a = Get-Rows $g.Group $Early; $b = Get-Rows $g.Group $Late
        if ($a.Count -eq 0 -or $a.Count -ne $b.Count) { continue }
        $n = @($a | Where-Object { $_.Group -eq 'new' -or $_.Group -eq 'c' }).Count
        if ($n -eq 0 -or $n -eq $a.Count) { continue }
        $pairs += [pscustomobject]@{ Build = $f.BaseName; X = (Get-Share $a); Y = (Get-Share $b) }
    }
}
if ($pairs.Count -lt 3) { throw "Fewer than 3 games logged both turn $Early and turn $Late" }

$mx = ($pairs | Measure-Object X -Average).Average; $my = ($pairs | Measure-Object Y -Average).Average
$sxy = 0.0; $sxx = 0.0; $syy = 0.0
foreach ($p in $pairs) { $sxy += ($p.X - $mx) * ($p.Y - $my); $sxx += ($p.X - $mx) * ($p.X - $mx); $syy += ($p.Y - $my) * ($p.Y - $my) }
Write-Output ("{0} games from {1} files logged turns {2} and {3}" -f $pairs.Count, @($pairs | Group-Object Build).Count, $Early, $Late)
Write-Output ("Group gain at T{0} vs T{1}: correlation {2:N2}, slope {3:N2} (1 = an edge keeps its size)" -f $Early, $Late, ($sxy / [Math]::Sqrt($sxx * $syy)), ($sxy / $sxx))

# the side ahead at the early turn, by its margin then
Write-Output "Side ahead changed between the two turns, by the early margin:"
foreach ($band in @(@(0, 1), @(1, 2), @(2, 4), @(4, 1000))) {
    $in = @($pairs | Where-Object { [Math]::Abs($_.X) -ge $band[0] -and [Math]::Abs($_.X) -lt $band[1] })
    $flips = @($in | Where-Object { ($_.X -gt 0) -ne ($_.Y -gt 0) }).Count
    $label = if ($band[1] -ge 1000) { "{0}+ points" -f $band[0] } else { "{0}-{1} points" -f $band[0], $band[1] }
    Write-Output ("  {0,-12} {1,3} games, {2,3} changed side" -f $label, $in.Count, $flips)
}

# spread of one game within a build (each build's mean taken out), at each turn
foreach ($side in "X", "Y") {
    $num = 0.0; $df = 0
    foreach ($b in ($pairs | Group-Object Build)) {
        if ($b.Count -lt 2) { continue }
        $m = ($b.Group | Measure-Object $side -Average).Average
        foreach ($p in $b.Group) { $num += ($p.$side - $m) * ($p.$side - $m) }
        $df += $b.Count - 1
    }
    $turn = if ($side -eq "X") { $Early } else { $Late }
    if ($df -gt 0) { Write-Output ("Spread of one game within a build at T{0}: {1:N2} points ({2} degrees of freedom)" -f $turn, [Math]::Sqrt($num / $df), $df) }
}
