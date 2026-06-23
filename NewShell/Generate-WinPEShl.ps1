<#
.SYNOPSIS
Generates the winpeshl.ini file required to hijack the WinPE boot sequence.

.DESCRIPTION
Standard WinPE boots directly into cmd.exe. 
To launch NewShell as the primary graphical interface, this script generates the winpeshl.ini 
file. When you mount your boot.wim file using DISM, you must copy the generated winpeshl.ini 
into the mounted Windows\System32 directory.

.EXAMPLE
.\Generate-WinPEShl.ps1 -OutputPath "C:\WinPE_Mount\Windows\System32\winpeshl.ini"
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\winpeshl.ini"
)

# The configuration block for winpeshl.ini
# We instruct it to launch NewShell.exe (assuming you copy NewShell.exe to the root of X:\ or X:\Tools)
# Update the path to X:\NewShell.exe or wherever you inject it into the boot.wim!
$iniContent = @"
[LaunchApps]
%SYSTEMROOT%\System32\wpeinit.exe
%SYSTEMDRIVE%\Tools\NewShell\CustomShell.exe
"@

try {
    # Ensure ASCII encoding. WinPE's winpeshl.ini parser breaks if there is a UTF-8 BOM!
    [System.IO.File]::WriteAllText($OutputPath, $iniContent, [System.Text.Encoding]::ASCII)
    Write-Host "[+] Successfully generated WinPE shell hook at: $OutputPath" -ForegroundColor Green
    Write-Host "[!] INSTRUCTIONS:" -ForegroundColor Cyan
    Write-Host "    1. Mount your boot.wim using DISM."
    Write-Host "    2. Copy this winpeshl.ini file into the mounted Windows\System32\ folder."
    Write-Host "    3. Copy your compiled NewShell.exe to X:\Tools\NewShell\ inside the WIM."
    Write-Host "    4. Commit the WIM. WinPE will now boot into your custom Sovereign UI!"
}
catch {
    Write-Error "Failed to generate winpeshl.ini: $_"
}
