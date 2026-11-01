# Find references to VAs in an exe: absolute dwords anywhere (vtables, push imm, mov [x],imm) and
# E8/E9 rel32 calls/jumps in code.
#   powershell -File xref.ps1 -Targets 0x4D8BF0,0xA1DAE0
param([string]$Targets, [string]$Exe = "CivilizationV_DX11.exe")
$targetList = $Targets -split ','

if (-not [IO.Path]::IsPathRooted($Exe)) { $Exe = Join-Path "C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V" $Exe }
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
public static class XRef {
    public static List<string> Find(byte[] b, uint[][] secs, uint target) {
        var res = new List<string>();
        foreach (var s in secs) {
            uint rva = s[0], size = s[1], raw = s[2], exec = s[3];
            for (uint i = 0; i + 4 <= size && raw + i + 4 <= b.Length; i++) {
                uint va = 0x400000 + rva + i;
                uint d = BitConverter.ToUInt32(b, (int)(raw + i));
                if (d == target) res.Add(String.Format("{0:X8} abs", va));
                if (exec != 0 && i >= 1) {
                    byte op = b[raw + i - 1];
                    if ((op == 0xE8 || op == 0xE9) && unchecked(va + 4 + d) == target)
                        res.Add(String.Format("{0:X8} {1}", va - 1, op == 0xE8 ? "call" : "jmp"));
                }
            }
        }
        return res;
    }
}
"@
$b = [IO.File]::ReadAllBytes($Exe)
$pe = [BitConverter]::ToInt32($b, 0x3C); $nsec = [BitConverter]::ToUInt16($b, $pe + 6); $opt = [BitConverter]::ToUInt16($b, $pe + 20)
$secs = New-Object 'System.Collections.Generic.List[uint32[]]'
for ($i = 0; $i -lt $nsec; $i++) {
    $o = $pe + 24 + $opt + 40 * $i
    $chars = [BitConverter]::ToUInt32($b, $o + 36)
    $secs.Add([uint32[]]@([BitConverter]::ToUInt32($b, $o + 12), [BitConverter]::ToUInt32($b, $o + 16), [BitConverter]::ToUInt32($b, $o + 20), [uint32](($chars -band 0x20000000) -ne 0)))
}
foreach ($t in $targetList) {
    $v = [Convert]::ToUInt32($t.Replace("0x", ""), 16)
    "== refs to {0:X8}" -f $v
    [XRef]::Find($b, $secs.ToArray(), $v)
}
