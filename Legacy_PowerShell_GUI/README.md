# Legacy PowerShell GUI

This folder contains the old PowerShell-based Sovereign Dashboard deployer. 

These files were moved here to separate them from the new deployment pipeline, which now uses the C# `NewShell` GUI (compiled into the WinPE ISO during build).

### Files moved to this directory:
- The entire contents of the old `src/scripts` directory (which included `SovereignDashboard.ps1`, `SurgicalLoader.ps1`, `ImageInterrogator.ps1`, `UnattendGenerator.ps1`, etc.).
- The old `DashboardLayout.xaml` file that was originally located in the `assets/` folder.
