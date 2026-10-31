# Disassemble CivilizationV_DX11.exe at a VA, annotating string and code references.
#   powershell -File dis.ps1 -VA 0x652000 -Len 0x100
param([string]$VA, [string]$Len = "0x100", [string]$Exe = "CivilizationV_DX11.exe")

Add-Type -Path "$PSScriptRoot\iced\Iced.dll"
if (-not [IO.Path]::IsPathRooted($Exe)) { $Exe = Join-Path "C:\Program Files (x86)\Steam\steamapps\common\Sid Meier's Civilization V" $Exe }
$script:b = [IO.File]::ReadAllBytes($Exe)
# sections as (RVA, size, raw offset), read from the PE header
$pe = [BitConverter]::ToInt32($b, 0x3C); $nsec = [BitConverter]::ToUInt16($b, $pe + 6); $opt = [BitConverter]::ToUInt16($b, $pe + 20)
$secs = @()
for ($i = 0; $i -lt $nsec; $i++) { $o = $pe + 24 + $opt + 40 * $i; $secs += , @([BitConverter]::ToUInt32($b, $o + 12), [BitConverter]::ToUInt32($b, $o + 16), [BitConverter]::ToUInt32($b, $o + 20)) }

function VAToRaw([long]$va) {
    $rva = $va - 0x400000
    foreach ($s in $secs) { if ($rva -ge $s[0] -and $rva -lt $s[0] + $s[1]) { return $rva - $s[0] + $s[2] } }
    return -1
}
function StrAt([long]$va) {
    $r = VAToRaw $va
    if ($r -lt 0) { return $null }
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt 80; $i++) {
        $c = $script:b[$r + $i]
        if ($c -eq 0) { break }
        if ($c -lt 0x20 -or $c -gt 0x7E) { return $null }
        [void]$sb.Append([char]$c)
    }
    if ($sb.Length -ge 4) { return $sb.ToString() } else { return $null }
}

$start = [Convert]::ToInt64($VA, 16)
$n = [Convert]::ToInt32($Len, 16)
$raw = VAToRaw $start
$code = New-Object byte[] $n
[Array]::Copy($script:b, $raw, $code, 0, $n)
$reader = New-Object Iced.Intel.ByteArrayCodeReader -ArgumentList (, $code)
$dec = [Iced.Intel.Decoder]::Create(32, $reader)
$dec.IP = [uint64]$start
$fmt = New-Object Iced.Intel.MasmFormatter
$out = New-Object Iced.Intel.StringOutput
$end = [uint64]($start + $n)
while ($dec.IP -lt $end) {
    $ins = $dec.Decode()
    $fmt.Format([ref]$ins, $out)
    $txt = $out.ToStringAndReset()
    $note = ""
    foreach ($m in [regex]::Matches($txt, '\b([0-9A-F]{6,8})h\b')) {
        $v = [Convert]::ToInt64($m.Groups[1].Value, 16)
        $s = StrAt $v
        if ($s) { $note += "  ; `"$s`"" }
    }
    "{0:X8}  {1}{2}" -f $ins.IP, $txt, $note
}
