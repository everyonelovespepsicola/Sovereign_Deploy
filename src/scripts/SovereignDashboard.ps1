<#
.SYNOPSIS
    Sovereign Dashboard - Main Entry Point
#>

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Load PresentationFramework for WPF
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 0. Add C# type for DWM API to enable Dark Mode on the window title bar
if (-not ('DwmApi' -as [type])) {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class DwmApi {
        [DllImport("dwmapi.dll", PreserveSig = true)]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
    }
"@
}

# 0.5 Load Modules
$FunctionsPath = Join-Path $PSScriptRoot "Functions.ps1"
if (Test-Path $FunctionsPath) {
    . $FunctionsPath
}

$InterrogatorPath = Join-Path $PSScriptRoot "ImageInterrogator.ps1"
if (Test-Path $InterrogatorPath) {
    . $InterrogatorPath
}
$SurgicalPath = Join-Path $PSScriptRoot "SurgicalLoader.ps1"
if (Test-Path $SurgicalPath) {
    . $SurgicalPath
}
$UnattendPath = Join-Path $PSScriptRoot "UnattendGenerator.ps1"
if (Test-Path $UnattendPath) {
    . $UnattendPath
}
$DeepStatePath = Join-Path $PSScriptRoot "DeepStateResolution.ps1"
if (Test-Path $DeepStatePath) {
    . $DeepStatePath
}

# 1. Load the XAML Layout
$XamlPath = Join-Path $PSScriptRoot "DashboardLayout.xaml"
if (-not (Test-Path $XamlPath)) {
    Write-Error "Cannot find UI definition at $XamlPath"
    return
}

$XamlContent = Get-Content -Path $XamlPath -Raw
$XmlReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($XamlContent))
$Window = [System.Windows.Markup.XamlReader]::Load($XmlReader)
$Global:Window = $Window

# 2. Apply Dark Mode to Title Bar ("Handle") when Window initializes
$Window.Add_SourceInitialized({
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).EnsureHandle()
        $trueVal = 1
        [DwmApi]::DwmSetWindowAttribute($hwnd, 20, [ref]$trueVal, 4) | Out-Null # Windows 10 1903+ and Windows 11
        [DwmApi]::DwmSetWindowAttribute($hwnd, 19, [ref]$trueVal, 4) | Out-Null # Windows 10 1809
    })

# 3. Map GUI Controls to PowerShell Variables
$BtnMount = $Window.FindName("BtnMount")
$BtnBuild = $Window.FindName("BtnBuild")
$ComponentList = $Window.FindName("ComponentList")
$SearchBox = $Window.FindName("SearchBox")
$BtnSelectAll = $Window.FindName("BtnSelectAll")
$BtnPhysicalist = $Window.FindName("BtnPhysicalist")
$TxtWimPath = $Window.FindName("TxtWimPath")
$BtnBrowseWim = $Window.FindName("BtnBrowseWim")
$LnkDownloadIso = $Window.FindName("LnkDownloadIso")
$CmbWimIndex = $Window.FindName("CmbWimIndex")
$BtnScanWim = $Window.FindName("BtnScanWim")
$TxtUsername = $Window.FindName("TxtUsername")
$TxtPassword = $Window.FindName("TxtPassword")
$ChkBuiltInAdmin = $Window.FindName("ChkBuiltInAdmin")
$ChkToolRegionPolicy = $Window.FindName("ChkToolRegionPolicy")
$ChkToolDisableUCPD = $Window.FindName("ChkToolDisableUCPD")
$ChkToolBypassTPM = $Window.FindName("ChkToolBypassTPM")
$ChkToolKillCopilot = $Window.FindName("ChkToolKillCopilot")
$ChkToolKillRecall = $Window.FindName("ChkToolKillRecall")
$ChkToolKillEdge = $Window.FindName("ChkToolKillEdge")
$ChkToolWebSearch = $Window.FindName("ChkToolWebSearch")
$ChkToolCampaigns = $Window.FindName("ChkToolCampaigns")
$ChkToolPromos = $Window.FindName("ChkToolPromos")
$ChkToolKillOneDrive = $Window.FindName("ChkToolKillOneDrive")
$ChkToolKillDefender = $Window.FindName("ChkToolKillDefender")
$ChkToolCustomInstaller = $Window.FindName("ChkToolCustomInstaller")
$ChkToolQoLTweaks = $Window.FindName("ChkToolQoLTweaks")
$ChkToolDisableIndexing = $Window.FindName("ChkToolDisableIndexing")
$ChkToolInstallOpenShell = $Window.FindName("ChkToolInstallOpenShell")
$OptNukeNone = $Window.FindName("OptNukeNone")
$OptNukeWhitelisted = $Window.FindName("OptNukeWhitelisted")
$OptNukeAll = $Window.FindName("OptNukeAll")
$OptWuDefault = $Window.FindName("OptWuDefault")
$OptWuSecurity = $Window.FindName("OptWuSecurity")
$OptWuDisable = $Window.FindName("OptWuDisable")

# Initialize Mount Button State
$Global:IsWimMounted = $false
$BrushConverter = New-Object System.Windows.Media.BrushConverter
$BtnMount.Background = $BrushConverter.ConvertFromString("#C83232") # Red (Unmounted)
$BtnMount.Foreground = $BrushConverter.ConvertFromString("#FFFFFF")

# Initialize sequential Solid Border
function Set-Glow {
    param($ButtonToGlow)
    $BtnBrowseWim.BorderThickness = 0
    $BtnScanWim.BorderThickness = 0
    $BtnMount.BorderThickness = 0
    $BtnBuild.BorderThickness = 0

    $BtnBrowseWim.Effect = $null
    $BtnScanWim.Effect = $null
    $BtnMount.Effect = $null
    $BtnBuild.Effect = $null

    if ($null -ne $ButtonToGlow) {
        $ButtonToGlow.BorderBrush = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(0, 255, 0))
        $ButtonToGlow.BorderThickness = 2
    }
}

Set-Glow $BtnBrowseWim

# 3.5 Session Recovery Check
$Window.Add_Loaded({
        $activeMounts = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -match "Sovereign_Mount" }
        if ($activeMounts) {
            $res = [System.Windows.MessageBox]::Show("An active Sovereign session was detected in the working folders.`n`nWould you like to RELOAD the session? (Click 'No' to unmount and clear folders)", "Session Recovery", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
            if ($res -eq 'Yes') {
                $firstMount = $activeMounts[0]
                $TxtWimPath.Text = $firstMount.ImagePath
                $index = $firstMount.ImageIndex
                if (-not $index) { $index = 1 }
                $CmbWimIndex.Items.Clear()
                $CmbWimIndex.Items.Add("[$index] Recovered Session") | Out-Null
                $CmbWimIndex.SelectedIndex = 0

                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([System.Action] {
                        $BtnMount.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
                    }) | Out-Null
            }
            else {
                Invoke-WithTerminal -Title "Sovereign Terminal - Cleanup" -Arguments @{ ScriptDir = $PSScriptRoot } -ScriptBlock {
                    param($argsHash)
                    $activeMounts = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -match "Sovereign_" }
                    if ($activeMounts) {
                        Write-Host "SOV_YELLOW:Cleaning up working folders..."
                        foreach ($mount in $activeMounts) {
                            Write-Host "SOV_DARKGRAY:  -> Unmounting $($mount.Path)..."
                            try { Dismount-WindowsImage -Path $mount.Path -Discard -ErrorAction Stop | Out-Null } catch {
                                Write-Host "SOV_RED:Dismount failed for $($mount.Path): $($_.Exception.Message)"
                            }
                        }
                    }
                    Write-Host "SOV_DARKGRAY:Attempting emergency DISM cleanup..."
                    try { & dism.exe /Cleanup-Wim | Out-Null } catch {}
                    try { Clear-WindowsCorruptMountPoint -ErrorAction SilentlyContinue | Out-Null } catch {}

                    $folders = @(
                        Join-Path $argsHash.ScriptDir "Sovereign_Mount",
                        Join-Path $argsHash.ScriptDir "Sovereign_BootMount",
                        Join-Path $argsHash.ScriptDir "Sovereign_ISORoot"
                    )
                    foreach ($f in $folders) {
                        if (Test-Path $f) {
                            Write-Host "SOV_DARKGRAY:  -> Removing $f..."
                            cmd.exe /c "rmdir /s /q `"$f`"" | Out-Null
                        }
                    }
                    Write-Host "SOV_GREEN:Cleanup Complete."
                }
            }
        }
    })

# 3.6 Exit Warning Check
$Window.Add_Closing({
        param($sender, $e)
        if ($Global:IsWimMounted) {
            $res = [System.Windows.MessageBox]::Show("A WIM image is currently mounted.`n`nWould you like to unmount and clean up before exiting to prevent orphaned sessions?", "Active Mount Detected", [System.Windows.MessageBoxButton]::YesNoCancel, [System.Windows.MessageBoxImage]::Warning)
            if ($res -eq 'Cancel') {
                $e.Cancel = $true
            }
            elseif ($res -eq 'Yes') {
                Invoke-WithTerminal -Title "Sovereign Terminal - Cleanup & Exit" -Arguments @{ ScriptDir = $PSScriptRoot } -ScriptBlock {
                    param($argsHash)
                    $activeMounts = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -match "Sovereign_" }
                    if ($activeMounts) {
                        Write-Host "SOV_YELLOW:Unmounting WIM(s) before exit..."
                        foreach ($mount in $activeMounts) {
                            Write-Host "SOV_DARKGRAY:  -> Unmounting $($mount.Path)..."
                            try { Dismount-WindowsImage -Path $mount.Path -Discard -ErrorAction Stop | Out-Null } catch {
                                Write-Host "SOV_RED:Dismount failed for $($mount.Path): $($_.Exception.Message)"
                            }
                        }
                    }
                    Write-Host "SOV_DARKGRAY:Attempting emergency DISM cleanup..."
                    try { & dism.exe /Cleanup-Wim | Out-Null } catch {}
                    try { Clear-WindowsCorruptMountPoint -ErrorAction SilentlyContinue | Out-Null } catch {}

                    $folders = @(
                        Join-Path $argsHash.ScriptDir "Sovereign_Mount",
                        Join-Path $argsHash.ScriptDir "Sovereign_BootMount"
                    )
                    foreach ($f in $folders) {
                        if (Test-Path $f) {
                            Write-Host "SOV_DARKGRAY:  -> Removing $f..."
                            cmd.exe /c "rmdir /s /q `"$f`"" | Out-Null
                        }
                    }
                    Write-Host "SOV_GREEN:Cleanup Complete. Exiting..."
                }
            }
        }
    })

# 4. Hook up Events (Placeholders for upcoming modules)
$ChkToolRegionPolicy.Add_Checked({
        $ChkToolDisableUCPD.IsChecked = $true
        if ($ChkToolKillCopilot) { $ChkToolKillCopilot.IsEnabled = $true }
        if ($ChkToolKillRecall) { $ChkToolKillRecall.IsEnabled = $true }
        if ($ChkToolKillEdge) { $ChkToolKillEdge.IsEnabled = $true }
        if ($ChkToolWebSearch) { $ChkToolWebSearch.IsEnabled = $true }
        if ($ChkToolCampaigns) { $ChkToolCampaigns.IsEnabled = $true }
        if ($ChkToolPromos) { $ChkToolPromos.IsEnabled = $true }
        if ($ChkToolKillOneDrive) { $ChkToolKillOneDrive.IsEnabled = $true }
        if ($ChkToolQoLTweaks) { $ChkToolQoLTweaks.IsEnabled = $true }
        if ($ChkToolDisableIndexing) { $ChkToolDisableIndexing.IsEnabled = $true }
        if ($ChkToolInstallOpenShell) { $ChkToolInstallOpenShell.IsEnabled = $true }
        if ($OptNukeNone) { $OptNukeNone.IsEnabled = $true }
        if ($OptNukeWhitelisted) { $OptNukeWhitelisted.IsEnabled = $true }
        if ($OptNukeAll) { $OptNukeAll.IsEnabled = $true }
    })

$ChkToolRegionPolicy.Add_Unchecked({
        if ($ChkToolKillCopilot) { $ChkToolKillCopilot.IsEnabled = $false; $ChkToolKillCopilot.IsChecked = $false }
        if ($ChkToolKillRecall) { $ChkToolKillRecall.IsEnabled = $false; $ChkToolKillRecall.IsChecked = $false }
        if ($ChkToolKillEdge) { $ChkToolKillEdge.IsEnabled = $false; $ChkToolKillEdge.IsChecked = $false }
        if ($ChkToolWebSearch) { $ChkToolWebSearch.IsEnabled = $false; $ChkToolWebSearch.IsChecked = $false }
        if ($ChkToolCampaigns) { $ChkToolCampaigns.IsEnabled = $false; $ChkToolCampaigns.IsChecked = $false }
        if ($ChkToolPromos) { $ChkToolPromos.IsEnabled = $false; $ChkToolPromos.IsChecked = $false }
        if ($ChkToolKillOneDrive) { $ChkToolKillOneDrive.IsEnabled = $false; $ChkToolKillOneDrive.IsChecked = $false }
        if ($ChkToolQoLTweaks) { $ChkToolQoLTweaks.IsEnabled = $false; $ChkToolQoLTweaks.IsChecked = $false }
        if ($ChkToolDisableIndexing) { $ChkToolDisableIndexing.IsEnabled = $false; $ChkToolDisableIndexing.IsChecked = $false }
        if ($ChkToolInstallOpenShell) { $ChkToolInstallOpenShell.IsEnabled = $false; $ChkToolInstallOpenShell.IsChecked = $false }
        if ($OptNukeNone) { $OptNukeNone.IsEnabled = $false; $OptNukeNone.IsChecked = $true }
        if ($OptNukeWhitelisted) { $OptNukeWhitelisted.IsEnabled = $false }
        if ($OptNukeAll) { $OptNukeAll.IsEnabled = $false }
    })

$AppxAllowList = @(
    "Microsoft.DesktopAppInstaller",
    "Microsoft.WindowsTerminal",
    "Microsoft.SecHealthUI",
    "Microsoft.WindowsStore",
    "Microsoft.StorePurchaseApp",
    "Microsoft.UI.Xaml",
    "Microsoft.VCLibs",
    "Microsoft.VP9VideoExtensions",
    "Microsoft.AV1VideoExtension",
    "Microsoft.HEVCVideoExtension",
    "Microsoft.WebpImageExtension",
    "Microsoft.ScreenSketch",
    "Microsoft.WindowsNotepad",
    "Microsoft.WindowsCalculator",
    "Microsoft.GamingServices"
) -join "|"

if ($OptNukeNone) {
    $OptNukeNone.Add_Checked({
            if ($Global:ComponentData) {
                foreach ($item in $Global:ComponentData) {
                    if ($item.Type -eq "AppxPackage") {
                        $item.Action = $true
                    }
                }
                if ($Global:CollectionView) { $Global:CollectionView.Refresh() }
            }
        })
}

if ($OptNukeWhitelisted) {
    $OptNukeWhitelisted.Add_Checked({
            if ($Global:ComponentData) {
                foreach ($item in $Global:ComponentData) {
                    if ($item.Type -eq "AppxPackage") {
                        if ($item.Name -match "(?i)($AppxAllowList)") {
                            $item.Action = $true
                        }
                        else {
                            $item.Action = $false
                        }
                    }
                }
                if ($Global:CollectionView) { $Global:CollectionView.Refresh() }
            }
        })
}

if ($OptNukeAll) {
    $OptNukeAll.Add_Checked({
            if ($Global:ComponentData) {
                foreach ($item in $Global:ComponentData) {
                    if ($item.Type -eq "AppxPackage") {
                        if ($item.Name -match "(?i)(Microsoft\.VCLibs|Microsoft\.UI\.Xaml|Microsoft\.DesktopAppInstaller)") {
                            $item.Action = $true
                        }
                        else {
                            $item.Action = $false
                        }
                    }
                }
                if ($Global:CollectionView) { $Global:CollectionView.Refresh() }
            }
        })
}

function Invoke-WithTerminal {
    param(
        [string]$Title,
        [scriptblock]$ScriptBlock,
        [hashtable]$Arguments,
        [switch]$ShowKeepAlive
    )

    if ($Global:Window) {
        $Global:Window.IsEnabled = $false
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([System.Action] {}, 'Background')
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(1100, 800)
    $form.BackColor = [System.Drawing.Color]::FromArgb(255, 30, 30, 30)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(255, 241, 241, 241)
    $form.Font = New-Object System.Drawing.Font("Consolas", 11)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.ShowIcon = $false
    $form.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic).SetValue($form, $true, $null)

    $Global:KeepSessionAlive = $false

    $pnlButtons = New-Object System.Windows.Forms.Panel
    $pnlButtons.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $pnlButtons.Height = 50
    $pnlButtons.Visible = $false
    $form.Controls.Add($pnlButtons)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = if ($ShowKeepAlive) { "Process Complete - Finish & Clear Session" } else { "Process Complete - Click Here to Return to Dashboard" }
    $btnClose.Dock = if ($ShowKeepAlive) { [System.Windows.Forms.DockStyle]::Left } else { [System.Windows.Forms.DockStyle]::Fill }
    if ($ShowKeepAlive) { $btnClose.Width = 550 }
    $btnClose.BackColor = if ($ShowKeepAlive) { [System.Drawing.Color]::FromArgb(255, 200, 50, 50) } else { [System.Drawing.Color]::FromArgb(255, 0, 122, 204) }
    $btnClose.ForeColor = [System.Drawing.Color]::White
    $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClose.Add_Click({
            $Global:KeepSessionAlive = $false
            if ($form -and -not $form.IsDisposed) { $form.Close() }
        }.GetNewClosure())
    $pnlButtons.Controls.Add($btnClose)

    if ($ShowKeepAlive) {
        $btnKeep = New-Object System.Windows.Forms.Button
        $btnKeep.Text = "Return & Keep Session in RAM"
        $btnKeep.Dock = [System.Windows.Forms.DockStyle]::Right
        $btnKeep.Width = 550
        $btnKeep.BackColor = [System.Drawing.Color]::FromArgb(255, 46, 139, 87)
        $btnKeep.ForeColor = [System.Drawing.Color]::White
        $btnKeep.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
        $btnKeep.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnKeep.Add_Click({
                $Global:KeepSessionAlive = $true
                if ($form -and -not $form.IsDisposed) { $form.Close() }
            }.GetNewClosure())
        $pnlButtons.Controls.Add($btnKeep)
    }

    $textBox = New-Object System.Windows.Forms.RichTextBox
    $textBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $textBox.BackColor = [System.Drawing.Color]::FromArgb(255, 30, 30, 30)
    $textBox.ForeColor = [System.Drawing.Color]::FromArgb(255, 241, 241, 241)
    $textBox.ReadOnly = $true
    $textBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $textBox.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic).SetValue($textBox, $true, $null)
    $form.Controls.Add($textBox)

    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript($ScriptBlock).AddArgument($Arguments) | Out-Null

    $asyncHandle = $ps.BeginInvoke()

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16

    $Global:TerminalResult = $null

    $colorMap = @{
        "CYAN"     = [System.Drawing.Color]::FromArgb(255, 0, 122, 204);
        "GREEN"    = [System.Drawing.Color]::FromArgb(255, 46, 139, 87);
        "YELLOW"   = [System.Drawing.Color]::FromArgb(255, 212, 160, 23);
        "RED"      = [System.Drawing.Color]::FromArgb(255, 231, 76, 60);
        "DARKRED"  = [System.Drawing.Color]::FromArgb(255, 192, 57, 43);
        "DARKGRAY" = [System.Drawing.Color]::FromArgb(255, 170, 170, 170);
        "DEFAULT"  = [System.Drawing.Color]::FromArgb(255, 241, 241, 241);
    }
    $defaultColor = $colorMap.DEFAULT

    $form.Add_FormClosing({
            param($sender, $e)
            if ($form.Tag -ne "Done") {
                $res = [System.Windows.Forms.MessageBox]::Show(
                    "A background operation is currently running.`n`nForcefully closing this terminal may leave Windows images mounted, files locked, or cause data corruption.`n`nAre you absolutely sure you want to abort?",
                    "Warning: Operation in Progress",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                if ($res -eq [System.Windows.Forms.DialogResult]::No) {
                    $e.Cancel = $true
                }
                else {
                    try { $ps.Stop() } catch {}
                }
            }
        })

    $timer.Add_Tick({
            if ($form.Tag -eq "Done") { return }

            $textAppended = $false

            if ($ps -and $ps.Streams) {
                if ($null -ne $ps.Streams.Information) {
                    foreach ($infoItem in $ps.Streams.Information.ReadAll()) {
                        if ($infoItem) {
                            $message = $infoItem.MessageData.ToString()
                            $color = $defaultColor
                            if ($message -match '^SOV_([A-Z]+):(.*)') {
                                $colorKey = $matches[1]
                                $text = $matches[2]
                                if ($colorMap.ContainsKey($colorKey)) {
                                    $color = $colorMap[$colorKey]
                                }
                                $textBox.SelectionColor = $color
                                $textBox.AppendText($text + "`n")
                            }
                            else {
                                $textBox.SelectionColor = $defaultColor
                                $textBox.AppendText($message + "`n")
                            }
                            $textAppended = $true
                        }
                    }
                }
                if ($null -ne $ps.Streams.Error) {
                    foreach ($errItem in $ps.Streams.Error.ReadAll()) {
                        if ($errItem) {
                            $textBox.SelectionColor = $colorMap.RED
                            $textBox.AppendText("ERROR: " + $errItem.ToString() + "`n")
                            $textAppended = $true
                        }
                    }
                }
            }

            if ($textAppended) {
                $textBox.SelectionStart = $textBox.Text.Length
                $textBox.ScrollToCaret()
            }

            if ($asyncHandle.IsCompleted) {
                $timer.Stop()
                $form.Tag = "Done"

                $Global:TerminalResult = $ps.EndInvoke($asyncHandle)
                $ps.Dispose()
                $runspace.Close()
                $runspace.Dispose()
                $textBox.AppendText("`n[Process Complete.]")
                $textBox.SelectionStart = $textBox.Text.Length
                $textBox.ScrollToCaret()

                $pnlButtons.Visible = $true
                $textBox.Refresh()
            }
        }.GetNewClosure())

    $form.Add_Load({ $timer.Start() })
    $form.ShowDialog() | Out-Null

    if ($Global:Window) {
        $Global:Window.IsEnabled = $true
        $Global:Window.Activate()
        $Global:Window.Focus() | Out-Null
    }
    return $Global:TerminalResult
}

$ChkToolDisableUCPD.Add_Unchecked({
        $ChkToolRegionPolicy.IsChecked = $false
    })

$LnkDownloadIso.Add_Click({
        Start-Process "https://www.microsoft.com/software-download/windows11" -ErrorAction SilentlyContinue
    })

$BtnBrowseWim.Add_Click({
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "ISO Files (*.iso)|*.iso|All Files (*.*)|*.*"
        $openFileDialog.Title = "Select a Windows ISO file"
        if ($openFileDialog.ShowDialog() -eq $true) {
            $TxtWimPath.Text = $openFileDialog.FileName
        }
    })

$TxtWimPath.Add_PreviewDragOver({
        param($sender, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $e.Effects = [System.Windows.DragDropEffects]::Copy
        }
        else {
            $e.Effects = [System.Windows.DragDropEffects]::None
        }
        $e.Handled = $true
    })

$TxtWimPath.Add_Drop({
        param($sender, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
            if ($files -and $files.Count -gt 0) {
                $TxtWimPath.Text = $files[0]
            }
        }
    })

$TxtWimPath.Add_TextChanged({
        if (-not [string]::IsNullOrWhiteSpace($TxtWimPath.Text) -and -not $Global:IsWimMounted) {
            Set-Glow $BtnScanWim
        }
        elseif ([string]::IsNullOrWhiteSpace($TxtWimPath.Text)) {
            Set-Glow $BtnBrowseWim
        }
    })

$BtnScanWim.Add_Click({
        if ([string]::IsNullOrWhiteSpace($TxtWimPath.Text) -or -not (Test-Path $TxtWimPath.Text) -or $TxtWimPath.Text -notmatch '(?i)\.iso$') {
            [System.Windows.MessageBox]::Show("Please provide a valid ISO path to scan!", "Error", 0, 16) | Out-Null
            return
        }

        $scanArgs = @{ WimPath = $TxtWimPath.Text }
        $terminalResult = Invoke-WithTerminal -Title "Sovereign Terminal - Scanning Image Editions" -Arguments $scanArgs -ScriptBlock {
            param($argsHash)
            $wimPath = $argsHash.WimPath
            $isoDrive = $null
            $imageInfo = $null

            try {
                if ($wimPath -match '(?i)\.iso$') {
                    Write-Host "SOV_CYAN:ISO file detected. Mounting momentarily to read editions..."
                    $MountResult = Mount-DiskImage -ImagePath $wimPath -PassThru
                    $DriveLetter = ($MountResult | Get-Volume).DriveLetter
                    if (-not $DriveLetter) {
                        Start-Sleep -Seconds 2
                        $DriveLetter = (Get-DiskImage -ImagePath $wimPath | Get-Volume).DriveLetter
                    }
                    if ($DriveLetter) {
                        $isoDrive = "$($DriveLetter):"
                        if (Test-Path "$isoDrive\sources\install.wim") { $targetWim = "$isoDrive\sources\install.wim" }
                        elseif (Test-Path "$isoDrive\sources\install.esd") { $targetWim = "$isoDrive\sources\install.esd" }
                        else { Write-Host "SOV_RED:Could not find install.wim or install.esd in the ISO!" }

                        if ($targetWim) {
                            Write-Host "SOV_DARKGRAY:  -> Reading image info from $targetWim..."
                            $imageInfo = Get-WindowsImage -ImagePath $targetWim
                        }
                    }
                }
                else {
                    Write-Host "SOV_DARKGRAY:  -> Reading image info from $wimPath..."
                    $imageInfo = Get-WindowsImage -ImagePath $wimPath
                }

                if ($imageInfo) {
                    Write-Host "SOV_GREEN:Successfully read editions."
                    $imageInfo | Select-Object ImageIndex, ImageName
                    return
                }
            }
            catch { Write-Host "SOV_RED:Error scanning WIM: $($_.Exception.Message)" }
            finally {
                if ($isoDrive) {
                    Write-Host "SOV_DARKGRAY:  -> Dismounting ISO..."
                    Dismount-DiskImage -ImagePath $wimPath -ErrorAction SilentlyContinue | Out-Null
                }
            }
            return $null
        }

        if ($terminalResult) {
            $CmbWimIndex.Items.Clear()
            $proIndex = -1
            $currentIndex = 0
            foreach ($img in $terminalResult) {
                if ($img -and $img.ImageIndex) {
                    $CmbWimIndex.Items.Add("[$($img.ImageIndex)] $($img.ImageName)") | Out-Null

                    # Look for standard Pro edition (ignores Pro Education / Pro for Workstations)
                    if ($proIndex -eq -1 -and $img.ImageName -match '(?i)\bPro\b' -and $img.ImageName -notmatch '(?i)(Education|Workstation)') {
                        $proIndex = $currentIndex
                    }
                    $currentIndex++
                }
            }
            if ($CmbWimIndex.Items.Count -gt 0) {
                if ($proIndex -ne -1) { $CmbWimIndex.SelectedIndex = $proIndex } else { $CmbWimIndex.SelectedIndex = 0 }
            }

            Set-Glow $BtnMount
        }
    })

$BtnMount.Add_Click({
        if (-not $Global:IsWimMounted) {
            if ([string]::IsNullOrWhiteSpace($TxtWimPath.Text) -or -not (Test-Path $TxtWimPath.Text) -or $TxtWimPath.Text -notmatch '(?i)\.iso$') {
                [System.Windows.MessageBox]::Show("Please provide a valid ISO path!", "Error", 0, 16) | Out-Null
                return
            }

            $selectedIndex = 1
            if ($CmbWimIndex.SelectedItem) {
                if ($CmbWimIndex.SelectedItem.ToString() -match '\[(\d+)\]') {
                    $selectedIndex = [int]$matches[1]
                }
            }

            $mountArgs = @{
                WimPath   = $TxtWimPath.Text
                ScriptDir = $PSScriptRoot
                MountDir  = Join-Path $PSScriptRoot "Sovereign_Mount"
                IsoRoot   = Join-Path $PSScriptRoot "Sovereign_ISORoot"
                Index     = $selectedIndex
            }

            $terminalResult = Invoke-WithTerminal -Title "Sovereign Terminal - Mounting Image" -Arguments $mountArgs -ScriptBlock {
                param($argsHash)
                $wimPath = $argsHash.WimPath
                $isoRoot = $argsHash.IsoRoot

                if ($wimPath -match '(?i)\.iso$') {
                    Write-Host "SOV_CYAN:ISO file detected. Attempting to extract contents..."
                    $MountResult = Mount-DiskImage -ImagePath $wimPath -PassThru
                    $DriveLetter = ($MountResult | Get-Volume).DriveLetter

                    if (-not $DriveLetter) {
                        Start-Sleep -Seconds 2
                        $DriveLetter = (Get-DiskImage -ImagePath $wimPath | Get-Volume).DriveLetter
                    }

                    if ($DriveLetter) {
                        Write-Host "SOV_CYAN:Copying files from $($DriveLetter):\ to $isoRoot (This might take a few minutes)..."
                        if (Test-Path $isoRoot) { cmd.exe /c "rmdir /s /q `"$isoRoot`"" | Out-Null }
                        New-Item -ItemType Directory -Path $isoRoot -Force | Out-Null

                        Write-Host "SOV_DARKGRAY:Extracting files natively..."
                        & cmd.exe /c "xcopy /y /e /h /i `"$($DriveLetter):\*`" `"$isoRoot\`" >nul"

                        Dismount-DiskImage -ImagePath $wimPath | Out-Null

                        Write-Host "SOV_CYAN:Removing Read-Only attributes from extracted files..."
                        Get-ChildItem -Path $isoRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.IsReadOnly } | ForEach-Object { $_.IsReadOnly = $false }

                        if (Test-Path "$isoRoot\sources\install.wim") {
                            $wimPath = "$isoRoot\sources\install.wim"
                            Write-Host "SOV_GREEN:Extraction complete. Found install.wim."
                        }
                        elseif (Test-Path "$isoRoot\sources\install.esd") {
                            $wimPath = "$isoRoot\sources\install.esd"
                            Write-Host "SOV_YELLOW:Extraction complete. Found install.esd (Note: ESD files cannot be modified directly)."
                        }
                        else {
                            Write-Host "SOV_RED:Could not find install.wim or install.esd in the extracted ISO!"
                            return $null
                        }
                    }
                    else {
                        Write-Host "SOV_RED:Could not assign a drive letter to the mounted ISO."
                        Dismount-DiskImage -ImagePath $wimPath -ErrorAction SilentlyContinue | Out-Null
                        return $null
                    }
                }

                . (Join-Path $argsHash.ScriptDir "ImageInterrogator.ps1")
                $compList = Get-SovereignComponentList -WimPath $wimPath -Index $argsHash.Index -MountPath $argsHash.MountDir
                return @{ ExtractedWimPath = $wimPath; ComponentData = $compList }
            }

            if ($null -ne $terminalResult -and $null -ne $terminalResult.ComponentData) {
                $Global:ExtractedWimPath = $terminalResult.ExtractedWimPath

                $Global:ComponentData = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
                foreach ($item in $terminalResult.ComponentData) {
                    $Global:ComponentData.Add($item)
                }
                $ComponentList.ItemsSource = $Global:ComponentData

                $BtnMount.Content = "Unmount WIM"
                $BtnMount.Background = $BrushConverter.ConvertFromString("#2E8B57") # Green (Mounted)
                $Global:IsWimMounted = $true

                $Global:CollectionView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($ComponentList.ItemsSource)
                $Global:CollectionView.GroupDescriptions.Clear()
                $Global:CollectionView.GroupDescriptions.Add((New-Object System.Windows.Data.PropertyGroupDescription("Category")))

                $Global:FilterText = $SearchBox.Text
                if (-not [string]::IsNullOrWhiteSpace($Global:FilterText)) {
                    $Global:CollectionView.Filter = [System.Predicate[System.Object]] {
                        param($item)
                        return ($item.Name -match "(?i)$Global:FilterText") -or
                        ($item.DisplayName -match "(?i)$Global:FilterText") -or
                        ($item.Description -match "(?i)$Global:FilterText")
                    }
                }

                Set-Glow $BtnBuild
            }
        }
        else {
            Invoke-WithTerminal -Title "Sovereign Terminal - Unmounting WIM" -Arguments @{ ScriptDir = $PSScriptRoot } -ScriptBlock {
                param($argsHash)
                $activeMounts = Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -match "Sovereign_Mount" }
                if ($activeMounts) {
                    Write-Host "SOV_YELLOW:Manually unmounting WIM(s)..."
                    foreach ($mount in $activeMounts) {
                        Write-Host "SOV_DARKGRAY:  -> Unmounting $($mount.Path)..."
                        try { Dismount-WindowsImage -Path $mount.Path -Discard -ErrorAction Stop | Out-Null } catch {
                            Write-Host "SOV_RED:Dismount failed for $($mount.Path): $($_.Exception.Message)"
                        }
                    }
                }
                else {
                    Write-Host "SOV_DARKGRAY:No active WIM mount found to unmount."
                }
                Write-Host "SOV_DARKGRAY:Attempting emergency DISM cleanup..."
                try { & dism.exe /Cleanup-Wim | Out-Null } catch {}
                try { Clear-WindowsCorruptMountPoint -ErrorAction SilentlyContinue | Out-Null } catch {}

                $folders = @(
                    Join-Path $argsHash.ScriptDir "Sovereign_Mount",
                    Join-Path $argsHash.ScriptDir "Sovereign_BootMount"
                )
                foreach ($f in $folders) {
                    if (Test-Path $f) {
                        Write-Host "SOV_DARKGRAY:  -> Removing $f..."
                        cmd.exe /c "rmdir /s /q `"$f`"" | Out-Null
                    }
                }
            }

            $Global:ComponentData = $null
            $ComponentList.ItemsSource = $null

            $BtnMount.Content = "Mount ISO..."
            $BtnMount.Background = $BrushConverter.ConvertFromString("#C83232") # Red (Unmounted)
            $Global:IsWimMounted = $false
            $Global:ExtractedWimPath = $null

            if (-not [string]::IsNullOrWhiteSpace($TxtWimPath.Text)) {
                Set-Glow $BtnScanWim
            }
            else {
                Set-Glow $BtnBrowseWim
            }
        }
    })

$SearchBox.Add_TextChanged({
        if ($Global:CollectionView) {
            $Global:FilterText = $SearchBox.Text
            if ([string]::IsNullOrWhiteSpace($Global:FilterText)) {
                $Global:CollectionView.Filter = $null
            }
            else {
                $Global:CollectionView.Filter = [System.Predicate[System.Object]] {
                    param($item)
                    return ($item.Name -match "(?i)$Global:FilterText") -or
                    ($item.DisplayName -match "(?i)$Global:FilterText") -or
                    ($item.Description -match "(?i)$Global:FilterText")
                }
            }
        }
    })

$BtnSelectAll.Add_Click({
        if ($Global:ComponentData) {
            $targetState = ($BtnSelectAll.Content -eq "Check All")
            foreach ($item in $Global:ComponentData) { $item.Action = $targetState }
            $BtnSelectAll.Content = if ($targetState) { "Uncheck All" } else { "Check All" }
            $BtnSelectAll.Background = if ($targetState) { $BrushConverter.ConvertFromString("#2E8B57") } else { $BrushConverter.ConvertFromString("#C83232") }
            $BtnSelectAll.Foreground = $BrushConverter.ConvertFromString("#FFFFFF")
            if ($Global:CollectionView) { $Global:CollectionView.Refresh() }
        }
    })

$BtnPhysicalist.Add_Click({
        if ($Global:ComponentData) {
            $bloatKeywords = "Copilot|Recall|Xbox|Bing|Zune|GetHelp|SmartAppControl|Telemetry|Edge|InternetExplorer|Browser"
            $isActive = ($BtnPhysicalist.Tag -ne "Active")

            foreach ($item in $Global:ComponentData) {
                if ($item.Name -match "(?i)($bloatKeywords)") { $item.Action = (-not $isActive) }
            }

            if ($isActive) {
                $BtnPhysicalist.Tag = "Active"
                $BtnPhysicalist.Background = $BrushConverter.ConvertFromString("#2E8B57")
            }
            else {
                $BtnPhysicalist.Tag = "Inactive"
                $BtnPhysicalist.Background = $BrushConverter.ConvertFromString("#C83232")
            }
            $BtnPhysicalist.Foreground = $BrushConverter.ConvertFromString("#FFFFFF")

            if ($Global:CollectionView) { $Global:CollectionView.Refresh() }
        }
    })

$BtnBuild.Add_Click({
        if ($Global:ComponentData) {
            $selectedIndex = 1
            if ($CmbWimIndex.SelectedItem) {
                if ($CmbWimIndex.SelectedItem.ToString() -match '\[(\d+)\]') {
                    $selectedIndex = [int]$matches[1]
                }
            }

            $useAdmin = if ($ChkBuiltInAdmin -and $ChkBuiltInAdmin.IsChecked) { $true } else { $false }
            $applyRegionPolicy = if ($ChkToolRegionPolicy -and $ChkToolRegionPolicy.IsChecked) { $true } else { $false }
            $disableUCPD = if ($ChkToolDisableUCPD -and $ChkToolDisableUCPD.IsChecked) { $true } else { $false }
            $bypassTPM = if ($ChkToolBypassTPM -and $ChkToolBypassTPM.IsChecked) { $true } else { $false }

            $wuMode = "Default"
            if ($OptWuSecurity -and $OptWuSecurity.IsChecked) { $wuMode = "Security" }
            if ($OptWuDisable -and $OptWuDisable.IsChecked) { $wuMode = "Disable" }

            $killCopilot = if ($ChkToolKillCopilot -and $ChkToolKillCopilot.IsChecked) { $true } else { $false }
            $killRecall = if ($ChkToolKillRecall -and $ChkToolKillRecall.IsChecked) { $true } else { $false }
            $killEdge = if ($ChkToolKillEdge -and $ChkToolKillEdge.IsChecked) { $true } else { $false }
            $killWebSearch = if ($ChkToolWebSearch -and $ChkToolWebSearch.IsChecked) { $true } else { $false }
            $killCampaigns = if ($ChkToolCampaigns -and $ChkToolCampaigns.IsChecked) { $true } else { $false }
            $killPromos = if ($ChkToolPromos -and $ChkToolPromos.IsChecked) { $true } else { $false }
            $killOneDrive = if ($ChkToolKillOneDrive -and $ChkToolKillOneDrive.IsChecked) { $true } else { $false }
            $killDefender = if ($ChkToolKillDefender -and $ChkToolKillDefender.IsChecked) { $true } else { $false }
            $useCustomInstaller = if ($ChkToolCustomInstaller -and $ChkToolCustomInstaller.IsChecked) { $true } else { $false }
            $applyQoLTweaks = if ($ChkToolQoLTweaks -and $ChkToolQoLTweaks.IsChecked) { $true } else { $false }
            $disableIndexing = if ($ChkToolDisableIndexing -and $ChkToolDisableIndexing.IsChecked) { $true } else { $false }
            $installOpenShell = if ($ChkToolInstallOpenShell -and $ChkToolInstallOpenShell.IsChecked) { $true } else { $false }

            $ComponentArray = @()
            foreach ($c in $Global:ComponentData) { $ComponentArray += $c | Select-Object * }

            $BuildArgs = @{
                ComponentData      = $ComponentArray
                ScriptDir          = $PSScriptRoot
                MountPath          = Join-Path $PSScriptRoot "Sovereign_Mount"
                IsoRoot            = Join-Path $PSScriptRoot "Sovereign_ISORoot"
                WimPath            = $Global:ExtractedWimPath
                WimIndex           = $selectedIndex
                Username           = $TxtUsername.Text
                Password           = $TxtPassword.Text
                UseBuiltInAdmin    = $useAdmin
                ApplyRegionPolicy  = $applyRegionPolicy
                DisableUCPD        = $disableUCPD
                BypassTPM          = $bypassTPM
                WuMode             = $wuMode
                KillCopilot        = $killCopilot
                KillRecall         = $killRecall
                KillEdge           = $killEdge
                KillWebSearch      = $killWebSearch
                KillCampaigns      = $killCampaigns
                KillPromos         = $killPromos
                KillOneDrive       = $killOneDrive
                KillDefender       = $killDefender
                UseCustomInstaller = $useCustomInstaller
                ApplyQoLTweaks     = $applyQoLTweaks
                DisableIndexing    = $disableIndexing
                InstallOpenShell   = $installOpenShell
            }

            Invoke-WithTerminal -Title "Sovereign Terminal - Building ISO" -Arguments $BuildArgs -ShowKeepAlive -ScriptBlock {
                param($argsHash)
                $LogFile = Join-Path $argsHash.ScriptDir "SovereignBuild.log"
                Start-Transcript -Path $LogFile -Force
                $ProgressPreference = 'SilentlyContinue'
                . (Join-Path $argsHash.ScriptDir "UnattendGenerator.ps1")
                . (Join-Path $argsHash.ScriptDir "SurgicalLoader.ps1")
                . (Join-Path $argsHash.ScriptDir "DeepStateResolution.ps1")
                if (Test-Path (Join-Path $argsHash.ScriptDir "Functions.ps1")) { . (Join-Path $argsHash.ScriptDir "Functions.ps1") }

                $obs = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
                foreach ($c in $argsHash.ComponentData) { $obs.Add($c) }
                $argsHash.ComponentData = $obs

                Invoke-SovereignBuild @argsHash

                Stop-Transcript
                Write-Host "SOV_GREEN:Build Complete! Your Sovereign ISO is ready."
            }

            if (-not $Global:KeepSessionAlive) {
                $Global:ComponentData = $null
                $ComponentList.ItemsSource = $null
                $BtnMount.Content = "Mount ISO..."
                $BtnMount.Background = $BrushConverter.ConvertFromString("#C83232")
                $Global:IsWimMounted = $false
                $Global:ExtractedWimPath = $null

                $BtnBuild.IsEnabled = $false
                $BtnBuild.Background = $BrushConverter.ConvertFromString("#007ACC")
                $CmbWimIndex.BorderBrush = $BrushConverter.ConvertFromString("#2E8B57")
                $CmbWimIndex.BorderThickness = 2

                Set-Glow $BtnBrowseWim
            }
            else {
                $BtnBuild.IsEnabled = $true
                Set-Glow $BtnBuild
            }
        }
        else {
            [System.Windows.MessageBox]::Show("Please mount a WIM file first!", "Warning", 0, 48) | Out-Null
        }
    })

# 5. Launch the Dashboard
$Window.ShowDialog() | Out-Null
