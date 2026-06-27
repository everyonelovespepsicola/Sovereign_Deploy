function Convert-ToFriendlyName {
    param([string]$RawName)
    if ([string]::IsNullOrWhiteSpace($RawName)) { return "Unknown Component" }

    $name = $RawName
    # Strip DISM capability tails (e.g., ~~~~0.0.1.0) and Package hashes (e.g., ~31bf3856ad364e35...)
    $name = $name -replace '~.*$', ''
    # Strip Appx version/hash tails (e.g., _1.0.0.0_neutral__8wekyb3d8bbwe)
    $name = $name -replace '_.*$', ''

    # Remove common manufacturer prefixes
    $name = $name -replace '(?i)^Microsoft[-.](Windows[-.])?', ''
    $name = $name -replace '(?i)^Windows[-.]', ''
    $name = $name -replace '(?i)^App[-.]', ''

    # Replace punctuation with spaces
    $name = $name -replace '[-.]', ' '

    # Add spaces to CamelCase words
    $name = [System.Text.RegularExpressions.Regex]::Replace($name, '([a-z])([A-Z])', '$1 $2')

    $name = $name.Trim()

    if ($name -match '(?i)^Internet Browser Package') {
        $name += " (Microsoft Edge)"
    }

    return $name
}

function Get-SovereignComponentList {
    [CmdletBinding()]
    param (
        [string]$WimPath = $null,
        [string]$MountPath = "C:\Sovereign_Mount",
        [int]$Index = 1
    )

    # We use an ObservableCollection so the WPF UI updates automatically if we change items
    $MasterList = New-Object System.Collections.ObjectModel.ObservableCollection[Object]

    if ([string]::IsNullOrWhiteSpace($WimPath) -or -not (Test-Path $WimPath)) {
        Write-Host "SOV_RED:Invalid WIM path provided."
        return $MasterList
    }

    # REAL WIM INTERROGATION LOGIC
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
                return $MasterList
            }
        }

        Write-Host "SOV_DARKGRAY:  -> Deep cleaning DISM registry locks..."
        try { & dism.exe /Cleanup-Wim | Out-Null } catch {}
        try { Clear-WindowsCorruptMountPoint -ErrorAction SilentlyContinue | Out-Null } catch {}

        if (Test-Path $MountPath) {
            cmd.exe /c "rmdir /s /q `"$MountPath`"" | Out-Null
        }

        $stuckMount = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.ImagePath -eq $WimPath }
        if ($stuckMount) {
            Write-Host "SOV_RED:  [!] WIM is still locked by Windows. A PC restart may be required."
            return $MasterList
        }

        if (-not (Test-Path $MountPath)) { New-Item -ItemType Directory -Path $MountPath | Out-Null }

        # Ensure the WIM is not Read-Only
        $wimFile = Get-Item -Path $WimPath
        if ($wimFile.IsReadOnly) {
            Write-Host "SOV_CYAN:  -> Removing Read-Only attribute from WIM file..."
            $wimFile.IsReadOnly = $false
        }

        Write-Host "SOV_CYAN:Mounting $WimPath (Index $Index) to $MountPath..."
        Mount-WindowsImage -ImagePath $WimPath -Index $Index -Path $MountPath | Out-Null
    }

    Write-Host "SOV_CYAN:Scanning Image Components..."

    $Capabilities = @()
    try { $Capabilities = Get-WindowsCapability -Path $MountPath -ErrorAction Stop }
    catch { Write-Host "SOV_DARKGRAY:  -> Skipping Capabilities: $($_.Exception.Message)" }

    $OptionalFeatures = @()
    try { $OptionalFeatures = Get-WindowsOptionalFeature -Path $MountPath -ErrorAction Stop }
    catch { Write-Host "SOV_DARKGRAY:  -> Skipping Optional Features: $($_.Exception.Message)" }

    $Bloatware = @()
    try { $Bloatware = Get-AppxProvisionedPackage -Path $MountPath -ErrorAction Stop }
    catch { Write-Host "SOV_DARKGRAY:  -> Skipping Bloatware: $($_.Exception.Message)" }

    $Packages = @()
    try { $Packages = Get-WindowsPackage -Path $MountPath -ErrorAction Stop }
    catch { Write-Host "SOV_DARKGRAY:  -> Skipping Packages: $($_.Exception.Message)" }

    foreach ($cap in $Capabilities) {
        $dName = $cap.DisplayName
        $contextName = if ([string]::IsNullOrWhiteSpace($dName) -or $dName -eq $cap.Name -or $dName -notmatch ' ') { Convert-ToFriendlyName $cap.Name } else { $dName }
        $desc = "Windows Capability ($($cap.Name))"
        $MasterList.Add([PSCustomObject]@{ Name = $cap.Name; DisplayName = $contextName; Description = $desc; Type = "Capability"; Category = "Windows Capabilities"; Action = $true })
    }
    foreach ($feat in $OptionalFeatures) {
        $dName = $feat.DisplayName
        $contextName = if ([string]::IsNullOrWhiteSpace($dName) -or $dName -eq $feat.FeatureName -or $dName -notmatch ' ') { Convert-ToFriendlyName $feat.FeatureName } else { $dName }
        $desc = "Optional Feature ($($feat.FeatureName))"
        # Keep enabled features checked by default
        $isChecked = ($feat.State -eq 'Enabled')

        $MasterList.Add([PSCustomObject]@{ Name = $feat.FeatureName; DisplayName = $contextName; Description = $desc; Type = "OptionalFeature"; Category = "Optional Features"; Action = $isChecked })
    }
    foreach ($app in $Bloatware) {
        $dName = $app.DisplayName
        $contextName = if ([string]::IsNullOrWhiteSpace($dName) -or $dName -eq $app.PackageName -or $dName -notmatch ' ') { Convert-ToFriendlyName $app.PackageName } else { $dName }
        $desc = "Appx Package ($($app.PackageName))"

        $MasterList.Add([PSCustomObject]@{ Name = $app.PackageName; DisplayName = $contextName; Description = $desc; Type = "AppxPackage"; Category = "Appx Packages (Bloatware)"; Action = $true })
    }
    foreach ($pkg in $Packages) {
        # Only target packages that are actively installed in the image
        if ($pkg.PackageState -ne 'Installed') { continue }

        # Hide foundational OS packages and standard updates to prevent breaking the OS and cluttering the UI
        if ($pkg.PackageName -match '(?i)(Foundation|UpdateStore|LanguagePack|EditionPack|Client-Features|Client-Desktop)') { continue }
        if ($pkg.ReleaseType -match '(?i)(Update|Security Update|Service Pack)' -and $pkg.PackageName -notmatch '(?i)(Edge|Browser)') { continue }

        $dName = $pkg.PackageName
        $contextName = Convert-ToFriendlyName $pkg.PackageName
        $desc = "Windows Package ($($pkg.ReleaseType))"

        $MasterList.Add([PSCustomObject]@{ Name = $pkg.PackageName; DisplayName = $contextName; Description = $desc; Type = "Package"; Category = "Windows Packages (Deep System)"; Action = $true })
    }

    Write-Host "SOV_GREEN:WIM is now mounted and locked for edits."

    return $MasterList
}
