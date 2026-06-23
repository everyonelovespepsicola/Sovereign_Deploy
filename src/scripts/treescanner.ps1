$inputFile = "C:\Users\Administrator\Desktop\projects\New folder\CFileList.txt"
$outputFile = "C:\Users\Administrator\Desktop\projects\ntlight\tree\Found_Bloatware_Paths.txt"

# The keywords we are hunting for
$pattern = "(?i)(copilot|recall|windowsai|microsoft-edge|msedge|xbox|bing)"

Write-Host "Hunting for ghosts... This may take a minute on a 48MB file."
Get-Content -Path $inputFile -ReadCount 5000 |
    Select-String -Pattern $pattern |
    ForEach-Object {
        # Extract the directory path from the line
        $line = $_.Line.Trim()
        if (Test-Path -Path $line -IsValid) {
            Split-Path $line -Parent -ErrorAction SilentlyContinue
        } else {
            $line
        }
    } |
    Sort-Object -Unique |
    Out-File -FilePath $outputFile -Encoding utf8

Write-Host "Done! Check $outputFile"
