# Resolve RVAs in a DLL to function+offset (and file:line) using its PDB via Windows' dbghelp.dll.
#   powershell -File sym.ps1 -Dll C:\path\CvGameCore_Expansion2.dll 0x40630e 0x408661
param([string]$Dll, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rvas)

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Sym
{
    [DllImport("dbghelp.dll", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern bool SymInitialize(IntPtr hProcess, string searchPath, bool invade);
    [DllImport("dbghelp.dll", SetLastError = true)]
    public static extern uint SymSetOptions(uint options);
    [DllImport("dbghelp.dll", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern ulong SymLoadModuleEx(IntPtr hProcess, IntPtr hFile, string imageName, string moduleName, ulong baseOfDll, uint dllSize, IntPtr data, uint flags);
    [DllImport("dbghelp.dll", SetLastError = true)]
    public static extern bool SymFromAddr(IntPtr hProcess, ulong address, out ulong displacement, IntPtr symbol);
    [DllImport("dbghelp.dll", SetLastError = true)]
    public static extern bool SymGetLineFromAddr64(IntPtr hProcess, ulong address, out uint displacement, ref IMAGEHLP_LINE64 line);

    [StructLayout(LayoutKind.Sequential)]
    public struct IMAGEHLP_LINE64 { public uint SizeOfStruct; public IntPtr Key; public uint LineNumber; public IntPtr FileName; public ulong Address; }

    public static string Resolve(IntPtr proc, ulong addr)
    {
        const int maxName = 1024;
        int size = 88 + maxName;   // SYMBOL_INFO
        IntPtr buf = Marshal.AllocHGlobal(size);
        try
        {
            for (int i = 0; i < size; i++) Marshal.WriteByte(buf, i, 0);
            Marshal.WriteInt32(buf, 0, 88);          // SizeOfStruct
            Marshal.WriteInt32(buf, 80, maxName);    // MaxNameLen
            ulong disp;
            string result = "?";
            if (SymFromAddr(proc, addr, out disp, buf))
                result = Marshal.PtrToStringAnsi(new IntPtr(buf.ToInt64() + 84)) + "+0x" + disp.ToString("X");
            var line = new IMAGEHLP_LINE64();
            line.SizeOfStruct = (uint)Marshal.SizeOf(typeof(IMAGEHLP_LINE64));
            uint ldisp;
            if (SymGetLineFromAddr64(proc, addr, out ldisp, ref line))
                result += "  (" + Marshal.PtrToStringAnsi(line.FileName) + ":" + line.LineNumber + ")";
            return result;
        }
        finally { Marshal.FreeHGlobal(buf); }
    }
}
'@

$proc = [IntPtr]1234
[void][Sym]::SymSetOptions(0x2 -bor 0x10)   # SYMOPT_UNDNAME | SYMOPT_LOAD_LINES
if (-not [Sym]::SymInitialize($proc, (Split-Path $Dll), $false)) { throw "SymInitialize failed" }
$base = [uint64]0x10000000
$mod = [Sym]::SymLoadModuleEx($proc, [IntPtr]::Zero, $Dll, $null, $base, 0, [IntPtr]::Zero, 0)
if ($mod -eq 0) { throw "SymLoadModuleEx failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
foreach ($r in $Rvas) {
    $rva = [Convert]::ToUInt64($r, 16)
    # Return addresses point after the call; look up the call instruction itself.
    "{0}: {1}" -f $r, [Sym]::Resolve($proc, $base + $rva - 1)
}
