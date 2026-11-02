# Summarizes AIABTest.csv, the file AI A/B test games append to (see README.md next to this script).
#
#   powershell -ExecutionPolicy Bypass -File tools\ab\Summarize-ABTest.ps1 [-Csv <path>] [-MinTurn 100]
#
# Each game is judged at its last logged turn (or its final row if someone won). The main result is
# how many games the "new" group (changed AI) finished ahead of the "cp" group (Community Patch's
# AI) on average score, with a sign test for how likely that split is by chance.
param(
    [string]$Csv = "",    # one results file; by default every AIABTest*.csv in My Games, each on its own
    [int]$MinTurn = 100,  # ignore games that stopped before this turn
    [string]$MyGames = "$([Environment]::GetFolderPath('MyDocuments'))\My Games\Sid Meier's Civilization 5"
)

$ErrorActionPreference = "Stop"
if (-not $Csv) {
    # Each build of AI changes writes its own file (AIABTest_batch1.csv, ...; the first build, with no
    # changes, wrote AIABTest.csv), so results from different builds are never mixed.
    $files = @(Get-ChildItem -Path $MyGames -Filter "AIABTest*.csv" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
    if ($files.Count -eq 0) { throw "No AIABTest*.csv in $MyGames. Play a test game with the -ABTest pack first." }
    foreach ($f in $files) {
        Write-Output ""
        Write-Output ("===== {0} =====" -f $f.Name)
        try { & $PSCommandPath -Csv $f.FullName -MinTurn $MinTurn } catch { Write-Output "  $($_.Exception.Message)" }
    }
    return
}
if (-not (Test-Path $Csv)) { throw "No results file at $Csv. Play a test game with the -ABTest pack first." }
$rows = @(Import-Csv $Csv)
if ($rows.Count -eq 0) { throw "$Csv has no rows" }

# Two-sided sign test: chance of a split at least this uneven if both groups were equally good.
function Get-SignTestP([int]$wins, [int]$n) {
    if ($n -eq 0) { return 1.0 }
    $k = [Math]::Min($wins, $n - $wins)
    $p = 0.0
    for ($i = 0; $i -le $k; $i++) {
        # log of n choose i, times 0.5^n
        $logC = 0.0
        for ($j = 1; $j -le $i; $j++) { $logC += [Math]::Log($n - $i + $j) - [Math]::Log($j) }
        $p += [Math]::Exp($logC - $n * [Math]::Log(2))
    }
    return [Math]::Min(1.0, 2 * $p)
}

$games = @()
foreach ($g in ($rows | Group-Object GameId)) {
    $final = @($g.Group | Where-Object { $_.Final -eq "1" })
    $pick = if ($final.Count -gt 0) { $final } else {
        $last = ($g.Group | ForEach-Object { [int]$_.Turn } | Measure-Object -Maximum).Maximum
        @($g.Group | Where-Object { [int]$_.Turn -eq $last })
    }
    # A reloaded save can log the same turn twice: keep the last row per player.
    $civs = @($pick | Group-Object Player | ForEach-Object { $_.Group[-1] })
    $turn = [int]$civs[0].Turn
    if ($turn -lt $MinTurn) { continue }
    $new = @($civs | Where-Object { $_.Group -eq "new" })
    $cp = @($civs | Where-Object { $_.Group -eq "cp" })
    if ($new.Count -eq 0 -or $cp.Count -eq 0) { continue }   # not a test game

    $total = ($civs | ForEach-Object { [double]$_.Score } | Measure-Object -Sum).Sum
    if ($total -le 0) { $total = 1 }
    $winner = @($civs | Where-Object { $_.Winner -eq "1" })
    $games += [pscustomobject]@{
        GameId    = $g.Name
        Turn      = $turn
        Victory   = if ($winner.Count -gt 0) { $winner[0].Victory } else { "" }
        WinnerGrp = if ($winner.Count -gt 0) { $winner[0].Group } else { "" }
        NewScore  = ($new | ForEach-Object { [double]$_.Score } | Measure-Object -Average).Average
        CpScore   = ($cp | ForEach-Object { [double]$_.Score } | Measure-Object -Average).Average
        Civs      = $civs
        Total     = $total
    }
}

if ($games.Count -eq 0) { throw "No test games reached turn $MinTurn yet" }

Write-Output ""
Write-Output ("{0} test games (turn {1} or later)" -f $games.Count, $MinTurn)
Write-Output ""
Write-Output "Per game (average score of each group at the last logged turn):"
foreach ($g in $games) {
    $ahead = if ($g.NewScore -gt $g.CpScore) { "new ahead" } elseif ($g.NewScore -lt $g.CpScore) { "cp ahead" } else { "tie" }
    $won = if ($g.WinnerGrp) { "  won by $($g.WinnerGrp) ($($g.Victory))" } else { "" }
    Write-Output ("  {0}  turn {1,3}  new {2,6:N0}  cp {3,6:N0}  {4}{5}" -f $g.GameId, $g.Turn, $g.NewScore, $g.CpScore, $ahead, $won)
}

$newAhead = @($games | Where-Object { $_.NewScore -gt $_.CpScore }).Count
$cpAhead = @($games | Where-Object { $_.NewScore -lt $_.CpScore }).Count
$p = Get-SignTestP $newAhead ($newAhead + $cpAhead)
Write-Output ""
Write-Output ("Games ahead on score: new {0}, cp {1} (ties left out); chance of a split this uneven by luck: {2:P0}" -f $newAhead, $cpAhead, $p)
$newWins = @($games | Where-Object { $_.WinnerGrp -eq "new" }).Count
$cpWins = @($games | Where-Object { $_.WinnerGrp -eq "cp" }).Count
Write-Output ("Games won outright: new {0}, cp {1}, unfinished {2}" -f $newWins, $cpWins, ($games.Count - $newWins - $cpWins))

# Averages per civ, by group, over all games.
Write-Output ""
Write-Output "Average per civ at the last logged turn:"
Write-Output ("  {0,-5} {1,6} {2,8} {3,7} {4,7} {5,6} {6,9} {7,9} {8,9} {9,8} {10,12}" -f "Group", "Civs", "Score%", "Alive", "Cities", "Pop", "Techs", "Policies", "Military", "Wonders", "LostCapital")
foreach ($grp in "new", "cp") {
    $list = @()
    foreach ($g in $games) {
        foreach ($c in @($g.Civs | Where-Object { $_.Group -eq $grp })) {
            $list += [pscustomobject]@{
                Share = 100.0 * [double]$c.Score / $g.Total; Alive = [double]$c.Alive; Cities = [double]$c.Cities
                Pop = [double]$c.Population; Techs = [double]$c.Techs; Policies = [double]$c.Policies
                Military = [double]$c.Military; Wonders = [double]$c.Wonders; Lost = [double]$c.LostCapital
            }
        }
    }
    $avg = { param($f) ($list | ForEach-Object { $_.$f } | Measure-Object -Average).Average }
    Write-Output ("  {0,-5} {1,6} {2,7:N1}% {3,6:P0} {4,7:N1} {5,6:N1} {6,9:N1} {7,9:N1} {8,9:N0} {9,8:N1} {10,11:P0}" -f $grp, $list.Count,
        (& $avg "Share"), (& $avg "Alive"), (& $avg "Cities"), (& $avg "Pop"), (& $avg "Techs"), (& $avg "Policies"),
        (& $avg "Military"), (& $avg "Wonders"), (& $avg "Lost"))
}

# Early-game milestones (files from batch2a on): turn the 2nd-4th cities were founded, National College,
# and which opening plan the civ followed. Averages count only civs that reached the milestone.
if ($rows[0].PSObject.Properties.Name -contains "City2Turn") {
    Write-Output ""
    Write-Output "Early game, average per civ at the last logged turn (turn founded; share of civs that got there):"
    Write-Output ("  {0,-5} {1,14} {2,14} {3,14} {4,16}  {5}" -f "Group", "2nd city", "3rd city", "4th city", "NationalCollege", "Opening plans")
    foreach ($grp in "new", "cp") {
        $civs = @($games | ForEach-Object { $_.Civs } | Where-Object { $_.Group -eq $grp })
        if ($civs.Count -eq 0) { continue }
        $cells = foreach ($col in "City2Turn", "City3Turn", "City4Turn") {
            $reached = @($civs | Where-Object { [int]$_.$col -ge 0 } | ForEach-Object { [double]$_.$col })
            if ($reached.Count -eq 0) { "-" } else { "T{0:N0} ({1:P0})" -f ($reached | Measure-Object -Average).Average, ($reached.Count / $civs.Count) }
        }
        $nc = @($civs | Where-Object { $_.NationalCollege -eq "1" }).Count / $civs.Count
        $plans = ($civs | Group-Object Book | Sort-Object Name | ForEach-Object { "$($_.Name) $($_.Count)" }) -join ", "
        Write-Output ("  {0,-5} {1,14} {2,14} {3,14} {4,16:P0}  {5}" -f $grp, $cells[0], $cells[1], $cells[2], $nc, $plans)
    }
}

Write-Output ""
Write-Output "A difference only means something once the chance above is small (under 5%) over many games."
