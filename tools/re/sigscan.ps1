# Build a wildcarded byte signature from a function in the DX11 exe and find it in other exes.
# Absolute addresses (imm/disp that look like image addresses) and rel32 branch targets are
# wildcarded, so the signature survives relinking.
#   powershell -File sigscan.ps1 -VA 0x51B1E0 -Len 0x60 -Targets CivilizationV.exe,CivilizationV_Tablet.exe
param([string]$VA, [string]$Len = "0x60", [string]$Targets = "CivilizationV_DX11.exe,CivilizationV.exe,CivilizationV_Tablet.exe", [switch]$Loose)
$targetList = $Targets -split ','

$civ = "C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V"
Add-Type -Path "$PSScriptRoot\iced\Iced.dll"

function Get-Sections([byte[]]$b) {
    $pe = [BitConverter]::ToInt32($b, 0x3C); $n = [BitConverter]::ToUInt16($b, $pe + 6); $opt = [BitConverter]::ToUInt16($b, $pe + 20)
    $base = [BitConverter]::ToUInt32($b, $pe + 24 + 28)
    $list = @()
    for ($i = 0; $i -lt $n; $i++) {
        $o = $pe + 24 + $opt + 40 * $i
        $list += [pscustomobject]@{ Name = [Text.Encoding]::ASCII.GetString($b, $o, 8).TrimEnd([char]0); VA = [BitConverter]::ToUInt32($b, $o + 12); VSize = [BitConverter]::ToUInt32($b, $o + 8); Raw = [BitConverter]::ToUInt32($b, $o + 20); RSize = [BitConverter]::ToUInt32($b, $o + 16) }
    }
    return @{ Base = $base; Secs = $list }
}

$src = [IO.File]::ReadAllBytes("$civ\CivilizationV_DX11.exe")
$si = Get-Sections $src
$text = $si.Secs | Where-Object Name -eq '.text'
$start = [Convert]::ToInt64($VA, 16); $n = [Convert]::ToInt32($Len, 16)
$raw = $start - $si.Base - $text.VA + $text.Raw
$code = New-Object byte[] $n; [Array]::Copy($src, $raw, $code, 0, $n)
$mask = New-Object bool[] $n
for ($i = 0; $i -lt $n; $i++) { $mask[$i] = $true }

$dec = [Iced.Intel.Decoder]::Create(32, (New-Object Iced.Intel.ByteArrayCodeReader -ArgumentList (, $code)))
$dec.IP = [uint64]$start
$end = [uint64]($start + $n)
while ($dec.IP -lt $end) {
    $ins = $dec.Decode()
    $off = [int]($ins.IP - $start)
    $offs = $dec.GetConstantOffsets([ref]$ins)
    $isRelBranch = $ins.OpCount -gt 0 -and $ins.GetOpKind(0) -eq [Iced.Intel.OpKind]::NearBranch32
    if ($isRelBranch) {
        # rel32 call/jmp/jcc: the last 4 bytes of the instruction are the displacement
        for ($j = $ins.Length - 4; $j -lt $ins.Length; $j++) { if ($off + $j -lt $n -and $ins.Length -ge 5) { $mask[$off + $j] = $false } }
    }
    elseif ($offs.HasImmediate -and $offs.ImmediateSize -eq 4) {
        $v = $ins.Immediate32
        if (($v -ge 0x400000 -and $v -lt 0x7000000) -or ($Loose -and $v -ge 0x100)) { for ($j = 0; $j -lt 4; $j++) { if ($off + $offs.ImmediateOffset + $j -lt $n) { $mask[$off + $offs.ImmediateOffset + $j] = $false } } }
    }
    if ($offs.HasDisplacement -and $offs.DisplacementSize -eq 4) {
        $isBranch = $ins.FlowControl -in @([Iced.Intel.FlowControl]::Call, [Iced.Intel.FlowControl]::UnconditionalBranch, [Iced.Intel.FlowControl]::ConditionalBranch)
        $v = $ins.MemoryDisplacement32
        if ($isBranch -or $Loose -or ($v -ge 0x400000 -and $v -lt 0x7000000)) { for ($j = 0; $j -lt 4; $j++) { if ($off + $offs.DisplacementOffset + $j -lt $n) { $mask[$off + $offs.DisplacementOffset + $j] = $false } } }
    }
}
$sig = ($code | ForEach-Object -Begin { $i = 0 } -Process { if ($mask[$i]) { '{0:X2}' -f $_ } else { '??' }; $i++ }) -join ' '
"sig: $sig"

foreach ($t in $targetList) {
    $b = [IO.File]::ReadAllBytes("$civ\$t")
    $ti = Get-Sections $b
    $tt = $ti.Secs | Where-Object Name -eq '.text'
    $hits = @()
    $first = $code[0]
    for ($k = $tt.Raw; $k -lt $tt.Raw + $tt.RSize - $n; $k++) {
        if ($b[$k] -ne $first) { continue }
        $ok = $true
        for ($j = 1; $j -lt $n; $j++) { if ($mask[$j] -and $b[$k + $j] -ne $code[$j]) { $ok = $false; break } }
        if ($ok) { $hits += ('0x{0:X}' -f ($k - $tt.Raw + $tt.VA + $ti.Base)) }
    }
    "{0}: {1} hit(s) {2}" -f $t, $hits.Count, ($hits -join ' ')
}
