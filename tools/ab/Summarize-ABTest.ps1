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
    [switch]$Scoreboard,  # one row per results file for the scoreboard at the top of RESULTS.md, instead of the full report
    [string]$Json = "",   # also write the games, SPRTs and screening ranks of one results file (-Csv) to this JSON file (the dashboard)
    [string]$MyGames = "$([Environment]::GetFolderPath('MyDocuments'))\My Games\Sid Meier's Civilization 5"
)

$ErrorActionPreference = "Stop"
$StrengthMetrics = 'Techs', 'Population', 'Land', 'Military', 'Cities'
if (-not $Csv) {
    # Each build of AI changes writes its own file (AIABTest_batch1.csv, ...; the first build, with no
    # changes, wrote AIABTest.csv), so results from different builds are never mixed.
    $files = @(Get-ChildItem -Path $MyGames -Filter "AIABTest*.csv" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
    if ($files.Count -eq 0) { throw "No AIABTest*.csv in $MyGames. Play a test game with the -ABTest pack first." }
    if ($Scoreboard) {
        Write-Output "| Results file | Games | Strength share of the test group | Aggressor's cities at the end | Cities per war | Coalition: civs at war with it; turns to 2+ | Deals per civ per 10 turns | Banned behaviours | Seconds per turn |"
        Write-Output "|---|---|---|---|---|---|---|---|---|"
        foreach ($f in $files) {
            try { & $PSCommandPath -Csv $f.FullName -MinTurn $MinTurn -AtTurn $AtTurn -Scoreboard } catch { Write-Output ("| {0} | {1} |" -f $f.BaseName, $_.Exception.Message) }
        }
        return
    }
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
    if (-not $Scoreboard) { Write-Output "B-vs-C build: below, 'new' is the candidate group c and 'cp' is the base group b." }
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
        for ($r = $c + 1; $r -lt $k; $r++) { if ([Math]::Abs(($A[$r, $c])) -gt [Math]::Abs(($A[$piv, $c]))) { $piv = $r } }
        if ([Math]::Abs(($A[$piv, $c])) -lt 1e-9) { return $null }   # a column never varies: can't be estimated
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
    for ($i = 0; $i -lt $k; $i++) { $se[$i] = [Math]::Sqrt([Math]::Max(0.0, $s2 * ($A[$i, ($k + $i)]))) }
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
$roleGames = @()
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
    # bully and builders games (lead job 10) are judged by what happens to the roles, not by the c/b strength split
    if (($civs[0].PSObject.Properties.Name -contains "Mode") -and $civs[0].Mode -and $civs[0].Mode -ne "split") {
        $roleGames += [pscustomobject]@{ GameId = $g.Name; Turn = $turn; Civs = $civs; BaseId = ($g.Name -replace 'F$', ''); Flipped = ($g.Name -match 'F$') }
        continue
    }
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

# ---- Bully and builders tests, diplomacy and banned behaviours (lead job 10; files from c7c_roles on) ----
# The bully test's numbers per game (lead job 10): the aggressor's share of all cities at T100 and at the end, its
# captures and wars, how many civs are at war with it at the end, and the turns from its first conquest until two or
# more civs were at war with it (-1 = never, $null = it took no city).
function Get-BullyStats {
    $bullyGames = @($roleGames | Where-Object { $_.Civs[0].Mode -eq "bully" })
    if ($bullyGames.Count -eq 0) { return }
    $byGame = @{}
    foreach ($grp in ($rows | Group-Object GameId)) { $byGame[$grp.Name] = $grp.Group }
    $num = { param($r, $col) if ($r -and $r.$col -ne $null -and $r.$col -ne "") { [double]$r.$col } else { 0.0 } }
    $rowsAt = { param($gid, $turn) @($byGame[$gid] | Where-Object { [int]$_.Turn -eq $turn -and $_.Final -ne "1" } | Group-Object Player | ForEach-Object { $_.Group[-1] }) }
    $cityShare = { param($civs, $player)
        $all = ($civs | ForEach-Object { [double]$_.Cities } | Measure-Object -Sum).Sum
        $mine = @($civs | Where-Object { $_.Player -eq $player })
        if ($all -le 0 -or $mine.Count -eq 0) { 0.0 } else { 100.0 * [double]$mine[0].Cities / $all } }
    foreach ($g in $bullyGames) {
        $agg = @($g.Civs | Where-Object { $_.Role -eq "aggressor" })[0]
        $tall = @($g.Civs | Where-Object { $_.Role -eq "tall" })[0]
        if (-not $agg) { continue }
        $t100 = & $rowsAt $g.GameId 100
        $turns = @($byGame[$g.GameId] | Where-Object { $_.Final -ne "1" } | ForEach-Object { [int]$_.Turn } | Sort-Object -Unique)
        $firstCapture = @(foreach ($t in $turns) { $r = @(& $rowsAt $g.GameId $t | Where-Object { $_.Player -eq $agg.Player }); if ($r.Count -and (& $num $r[0] "CitiesCaptured") -gt 0) { $t; break } })
        $coalition = $null
        if ($firstCapture.Count) {
            $joined = @(foreach ($t in ($turns | Where-Object { $_ -ge $firstCapture[0] })) {
                if (@(& $rowsAt $g.GameId $t | Where-Object { $_.AtWarAggressor -eq "1" }).Count -ge 2) { $t; break } })
            $coalition = if ($joined.Count) { $joined[0] - $firstCapture[0] } else { -1 }
        }
        [pscustomobject]@{
            GameId = $g.GameId; BaseId = $g.BaseId; Flipped = $g.Flipped
            Aggressor = ($agg.Civ -replace 'CIVILIZATION_', '')
            Share100 = if ($t100.Count) { & $cityShare $t100 $agg.Player } else { $null }
            ShareEnd = & $cityShare $g.Civs $agg.Player
            Captured = & $num $agg "CitiesCaptured"
            Wars = & $num $agg "WarsDeclared"
            AtWar = @($g.Civs | Where-Object { $_.AtWarAggressor -eq "1" }).Count
            CoalitionTurns = $coalition
            TallText = if ($tall) { "{0}/{1}/{2}" -f (& $num $tall "WarsOnUs"), (& $num $tall "Friends"), (& $num $tall "Pacts") } else { "-" }
            # files from c7c_proposals on: joint wars and sanctions the other civs aimed at the aggressor
            CoopVsAgg = ($g.Civs | ForEach-Object { & $num $_ "CoopWarAgreedVsAggressor" } | Measure-Object -Sum).Sum
            SanctionsVsAgg = ($g.Civs | ForEach-Object { & $num $_ "SanctionsProposedVsAggressor" } | Measure-Object -Sum).Sum
        }
    }
}

function Show-RoleTests {
if (-not ($rows[0].PSObject.Properties.Name -contains "Role")) { return }
    $byGame = @{}
    foreach ($grp in ($rows | Group-Object GameId)) { $byGame[$grp.Name] = $grp.Group }
    $num = { param($r, $col) if ($r -and $r.$col -ne $null -and $r.$col -ne "") { [double]$r.$col } else { 0.0 } }
    # one civ's rows over the game, by turn (the last row per turn)
    $civRows = { param($gid, $player) @($byGame[$gid] | Where-Object { $_.Player -eq $player -and $_.Final -ne "1" } | Group-Object Turn | ForEach-Object { $_.Group[-1] } | Sort-Object { [int]$_.Turn }) }
    $cityShare = { param($civs, $player)
        $all = ($civs | ForEach-Object { [double]$_.Cities } | Measure-Object -Sum).Sum
        $mine = @($civs | Where-Object { $_.Player -eq $player })
        if ($all -le 0 -or $mine.Count -eq 0) { 0.0 } else { 100.0 * [double]$mine[0].Cities / $all } }
    $rowsAt = { param($gid, $turn) @($byGame[$gid] | Where-Object { [int]$_.Turn -eq $turn -and $_.Final -ne "1" } | Group-Object Player | ForEach-Object { $_.Group[-1] }) }

    $bully = @(Get-BullyStats)
    if ($bully.Count -gt 0) {
        Write-Output ""
        Write-Output "Bully test: the aggressor against the rest. With c = the defenders, without = all on B (flipped game)."
        Write-Output ("  {0,-18} {1,-4} {2,-14} {3,9} {4,9} {5,9} {6,10} {7,10} {8,-22} {9}" -f "Game", "c?", "Aggressor", "Cities100", "CitiesEnd", "Captured", "AtWarWith", "Coalition", "Tall civ: wars on it/friends/pacts", "Joint wars/sanctions vs it")
        foreach ($b in $bully) {
            $s100 = if ($b.Share100 -ne $null) { "{0:N1}%" -f $b.Share100 } else { "-" }
            $coal = if ($b.CoalitionTurns -eq $null) { "-" } elseif ($b.CoalitionTurns -lt 0) { "never" } else { "+{0} turns" -f $b.CoalitionTurns }
            $withC = if ($b.Flipped) { "no" } else { "yes" }
            $prop = if ($rows[0].PSObject.Properties.Name -contains "CoopWarAgreedVsAggressor") { "{0}/{1}" -f $b.CoopVsAgg, $b.SanctionsVsAgg } else { "-" }
            Write-Output ("  {0,-18} {1,-4} {2,-14} {3,9} {4,8:N1}% {5,9} {6,10} {7,10} {8,-22} {9}" -f $b.GameId, $withC, $b.Aggressor, $s100, $b.ShareEnd, $b.Captured, $b.AtWar, $coal, $b.TallText, $prop)
        }
        # pairs: the aggressor's final share of all cities with c defenders minus without (negative = the candidate held better)
        $diffs = @(foreach ($p in ($bully | Group-Object BaseId | Where-Object { $_.Count -eq 2 })) {
            $gc = @($p.Group | Where-Object { -not $_.Flipped })[0]; $gb = @($p.Group | Where-Object { $_.Flipped })[0]
            if ($gc -and $gb) { $gc.ShareEnd - $gb.ShareEnd } })
        if ($diffs.Count -ge 2) {
            $m = ($diffs | Measure-Object -Average).Average
            $sd = [Math]::Sqrt((($diffs | ForEach-Object { ($_ - $m) * ($_ - $m) }) | Measure-Object -Sum).Sum / ($diffs.Count - 1))
            Write-Output ("  Pairs: the aggressor's share of all cities with c defenders minus without: {0:+0.0;-0.0;0.0} points +/- {1:N1} over {2} pairs (negative = c held better)" -f $m, ($sd / [Math]::Sqrt($diffs.Count)), $diffs.Count)
        }
    }

    $builders = @($roleGames | Where-Object { $_.Civs[0].Mode -eq "builders" })
    if ($builders.Count -gt 0) {
        Write-Output ""
        Write-Output "Builders test: pressure on the two builders (tall, no wars of their own) and the world around them."
        Write-Output ("  {0,-18} {1,-4} {2,-26} {3,-26} {4,9} {5,9} {6,9}" -f "Game", "c?", "Builder 1: wars on/lost/deals", "Builder 2: wars on/lost/deals", "AI wars", "Captures", "TopTechs")
        $pressure = @{}
        foreach ($g in $builders) {
            $bs = @($g.Civs | Where-Object { $_.Role -eq "builder" })
            $cells = foreach ($b in $bs) { "{0} {1}/{2}/{3}" -f ($b.Civ -replace 'CIVILIZATION_', ''), (& $num $b "WarsOnUs"), (& $num $b "CitiesLost"), (& $num $b "Deals") }
            while (@($cells).Count -lt 2) { $cells = @($cells) + "-" }
            $others = @($g.Civs | Where-Object { $_.Role -ne "builder" })
            $aiWars = ($others | ForEach-Object { & $num $_ "WarsDeclared" } | Measure-Object -Sum).Sum
            $caps = ($g.Civs | ForEach-Object { & $num $_ "CitiesCaptured" } | Measure-Object -Sum).Sum
            $topTech = ($others | ForEach-Object { [double]$_.Techs } | Measure-Object -Maximum).Maximum
            $pressure[$g.GameId] = ($bs | ForEach-Object { & $num $_ "WarsOnUs" } | Measure-Object -Sum).Sum
            $withC = if ($g.Flipped) { "no" } else { "yes" }
            Write-Output ("  {0,-18} {1,-4} {2,-26} {3,-26} {4,9} {5,9} {6,9}" -f $g.GameId, $withC, @($cells)[0], @($cells)[1], $aiWars, $caps, $topTech)
        }
    }

    # Diplomacy per AI civ per 10 turns, by group, and the banned behaviours (target 0)
    Write-Output ""
    Write-Output "Diplomacy and war, average per civ (counts per 10 turns; Friends, Pacts and Denouncing at the last logged turn):"
    Write-Output ("  {0,-5} {1,8} {2,8} {3,9} {4,9} {5,8} {6,7} {7,11} {8,12} {9,12}" -f "Group", "Deals", "WarsDecl", "Captures", "Friends", "Pacts", "Denounc", "Influential", "StolenCivil", "WonderChops")
    foreach ($grp in "new", "cp") {
        $cs = @(@($games) + @($roleGames) | ForEach-Object { $g = $_; $_.Civs | Where-Object { $_.Group -eq $grp } | ForEach-Object { [pscustomobject]@{ C = $_; T = [Math]::Max(1, $g.Turn) } } })
        if ($cs.Count -eq 0) { continue }
        $rate = { param($col) ($cs | ForEach-Object { 10.0 * (& $num $_.C $col) / $_.T } | Measure-Object -Average).Average }
        $avg = { param($col) ($cs | ForEach-Object { & $num $_.C $col } | Measure-Object -Average).Average }
        $sum = { param($col) ($cs | ForEach-Object { & $num $_.C $col } | Measure-Object -Sum).Sum }
        Write-Output ("  {0,-5} {1,8:N2} {2,8:N2} {3,9:N2} {4,9:N1} {5,8:N1} {6,7:N1} {7,11:N1} {8,12} {9,12}" -f $grp, (& $rate "Deals"), (& $rate "WarsDeclared"), (& $rate "CitiesCaptured"), (& $avg "Friends"), (& $avg "Pacts"), (& $avg "Denouncing"), (& $avg "Influential"), (& $sum "WorkersStolen"), (& $sum "WonderChops"))
    }
    Write-Output "  (Deals count each side, so one deal between two civs adds 1 to each. StolenCivil and WonderChops are game totals: the banned behaviours, target 0.)"
    if ($rows[0].PSObject.Properties.Name -contains "CoopWarAsked") {
        Write-Output ("  {0,-5} {1,14} {2,15} {3,18} {4,17}" -f "Group", "JointWarAsked", "JointWarAgreed", "SanctionsProposed", "SanctionsPassed")
        foreach ($grp in "new", "cp") {
            $cs = @(@($games) + @($roleGames) | ForEach-Object { $g = $_; $_.Civs | Where-Object { $_.Group -eq $grp } | ForEach-Object { [pscustomobject]@{ C = $_; T = [Math]::Max(1, $g.Turn) } } })
            if ($cs.Count -eq 0) { continue }
            $rate = { param($col) ($cs | ForEach-Object { 10.0 * (& $num $_.C $col) / $_.T } | Measure-Object -Average).Average }
            Write-Output ("  {0,-5} {1,14:N2} {2,15:N2} {3,18:N2} {4,17:N2}" -f $grp, (& $rate "CoopWarAsked"), (& $rate "CoopWarAgreed"), (& $rate "SanctionsProposed"), (& $rate "SanctionsPassed"))
        }
        Write-Output "  (per civ per 10 turns, counted for the civ that proposed)"
    }
}

# ---- Scoreboard row (lead job 11): the milestone measures for one results file ----
if ($Scoreboard) {
    $cols = $rows[0].PSObject.Properties.Name
    $numOf = { param($r, $col) if ($r -and $r.$col -ne $null -and $r.$col -ne "") { [double]$r.$col } else { 0.0 } }
    $strength = "-"
    if ($games.Count -gt 0) {
        $vals = @($games | ForEach-Object { [double]$_.NewStrength })
        $mean = ($vals | Measure-Object -Average).Average
        $strength = if ($vals.Count -ge 2) {
            $se = [Math]::Sqrt((($vals | ForEach-Object { ($_ - $mean) * ($_ - $mean) }) | Measure-Object -Sum).Sum / ($vals.Count - 1) / $vals.Count)
            "{0:N1}% +/- {1:N1}" -f $mean, $se
        } else { "{0:N1}%" -f $mean }
    }
    $aggShare = "-"; $perWar = "-"; $coalition = "-"
    $bs = @(Get-BullyStats)
    if ($bs.Count -gt 0) {
        $aggShare = "{0:N1}%" -f ($bs | Measure-Object ShareEnd -Average).Average
        $wars = ($bs | Measure-Object Wars -Sum).Sum
        $perWar = if ($wars -gt 0) { "{0:N2}" -f (($bs | Measure-Object Captured -Sum).Sum / $wars) } else { "no wars" }
        $speeds = @($bs | Where-Object { $_.CoalitionTurns -ne $null -and $_.CoalitionTurns -ge 0 } | ForEach-Object { $_.CoalitionTurns })
        $never = @($bs | Where-Object { $_.CoalitionTurns -eq -1 }).Count
        $speedText = if ($speeds.Count) { "{0:N0} turns" -f ($speeds | Measure-Object -Average).Average } else { "-" }
        if ($never) { $speedText += ", never in $never" }
        $coalition = "{0:N1}; {1}" -f ($bs | Measure-Object AtWar -Average).Average, $speedText
    }
    $allCivs = @(@($games) + @($roleGames) | ForEach-Object { $g = $_; $_.Civs | ForEach-Object { [pscustomobject]@{ C = $_; T = [Math]::Max(1, $g.Turn) } } })
    $nGames = $games.Count + $roleGames.Count
    $deals = if ($cols -contains "Deals" -and $allCivs.Count) { "{0:N2}" -f ($allCivs | ForEach-Object { 10.0 * (& $numOf $_.C "Deals") / $_.T } | Measure-Object -Average).Average } else { "-" }
    $banned = if ($cols -contains "WorkersStolen" -and $nGames) { "{0:N1} per game" -f ((($allCivs | ForEach-Object { (& $numOf $_.C "WorkersStolen") + (& $numOf $_.C "WonderChops") } | Measure-Object -Sum).Sum) / $nGames) } else { "-" }
    $secs = "-"
    if ($cols -contains "TurnSecs") {
        $t = @($rows | Where-Object { (& $numOf $_ "TurnSecs") -gt 0 } | Group-Object GameId, Turn | ForEach-Object { & $numOf $_.Group[0] "TurnSecs" })
        if ($t.Count) { $secs = "{0:N1}" -f ($t | Measure-Object -Average).Average }
    }
    Write-Output ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |" -f [IO.Path]::GetFileNameWithoutExtension($Csv), $nGames, $strength, $aggShare, $perWar, $coalition, $deals, $banned, $secs)
    return
}

if ($games.Count -eq 0 -and $roleGames.Count -gt 0) {
    Write-Output ("{0} bully/builders games (turn {1} or later)" -f $roleGames.Count, $MinTurn)
    Show-RoleTests
    return
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
$jsonTests = New-Object System.Collections.ArrayList     # for -Json
$jsonScreen = New-Object System.Collections.ArrayList
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
    Write-Output ("    {0} {1}: gain {2:+0.00;-0.00;0.00} points (c share {3:N2}%), spread of one result {4:N2}{5}" -f $n, $kind, $mean, (50 + $mean), $sd, $extra)
    if ($pairs.Count -ge 2) {
        # what pairing buys, and the split's own bias (lead job 6): the spread of single games, and the first games
        # against the flipped ones (in an A/A run, where c and b both run B, a difference is the c/b split's bias:
        # c gets the extra warmonger when a game has an odd number)
        $inPairs = @($pairs | ForEach-Object { $_.Group })
        $g1 = @($inPairs | Where-Object { -not $_.Flipped } | ForEach-Object { $_.NewStrength - 50 })
        $g2 = @($inPairs | Where-Object { $_.Flipped } | ForEach-Object { $_.NewStrength - 50 })
        $single = @($g1 + $g2)
        $ms = ($single | Measure-Object -Average).Average
        $sds = [Math]::Sqrt((($single | ForEach-Object { ($_ - $ms) * ($_ - $ms) }) | Measure-Object -Sum).Sum / ($single.Count - 1))
        $gain = if ($sd -gt 0) { ($sds * $sds) / ($sd * $sd) } else { 0 }
        Write-Output ("    single games: spread {0:N2}; each game played in a pair is worth {1:N1} unpaired games (an unpaired test would need that many times as many games)" -f $sds, ($gain / 2))
        Write-Output ("    first games {0:+0.00;-0.00;0.00}, second (flipped) games {1:+0.00;-0.00;0.00}: the difference is the split's bias, cancelled within each pair" -f ($g1 | Measure-Object -Average).Average, ($g2 | Measure-Object -Average).Average)
    }
    $jsonTest = [ordered]@{ config = $cfg.Name; kind = ($kind -replace ' \(unpaired\)', ''); results = $n; gamesLeftOut = $leftOver
        gain = [Math]::Round($mean, 3); share = [Math]::Round(50 + $mean, 3)
        spread = if ($n -ge 2) { [Math]::Round($sd, 3) } else { $null } }
    foreach ($test in @(@{ Name = "gainer";    S0 = 0.0;            S1 = $Delta },
                        @{ Name = "no-worse";  S0 = -0.875 * $Delta; S1 = 0.125 * $Delta })) {
        $llr = Get-SprtLLR $x $test.S0 $test.S1
        $state = if ($null -eq $llr) { "needs 2+ results" }
            elseif ($n -lt 5) { "too few to decide (5+ needed)" }
            elseif ($llr -ge $llrBound) { "PASSED" }
            elseif ($llr -le -$llrBound) { "FAILED" }
            else { "running" }
        $key = if ($test.Name -eq "gainer") { "gainer" } else { "noWorse" }
        $jsonTest[$key + "LLR"] = if ($null -eq $llr) { $null } else { [Math]::Round($llr, 3) }
        $jsonTest[$key + "State"] = $state
        $llrText = if ($null -eq $llr) { "   -  " } else { "{0,6:+0.00;-0.00;0.00}" -f $llr }
        Write-Output ("    {0,-9} H0 {1,5:+0.00;-0.00;0.00} H1 {2,5:+0.00;-0.00;0.00}  LLR {3}  {4}" -f $test.Name, $test.S0, $test.S1, $llrText, $state)
    }
    # Expected length (Wald): about 5.3 s^2/Delta^2 results when the true gain is at H0 or H1, 8.7 s^2/Delta^2 at worst
    $s = if ($Sigma -gt 0) { $Sigma } else { $sd }
    $jsonTest["expectedResults"] = if ($s -gt 0) { [Math]::Round(2 * 0.9 * $llrBound * $s * $s / ($Delta * $Delta), 1) } else { $null }
    $jsonTest["expectedResultsWorst"] = if ($s -gt 0) { [Math]::Round($llrBound * $llrBound * $s * $s / ($Delta * $Delta), 1) } else { $null }
    [void]$jsonTests.Add($jsonTest)
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
                Write-Output ("  {0,-14} {1,6:+0.00;-0.00;0.00} +/- {2,4:N2}  as group share {3,6:+0.00;-0.00;0.00}  chance it's really no better: {4,4:P0}" -f $cols[$i], $eff, $se, ($eff * $nCivs / 4), $pUp)
                [void]$jsonScreen.Add([ordered]@{ flag = $cols[$i]; effect = [Math]::Round($eff, 3); se = [Math]::Round($se, 3)
                    groupShare = [Math]::Round($eff * $nCivs / 4, 3); pNoBetter = [Math]::Round($pUp, 4); observations = $Y.Count; design = $design })
            }
            Write-Output "  Screening only ranks flags: confirm the promising ones with an SPRT on the flag alone."
        }
    }
}

Show-RoleTests

if ($Json) {
    # what the dashboard reads; the same numbers as the report above
    $r0 = if ($games.Count) { $games[0].Civs[0] } else { $rows[0] }   # a counted game's setup, not a stopped one's
    $has = { param($name) $r0.PSObject.Properties.Name -contains $name }
    $out = [ordered]@{
        file = [IO.Path]::GetFileName($Csv)
        setup = [ordered]@{ difficulty = if (& $has "Difficulty") { $r0.Difficulty } else { $null }
            map = if (& $has "Map") { $r0.Map } else { $null }; paired = (@($jsonTests | Where-Object { $_.kind -eq "pairs" }).Count -gt 0) }
        delta = $Delta; llrBound = [Math]::Round($llrBound, 3)
        games = @($games | ForEach-Object { [ordered]@{ gameId = $_.GameId; pair = $_.BaseId; flipped = [bool]$_.Flipped; turn = $_.Turn
            config = $_.Config; share = [Math]::Round($_.NewStrength, 3); shareNoMilitary = [Math]::Round($_.NewEconomy, 3) } })
        tests = @($jsonTests)
        screen = @($jsonScreen)
    }
    [IO.File]::WriteAllText($Json, ($out | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
}

Write-Output ""
Write-Output "A difference only means something once the chance above is small (under 5%) over many games."
