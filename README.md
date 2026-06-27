# Sovereign OS Deployment Pipeline

Sovereign OS is a radically debloated, fully automated Windows 11 deployment ecosystem. It completely replaces the standard Windows Setup with a custom .NET 8 WinPE (Windows Preinstallation Environment) GUI, allowing for deep system-level tweaks, offline registry modifications, native unattended user creation, and hardcore debloating *before* the OS ever boots.

---

## 📂 Workspace Structure

| Path | Purpose |
|---|---|
| `input/` | Place your master Windows 11 ISO here (`windows.iso`) |
| `output/` | The compiled `Sovereign_WinPE.iso` is generated here |
| `build/` | Internally used for transient WIM mount points during generation |
| `NewShell/` | Source code for the Sovereign GUI installer (C# / .NET 8 WinForms) |
| `src/scripts/` | Secondary utility and maintenance scripts |
| `tools/` | Tool manifest and cached dependencies |
| `frozen_tools/` | Downloaded tool binaries (7-Zip, Explorer++, AOMEI, xorriso, etc.) |
| `assets/` | WinPE wallpaper and other static assets |

---

## 🏗️ Architecture & Core Components

### `publish.ps1` — The Master Build Pipeline
Orchestrates the entire ISO generation process in 7 sequential steps:
1. Parses `tools/tools_manifest.json` to download and cache standalone utilities
2. Compiles `NewShell` as a self-contained .NET 8 single-file executable (carries its own runtime — no .NET install needed in WinPE)
3. Mounts the stock Windows ISO and extracts the `boot.wim` skeleton
4. Uses DISM to inject ADK Optional Components: `WinPE-WMI`, `WinPE-NetFX`, `WinPE-Scripting`, `WinPE-PowerShell`
5. Injects the Sovereign payload: compiled GUI, frozen tools, custom wallpaper
6. Generates `winpeshl.ini` to hijack the boot shell, bypassing `setup.exe` and launching the Sovereign GUI directly
7. Repacks everything into `output/Sovereign_WinPE.iso` using xorriso or oscdimg

### `NewShell/` — Sovereign OS Installer GUI
A full-screen dark .NET WinForms GUI (`InstallerForm.cs`) that runs as the command center inside WinPE. It operates in two distinct modes (controlled by the `debloatMode` constructor flag):

- **Installer Mode** — Full deployment from scratch (disk wipe → image apply → unattend inject → boot)
- **Tweaker Mode** — Offline debloat/tweak of an already-installed Windows drive

Core capabilities in both modes:
- **Disk Management** — Runs `diskpart` to wipe and construct perfect UEFI partition layouts (500MB EFI/FAT32 + 16MB MSR + Primary NTFS)
- **Image Deployment** — Applies `install.wim` / `install.esd` images using the native `ManagedWimLib` engine with progress callbacks
- **Package Interrogation** — Uses `DISM /Get-ProvisionedAppxPackages` to enumerate all AppX packages from the offline image for surgical removal
- **Hardcore Modules** — Nuclear debloat menu capable of removing Edge, Defender, Copilot/Recall AI, OneDrive, Xbox junk, Windows Update, and Search Indexing entirely from the offline registry and filesystem
- **Native Unattend Inject** — Bypasses Windows 11 OOBE entirely by generating a custom `unattend.xml` and writing it to `Windows\Panther\`, with `AutoLogon` and `SetupComplete.cmd` for zero-touch first boot
- **Active Setup Hacks** — Injects classic Windows 10 right-click context menu and "End Task" into the offline `NTUSER.DAT` and `Active Setup` registry keys, applying seamlessly on first login
- **Ghost Buster** — Drops a cleanup payload to user Startup folders that removes phantom AppX packages on first login

---

## 🎯 Three Deployment Scenarios

---

### 🖥️ Scenario 1: Full Deployment from Scratch (via Sovereign WinPE ISO)

**Use this when:** You want to do a clean install on a bare drive or completely wipe and reinstall a machine. This is the primary, fully automated path.

**What it does:**
- Boots into a custom WinPE environment (no Windows Setup wizard)
- Wipes the target disk and creates a proper UEFI partition table
- Rips `install.wim` directly from your Windows ISO using 7-Zip inside WinPE
- Applies the selected Windows edition using the Wimlib engine
- Injects optional drivers from a folder you specify
- Runs the debloat and registry hardening pipeline against the offline image
- Generates and injects `unattend.xml` to skip OOBE and auto-create your user account
- Writes the UEFI bootloader via `bcdboot`
- On first boot: drops you directly to a clean, configured Sovereign OS desktop — zero OOBE interaction

#### Prerequisites
- **.NET 8 SDK**
- A vanilla Windows 11 ISO at `input\windows.iso`
- A USB drive with [Ventoy](https://www.ventoy.net/) installed, **or** a VM

#### Step-by-Step Walkthrough

**Step 1 — Build the ISO**
```powershell
# Run in an elevated PowerShell window from the project root
.\publish.ps1
```
This produces `output\Sovereign_WinPE.iso`. The build log is written to `SovereignBuild.log`.

**Step 2 — Prepare your boot media**

*Option A — Ventoy USB:*
1. Copy `output\Sovereign_WinPE.iso` to the root of your Ventoy USB drive
2. Also copy your vanilla `windows.iso` to the same Ventoy drive alongside it
   > ⚠️ The Sovereign GUI needs access to the raw Windows ISO to rip `install.wim` at deploy time. Both ISOs must be present on the Ventoy drive.

*Option B — Virtual Machine:*
1. Create a new VM (UEFI firmware mode)
2. Mount `output\Sovereign_WinPE.iso` as the primary boot disk
3. Attach your `windows.iso` as a secondary optical drive, **or** store it somewhere accessible from within WinPE (network share, second virtual disk, etc.)

**Step 3 — Boot into WinPE**

Boot the target machine from the USB / VM. The Sovereign custom shell loads automatically — you will see a dark taskbar/desktop and the **Sovereign OS Installer** GUI launches.

**Step 4 — Fill in the Installer GUI**

| Field | What to do |
|---|---|
| **Select Target Drive** | Pick the disk to wipe (e.g., `Disk 0 - 476 GB (Online)`). **This disk will be completely erased.** |
| **Select Windows ISO or WIM** | Browse to your `windows.iso` (or `install.wim` if you extracted it already) |
| **Edition** | Select your target edition (defaults to Index 6 = Pro) |
| **Drivers Folder (Optional)** | Browse to a folder of extracted `.inf` drivers to inject offline |
| **Username / Password / PC Name** | Enter your desired local account credentials |
| **Use Built-in Administrator** | Check this if you want the built-in `Administrator` account instead of a named user |

**Step 5 — Select packages to purge**

After clicking **DEPLOY OS** and confirming the disk wipe warning, the pipeline will:
1. Wipe and partition the disk
2. Extract and apply the Windows image
3. Scan the offline image and present two lists:
   - **AppX Packages** — Check any bloatware you want removed (Xbox, Cortana, News, etc.)
   - **Hardcore Modules** — High-risk removals (Edge, Defender, OneDrive, Copilot/Recall AI, Windows Update, Search Indexing)

Check what you want gone, then click **PURGE SELECTED PACKAGES AND CONTINUE**.

**Step 6 — Wait for completion**

The pipeline finishes by:
- Applying your selected debloat
- Injecting offline registry tweaks (privacy lockdown, service hardening, Active Setup hacks)
- Generating and writing `unattend.xml` to `Windows\Panther\`
- Writing the UEFI bootloader

A success dialog appears. Reboot — Windows boots directly to your configured desktop.

---

### 💻 Scenario 2: Windows Already Installed — Offline Tweaker

**Use this when:** Windows is already installed and you want to debloat and harden it offline from WinPE, without reinstalling. Ideal for applying the Sovereign treatment to an existing install.

> This is the **Tweaker Mode** of the Sovereign GUI. It skips disk wipe and image deployment entirely, targeting the already-installed Windows partition instead.

**What it does:**
- Mounts the offline Windows hive files (`SOFTWARE`, `SYSTEM`) and applies registry tweaks
- Runs DISM to enumerate and surgically remove AppX packages from the offline image
- Executes the nuclear filesystem scanner to obliterate Edge/Copilot/Defender directories
- Wipes Start Menu cache and deploys the Ghost Buster cleanup script
- Optionally injects an `unattend.xml` + triggers Sysprep to re-run OOBE under your new account (see Scenario 3 for standalone OOBE bypass)

> [!NOTE]
> **Expected DISM Servicing Warning:** 
> If a user has already logged into the Windows partition you are tweaking, DISM may output the warning: `"This image cannot be serviced on an offline image after a user has logged into the image"`. This is normal and expected. The Sovereign Tweaker uses DISM primarily to discover packages and then deletes the directories and targets manually through custom cleanup heuristics and the Ghost Buster startup payload. You can safely ignore this error.

#### Step-by-Step Walkthrough

**Step 1 — Boot into Sovereign WinPE**

Boot from your Sovereign WinPE USB/ISO (built in Scenario 1, Step 1–3). The machine's existing Windows drive will be visible from within WinPE.

**Step 2 — Launch the Sovereign Tweaker**

In the Sovereign shell, open the **Sovereign Tweaker** (this is `InstallerForm` launched in `debloatMode = true`). You can access it from the taskbar or desktop shortcut depending on your shell configuration.

**Step 3 — Select the installed Windows drive**

The drive list shows all ready drives excluding the WinPE drive (`X:\`). Drives with a detected `\Windows` folder are labeled `(Windows Installed)`. Select your target drive.

**Step 4 — Choose packages and modules**

Click **ANALYZE SYSTEM**. The GUI will:
1. Run `DISM /Get-ProvisionedAppxPackages` against the selected offline drive
2. Display the full AppX package list and Hardcore Modules panel

Select everything you want removed. Click **PURGE SELECTED PACKAGES AND CONTINUE**.

**Step 5 — Wait for completion**

The pipeline runs:
- AppX package removal via DISM
- Filesystem nuke scan (Program Files, ProgramData, Windows) for targeted binaries
- User AppData surgical scrub
- Offline registry tweaks via hive load/unload (`HKLM\zSOFTWARE`, `HKLM\zSYSTEM`)
- Start Menu cache wipe across all user profiles
- Ghost Buster deployment to user Startup folders (cleans phantom AppX entries on next login)

A success dialog confirms completion. Reboot normally into your now-tweaked Windows install.

---

### 🔑 Scenario 3: Retail OOBE Bypass (Pre-installed Windows)

**Use this when:** Windows came pre-installed on the machine (OEM/retail) and has never gone through OOBE setup, or you want to skip OOBE entirely on a freshly installed but un-configured Windows and create your user account without ever seeing the Microsoft Account setup wizard.

> This is the **"New Preinstalled OOBE Bypass"** option, surfaced as a checkbox inside the Sovereign Tweaker (Scenario 2's GUI) when running in debloat mode.

**What it does:**
- Generates a fully configured `unattend.xml` targeting the offline Windows `Panther` directory
- Writes `SetupComplete.cmd` to `Windows\Setup\Scripts\` to create your user account and configure AutoLogon
- Triggers a Sysprep `/oobe` pass via `SovereignSysprep.cmd` which replaces the normal OOBE with your unattended configuration
- Injects the registry keys `BypassNRO`, `SkipMachineOOBE`, `SkipUserOOBE` to suppress all OOBE screens
- Sets `SetupType=1` in the SYSTEM hive so Windows runs the Setup boot phase, then hands off to `windeploy.exe` under your unattend

**The result:** On next boot, Windows completes OOBE silently, creates your specified local account, enables AutoLogon, and drops you to the desktop — no Microsoft Account prompts, no privacy nagging, no EULA clicking.

#### Step-by-Step Walkthrough

**Step 1 — Boot into Sovereign WinPE**

Boot from your Sovereign WinPE USB/ISO. The OEM/retail Windows drive must be visible from WinPE.

**Step 2 — Open the Sovereign Tweaker**

Launch the Sovereign Tweaker GUI (debloat mode). Select the pre-installed Windows drive.

**Step 3 — Enable the OOBE Bypass**

Check the **"New Preinstalled OOBE Bypass (use only if OOBE hasn't been setup)"** checkbox.

This enables the account credential fields:

| Field | What to enter |
|---|---|
| **Username** | Your desired local account name |
| **Password** | Your desired password (can be blank) |
| **Computer Name** | The machine's hostname (defaults to `Sovereign-PC`) |
| **Use Built-in Administrator** | Check to use the built-in `Administrator` account instead of creating a new user |

**Step 4 — Optionally debloat first**

With the OOBE bypass checkbox enabled, you can still select AppX packages and Hardcore Modules to remove. The debloat pipeline runs first, then the OOBE bypass is injected — giving you a fully cleaned, configured install in a single pass.

**Step 5 — Click ANALYZE SYSTEM and proceed**

Confirm the warning. The pipeline runs the debloat selection → then injects:
- `Windows\Panther\unattend.xml` with your credentials and AutoLogon
- `Windows\Setup\Scripts\SetupComplete.cmd` to create the user account
- `Windows\Setup\Scripts\SovereignSysprep.cmd` (runs `sysprep /oobe /unattend:...`)
- Offline registry keys: `BypassNRO=1`, `SkipMachineOOBE=1`, `SkipUserOOBE=1`, `SetupType=1`, `CmdLine=SovereignSysprep.cmd`

**Step 6 — Reboot**

On next boot, Sysprep runs silently under your unattend file. Windows completes OOBE automatically and logs in with your configured account. Done.

---

## ⚙️ Prerequisites Summary

| Requirement | Scenario 1 | Scenario 2 | Scenario 3 |
|---|:---:|:---:|:---:|
| Windows ADK + WinPE Add-on | ✅ (to build ISO) | ✅ (to build ISO) | ✅ (to build ISO) |
| .NET 8 SDK | ✅ (to build ISO) | ✅ (to build ISO) | ✅ (to build ISO) |
| Vanilla Windows 11 ISO | ✅ | ❌ | ❌ |
| Ventoy USB or VM | ✅ | ✅ | ✅ |
| Existing Windows install on target | ❌ | ✅ | ✅ (OEM/retail, not yet OOBE'd) |

---

## 🚀 Quick Build Reference

```powershell
# 1. Build the Sovereign WinPE ISO (elevated PowerShell)
.\publish.ps1

# Output: output\Sovereign_WinPE.iso
```

Place `Sovereign_WinPE.iso` (and your `windows.iso` for Scenario 1) on a Ventoy USB drive or mount in a VM. Boot and follow the GUI.

---

## 🔧 Live System Tweaking (No WinPE Required)

You can run the compiled `NewShell.exe` directly on a running Windows system to use the **Offline Tweaker** against a secondary drive, or run the debloat modules against drives you have administrative access to. The `.exe` is fully self-contained and safe to run on any host.

> [!NOTE]
> Running from within WinPE is strongly recommended for nuclear operations (Edge removal, Defender disabling, etc.) because WinPE bypasses TrustedInstaller and SYSTEM-level file locks on the offline image. Running live on a booted OS will encounter those protections and some operations may be blocked.

---

## 📁 Key Files Reference

| File | Purpose |
|---|---|
| [`publish.ps1`](publish.ps1) | Master build pipeline — builds the Sovereign WinPE ISO |
| [`NewShell/InstallerForm.cs`](NewShell/InstallerForm.cs) | Core GUI: both Installer and Tweaker modes |
| [`NewShell/Program.cs`](NewShell/Program.cs) | Entry point — launches `TaskbarForm` (custom WinPE shell) |
| [`NewShell/TaskbarForm.cs`](NewShell/TaskbarForm.cs) | Custom WinPE taskbar and launcher shell |
| [`NewShell/DesktopForm.cs`](NewShell/DesktopForm.cs) | WinPE desktop wallpaper renderer |
| [`NewShell/Generate-WinPEShl.ps1`](NewShell/Generate-WinPEShl.ps1) | Generates `winpeshl.ini` to hijack WinPE boot shell |
| [`tools/tools_manifest.json`](tools/tools_manifest.json) | Dependency manifest for auto-downloaded tools |
| [`clean.ps1`](clean.ps1) | Cleans build artifacts and mount directories |
