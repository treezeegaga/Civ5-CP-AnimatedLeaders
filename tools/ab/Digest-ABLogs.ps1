<#
.SYNOPSIS
    Boils the Civ V AI logs of the current (or last) test game down to a few lines per major civ.

.DESCRIPTION
    Needs LoggingEnabled = 1 and AILog = 1 in config.ini (test builds from fork commit 4cf291b on read them
    themselves). For each major civ: its A/B group and opening plan (from the results file), what its cities
    started building up to -UpToTurn (opening-book picks marked *), settlers ordered, found-city operations
    started / succeeded / aborted, turns its cities ran ENOUGH_SETTLERS while no found-city operation
    existed (a settler standing idle), and how its military operations ended over the whole game (by
    reason; HalfStrength is the abort that audit item 26 made stricter in B: below 2/3 of the army's
    required slots while gathering or moving), and a settler timeline up to -UpToTurn (Economy's request): each
    settler started by the opening book or the normal choice, with its city; each one bought with gold; each
    found-city operation's start, founding or abort; and the turns spent saving gold for a settler.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\ab\Digest-ABLogs.ps1 -UpToTurn 60
#>
param(
    [int]$UpToTurn = 60,
    [string]$MyGames = "$([Environment]::GetFolderPath('MyDocuments'))\My Games\Sid Meier's Civilization 5"
)

$logs = Join-Path $MyGames "Logs"

# The game keeps the logs open, so read them with sharing
function Read-Shared([string]$name) {
    $p = Join-Path $logs $name
    if (-not (Test-Path $p)) { return @() }
    $s = [IO.File]::Open($p, 'Open', 'Read', 'ReadWrite')
    $r = New-Object IO.StreamReader($s)
    $t = $r.ReadToEnd(); $r.Close()
    # Some logs write the civ as "The_Maya", others as "The Maya"; use the spaced form everywhere
    return ($t -split "`r?`n" | ForEach-Object {
        $p = $_ -split ', ', 3
        if ($p.Count -ge 2) { $p[1] = $p[1].Replace('_', ' '); $p -join ', ' } else { $_ }
    })
}
function Get-Turn([string]$line) { [int](($line -split ', ')[0]) }

# Groups and plans from the newest results file's newest game
$csv = Get-ChildItem $MyGames -Filter "AIABTest*.csv" | Sort-Object LastWriteTime | Select-Object -Last 1
$civs = @{}
if ($csv) {
    $rows = @(Import-Csv $csv.FullName)
    $game = $rows[-1].GameId
    $mine = @($rows | Where-Object { $_.GameId -eq $game })
    foreach ($r in ($mine | Group-Object Player | ForEach-Object { $_.Group[-1] })) {
        $civs[$r.Civ] = $r
    }
    "Game $game ($($csv.Name)), last logged turn $($mine[-1].Turn)"
}

$chosen = @(Read-Shared "CityStrategyAIProductionLog.csv" | Where-Object { $_ -match ', CHOSEN: ' })
$specLog = @(Read-Shared "CitySpecializationLog.csv")
$book = @($specLog | Where-Object { $_ -match 'OPENING BOOK - Started' })
# Economy's patch 0009 (logging only): "<turn>, <civ>, <city>, OPENING BOOK - Settler held (<reason>), size <n>, next <build>"
$held = @($specLog | Where-Object { $_ -match 'OPENING BOOK - Settler held \(' })
$allOps = @(Read-Shared "OperationalAILog.csv")
$ops = @($allOps | Where-Object { $_ -match ', OP_FOUND_CITY, ' })
# every other operation's end, for the military summary (lead job 9: is item 26's abort rule cutting attacks short?)
$milEnds = @($allOps | Where-Object { $_ -match 'Ended: ' -and $_ -notmatch ', OP_FOUND_CITY, ' -and $_ -notmatch 'SETTLE|FOUND_CITY' })
$strat = @(Read-Shared "CityStrategyAILog.csv" | Where-Object { $_ -match 'AICITYSTRATEGY_ENOUGH_SETTLERS, 1' })
$expansion = @(Read-Shared "PlayerHomelandAILog.csv" | Where-Object { $_ -match 'EXPANSION SETTLER - ' })

# Major civs are the ones whose names appear in the opening-book or ops logs alongside a results row; fall back to
# every name in the found-city ops log
$names = @($ops + $book + $milEnds + $expansion | ForEach-Object { ($_ -split ', ')[1] } | Sort-Object -Unique)
$names += @($chosen | ForEach-Object { ($_ -split ', ')[1] } | Where-Object { $_ -eq (($_ -split ', ')[2]) } | Sort-Object -Unique)
$names = @($names | Sort-Object -Unique)

$out = foreach ($n in $names) {
    $row = $civs.Values | Where-Object { $_.Civ -match ("CIVILIZATION_" + $n.ToUpper().Replace(' ', '_')) } | Select-Object -First 1
    if (-not $row -and $civs.Count -gt 0) { continue }   # city-state
    $builds = @()
    $builds += $book | Where-Object { $_ -match "^\d+, $n, " } | ForEach-Object { $c = $_ -split ', '; [pscustomobject]@{ T = [int]$c[0]; S = ($c[3] -replace 'OPENING BOOK - Started ', '') + '*'; City = $c[2] } }
    $builds += $chosen | Where-Object { $_ -match "^\d+, $n, " } | ForEach-Object { $c = $_ -split ', '; [pscustomobject]@{ T = [int]$c[0]; S = $c[5]; City = $c[2] } }
    # the capital is the city of the first build; builds elsewhere carry their city's name (for Economy: a settler
    # replaced by a wonder in the capital, and the capital's queue against new cities')
    $capital = @($builds | Sort-Object T | Select-Object -First 1 | ForEach-Object { $_.City })
    $early = @($builds | Where-Object { $_.T -le $UpToTurn } | Sort-Object T | ForEach-Object {
        if ($capital.Count -and $_.City -ne $capital[0]) { "T$($_.T) $($_.S) ($($_.City))" } else { "T$($_.T) $($_.S)" } })
    $settlers = @($builds | Where-Object { $_.S -match '^Settler' } | Sort-Object T | ForEach-Object { $_.T })

    $mineOps = @($ops | Where-Object { $_ -match "^\d+, $n, " })
    $started = @($mineOps | Where-Object { $_ -match 'found target for settler' } | ForEach-Object { Get-Turn $_ })
    $success = @($mineOps | Where-Object { $_ -match 'City founded' } | ForEach-Object { Get-Turn $_ })
    $aborted = @($mineOps | Where-Object { $_ -match 'Ended: ' -and $_ -notmatch 'Ended: Success' } | ForEach-Object { "T$(Get-Turn $_) " + (($_ -split 'Ended: ')[1] -split ';')[0] })

    # idle settler: ENOUGH_SETTLERS on in a turn where no found-city op line exists for this civ
    $opTurns = @{}; foreach ($l in $mineOps) { $opTurns[(Get-Turn $l)] = $true }
    $idle = @($strat | Where-Object { $_ -match "^\d+, $n, " } | ForEach-Object { Get-Turn $_ } | Sort-Object -Unique | Where-Object { -not $opTurns[$_] })
    # settler timeline (lead, for Economy): started (book/AI, city), bought, op started, founded, op ended
    $tl = @()
    $tl += @($book | Where-Object { $_ -match "^\d+, $n, " -and $_ -match 'OPENING BOOK - Started Settler' } | ForEach-Object { $c = $_ -split ', '; [pscustomobject]@{ T = [int]$c[0]; S = "settler (book) in $($c[2])" } })
    $tl += @($chosen | Where-Object { $_ -match "^\d+, $n, " } | ForEach-Object { $c = $_ -split ', '; if ($c.Count -gt 5 -and $c[5] -match '^Settler') { [pscustomobject]@{ T = [int]$c[0]; S = "settler (AI) in $($c[2])" } } })
    $tl += @($expansion | Where-Object { $_ -match "^\d+, $n, " -and $_ -match 'Bought' } | ForEach-Object { [pscustomobject]@{ T = (Get-Turn $_); S = "BOUGHT " + (($_ -split 'Bought ')[1]) } })
    $tl += @($mineOps | Where-Object { $_ -match 'found target for settler' } | ForEach-Object { [pscustomobject]@{ T = (Get-Turn $_); S = "op started" } })
    $tl += @($mineOps | Where-Object { $_ -match 'City founded' } | ForEach-Object { [pscustomobject]@{ T = (Get-Turn $_); S = "FOUNDED" } })
    $tl += @($mineOps | Where-Object { $_ -match 'Ended: ' -and $_ -notmatch 'Ended: Success' } | ForEach-Object { [pscustomobject]@{ T = (Get-Turn $_); S = "op ended: " + (($_ -split 'Ended: ')[1] -split ';')[0] } })
    $timeline = @($tl | Where-Object { $_.T -le $UpToTurn } | Sort-Object T | ForEach-Object { "T$($_.T) $($_.S)" })
    $saving = @($expansion | Where-Object { $_ -match "^\d+, $n, " -and $_ -match 'Saving' } | ForEach-Object { Get-Turn $_ } | Where-Object { $_ -le $UpToTurn } | Sort-Object -Unique)
    # settler steps the opening book passed over, by reason and by what it built instead (Economy's request)
    $mineHeld = @($held | Where-Object { $_ -match "^\d+, $n, " } | Where-Object { (Get-Turn $_) -le $UpToTurn })
    $heldText = if ($mineHeld.Count) {
        $why = @($mineHeld | ForEach-Object { if ($_ -match 'Settler held \(([^)]*)\)') { $Matches[1] } } | Group-Object | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) $($_.Count)" })
        $next = @($mineHeld | ForEach-Object { if ($_ -match ', next (.*)$') { $Matches[1].Trim() } } | Group-Object | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) $($_.Count)" })
        $first = @($mineHeld | Select-Object -First 3 | ForEach-Object { $c = $_ -split ', '; "T$($c[0]) $($c[2]) $(($c[4..($c.Count - 1)]) -join ' ')" })
        "  book SETTLER HELD to T${UpToTurn}: $($mineHeld.Count) (" + ($why -join ', ') + ")   built instead: " + ($next -join ', ') + "   first: " + ($first -join ' | ')
    }
    $mil = @($milEnds | Where-Object { $_ -match "^\d+, $n, " } | ForEach-Object { (($_ -split 'Ended: ')[1] -split '[;,]')[0].Trim() } |
        Group-Object | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) $($_.Count)" })

    [pscustomobject]@{
        Group = if ($row) { $row.Group } else { '?' }
        Civ = $n
        Plan = if ($row) { $row.Book } else { '' }
        Cities = if ($row) { $row.Cities } else { '' }
        Text = @(
            "  builds to T${UpToTurn} (capital $(if ($capital.Count) { $capital[0] } else { '?' }); other cities named): " + ($early -join ' | ')
            "  settlers ordered T: " + ($settlers -join ',') + "   found-city ops started T: " + ($started -join ',') + "   cities founded T: " + ($success -join ',')
            $(if ($aborted.Count) { "  ops aborted: " + ($aborted -join ', ') })
            $heldText
            $(if ($idle.Count) { "  IDLE SETTLER turns: $($idle.Count) (first T$($idle[0]))" })
            $(if ($mil.Count) { "  military ops ended (whole game): " + ($mil -join ', ') })
            $(if ($timeline.Count) { "  settler timeline to T${UpToTurn}: " + ($timeline -join ' | ') })
            $(if ($saving.Count) { "  saving gold for a settler: $($saving.Count) turns (T$($saving[0])-T$($saving[-1]))" })
        ) | Where-Object { $_ }
    }
}
foreach ($o in ($out | Sort-Object Group, Civ)) {
    "{0,-4} {1,-12} {2,-9} cities {3}" -f $o.Group, $o.Civ, $o.Plan, $o.Cities
    $o.Text
}
