# Define the Registry path where Shell Folders/COM icons live
$RegistryPath = "HKLM:\SOFTWARE\Classes\CLSID"

# Get all subkeys (the GUIDs)
$clsids = Get-ChildItem -Path $RegistryPath -ErrorAction SilentlyContinue

$total = $clsids.Count
$counter = 0

$results = foreach ($id in $clsids) {
    $counter++
    # Update the progress bar every 50 items to keep the script running fast
    if ($counter % 50 -eq 0) {
        Write-Progress -Activity "Scanning Registry for Shell Calls" -Status "Checking $counter of $total CLSIDs..." -PercentComplete (($counter / $total) * 100)
    }

    # We are looking for the "Instance" or "shell\open\command" parts
    $name = (Get-ItemProperty -Path $id.PSPath -Name "(default)" -ErrorAction SilentlyContinue)."(default)"
    
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = (Get-ItemProperty -Path $id.PSPath -Name "LocalizedString" -ErrorAction SilentlyContinue).LocalizedString
    }
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = "Unknown Shell Item"
    }

    $commandPath = Join-Path $id.PSPath "shell\open\command"
    $instancePath = Join-Path $id.PSPath "Instance\InitPropertyBag"
    $shellFolderPath = Join-Path $id.PSPath "ShellFolder"
    
    $command = $null

    if (Test-Path $commandPath) {
        $command = (Get-ItemProperty -Path $commandPath -Name "(default)" -ErrorAction SilentlyContinue)."(default)"
    } elseif (Test-Path $instancePath) {
        $instanceProps = Get-ItemProperty -Path $instancePath -ErrorAction SilentlyContinue
        if ($instanceProps.TargetFolderPath) { $command = $instanceProps.TargetFolderPath }
        elseif ($instanceProps.Target) { $command = $instanceProps.Target }
        elseif ($instanceProps.Command) { $command = $instanceProps.Command }
    }

    # Windows defines most native Shell Extensions (like Control Panel, Recycle Bin, Network) 
    # by giving the CLSID a "ShellFolder" subkey, or a System.ApplicationName property.
    if (-not $command -and (((Get-ItemProperty -Path $id.PSPath -Name "System.ApplicationName" -ErrorAction SilentlyContinue)."System.ApplicationName") -or (Test-Path $shellFolderPath))) {
        $command = "explorer.exe shell:::$($id.PSChildName)"
    }

    if ($command) {
        [PSCustomObject]@{
            Name    = $name
            GUID    = $id.PSChildName
            Command = $command
        }
    }
}

# Clear the progress bar from the screen when done
Write-Progress -Activity "Scanning Registry for Shell Calls" -Completed

# Output to the parent folder (project root) as a single text file
$parentDir = Split-Path -Path $PSScriptRoot -Parent
$results | Format-List | Out-File "$parentDir\Shell_Calls.txt" -Encoding utf8
Write-Host "Scan complete! Check Shell_Calls.txt in your project root folder." -ForegroundColor Green