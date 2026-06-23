function Get-Xorriso {
    [CmdletBinding()]
    param([string]$ScriptDir = "")

    if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = $PSScriptRoot }
    if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = $PWD.Path }
    $ToolPath = Join-Path $ScriptDir "xorriso.exe"

    if (Test-Path $ToolPath) { return $ToolPath }

    Write-Host "SOV_CYAN:xorriso.exe not found. Preparing multi-engine acquisition..."

    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $TempDir = Join-Path $env:TEMP "SovereignXorriso"
    if (Test-Path $TempDir) { Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $TempDir | Out-Null

    $downloadSuccess = $false

    # Engine 1: GitHub Releases API
    Write-Host "SOV_DARKGRAY:  -> Querying GitHub Releases API for xorriso..."
    try {
        $githubApiUrl = "https://api.github.com/repos/PeyTy/xorriso-exe-for-windows/releases/latest"
        $releaseRaw = $webClient.DownloadString($githubApiUrl) | ConvertFrom-Json

        $asset = $releaseRaw.assets | Where-Object { $_.name -match "\.zip$" } | Select-Object -First 1
        if ($asset) {
            $downloadPath = Join-Path $TempDir $asset.name
            $webClient.DownloadFile($asset.browser_download_url, $downloadPath)

            if ($asset.name -match "\.zip$") {
                Expand-Archive -Path $downloadPath -DestinationPath $TempDir -Force
            }
            else {
                Copy-Item -Path $downloadPath -Destination (Join-Path $TempDir "xorriso.exe") -Force
            }
            $downloadSuccess = $true
        }
    }
    catch { Write-Host "SOV_DARKGRAY:  -> GitHub API query failed. Proceeding to hard fallback..." }

    # Engine 2: Hard GitHub Archive (Master Zip Fallback)
    if (-not $downloadSuccess) {
        Write-Host "SOV_DARKGRAY:  -> Engaging hard fallback to GitHub Master archive..."
        try {
            $zipUrl = "https://github.com/PeyTy/xorriso-exe-for-windows/archive/refs/heads/master.zip"
            $zipPath = Join-Path $TempDir "xorriso_master.zip"
            $webClient.DownloadFile($zipUrl, $zipPath)
            Expand-Archive -Path $zipPath -DestinationPath $TempDir -Force
        }
        catch { Write-Host "SOV_DARKGRAY:  -> Archive download or extraction failed." }
    }

    # Locate the executable (Ensure we only match files, not directories)
    $foundExe = Get-ChildItem -Path $TempDir -Filter "xorriso.exe" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($foundExe) {
        Write-Host "SOV_GREEN:  -> SUCCESS! Found xorriso.exe."
        try {
            Unblock-File -Path $foundExe.FullName -ErrorAction SilentlyContinue
            Copy-Item -Path $foundExe.FullName -Destination $ToolPath -Force -ErrorAction Stop

            # Xorriso requires its packaged Cygwin libraries to execute correctly in Windows
            $dlls = Get-ChildItem -Path $TempDir -Filter "*.dll" -Recurse -File
            foreach ($dll in $dlls) { Copy-Item -Path $dll.FullName -Destination (Join-Path $ScriptDir $dll.Name) -Force -ErrorAction SilentlyContinue }
        }
        catch {
            Write-Host "SOV_RED:  [!] Failed to copy xorriso to $ScriptDir. Error: $_"
        }
    }
    else {
        Write-Host "SOV_RED:  [!] All acquisition engines failed."
    }

    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $ToolPath) { return $ToolPath }
    return $null
}

function Get-OpenShell {
    [CmdletBinding()]
    param([string]$ScriptDir = "")

    if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = $PSScriptRoot }
    if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = $PWD.Path }
    $ToolPath = Join-Path $ScriptDir "ClassicShellSetup.exe"

    if (Test-Path $ToolPath) { return $ToolPath }

    Write-Host "SOV_CYAN:ClassicShellSetup.exe not found. Acquiring from GitHub..."

    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    try {
        $githubApiUrl = "https://api.github.com/repos/Open-Shell/Open-Shell-Menu/releases/latest"
        $releaseRaw = $webClient.DownloadString($githubApiUrl) | ConvertFrom-Json

        $asset = $releaseRaw.assets | Where-Object { $_.name -match "OpenShellSetup.*\.exe$" } | Select-Object -First 1
        if ($asset) {
            Write-Host "SOV_DARKGRAY:  -> Downloading $($asset.name)..."
            $webClient.DownloadFile($asset.browser_download_url, $ToolPath)
            Unblock-File -Path $ToolPath -ErrorAction SilentlyContinue
        }
        else {
            Write-Host "SOV_YELLOW:  [!] Could not find a suitable EXE in the latest Open-Shell release."
            return $null
        }
    }
    catch {
        Write-Host "SOV_RED:  [!] GitHub API query failed for Open-Shell: $($_.Exception.Message)"
        return $null
    }

    if (Test-Path $ToolPath) {
        Write-Host "SOV_GREEN:  -> SUCCESS! Acquired ClassicShellSetup.exe."
        return $ToolPath
    }
    return $null
}

function Inject-WinPEOptionalComponents {
    [CmdletBinding()]
    param([string]$BootMountPath)

    # Default installation path for Windows 10/11 ADK WinPE Add-ons
    $ADK_OC_Path = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs"

    if (-not (Test-Path $ADK_OC_Path)) {
        Write-Host "SOV_CYAN:  -> WinPE ADK Add-on not found. Acquiring from Microsoft (This may take several minutes)..."
        $TempSetup = Join-Path $env:TEMP "adkwinpesetup.exe"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            # Direct link for the Windows 11 ADK PE Addon
            Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2243390" -OutFile $TempSetup -UseBasicParsing | Out-Null
            Write-Host "SOV_DARKGRAY:  -> Silently installing WinPE Add-on natively..."
            Start-Process -FilePath $TempSetup -ArgumentList "/quiet /features OptionId.WindowsPreinstallationEnvironment" -Wait -NoNewWindow | Out-Null
        }
        catch {
            Write-Host "SOV_RED:  [!] Failed to download or install WinPE ADK. Custom GUI will fall back to CLI."
            return
        }
    }

    if (Test-Path $ADK_OC_Path) {
        Write-Host "SOV_DARKGRAY:  -> Injecting PowerShell and WPF dependencies into boot.wim..."
        # Order is crucial: WMI -> NetFx -> Scripting -> PowerShell
        $Packages = @(
            "WinPE-WMI.cab", "en-us\WinPE-WMI_en-us.cab",
            "WinPE-NetFx.cab", "en-us\WinPE-NetFx_en-us.cab",
            "WinPE-Scripting.cab", "en-us\WinPE-Scripting_en-us.cab",
            "WinPE-PowerShell.cab", "en-us\WinPE-PowerShell_en-us.cab"
        )

        foreach ($pkg in $Packages) {
            $cabPath = Join-Path $ADK_OC_Path $pkg
            if (Test-Path $cabPath) {
                Write-Host "SOV_DARKGRAY:     + $pkg"
                Add-WindowsPackage -Path $BootMountPath -PackagePath $cabPath -ErrorAction SilentlyContinue | Out-Null
            }
            else {
                Write-Host "SOV_YELLOW:     [!] Missing $pkg"
            }
        }
    }
    else {
        Write-Host "SOV_RED:  [!] ADK OC Path still not found after installation attempt."
    }
}

function Invoke-SovereignBuild {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.ObjectModel.ObservableCollection[Object]]$ComponentData,
        [string]$ScriptDir = "",
        [string]$WimPath = $null,
        [int]$WimIndex = 1,
        [string]$MountPath = "C:\Sovereign_Mount",
        [string]$IsoRoot = "C:\Sovereign_ISORoot",
        [string]$Username = "SovereignAdmin",
        [string]$Password = "Password123",
        [bool]$UseBuiltInAdmin = $false,
        [bool]$ApplyRegionPolicy = $false,
        [bool]$DisableUCPD = $false,
        [bool]$BypassTPM = $false,
        [string]$WuMode = "Default",
        [bool]$KillCopilot = $false,
        [bool]$KillRecall = $false,
        [bool]$KillEdge = $false,
        [bool]$KillWebSearch = $false,
        [bool]$KillCampaigns = $false,
        [bool]$KillPromos = $false,
        [bool]$KillOneDrive = $false,
        [bool]$KillDefender = $false,
        [bool]$UseCustomInstaller = $false,
        [bool]$ApplyQoLTweaks = $false,
        [bool]$DisableIndexing = $false,
        [bool]$InstallOpenShell = $false
    )

    $ItemsToRemove = $ComponentData | Where-Object { $_.Action -eq $false }

    if ($ItemsToRemove.Count -eq 0) {
        Write-Host "SOV_CYAN:Nothing to remove! Ensure you have unchecked some items."
        return
    }

    if ([string]::IsNullOrWhiteSpace($WimPath) -or -not (Test-Path $WimPath)) {
        Write-Host "SOV_RED:Invalid WIM path provided."
        return
    }

    # Compile dynamic Scrub List for Phase 1 and WinPE chroot phase
    $DynamicScrubList = @()
    foreach ($item in $ItemsToRemove) {
        if ($item.Type -eq "AppxPackage") {
            $baseName = $item.Name.Split('_')[0]
            if (-not [string]::IsNullOrWhiteSpace($baseName) -and $baseName -notin $DynamicScrubList) {
                $DynamicScrubList += $baseName
            }
        }
    }

    # Auto-detect IsoRoot if the WIM is inside a standard Windows install structure (e.g., \sources\install.wim)
    if ($IsoRoot -eq "C:\Sovereign_ISORoot" -or [string]::IsNullOrWhiteSpace($IsoRoot)) {
        $parentDir = Split-Path $WimPath -Parent
        if ((Split-Path $parentDir -Leaf) -match '^(?i)sources$') {
            $detectedRoot = Split-Path $parentDir -Parent
            if (Test-Path "$detectedRoot\boot\etfsboot.com") {
                $IsoRoot = $detectedRoot
                Write-Host "SOV_CYAN:Auto-detected ISO Setup Root at: $IsoRoot"
            }
        }
    }

    # REAL BUILD MODE
    Write-Host "Verifying WIM mount state..."
    $activeMount = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $MountPath }

    if ($activeMount -and $activeMount.ImagePath -eq $WimPath) {
        Write-Host "SOV_GREEN:  -> WIM is already mounted at $MountPath. Reusing active session..."
    }
    else {
        $existingMounts = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.ImagePath -eq $WimPath -or $_.Path -eq $MountPath }
        foreach ($mount in $existingMounts) {
            Write-Host "SOV_YELLOW:  -> Force unmounting orphaned session at $($mount.Path)..."
            try {
                Dismount-WindowsImage -Path $mount.Path -Discard -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Host "SOV_RED:  [!] DISMOUNT FAILED: $($_.Exception.Message)"
                Write-Host "SOV_YELLOW:  [!] Close all File Explorer windows, VS Code, or Terminals looking at $($mount.Path), then try again."
                return
            }
        }

        Write-Host "SOV_CYAN:  -> Deep cleaning DISM registry locks..."
        try { & dism.exe /Cleanup-Wim | Out-Null } catch {}
        try { Clear-WindowsCorruptMountPoint -ErrorAction SilentlyContinue | Out-Null } catch {}

        if (Test-Path $MountPath) {
            cmd.exe /c "rmdir /s /q `"$MountPath`"" | Out-Null
        }

        $stuckMount = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.ImagePath -eq $WimPath }
        if ($stuckMount) {
            Write-Host "SOV_RED:  [!] WIM is still locked by Windows. A PC restart may be required."
            return
        }

        if (-not (Test-Path $MountPath)) { New-Item -ItemType Directory -Path $MountPath | Out-Null }

        # Ensure the WIM is not Read-Only
        $wimFile = Get-Item -Path $WimPath
        if ($wimFile.IsReadOnly) {
            Write-Host "SOV_CYAN:  -> Removing Read-Only attribute from WIM file..."
            $wimFile.IsReadOnly = $false
        }

        Write-Host "SOV_CYAN:Mounting $WimPath (Index $WimIndex) to $MountPath for modification..."
        Mount-WindowsImage -ImagePath $WimPath -Index $WimIndex -Path $MountPath | Out-Null
        Write-Host "SOV_GREEN:Mounted $WimPath successfully."
    }

    Write-Host "SOV_CYAN:Unlocking Permanent Packages in CBS Registry..."
    $SoftwareHive = Join-Path $MountPath "Windows\System32\config\SOFTWARE"
    & reg.exe load "HKLM\SovereignCBS" "$SoftwareHive" 2>&1 | Out-Null
    New-PSDrive -Name HK_SovCBS -PSProvider Registry -Root "HKEY_LOCAL_MACHINE\SovereignCBS" -ErrorAction Ignore *>&1 | Out-Null

    $cbsPackagesPath = "HK_SovCBS:\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages"
    $adminAccount = [System.Security.Principal.NTAccount]"Administrators"
    $accessRule = New-Object System.Security.AccessControl.RegistryAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")

    foreach ($item in $ItemsToRemove) {
        if ($item.Type -eq "Package") {
            $pkgKey = Join-Path $cbsPackagesPath $item.Name
            if (Test-Path $pkgKey) {
                try {
                    $acl = Get-Acl -Path $pkgKey
                    $acl.SetOwner($adminAccount)
                    Set-Acl -Path $pkgKey -AclObject $acl

                    $acl = Get-Acl -Path $pkgKey
                    $acl.SetAccessRule($accessRule)
                    Set-Acl -Path $pkgKey -AclObject $acl

                    Remove-ItemProperty -Path $pkgKey -Name "Visibility" -ErrorAction SilentlyContinue

                    $ownersKey = Join-Path $pkgKey "Owners"
                    if (Test-Path $ownersKey) {
                        $aclOwn = Get-Acl -Path $ownersKey
                        $aclOwn.SetOwner($adminAccount)
                        Set-Acl -Path $ownersKey -AclObject $aclOwn

                        $aclOwn = Get-Acl -Path $ownersKey
                        $aclOwn.SetAccessRule($accessRule)
                        Set-Acl -Path $ownersKey -AclObject $aclOwn

                        Remove-Item -Path $ownersKey -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Write-Host "SOV_DARKGRAY:  -> Unlocked CBS Package: $($item.Name)"
                }
                catch {}
            }
        }
    }

    Remove-PSDrive -Name HK_SovCBS -ErrorAction Ignore *>&1 | Out-Null
    [gc]::Collect()
    [gc]::WaitForPendingFinalizers()
    Start-Sleep -Seconds 1
    & reg.exe unload "HKLM\SovereignCBS" 2>&1 | Out-Null

    Write-Host "Beginning Surgical Subtraction..."
    $totalRemovals = $ItemsToRemove.Count
    $currentRemoval = 0
    foreach ($item in $ItemsToRemove) {
        $currentRemoval++
        Write-Host "SOV_YELLOW:  -> Removing [$currentRemoval/$totalRemovals] $($item.Type): $($item.DisplayName)..."
        try {
            switch ($item.Type) {
                "Capability" { Remove-WindowsCapability -Name $item.Name -Path $MountPath -ErrorAction Stop }
                "OptionalFeature" { Disable-WindowsOptionalFeature -FeatureName $item.Name -Path $MountPath -Remove -ErrorAction Stop }
                "AppxPackage" {
                    $dismOut = & dism.exe /Image:"$MountPath" /Remove-ProvisionedAppxPackage /PackageName:"$($item.Name)" 2>&1
                    if ($LASTEXITCODE -ne 0) { throw (($dismOut | Where-Object { $_ -match '\S' }) -join " | ") }
                }
                "Package" {
                    try {
                        Remove-WindowsPackage -PackageName $item.Name -Path $MountPath -ErrorAction Stop
                    }
                    catch {
                        $pkgFeatures = Get-WindowsOptionalFeature -Path $MountPath -PackageName $item.Name -ErrorAction SilentlyContinue
                        if ($pkgFeatures) {
                            Write-Host "SOV_YELLOW:  -> Package locked from physical removal. Disabling embedded features instead..."
                            foreach ($pf in $pkgFeatures) {
                                Disable-WindowsOptionalFeature -FeatureName $pf.FeatureName -Path $MountPath -ErrorAction SilentlyContinue | Out-Null
                            }
                        }
                        else {
                            throw $_
                        }
                    }
                }
            }
        }
        catch {
            Write-Host "SOV_DARKRED:Failed to remove $($item.Name): $($_.Exception.Message)"
        }
    }

    if ($ApplyRegionPolicy) {
        $System32PolicyPath = Join-Path $MountPath "Windows\System32\IntegratedServicesRegionPolicySet.json"
        if (Test-Path $System32PolicyPath) {
            # Generate an array of all 249 ISO 3166-1 alpha-2 country codes
            $AllCountries = "AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW" -split " "

            $PolicyHash = [ordered]@{
                SystemComponentsUninstall       = @{ defaultState = "enabled"; conditions = @{ region = $AllCountries } }
                TaskbarSearchThirdPartyProvider = @{ defaultState = "enabled"; conditions = @{ region = $AllCountries } }
                WidgetsThirdPartyProvider       = @{ defaultState = "enabled"; conditions = @{ region = $AllCountries } }
                StartMenuThirdPartyProvider     = @{ defaultState = "enabled"; conditions = @{ region = $AllCountries } }
                ThirdPartyFeedProvider          = @{ defaultState = "enabled"; conditions = @{ region = $AllCountries } }
                ShowLocalAccountOnOobe          = @{ defaultState = "enabled"; conditions = @{ region = $AllCountries } }
            }

            if ($KillEdge) { $PolicyHash["EdgeUninstall"] = @{ defaultState = "enabled"; conditions = @{ region = $AllCountries } } }
            if ($KillCopilot) { $PolicyHash["Copilot"] = @{ defaultState = "disabled"; conditions = @{ region = $AllCountries } } }
            if ($KillRecall) { $PolicyHash["Recall"] = @{ defaultState = "disabled"; conditions = @{ region = $AllCountries } } }
            if ($KillWebSearch) { $PolicyHash["TaskbarWebSearch"] = @{ defaultState = "enabled"; conditions = @{ region = $AllCountries } } }
            if ($KillCampaigns) { $PolicyHash["CampaignSegmentTargeting"] = @{ defaultState = "disabled"; conditions = @{ region = $AllCountries } } }
            if ($KillPromos) { $PolicyHash["FullScreenPromotionalSurface"] = @{ defaultState = "disabled"; conditions = @{ region = $AllCountries } } }
            if ($KillOneDrive) { $PolicyHash["OneDrive"] = @{ defaultState = "disabled"; conditions = @{ region = $AllCountries } } }

            $RegionPolicyJson = @{
                '$schema' = "https://developer.microsoft.com/en-us/json-schemas/windows/integratedservicesregionpolicyset/1.0.0/schema.json"
                policies  = $PolicyHash
            } | ConvertTo-Json -Depth 10

            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            $TempMasterPolicyPath = Join-Path $env:TEMP "MasterRegionPolicy.json"
            [System.IO.File]::WriteAllText($TempMasterPolicyPath, $RegionPolicyJson, $utf8NoBom)

            Write-Host "SOV_CYAN:Injecting Sovereign Master Region Policy directly into WIM..."
            Get-ChildItem -Path (Join-Path $MountPath "Windows\System32"), (Join-Path $MountPath "Windows\WinSxS") -Filter 'IntegratedServicesRegionPolicySet.json' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                Write-Host "SOV_DARKGRAY:  -> Overwriting $($_.FullName)"
                takeown.exe /f $_.FullName /a | Out-Null
                icacls.exe $_.FullName /grant '*S-1-5-32-544:F' /q | Out-Null
                Copy-Item -Path $TempMasterPolicyPath -Destination $_.FullName -Force -ErrorAction SilentlyContinue
            }
            Remove-Item -Path $TempMasterPolicyPath -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "SOV_CYAN:Optimizing Component Store (ResetBase)... This may take several minutes."
    try {
        $cleanupProc = Start-Process -FilePath "dism.exe" -ArgumentList "/Image:`"$MountPath`" /Cleanup-Image /StartComponentCleanup /ResetBase" -Wait -NoNewWindow -PassThru
        if ($cleanupProc.ExitCode -eq 0) {
            Write-Host "SOV_GREEN:  -> Component store optimization successful."
        }
        else {
            Write-Host "SOV_YELLOW:  [!] Component cleanup returned exit code $($cleanupProc.ExitCode)."
        }
    }
    catch {
        Write-Host "SOV_YELLOW:  [!] Component store optimization failed: $($_.Exception.Message)"
    }

    Write-Host "SOV_CYAN:Executing Deep Physical File Removals..."
    $HitList = @()
    if ($DynamicScrubList.Count -gt 0) { $HitList += $DynamicScrubList }

    $StandaloneFiles = @()
    if ($KillEdge) {
        $HitList += "microsoft-edge", "msedge", "EdgeCore", "EdgeUpdate"
        $StandaloneFiles += @(
            "Users\Public\Desktop\Microsoft Edge.lnk",
            "ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "Users\Default\Desktop\Microsoft Edge.lnk",
            "Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "Users\Default\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk"
        )
    }

    if ($KillCopilot) {
        $HitList += "copilot"
    }

    if ($KillRecall) {
        $HitList += "recall", "windowsai"
    }

    if ($KillOneDrive) {
        $HitList += "onedrive"
        $StandaloneFiles += @(
            "Windows\System32\OneDriveSetup.exe",
            "Windows\SysWOW64\OneDriveSetup.exe"
        )
    }

    if ($KillDefender) {
        $HitList += "windows-defender", "windows defender"
    }

    if ($DynamicScrubList -contains "Microsoft.WindowsCalculator") {
        $StandaloneFiles += @("Windows\System32\calc.exe", "Windows\SysWOW64\calc.exe")
    }
    if ($DynamicScrubList -contains "Microsoft.WindowsNotepad") {
        $StandaloneFiles += @("Windows\System32\notepad.exe", "Windows\SysWOW64\notepad.exe")
    }
    if ($DynamicScrubList -contains "Microsoft.Paint") {
        $StandaloneFiles += @("Windows\System32\mspaint.exe", "Windows\SysWOW64\mspaint.exe")
    }

    # Execute the High-Speed Scan
    if ($HitList.Count -gt 0) {
        Invoke-DeepStateResolution -MountPath $MountPath -Keywords $HitList
    }

    if ($StandaloneFiles.Count -gt 0) {
        Write-Host "SOV_DARKGRAY:  -> Cleaning up standalone files and shortcuts..."
        foreach ($file in $StandaloneFiles) {
            $target = Join-Path $MountPath $file
            if ($target -and (Test-Path $target)) {
                takeown.exe /f $target /a /r /d y *>&1 | Out-Null
                icacls.exe $target /grant '*S-1-5-32-544:F' /t /c /q *>&1 | Out-Null
                Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host "SOV_CYAN:Applying Offline Registry Policies to WIM..."
    $SoftwareHive = Join-Path $MountPath "Windows\System32\config\SOFTWARE"
    $SystemHive = Join-Path $MountPath "Windows\System32\config\SYSTEM"
    $DefaultUserHive = Join-Path $MountPath "Users\Default\NTUSER.DAT"
    $sysHiveLoaded = $false
    $systemHiveLoaded = $false
    $defUserHiveLoaded = $false
    try {
        & reg.exe load "HKLM\SovereignOfflineSoftware" "$SoftwareHive" *>&1 | Out-Null
        $sysHiveLoaded = $true
        & reg.exe load "HKLM\SovereignOfflineSystem" "$SystemHive" *>&1 | Out-Null
        $systemHiveLoaded = $true
        & reg.exe load "HKU\SovereignOfflineDefaultUser" "$DefaultUserHive" *>&1 | Out-Null
        $defUserHiveLoaded = $true

        New-PSDrive -Name HK_OfflineSoftware -PSProvider Registry -Root "HKEY_LOCAL_MACHINE\SovereignOfflineSoftware" -ErrorAction Ignore *>&1 | Out-Null
        New-PSDrive -Name HK_OfflineUser -PSProvider Registry -Root "HKEY_USERS\SovereignOfflineDefaultUser" -ErrorAction Ignore *>&1 | Out-Null

        $ScanAndScrub = {
            param([string]$Pattern)
            $adminAccount = [System.Security.Principal.NTAccount]"Administrators"
            $accessRule = New-Object System.Security.AccessControl.RegistryAccessRule("Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
            $ScrubRoots = @(
                "HK_OfflineSoftware:\Microsoft\Windows\CurrentVersion\Uninstall",
                "HK_OfflineSoftware:\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                "HK_OfflineSoftware:\Microsoft\Windows\CurrentVersion\App Paths",
                "HK_OfflineSoftware:\Clients\StartMenuInternet",
                "HK_OfflineSoftware:\Microsoft\Active Setup\Installed Components",
                "HK_OfflineSoftware:\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Applications",
                "HK_OfflineSoftware:\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\EndOfLife",
                "HK_OfflineSoftware:\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\InboxApplications",
                "HK_OfflineUser:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
                "HK_OfflineUser:\Software\Microsoft\Windows\CurrentVersion\App Paths",
                "HK_OfflineUser:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages"
            )
            foreach ($root in $ScrubRoots) {
                if (Test-Path $root) {
                    Get-ChildItem -Path $root -ErrorAction Ignore | ForEach-Object {
                        $keyName = $_.PSChildName
                        $displayName = (Get-ItemProperty -Path $_.PSPath -Name "DisplayName" -ErrorAction Ignore).DisplayName
                        if ($keyName -match $Pattern -or $displayName -match $Pattern) {
                            try {
                                $acl = Get-Acl -Path $_.PSPath -ErrorAction Ignore
                                $acl.SetOwner($adminAccount)
                                Set-Acl -Path $_.PSPath -AclObject $acl -ErrorAction Ignore
                                $acl = Get-Acl -Path $_.PSPath -ErrorAction Ignore
                                $acl.SetAccessRule($accessRule)
                                Set-Acl -Path $_.PSPath -AclObject $acl -ErrorAction Ignore
                            }
                            catch {}
                            Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction Ignore *>&1 | Out-Null
                        }
                    }
                }
            }
        }

        Write-Host "SOV_DARKGRAY:  -> Injecting Windows Consumer Features Kill Policy..."
        & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f *>&1 | Out-Null

        Write-Host "SOV_DARKGRAY:  -> Injecting OOBE BypassNRO Policy..."
        & reg.exe add "HKLM\SovereignOfflineSoftware\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f *>&1 | Out-Null

        if ($DisableUCPD) {
            Write-Host "SOV_DARKGRAY:  -> Disabling UCPD Driver in SYSTEM Hive..."
            & reg.exe add "HKLM\SovereignOfflineSystem\ControlSet001\Services\UCPD" /v Start /t REG_DWORD /d 4 /f *>&1 | Out-Null
        }

        Write-Host "SOV_DARKGRAY:  -> Injecting PowerShell Execution Policy (RemoteSigned)..."
        & reg.exe add "HKLM\SovereignOfflineSoftware\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" /v ExecutionPolicy /t REG_SZ /d "RemoteSigned" /f *>&1 | Out-Null

        if ($KillCopilot) {
            Write-Host "SOV_DARKGRAY:  -> Injecting Windows Copilot Kill Policy..."
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKU\SovereignOfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCopilotButton /t REG_DWORD /d 0 /f *>&1 | Out-Null
            Write-Host "SOV_DARKGRAY:  -> Scanning and scrubbing Copilot traces..."
            &$ScanAndScrub -Pattern '(?i)copilot'
        }

        if ($KillRecall) {
            Write-Host "SOV_DARKGRAY:  -> Injecting Windows Recall (AI) Kill Policy..."
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSystem\ControlSet001\Services\WSService" /v Start /t REG_DWORD /d 4 /f *>&1 | Out-Null
            Write-Host "SOV_DARKGRAY:  -> Scanning and scrubbing Recall traces..."
            &$ScanAndScrub -Pattern '(?i)(recall|windowsai)'
        }

        if ($KillEdge) {
            Write-Host "SOV_DARKGRAY:  -> Injecting Edge Chromium Kill Policy..."
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\EdgeUpdate" /v DoNotUpdateToEdgeWithChromium /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\EdgeUpdate" /v CreateDesktopShortcutDefault /t REG_DWORD /d 0 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\EdgeUpdate" /v RemoveDesktopShortcutDefault /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\MicrosoftEdge\Main" /v AllowPrelaunch /t REG_DWORD /d 0 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\MicrosoftEdge\TabPreloader" /v AllowTabPreloading /t REG_DWORD /d 0 /f *>&1 | Out-Null

            Write-Host "SOV_DARKGRAY:  -> Scanning and scrubbing Edge traces from Installed Apps (Registry)..."
            &$ScanAndScrub -Pattern '(?i)(microsoft\s*edge|msedge)'
        }

        if ($WuMode -eq "Security") {
            Write-Host "SOV_DARKGRAY:  -> Injecting Security Updates Only Policy..."
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate" /v DeferFeatureUpdates /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate" /v DeferFeatureUpdatesPeriodInDays /t REG_DWORD /d 365 /f *>&1 | Out-Null
        }
        elseif ($WuMode -eq "Disable") {
            Write-Host "SOV_DARKGRAY:  -> Injecting Completely Disable Updates Policy..."
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Microsoft\WindowsUpdate\UX\Settings" /v PauseFeatureUpdatesStartTime /t REG_SZ /d "2024-01-01T00:00:00Z" /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Microsoft\WindowsUpdate\UX\Settings" /v PauseFeatureUpdatesEndTime /t REG_SZ /d "2099-12-31T00:00:00Z" /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Microsoft\WindowsUpdate\UX\Settings" /v PauseQualityUpdatesStartTime /t REG_SZ /d "2024-01-01T00:00:00Z" /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Microsoft\WindowsUpdate\UX\Settings" /v PauseQualityUpdatesEndTime /t REG_SZ /d "2099-12-31T00:00:00Z" /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Microsoft\WindowsUpdate\UX\Settings" /v PauseUpdatesExpiryTime /t REG_SZ /d "2099-12-31T00:00:00Z" /f *>&1 | Out-Null

            Write-Host "SOV_DARKGRAY:  -> Disabling Windows Update Services in SYSTEM Hive..."
            & reg.exe add "HKLM\SovereignOfflineSystem\ControlSet001\Services\wuauserv" /v Start /t REG_DWORD /d 4 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSystem\ControlSet001\Services\UsoSvc" /v Start /t REG_DWORD /d 4 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSystem\ControlSet001\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f *>&1 | Out-Null
        }

        if ($DisableIndexing) {
            Write-Host "SOV_DARKGRAY:  -> Disabling Windows Search Indexing Service in SYSTEM Hive..."
            & reg.exe add "HKLM\SovereignOfflineSystem\ControlSet001\Services\WSearch" /v Start /t REG_DWORD /d 4 /f *>&1 | Out-Null
        }

        if ($KillDefender) {
            Write-Host "SOV_DARKGRAY:  -> Disabling Windows Defender Services and Policies..."
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows Defender" /v DisableAntiVirus /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableScanOnRealtimeEnable /t REG_DWORD /d 1 /f *>&1 | Out-Null

            $DefenderServices = @("WinDefend", "WdNisSvc", "Sense", "SecurityHealthService", "wscsvc")
            foreach ($svc in $DefenderServices) {
                & reg.exe add "HKLM\SovereignOfflineSystem\ControlSet001\Services\$svc" /v Start /t REG_DWORD /d 4 /f *>&1 | Out-Null
            }
        }

        if ($KillOneDrive) {
            Write-Host "SOV_DARKGRAY:  -> Injecting OneDrive Kill Policy and scrubbing Run keys..."
            & reg.exe add "HKLM\SovereignOfflineSoftware\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe delete "HKU\SovereignOfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDriveSetup /f *>&1 | Out-Null
            & reg.exe add "HKU\SovereignOfflineDefaultUser\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f *>&1 | Out-Null
            Write-Host "SOV_DARKGRAY:  -> Scanning and scrubbing OneDrive traces..."
            &$ScanAndScrub -Pattern '(?i)onedrive'
        }

        if ($DynamicScrubList.Count -gt 0) {
            Write-Host "SOV_DARKGRAY:  -> Scanning and scrubbing Appx traces from Offline Registry..."
            foreach ($appName in $DynamicScrubList) {
                &$ScanAndScrub -Pattern "(?i)$appName"
            }
        }

        if ($ApplyQoLTweaks) {
            Write-Host "SOV_DARKGRAY:  -> Injecting Quality of Life Explorer Tweaks..."
            & reg.exe add "HKU\SovereignOfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 0 /f *>&1 | Out-Null
            & reg.exe add "HKU\SovereignOfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f *>&1 | Out-Null
            & reg.exe add "HKU\SovereignOfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f *>&1 | Out-Null
            & reg.exe add "HKU\SovereignOfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f *>&1 | Out-Null
            & reg.exe add "HKU\SovereignOfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v TaskbarEndTask /t REG_DWORD /d 1 /f *>&1 | Out-Null
            Write-Host "SOV_DARKGRAY:  -> Injecting Classic Context Menu Policy..."
            & reg.exe add "HKU\SovereignOfflineDefaultUser\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /t REG_SZ /d "" /f *>&1 | Out-Null

            Write-Host "SOV_DARKGRAY:  -> Securing Tweaks via First-Logon RunOnce..."
            & reg.exe add "HKU\SovereignOfflineDefaultUser\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "SovereignContextMenu" /t REG_SZ /d "cmd.exe /c reg.exe add `"HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32`" /ve /f" /f *>&1 | Out-Null
        }
    }
    catch {
        Write-Host "SOV_YELLOW:  [!] Failed to apply offline registry keys: $($_.Exception.Message)"
    }
    finally {
        Remove-PSDrive -Name HK_OfflineSoftware -ErrorAction Ignore *>&1 | Out-Null
        Remove-PSDrive -Name HK_OfflineUser -ErrorAction Ignore *>&1 | Out-Null
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
        Start-Sleep -Seconds 1
        if ($sysHiveLoaded) {
            & reg.exe unload "HKLM\SovereignOfflineSoftware" *>&1 | Out-Null
        }
        if ($systemHiveLoaded) {
            & reg.exe unload "HKLM\SovereignOfflineSystem" *>&1 | Out-Null
        }
        if ($defUserHiveLoaded) {
            & reg.exe unload "HKU\SovereignOfflineDefaultUser" *>&1 | Out-Null
        }
    }

    Write-Host "SOV_CYAN:Committing changes and dismounting WIM (This may take a while)..."
    try {
        Dismount-WindowsImage -Path $MountPath -Save -ErrorAction Stop
        Write-Host "SOV_GREEN:WIM dismounted and saved successfully."
    }
    catch {
        Write-Host "SOV_RED:Dismount Failed: $($_.Exception.Message)"
        Write-Host "SOV_YELLOW:Running cleanup to prevent ghost mounts..."
        try { & dism.exe /Cleanup-Wim | Out-Null } catch {}
        try { Clear-WindowsCorruptMountPoint -ErrorAction SilentlyContinue | Out-Null } catch {}
        return
    }

    Write-Host "SOV_CYAN:Exporting WIM to reclaim space (Slimming Image)..."
    $ExportedWimPath = Join-Path (Split-Path $WimPath -Parent) "install_slim.wim"
    if (Test-Path $ExportedWimPath) { Remove-Item -Path $ExportedWimPath -Force -ErrorAction SilentlyContinue }

    Write-Host "SOV_CYAN:  -> Exporting image (This will take a while)..."
    $exportProc = Start-Process -FilePath "dism.exe" -ArgumentList "/Export-Image /SourceImageFile:`"$WimPath`" /SourceIndex:$WimIndex /DestinationImageFile:`"$ExportedWimPath`"" -Wait -NoNewWindow -PassThru

    $TargetInstallIndex = $WimIndex
    if ($exportProc.ExitCode -eq 0 -and (Test-Path $ExportedWimPath)) {
        Write-Host "SOV_GREEN:  -> Export successful! Replacing original WIM..."
        Remove-Item -Path $WimPath -Force -ErrorAction SilentlyContinue
        Rename-Item -Path $ExportedWimPath -NewName (Split-Path $WimPath -Leaf) -Force -ErrorAction SilentlyContinue
        $TargetInstallIndex = 1
    }
    else {
        Write-Host "SOV_YELLOW:  [!] Export failed or was skipped. Using original WIM size."
    }

    Write-Host "SOV_CYAN:Staging SetupComplete.cmd for post-OOBE enforcement..."
    $oemScriptsPath = Join-Path $IsoRoot 'sources\$OEM$\$$\Setup\Scripts'
    if (-not (Test-Path $oemScriptsPath)) {
        New-Item -ItemType Directory -Path $oemScriptsPath -Force | Out-Null
    }
    $setupCompletePath = Join-Path $oemScriptsPath "SetupComplete.cmd"

    $scContent = "@echo off`r`n"
    $scContent += "echo Enforcing Sovereign Policies (SetupComplete)...`r`n"
    $scContent += "reg add `"HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent`" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1`r`n"

    if ($DisableUCPD) {
        $scContent += "reg add `"HKLM\SYSTEM\CurrentControlSet\Services\UCPD`" /v Start /t REG_DWORD /d 4 /f >nul 2>&1`r`n"
    }
    if ($WuMode -eq "Disable") {
        $scContent += "reg add `"HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul 2>&1`r`n"
        $scContent += "reg add `"HKLM\SYSTEM\CurrentControlSet\Services\wuauserv`" /v Start /t REG_DWORD /d 4 /f >nul 2>&1`r`n"
    }

    $scContent += "echo Processing Zero-Touch Application Provisioning...`r`n"
    $scContent += "if exist `"%WINDIR%\Setup\Apps`" (`r`n"
    $scContent += "    for %%f in (`"%WINDIR%\Setup\Apps\*.exe`") do (`r`n"
    $scContent += "        start /wait `"`" `"%%f`" /S /quiet /qn`r`n"
    $scContent += "    )`r`n"
    $scContent += "    for %%f in (`"%WINDIR%\Setup\Apps\*.msi`") do (`r`n"
    $scContent += "        start /wait msiexec.exe /i `"%%f`" /qn /norestart`r`n"
    $scContent += "    )`r`n"
    $scContent += ")`r`n"

    if (Test-Path $setupCompletePath) {
        $scContent | Out-File -FilePath $setupCompletePath -Encoding ascii -Append
    }
    else {
        $scContent | Out-File -FilePath $setupCompletePath -Encoding ascii -Force
    }

    if ($InstallOpenShell) {
        Write-Host "SOV_CYAN:Acquiring Open-Shell for unattended installation..."
        $openShellExe = Get-OpenShell -ScriptDir $ScriptDir
        if ($openShellExe) {
            $oemScriptsPath = Join-Path $IsoRoot 'sources\$OEM$\$$\Setup\Scripts'
            if (-not (Test-Path $oemScriptsPath)) {
                New-Item -ItemType Directory -Path $oemScriptsPath -Force | Out-Null
            }
            Copy-Item -Path $openShellExe -Destination (Join-Path $oemScriptsPath "ClassicShellSetup.exe") -Force

            $setupCompletePath = Join-Path $oemScriptsPath "SetupComplete.cmd"
            $cmdContent = "echo Installing Open-Shell...`r`n"
            $cmdContent += "copy /y `"%~dp0ClassicShellSetup.exe`" `"%TEMP%\ClassicShellSetup.exe`" >nul 2>&1`r`n"
            $cmdContent += "start /wait `"`" `"%TEMP%\ClassicShellSetup.exe`" /qn ADDLOCAL=StartMenu /norestart`r`n"
            $cmdContent += "ping -n 3 127.0.0.1 >nul`r`n"
            $cmdContent += ":WaitOS`r`n"
            $cmdContent += "tasklist /FI `"IMAGENAME eq msiexec.exe`" 2>NUL | find /I `"msiexec.exe`" >NUL`r`n"
            $cmdContent += "if `"%ERRORLEVEL%`"==`"0`" (`r`n"
            $cmdContent += "    ping -n 3 127.0.0.1 >nul`r`n"
            $cmdContent += "    goto WaitOS`r`n"
            $cmdContent += ")`r`n"
            $cmdContent += "del /q `"%TEMP%\ClassicShellSetup.exe`" >nul 2>&1`r`n"
            if (Test-Path $setupCompletePath) {
                $cmdContent | Out-File -FilePath $setupCompletePath -Encoding ascii -Append
            }
            else {
                $cmdContent | Out-File -FilePath $setupCompletePath -Encoding ascii -Force
            }
            Write-Host "SOV_GREEN:  -> Open-Shell staged for installation (SetupComplete.cmd)."
        }
    }

    if (Get-Command New-SovereignUnattend -ErrorAction SilentlyContinue) {
        New-SovereignUnattend -OutputPath "$IsoRoot\autounattend.xml" -Username $Username -Password $Password -UseBuiltInAdmin $UseBuiltInAdmin -RemovedItems $ItemsToRemove -IsoRoot $IsoRoot -ApplyRegionPolicy $ApplyRegionPolicy -DisableUCPD $DisableUCPD -BypassTPM $BypassTPM -WuMode $WuMode -ApplyQoLTweaks $ApplyQoLTweaks
    }

    # Assemble final Scrub List for WinPE chroot phase
    $WinPeScrubList = @()
    $WinPeScrubList += $DynamicScrubList
    if ($KillEdge) { $WinPeScrubList += "microsoft-edge"; $WinPeScrubList += "msedge" }
    if ($KillCopilot) { $WinPeScrubList += "copilot" }
    if ($KillRecall) { $WinPeScrubList += "recall"; $WinPeScrubList += "windowsai" }
    if ($KillOneDrive) { $WinPeScrubList += "onedrive" }
    if ($KillDefender) { $WinPeScrubList += "windows-defender"; $WinPeScrubList += "windows defender" }

    $PsScrubString = if ($WinPeScrubList.Count -gt 0) { "`"" + ($WinPeScrubList -join "`", `"") + "`"" } else { "`"NONE`"" }
    $CmdScrubString = if ($WinPeScrubList.Count -gt 0) { "`"" + ($WinPeScrubList -join "`" `"") + "`"" } else { "`"NONE`"" }

    if ($UseCustomInstaller) {
        Write-Host "SOV_CYAN:Configuring Custom Sovereign Installer (boot.wim)..."
        $BootWimPath = Join-Path $IsoRoot "sources\boot.wim"
        $BootMountPath = Join-Path (Split-Path $MountPath -Parent) "Sovereign_BootMount"

        if (Test-Path $BootWimPath) {
            if (Test-Path $BootMountPath) {
                cmd.exe /c "rmdir /s /q `"$BootMountPath`"" | Out-Null
            }
            New-Item -ItemType Directory -Path $BootMountPath | Out-Null

            $BootWimFile = Get-Item -Path $BootWimPath
            if ($BootWimFile.IsReadOnly) { $BootWimFile.IsReadOnly = $false }

            Write-Host "SOV_CYAN:  -> Mounting boot.wim (Index 2)..."
            Mount-WindowsImage -ImagePath $BootWimPath -Index 2 -Path $BootMountPath | Out-Null

            Inject-WinPEOptionalComponents -BootMountPath $BootMountPath

            Write-Host "SOV_DARKGRAY:  -> Injecting winpeshl.ini and setup scripts..."

            # 1. winpeshl.ini (The Hook)
            $WinpeshlContent = @"
[LaunchApps]
"wpeinit.exe"
"X:\SovereignSetup.cmd"
"@
            $WinpeshlContent | Out-File -FilePath (Join-Path $BootMountPath "Windows\System32\winpeshl.ini") -Encoding ascii -Force

            # 2. SovereignSetup.ps1 (XAML GUI Installer)
            $SetupPs1Content = @'
Start-Transcript -Path "X:\SovereignInstall.log" -Force
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Sovereign OS Installer"
$form.WindowState = [System.Windows.Forms.FormWindowState]::Normal

$form.Size = New-Object System.Drawing.Size(850, 680)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$form.BackColor = [System.Drawing.Color]::FromArgb(255, 30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic).SetValue($form, $true, $null)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Sovereign OS Installation"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(255, 0, 122, 204)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Select the destination drive. WARNING: ALL DATA WILL BE ERASED."
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Regular)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(255, 212, 160, 23)
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(20, 70)
$form.Controls.Add($subtitle)

$locales = @(
    "English (United States) | en-US",
    "English (United Kingdom) | en-GB",
    "English (Australia) | en-AU",
    "English (Canada) | en-CA",
    "Spanish (Spain) | es-ES",
    "Spanish (Mexico) | es-MX",
    "French (France) | fr-FR",
    "French (Canada) | fr-CA",
    "German (Germany) | de-DE",
    "Italian (Italy) | it-IT",
    "Portuguese (Brazil) | pt-BR",
    "Portuguese (Portugal) | pt-PT",
    "Dutch (Netherlands) | nl-NL",
    "Japanese (Japan) | ja-JP",
    "Korean (Korea) | ko-KR",
    "Chinese (Simplified) | zh-CN"
)

$lblLang = New-Object System.Windows.Forms.Label
$lblLang.Text = "Language:"
$lblLang.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblLang.Location = New-Object System.Drawing.Point(20, 110)
$lblLang.AutoSize = $true
$form.Controls.Add($lblLang)

$CmbLang = New-Object System.Windows.Forms.ComboBox
$CmbLang.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$CmbLang.Width = 240
$CmbLang.Location = New-Object System.Drawing.Point(20, 135)
$CmbLang.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$locales | ForEach-Object { $CmbLang.Items.Add($_) | Out-Null }
$CmbLang.SelectedIndex = 0
$form.Controls.Add($CmbLang)

$lblTime = New-Object System.Windows.Forms.Label
$lblTime.Text = "Time & Currency Format:"
$lblTime.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblTime.Location = New-Object System.Drawing.Point(280, 110)
$lblTime.AutoSize = $true
$form.Controls.Add($lblTime)

$CmbTime = New-Object System.Windows.Forms.ComboBox
$CmbTime.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$CmbTime.Width = 240
$CmbTime.Location = New-Object System.Drawing.Point(280, 135)
$CmbTime.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$locales | ForEach-Object { $CmbTime.Items.Add($_) | Out-Null }
$CmbTime.SelectedIndex = 0
$form.Controls.Add($CmbTime)

$lblKeyb = New-Object System.Windows.Forms.Label
$lblKeyb.Text = "Keyboard / Input Method:"
$lblKeyb.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblKeyb.Location = New-Object System.Drawing.Point(540, 110)
$lblKeyb.AutoSize = $true
$form.Controls.Add($lblKeyb)

$CmbKeyb = New-Object System.Windows.Forms.ComboBox
$CmbKeyb.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$CmbKeyb.Width = 240
$CmbKeyb.Location = New-Object System.Drawing.Point(540, 135)
$CmbKeyb.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$locales | ForEach-Object { $CmbKeyb.Items.Add($_) | Out-Null }
$CmbKeyb.SelectedIndex = 0
$form.Controls.Add($CmbKeyb)

$DiskCombo = New-Object System.Windows.Forms.ComboBox
$DiskCombo.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Regular)
$DiskCombo.Width = 760
$DiskCombo.Location = New-Object System.Drawing.Point(20, 190)
$DiskCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($DiskCombo)

$chkAdvanced = New-Object System.Windows.Forms.CheckBox
$chkAdvanced.Text = "Advanced Mode (Manual Partitioning)"
$chkAdvanced.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$chkAdvanced.Location = New-Object System.Drawing.Point(20, 230)
$chkAdvanced.AutoSize = $true
$chkAdvanced.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($chkAdvanced)

$pnlAdvanced = New-Object System.Windows.Forms.Panel
$pnlAdvanced.Location = New-Object System.Drawing.Point(20, 270)
$pnlAdvanced.Size = New-Object System.Drawing.Size(740, 250)
$pnlAdvanced.Visible = $false
$form.Controls.Add($pnlAdvanced)

$listParts = New-Object System.Windows.Forms.ListView
$listParts.View = [System.Windows.Forms.View]::Details
$listParts.FullRowSelect = $true
$listParts.GridLines = $true
$listParts.Width = 580
$listParts.Height = 250
$listParts.Location = New-Object System.Drawing.Point(0, 0)
$listParts.BackColor = [System.Drawing.Color]::FromArgb(255, 40, 40, 40)
$listParts.ForeColor = [System.Drawing.Color]::White
$listParts.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$listParts.Columns.Add("Name", 300) | Out-Null
$listParts.Columns.Add("Total Size", 130) | Out-Null
$listParts.Columns.Add("Type", 120) | Out-Null
$pnlAdvanced.Controls.Add($listParts)

function Refresh-DiskList {
    $listParts.Items.Clear()
    $disks = Get-WmiObject Win32_DiskDrive
    foreach ($d in $disks) {
        $size = [math]::Round($d.Size / 1GB, 2)
        $item = New-Object System.Windows.Forms.ListViewItem("Drive $($d.Index) Unallocated Space")
        $item.SubItems.Add("$size GB") | Out-Null
        $item.SubItems.Add("Disk") | Out-Null
        $item.Tag = "Disk,$($d.Index)"
        $listParts.Items.Add($item) | Out-Null

        "select disk $($d.Index)`nlist partition" | Out-File "X:\dp_list.txt" -Encoding ascii
        $dpOut = diskpart /s X:\dp_list.txt
        foreach ($line in $dpOut) {
            if ($line -match "^\s*Partition\s+(\d+)\s+(.+?)\s+([0-9,.]+\s+[a-zA-Z]+)\s+([0-9,.]+\s+[a-zA-Z]+)") {
                $partNum = $matches[1]
                $partType = $matches[2].Trim()
                $partSize = $matches[3]
                $pitem = New-Object System.Windows.Forms.ListViewItem("  Partition $partNum")
                $pitem.SubItems.Add($partSize) | Out-Null
                $pitem.SubItems.Add($partType) | Out-Null
                $pitem.Tag = "Part,$($d.Index),$partNum"
                $listParts.Items.Add($pitem) | Out-Null
            }
        }
    }
}

$chkAdvanced.Add_CheckedChanged({
    $pnlAdvanced.Visible = $chkAdvanced.Checked
    $DiskCombo.Enabled = -not $chkAdvanced.Checked
    if ($chkAdvanced.Checked) { Refresh-DiskList }
})

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh"
$btnRefresh.Location = New-Object System.Drawing.Point(600, 0)
$btnRefresh.Width = 120
$btnRefresh.Height = 35
$btnRefresh.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$btnRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRefresh.Add_Click({ Refresh-DiskList })
$pnlAdvanced.Controls.Add($btnRefresh)

$btnNew = New-Object System.Windows.Forms.Button
$btnNew.Text = "New"
$btnNew.Location = New-Object System.Drawing.Point(600, 45)
$btnNew.Width = 120
$btnNew.Height = 35
$btnNew.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$btnNew.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnNew.Add_Click({
    if ($listParts.SelectedItems.Count -gt 0) {
        $tag = $listParts.SelectedItems[0].Tag -split ","
        if ($tag[0] -eq "Disk") {
            $res = [System.Windows.Forms.MessageBox]::Show("To ensure Windows features work correctly, Setup will create additional partitions for system files. Continue?", "Windows Setup", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Information)
            if ($res -eq 'Yes') {
                "select disk $($tag[1])`nclean`nconvert gpt`ncreate partition efi size=500`nformat quick fs=fat32 label=`"System`"`ncreate partition msr size=16`ncreate partition primary`nformat quick fs=ntfs label=`"Windows`"" | Out-File "X:\dp_new.txt" -Encoding ascii
                diskpart /s X:\dp_new.txt | Out-Null
                Refresh-DiskList
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Select an Unallocated Disk to create new partitions.", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        }
    }
})
$pnlAdvanced.Controls.Add($btnNew)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "Delete"
$btnDelete.Location = New-Object System.Drawing.Point(600, 90)
$btnDelete.Width = 120
$btnDelete.Height = 35
$btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$btnDelete.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnDelete.Add_Click({
    if ($listParts.SelectedItems.Count -gt 0) {
        $tag = $listParts.SelectedItems[0].Tag -split ","
        if ($tag[0] -eq "Part") {
            $res = [System.Windows.Forms.MessageBox]::Show("This partition might contain recovery files, system files, or important software. If you delete this partition, any data stored on it will be lost.", "Windows Setup", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($res -eq 'OK') {
                "select disk $($tag[1])`nselect partition $($tag[2])`ndelete partition override" | Out-File "X:\dp_del.txt" -Encoding ascii
                diskpart /s X:\dp_del.txt | Out-Null
                Refresh-DiskList
            }
        } elseif ($tag[0] -eq "Disk") {
            $res = [System.Windows.Forms.MessageBox]::Show("Erase all partitions on this disk?", "Warning", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($res -eq 'OK') {
                "select disk $($tag[1])`nclean" | Out-File "X:\dp_del.txt" -Encoding ascii
                diskpart /s X:\dp_del.txt | Out-Null
                Refresh-DiskList
            }
        }
    }
})
$pnlAdvanced.Controls.Add($btnDelete)

$btnFormat = New-Object System.Windows.Forms.Button
$btnFormat.Text = "Format"
$btnFormat.Location = New-Object System.Drawing.Point(600, 135)
$btnFormat.Width = 120
$btnFormat.Height = 35
$btnFormat.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$btnFormat.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnFormat.Add_Click({
    if ($listParts.SelectedItems.Count -gt 0) {
        $tag = $listParts.SelectedItems[0].Tag -split ","
        if ($tag[0] -eq "Part") {
            $res = [System.Windows.Forms.MessageBox]::Show("This partition might contain recovery files, system files, or important software. If you format this partition, any data stored on it will be lost.", "Windows Setup", [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($res -eq 'OK') {
                "select disk $($tag[1])`nselect partition $($tag[2])`nformat quick fs=ntfs" | Out-File "X:\dp_fmt.txt" -Encoding ascii
                diskpart /s X:\dp_fmt.txt | Out-Null
                [System.Windows.Forms.MessageBox]::Show("Partition formatted successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                Refresh-DiskList
            }
        }
    }
})
$pnlAdvanced.Controls.Add($btnFormat)

$btnLoadDriver = New-Object System.Windows.Forms.Button
$btnLoadDriver.Text = "Load Driver"
$btnLoadDriver.Location = New-Object System.Drawing.Point(600, 180)
$btnLoadDriver.Width = 120
$btnLoadDriver.Height = 35
$btnLoadDriver.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$btnLoadDriver.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnLoadDriver.Add_Click({
    $fd = New-Object System.Windows.Forms.OpenFileDialog
    $fd.Filter = "Setup Information File (*.inf)|*.inf"
    $fd.AutoUpgradeEnabled = $false
    $fd.Title = "Select Driver INF File"
    if ($fd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $drv = Start-Process "drvload.exe" -ArgumentList "`"$($fd.FileName)`"" -Wait -PassThru -WindowStyle Hidden
        if ($drv.ExitCode -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Driver loaded successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            Refresh-DiskList
        } else {
            [System.Windows.Forms.MessageBox]::Show("Failed to load driver.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    }
})
$pnlAdvanced.Controls.Add($btnLoadDriver)

$BtnInstall = New-Object System.Windows.Forms.Button
$BtnInstall.Text = "Install Sovereign OS"
$BtnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Regular)
$BtnInstall.BackColor = [System.Drawing.Color]::FromArgb(255, 0, 122, 204)
$BtnInstall.ForeColor = [System.Drawing.Color]::White
$BtnInstall.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$BtnInstall.FlatAppearance.BorderSize = 0
$BtnInstall.Cursor = [System.Windows.Forms.Cursors]::Hand
$BtnInstall.AutoSize = $true
$BtnInstall.Padding = New-Object System.Windows.Forms.Padding(20, 10, 20, 10)
$BtnInstall.Location = New-Object System.Drawing.Point(500, 480)
$form.Controls.Add($BtnInstall)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 16)
$lblStatus.ForeColor = [System.Drawing.Color]::White
$lblStatus.AutoSize = $true
$lblStatus.Location = New-Object System.Drawing.Point(20, 250)
$lblStatus.Visible = $false
$form.Controls.Add($lblStatus)

$progBar = New-Object System.Windows.Forms.ProgressBar
$progBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$progBar.Width = 600
$progBar.Height = 30
$progBar.Location = New-Object System.Drawing.Point(20, 300)
$progBar.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$progBar.Visible = $false
$form.Controls.Add($progBar)

$form.Add_Load({
    $BtnInstall.Location = New-Object System.Drawing.Point($($form.ClientSize.Width - $BtnInstall.Width - 20), $($form.ClientSize.Height - $BtnInstall.Height - 20))
    $BtnInstall.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
})

$script:SelectedDisk = -1
$script:SelectedPartition = -1
$script:AdvancedMode = $false

try {
    $disks = Get-WmiObject Win32_DiskDrive -ErrorAction Stop
    foreach ($d in $disks) {
        $size = [math]::Round($d.Size / 1GB, 2)
        $DiskCombo.Items.Add("Disk $($d.Index) - $($d.Model) ($size GB)") | Out-Null
    }
    if ($DiskCombo.Items.Count -gt 0) { $DiskCombo.SelectedIndex = 0 }
} catch {
    0..4 | ForEach-Object { $DiskCombo.Items.Add("Disk $_") | Out-Null }
    $DiskCombo.SelectedIndex = 0
}

$BtnInstall.Add_Click({
    $script:AdvancedMode = $chkAdvanced.Checked
    if ($script:AdvancedMode) {
        if ($listParts.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a target Partition to install to.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            return
        }
        $tag = $listParts.SelectedItems[0].Tag -split ","
        if ($tag[0] -ne "Part") {
            [System.Windows.Forms.MessageBox]::Show("You must select a specific Partition (not Unallocated Space) in Advanced Mode.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }
        $script:SelectedDisk = $tag[1]
        $script:SelectedPartition = $tag[2]
    } else {
        if ($DiskCombo.SelectedIndex -eq -1) {
            [System.Windows.Forms.MessageBox]::Show("Please select a disk first.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            return
        }
        $selectedStr = $DiskCombo.SelectedItem.ToString()
        $script:SelectedDisk = if ($selectedStr -match "Disk (\d+)") { $matches[1] } else { 0 }
    }

    # Transition UI to Installation Mode
        $form.Hide()
    [System.Windows.Forms.Application]::DoEvents()

    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host "      Sovereign OS - Installation Phase" -ForegroundColor Cyan
    Write-Host "===================================================`n" -ForegroundColor Cyan

    if ($script:AdvancedMode) {
            $lblStatus.Text = "Preparing Selected Partition (Advanced Mode)..."
            [System.Windows.Forms.Application]::DoEvents()
        Write-Host "[*] Preparing Selected Partition (Advanced Mode)..." -ForegroundColor Yellow
        $dpScript = "select disk $($script:SelectedDisk)`nselect partition $($script:SelectedPartition)`nassign letter=W`n"
        $dpScript | Out-File "X:\dp.txt" -Encoding ascii
        $dpOut1 = & diskpart.exe /s X:\dp.txt 2>&1
        $dpOut1 | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }

        $efiIndex = 1
        "select disk $($script:SelectedDisk)`nlist partition" | Out-File "X:\dp_efifind.txt" -Encoding ascii
        $dpList = diskpart /s X:\dp_efifind.txt
        foreach ($line in $dpList) {
            if ($line -match "^\s*Partition\s+(\d+)\s+System") { $efiIndex = $matches[1]; break }
        }
        $dpEfi = "select disk $($script:SelectedDisk)`nselect partition $efiIndex`nassign letter=S`n"
        $dpEfi | Out-File "X:\dp_efi.txt" -Encoding ascii
        $dpOut2 = & diskpart.exe /s X:\dp_efi.txt 2>&1
        $dpOut2 | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
    } else {
            $lblStatus.Text = "Partitioning drive (Basic Mode)..."
            [System.Windows.Forms.Application]::DoEvents()
        Write-Host "[*] Partitioning drive (Basic Mode)..." -ForegroundColor Yellow
        $dpScript = "select disk $($script:SelectedDisk)`nclean`nconvert gpt`ncreate partition efi size=500`nformat quick fs=fat32 label=`"System`"`nassign letter=S`ncreate partition msr size=16`ncreate partition primary`nformat quick fs=ntfs label=`"Windows`"`nassign letter=W`n"
        $dpScript | Out-File "X:\dp.txt" -Encoding ascii
        $dpOut3 = & diskpart.exe /s X:\dp.txt 2>&1
        $dpOut3 | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
    }

        $lblStatus.Text = "Locating installation media..."
        [System.Windows.Forms.Application]::DoEvents()
    Write-Host "`n[*] Locating installation media..." -ForegroundColor Yellow
    $installMedia = $null
    foreach ($drive in (67..90 | ForEach-Object { [char]$_ + ":" })) {
        if (Test-Path "$drive\sources\install.wim") { $installMedia = $drive; break }
        if (Test-Path "$drive\sources\install.esd") { $installMedia = $drive; break }
    }

    if (-not $installMedia) {
        [System.Windows.Forms.MessageBox]::Show("CRITICAL ERROR: Install media not found!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            $form.Show()
        return
    }
    $wimPath = if (Test-Path "$installMedia\sources\install.wim") { "$installMedia\sources\install.wim" } else { "$installMedia\sources\install.esd" }

        $lblStatus.Text = "Extracting Sovereign OS (0%)..."
        [System.Windows.Forms.Application]::DoEvents()
    Write-Host "`n[*] Extracting Sovereign OS (This will take a while)..." -ForegroundColor Yellow
        & dism.exe /English /Apply-Image /ImageFile:"$wimPath" /Index:1 /ApplyDir:W:\ | ForEach-Object {
            if ($_ -match "([0-9]+[\.,][0-9]+)%") {
                $pctString = $matches[1] -replace ',', '.'
                $val = [math]::Round([double]$pctString)
                if ($val -ge 0 -and $val -le 100) {
                    $progBar.Value = $val
                    $lblStatus.Text = "Extracting Sovereign OS ($val%)..."
                    [System.Windows.Forms.Application]::DoEvents()
                }
            }
            Write-Host $_ -ForegroundColor DarkGray
        }

        $lblStatus.Text = "Writing Bootloader..."
        [System.Windows.Forms.Application]::DoEvents()
    Write-Host "`n[*] Writing Bootloader..." -ForegroundColor Yellow
    $bcdOut = & bcdboot.exe W:\Windows /s S: /f UEFI 2>&1
    $bcdOut | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }

        $lblStatus.Text = "Performing DISM Image API Scrub..."
        [System.Windows.Forms.Application]::DoEvents()
    Write-Host "`n[*] Performing DISM Offline API Scrub..." -ForegroundColor Yellow

    $dismAppx = & dism.exe /Image:W:\ /Get-ProvisionedAppxPackages 2>&1
    $dismPkgs = & dism.exe /Image:W:\ /Get-Packages 2>&1

    $ScrubItems = @(###SCRUB_LIST###)
    if ("NONE" -notin $ScrubItems) {
        foreach ($appName in $ScrubItems) {
            Write-Host "  > Checking API targets for: $appName" -ForegroundColor Cyan

            $currentPkg = $null
            foreach ($line in $dismAppx) {
                if ($line -match "PackageName\s*:\s*(.*)") { $currentPkg = $matches[1].Trim() }
                if ($line -match "(?i)$appName" -and $currentPkg) {
                    Write-Host "    -> DISM Deregistering Appx: $currentPkg" -ForegroundColor DarkGray
                    & dism.exe /Image:W:\ /Remove-ProvisionedAppxPackage /PackageName:$currentPkg | Out-Null
                    $currentPkg = $null
                }
            }

            $currentPkg = $null
            foreach ($line in $dismPkgs) {
                if ($line -match "Package Identity\s*:\s*(.*)") { $currentPkg = $matches[1].Trim() }
                if ($line -match "(?i)$appName" -and $currentPkg) {
                    Write-Host "    -> DISM Deregistering CBS Package: $currentPkg" -ForegroundColor DarkGray
                    & dism.exe /Image:W:\ /Remove-Package /PackageName:$currentPkg | Out-Null
                    $currentPkg = $null
                }
            }
        }
    }

        $lblStatus.Text = "Performing Deep Physical Scrub..."
        [System.Windows.Forms.Application]::DoEvents()
    Write-Host "`n[*] Performing Deep Physical Scrub on applied image..." -ForegroundColor Yellow

    $ScrubItems = @(###SCRUB_LIST###)
    if ("NONE" -notin $ScrubItems) {
        $ScrubRoots = @("W:\Program Files\WindowsApps", "W:\Windows\SystemApps", "W:\Windows\WinSxS", "W:\ProgramData\Microsoft\Windows\AppRepository\Packages", "W:\Users\Default\AppData\Local\Packages", "W:\Program Files\Windows Defender", "W:\Program Files (x86)\Windows Defender", "W:\ProgramData\Microsoft\Windows Defender")
        Write-Host "  > Unlocking root restricted directories..." -ForegroundColor DarkGray
        foreach ($root in $ScrubRoots) {
            if (Test-Path $root) {
                takeown.exe /f $root /a >$null 2>&1
                icacls.exe $root /grant '*S-1-5-32-544:RX' >$null 2>&1
            }
        }

        $IndexFile = "X:\Sovereign_RawIndex.txt"
        if (Test-Path $IndexFile) { Remove-Item $IndexFile -Force -ErrorAction SilentlyContinue }

        Write-Host "  > Performing High-Speed Raw Indexing..." -ForegroundColor DarkGray
        $lblStatus.Text = "Indexing W:\ Drive..."
        [System.Windows.Forms.Application]::DoEvents()
        foreach ($root in $ScrubRoots) { if (Test-Path $root) { cmd.exe /c "dir `"$root`" /s /b /ad >> `"$IndexFile`" 2>nul" } }

        $targetPaths = @()
        $regexPattern = "(?i)(" + ($ScrubItems -join "|") + ")"
        if (Test-Path $IndexFile) {
            Get-Content -Path $IndexFile -ReadCount 5000 | Select-String -Pattern $regexPattern | ForEach-Object {
                $line = $_.Line.Trim()
                if (Test-Path $line) { $targetPaths += $line }
            }
        }
        $resolvedTargets = $targetPaths | Sort-Object -Unique | Sort-Object Length -Descending

        Write-Host "  > Resolved $($resolvedTargets.Count) hidden payloads. Eradicating..." -ForegroundColor Cyan
        $lblStatus.Text = "Eradicating $($resolvedTargets.Count) payload directories..."
        [System.Windows.Forms.Application]::DoEvents()
        foreach ($dir in $resolvedTargets) {
            if (Test-Path $dir) {
                Write-Host "    -> Nuking: $dir" -ForegroundColor Red
                takeown.exe /f $dir /a /r /d y >$null 2>&1
                icacls.exe $dir /grant '*S-1-5-32-544:F' /t /c /q >$null 2>&1
                Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Remove-Item -Path $IndexFile -Force -ErrorAction SilentlyContinue
    }

        $lblStatus.Text = "Applying Unattend and OEM Settings..."
        [System.Windows.Forms.Application]::DoEvents()
    Write-Host "`n[*] Applying Unattend and OEM Settings..." -ForegroundColor Yellow
    if (Test-Path "$installMedia\autounattend.xml") {
        New-Item -ItemType Directory -Path "W:\Windows\Panther" -Force | Out-Null

        $xmlContent = Get-Content "$installMedia\autounattend.xml" -Raw

        $selectedLang = ($CmbLang.SelectedItem -split "\|")[1].Trim()
        $selectedTime = ($CmbTime.SelectedItem -split "\|")[1].Trim()
        $selectedKeyb = ($CmbKeyb.SelectedItem -split "\|")[1].Trim()

        $xmlContent = $xmlContent -replace '<InputLocale>.*?</InputLocale>', "<InputLocale>$selectedKeyb</InputLocale>"
        $xmlContent = $xmlContent -replace '<SystemLocale>.*?</SystemLocale>', "<SystemLocale>$selectedTime</SystemLocale>"
        $xmlContent = $xmlContent -replace '<UILanguage>.*?</UILanguage>', "<UILanguage>$selectedLang</UILanguage>"
        $xmlContent = $xmlContent -replace '<UserLocale>.*?</UserLocale>', "<UserLocale>$selectedTime</UserLocale>"

        $xmlContent | Out-File -FilePath "W:\Windows\Panther\unattend.xml" -Encoding UTF8 -Force
        Write-Host "> Copied and localized autounattend.xml to Panther directory." -ForegroundColor DarkGray
    }

    $oemBase = Join-Path $installMedia 'sources\$OEM$'
    if (Test-Path $oemBase) {
        if (Test-Path (Join-Path $oemBase '$1')) {
            Write-Host "    -> Copying `$OEM`$\`$1..." -ForegroundColor DarkGray
            & cmd.exe /c xcopy /y /e /h /i /c /f "$oemBase\`$1\*" "W:\" 2>&1 | ForEach-Object { Write-Host "      [xcopy] $_" -ForegroundColor DarkGray }
        }
        if (Test-Path (Join-Path $oemBase '$$')) {
            Write-Host "    -> Copying `$OEM`$\`$`$..." -ForegroundColor DarkGray
            & cmd.exe /c xcopy /y /e /h /i /c /f "$oemBase\`$`$\*" "W:\Windows\" 2>&1 | ForEach-Object { Write-Host "      [xcopy] $_" -ForegroundColor DarkGray }
        }
        if (Test-Path (Join-Path $oemBase '$Docs')) {
            Write-Host "    -> Copying `$OEM`$\`$Docs..." -ForegroundColor DarkGray
            & cmd.exe /c xcopy /y /e /h /i /c /f "$oemBase\`$Docs\*" "W:\Users\" 2>&1 | ForEach-Object { Write-Host "      [xcopy] $_" -ForegroundColor DarkGray }
        }
        if (Test-Path (Join-Path $oemBase '$Progs')) {
            Write-Host "    -> Copying `$OEM`$\`$Progs..." -ForegroundColor DarkGray
            & cmd.exe /c xcopy /y /e /h /i /c /f "$oemBase\`$Progs\*" "W:\Program Files\" 2>&1 | ForEach-Object { Write-Host "      [xcopy] $_" -ForegroundColor DarkGray }
        }
    }

        $lblStatus.Text = "Injecting Zero-Touch Drivers..."
        $progBar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
        $progBar.MarqueeAnimationSpeed = 16
        [System.Windows.Forms.Application]::DoEvents()
    Write-Host "`n[*] Injecting Zero-Touch Drivers..." -ForegroundColor Yellow
    $driversBase = Join-Path $installMedia 'Drivers'
    if (Test-Path $driversBase) {
        $infFiles = Get-ChildItem -Path $driversBase -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue
        if ($infFiles.Count -gt 0) {
            $dismDrv = & dism.exe /Image:W:\ /Add-Driver /Driver:"$driversBase" /Recurse 2>&1
            $dismDrv | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
        } else {
            Write-Host "    -> No .inf drivers found in drop folder. Skipping." -ForegroundColor DarkGray
        }
    }

        $lblStatus.Text = "Copying Application Provisioning Drop..."
        [System.Windows.Forms.Application]::DoEvents()
    Write-Host "`n[*] Copying Application Provisioning Drop..." -ForegroundColor Yellow
    $appsBase = Join-Path $installMedia 'Apps'
    if (Test-Path $appsBase) {
        New-Item -ItemType Directory -Path "W:\Windows\Setup\Apps" -Force | Out-Null
        Write-Host "    -> Copying Apps directory..." -ForegroundColor DarkGray
        & cmd.exe /c xcopy /y /e /h /i /c /f "$appsBase\*" "W:\Windows\Setup\Apps\" 2>&1 | ForEach-Object { Write-Host "      [xcopy] $_" -ForegroundColor DarkGray }
    }

        $lblStatus.Text = "Installation Complete!"
        $progBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
        $progBar.Value = 100
        [System.Windows.Forms.Application]::DoEvents()
    Write-Host "`n[*] Installation Complete! Cleaning up logs..." -ForegroundColor Green
    Stop-Transcript
    if (Test-Path "W:\") {
        Copy-Item -Path "X:\SovereignInstall.log" -Destination "W:\SovereignInstall.log" -Force -ErrorAction SilentlyContinue
    }

    Write-Host "`n[*] Awaiting restart confirmation..." -ForegroundColor Cyan
    $msgResult = [System.Windows.Forms.MessageBox]::Show("Installation Complete!`n`nWould you like to Reboot now?`n(Select 'No' to Shutdown, which is recommended if VirtualBox freezes on reboot).", "Sovereign OS Setup", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Information)
    if ($msgResult -eq 'No') {
        Start-Process "$env:SystemRoot\System32\wpeutil.exe" -ArgumentList "shutdown" -WindowStyle Hidden
    } else {
        Start-Process "$env:SystemRoot\System32\wpeutil.exe" -ArgumentList "reboot" -WindowStyle Hidden
    }
    $form.Close()
})

$form.ShowDialog() | Out-Null
exit
'@
            $SetupPs1Content = $SetupPs1Content -replace '/Index:1', "/Index:$TargetInstallIndex"
            $SetupPs1Content = $SetupPs1Content -replace '###SCRUB_LIST###', $PsScrubString
            $SetupPs1Content | Out-File -FilePath (Join-Path $BootMountPath "SovereignSetup.ps1") -Encoding utf8 -Force

            # 3. SovereignSetup.cmd (Smart Launcher / Fallback)
            $SetupCmdContent = @'
@echo off
setlocal EnableDelayedExpansion
mode con cols=120 lines=40
color 0B
echo ===================================================
echo       Sovereign OS - Initialization
echo ===================================================
echo Checking for WPF and PowerShell Support...
powershell.exe -Command "exit" >nul 2>&1
if %errorlevel% equ 0 (
    echo PowerShell detected! Launching XAML Installer...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Maximized -File X:\SovereignSetup.ps1
    wpeutil.exe reboot
    exit /b
)

echo.
echo [!] PowerShell/WPF not detected in this WinPE image.
echo [!] Falling back to Command Line Installer...
echo.
timeout /t 3 >nul

echo Please select a drive to install Windows on.
echo WARNING: THE SELECTED DRIVE WILL BE COMPLETELY WIPED!
echo.
echo list disk > X:\listdisks.txt
diskpart /s X:\listdisks.txt | findstr /i /c:"Disk " | findstr /V "###"
echo.
set /p TargetDisk="Enter the Disk Number (e.g., 0, 1): "

echo select disk %TargetDisk% > X:\diskpart.txt
echo clean >> X:\diskpart.txt
echo convert gpt >> X:\diskpart.txt
echo create partition efi size=500 >> X:\diskpart.txt
echo format quick fs=fat32 label="System" >> X:\diskpart.txt
echo assign letter=S >> X:\diskpart.txt
echo create partition msr size=16 >> X:\diskpart.txt
echo create partition primary >> X:\diskpart.txt
echo format quick fs=ntfs label="Windows" >> X:\diskpart.txt
echo assign letter=W >> X:\diskpart.txt

echo.
echo [1/3] Partitioning Disk %TargetDisk%...
diskpart /s X:\diskpart.txt

echo.
echo [2/3] Extracting Sovereign OS...
for %%I in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%I:\sources\install.wim" set InstallMedia=%%I:
    if exist "%%I:\sources\install.esd" set InstallMedia=%%I:
)
if not defined InstallMedia (
    echo [ERROR] Could not find installation media!
    pause
    exit /b
)
if exist "%InstallMedia%\sources\install.wim" (
    dism /Apply-Image /ImageFile:%InstallMedia%\sources\install.wim /Index:1 /ApplyDir:W:\
) else (
    dism /Apply-Image /ImageFile:%InstallMedia%\sources\install.esd /Index:1 /ApplyDir:W:\
)
echo [3/3] Writing Bootloader...
bcdboot W:\Windows /s S: /f UEFI

echo.
echo Performing DISM Offline API Scrub...
set ScrubItems=###CMD_SCRUB_LIST###
if not "!ScrubItems!"=="NONE" (
    for %%A in (!ScrubItems!) do (
        echo   - Checking API targets for: %%A
                for /f "tokens=2 delims=:" %%P in ('dism /Image:W:\ /Get-ProvisionedAppxPackages ^| findstr /i /c:"%%~A"') do (
            set "Pkg=%%P"
            set "Pkg=!Pkg: =!"
            echo     - DISM Deregistering Appx: !Pkg!
            dism /Image:W:\ /Remove-ProvisionedAppxPackage /PackageName:!Pkg! >nul 2>&1
        )
                for /f "tokens=2 delims=:" %%P in ('dism /Image:W:\ /Get-Packages ^| findstr /i /c:"%%~A"') do (
            set "Pkg=%%P"
            set "Pkg=!Pkg: =!"
            echo     - DISM Deregistering CBS Package: !Pkg!
            dism /Image:W:\ /Remove-Package /PackageName:!Pkg! >nul 2>&1
        )
    )
)

echo.
echo Performing Deep Physical Scrub...
set ScrubItems=###CMD_SCRUB_LIST###
if not "!ScrubItems!"=="NONE" (
    echo Unlocking root folders for scanning...
    for %%R in ("W:\Program Files\WindowsApps" "W:\Windows\SystemApps" "W:\Windows\WinSxS" "W:\ProgramData\Microsoft\Windows\AppRepository\Packages" "W:\Users\Default\AppData\Local\Packages") do (
        if exist %%R (
            takeown /f %%R /a >nul 2>&1
            icacls %%R /grant *S-1-5-32-544:RX >nul 2>&1
        )
    )

    echo Performing High-Speed Raw Indexing...
    if exist X:\Sovereign_RawIndex.txt del /q X:\Sovereign_RawIndex.txt
    for %%R in ("W:\Program Files\WindowsApps" "W:\Windows\SystemApps" "W:\Windows\WinSxS" "W:\ProgramData\Microsoft\Windows\AppRepository\Packages" "W:\Users\Default\AppData\Local\Packages") do (
        if exist %%R ( dir %%R /s /b /ad >> X:\Sovereign_RawIndex.txt 2>nul )
    )

    for %%A in (!ScrubItems!) do (
        echo   - Hunting target: %%A
            for /f "delims=" %%D in ('findstr /i /c:"%%~A" X:\Sovereign_RawIndex.txt') do (
            if exist "%%D" (
                echo     - Nuking: %%D
                takeown /f "%%D" /a /r /d y >nul 2>&1
                icacls "%%D" /grant *S-1-5-32-544:F /t /c /q >nul 2>&1
                rd /s /q "%%D" >nul 2>&1
            )
        )
    )
    if exist X:\Sovereign_RawIndex.txt del /q X:\Sovereign_RawIndex.txt
)

if exist "%InstallMedia%\autounattend.xml" (
    echo Applying Unattend File...
        mkdir W:\Windows\Panther
        copy /y "%InstallMedia%\autounattend.xml" "W:\Windows\Panther\unattend.xml"
)
if exist "%InstallMedia%\sources\$OEM$" (
    echo Applying OEM Folders...
        if exist "%InstallMedia%\sources\$OEM$\$1" xcopy /y /e /h /i /c /f "%InstallMedia%\sources\$OEM$\$1\*" "W:\"
        if exist "%InstallMedia%\sources\$OEM$\$$" xcopy /y /e /h /i /c /f "%InstallMedia%\sources\$OEM$\$$\*" "W:\Windows\"
        if exist "%InstallMedia%\sources\$OEM$\$Docs" xcopy /y /e /h /i /c /f "%InstallMedia%\sources\$OEM$\$Docs\*" "W:\Users\"
        if exist "%InstallMedia%\sources\$OEM$\$Progs" xcopy /y /e /h /i /c /f "%InstallMedia%\sources\$OEM$\$Progs\*" "W:\Program Files\"
)
if exist "%InstallMedia%\Drivers" (
    dir /s /b "%InstallMedia%\Drivers\*.inf" >nul 2>&1
    if !errorlevel! equ 0 (
        echo Injecting Zero-Touch Drivers...
        dism /Image:W:\ /Add-Driver /Driver:"%InstallMedia%\Drivers" /Recurse
    ) else (
        echo No .inf drivers found in drop folder. Skipping.
    )
)
if exist "%InstallMedia%\Apps" (
    echo Copying Provisioned Apps...
        mkdir W:\Windows\Setup\Apps
        xcopy /y /e /h /i /c /f "%InstallMedia%\Apps\*" "W:\Windows\Setup\Apps\"
)
echo.
echo ===================================================
echo Installation Complete!
echo ===================================================
echo Press any key to reboot. (If using VirtualBox, you may want to manually power off instead).
pause >nul
wpeutil.exe reboot
'@
            $SetupCmdContent = $SetupCmdContent -replace '/Index:1', "/Index:$TargetInstallIndex"
            $SetupCmdContent = $SetupCmdContent -replace '###CMD_SCRUB_LIST###', $CmdScrubString
            $SetupCmdContent | Out-File -FilePath (Join-Path $BootMountPath "SovereignSetup.cmd") -Encoding ascii -Force

            # 3. Custom WinPE Background (Sovereign Branding)
            Write-Host "SOV_DARKGRAY:  -> Generating custom Sovereign background..."
            try {
                Add-Type -AssemblyName System.Drawing
                $bmp = New-Object System.Drawing.Bitmap(1920, 1080)
                $graphics = [System.Drawing.Graphics]::FromImage($bmp)

                # Dark Minimalist Background
                $graphics.Clear([System.Drawing.Color]::FromArgb(255, 20, 20, 20))

                $fontTitle = New-Object System.Drawing.Font("Segoe UI", 72, [System.Drawing.FontStyle]::Bold)
                $brushTitle = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 0, 122, 204))
                $graphics.DrawString("Sovereign OS", $fontTitle, $brushTitle, 100, 100)

                $fontSub = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Regular)
                $brushSub = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 150, 150, 150))
                $graphics.DrawString("Custom Preinstallation Environment", $fontSub, $brushSub, 110, 220)

                $BgPath = Join-Path $BootMountPath "Windows\System32\winpe.jpg"
                takeown.exe /f $BgPath /a | Out-Null
                icacls.exe $BgPath /grant '*S-1-5-32-544:F' /q | Out-Null
                $bmp.Save($BgPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)

                $graphics.Dispose()
                $bmp.Dispose()
            }
            catch {
                Write-Host "SOV_YELLOW:  [!] Could not generate custom background."
            }

            Write-Host "SOV_CYAN:  -> Committing boot.wim..."
            Dismount-WindowsImage -Path $BootMountPath -Save -ErrorAction Stop | Out-Null
        }
        else {
            Write-Host "SOV_RED:  [!] boot.wim not found at $BootWimPath! Cannot configure custom installer."
        }
    }

    Write-Host "SOV_CYAN:Staging Zero-Touch Application Drop..."
    $AppsDir = Join-Path $IsoRoot "Apps"
    if (-not (Test-Path $AppsDir)) { New-Item -ItemType Directory -Path $AppsDir -Force | Out-Null }
    "Drop silent installers (.exe or .msi) in this folder. They will automatically install silently during the final phase of Windows setup." | Out-File -FilePath (Join-Path $AppsDir "README.txt") -Encoding ascii -Force

    Write-Host "SOV_CYAN:Staging Zero-Touch Driver Drop..."
    $DriversDir = Join-Path $IsoRoot "Drivers"
    if (-not (Test-Path $DriversDir)) { New-Item -ItemType Directory -Path $DriversDir -Force | Out-Null }
    "Drop extracted third-party drivers (.inf files and their dependencies) in this folder. They will be recursively injected into the offline Windows image before the first boot." | Out-File -FilePath (Join-Path $DriversDir "README.txt") -Encoding ascii -Force

    Write-Host "SOV_CYAN:Packaging ISO..."
    if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = $PSScriptRoot }
    if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = $PWD.Path }

    $xorriso = Join-Path $ScriptDir "xorriso.exe"

    if (-not (Get-Command xorriso.exe -ErrorAction SilentlyContinue) -and -not (Test-Path $xorriso)) {
        $acquired = Get-Xorriso -ScriptDir $ScriptDir
        if ($acquired) { $xorriso = $acquired }
    }

    if ((Test-Path $xorriso) -or (Get-Command xorriso.exe -ErrorAction SilentlyContinue)) {
        $xorrisoCmd = if (Test-Path $xorriso) { $xorriso } else { "xorriso.exe" }

        $IsoRootParent = Split-Path $IsoRoot -Parent
        if ([string]::IsNullOrWhiteSpace($IsoRootParent)) { $IsoRootParent = "C:\" }
        $IsoRootLeaf = Split-Path $IsoRoot -Leaf
        $timeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $isoFileName = "Sovereign_Win11_$timeStamp.iso"
        $FinalIsoPath = Join-Path $IsoRootParent $isoFileName

        if ((Test-Path "$IsoRoot\boot\etfsboot.com") -and (Test-Path "$IsoRoot\efi\microsoft\boot\efisys.bin")) {
            $xorrisoArgs = "-as mkisofs " +
            "-iso-level 3 " +
            "-full-iso9660-filenames " +
            "-relaxed-filenames " +
            "-J -joliet-long " +
            "-volid `"SOVEREIGN_WIN11`" " +
            "-b boot/etfsboot.com " +
            "-no-emul-boot " +
            "-boot-load-size 8 " +
            "-boot-info-table " +
            "-eltorito-alt-boot " +
            "-e efi/microsoft/boot/efisys.bin " +
            "-no-emul-boot " +
            "-output `"./$isoFileName`" " +
            "`"$IsoRootLeaf`""

            Write-Host "SOV_CYAN:  -> Packaging ISO with xorriso (This may take a while)..."
            $p = Start-Process -FilePath $xorrisoCmd -ArgumentList $xorrisoArgs -WorkingDirectory $IsoRootParent -Wait -NoNewWindow -PassThru

            if ($p.ExitCode -eq 0) { Write-Host "SOV_GREEN:ISO created successfully at: $FinalIsoPath" }
            else { Write-Host "SOV_RED:xorriso encountered an error (Exit Code: $($p.ExitCode))." }
        }
        else { Write-Host "SOV_RED:Boot sectors missing in $IsoRoot. Cannot build bootable ISO." }
    }
    else {
        Write-Host "SOV_YELLOW:xorriso.exe could not be acquired. Your modified Windows setup files are ready in:"
        Write-Host "SOV_CYAN:  -> $IsoRoot"
        Write-Host "SOV_DARKGRAY:You can copy this folder's contents directly to a bootable USB drive or build the ISO manually."
    }

    Write-Host "SOV_GREEN:Surgical subtraction complete!"
}
