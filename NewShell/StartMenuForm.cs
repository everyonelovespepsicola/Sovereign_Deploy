using System;
using System.Drawing;
using System.Windows.Forms;
using System.Diagnostics;
using System.IO;
using Microsoft.Win32;

namespace CustomShell
{
    public class StartMenuForm : Form
    {
        public StartMenuForm()
        {
            this.FormBorderStyle = FormBorderStyle.None;
            this.TopMost = true;
            this.BackColor = Color.FromArgb(45, 45, 45);
            this.Size = new Size(300, 680);
            this.StartPosition = FormStartPosition.Manual;
            this.ShowInTaskbar = false;

            Label title = new Label();
            title.Text = "Sovereign Menu";
            title.Font = new Font("Segoe UI Semibold", 16, FontStyle.Regular);
            title.ForeColor = Color.White;
            title.Location = new Point(20, 20);
            title.AutoSize = true;
            this.Controls.Add(title);

            // The massive Sovereign Deploy button
            Button deployBtn = new Button();
            deployBtn.Text = "SOVEREIGN DEPLOY";
            deployBtn.Font = new Font("Segoe UI Semibold", 14, FontStyle.Bold);
            deployBtn.FlatStyle = FlatStyle.Flat;
            deployBtn.FlatAppearance.BorderSize = 0;
            deployBtn.BackColor = Color.FromArgb(180, 0, 0); // Red
            deployBtn.ForeColor = Color.White;
            deployBtn.Size = new Size(260, 50);
            deployBtn.Location = new Point(20, 60);
            bool isWinPE = Registry.LocalMachine.OpenSubKey(@"System\CurrentControlSet\Control\MiniNT") != null;

            deployBtn.Click += (s, e) => { 
                if (!isWinPE) {
                    MessageBox.Show("Deployment mode is strictly locked to the WinPE environment to prevent accidental data loss.\n\nPlease boot from the Sovereign_WinPE.iso to deploy.", "CRITICAL ERROR", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }
                new InstallerForm(DeployScenario.CleanInstall).Show(); 
                this.Hide(); 
            };
            SetRoundedRegion(deployBtn, 10);
            this.Controls.Add(deployBtn);

            Button tweakBtn = new Button();
            tweakBtn.Text = "SOVEREIGN TWEAKER";
            tweakBtn.Font = new Font("Segoe UI Semibold", 12, FontStyle.Bold);
            tweakBtn.FlatStyle = FlatStyle.Flat;
            tweakBtn.FlatAppearance.BorderSize = 0;
            tweakBtn.BackColor = Color.FromArgb(0, 120, 215); // Blue
            tweakBtn.ForeColor = Color.White;
            tweakBtn.Size = new Size(260, 40);
            tweakBtn.Location = new Point(20, 120);
            tweakBtn.Click += (s, e) => { 
                new InstallerForm(DeployScenario.OfflineTweaker).Show(); 
                this.Hide(); 
            };
            SetRoundedRegion(tweakBtn, 10);
            this.Controls.Add(tweakBtn);

            Button oobeBtn = new Button();
            oobeBtn.Text = "OEM OOBE BYPASS";
            oobeBtn.Font = new Font("Segoe UI Semibold", 12, FontStyle.Bold);
            oobeBtn.FlatStyle = FlatStyle.Flat;
            oobeBtn.FlatAppearance.BorderSize = 0;
            oobeBtn.BackColor = Color.FromArgb(0, 150, 136); // Teal
            oobeBtn.ForeColor = Color.White;
            oobeBtn.Size = new Size(260, 40);
            oobeBtn.Location = new Point(20, 170);
            oobeBtn.Click += (s, e) => { 
                new InstallerForm(DeployScenario.OobeBypass).Show(); 
                this.Hide(); 
            };
            SetRoundedRegion(oobeBtn, 10);
            this.Controls.Add(oobeBtn);

            int startY = 220;
            int step = 56;
            AddAppButton("Explorer++", "Launch File Explorer", startY, () => LaunchApp("Explorer++\\Explorer++.exe"));
            AddAppButton("MBR-Deep Search", "Ultra-Fast MFT File Scanner", startY + step, () => LaunchApp("MBR-Deep\\MBR-Deep-Classic.exe"));
            AddAppButton("DiskGenius", "Partition & Data Recovery", startY + (step * 2), () => LaunchApp("DiskGenius\\DiskGenius.exe"));
            AddAppButton("Dism++", "System Deployment", startY + (step * 3), () => LaunchApp("Dism++\\Dism++x64.exe"));
            ContextMenuStrip sysToolsMenu = new ContextMenuStrip();
            sysToolsMenu.Items.Add("Command Prompt", null, (s, e) => { this.Hide(); LaunchApp("cmd.exe", true); });
            sysToolsMenu.Items.Add("Notepad", null, (s, e) => { this.Hide(); LaunchApp("notepad.exe", true); });
            sysToolsMenu.Items.Add("Registry Editor", null, (s, e) => { this.Hide(); LaunchApp("regedit.exe", true); });
            sysToolsMenu.Items.Add("Task Manager", null, (s, e) => { this.Hide(); LaunchApp("taskmgr.exe", true); });
            sysToolsMenu.Items.Add("DiskPart", null, (s, e) => { this.Hide(); LaunchApp("cmd.exe", true, "/k diskpart"); });
            sysToolsMenu.Items.Add("System Information", null, (s, e) => { this.Hide(); LaunchApp("msinfo32.exe", true); });
            sysToolsMenu.Items.Add(new ToolStripSeparator());
            sysToolsMenu.Items.Add("Magic Beans (Extract OEM Key)", null, (s, e) => { 
                this.Hide(); 
                try {
                    Process p = new Process();
                    p.StartInfo.FileName = "wmic";
                    p.StartInfo.Arguments = "path softwarelicensingservice get OA3xOriginalProductKey";
                    p.StartInfo.UseShellExecute = false;
                    p.StartInfo.RedirectStandardOutput = true;
                    p.StartInfo.CreateNoWindow = true;
                    p.Start();
                    string output = p.StandardOutput.ReadToEnd();
                    p.WaitForExit();
                    
                    string[] lines = output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                    string key = lines.Length > 1 ? lines[1].Trim() : "";
                    
                    if (string.IsNullOrEmpty(key)) {
                        MessageBox.Show("No embedded OEM Windows Key was found in the motherboard firmware.", "Magic Beans", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    } else {
                        Clipboard.SetText(key);
                        MessageBox.Show($"Successfully extracted OEM Key from ACPI BIOS:\n\n{key}\n\n(This key has been automatically copied to your clipboard!)", "Magic Beans", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    }
                } catch (Exception ex) {
                    MessageBox.Show("Failed to extract OEM key: " + ex.Message, "Magic Beans Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            });

            AddAppButton("System Tools", "Native Windows Utilities (Folder)", startY + (step * 4), () => {
                sysToolsMenu.Show(Cursor.Position);
            }, false);

            AddAppButton("NTPWEdit", "Password Reset Tool", startY + (step * 5), () => LaunchApp("NTPWEdit\\ntpwedit64.exe"));
            AddAppButton("Reboot", "Restart WinPE", startY + (step * 6), () => LaunchApp("wpeutil", true, "reboot"));
            AddAppButton("Shutdown", "Power Off", startY + (step * 7), () => LaunchApp("wpeutil", true, "shutdown"));
            
            SetRoundedRegion(this, 15);
        }

        private void SetRoundedRegion(Control control, int radius)
        {
            System.Drawing.Drawing2D.GraphicsPath path = new System.Drawing.Drawing2D.GraphicsPath();
            path.AddArc(0, 0, radius, radius, 180, 90);
            path.AddArc(control.Width - radius, 0, radius, radius, 270, 90);
            path.AddArc(control.Width - radius, control.Height - radius, radius, radius, 0, 90);
            path.AddArc(0, control.Height - radius, radius, radius, 90, 90);
            path.CloseFigure();
            control.Region = new Region(path);
        }

        private void AddAppButton(string text, string subText, int yPos, Action onClick, bool autoHide = true)
        {
            Button btn = new Button();
            btn.Text = text + "\n" + subText;
            btn.Font = new Font("Segoe UI Semibold", 11, FontStyle.Regular);
            btn.TextAlign = ContentAlignment.MiddleCenter;
            btn.FlatStyle = FlatStyle.Flat;
            btn.FlatAppearance.BorderSize = 0;
            btn.BackColor = Color.FromArgb(60, 60, 60);
            btn.ForeColor = Color.White;
            btn.Size = new Size(280, 50);
            btn.Location = new Point(10, yPos);
            btn.Cursor = Cursors.Hand;
            SetRoundedRegion(btn, 10);
            
            btn.Click += (s, e) => {
                if (autoHide) this.Hide();
                onClick();
            };

            this.Controls.Add(btn);
        }

        private void LaunchApp(string relativePath, bool isSystem = false, string args = "")
        {
            try
            {
                string targetPath = isSystem ? relativePath : Path.Combine("X:\\Tools", relativePath);
                
                if (!isSystem && !File.Exists(targetPath))
                {
                    MessageBox.Show($"Could not find application at:\n{targetPath}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = targetPath,
                    Arguments = args,
                    UseShellExecute = true
                };
                Process.Start(psi);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Failed to launch app: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        protected override void OnDeactivate(EventArgs e)
        {
            base.OnDeactivate(e);
            this.Hide();
        }
    }
}
