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
$StrengthMetrics = 'Techs', 'Population', 'Land', 'Military', 'Cities'
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

# B-vs-C builds label the groups c (candidate changes) and b (the base build); report c in the "new" column and b in
# the "cp" column
if (@($rows | Where-Object { $_.Group -eq 'c' }).Count -gt 0) {
    foreach ($r in $rows) { if ($r.Group -eq 'c') { $r.Group = 'new' } elseif ($r.Group -eq 'b') { $r.Group = 'cp' } }
    Write-Output "B-vs-C build: below, 'new' is the candidate group c and 'cp' is the base group b."
}

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

    # Strength: the new group's share of the game's techs, population, land, military and cities, averaged (50% =
    # even). Civ's score also counts religion (20 points a belief) and wonders, which add score more than power.
    $shares = foreach ($m in $StrengthMetrics) {
        $all = ($civs | ForEach-Object { [double]$_.$m } | Measure-Object -Sum).Sum
        if ($all -le 0) { 0.5 } else { ($new | ForEach-Object { [double]$_.$m } | Measure-Object -Sum).Sum / $all }
    }
    $games += [pscustomobject]@{
        GameId    = $g.Name
        Turn      = $turn
        Victory   = if ($winner.Count -gt 0) { $winner[0].Victory } else { "" }
        WinnerGrp = if ($winner.Count -gt 0) { $winner[0].Group } else { "" }
        NewScore  = ($new | ForEach-Object { [double]$_.Score } | Measure-Object -Average).Average
        CpScore   = ($cp | ForEach-Object { [double]$_.Score } | Measure-Object -Average).Average
        NewStrength = 100.0 * ($shares | Measure-Object -Average).Average
        # the same without military: with almost no city changing hands, an army is mostly upkeep, and a civ that
        # builds few units shows its lead here
        NewEconomy = 100.0 * (@(for ($i = 0; $i -lt $StrengthMetrics.Count; $i++) { if ($StrengthMetrics[$i] -ne 'Military') { $shares[$i] } }) | Measure-Object -Average).Average
        Civs      = $civs
        Total     = $total
    }
}

if ($games.Count -eq 0) { throw "No test games reached turn $MinTurn yet" }

Write-Output ""
Write-Output ("{0} test games (turn {1} or later)" -f $games.Count, $MinTurn)
Write-Output ""
Write-Output "Per game at the last logged turn: the new group's strength share (its share of techs, population, land,"
Write-Output "military and cities; 50% = even) and each group's average score (which also counts religion and wonders):"
foreach ($g in $games) {
    $ahead = if ($g.NewStrength -gt 50) { "new stronger" } elseif ($g.NewStrength -lt 50) { "cp stronger" } else { "even" }
    $won = if ($g.WinnerGrp) { "  won by $($g.WinnerGrp) ($($g.Victory))" } else { "" }
    Write-Output ("  {0}  turn {1,3}  strength {2,5:N1}%  {3,-12}  no-military {7,5:N1}%  score new {4,4:N0} cp {5,4:N0}{6}" -f $g.GameId, $g.Turn, $g.NewStrength, $ahead, $g.NewScore, $g.CpScore, $won, $g.NewEconomy)
}

$newAhead = @($games | Where-Object { $_.NewStrength -gt 50 }).Count
$cpAhead = @($games | Where-Object { $_.NewStrength -lt 50 }).Count
$p = Get-SignTestP $newAhead ($newAhead + $cpAhead)
Write-Output ""
Write-Output ("Games stronger: new {0}, cp {1} (ties left out); chance of a split this uneven by luck: {2:P0}; average strength share {3:N1}%" -f $newAhead, $cpAhead, $p, ($games | Measure-Object NewStrength -Average).Average)
# The win count throws away the margins; a t-test on the per-game strength shares uses them, so a steady small edge
# shows up in fewer games. (One-sided: is the new group's share above 50%?)
if ($games.Count -ge 2) {
    $vals = @($games | ForEach-Object { [double]$_.NewStrength })
    $mean = ($vals | Measure-Object -Average).Average
    $var = (($vals | ForEach-Object { ($_ - $mean) * ($_ - $mean) }) | Measure-Object -Sum).Sum / ($vals.Count - 1)
    $se = [Math]::Sqrt($var / $vals.Count)
    $t = if ($se -gt 0) { ($mean - 50) / $se } else { 0 }
    # t distribution tail via the regularized incomplete beta function (Lentz continued fraction)
    function Get-BetaCF([double]$a, [double]$b, [double]$x) {
        $c = 1.0; $d = 1.0 - ($a + $b) * $x / ($a + 1); if ([Math]::Abs($d) -lt 1e-30) { $d = 1e-30 }; $d = 1 / $d; $h = $d
        for ($m = 1; $m -le 200; $m++) {
            $m2 = 2 * $m
            $aa = $m * ($b - $m) * $x / (($a + $m2 - 1) * ($a + $m2))
            $d = 1 + $aa * $d; if ([Math]::Abs($d) -lt 1e-30) { $d = 1e-30 }; $c = 1 + $aa / $c; if ([Math]::Abs($c) -lt 1e-30) { $c = 1e-30 }; $d = 1 / $d; $h *= $d * $c
            $aa = -($a + $m) * ($a + $b + $m) * $x / (($a + $m2) * ($a + $m2 + 1))
            $d = 1 + $aa * $d; if ([Math]::Abs($d) -lt 1e-30) { $d = 1e-30 }; $c = 1 + $aa / $c; if ([Math]::Abs($c) -lt 1e-30) { $c = 1e-30 }; $d = 1 / $d; $del = $d * $c; $h *= $del
            if ([Math]::Abs($del - 1) -lt 1e-10) { break }
        }
        return $h
    }
    function Get-LogGamma([double]$z) {
        $g = @(76.18009172947146, -86.50532032941677, 24.01409824083091, -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5)
        $y = $z; $tmp = $z + 5.5; $tmp -= ($z + 0.5) * [Math]::Log($tmp); $ser = 1.000000000190015
        foreach ($c in $g) { $y += 1; $ser += $c / $y }
        return -$tmp + [Math]::Log(2.5066282746310005 * $ser / $z)
    }
    $df = $vals.Count - 1
    $x = $df / ($df + $t * $t)
    $a = $df / 2.0; $b = 0.5
    $lbeta = (Get-LogGamma ($a + $b)) - (Get-LogGamma $a) - (Get-LogGamma $b) + $a * [Math]::Log($x) + $b * [Math]::Log(1 - $x)
    $ibeta = if ($x -lt ($a + 1) / ($a + $b + 2)) { [Math]::Exp($lbeta) * (Get-BetaCF $a $b $x) / $a } else { 1 - [Math]::Exp($lbeta) * (Get-BetaCF $b $a (1 - $x)) / $b }
    $pOne = if ($t -gt 0) { $ibeta / 2 } else { 1 - $ibeta / 2 }
    Write-Output ("Strength share {0:N1}% +/- {1:N1} (standard error); chance the new group is really no stronger than cp: {2:P0}" -f $mean, $se, $pOne)
}
Write-Output ("Strength share without military (techs, population, land, cities): {0:N1}%" -f ($games | Measure-Object NewEconomy -Average).Average)
$newScoreAhead = @($games | Where-Object { $_.NewScore -gt $_.CpScore }).Count
$cpScoreAhead = @($games | Where-Object { $_.NewScore -lt $_.CpScore }).Count
Write-Output ("Games ahead on score: new {0}, cp {1}" -f $newScoreAhead, $cpScoreAhead)
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

# Warmongers per group (files from c7c_flags on): the c/b split deals warmongers out c first, so c has more of them
# whenever a game has an odd number, and their personalities differ from the rest
if ($rows[0].PSObject.Properties.Name -contains "Warmonger") {
    Write-Output ""
    $cells = foreach ($grp in "new", "cp") {
        $n = @($games | ForEach-Object { $_.Civs } | Where-Object { $_.Group -eq $grp -and $_.Warmonger -eq "1" }).Count
        "{0} {1:N1}" -f $grp, ($n / $games.Count)
    }
    Write-Output ("Warmongers per game: {0}" -f ($cells -join ", "))
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
