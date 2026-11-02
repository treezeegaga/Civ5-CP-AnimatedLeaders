# Builds a multiplayer mod pack (pseudo-DLC) from an installed Community Patch, the same way
# Gedemon's MP Modpacks Maker does, but offline:
#   Override\CIV5Units.xml         the whole gameplay database as CP left it (schema + every row)
#   Override\CIV5Units_Mongol.xml  text CP adds or changes, as <Replace> rows
#   Override\<base file>.xml       empty files that stop the base game database XML from loading
#   Mods\(1) Community Patch\...   CP's Lua, UI, art, audio and DLL
#   UI\InGame.lua                  CP's InGame.lua with its InGameUIAddins listed by name
#
# Needs the game cache to hold a database built with Community Patch active: enable CP in the
# Mods menu, click Next, then close the game without going back to the main menu.
#
#   powershell -ExecutionPolicy Bypass -File CPModpack\Build-CPModpack.ps1 [-Install]
param(
    [string]$CivDir = "C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V",
    [string]$MyGames = "$([Environment]::GetFolderPath('MyDocuments'))\My Games\Sid Meier's Civilization 5",
    [string]$BaselineLocDb = (Join-Path $PSScriptRoot "data\baseline\Localization-Merged.vanilla.db"),
    [string]$PackName = "MP_CPLeaderheads",
    [string]$OutRoot = "$env:TEMP\cpmodpack\out",
    [string]$GameDb = "",
    [string]$LocDb = "",
    [string]$Dll = "",   # gameplay DLL to ship; defaults to the one in CP's MODS folder
    [switch]$LeaderheadsOff,   # ship MP_LEADERHEADS = 0 (the 2D diplomacy screens, for comparison tests)
    [switch]$StockRules,   # ship CP's own Prince (by default Prince gives AIs and humans the same rules)
    [switch]$ABTest,   # ship AI_AB_TEST = 1: a test pack for AI-only games (see tools\ab\README.md); not for normal play
    [switch]$DryRun,   # allow a database built without CP, to test the export
    [switch]$Install
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Sqlite.ps1")

$cpDir = Join-Path $MyGames "MODS\(1) Community Patch"
$cache = Join-Path $MyGames "cache"
$snapshot = Join-Path $PSScriptRoot "data\cp-snapshot"

# Every game launch rewrites the cache, so build from a snapshot taken while the cache last held a
# full Community Patch database (CP's mod or this pack loaded).
if (-not $GameDb) {
    $cacheGameDb = Join-Path $cache "Civ5DebugDatabase.db"
    $r = @(Invoke-SqliteQuery $cacheGameDb "SELECT (SELECT count(*) FROM sqlite_master WHERE type='table') AS n, (SELECT count(*) FROM sqlite_master WHERE name='CustomModOptions') AS cmo")
    if ($r[0]["cmo"] -eq 1 -and $r[0]["n"] -gt 700) {
        New-Item -ItemType Directory -Force $snapshot | Out-Null
        Copy-Item $cacheGameDb (Join-Path $snapshot "Civ5DebugDatabase.db") -Force
        Copy-Item (Join-Path $cache "Localization-Merged.db") (Join-Path $snapshot "Localization-Merged.db") -Force
        Write-Output "== Snapshot taken from the cache ($($r[0]["n"]) tables)"
    }
    elseif (Test-Path (Join-Path $snapshot "Civ5DebugDatabase.db")) {
        Write-Output "== Cache doesn't hold a Community Patch database; using the snapshot from $((Get-Item (Join-Path $snapshot "Civ5DebugDatabase.db")).LastWriteTime)"
    }
    $GameDb = Join-Path $snapshot "Civ5DebugDatabase.db"
    if (-not $LocDb) { $LocDb = Join-Path $snapshot "Localization-Merged.db" }
}
$gameDb = $GameDb
$locDb = if ($LocDb) { $LocDb } else { Join-Path $cache "Localization-Merged.db" }
$out = Join-Path $OutRoot $PackName
$utf8 = New-Object Text.UTF8Encoding($false)

function Write-Step([string]$msg) { Write-Output "== $msg" }

function Escape-Xml([string]$s) {
    return $s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace('"', "&quot;")
}

function Get-Scalar([string]$db, [string]$sql) {
    $r = @(Invoke-SqliteQuery $db $sql)
    if ($r.Count -eq 0) { return $null }
    return $r[0][0]
}

# ---------------------------------------------------------------------------------------------
Write-Step "Checking the cached database was built with Community Patch"
if ((Get-Scalar $gameDb "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='CustomModOptions'") -ne 1) {
    if (-not $DryRun) {
        throw "The cached database has no CustomModOptions table, so it was not built with Community Patch. Enable CP in the Mods menu, click Next, then close the game without going back."
    }
    Write-Warning "Dry run: database was built without Community Patch"
}
else {
    $mpLeaderheads = Get-Scalar $gameDb "SELECT Value FROM CustomModOptions WHERE Name='MP_LEADERHEADS'"
    Write-Output "   MP_LEADERHEADS = $mpLeaderheads"
    if ($mpLeaderheads -ne 1) { Write-Warning "MP_LEADERHEADS is not 1 in the cached database; the pack will have 3D MP leaders turned off." }
}

if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force (Join-Path $out "Override"), (Join-Path $out "UI"), (Join-Path $out "Mods") | Out-Null

# ---------------------------------------------------------------------------------------------
# Even rules on Prince (-StockRules ships CP's own). In CP 5.4.8 Prince still favours the AI: 15%
# cheaper techs, 25% cheaper policies, 15 free happiness against a human's 9, less unhappiness, more
# unit supply, cheaper maintenance and upgrades, a bigger bonus against barbarians, and it rates
# humans 20% stronger than they are. The game core works out what an AI gets as its own row
# (HANDICAP_AI_DEFAULT) plus the game difficulty's "AI..." columns; a human gets their own row. So
# on Prince each "AIx" column is set to what makes an AI's total equal a human's, and each "Humanx"
# column (how the AI treats humans) to its "AIx" twin (how it treats other AIs), or 0 without one.
# The tactical AI also gets Deity's search budget: that's how hard it thinks, not a bonus.
$rowEdits = @{}       # "Table|Type or Name" -> ordered column -> value, applied while exporting
$dropPrinceRows = @{} # HandicapInfo_AI* tables whose Prince rows are left out
$isCpDb = (Get-Scalar $gameDb "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='CustomModOptions'") -eq 1
if (-not $StockRules -and -not $isCpDb) { Write-Warning "Dry run without Community Patch: leaving the difficulty rules alone" }
if (-not $StockRules -and $isCpDb) {
    Write-Step "Evening out the rules on Prince"
    $hi = @{}
    foreach ($r in @(Invoke-SqliteQuery $gameDb "SELECT * FROM HandicapInfos")) { $hi[[string]$r["Type"]] = $r }
    foreach ($t in "HANDICAP_PRINCE", "HANDICAP_AI_DEFAULT", "HANDICAP_DEITY") {
        if (-not $hi.ContainsKey($t)) { throw "HandicapInfos has no $t row" }
    }
    $prince = $hi["HANDICAP_PRINCE"]; $aiDefault = $hi["HANDICAP_AI_DEFAULT"]; $deity = $hi["HANDICAP_DEITY"]
    # Cost percentages multiply (an AI pays its own row's % times the difficulty's AI %); the rest add.
    $multiplied = @("ImprovementCostPercent", "BuildingCostPercent", "UnitCostPercent", "InflationPercent",
        "UnitUpgradePercent", "GrowthPercent", "ResearchPercent", "PolicyPercent", "ProphetPercent",
        "GreatPeoplePercent", "GoldenAgePercent", "CivilianPercent", "TrainPercent", "WorldTrainPercent",
        "ConstructPercent", "WorldConstructPercent", "CreatePercent", "WorldCreatePercent")
    $edits = [ordered]@{}
    foreach ($col in @($prince.Keys)) {
        if ($col -clike "AI*" -or $col -clike "Human*" -or -not $prince.Contains("AI$col")) { continue }
        $p = [long]$prince[$col]; $a = [long]$aiDefault[$col]
        if ($multiplied -contains $col) {
            if ($a -eq 0) { throw "HANDICAP_AI_DEFAULT has $col = 0, so AI costs can't be matched to a human's" }
            if ($a -ne 100) { Write-Warning "HANDICAP_AI_DEFAULT has $col = $a (expected 100)" }
            $v = [long][Math]::Round(100.0 * $p / $a)
        }
        else {
            if ($a -ne 0) { Write-Warning "HANDICAP_AI_DEFAULT has $col = $a (expected 0)" }
            $v = $p - $a
        }
        if ([long]$prince["AI$col"] -ne $v) { $edits["AI$col"] = $v }
    }
    foreach ($col in @($prince.Keys)) {
        if ($col -cnotlike "Human*") { continue }
        $twin = "AI" + $col.Substring(5)
        $v = if ($prince.Contains($twin)) { [long]$prince[$twin] } else { 0 }
        if ([long]$prince[$col] -ne $v) { $edits[$col] = $v }
    }
    foreach ($col in "TacticalSimMaxCompletedPositions", "TacticalSimMaxBranches", "TacticalSimMaxChoicesPerUnit") {
        if ([long]$prince[$col] -ne [long]$deity[$col]) { $edits[$col] = [long]$deity[$col] }
    }
    $rowEdits["HandicapInfos|HANDICAP_PRINCE"] = $edits
    foreach ($k in $edits.Keys) { Write-Output ("   Prince {0}: {1} -> {2}" -f $k, $prince[$k], $edits[$k]) }

    # Per-difficulty lists: the HandicapInfo_AI* ones go to AIs only (AI free techs, VP's AI yield
    # bonuses), so Prince gets none. The others go to a player by their own row; AIs use
    # HANDICAP_AI_DEFAULT's, which should match Prince's.
    $childTables = @(Invoke-SqliteQuery $gameDb "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'HandicapInfo\_%' ESCAPE '\' ORDER BY name" | ForEach-Object { $_["name"] })
    foreach ($tn in $childTables) {
        $cols = @(Invoke-SqliteQuery $gameDb "PRAGMA table_info('$tn')" | ForEach-Object { $_["name"] })
        if ($cols -notcontains "HandicapType") { continue }
        if ($tn -clike "HandicapInfo_AI*") {
            $n = Get-Scalar $gameDb "SELECT count(*) FROM '$tn' WHERE HandicapType='HANDICAP_PRINCE'"
            if ($n -gt 0) { $dropPrinceRows[$tn] = $true; Write-Output "   Leaving out $n Prince rows of $tn" }
            continue
        }
        $listCols = @($cols | Where-Object { $_ -ne "HandicapType" })
        if ($listCols.Count -eq 0) { continue }
        $sel = ($listCols | ForEach-Object { "COALESCE(`"$_`", '')" }) -join " || '|' || "
        $rowsOf = { param($h) @(Invoke-SqliteQuery $gameDb "SELECT $sel AS k FROM '$tn' WHERE HandicapType='$h' ORDER BY k" | ForEach-Object { [string]$_["k"] }) -join ";" }
        $pr = & $rowsOf "HANDICAP_PRINCE"; $ai = & $rowsOf "HANDICAP_AI_DEFAULT"
        if ($pr -ne $ai) { Write-Warning "$tn differs between HANDICAP_PRINCE ($pr) and HANDICAP_AI_DEFAULT ($ai): humans and AIs get different lists" }
    }

    # The AI treats humans the same as other AIs where CP otherwise makes exceptions.
    $rowEdits["CustomModOptions|HUMAN_USES_AI_MECHANICS"] = [ordered]@{ Value = 1 }
    Write-Output "   HUMAN_USES_AI_MECHANICS = 1"
}
$appliedEdits = @{}

# ---------------------------------------------------------------------------------------------
Write-Step "Exporting the gameplay database"
# Some tables exist before any XML loads, and redefining one makes the XML loader abandon the whole
# file. Same lists as CP's own Modpack Maker (ModpackMaker.lua): rewrite the rows of these without a
# <Table> definition...
$coreTables = @{}
foreach ($n in "ArtDefine_LandmarkTypes", "ArtDefine_Landmarks", "ArtDefine_StrategicView", "ArtDefine_UnitInfoMemberInfos",
    "ArtDefine_UnitInfos", "ArtDefine_UnitMemberCombatWeapons", "ArtDefine_UnitMemberCombats", "ArtDefine_UnitMemberInfos",
    "Audio_2DSounds", "Audio_3DSounds", "Audio_ScriptTypes", "Audio_SoundLoadTypes", "Audio_SoundScapeElementScripts",
    "Audio_SoundScapeElements", "Audio_SoundScapes", "Audio_SoundTypes", "Audio_Sounds", "Audio_SpeakerChannels",
    "Map_Folders", "Map_Sizes", "Maps") { $coreTables[$n] = $true }
# ...and leave these, which the engine fills in itself, alone.
$engineTables = @("ApplicationInfo", "DownloadableContent", "MapScriptOptionPossibleValues", "MapScriptOptions",
    "MapScriptRequiredDLC", "MapScripts", "ScannedFiles")
$tables = @(Invoke-SqliteQuery $gameDb "SELECT name, sql FROM sqlite_master WHERE type='table' ORDER BY rowid") |
    Where-Object { $_["name"] -notlike "sqlite_*" -and $engineTables -notcontains $_["name"] }
# The loader abandons the rest of the file at the first failure, so write the core tables (rows
# only) last: a problem there can't take the gameplay tables down with it.
$tables = @($tables | Where-Object { -not $coreTables.ContainsKey($_["name"]) }) + @($tables | Where-Object { $coreTables.ContainsKey($_["name"]) })

$sb = New-Object Text.StringBuilder (16MB)
[void]$sb.Append("<?xml version=`"1.0`" encoding=`"utf-8`"?>`r`n<!-- Generated by Build-CPModpack.ps1 from the Community Patch game database -->`r`n<GameData>`r`n")
$rowCount = 0
foreach ($t in $tables) {
    $name = $t["name"]
    $createSql = [string]$t["sql"]
    $cols = @(Invoke-SqliteQuery $gameDb "PRAGMA table_info('$name')")
    $fks = @(Invoke-SqliteQuery $gameDb "PRAGMA foreign_key_list('$name')")

    # Single-column UNIQUE constraints come back as automatic unique indexes.
    $uniqueCols = @{}
    foreach ($ix in @(Invoke-SqliteQuery $gameDb "PRAGMA index_list('$name')")) {
        if ($ix["unique"] -eq 1 -and $ix["origin"] -eq "u") {
            $ixCols = @(Invoke-SqliteQuery $gameDb "PRAGMA index_info('$($ix["name"])')")
            if ($ixCols.Count -eq 1) { $uniqueCols[$ixCols[0]["name"]] = $true }
        }
    }

    $isCore = $coreTables.ContainsKey($name)
    if (-not $isCore) { [void]$sb.Append("`t<Table name=`"$name`">`r`n") }
    $types = @{}
    foreach ($c in $cols) {
        $cn = $c["name"]
        $type = ([string]$c["type"]).ToLower()
        if ($type -eq "") { $type = "text" }
        $types[$cn] = $type
        $attrs = "name=`"$cn`" type=`"$type`""
        if ($c["pk"] -gt 0) {
            $attrs += " primarykey=`"true`""
            if ($createSql -match "(?i)['`"]?$([regex]::Escape($cn))['`"]?\s+integer\s+primary\s+key\s+autoincrement") { $attrs += " autoincrement=`"true`"" }
        }
        if ($c["notnull"] -eq 1) { $attrs += " notnull=`"true`"" }
        if ($uniqueCols.ContainsKey($cn)) { $attrs += " unique=`"true`"" }
        if ($null -ne $c["dflt_value"]) {
            $d = [string]$c["dflt_value"]
            if ($d.Length -ge 2 -and (($d[0] -eq "'" -and $d[-1] -eq "'") -or ($d[0] -eq '"' -and $d[-1] -eq '"'))) { $d = $d.Substring(1, $d.Length - 2) }
            $attrs += " default=`"$(Escape-Xml $d)`""
        }
        $fk = $fks | Where-Object { $_["from"] -eq $cn } | Select-Object -First 1
        if ($fk) { $attrs += " reference=`"$($fk["table"])($($fk["to"]))`"" }
        if (-not $isCore) { [void]$sb.Append("`t`t<Column $attrs/>`r`n") }
    }
    if (-not $isCore) { [void]$sb.Append("`t</Table>`r`n") }
    [void]$sb.Append("`t<$name>`r`n`t`t<Delete/>`r`n")

    foreach ($row in @(Invoke-SqliteQuery $gameDb "SELECT * FROM '$name' ORDER BY rowid")) {
        if ($dropPrinceRows.ContainsKey($name) -and $row["HandicapType"] -eq "HANDICAP_PRINCE") { continue }
        $editKey = if ($row.Contains("Type")) { "$name|$($row["Type"])" } elseif ($row.Contains("Name")) { "$name|$($row["Name"])" } else { $null }
        if ($editKey -and $rowEdits.ContainsKey($editKey)) {
            foreach ($c in $rowEdits[$editKey].Keys) {
                if (-not $row.Contains($c)) { throw "$name has no column $c" }
                $row[$c] = $rowEdits[$editKey][$c]
            }
            $appliedEdits[$editKey] = $true
        }
        [void]$sb.Append("`t`t<Row>")
        foreach ($cn in $row.Keys) {
            $v = $row[$cn]
            if ($null -eq $v) { continue }
            if ($types[$cn] -eq "boolean" -and ($v -is [long])) { $s = if ($v -ne 0) { "true" } else { "false" } }
            elseif ($v -is [double]) { $s = $v.ToString("R", [Globalization.CultureInfo]::InvariantCulture) }
            else { $s = Escape-Xml ([string]$v) }
            [void]$sb.Append("<$cn>$s</$cn>")
        }
        [void]$sb.Append("</Row>`r`n")
        $rowCount++
    }
    [void]$sb.Append("`t</$name>`r`n")
}
[void]$sb.Append("</GameData>`r`n")
foreach ($k in $rowEdits.Keys) { if (-not $appliedEdits.ContainsKey($k)) { throw "No row for $k in the database" } }
# The snapshot can come from a test run with an option switched off; the pack decides these here.
$dbXml = $sb.ToString()
function Set-ModOption([string]$name, [int]$value, [int]$class) {
    $optionRow = [regex]"<Name>$name</Name><Value>-?\d+</Value>"
    if ($optionRow.IsMatch($script:dbXml)) {
        $script:dbXml = $optionRow.Replace($script:dbXml, "<Name>$name</Name><Value>$value</Value>")
    }
    else {
        # Database built from a CP without this option in NewCustomModOptions.xml: add the row.
        $close = "`t</CustomModOptions>`r`n"
        if (-not $script:dbXml.Contains($close)) { throw "No CustomModOptions table in the database" }
        $script:dbXml = $script:dbXml.Replace($close, "`t`t<Row><Class>$class</Class><Name>$name</Name><Value>$value</Value></Row>`r`n$close")
    }
    Write-Output "   $name shipped as $value"
}
Set-ModOption "MP_LEADERHEADS" $(if ($LeaderheadsOff) { 0 } else { 1 }) 5
Set-ModOption "AI_AB_TEST" $(if ($ABTest) { 1 } else { 0 }) 4
[IO.File]::WriteAllText((Join-Path $out "Override\CIV5Units.xml"), $dbXml, $utf8)
Write-Output "   $($tables.Count) tables, $rowCount rows"

# ---------------------------------------------------------------------------------------------
Write-Step "Exporting text that Community Patch adds or changes"
$tableFor = @{}
foreach ($l in @(Invoke-SqliteQuery $locDb "SELECT Type, TableName FROM Languages")) { $tableFor[$l["Type"]] = $l["TableName"] }
# Languages only lists en_US; the others use upper-case table names (Language_DE_DE, Language_ZH_HANT_HK).
foreach ($tn in @(Invoke-SqliteQuery $locDb "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'Language\_%' ESCAPE '\'" | ForEach-Object { $_["name"] })) {
    foreach ($lang in @(Invoke-SqliteQuery $locDb "SELECT DISTINCT Language FROM LocalizedText" | ForEach-Object { $_["Language"] })) {
        if (-not $tableFor.ContainsKey($lang) -and $tn -eq "Language_$($lang.ToUpper())") { $tableFor[$lang] = $tn }
    }
}
$baseline = @{}
foreach ($r in @(Invoke-SqliteQuery $BaselineLocDb "SELECT Language, Tag, Text, Gender, Plurality FROM LocalizedText")) {
    $baseline["$($r['Language'])|$($r['Tag'])"] = "$($r['Text'])|$($r['Gender'])|$($r['Plurality'])"
}
$byLang = @{}
foreach ($r in @(Invoke-SqliteQuery $locDb "SELECT Language, Tag, Text, Gender, Plurality FROM LocalizedText ORDER BY Language, Tag")) {
    $key = "$($r['Language'])|$($r['Tag'])"
    if ($baseline.ContainsKey($key) -and $baseline[$key] -eq "$($r['Text'])|$($r['Gender'])|$($r['Plurality'])") { continue }
    if (-not $byLang.ContainsKey($r["Language"])) { $byLang[$r["Language"]] = New-Object Collections.ArrayList }
    [void]$byLang[$r["Language"]].Add($r)
}
$tb = New-Object Text.StringBuilder (4MB)
[void]$tb.Append("<?xml version=`"1.0`" encoding=`"utf-8`"?>`r`n<!-- Generated by Build-CPModpack.ps1: text Community Patch adds or changes -->`r`n<GameData>`r`n")
$textCount = 0
foreach ($lang in ($byLang.Keys | Sort-Object)) {
    $tableName = $tableFor[$lang]
    if (-not $tableName) { Write-Warning "No language table for $lang; skipping its text"; continue }
    [void]$tb.Append("`t<$tableName>`r`n")
    foreach ($r in $byLang[$lang]) {
        [void]$tb.Append("`t`t<Replace Tag=`"$(Escape-Xml $r['Tag'])`"><Text>$(Escape-Xml $r['Text'])</Text>")
        if ($null -ne $r["Gender"]) { [void]$tb.Append("<Gender>$(Escape-Xml $r['Gender'])</Gender>") }
        if ($null -ne $r["Plurality"]) { [void]$tb.Append("<Plurality>$(Escape-Xml $r['Plurality'])</Plurality>") }
        [void]$tb.Append("</Replace>`r`n")
        $textCount++
    }
    [void]$tb.Append("`t</$tableName>`r`n")
}
[void]$tb.Append("</GameData>`r`n")
[IO.File]::WriteAllText((Join-Path $out "Override\CIV5Units_Mongol.xml"), $tb.ToString(), $utf8)
Write-Output "   $textCount strings in $($byLang.Count) languages"

# ---------------------------------------------------------------------------------------------
Write-Step "Blanking the base game database files"
# Every XML under Assets whose root is <GameData>, except text-only files (kept, so all languages
# survive) and scenario files (not used in MP). Matched by name, so one empty file covers the base
# game, Expansion and Expansion2 copies.
$ownPacks = "MPLeaderScreens|MPLeaderProbe|MPModsButton|$([regex]::Escape($PackName))"
$blank = New-Object Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
foreach ($f in Get-ChildItem (Join-Path $CivDir "Assets") -Recurse -Filter *.xml -File) {
    if ($f.FullName -match "\\DLC\\($ownPacks)\\" -or $f.FullName -match "\\Scenarios\\") { continue }
    if ((Get-Content $f.FullName -TotalCount 40 | Out-String) -notmatch "<GameData") { continue }
    $raw = [IO.File]::ReadAllText($f.FullName)
    $isText = ($raw -match "<Language_") -and -not [regex]::IsMatch($raw, "<(?!Language_|Row|Update|Delete|Replace|Where|Set|Text|Gender|Plurality|GameData|/)[A-Za-z_]+[\s>]")
    if (-not $isText) { [void]$blank.Add($f.Name) }
}
$blankCount = 0
foreach ($n in $blank) {
    $p = Join-Path $out "Override\$n"
    if (-not (Test-Path $p)) { [IO.File]::WriteAllBytes($p, [byte[]]@()); $blankCount++ }
}
Write-Output "   $blankCount empty files"

# ---------------------------------------------------------------------------------------------
Write-Step "Copying Community Patch's UI, Lua, art, audio and DLL"
$cpOut = Join-Path $out "Mods\(1) Community Patch"
$copied = 0
foreach ($dir in "Assets", "Core Files", "LUA", "Kit") {
    foreach ($f in Get-ChildItem (Join-Path $cpDir $dir) -Recurse -File) {
        $rel = $f.FullName.Substring($cpDir.Length + 1)
        if ($rel -eq "Core Files\Overrides\InGame.lua") { continue }   # replaced by UI\InGame.lua below
        $dst = Join-Path $cpOut $rel
        New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
        Copy-Item $f.FullName $dst
        $copied++
    }
}
$dllSource = if ($Dll) { $Dll } else { Join-Path $cpDir "CvGameCore_Expansion2.dll" }
Copy-Item $dllSource (Join-Path $cpOut "CvGameCore_Expansion2.dll")
$copied++
Write-Output "   DLL from $dllSource"
Write-Output "   $copied files"

# ---------------------------------------------------------------------------------------------
Write-Step "Writing InGame.lua with CP's InGameUIAddins"
[xml]$modinfo = Get-Content (Get-ChildItem $cpDir -Filter *.modinfo | Select-Object -First 1).FullName -Raw
$addins = @($modinfo.Mod.EntryPoints.EntryPoint | Where-Object { $_.type -eq "InGameUIAddin" } | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.file) })
$inGame = [IO.File]::ReadAllText((Join-Path $cpDir "Core Files\Overrides\InGame.lua"))
$marker = '-- Modpacks will add "g_uiAddins[#g_uiAddins + 1] = fileName" lines below'
if (-not $inGame.Contains($marker)) { throw "CP's InGame.lua no longer has the modpack marker line" }
$lines = ($addins | ForEach-Object { "g_uiAddins[#g_uiAddins + 1] = `"$_`"" }) -join "`r`n"
$inGame = $inGame.Replace($marker, "$marker`r`n$lines")
# Only the map view runs the game core, so while a 3D leader scene (game state 12) is up in network
# MP, the DLL's Game.UpdateCoreInLeaderScene runs it instead, every frame.
$inGame += @"

-- CP with Animated Leaders: keep the game core running while a 3D leader scene is up in network
-- multiplayer. Game state 12 is the leader view.
if Game.UpdateCoreInLeaderScene and Game.IsNetworkMultiPlayer() then
	Events.LocalMachineAppUpdate.Add( function( tickCount, timeIncrement )
		if UI.GetCurrentGameState() == 12 then
			Game.UpdateCoreInLeaderScene( timeIncrement );
		end
	end );
end
"@.Replace("`r`n", "`n").Replace("`n", "`r`n")
[IO.File]::WriteAllText((Join-Path $out "UI\InGame.lua"), $inGame, $utf8)
Write-Output "   $($addins.Count) addins: $($addins -join ', ')"

# ---------------------------------------------------------------------------------------------
Write-Step "Writing the package file"
# Priority 300 puts the pack above Expansion2 (200), so its CvGameCore_Expansion2.dll, Lua and
# Override files win by name. SteamApp and Key are Brave New World's, as in CP's own Modpack Maker
# (CvGame::CreateMPMP): without them the pack can drop out of the DLC set when hosting MP, which
# swaps the DLL mid-setup and crashes reading the PreGame stream.
$pkg = @"
<?xml version="1.0" encoding="utf-8"?>
<Civ5Package>
	<GUID>{3C2A6E58-9F0B-4C61-A7D4-2B1E8F5C9D70}</GUID>
	<SteamApp>235580</SteamApp>
	<Version>1</Version>
	<Priority>300</Priority>
	<Key>bf6d34a0074b7ad4b1d1716475f7f7fe</Key>
	<PTags>
		<Tag>Version</Tag>
	</PTags>
	<Name>
		<Value language="en_US">CP with Animated Leaders</Value>
	</Name>
	<Description>
		<Value language="en_US">Community Patch 5.4.8 as a multiplayer mod pack, with 3D leader scenes for AI diplomacy in network MP.</Value>
	</Description>
	<UISkin name="Expansion2Primary" set="Expansion2" platform="Common">
		<GameplaySkin>
			<Directory>Mods</Directory>
			<Directory>UI</Directory>
		</GameplaySkin>
	</UISkin>
</Civ5Package>
"@
[IO.File]::WriteAllText((Join-Path $out "$PackName.Civ5Pkg"), $pkg, $utf8)

$size = (Get-ChildItem $out -Recurse -File | Measure-Object Length -Sum).Sum
Write-Output ("Built {0} ({1:N1} MB)" -f $out, ($size / 1MB))

if ($Install) {
    $dst = Join-Path $CivDir "Assets\DLC\$PackName"
    if (Get-Process -Name CivilizationV_DX11, CivilizationV, CivilizationV_Tablet -ErrorAction SilentlyContinue) { throw "Civ V is running. Close it before installing." }
    if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
    Copy-Item -Recurse $out $dst
    Write-Output "Installed to $dst"
}
