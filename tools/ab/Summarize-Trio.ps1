<#
.SYNOPSIS
    The trio test (the user's goal, 2026-11-04): in each game, is the strongest civ one of our three styles?

.DESCRIPTION
    Reads trio results (Mode = trio). At each game's last logged turn, a civ's strength is the mean of its shares of
    the game's techs, population, land, military and cities (the same measure as Summarize-ABTest.ps1). Our three are
    the civs with Role greedy, balanced or aggressor; the others played CP's AI. A game that ended in a victory
    (Final = 1, Winner set) counts its winner instead. The goal is one of our three on top in at least 90% of full
    games; at T150 the top strength spot stands in for it.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\ab\Summarize-Trio.ps1 -Csv tools\ab\results\AIABTest_trio@TREEDESKTOP.csv
#>
param(
    [Parameter(Mandatory = $true)][string[]]$Csv
)
$ErrorActionPreference = "Stop"
$files = @($Csv | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$rows = @($files | ForEach-Object { Import-Csv $_ })
$rows = @($rows | Where-Object { $_.Mode -eq 'trio' })
if ($rows.Count -eq 0) { Write-Output "No trio rows (Mode = trio) in $($files -join ', ')"; return }

$ours = @('greedy', 'balanced', 'aggressor')
$won = 0; $games = 0
$byStyle = @{ greedy = 0; balanced = 0; aggressor = 0; cp = 0 }
foreach ($g in ($rows | Group-Object GameId)) {
    $maxTurn = ($g.Group | ForEach-Object { [int]$_.Turn } | Measure-Object -Maximum).Maximum
    $last = @($g.Group | Where-Object { [int]$_.Turn -eq $maxTurn })
    $winner = $last | Where-Object { $_.Final -eq '1' -and $_.Winner -eq '1' } | Select-Object -First 1
    if (-not $winner) {
        $tot = @{}
        foreach ($k in 'Techs', 'Population', 'Land', 'Military', 'Cities') { $tot[$k] = ($last | ForEach-Object { [double]$_.$k } | Measure-Object -Sum).Sum }
        $best = $null; $bestScore = -1
        foreach ($r in $last) {
            $sum = 0.0
            foreach ($k in $tot.Keys) { if ($tot[$k] -gt 0) { $sum += [double]$r.$k / $tot[$k] } }
            $score = $sum / 5
            if ($score -gt $bestScore) { $bestScore = $score; $best = $r }
        }
        $winner = $best
        $how = "top strength {0:N1}% at T{1}" -f ($bestScore * 100), $maxTurn
    } else { $how = "won at T$maxTurn ($($winner.Victory))" }
    $games++
    $style = if ($ours -contains $winner.Role) { $winner.Role } else { 'cp' }
    $byStyle[$style]++
    if ($style -ne 'cp') { $won++ }
    "{0}  {1,-22} {2,-9} {3}" -f $g.Name, ($winner.Civ -replace '^CIVILIZATION_', ''), $style, $how
}
""
"Games: $games. One of our three on top: $won ({0:N0}%). Goal: 90%; if all six played alike: 50%." -f (100.0 * $won / [math]::Max(1, $games))
"By style: greedy $($byStyle.greedy), balanced $($byStyle.balanced), aggressive $($byStyle.aggressor), CP $($byStyle.cp)"
