# Packages a built mod pack into a one-click zip for other players:
#   CP-Animated-Leaders\Install.bat, Uninstall.bat, Readme.txt
#   CP-Animated-Leaders\files\install.ps1, PackVersion.txt, MP_CPLeaderheads\...
#
#   powershell -ExecutionPolicy Bypass -File CPModpack\Package-CPModpack.ps1
param(
    [string]$PackDir = "$env:TEMP\cpmodpack\out\MP_CPLeaderheads",
    [string]$OutZip = (Join-Path $PSScriptRoot "CP-Animated-Leaders.zip")
)

$ErrorActionPreference = "Stop"
$name = "CP-Animated-Leaders"
$stage = "$env:TEMP\cpmodpack\dist"
$root = Join-Path $stage $name

if (-not (Test-Path (Join-Path $PackDir "MP_CPLeaderheads.Civ5Pkg"))) { throw "No built pack at $PackDir. Run Build-CPModpack.ps1 first." }
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $root | Out-Null
Copy-Item -Recurse (Join-Path $PSScriptRoot "dist-template\*") $root
Copy-Item -Recurse $PackDir (Join-Path $root "files\MP_CPLeaderheads")

# Version code: hash over every file's relative path and contents, so identical packs match.
$sha = [Security.Cryptography.SHA256]::Create()
$packRoot = Join-Path $root "files\MP_CPLeaderheads"
$lines = Get-ChildItem $packRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
    $_.FullName.Substring($packRoot.Length + 1).ToLowerInvariant() + ":" + (Get-FileHash $_.FullName -Algorithm SHA256).Hash
}
$digest = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n")))
$code = (($digest[0..3] | ForEach-Object { $_.ToString("X2") }) -join "")
$version = "CP 5.4.8 + 3D leaders, build $code"
Set-Content -Path (Join-Path $root "files\PackVersion.txt") -Value $version -Encoding ascii

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
if (Test-Path $OutZip) { Remove-Item $OutZip -Force }
# Written entry by entry: .NET Framework's CreateFromDirectory stores backslash paths, which some
# unzip tools mishandle. Zip entries should use forward slashes.
$zip = [IO.Compression.ZipFile]::Open($OutZip, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in Get-ChildItem $stage -Recurse -File) {
        $entryName = $f.FullName.Substring($stage.Length + 1).Replace("\", "/")
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $entryName, [IO.Compression.CompressionLevel]::Optimal)
    }
}
finally { $zip.Dispose() }
Write-Output ("{0}: {1:N1} MB, {2}" -f $OutZip, ((Get-Item $OutZip).Length / 1MB), $version)
