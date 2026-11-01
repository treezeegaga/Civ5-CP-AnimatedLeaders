# Disassemble a named function from a DLL using its PDB.
param([string]$Dll, [string]$Name, [int]$Len = 0x140)
Add-Type -Path "C:\Users\itstr\Documents\Civ5-MP-Leaderheads\tools\re\iced\Iced.dll"
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class S2 {
    [DllImport("dbghelp.dll", CharSet = CharSet.Ansi)] public static extern bool SymInitialize(IntPtr p, string s, bool i);
    [DllImport("dbghelp.dll")] public static extern uint SymSetOptions(uint o);
    [DllImport("dbghelp.dll", CharSet = CharSet.Ansi)] public static extern ulong SymLoadModuleEx(IntPtr p, IntPtr f, string img, string mod, ulong b, uint sz, IntPtr d, uint fl);
    [DllImport("dbghelp.dll", CharSet = CharSet.Ansi)] public static extern bool SymFromName(IntPtr p, string name, IntPtr sym);
    public static ulong Addr(IntPtr p, string name) {
        IntPtr buf = Marshal.AllocHGlobal(88 + 1024);
        for (int i = 0; i < 88 + 1024; i++) Marshal.WriteByte(buf, i, 0);
        Marshal.WriteInt32(buf, 0, 88); Marshal.WriteInt32(buf, 80, 1024);
        ulong a = SymFromName(p, name, buf) ? (ulong)Marshal.ReadInt64(buf, 56) : 0;
        Marshal.FreeHGlobal(buf); return a;
    }
}
'@
$proc = [IntPtr]4321
[void][S2]::SymSetOptions(0x2)
[void][S2]::SymInitialize($proc, (Split-Path $Dll), $false)
$base = [uint64]0x10000000
[void][S2]::SymLoadModuleEx($proc, [IntPtr]::Zero, $Dll, $null, $base, 0, [IntPtr]::Zero, 0)
$a = [S2]::Addr($proc, $Name)
if ($a -eq 0) { throw "symbol not found" }
$rva = [uint32]($a - $base)
"{0} at RVA 0x{1:X}" -f $Name, $rva
$b = [IO.File]::ReadAllBytes($Dll)
$pe = [BitConverter]::ToInt32($b, 0x3C); $nsec = [BitConverter]::ToUInt16($b, $pe + 6); $opt = [BitConverter]::ToUInt16($b, $pe + 20)
$raw = -1
for ($i = 0; $i -lt $nsec; $i++) { $o = $pe + 24 + $opt + 40 * $i; $sr = [BitConverter]::ToUInt32($b, $o + 12); $ss = [BitConverter]::ToUInt32($b, $o + 8); if ($rva -ge $sr -and $rva -lt $sr + $ss) { $raw = $rva - $sr + [BitConverter]::ToUInt32($b, $o + 20) } }
$code = New-Object byte[] $Len; [Array]::Copy($b, $raw, $code, 0, $Len)
$dec = [Iced.Intel.Decoder]::Create(32, (New-Object Iced.Intel.ByteArrayCodeReader -ArgumentList (, $code)))
$dec.IP = [uint64]$rva
$fmt = New-Object Iced.Intel.MasmFormatter
$out = New-Object Iced.Intel.StringOutput
while ($dec.IP -lt $rva + $Len) {
    $ins = $dec.Decode(); $fmt.Format([ref]$ins, $out)
    "{0:X8}  {1}" -f $ins.IP, $out.ToStringAndReset()
    if ($ins.Mnemonic -eq [Iced.Intel.Mnemonic]::Ret) { break }
}
