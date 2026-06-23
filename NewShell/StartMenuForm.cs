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
            this.Size = new Size(300, 610);
            this.StartPosition = FormStartPosition.Manual;
            this.ShowInTaskbar = false;

            Label title = new Label();
            title.Text = "Sovereign Menu";
            title.Font = new Font("Segoe UI", 16, FontStyle.Bold);
            title.ForeColor = Color.White;
            title.Location = new Point(20, 20);
            title.AutoSize = true;
            this.Controls.Add(title);

            // The massive Sovereign Deploy button
            Button deployBtn = new Button();
            deployBtn.Text = "SOVEREIGN DEPLOY";
            deployBtn.Font = new Font("Segoe UI", 14, FontStyle.Bold);
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
                new InstallerForm().Show(); 
                this.Hide(); 
            };
            this.Controls.Add(deployBtn);

            Button tweakBtn = new Button();
            tweakBtn.Text = "SOVEREIGN TWEAKER";
            tweakBtn.Font = new Font("Segoe UI", 12, FontStyle.Bold);
            tweakBtn.FlatStyle = FlatStyle.Flat;
            tweakBtn.FlatAppearance.BorderSize = 0;
            tweakBtn.BackColor = Color.FromArgb(0, 120, 215); // Blue
            tweakBtn.ForeColor = Color.White;
            tweakBtn.Size = new Size(260, 40);
            tweakBtn.Location = new Point(20, 120);
            tweakBtn.Click += (s, e) => { 
                new InstallerForm(true).Show(); 
                this.Hide(); 
            };
            this.Controls.Add(tweakBtn);

            int startY = 175;
            AddAppButton("Explorer++", "Launch File Explorer", startY, () => LaunchApp("Explorer++\\Explorer++.exe"));
            AddAppButton("MBR-Deep Search", "Ultra-Fast MFT File Scanner", startY + 50, () => LaunchApp("MBR-Deep\\MBR-Deep-Classic.exe"));
            AddAppButton("AOMEI Partition", "Manage Disks", startY + 100, () => LaunchApp("AOMEI\\x64\\PartAssist.exe"));
            AddAppButton("Dism++", "System Deployment", startY + 150, () => LaunchApp("Dism++\\Dism++x64.exe"));
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

            AddAppButton("System Tools", "Native Windows Utilities (Folder)", startY + 200, () => {
                sysToolsMenu.Show(Cursor.Position);
            }, false);

            AddAppButton("NTPWEdit", "Password Reset Tool", startY + 250, () => LaunchApp("NTPWEdit\\ntpwedit64.exe"));
            AddAppButton("Reboot", "Restart WinPE", startY + 300, () => LaunchApp("wpeutil", true, "reboot"));
            AddAppButton("Shutdown", "Power Off", startY + 350, () => LaunchApp("wpeutil", true, "shutdown"));
        }

        private void AddAppButton(string text, string subText, int yPos, Action onClick, bool autoHide = true)
        {
            Button btn = new Button();
            btn.Text = text + "\n" + subText;
            btn.Font = new Font("Segoe UI", 10, FontStyle.Regular);
            btn.TextAlign = ContentAlignment.MiddleLeft;
            btn.FlatStyle = FlatStyle.Flat;
            btn.FlatAppearance.BorderSize = 0;
            btn.BackColor = Color.FromArgb(60, 60, 60);
            btn.ForeColor = Color.White;
            btn.Size = new Size(280, 45);
            btn.Location = new Point(10, yPos);
            btn.Cursor = Cursors.Hand;
            
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
