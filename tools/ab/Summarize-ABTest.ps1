# Summarizes AIABTest.csv, the file AI A/B test games append to (see README.md next to this script).
#
#   powershell -ExecutionPolicy Bypass -File tools\ab\Summarize-ABTest.ps1 [-Csv <path>] [-MinTurn 100] [-AtTurn 100]
#       [-Delta 2] [-Sigma 0]
#
# Each game is judged at its last logged turn (or its final row if someone won), or at -AtTurn. The verdict is the
# test group's strength share. From lead job 4 on it also prints, per setup and flag configuration:
# - SPRT (the Stockfish Fishtest method, normal approximation): a gainer test (H0 gain 0, H1 gain Delta) and a
#   no-worse test (H0 -0.875 Delta, H1 +0.125 Delta, Fishtest's non-regression shape), on pairs of games (the same
#   map twice with the groups swapped; see Run-Games.ps1) or, with no pairs, on single games. Pass at LLR >= +2.94,
#   fail at <= -2.94 (5% chance of each kind of mistake). The LLR is shown from 2 results on, but only acted on
#   from 5, because the variance comes from the data.
# - how many pairs (or games) an SPRT at this Delta is expected to need, from the spread measured so far
#   (or -Sigma, the spread of one result, in strength-share points).
# - for screening runs (flags under Screen = in AIABTest.ini), a regression of each civ's strength on the screened
#   flags it ran.
param(
    [string]$Csv = "",    # one results file; by default every AIABTest*.csv in My Games, each on its own
    [int]$MinTurn = 100,  # ignore games that stopped before this turn
    [int]$AtTurn = 0,     # judge every game at this turn instead of its last (games that didn't log it are left out)
    [double]$Delta = 2.0, # SPRT: the smallest gain worth keeping, in strength-share points
    [double]$Sigma = 0,   # SPRT games estimate: spread of one result (pair or game) in points; 0 = measure it
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
        try { & $PSCommandPath -Csv $f.FullName -MinTurn $MinTurn -AtTurn $AtTurn -Delta $Delta -Sigma $Sigma } catch { Write-Output "  $($_.Exception.Message)" }
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
# One-sided: chance of a t at least this large if the true value were 0
function Get-TOneSidedP([double]$t, [int]$df) {
    if ($df -lt 1) { return 1.0 }
    $x = $df / ($df + $t * $t)
    $a = $df / 2.0; $b = 0.5
    if ($x -ge 1) { return 0.5 }
    $lbeta = (Get-LogGamma ($a + $b)) - (Get-LogGamma $a) - (Get-LogGamma $b) + $a * [Math]::Log($x) + $b * [Math]::Log(1 - $x)
    $ibeta = if ($x -lt ($a + 1) / ($a + $b + 2)) { [Math]::Exp($lbeta) * (Get-BetaCF $a $b $x) / $a } else { 1 - [Math]::Exp($lbeta) * (Get-BetaCF $b $a (1 - $x)) / $b }
    if ($t -gt 0) { return $ibeta / 2 } else { return 1 - $ibeta / 2 }
}

# Least squares: coefficients, their standard errors and the residual degrees of freedom. $X is a list of rows (each a
# double[]), $y the responses. Gauss-Jordan on the normal equations; fine for a handful of columns.
function Get-OLS($X, [double[]]$y) {
    $n = $y.Count; $k = $X[0].Count
    $A = New-Object 'double[,]' $k, ($k * 2)
    $Xty = New-Object double[] $k
    for ($r = 0; $r -lt $n; $r++) {
        for ($i = 0; $i -lt $k; $i++) {
            $Xty[$i] += $X[$r][$i] * $y[$r]
            for ($j = 0; $j -lt $k; $j++) { $A[$i, $j] += $X[$r][$i] * $X[$r][$j] }
        }
    }
    for ($i = 0; $i -lt $k; $i++) { $A[$i, ($k + $i)] = 1.0 }
    for ($c = 0; $c -lt $k; $c++) {
        $piv = $c
        for ($r = $c + 1; $r -lt $k; $r++) { if ([Math]::Abs($A[$r, $c]) -gt [Math]::Abs($A[$piv, $c])) { $piv = $r } }
        if ([Math]::Abs($A[$piv, $c]) -lt 1e-9) { return $null }   # a column never varies: can't be estimated
        if ($piv -ne $c) { for ($j = 0; $j -lt 2 * $k; $j++) { $tmp = $A[$c, $j]; $A[$c, $j] = $A[$piv, $j]; $A[$piv, $j] = $tmp } }
        $d = $A[$c, $c]
        for ($j = 0; $j -lt 2 * $k; $j++) { $A[$c, $j] /= $d }
        for ($r = 0; $r -lt $k; $r++) {
            if ($r -eq $c) { continue }
            $f = $A[$r, $c]
            if ($f -ne 0) { for ($j = 0; $j -lt 2 * $k; $j++) { $A[$r, $j] -= $f * $A[$c, $j] } }
        }
    }
    $beta = New-Object double[] $k
    for ($i = 0; $i -lt $k; $i++) { for ($j = 0; $j -lt $k; $j++) { $beta[$i] += $A[$i, ($k + $j)] * $Xty[$j] } }
    $rss = 0.0
    for ($r = 0; $r -lt $n; $r++) {
        $fit = 0.0; for ($i = 0; $i -lt $k; $i++) { $fit += $X[$r][$i] * $beta[$i] }
        $rss += ($y[$r] - $fit) * ($y[$r] - $fit)
    }
    $df = $n - $k
    $s2 = if ($df -gt 0) { $rss / $df } else { [double]::NaN }
    $se = New-Object double[] $k
    for ($i = 0; $i -lt $k; $i++) { $se[$i] = [Math]::Sqrt([Math]::Max(0.0, $s2 * $A[$i, ($k + $i)])) }
    return [pscustomobject]@{ Beta = $beta; SE = $se; DF = $df }
}

# SPRT log-likelihood ratio, Fishtest's normal approximation (LLRcalc.LLR_alt2): N (s1 - s0)(2 mean - s0 - s1) / (2 var)
function Get-SprtLLR([double[]]$x, [double]$s0, [double]$s1) {
    $n = $x.Count
    if ($n -lt 2) { return $null }
    $mean = ($x | Measure-Object -Average).Average
    $var = (($x | ForEach-Object { ($_ - $mean) * ($_ - $mean) }) | Measure-Object -Sum).Sum / ($n - 1)
    if ($var -le 0) { return $null }
    return $n * ($s1 - $s0) * (2 * $mean - $s0 - $s1) / (2 * $var)
}

# The flags group c ran in a game, without the screened ones (those vary civ by civ): "CanWin", "none", ...
function Get-CFlags($civs) {
    $screen = @($civs[0].Screen -split '\+' | Where-Object { $_ -and $_ -ne "none" })
    $sets = @($civs | Where-Object { $_.Group -eq "new" } | ForEach-Object {
        $l = @($_.Fixes -split '\+' | Where-Object { $_ -and $_ -ne "none" -and $screen -notcontains $_ })
        if ($l.Count -eq 0) { "none" } else { $l -join "+" }
    } | Sort-Object -Unique)
    return ($sets -join " / ")
}

$games = @()
foreach ($g in ($rows | Group-Object GameId)) {
    $final = @($g.Group | Where-Object { $_.Final -eq "1" })
    $pick = if ($AtTurn -gt 0) {
        # the 10-turn row of that turn, or the final row if the game was won exactly then
        $at = @($g.Group | Where-Object { [int]$_.Turn -eq $AtTurn -and $_.Final -ne "1" })
        if ($at.Count -eq 0) { $at = @($g.Group | Where-Object { [int]$_.Turn -eq $AtTurn }) }
        if ($at.Count -eq 0) { continue }
        $at
    } elseif ($final.Count -gt 0) { $final } else {
        $last = ($g.Group | ForEach-Object { [int]$_.Turn } | Measure-Object -Maximum).Maximum
        @($g.Group | Where-Object { [int]$_.Turn -eq $last })
    }
    # A reloaded save can log the same turn twice: keep the last row per player.
    $civs = @($pick | Group-Object Player | ForEach-Object { $_.Group[-1] })
    $turn = [int]$civs[0].Turn
    if ($AtTurn -le 0 -and $turn -lt $MinTurn) { continue }
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
        # paired games: the second game of a pair has the first one's GameId plus F
        BaseId    = ($g.Name -replace 'F$', '')
        Flipped   = ($g.Name -match 'F$')
        # setup and the flags group c ran; games with different ones are tested separately (files before c7c_settings: one)
        Config    = if ($civs[0].PSObject.Properties.Name -contains "Fixes") {
            "{0} {1} {2} {3} stop T{4}; c runs {5}; screened {6}" -f $civs[0].Map, $civs[0].MapOptions, $civs[0].Pace, $civs[0].Difficulty, $civs[0].StopTurn,
                (Get-CFlags $civs), $civs[0].Screen
        } else { "this file" }
        Total     = $total
    }
}

if ($games.Count -eq 0) { throw "No test games reached turn $MinTurn yet" }

# Settings (files from c7c_settings on): every row records the game's setup and which candidate flags each civ ran.
# Games from different setups or flag configurations shouldn't be pooled: list them, so a mix is obvious.
if ($rows[0].PSObject.Properties.Name -contains "Fixes") {
    Write-Output ""
    Write-Output "Setups and flag configurations in this file (games at turn $MinTurn or later):"
    $configs = foreach ($g in $games) {
        $c0 = $g.Civs[0]
        $setup = "{0} {1}, {2}, {3}, {4}, ruins {5}, barbarians {6}, stop T{7}" -f $c0.Map, $c0.MapOptions, $c0.WorldSize, $c0.Pace, $c0.Difficulty, $c0.Ruins, $c0.Barbarians, $c0.StopTurn
        $flags = "c runs {0}; screened {1}" -f (Get-CFlags $g.Civs), $c0.Screen
        [pscustomobject]@{ Setup = $setup; Flags = $flags; Flip = $c0.Flip; Build = $c0.Build }
    }
    foreach ($grp in ($configs | Group-Object Setup, Flags, Build)) {
        $flips = @($grp.Group | Where-Object { $_.Flip -eq "1" }).Count
        Write-Output ("  {0,3} games ({1} flipped)  {2}" -f $grp.Count, $flips, $grp.Group[0].Setup)
        Write-Output ("        {0}; build {1}" -f $grp.Group[0].Flags, $grp.Group[0].Build)
    }
    if (@($configs | Group-Object Setup, Flags).Count -gt 1) {
        Write-Output "  WARNING: more than one setup or flag configuration. The results below pool them; split the file to compare."
    }
}

Write-Output ""
if ($AtTurn -gt 0) { Write-Output ("{0} test games, judged at turn {1}" -f $games.Count, $AtTurn) }
else { Write-Output ("{0} test games (turn {1} or later)" -f $games.Count, $MinTurn) }
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
    $pOne = Get-TOneSidedP $t ($vals.Count - 1)
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

# ---- SPRT per setup and flag configuration (lead job 4) ----
$llrBound = [Math]::Log(0.95 / 0.05)   # 2.944: alpha = beta = 5%
Write-Output ""
Write-Output ("SPRT (Fishtest method, normal approximation), Delta = {0:N1} points of strength share; pass at LLR >= +{1:N2}, fail at <= -{1:N2}:" -f $Delta, $llrBound)
foreach ($cfg in ($games | Group-Object Config)) {
    $list = @($cfg.Group)
    # results: pairs where both games are here (mean of the two c shares), otherwise single games
    $pairs = @($list | Group-Object BaseId | Where-Object { $_.Count -eq 2 -and @($_.Group | Where-Object { $_.Flipped }).Count -eq 1 })
    if ($pairs.Count -gt 0) {
        $kind = "pairs"
        $x = @($pairs | ForEach-Object { (($_.Group | Measure-Object NewStrength -Average).Average) - 50 })
        $leftOver = $list.Count - 2 * $pairs.Count
    } else {
        $kind = "games (unpaired)"
        $x = @($list | ForEach-Object { $_.NewStrength - 50 })
        $leftOver = 0
    }
    Write-Output ("  {0}" -f $cfg.Name)
    $n = $x.Count
    $mean = ($x | Measure-Object -Average).Average
    $sd = if ($n -ge 2) { [Math]::Sqrt((($x | ForEach-Object { ($_ - $mean) * ($_ - $mean) }) | Measure-Object -Sum).Sum / ($n - 1)) } else { [double]::NaN }
    $extra = if ($leftOver -gt 0) { "; $leftOver game(s) without their pair left out" } else { "" }
    Write-Output ("    {0} {1}: gain {2:+0.00;-0.00} points (c share {3:N2}%), spread of one result {4:N2}{5}" -f $n, $kind, $mean, (50 + $mean), $sd, $extra)
    foreach ($test in @(@{ Name = "gainer";    S0 = 0.0;            S1 = $Delta },
                        @{ Name = "no-worse";  S0 = -0.875 * $Delta; S1 = 0.125 * $Delta })) {
        $llr = Get-SprtLLR $x $test.S0 $test.S1
        $state = if ($null -eq $llr) { "needs 2+ results" }
            elseif ($n -lt 5) { "too few to decide (5+ needed)" }
            elseif ($llr -ge $llrBound) { "PASSED" }
            elseif ($llr -le -$llrBound) { "FAILED" }
            else { "running" }
        $llrText = if ($null -eq $llr) { "   -  " } else { "{0,6:+0.00;-0.00}" -f $llr }
        Write-Output ("    {0,-9} H0 {1,5:+0.00;-0.00} H1 {2,5:+0.00;-0.00}  LLR {3}  {4}" -f $test.Name, $test.S0, $test.S1, $llrText, $state)
    }
    # Expected length (Wald): about 5.3 s^2/Delta^2 results when the true gain is at H0 or H1, 8.7 s^2/Delta^2 at worst
    $s = if ($Sigma -gt 0) { $Sigma } else { $sd }
    if ($s -gt 0) {
        $src = if ($Sigma -gt 0) { "-Sigma" } else { "measured" }
        Write-Output ("    expected length at spread {0:N2} ({1}): about {2:N0} {3} if the true gain is 0 or Delta, up to {4:N0} if it's halfway" -f $s, $src,
            (2 * 0.9 * $llrBound * $s * $s / ($Delta * $Delta)), ($kind -replace ' \(unpaired\)', ''), ($llrBound * $llrBound * $s * $s / ($Delta * $Delta)))
    }
}

# ---- Screening regression (lead job 4): each civ's strength against the screened flags it ran ----
if ($rows[0].PSObject.Properties.Name -contains "Screen") {
    $screened = @($games | ForEach-Object { $_.Civs[0].Screen } | Where-Object { $_ -and $_ -ne "none" } | ForEach-Object { $_ -split '\+' } | Sort-Object -Unique)
    if ($screened.Count -gt 0) {
        $sg = @($games | Where-Object { $_.Civs[0].Screen -and $_.Civs[0].Screen -ne "none" })
        # a civ's strength: its share of the game's techs, population, land, military and cities, averaged, in points
        $civY = {
            param($game, $civ)
            $sum = 0.0
            foreach ($m in $StrengthMetrics) {
                $all = ($game.Civs | ForEach-Object { [double]$_.$m } | Measure-Object -Sum).Sum
                $sum += if ($all -le 0) { 1.0 / $game.Civs.Count } else { [double]$civ.$m / $all }
            }
            100.0 * $sum / $StrengthMetrics.Count
        }
        $hasFlag = { param($civ, $flag) (@($civ.Fixes -split '\+') -contains $flag) }
        $nCivs = ($sg | ForEach-Object { $_.Civs.Count } | Measure-Object -Average).Average
        $sPairs = @($sg | Group-Object BaseId | Where-Object { $_.Count -eq 2 -and @($_.Group | Where-Object { $_.Flipped }).Count -eq 1 })
        $X = New-Object System.Collections.ArrayList; $Y = New-Object System.Collections.ArrayList
        if ($sPairs.Count -gt 0) {
            # Paired: each civ played the same map twice with every screened flag swapped, so its difference between
            # the two games is the flags' effect plus noise; the civ and the map cancel out. No intercept.
            $design = "paired: per civ, first game minus second, {0} pairs" -f $sPairs.Count
            foreach ($p in $sPairs) {
                $g1 = @($p.Group | Where-Object { -not $_.Flipped })[0]; $g2 = @($p.Group | Where-Object { $_.Flipped })[0]
                foreach ($c1 in $g1.Civs) {
                    $c2 = @($g2.Civs | Where-Object { $_.Player -eq $c1.Player -and $_.Civ -eq $c1.Civ })
                    if ($c2.Count -eq 0) { continue }
                    $row = foreach ($f in $screened) { ([double](& $hasFlag $c1 $f)) - ([double](& $hasFlag $c2[0] $f)) }
                    [void]$X.Add([double[]]@($row)); [void]$Y.Add((& $civY $g1 $c1) - (& $civY $g2 $c2[0]))
                }
            }
            $cols = $screened
        } else {
            # Unpaired: pooled over civs, with an intercept and a warmonger term (warmongers differ, and flags are dealt
            # half to warmongers)
            $design = "pooled over {0} games (no pairs yet)" -f $sg.Count
            $hasWm = $rows[0].PSObject.Properties.Name -contains "Warmonger"
            foreach ($g in $sg) {
                foreach ($c in $g.Civs) {
                    $row = @(1.0) + @(foreach ($f in $screened) { [double](& $hasFlag $c $f) })
                    if ($hasWm) { $row += [double]($c.Warmonger -eq "1") }
                    [void]$X.Add([double[]]$row); [void]$Y.Add((& $civY $g $c))
                }
            }
            $cols = @("(intercept)") + $screened
            if ($hasWm) { $cols += "(warmonger)" }
        }
        Write-Output ""
        Write-Output ("Screening regression ({0}; {1} observations). Effect of each flag on the strength of a civ that runs it," -f $design, $Y.Count)
        Write-Output ("in points of the game's strength (a civ averages {0:N1}); 'as group share' is what it would add to a half of the civs running it:" -f (100.0 / $nCivs))
        $fit = if ($Y.Count -gt $cols.Count) { Get-OLS $X.ToArray() ([double[]]$Y.ToArray()) } else { $null }
        if (-not $fit) { Write-Output "  not enough data yet (or a flag that never varies)" }
        else {
            for ($i = 0; $i -lt $cols.Count; $i++) {
                if ($cols[$i] -like "(*") { continue }
                # on minus off for a civ (paired rows code a flag as +1 on in the first game, -1 on in the second)
                $eff = $fit.Beta[$i]
                $se = $fit.SE[$i]
                $t = if ($se -gt 0) { $eff / $se } else { 0 }
                $pUp = Get-TOneSidedP $t $fit.DF
                Write-Output ("  {0,-14} {1,6:+0.00;-0.00} +/- {2,4:N2}  as group share {3,6:+0.00;-0.00}  chance it's really no better: {4,4:P0}" -f $cols[$i], $eff, $se, ($eff * $nCivs / 4), $pUp)
            }
            Write-Output "  Screening only ranks flags: confirm the promising ones with an SPRT on the flag alone."
        }
    }
}

Write-Output ""
Write-Output "A difference only means something once the chance above is small (under 5%) over many games."
