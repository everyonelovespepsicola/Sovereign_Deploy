<#
.SYNOPSIS
    Standalone script to test xorriso.exe ISO generation rapidly.
#>

$ScriptDir = $PSScriptRoot
$XorrisoExe = Join-Path $ScriptDir "xorriso.exe"
$IsoRoot = "C:\Sovereign_ISORoot"
$OutputPath = "C:\Sovereign_Win11.iso"

if (-not (Test-Path $XorrisoExe)) {
    Write-Host "[!] xorriso.exe not found in $ScriptDir!" -ForegroundColor Red
    exit
}

if (-not (Test-Path $IsoRoot)) {
    Write-Host "[!] ISO Root directory not found at $IsoRoot!" -ForegroundColor Red
    exit
}

# Extract parent directories and leaf names to avoid MSYS absolute path parsing and drive letter colons
$IsoRootParent = Split-Path $IsoRoot -Parent
$IsoRootLeaf = Split-Path $IsoRoot -Leaf
$OutputIsoName = Split-Path $OutputPath -Leaf

# Break down the arguments so they are easy to tweak and test
$ArgumentList = "-as mkisofs " +
"-v " +
"-iso-level 3 " +
"-full-iso9660-filenames " +
"-relaxed-filenames " +
"-J -joliet-long " +
"-volid `"SOVEREIGN`" " +
"-b boot/etfsboot.com " +
"-no-emul-boot " +
"-boot-load-size 8 " +
"-boot-info-table " +
"-eltorito-alt-boot " +
"-e efi/microsoft/boot/efisys.bin " +
"-no-emul-boot " +
"-output `"./$OutputIsoName`" " +
"`"$IsoRootLeaf`""

Write-Host "Executing xorriso with arguments:" -ForegroundColor Cyan
Write-Host $ArgumentList -ForegroundColor DarkGray

$process = Start-Process -FilePath $XorrisoExe -ArgumentList $ArgumentList -WorkingDirectory $IsoRootParent -Wait -NoNewWindow -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host "`n[+] ISO created successfully at: $OutputPath" -ForegroundColor Green
}
else {
    Write-Host "`n[-] xorriso encountered an error (Exit Code: $($process.ExitCode))." -ForegroundColor Red
}
