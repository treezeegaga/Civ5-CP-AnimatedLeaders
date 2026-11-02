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
    required slots while gathering or moving).

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
$book = @(Read-Shared "CitySpecializationLog.csv" | Where-Object { $_ -match 'OPENING BOOK - Started' })
$allOps = @(Read-Shared "OperationalAILog.csv")
$ops = @($allOps | Where-Object { $_ -match ', OP_FOUND_CITY, ' })
# every other operation's end, for the military summary (lead job 9: is item 26's abort rule cutting attacks short?)
$milEnds = @($allOps | Where-Object { $_ -match 'Ended: ' -and $_ -notmatch ', OP_FOUND_CITY, ' -and $_ -notmatch 'SETTLE|FOUND_CITY' })
$strat = @(Read-Shared "CityStrategyAILog.csv" | Where-Object { $_ -match 'AICITYSTRATEGY_ENOUGH_SETTLERS, 1' })

# Major civs are the ones whose names appear in the opening-book or ops logs alongside a results row; fall back to
# every name in the found-city ops log
$names = @($ops + $book + $milEnds | ForEach-Object { ($_ -split ', ')[1] } | Sort-Object -Unique)
$names += @($chosen | ForEach-Object { ($_ -split ', ')[1] } | Where-Object { $_ -eq (($_ -split ', ')[2]) } | Sort-Object -Unique)
$names = @($names | Sort-Object -Unique)

$out = foreach ($n in $names) {
    $row = $civs.Values | Where-Object { $_.Civ -match ("CIVILIZATION_" + $n.ToUpper().Replace(' ', '_')) } | Select-Object -First 1
    if (-not $row -and $civs.Count -gt 0) { continue }   # city-state
    $builds = @()
    $builds += $book | Where-Object { $_ -match "^\d+, $n, " } | ForEach-Object { $c = $_ -split ', '; [pscustomobject]@{ T = [int]$c[0]; S = ($c[3] -replace 'OPENING BOOK - Started ', '') + '*' } }
    $builds += $chosen | Where-Object { $_ -match "^\d+, $n, " } | ForEach-Object { $c = $_ -split ', '; [pscustomobject]@{ T = [int]$c[0]; S = $c[5] } }
    $early = @($builds | Where-Object { $_.T -le $UpToTurn } | Sort-Object T | ForEach-Object { "T$($_.T) $($_.S)" })
    $settlers = @($builds | Where-Object { $_.S -match '^Settler' } | Sort-Object T | ForEach-Object { $_.T })

    $mineOps = @($ops | Where-Object { $_ -match "^\d+, $n, " })
    $started = @($mineOps | Where-Object { $_ -match 'found target for settler' } | ForEach-Object { Get-Turn $_ })
    $success = @($mineOps | Where-Object { $_ -match 'City founded' } | ForEach-Object { Get-Turn $_ })
    $aborted = @($mineOps | Where-Object { $_ -match 'Ended: ' -and $_ -notmatch 'Ended: Success' } | ForEach-Object { "T$(Get-Turn $_) " + (($_ -split 'Ended: ')[1] -split ';')[0] })

    # idle settler: ENOUGH_SETTLERS on in a turn where no found-city op line exists for this civ
    $opTurns = @{}; foreach ($l in $mineOps) { $opTurns[(Get-Turn $l)] = $true }
    $idle = @($strat | Where-Object { $_ -match "^\d+, $n, " } | ForEach-Object { Get-Turn $_ } | Sort-Object -Unique | Where-Object { -not $opTurns[$_] })
    $mil = @($milEnds | Where-Object { $_ -match "^\d+, $n, " } | ForEach-Object { (($_ -split 'Ended: ')[1] -split '[;,]')[0].Trim() } |
        Group-Object | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) $($_.Count)" })

    [pscustomobject]@{
        Group = if ($row) { $row.Group } else { '?' }
        Civ = $n
        Plan = if ($row) { $row.Book } else { '' }
        Cities = if ($row) { $row.Cities } else { '' }
        Text = @(
            "  builds to T${UpToTurn}: " + ($early -join ' | ')
            "  settlers ordered T: " + ($settlers -join ',') + "   found-city ops started T: " + ($started -join ',') + "   cities founded T: " + ($success -join ',')
            $(if ($aborted.Count) { "  ops aborted: " + ($aborted -join ', ') })
            $(if ($idle.Count) { "  IDLE SETTLER turns: $($idle.Count) (first T$($idle[0]))" })
            $(if ($mil.Count) { "  military ops ended (whole game): " + ($mil -join ', ') })
        ) | Where-Object { $_ }
    }
}
foreach ($o in ($out | Sort-Object Group, Civ)) {
    "{0,-4} {1,-12} {2,-9} cities {3}" -f $o.Group, $o.Civ, $o.Plan, $o.Cities
    $o.Text
}
