<#
.SYNOPSIS
Sovereign WinPE Build Pipeline

.DESCRIPTION
Orchestrates the entire build process:
1. Uses GitHub API to resolve dependencies from tools_manifest.json.
2. Compiles NewShell as a .NET 8 self-contained executable.
3. Mounts the stock Windows ISO and extracts boot.wim.
4. Uses DISM to inject Optional Components and custom payloads.
5. Repacks the result into a universal Sovereign_WinPE.iso for Ventoy/VirtualBox.

.NOTES
Requires Windows ADK (for oscdimg and WinPE Optional Components) and .NET 8 SDK.
#>

$ErrorActionPreference = "Stop"

# --- CONFIGURATION ---
$WorkspacePath = $PSScriptRoot
$IsoPath = "$WorkspacePath\input\windows.iso"
$MountDir = "$WorkspacePath\build\mount"
$ExtractDir = "$WorkspacePath\build\extracted_iso"
$FrozenToolsDir = "$WorkspacePath\frozen_tools"
$ManifestPath = "$WorkspacePath\tools\tools_manifest.json"
$FinalIsoPath = "$WorkspacePath\output\Sovereign_WinPE.iso"

if (Test-Path $FinalIsoPath) {
    Write-Host "Cleaning up old ISO..." -ForegroundColor Yellow
    Remove-Item $FinalIsoPath -Force -ErrorAction Stop
}

# 1. RESOLVE DEPENDENCIES (Direct Manifest Download)
Write-Host ">>> STEP 1: Resolving Dependencies..." -ForegroundColor Cyan
if (Test-Path $ManifestPath) {
    $manifest = Get-Content $ManifestPath | ConvertFrom-Json
    foreach ($tool in $manifest.tools) {
        Write-Host "Checking cache for $($tool.name)..."
        $TargetDir = "$FrozenToolsDir\$($tool.name)"
        $ExpectedExe = "$TargetDir\$($tool.exe_name)"

        if (Test-Path $ExpectedExe) {
            Write-Host "[+] $($tool.name) is already frozen in cache. Skipping download." -ForegroundColor Green
            continue
        }

        $url = $null
        if ($tool.github_repo) {
            Write-Host "Resolving latest release of $($tool.name) via GitHub API..."
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                $headers = @{ "User-Agent" = "SovereignDeploy-Pipeline" }
                $releaseUrl = "https://api.github.com/repos/$($tool.github_repo)/releases/latest"
                $releaseInfo = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -ErrorAction Stop
                
                $matchAsset = $releaseInfo.assets | Where-Object { $_.name -match $tool.asset_pattern } | Select-Object -First 1
                if ($matchAsset) {
                    $url = $matchAsset.browser_download_url
                    $tool.asset_name = $matchAsset.name
                    Write-Host "  -> Found latest asset: $($matchAsset.name)"
                }
                else {
                    Write-Warning "Could not find asset matching pattern $($tool.asset_pattern) in repository $($tool.github_repo)!"
                }
            }
            catch {
                Write-Warning "GitHub API query failed for $($tool.name): $($_.Exception.Message)"
            }
        }
        else {
            $url = $tool.download_url
        }

        if (-not $url) {
            Write-Host "WARNING: Failed to resolve download URL for $($tool.name). Falling back to frozen cache if available." -ForegroundColor Yellow
            continue
        }

        Write-Host "Downloading $($tool.name) from $url..."
        $OutFile = "$FrozenToolsDir\$($tool.asset_name)"
        
        try {
            Invoke-WebRequest -Uri $url -OutFile $OutFile -ErrorAction Stop
            
            if ($tool.extract) {
                Write-Host "Extracting $($tool.name)..."
                if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir | Out-Null }
                Expand-Archive -Path $OutFile -DestinationPath $TargetDir -Force
                Remove-Item $OutFile -Force
                
                # Flatten double-nesting if zip contained a folder matching the tool name
                if (Test-Path "$TargetDir\$($tool.name)") {
                    Move-Item -Path "$TargetDir\$($tool.name)\*" -Destination $TargetDir -Force
                    Remove-Item "$TargetDir\$($tool.name)" -Recurse -Force
                }
            }
            elseif ($tool.inno_extract) {
                Write-Host "Extracting $($tool.name) using innoextract..."
                if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir | Out-Null }
                $innoExe = "$FrozenToolsDir\InnoExtract\innoextract.exe"
                if (-not (Test-Path $innoExe)) {
                    Write-Warning "innoextract.exe not found! Cannot extract $($tool.name)."
                }
                else {
                    & $innoExe $OutFile -d $TargetDir -q -T none 2>&1 | Out-Null
                    # Flatten the Inno Setup structure by moving 'app' contents to the root
                    if (Test-Path "$TargetDir\app") {
                        Move-Item -Path "$TargetDir\app\*" -Destination $TargetDir -Force
                        Remove-Item "$TargetDir\app", "$TargetDir\tmp", "$TargetDir\win" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
                Remove-Item $OutFile -Force
            }
            else {
                if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir | Out-Null }
                # For non-extracted files, exe_name might contain subfolders if it's a deeply nested path, but here it's usually just the filename
                # For safety, ensure destination parent directory exists if exe_name has path separators
                $DestFile = "$TargetDir\$($tool.exe_name)"
                $DestParent = Split-Path $DestFile -Parent
                if (-not (Test-Path $DestParent)) { New-Item -ItemType Directory -Path $DestParent | Out-Null }
                Move-Item -Path $OutFile -Destination $DestFile -Force
            }
            Write-Host "[+] Successfully fetched $($tool.name)!" -ForegroundColor Green
            if ($tool.name -eq "DiskGenius") {
                Write-Host "Locating 64-bit oledlg.dll dependency in WinSxS..."
                $OledlgPath = (Get-ChildItem -Path "C:\Windows\WinSxS" -Filter "oledlg.dll" -Recurse -ErrorAction SilentlyContinue | 
                    Where-Object { $_.FullName -like "*amd64_*" -and $_.FullName -notlike "*\r\*" } | 
                    Select-Object -First 1).FullName
                
                if ($OledlgPath -and (Test-Path $OledlgPath)) {
                    Write-Host "Copying oledlg.dll from $OledlgPath..."
                    Copy-Item -Path $OledlgPath -Destination $TargetDir -Force
                } else {
                    Write-Warning "Could not find a 64-bit oledlg.dll in WinSxS!"
                }
            }
        }
        catch {
            Write-Host "WARNING: Failed to download $($tool.name). Falling back to frozen cache if available." -ForegroundColor Yellow
        }
    }
}

# 2. COMPILE NEWSHELL (Self-Contained .NET 8)
Write-Host "`n>>> STEP 2: Compiling NewShell (Self-Contained)..." -ForegroundColor Cyan
$NewShellDir = "$WorkspacePath\NewShell"
$PublishDir = "$NewShellDir\bin\Release\net8.0-windows\win-x64\publish"

Set-Location $NewShellDir
# We compile as self-contained so it carries the .NET 8 runtime with it, bypassing WinPE's limitations!
dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true



# 3. MOUNT ISO & EXTRACT BOOT.WIM AND SKELETON
Write-Host "`n>>> STEP 3: Extracting ISO skeleton and boot.wim..." -ForegroundColor Cyan
$IsoBuildDir = "$WorkspacePath\build\iso_build"
if (-not (Test-Path $IsoBuildDir)) { New-Item -ItemType Directory -Path $IsoBuildDir | Out-Null }

Write-Host "Mounting ISO: $IsoPath"
$mountedDrive = (Mount-DiskImage -ImagePath $IsoPath -PassThru | Get-Volume).DriveLetter

Write-Host "Copying ISO skeleton to workspace (skipping massive install.wim)..."
& robocopy.exe "${mountedDrive}:\" "$IsoBuildDir" /E /XF install.wim /NJH /NJS /NDL /NC /NS /NP | Out-Null

$sourceWim = "${mountedDrive}:\sources\boot.wim"
$localWim = "$IsoBuildDir\sources\boot.wim"

Write-Host "Removing bootfix.bin to enable Zero-Touch Booting (no 'Press any key' prompt)..."
if (Test-Path "$IsoBuildDir\boot\bootfix.bin") {
    Remove-Item -Path "$IsoBuildDir\boot\bootfix.bin" -Force
}

# CRITICAL FIX: Files copied from an ISO are read-only. DISM cannot mount a read-only WIM!
Set-ItemProperty -Path $localWim -Name IsReadOnly -Value $false

Write-Host "Unmounting ISO..."
Dismount-DiskImage -ImagePath $IsoPath | Out-Null

# 4. MOUNT WIM
Write-Host "`n>>> STEP 4: Mounting WinPE Image..." -ForegroundColor Cyan
if (Test-Path $MountDir) {
    Write-Host "Cleaning up old mount directory..."
    Remove-Item -Path $MountDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $MountDir -Force | Out-Null

dism.exe /Mount-Wim /WimFile:$localWim /Index:2 /MountDir:$MountDir

# 5. INJECT CUSTOM PAYLOADS
Write-Host "`n>>> STEP 5: Injecting Sovereign Payload..." -ForegroundColor Cyan
$PeToolsDir = "$MountDir\Tools"
if (-not (Test-Path $PeToolsDir)) { New-Item -ItemType Directory -Path $PeToolsDir | Out-Null }

$NewShellPeDir = "$PeToolsDir\NewShell"
if (-not (Test-Path $NewShellPeDir)) { New-Item -ItemType Directory -Path $NewShellPeDir | Out-Null }

# Copy Compiled NewShell
Write-Host "Copying NewShell..."
Copy-Item -Path "$PublishDir\*" -Destination $NewShellPeDir -Recurse -Force

# Copy Frozen Tools (Explorer++, AOMEI, Dism++)
Write-Host "Copying Frozen Tools..."
Copy-Item -Path "$FrozenToolsDir\*" -Destination $PeToolsDir -Recurse -Force

# Copy MBR-Deep
Write-Host "Copying MBR-Deep..."
$MbrDeepDir = "$PeToolsDir\MBR-Deep"
if (-not (Test-Path $MbrDeepDir)) { New-Item -ItemType Directory -Path $MbrDeepDir | Out-Null }
Copy-Item -Path "C:\projects\MBR-Deep\src\UI_Python\dist\MBR-Deep-Classic.exe" -Destination "$MbrDeepDir\" -Force



# Inject Custom Wallpaper
$WallpaperPath = "$WorkspacePath\assets\winpe.jpg"
if (Test-Path $WallpaperPath) {
    Write-Host "Injecting Sovereign Wallpaper..."
    $TargetWallpaper = "$MountDir\Windows\System32\winpe.jpg"
    if (Test-Path $TargetWallpaper) {
        takeown.exe /f $TargetWallpaper /a | Out-Null
        icacls.exe $TargetWallpaper /grant "Administrators:F" | Out-Null
    }
    Copy-Item -Path $WallpaperPath -Destination $TargetWallpaper -Force
}

# Generate winpeshl.ini hook
Write-Host "Generating WinPE Shell hook..."
& "$NewShellDir\Generate-WinPEShl.ps1" -OutputPath "$MountDir\Windows\System32\winpeshl.ini"

# 6. COMMIT WIM
Write-Host "`n>>> STEP 6: Committing Changes to boot.wim..." -ForegroundColor Cyan
dism.exe /Unmount-Wim /MountDir:$MountDir /Commit

# 7. REPACK INTO UNIVERSAL ISO
Write-Host "`n>>> STEP 7: Repacking Universal Sovereign_WinPE.iso..." -ForegroundColor Cyan
Write-Host "Building Sovereign WinPE ISO..." -ForegroundColor Cyan

$unattendWinPe = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <Display>
                <ColorDepth>32</ColorDepth>
                <HorizontalResolution>1280</HorizontalResolution>
                <RefreshRate>60</RefreshRate>
                <VerticalResolution>720</VerticalResolution>
            </Display>
        </component>
    </settings>
</unattend>
"@
Set-Content -Path "$WorkspacePath\input\unattend.xml" -Value $unattendWinPe -Encoding Ascii -Force

# Check for xorriso (downloaded via GitHub API)
$xorriso = Join-Path $FrozenToolsDir "xorriso.exe"
# Check for oscdimg (from Windows ADK)
$oscdimg = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"

if (Test-Path $xorriso) {
    Write-Host "Found Xorriso! Using xorriso to pack ISO..."
    Set-Location $WorkspacePath
    $FinalIsoName = Split-Path $FinalIsoPath -Leaf
    $xorrisoCommand = "-as mkisofs -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -boot-info-table -c BOOT.CAT -iso-level 4 -J -l -D -N -joliet-long -relaxed-filenames -V `"SOVEREIGN`" -eltorito-alt-boot -e efi/microsoft/boot/efisys.bin -no-emul-boot -o `"$FinalIsoPath`" `"build\iso_build`""
    
    Invoke-Expression "& `"$xorriso`" $xorrisoCommand"
    
    if ($LASTEXITCODE -eq 0) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "===========================================================" -ForegroundColor Green
        Write-Host "`n[+++] PIPELINE COMPLETE! Universal ISO created at: $FinalIsoPath" -ForegroundColor Green
        Write-Host "[+++] COMPILE TIMESTAMP: $timestamp" -ForegroundColor Magenta
        Write-Host "`n===========================================================" -ForegroundColor Green
    }
    else {
        Write-Warning "Xorriso encountered an error while packing the ISO."
    }
}
elseif (Test-Path $oscdimg) {
    Write-Host "Found oscdimg! Using ADK tool to pack ISO..."
    $etfsboot = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\etfsboot.com"
    $efisys = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys.bin"
    
    & $oscdimg -m -o -u2 -udfver102 -bootdata:2#p0, e, b"$etfsboot"#pEF, e, b"$efisys" "$IsoBuildDir" "$FinalIsoPath"
    
    Write-Host "`n[+++] PIPELINE COMPLETE! Universal ISO created at: $FinalIsoPath" -ForegroundColor Green
}
else {
    Write-Warning "Neither xorriso.exe nor oscdimg.exe were found. Skipping ISO generation. You can manually copy iso_build\sources\boot.wim to Ventoy."
}
