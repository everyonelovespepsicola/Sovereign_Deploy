# Sovereign OS Deployment Pipeline

Sovereign OS is a radically debloated, fully automated Windows 11 deployment ecosystem. It completely replaces the standard Windows Setup with a custom .NET 8 WinPE (Windows Preinstallation Environment) GUI, allowing for deep system-level tweaks, offline registry modifications, native unattended user creation, and hardcore debloating *before* the OS ever boots.

---

## 📂 Workspace Structure

- **`input/`**: Place your master Windows 11 ISO here (e.g., `windows.iso`).
- **`output/`**: The compiled `Sovereign_WinPE.iso` is generated here.
- **`build/`**: Internally used for transient WIM mount points during generation.
- **`src/scripts/`**: Houses secondary utility and maintenance scripts.
- **`tools/`**: Cached dependencies, executables, and manifest files.

---

## 🏗️ Architecture & Core Components

### 1. `publish.ps1` (The Master Pipeline)
This is the heart of the build system. Running this script automates the entire ISO generation process:
- Parses `tools_manifest.json` to dynamically download and extract standalone utilities (Dism++, AOMEI Partition Assistant, Explorer++).
- Compiles the `NewShell` project as a standalone, self-contained `.NET 8` executable.
- Extracts `boot.wim` from a standard Windows ISO.
- Uses DISM to inject Microsoft ADK Optional Components (WinPE-NetFX, WinPE-PowerShell, WinPE-WMI).
- Injects the custom `winpeshl.ini` to hijack the boot sequence, bypassing `setup.exe` and loading the Sovereign GUI natively.
- Repacks the heavily modified `boot.wim` into `output/Sovereign_WinPE.iso`.

### 2. `NewShell` (Sovereign OS Installer)
A beautiful, full-screen .NET WinForms GUI that serves as the command center inside WinPE. It handles:
- **Disk Management**: Fully automates `diskpart` to wipe drives and construct perfect UEFI partitions.
- **Image Deployment**: Automatically mounts and applies standard `install.wim` or `install.esd` images using native DISM commands.
- **Native Unattend Setup**: Bypasses the notoriously buggy Windows 11 `oobeSystem` profile generation by securely collecting User Credentials in the WinPE GUI, injecting them directly into an `unattend.xml` Answer File, and configuring `AutoLogon` for a completely zero-touch first boot.
- **Hardcore Modules**: Integrates a "nuclear" debloat menu capable of permanently ripping out Microsoft Edge, Windows Defender, Copilot, Recall AI, OneDrive, and Telemetry directly from the offline image before the OS boots.
- **Active Setup Hacks**: Uses enterprise-grade `Active Setup` registry protocols to seamlessly inject tweaks (like restoring the classic Windows 10 right-click context menu) natively into the dynamic `UsrClass.dat` file during the first login.

---

## 🚀 How to Build & Deploy

1. **Prerequisites**: 
   - Windows ADK (Assessment and Deployment Kit) with the WinPE Add-on installed.
   - .NET 8 SDK.
   - A vanilla Windows 11 ISO located at `C:\projects\ntlight\input\windows.iso`.
2. **Build**: Run `.\publish.ps1` in an elevated PowerShell window.
3. **Deploy**: Mount the resulting `output\Sovereign_WinPE.iso` onto a Virtual Machine or flash it to a USB drive using Ventoy. 
4. **Install**: Boot into WinPE, fill out the user credentials in the Sovereign GUI, select your target drive, and click **DEPLOY OS**. The system will install, seamlessly skip the OOBE setup, and drop you onto your fully debloated Sovereign OS desktop.

> [!NOTE]
> **Environment Lock Enabled**
> The Sovereign Installer features an advanced context-aware execution lock. If you launch the GUI on your live main machine, the **Deployment** module (which wipes disks) is completely locked out. Conversely, if you boot from the WinPE ISO, the **Live Tweaker** module is disabled until Windows initializes. This makes the compiled `.exe` 100% safe to run natively on any host system.
