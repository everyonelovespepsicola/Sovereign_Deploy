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
            AddAppButton("Command Prompt", "Advanced CLI", startY + 200, () => LaunchApp("cmd.exe", true));
            AddAppButton("NTPWEdit", "Password Reset Tool", startY + 250, () => LaunchApp("NTPWEdit\\ntpwedit64.exe"));
            AddAppButton("Reboot", "Restart WinPE", startY + 320, () => LaunchApp("wpeutil", true, "reboot"));
            AddAppButton("Shutdown", "Power Off", startY + 370, () => LaunchApp("wpeutil", true, "shutdown"));
        }

        private void AddAppButton(string text, string subText, int yPos, Action onClick)
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
                this.Hide();
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
