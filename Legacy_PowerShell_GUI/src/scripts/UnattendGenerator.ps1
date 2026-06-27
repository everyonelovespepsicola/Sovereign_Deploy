function New-SovereignUnattend {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [string]$Username = "SovereignAdmin",
        [string]$Password = "Password123",
        [bool]$UseBuiltInAdmin = $false,
        [string]$SystemLanguage = "en-US",
        [array]$RemovedItems = @(),
        [string]$IsoRoot = $null,
        [bool]$ApplyRegionPolicy = $false,
        [bool]$DisableUCPD = $false,
        [bool]$BypassTPM = $false,
        [string]$WuMode = "Default",
        [bool]$ApplyQoLTweaks = $false
    )

    Write-Host "SOV_CYAN:Generating autounattend.xml..."

    $RunSyncCommands = @"
                <RunSynchronousCommand wcm:action=""add"">
                    <Order>$Order</Order>
                    <Path>powershell.exe -NoProfile -Command ""Set-ExecutionPolicy Unrestricted -Force""</Path>
                    <Description>Permanently Allow PowerShell Scripts</Description>
                </RunSynchronousCommand>
"@
    $Order = 2

    if ($UseBuiltInAdmin) {
        $AccountXml = ""
        if (-not [string]::IsNullOrEmpty($Password)) {
            $AccountXml = @"
                <AdministratorPassword>
                    <Value>$Password</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
"@
        }
        $RunSyncCommands += @"
                <RunSynchronousCommand wcm:action="add">
                    <Order>$Order</Order>
                    <Path>powershell.exe -NoProfile -Command "Get-LocalUser | Where-Object SID -Like 'S-1-5-21-*-500' | Rename-LocalUser -NewName '$Username'; Enable-LocalUser -Name '$Username'"</Path>
                    <Description>Rename and Enable Built-in Administrator</Description>
                </RunSynchronousCommand>
"@
        $Order++
    }
    else {
        $LocalPwdXml = ""
        if (-not [string]::IsNullOrEmpty($Password)) {
            $LocalPwdXml = @"
                        <Password>
                            <Value>$Password</Value>
                            <PlainText>true</PlainText>
                        </Password>
"@
        }
        $AccountXml = @"
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
$LocalPwdXml
                        <Description>Local Administrator Account</Description>
                        <DisplayName>$Username</DisplayName>
                        <Group>Administrators</Group>
                        <Name>$Username</Name>
                    </LocalAccount>
                </LocalAccounts>
"@
    }

    $SpecializePass = ""
    if (-not [string]::IsNullOrWhiteSpace($RunSyncCommands)) {
        $SpecializePass = @"
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
$RunSyncCommands
            </RunSynchronous>
        </component>
    </settings>
"@
    }

    $WindowsPEPass = @"
    <settings pass=""windowsPE"">
        <component name=""Microsoft-Windows-Setup"" processorArchitecture=""amd64"" publicKeyToken=""31bf3856ad364e35"" language=""neutral"" versionScope=""nonSxS"" xmlns:wcm=""http://schemas.microsoft.com/WMIConfig/2002/State"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"">
            <Display>
                <ColorDepth>32</ColorDepth>
                <HorizontalResolution>1280</HorizontalResolution>
                <VerticalResolution>720</VerticalResolution>
            </Display>
"@

    if ($BypassTPM) {
        $WindowsPEPass += @"
            <RunSynchronous>
                <RunSynchronousCommand wcm:action=""add"">
                    <Order>1</Order>
                    <Path>cmd.exe /c reg add ""HKLM\SYSTEM\Setup\LabConfig"" /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action=""add"">
                    <Order>2</Order>
                    <Path>cmd.exe /c reg add ""HKLM\SYSTEM\Setup\LabConfig"" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action=""add"">
                    <Order>3</Order>
                    <Path>cmd.exe /c reg add ""HKLM\SYSTEM\Setup\LabConfig"" /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action=""add"">
                    <Order>4</Order>
                    <Path>cmd.exe /c reg add ""HKLM\SYSTEM\Setup\LabConfig"" /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action=""add"">
                    <Order>5</Order>
                    <Path>cmd.exe /c reg add ""HKLM\SYSTEM\Setup\LabConfig"" /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
"@
    }

    $WindowsPEPass += @"
        </component>
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>$SystemLanguage</UILanguage>
            </SetupUILanguage>
            <InputLocale>$SystemLanguage</InputLocale>
            <SystemLocale>$SystemLanguage</SystemLocale>
            <UILanguage>$SystemLanguage</UILanguage>
            <UserLocale>$SystemLanguage</UserLocale>
        </component>
    </settings>
"@

    # --- Validation Script Generation ---
    $ValidationScript = @"
`$ErrorActionPreference = 'SilentlyContinue'
Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    Sovereign Validation Report" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

function Check-Item {
    param(`$Name, `$Condition)
    if (`$Condition) {
        Write-Host "[X] PASS: `$Name" -ForegroundColor Green
    } else {
        Write-Host "[ ] FAIL: `$Name" -ForegroundColor Red
    }
}

Check-Item "User Account '$Username' exists" (`$null -ne (Get-LocalUser -Name '$Username' -ErrorAction SilentlyContinue))
"@

    if ($UseBuiltInAdmin) {
        $ValidationScript += @"
Check-Item "Built-in Admin is Active" ((Get-LocalUser -Name '$Username' -ErrorAction SilentlyContinue).Enabled)
"@
    }

    $ValidationScript += @"
`$cloudContent = Get-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\CloudContent' -ErrorAction SilentlyContinue
Check-Item "Consumer Features Disabled" (`$cloudContent.DisableWindowsConsumerFeatures -eq 1)
"@

    if ($DisableUCPD) {
        $ValidationScript += @"
`$ucpd = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\UCPD' -ErrorAction SilentlyContinue
Check-Item "UCPD Driver Disabled" (`$ucpd.Start -eq 4)
"@
    }

    if ($WuMode -eq "Security") {
        $ValidationScript += @"
`$wu = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -ErrorAction SilentlyContinue
Check-Item "Security Updates Only (Feature Updates Deferred)" (`$wu.DeferFeatureUpdates -eq 1)
"@
    }
    elseif ($WuMode -eq "Disable") {
        $ValidationScript += @"
`$wu = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -ErrorAction SilentlyContinue
`$wuPause = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -ErrorAction SilentlyContinue
`$wuauserv = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\wuauserv' -ErrorAction SilentlyContinue
`$usoSvc = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\UsoSvc' -ErrorAction SilentlyContinue
Check-Item "Windows Update Disabled" (`$wu.NoAutoUpdate -eq 1)
Check-Item "Updates Paused Until 2099" (`$wuPause.PauseUpdatesExpiryTime -match "2099")
Check-Item "Update Services Disabled" (`$wuauserv.Start -eq 4 -and `$usoSvc.Start -eq 4)
"@
    }

    if ($RemovedItems -and $RemovedItems.Count -gt 0) {
        $ValidationScript += @"

Write-Host "`nScanning system components (this may take a moment)..." -ForegroundColor DarkGray
`$caps = Get-WindowsCapability -Online -ErrorAction SilentlyContinue
`$feats = Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue
`$appx = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
`$pkgs = Get-WindowsPackage -Online -ErrorAction SilentlyContinue

Write-Host "`nVerifying Removed Components..." -ForegroundColor Cyan
"@
        foreach ($item in $RemovedItems) {
            if ($item.Type -eq "Capability") {
                $ValidationScript += "`nCheck-Item `"Removed: $($item.DisplayName)`" ((`$caps | Where-Object { `$_.Name -eq '$($item.Name)' }).State -eq 'NotPresent')"
            }
            elseif ($item.Type -eq "OptionalFeature") {
                $ValidationScript += "`nCheck-Item `"Disabled: $($item.DisplayName)`" ((`$feats | Where-Object { `$_.FeatureName -eq '$($item.Name)' }).State -ne 'Enabled')"
            }
            elseif ($item.Type -eq "AppxPackage") {
                $ValidationScript += "`nCheck-Item `"Removed: $($item.DisplayName)`" (-not (`$appx | Where-Object { `$_.PackageName -eq '$($item.Name)' }))"
            }
            elseif ($item.Type -eq "Package") {
                $ValidationScript += "`nCheck-Item `"Removed: $($item.DisplayName)`" ((`$pkgs | Where-Object { `$_.PackageName -eq '$($item.Name)' }).PackageState -ne 'Installed')"
            }
        }
    }

    $ValidationScript += @"

Write-Host "`nValidation Complete. Welcome to your Sovereign System!" -ForegroundColor Cyan
Read-Host "Press Enter to close"
"@

    if (-not [string]::IsNullOrWhiteSpace($IsoRoot) -and (Test-Path $IsoRoot)) {
        # Place the validation script in the $OEM$ folder.
        # Windows Setup automatically copies everything in $OEM$\$1 to the root of the OS drive (C:\).
        $OemDesktopPath = Join-Path $IsoRoot 'sources\$OEM$\$1\Users\Public\Desktop'
        if (-not (Test-Path $OemDesktopPath)) {
            New-Item -ItemType Directory -Path $OemDesktopPath -Force | Out-Null
        }

        $ValidationScriptPath = Join-Path $OemDesktopPath "SovereignValidation.ps1"
        $ValidationScript | Out-File -FilePath $ValidationScriptPath -Encoding UTF8 -Force

        # Place an explicit copy at the root of the ISO media as requested
        $IsoRootScriptPath = Join-Path $IsoRoot "SovereignValidation.ps1"
        $ValidationScript | Out-File -FilePath $IsoRootScriptPath -Encoding UTF8 -Force

        # Create Windows Updater GUI launcher on the Desktop
        try {
            Write-Host "SOV_DARKGRAY:  -> Creating Windows Updater GUI launcher..."
            $UpdaterPath = Join-Path $OemDesktopPath "WindowsUpdaterGUI.cmd"
            $UpdaterRootPath = Join-Path $IsoRoot "WindowsUpdaterGUI.cmd"
            $UpdaterCmd = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/everyonelovespepsicola/WindowsUpdate/refs/heads/main/WindowsUpdaterGUI.ps1 | iex`""
            $UpdaterCmd | Out-File -FilePath $UpdaterPath -Encoding ascii -Force
            $UpdaterCmd | Out-File -FilePath $UpdaterRootPath -Encoding ascii -Force
        }
        catch {
            Write-Host "SOV_YELLOW:  [!] Failed to create Windows Updater GUI launcher: $($_.Exception.Message)"
        }

        if ($ApplyQoLTweaks) {
            # Create Chris Titus WinUtil launcher on the Desktop
            try {
                Write-Host "SOV_DARKGRAY:  -> Creating WinUtil.cmd launcher..."
                $WinUtilPath = Join-Path $OemDesktopPath "WinUtil.cmd"
                $WinUtilRootPath = Join-Path $IsoRoot "WinUtil.cmd"
                $WinUtilCmd = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"irm christitus.com/win | iex`""
                $WinUtilCmd | Out-File -FilePath $WinUtilPath -Encoding ascii -Force
                $WinUtilCmd | Out-File -FilePath $WinUtilRootPath -Encoding ascii -Force
            }
            catch {
                Write-Host "SOV_YELLOW:  [!] Failed to create WinUtil launcher: $($_.Exception.Message)"
            }
        }

        # The script is now natively on the local drive, no USB needed!
        $FindAndRun = 'if (Test-Path "$env:PUBLIC\Desktop\SovereignValidation.ps1") { & "$env:PUBLIC\Desktop\SovereignValidation.ps1" }'
        $Bytes = [System.Text.Encoding]::Unicode.GetBytes($FindAndRun)
    }
    else {
        $Bytes = [System.Text.Encoding]::Unicode.GetBytes($ValidationScript)
    }
    $Base64 = [Convert]::ToBase64String($Bytes)
    $ValidationCmd = "powershell.exe -WindowStyle Normal -ExecutionPolicy Bypass -NoProfile -EncodedCommand $Base64"

    $FirstLogonXml = @"
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>cmd.exe /c if exist "%WINDIR%\Setup\Scripts\SetupComplete.cmd" "%WINDIR%\Setup\Scripts\SetupComplete.cmd"</CommandLine>
                    <Description>Force Execute SetupComplete (App Provisioning)</Description>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <CommandLine>$ValidationCmd</CommandLine>
                    <Description>Sovereign System Validation Scan</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
"@

    $AutoLogonPwdXml = ""
    if (-not [string]::IsNullOrEmpty($Password)) {
        $AutoLogonPwdXml = @"
                <Password>
                    <Value>$Password</Value>
                    <PlainText>true</PlainText>
                </Password>
"@
    }

    $XmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
$WindowsPEPass
$SpecializePass
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>$SystemLanguage</InputLocale>
            <SystemLocale>$SystemLanguage</SystemLocale>
            <UILanguage>$SystemLanguage</UILanguage>
            <UserLocale>$SystemLanguage</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <AutoLogon>
$AutoLogonPwdXml
                <Enabled>true</Enabled>
                <LogonCount>9999999</LogonCount>
                <Username>$Username</Username>
            </AutoLogon>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>3</ProtectYourPC>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
            <UserAccounts>
$AccountXml
            </UserAccounts>
$FirstLogonXml
        </component>
    </settings>
</unattend>
"@

    $XmlContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
    Write-Host "SOV_GREEN:Injected Unattend file at $OutputPath"
}
