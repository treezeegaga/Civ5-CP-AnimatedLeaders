# For each VA, find the enclosing function (scan back to int3 padding) and list the strings it references.
#   powershell -File ctx.ps1 0x42024A 0x43F125 ...
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Sites)

$Exe = "C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V\CivilizationV_DX11.exe"
Add-Type -Path "$PSScriptRoot\iced\Iced.dll"
$b = [IO.File]::ReadAllBytes($Exe)
$secs = @(@(0x1000, 0x5D4D30, 0x400), @(0x5D6000, 0x1BD343, 0x5D5200), @(0x794000, 0x124400, 0x792600))
function VAToRaw([long]$va) { $rva = $va - 0x400000; foreach ($s in $secs) { if ($rva -ge $s[0] -and $rva -lt $s[0] + $s[1]) { return $rva - $s[0] + $s[2] } }; return -1 }
function StrAt([long]$va) {
    $r = VAToRaw $va; if ($r -lt 0) { return $null }
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt 60; $i++) { $c = $b[$r + $i]; if ($c -eq 0) { break }; if ($c -lt 0x20 -or $c -gt 0x7E) { return $null }; [void]$sb.Append([char]$c) }
    if ($sb.Length -ge 4) { return $sb.ToString() } else { return $null }
}
foreach ($site in $Sites) {
    $va = [Convert]::ToInt64($site, 16)
    $raw = VAToRaw $va
    $fs = $raw
    for ($k = $raw; $k -gt $raw - 0x3000; $k--) { if ($b[$k - 1] -eq 0xCC -and $b[$k - 2] -eq 0xCC -and $b[$k] -ne 0xCC) { $fs = $k; break } }
    $fva = $fs - 0x400 + 0x401000
    $n = [Math]::Min(0x1800, ($raw - $fs) + 0x400)
    $code = New-Object byte[] $n; [Array]::Copy($b, $fs, $code, 0, $n)
    $dec = [Iced.Intel.Decoder]::Create(32, (New-Object Iced.Intel.ByteArrayCodeReader -ArgumentList (, $code)))
    $dec.IP = [uint64]$fva
    $strs = New-Object System.Collections.Generic.List[string]
    $endIP = [uint64]($fva + $n)
    while ($dec.IP -lt $endIP) {
        $ins = $dec.Decode()
        if ($ins.Code -eq [Iced.Intel.Code]::Int3) { break }
        for ($o = 0; $o -lt $ins.OpCount; $o++) {
            $kind = $ins.GetOpKind($o)
            $v = 0
            if ($kind -eq [Iced.Intel.OpKind]::Immediate32 -or $kind -eq [Iced.Intel.OpKind]::Immediate8to32) { $v = $ins.Immediate32 }
            elseif ($kind -eq [Iced.Intel.OpKind]::Memory -and $ins.MemoryBase -eq [Iced.Intel.Register]::None) { $v = $ins.MemoryDisplacement32 }
            if ($v -gt 0x9D6000) { $s = StrAt $v; if ($s -and -not $strs.Contains($s)) { $strs.Add($s) } }
        }
    }
    "{0} (fn 0x{1:X}): {2}" -f $site, $fva, (($strs | Select-Object -First 6) -join ' | ')
}
