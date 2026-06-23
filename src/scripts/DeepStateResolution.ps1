function Invoke-DeepStateResolution {
    <#
    .SYNOPSIS
        Executes Phase 5 of the Sovereign Architecture: Deep System State Resolution.
    .DESCRIPTION
        Performs lightning-fast raw file system parsing to completely eliminate deeply embedded
        and dynamically hashed bloatware components (Ghost Artifacts) from an offline WIM.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MountPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Keywords
    )

    Write-Host "SOV_CYAN:Starting Phase 5: Deep System State Resolution..."

    if (-not (Test-Path $MountPath)) {
        Write-Host "SOV_RED:  [!] Mount path not found: $MountPath"
        return
    }

    if ($Keywords.Count -eq 0 -or $Keywords[0] -eq "NONE") {
        Write-Host "SOV_DARKGRAY:  -> No hit-list keywords provided. Skipping."
        return
    }

    $IndexFile = Join-Path $env:TEMP "Sovereign_RawIndex.txt"
    $HitOutFile = Join-Path $env:TEMP "Sovereign_Hits.txt"
    $KeywordsCsv = $Keywords -join ","

    # Native PowerShell parsing engine will be used exclusively.

    # Step 1: High-Speed Indexing
    Write-Host "SOV_DARKGRAY:  -> [1/4] Performing High-Speed Raw Indexing of $MountPath..."
    cmd.exe /c "dir `"$MountPath`" /s /b /a > `"$IndexFile`""

    # Step 2: Target Resolution & Parsing
    Write-Host "SOV_DARKGRAY:  -> [2/4] Parsing index via Native PowerShell ($KeywordsCsv)..."
    $targetPaths = @()

    $regexPattern = "(?i)(" + ($Keywords -join "|") + ")"
    Get-Content -Path $IndexFile -ReadCount 5000 | Select-String -Pattern $regexPattern | ForEach-Object {
        $line = $_.Line.Trim()
        if (Test-Path -Path $line -IsValid) {
            if ($line -ne $MountPath) {
                $targetPaths += $line
            }
        }
    }

    # Deduplicate and sort by length descending (Deepest paths first so we delete children before parents)
    $resolvedTargets = $targetPaths | Sort-Object -Unique | Sort-Object Length -Descending

    if ($resolvedTargets.Count -eq 0) {
        Write-Host "SOV_GREEN:  -> No embedded ghosts found for provided keywords."
        Remove-Item -Path $IndexFile -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $HitOutFile -Force -ErrorAction SilentlyContinue
        return
    }

    Write-Host "SOV_YELLOW:  -> Resolved $($resolvedTargets.Count) hidden payload directories."

    # Step 3 & 4: Privilege Escalation & Surgical Extraction
    Write-Host "SOV_DARKGRAY:  -> [3/4 & 4/4] Executing ACL Seizures & Surgical Extractions..."
    $nukedCount = 0
    foreach ($target in $resolvedTargets) {
        if (Test-Path $target) {
            takeown.exe /f $target /a /r /d y *>&1 | Out-Null
            icacls.exe $target /grant '*S-1-5-32-544:F' /t /c /q *>&1 | Out-Null

            Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue

            $nukedCount++
        }
    }

    Write-Host "SOV_GREEN:  -> Successfully eradicated $nukedCount deeply embedded payloads."
    Remove-Item -Path $IndexFile -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $HitOutFile -Force -ErrorAction SilentlyContinue
}
