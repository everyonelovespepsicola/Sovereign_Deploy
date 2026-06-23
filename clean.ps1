<#
.SYNOPSIS
Cleans up transient build folders and unmounts dangling WIMs safely.
#>

$ErrorActionPreference = "SilentlyContinue"
$WorkspacePath = "C:\projects\ntlight"
$BuildDir = "$WorkspacePath\build"

Write-Host "Unmounting any dangling WIMs..." -ForegroundColor Cyan
dism.exe /Unmount-Wim /MountDir:"$BuildDir\mount" /Discard
dism.exe /Cleanup-Wim

Write-Host "Deleting transient build directories..." -ForegroundColor Cyan
Remove-Item -Path "$BuildDir\mount" -Recurse -Force
Remove-Item -Path "$BuildDir\extracted_iso" -Recurse -Force
Remove-Item -Path "$BuildDir\iso_build" -Recurse -Force
Remove-Item -Path "$BuildDir\Sovereign_BootMount" -Recurse -Force
Remove-Item -Path "$BuildDir\Sovereign_ISORoot" -Recurse -Force
Remove-Item -Path "$BuildDir\Sovereign_Mount" -Recurse -Force

Write-Host "Cleanup Complete!" -ForegroundColor Green
