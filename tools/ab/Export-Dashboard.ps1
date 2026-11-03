<#
Writes the data the test dashboard shows (the lead runs it at every check-in, then uploads the files):
  tests.json  one row per results file and flag configuration: the SPRT state (Summarize-ABTest.ps1's numbers)
  games.json  one row per game: the test group's strength share
  screen.json one row per screened flag: the screening regression's rank
status.json (the PC runner's queue, the sessions, blockers) is written by hand next to them.
#>
param(
    [string]$Results = (Join-Path $PSScriptRoot "results"),
    [string]$Out = (Join-Path $PSScriptRoot "dashboard")
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$tmp = Join-Path ([IO.Path]::GetTempPath()) "abdash"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$tests = New-Object System.Collections.ArrayList
$games = New-Object System.Collections.ArrayList
$screen = New-Object System.Collections.ArrayList
# a run split over PCs has one file per PC (AIABTest_screen2.csv, AIABTest_screen2@PC2.csv): read them as one
foreach ($grp in (Get-ChildItem $Results -Filter "AIABTest*.csv" | Group-Object { $_.BaseName -replace '@.*$', '' })) {
    $build = $grp.Name -replace '^AIABTest_?', ''
    if (-not $build) { $build = "first" }
    $json = Join-Path $tmp "$build.json"
    Remove-Item $json -ErrorAction SilentlyContinue
    try { & (Join-Path $PSScriptRoot "Summarize-ABTest.ps1") -Csv (@($grp.Group | ForEach-Object { $_.FullName }) -join ",") -Json $json | Out-Null } catch { continue }
    if (-not (Test-Path $json)) { continue }
    $d = Get-Content $json -Raw | ConvertFrom-Json
    $setup = if ($d.setup.difficulty) {
        "{0}, {1}{2}" -f ([Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase(($d.setup.difficulty -replace '^HANDICAP_', '').ToLower())),
            ($d.setup.map -replace '\.lua$', '' -replace '^.*[\\/]', ''), $(if ($d.setup.paired) { ", pairs" } else { "" })
    } else { "Prince, old setup" }
    $current = [bool]($d.setup.difficulty -eq "HANDICAP_KING")
    foreach ($t in $d.tests) {
        # the flags group c ran, short: "13 flags: WidePlans, BoxedIn, BoxedInWar, ..." or "none (every civ on B)"
        $flags = if ($t.config -match 'c runs ([^;]*)') { $Matches[1].Trim() } else { $t.config }
        $list = @($flags -split '\+' | Where-Object { $_ })
        $label = if ($flags -eq "none") { "none (every civ on B)" } elseif ($list.Count -gt 3) { "$($list.Count) flags: " + (($list[0..2]) -join ", ") + ", ..." } else { $list -join ", " }
        if ($t.config -match 'screened (.+)$' -and $Matches[1] -ne "none") { $label += "; screening $(@($Matches[1] -split '\+').Count) flags" }
        [void]$tests.Add([ordered]@{ test = "$build | $($t.config)"; build = $build; config = $label; setup = $setup; current = $current
            kind = $t.kind; results = $t.results; share = $t.share; gain = $t.gain; spread = $t.spread
            gainerLLR = $t.gainerLLR; gainerState = $t.gainerState; noWorseLLR = $t.noWorseLLR; noWorseState = $t.noWorseState
            expectedResults = $t.expectedResults; expectedResultsWorst = $t.expectedResultsWorst })
    }
    foreach ($g in $d.games) {
        [void]$games.Add([ordered]@{ build = $build; gameId = $g.gameId; pair = $g.pair; flipped = $g.flipped; turn = $g.turn
            config = $g.config; share = $g.share; shareNoMilitary = $g.shareNoMilitary; current = $current })
    }
    foreach ($s in $d.screen) {
        [void]$screen.Add([ordered]@{ build = $build; flag = $s.flag; effect = $s.effect; se = $s.se; groupShare = $s.groupShare
            pNoBetter = $s.pNoBetter; observations = $s.observations })
    }
}
$enc = New-Object Text.UTF8Encoding($false)
# ConvertTo-Json writes a one-item array as an object: wrap every list under "rows"
foreach ($pair in @(@("tests", $tests), @("games", $games), @("screen", $screen))) {
    $text = ConvertTo-Json -InputObject ([ordered]@{ rows = @($pair[1]) }) -Depth 4
    [IO.File]::WriteAllText((Join-Path $Out "$($pair[0]).json"), $text, $enc)
}
Write-Output ("{0} tests, {1} games, {2} screened flags -> {3}" -f $tests.Count, $games.Count, $screen.Count, $Out)
