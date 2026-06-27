using System;
using System.Drawing;
using System.Windows.Forms;
using System.IO;
using System.Diagnostics;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using ManagedWimLib;

namespace CustomShell
{
    public class InstallerForm : Form
    {
        private ComboBox diskCombo;
        private TextBox isoPathBox;
        private ComboBox editionCombo;
        private TextBox driverPathBox;
        private Button browseBtn;
        private Button browseDriverBtn;
        private Button deployBtn;
        private ProgressBar progressBar;
        private Label statusLabel;
        private Label titleLabel;
        private TextBox logBox;
        private ComboBox languageCombo;
        
        // NTLight GUI Elements
        private CheckedListBox packageList;
        private CheckedListBox hardcoreList;
        private Label hardcoreLabel;
        private Button selectJunkBtn;
        private Button purgeBtn;
        private TaskCompletionSource<bool> purgeApprovalSource;

        private bool isDebloatMode = false;
        private ComboBox targetDriveComboBox;

        private TextBox userBox;
        private TextBox passBox;
        private TextBox pcBox;
        private CheckBox builtinAdminBox;
        private CheckBox bypassOobeBox;

        public InstallerForm(bool debloatMode = false)
        {
            isDebloatMode = debloatMode;
            this.Text = isDebloatMode ? "Sovereign Offline Tweaker" : "Sovereign OS Installer";
            this.Size = new Size(800, 760);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.BackColor = Color.FromArgb(20, 20, 20);
            this.ForeColor = Color.White;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;

            // Title
            titleLabel = new Label() { Text = isDebloatMode ? "SOVEREIGN TWEAKER" : "SOVEREIGN DEPLOYMENT", Font = new Font("Segoe UI", 24, FontStyle.Bold), ForeColor = Color.FromArgb(0, 120, 215), Location = new Point(50, 15), AutoSize = true };
            this.Controls.Add(titleLabel);

            // Disk Selection
            Label diskLabel = new Label() { Text = isDebloatMode ? "Select Installed Windows Drive:" : "Select Target Drive (WILL BE WIPED):", Location = new Point(50, 70), AutoSize = true, Font = new Font("Segoe UI", 12) };
            this.Controls.Add(diskLabel);

            if (!isDebloatMode) {
                diskCombo = new ComboBox() { Location = new Point(50, 95), Size = new Size(700, 30), Font = new Font("Segoe UI", 12), DropDownStyle = ComboBoxStyle.DropDownList };
                LoadDisks();
                this.Controls.Add(diskCombo);
            } else {
                targetDriveComboBox = new ComboBox() { Location = new Point(50, 95), Size = new Size(700, 30), Font = new Font("Segoe UI", 12), DropDownStyle = ComboBoxStyle.DropDownList };
                foreach (var d in DriveInfo.GetDrives()) {
                    if (d.IsReady && d.Name != @"X:\") {
                        string displayText = d.Name;
                        if (Directory.Exists(Path.Combine(d.Name, "Windows"))) {
                            displayText += " (Windows Installed)";
                        }
                        targetDriveComboBox.Items.Add(displayText);
                    }
                }
                if (targetDriveComboBox.Items.Count > 0) targetDriveComboBox.SelectedIndex = 0;
                this.Controls.Add(targetDriveComboBox);
            }

            // ISO Selection
            Label isoLabel = new Label() { Text = "1. Select Windows .ISO or .WIM:", Location = new Point(50, 135), AutoSize = true, Font = new Font("Segoe UI", 12), Visible = !isDebloatMode };
            this.Controls.Add(isoLabel);

            isoPathBox = new TextBox() { Location = new Point(50, 160), Size = new Size(420, 30), Font = new Font("Segoe UI", 12), ReadOnly = true, Visible = !isDebloatMode };
            this.Controls.Add(isoPathBox);

            editionCombo = new ComboBox() { Location = new Point(480, 160), Size = new Size(170, 30), Font = new Font("Segoe UI", 12), DropDownStyle = ComboBoxStyle.DropDownList, Visible = !isDebloatMode };
            editionCombo.Items.AddRange(new string[] { "Index 1 (Home)", "Index 2", "Index 3", "Index 4 (Education)", "Index 5", "Index 6 (Pro)", "Index 7", "Index 8", "Index 9", "Index 10" });
            editionCombo.SelectedIndex = 5; // Default to Pro
            this.Controls.Add(editionCombo);

            browseBtn = new Button() { Text = "Browse...", Location = new Point(660, 160), Size = new Size(90, 30), FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(40, 40, 40), Visible = !isDebloatMode };
            browseBtn.Click += BrowseBtn_Click;
            this.Controls.Add(browseBtn);

            // Driver Selection
            Label driverLabel = new Label() { Text = "2. Select Drivers Folder (Optional):", Location = new Point(50, 200), AutoSize = true, Font = new Font("Segoe UI", 12), Visible = !isDebloatMode };
            this.Controls.Add(driverLabel);

            driverPathBox = new TextBox() { Location = new Point(50, 225), Size = new Size(320, 30), Font = new Font("Segoe UI", 12), ReadOnly = true, Visible = !isDebloatMode };
            this.Controls.Add(driverPathBox);

            browseDriverBtn = new Button() { Text = "Browse...", Location = new Point(380, 225), Size = new Size(90, 30), FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(40, 40, 40), Visible = !isDebloatMode };
            browseDriverBtn.Click += BrowseDriverBtn_Click;
            this.Controls.Add(browseDriverBtn);

            Label langLabel = new Label() { Text = "Language:", Location = new Point(480, 200), AutoSize = true, Font = new Font("Segoe UI", 12), Visible = !isDebloatMode };
            this.Controls.Add(langLabel);

            languageCombo = new ComboBox() { Location = new Point(480, 225), Size = new Size(270, 30), Font = new Font("Segoe UI", 12), DropDownStyle = ComboBoxStyle.DropDownList, Visible = !isDebloatMode };
            languageCombo.Items.AddRange(new string[] { "en-US (English - US)", "en-GB (English - UK)", "es-ES (Spanish)", "fr-FR (French)", "de-DE (German)", "ja-JP (Japanese)" });
            if (languageCombo.Items.Count > 0) languageCombo.SelectedIndex = 0;
            this.Controls.Add(languageCombo);

            if (isDebloatMode) {
                bypassOobeBox = new CheckBox() { 
                    Text = "New Preinstalled OOBE Bypass (use only if OOBE hasn't been setup)", 
                    Location = new Point(50, 235), 
                    AutoSize = true, 
                    Font = new Font("Segoe UI", 10, FontStyle.Bold), 
                    ForeColor = Color.Orange 
                };
                this.Controls.Add(bypassOobeBox);
            }

            // User Credentials
            Label userLabel = new Label() { Text = isDebloatMode ? "Create User Account (OOBE Bypass):" : "3. Create User Account:", Location = new Point(50, 265), AutoSize = true, Font = new Font("Segoe UI", 12), Visible = true };
            this.Controls.Add(userLabel);
            userBox = new TextBox() { Location = new Point(50, 290), Size = new Size(200, 30), Font = new Font("Segoe UI", 12), Text = "Admin", Visible = true };
            this.Controls.Add(userBox);

            Label passLabel = new Label() { Text = "Password (Optional):", Location = new Point(260, 265), AutoSize = true, Font = new Font("Segoe UI", 12), Visible = true };
            this.Controls.Add(passLabel);
            passBox = new TextBox() { Location = new Point(260, 290), Size = new Size(200, 30), Font = new Font("Segoe UI", 12), Visible = true };
            this.Controls.Add(passBox);

            Label pcLabel = new Label() { Text = "Computer Name:", Location = new Point(470, 265), AutoSize = true, Font = new Font("Segoe UI", 12), Visible = true };
            this.Controls.Add(pcLabel);
            pcBox = new TextBox() { Location = new Point(470, 290), Size = new Size(200, 30), Font = new Font("Segoe UI", 12), Text = "Sovereign-PC", Visible = true };
            this.Controls.Add(pcBox);

            builtinAdminBox = new CheckBox() { Text = "Use Built-in Administrator Account", Location = new Point(50, 330), AutoSize = true, Font = new Font("Segoe UI", 10), ForeColor = Color.LightGray, Visible = true };

            if (isDebloatMode) {
                userLabel.Enabled = false;
                userBox.Enabled = false;
                passLabel.Enabled = false;
                passBox.Enabled = false;
                pcLabel.Enabled = false;
                pcBox.Enabled = false;
                builtinAdminBox.Enabled = false;

                bypassOobeBox.CheckedChanged += (s, ev) => {
                    bool enabled = bypassOobeBox.Checked;
                    userLabel.Enabled = enabled;
                    userBox.Enabled = enabled && !builtinAdminBox.Checked;
                    passLabel.Enabled = enabled;
                    passBox.Enabled = enabled;
                    pcLabel.Enabled = enabled;
                    pcBox.Enabled = enabled;
                    builtinAdminBox.Enabled = enabled;
                };
            }

            builtinAdminBox.CheckedChanged += (s, ev) => {
                if (isDebloatMode && (bypassOobeBox == null || !bypassOobeBox.Checked)) return;
                userBox.Enabled = !builtinAdminBox.Checked;
            };
            this.Controls.Add(builtinAdminBox);

            // Progress Bar
            progressBar = new ProgressBar() { Location = new Point(50, 365), Size = new Size(700, 30) };
            this.Controls.Add(progressBar);

            statusLabel = new Label() { Text = isDebloatMode ? "Ready to analyze system." : "Ready to deploy.", Location = new Point(50, 400), AutoSize = true, Font = new Font("Segoe UI", 10) };
            this.Controls.Add(statusLabel);

            // Deploy Button
            deployBtn = new Button() { Text = isDebloatMode ? "ANALYZE SYSTEM" : "DEPLOY OS", Font = new Font("Segoe UI", 14, FontStyle.Bold), Location = new Point(50, 425), Size = new Size(700, 50), FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(180, 0, 0) };
            deployBtn.Click += DeployBtn_Click;
            this.Controls.Add(deployBtn);

            // NTLight GUI
            packageList = new CheckedListBox() { Location = new Point(50, 490), Size = new Size(340, 90), Font = new Font("Segoe UI", 10), BackColor = Color.FromArgb(30, 30, 30), ForeColor = Color.White, CheckOnClick = true, Visible = false };
            this.Controls.Add(packageList);

            hardcoreLabel = new Label() { Text = "HARDCORE MODULES (DANGEROUS):", Location = new Point(410, 470), AutoSize = true, Font = new Font("Segoe UI", 10, FontStyle.Bold), ForeColor = Color.Red, Visible = false };
            this.Controls.Add(hardcoreLabel);

            hardcoreList = new CheckedListBox() { Location = new Point(410, 490), Size = new Size(340, 90), Font = new Font("Segoe UI", 10, FontStyle.Bold), BackColor = Color.FromArgb(40, 10, 10), ForeColor = Color.Red, CheckOnClick = true, Visible = false };
            hardcoreList.Items.AddRange(new string[] { "Microsoft Edge", "Windows Defender", "OneDrive", "Windows Copilot / Recall AI", "Xbox Junk", "Nuclear Windows Update", "Disable Search Indexing", "AppX Ghost Buster (Live Cleanup)", "Essentials (Classic Menu & End Task)", "Manual Services (Chris Titus Tweak)" });
            this.Controls.Add(hardcoreList);

            selectJunkBtn = new Button() { Text = "Select All", Location = new Point(50, 590), Size = new Size(150, 30), FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(40, 40, 40), Visible = false };
            selectJunkBtn.Click += SelectJunkBtn_Click;
            this.Controls.Add(selectJunkBtn);

            purgeBtn = new Button() { Text = "PURGE SELECTED PACKAGES AND CONTINUE", Font = new Font("Segoe UI", 12, FontStyle.Bold), Location = new Point(210, 590), Size = new Size(540, 30), FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(180, 0, 0), Visible = false };
            purgeBtn.Click += PurgeBtn_Click;
            this.Controls.Add(purgeBtn);

            // Terminal Log Box
            logBox = new TextBox() { Location = new Point(50, 630), Size = new Size(700, 90), Font = new Font("Consolas", 9), BackColor = Color.Black, ForeColor = Color.Lime, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true };
            this.Controls.Add(logBox);
        }

        private void SelectJunkBtn_Click(object sender, EventArgs e)
        {
            for (int i = 0; i < packageList.Items.Count; i++)
            {
                packageList.SetItemChecked(i, true);
            }
            for (int i = 0; i < hardcoreList.Items.Count; i++)
            {
                hardcoreList.SetItemChecked(i, true);
            }
        }

        private void PurgeBtn_Click(object sender, EventArgs e)
        {
            purgeBtn.Enabled = false;
            selectJunkBtn.Enabled = false;
            packageList.Enabled = false;
            hardcoreList.Enabled = false;
            if (purgeApprovalSource != null)
            {
                purgeApprovalSource.SetResult(true);
            }
        }

        private void LoadDisks()
        {
            try
            {
                string scriptPath = Path.Combine(Path.GetTempPath(), "list_disk.txt");
                File.WriteAllText(scriptPath, "list disk\nexit");

                Process p = new Process();
                p.StartInfo.FileName = "diskpart.exe";
                p.StartInfo.Arguments = $"/s \"{scriptPath}\"";
                p.StartInfo.UseShellExecute = false;
                p.StartInfo.RedirectStandardOutput = true;
                p.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
                p.StartInfo.CreateNoWindow = true;
                p.Start();

                string output = p.StandardOutput.ReadToEnd();
                p.WaitForExit();

                string[] lines = output.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                foreach (string line in lines)
                {
                    if (line.Trim().StartsWith("Disk "))
                    {
                        if (line.Contains("Status") && line.Contains("Size")) continue;
                        
                        string[] parts = line.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                        if (parts.Length >= 4 && parts[0] == "Disk")
                        {
                            string index = parts[1];
                            string status = parts[2];
                            string size = parts[3] + " " + parts[4];
                            diskCombo.Items.Add($"Disk {index} - {size} ({status})");
                        }
                    }
                }

                if (diskCombo.Items.Count > 0) diskCombo.SelectedIndex = 0;
            }
            catch (Exception ex)
            {
                MessageBox.Show("Failed to load disks via DiskPart: " + ex.Message);
            }
        }

        private void BrowseBtn_Click(object sender, EventArgs e)
        {
            using (OpenFileDialog ofd = new OpenFileDialog())
            {
                ofd.Filter = "Windows Image (*.iso;*.wim)|*.iso;*.wim|All files (*.*)|*.*";
                ofd.Title = "Select Windows ISO or WIM";
                if (ofd.ShowDialog() == DialogResult.OK)
                {
                    isoPathBox.Text = ofd.FileName;
                }
            }
        }

        private void BrowseDriverBtn_Click(object sender, EventArgs e)
        {
            using (FolderBrowserDialog fbd = new FolderBrowserDialog())
            {
                fbd.Description = "Select the folder containing your extracted .inf drivers";
                if (fbd.ShowDialog() == DialogResult.OK)
                {
                    driverPathBox.Text = fbd.SelectedPath;
                }
            }
        }

        private async void DeployBtn_Click(object sender, EventArgs e)
        {
            if (isDebloatMode)
            {
                if (targetDriveComboBox.SelectedIndex == -1)
                {
                    MessageBox.Show("Please select a target Windows drive.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }
                
                string targetDrive = targetDriveComboBox.SelectedItem.ToString().Split(' ')[0];
                DialogResult drDebloat = MessageBox.Show($"WARNING: Debloating {targetDrive} will permanently delete core packages!\n\nAre you sure you want to proceed?", "CRITICAL WARNING", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
                if (drDebloat != DialogResult.Yes) return;
                
                deployBtn.Enabled = false;
                targetDriveComboBox.Enabled = false;
                
                string uname = "", pass = "", pc = "";
                bool useBuiltInAccount = false;
                bool injectUnattend = false;
                
                if (bypassOobeBox != null && bypassOobeBox.Checked) {
                    uname = userBox.Text.Trim();
                    pass = passBox.Text;
                    pc = pcBox.Text.Trim();
                    useBuiltInAccount = builtinAdminBox.Checked;
                    injectUnattend = true;

                    if (!useBuiltInAccount && string.IsNullOrEmpty(uname)) {
                        MessageBox.Show("Username cannot be empty unless using the built-in Administrator.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        deployBtn.Enabled = true;
                        targetDriveComboBox.Enabled = true;
                        return;
                    }
                }
                
                await Task.Run(() => RunDeploymentPipeline("", "", "", uname, pass, pc, useBuiltInAccount, 1, injectUnattend, "en-US"));
                
                deployBtn.Enabled = true;
                targetDriveComboBox.Enabled = true;
                return;
            }

            if (diskCombo.SelectedIndex == -1 || string.IsNullOrEmpty(isoPathBox.Text))
            {
                MessageBox.Show("Please select a disk and an ISO/WIM file.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            string diskSelection = diskCombo.SelectedItem.ToString();
            string diskIndex = diskSelection.Split('-')[0].Replace("Disk ", "").Trim();
            string mediaPath = isoPathBox.Text;
            string driverPath = driverPathBox.Text;

            DialogResult dr = MessageBox.Show($"WARNING: Disk {diskIndex} will be COMPLETELY WIPED!\n\nAre you sure you want to proceed?", "CRITICAL WARNING", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
            if (dr != DialogResult.Yes) return;

            deployBtn.Enabled = false;
            browseBtn.Enabled = false;
            browseDriverBtn.Enabled = false;
            diskCombo.Enabled = false;

            string username = userBox.Text.Trim();
            string password = passBox.Text;
            string pcname = pcBox.Text.Trim();
            bool useBuiltIn = builtinAdminBox.Checked;

            if (!useBuiltIn && string.IsNullOrEmpty(username)) {
                MessageBox.Show("Username cannot be empty unless using the built-in Administrator.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                deployBtn.Enabled = true;
                browseBtn.Enabled = true;
                browseDriverBtn.Enabled = true;
                diskCombo.Enabled = true;
                return;
            }

            int editionIndex = 6;
            if (!isDebloatMode) {
                editionIndex = int.Parse(editionCombo.SelectedItem.ToString().Split(' ')[1]);
            }

            string selectedLang = "en-US";
            if (!isDebloatMode && languageCombo.SelectedIndex != -1) {
                selectedLang = languageCombo.SelectedItem.ToString().Split(' ')[0];
            }

            await Task.Run(() => RunDeploymentPipeline(diskIndex, mediaPath, driverPath, username, password, pcname, useBuiltIn, editionIndex, true, selectedLang));

            deployBtn.Enabled = true;
            browseBtn.Enabled = true;
            browseDriverBtn.Enabled = true;
            diskCombo.Enabled = true;
        }

        private async Task RunDeploymentPipeline(string diskIndex, string mediaPath, string driverPath, string username, string password, string pcname, bool useBuiltIn, int editionIndex, bool injectUnattend, string language)
        {
            try
            {
                string targetDrive = "W:\\";
                string finalWimPath = mediaPath ?? "";

                if (!isDebloatMode) 
                {
                // STEP 1: DISKPART
                UpdateStatus("Wiping disk and creating UEFI partitions...");
                string scriptPath = Path.Combine(Path.GetTempPath(), "diskpart.txt");
                string script = $@"
select disk {diskIndex}
clean
convert gpt
create partition efi size=500
format quick fs=fat32 label=""System""
assign letter=""S""
create partition msr size=16
create partition primary
format quick fs=ntfs label=""Windows""
assign letter=""W""
exit";
                File.WriteAllText(scriptPath, script);

                Process p = new Process();
                p.StartInfo.FileName = "diskpart.exe";
                p.StartInfo.Arguments = $"/s \"{scriptPath}\"";
                p.StartInfo.UseShellExecute = false;
                p.StartInfo.RedirectStandardOutput = true;
                p.StartInfo.RedirectStandardError = true;
                p.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
                p.StartInfo.CreateNoWindow = true;
                
                p.OutputDataReceived += (s, ev) => Log(ev.Data);
                    p.ErrorDataReceived += (s, ev) => Log(ev.Data);
                    
                    p.Start();
                    p.BeginOutputReadLine();
                    p.BeginErrorReadLine();
                    p.WaitForExit();

                    if (p.ExitCode != 0) throw new Exception("Diskpart failed!");

                    finalWimPath = mediaPath;

                    // STEP 2: 7-ZIP ISO RIPPING (if ISO)
                    if (mediaPath.ToLower().EndsWith(".iso"))
                    {
                        UpdateStatus("Ripping install.wim from ISO using 7-Zip...");
                        string sevenZipPath = @"X:\Tools\7-Zip\7z.exe";
                        if (!File.Exists(sevenZipPath)) sevenZipPath = @"C:\Tools\7-Zip\7z.exe";

                        finalWimPath = @"W:\install.wim";

                        Process sz = new Process();
                        sz.StartInfo.FileName = sevenZipPath;
                        sz.StartInfo.Arguments = $"e \"{mediaPath}\" sources\\install.wim -o\"W:\\\" -y";
                        sz.StartInfo.UseShellExecute = false;
                        sz.StartInfo.RedirectStandardOutput = true;
                        sz.StartInfo.RedirectStandardError = true;
                        sz.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
                        sz.StartInfo.CreateNoWindow = true;
                        
                        sz.OutputDataReceived += (s, ev) => { if (!string.IsNullOrWhiteSpace(ev.Data) && ev.Data.Contains("%")) Log(ev.Data); };
                        sz.ErrorDataReceived += (s, ev) => Log(ev.Data);

                        sz.Start();
                        sz.BeginOutputReadLine();
                        sz.BeginErrorReadLine();
                        sz.WaitForExit();

                        if (!File.Exists(finalWimPath)) throw new Exception("Failed to extract install.wim from the ISO!");
                    }

                    // STEP 3: WIMLIB EXTRACT
                    UpdateStatus("Deploying Windows using Sovereign Wimlib Engine...");
                    
                    string libPath = @"X:\Windows\System32\libwim-15.dll";
                    if (!File.Exists(libPath)) libPath = "libwim-15.dll";
                    Wim.GlobalInit(libPath);

                    using (Wim wim = Wim.OpenWim(finalWimPath, OpenFlags.None))
                    {
                        wim.RegisterCallback((msg, info, progctx) =>
                        {
                            if (msg == ProgressMsg.ExtractImageBegin)
                            {
                                UpdateProgress(0);
                                Log("Wimlib: Extraction started...");
                            }
                            return CallbackStatus.Continue;
                        });

                        wim.ExtractImage(editionIndex, @"W:\", ExtractFlags.None);
                    }

                    // STEP 3.2: OFFLINE DRIVER INJECTION
                    if (!string.IsNullOrEmpty(driverPath) && Directory.Exists(driverPath))
                    {
                        UpdateStatus("Injecting offline drivers from: " + driverPath);
                        Log("Running dism /Add-Driver...");
                        Process pDrv = new Process();
                        pDrv.StartInfo.FileName = "dism.exe";
                        pDrv.StartInfo.Arguments = $"/image:W:\\ /Add-Driver /Driver:\"{driverPath}\" /Recurse /ForceUnsigned";
                        pDrv.StartInfo.UseShellExecute = false;
                        pDrv.StartInfo.RedirectStandardOutput = true;
                        pDrv.StartInfo.RedirectStandardError = true;
                        pDrv.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
                        pDrv.StartInfo.CreateNoWindow = true;
                        
                        pDrv.OutputDataReceived += (s, ev) => Log(ev.Data);
                        pDrv.ErrorDataReceived += (s, ev) => Log(ev.Data);

                        pDrv.Start();
                        pDrv.BeginOutputReadLine();
                        pDrv.BeginErrorReadLine();
                        pDrv.WaitForExit();
                    }
                }
                else 
                {
                    this.Invoke(new Action(() => {
                        targetDrive = targetDriveComboBox.SelectedItem.ToString().Split(' ')[0];
                        if (!targetDrive.EndsWith("\\")) targetDrive += "\\";
                    }));
                }

                // STEP 3.5: SOVEREIGN NTLIGHT GUI
                UpdateStatus("Interrogating offline image for AppX Packages...");
                
                Process dism = new Process();
                dism.StartInfo.FileName = "dism.exe";
                dism.StartInfo.Arguments = $"/image:{targetDrive} /Get-ProvisionedAppxPackages /English";
                dism.StartInfo.UseShellExecute = false;
                dism.StartInfo.RedirectStandardOutput = true;
                dism.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
                dism.StartInfo.CreateNoWindow = true;
                dism.Start();
                string dismOutput = dism.StandardOutput.ReadToEnd();
                dism.WaitForExit();

                string[] dismLines = dismOutput.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
                
                this.Invoke(new Action(() => {
                    packageList.Items.Clear();
                    foreach (string line in dismLines)
                    {
                        if (line.StartsWith("PackageName : "))
                        {
                            string pkgName = line.Replace("PackageName : ", "").Trim();
                            packageList.Items.Add(pkgName);
                        }
                    }
                    packageList.Visible = true;
                    hardcoreList.Visible = true;
                    hardcoreLabel.Visible = true;
                    selectJunkBtn.Visible = true;
                    purgeBtn.Visible = true;
                    deployBtn.Visible = false;
                    progressBar.Visible = false;
                }));

                UpdateStatus("Please select packages to purge, then click Continue.");
                purgeApprovalSource = new TaskCompletionSource<bool>();
                await purgeApprovalSource.Task;

                // PURGE EXECUTION
                this.Invoke(new Action(() => {
                    packageList.Visible = false;
                    hardcoreList.Visible = false;
                    hardcoreLabel.Visible = false;
                    selectJunkBtn.Visible = false;
                    purgeBtn.Visible = false;
                    deployBtn.Visible = true;
                    progressBar.Visible = true;
                }));

                for (int i = 0; i < packageList.Items.Count; i++)
                {
                    if (packageList.GetItemChecked(i))
                    {
                        string targetPkg = packageList.Items[i].ToString();
                        UpdateStatus("Purging: " + targetPkg);
                        Log("Running dism to remove: " + targetPkg);

                        Process pdism = new Process();
                        pdism.StartInfo.FileName = "dism.exe";
                        pdism.StartInfo.Arguments = $"/image:{targetDrive} /Remove-ProvisionedAppxPackage /PackageName:\"{targetPkg}\"";
                        pdism.StartInfo.UseShellExecute = false;
                        pdism.StartInfo.RedirectStandardOutput = true;
                        pdism.StartInfo.RedirectStandardError = true;
                        pdism.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
                        pdism.StartInfo.CreateNoWindow = true;
                        
                        pdism.OutputDataReceived += (s, ev) => Log(ev.Data);
                        pdism.ErrorDataReceived += (s, ev) => Log(ev.Data);

                        pdism.Start();
                        pdism.BeginOutputReadLine();
                        pdism.BeginErrorReadLine();
                        pdism.WaitForExit();
                    }
                }

                // OFFLINE REGISTRY TWEAKS (Privacy Lockdown)
                UpdateStatus("Injecting offline registry policies...");
                
                bool killEdge = false, killDefender = false, killCopilot = false, killOneDrive = false, killXbox = false, killUpdates = false, killIndexing = false, runGhostBuster = false, installEssentials = false, manualServices = false;
                this.Invoke(new Action(() => {
                    for (int i = 0; i < hardcoreList.Items.Count; i++) {
                        if (hardcoreList.GetItemChecked(i)) {
                            string item = hardcoreList.Items[i].ToString();
                            if (item.Contains("Edge")) killEdge = true;
                            if (item.Contains("Defender")) killDefender = true;
                            if (item.Contains("Copilot") || item.Contains("Recall")) killCopilot = true;
                            if (item.Contains("OneDrive")) killOneDrive = true;
                            if (item.Contains("Xbox")) killXbox = true;
                            if (item.Contains("Update")) killUpdates = true;
                            if (item.Contains("Indexing")) killIndexing = true;
                            if (item.Contains("Ghost Buster")) runGhostBuster = true;
                            if (item.Contains("Essentials")) installEssentials = true;
                            if (item.Contains("Manual Services")) manualServices = true;
                        }
                    }
                }));

                UpdateStatus("Building Dynamic Search & Destroy Heuristics...");
                List<string> nukeKeywords = new List<string>();
                if (killEdge) nukeKeywords.AddRange(new string[] { "microsoft-edge", "msedge", "edgewebview", "edgecore", "edgeupdate" });
                if (killCopilot) nukeKeywords.AddRange(new string[] { "copilot", "webexperience", "recall" });
                if (killDefender) nukeKeywords.AddRange(new string[] { "windefend", "windows-defender" });
                if (killXbox) nukeKeywords.Add("xbox");
                if (killOneDrive) nukeKeywords.Add("onedrivesetup");
                nukeKeywords.AddRange(new string[] { "mspaint.exe", "gdi-painting" });
                this.Invoke(new Action(() => {
                    for (int i = 0; i < packageList.Items.Count; i++) {
                        if (packageList.GetItemChecked(i)) {
                            string baseName = packageList.Items[i].ToString().Split('_')[0].ToLower();
                            if (!string.IsNullOrWhiteSpace(baseName)) nukeKeywords.Add(baseName);
                        }
                    }
                }));
                List<string> hitTargets = new List<string>();
                if (nukeKeywords.Count > 0) {
                    UpdateStatus($"Scanning {targetDrive} for hidden components. This may take a minute...");
                    string[] scanRoots = new string[] { Path.Combine(targetDrive, "Program Files"), Path.Combine(targetDrive, "Program Files (x86)"), Path.Combine(targetDrive, "ProgramData"), Path.Combine(targetDrive, "Windows") };
                    foreach (string root in scanRoots) {
                        if (!Directory.Exists(root)) continue;
                        var stack = new Stack<string>();
                        stack.Push(root);
                        while (stack.Count > 0) {
                            string current = stack.Pop();
                            try {
                                foreach (string d in Directory.GetDirectories(current)) {
                                    string name = new DirectoryInfo(d).Name.ToLower();
                                    if (nukeKeywords.Any(k => name.Contains(k))) {
                                        hitTargets.Add(d);
                                        continue; 
                                    }
                                    stack.Push(d);
                                }
                                foreach (string f in Directory.GetFiles(current)) {
                                    string name = Path.GetFileName(f).ToLower();
                                    if (nukeKeywords.Any(k => name.Contains(k))) {
                                        hitTargets.Add(f);
                                    }
                                }
                            } catch { }
                        }
                    }
                }

                UpdateStatus($"Found {hitTargets.Count} obfuscated targets. Obliterating...");
                string scriptPathNuke = Path.Combine(Path.GetTempPath(), "nuclear.bat");
                string scriptNuke = "@echo off\r\n";
                foreach (string target in hitTargets) {
                    if (Directory.Exists(target)) {
                        scriptNuke += $"{targetDrive.Substring(0, 2)}Windows\\System32\\takeown.exe /f \"{target}\" /r /d Y\r\n";
                        scriptNuke += $"{targetDrive.Substring(0, 2)}Windows\\System32\\icacls.exe \"{target}\" /grant Administrators:F /t\r\n";
                        scriptNuke += $"rd /s /q \"{target}\"\r\n";
                    } else if (File.Exists(target)) {
                        scriptNuke += $"{targetDrive.Substring(0, 2)}Windows\\System32\\takeown.exe /f \"{target}\"\r\n";
                        scriptNuke += $"{targetDrive.Substring(0, 2)}Windows\\System32\\icacls.exe \"{target}\" /grant Administrators:F\r\n";
                        scriptNuke += $"del /f /q \"{target}\"\r\n";
                    }
                }

                if (killEdge) {
                    scriptNuke += $"{targetDrive.Substring(0, 2)}Windows\\System32\\takeown.exe /f \"{targetDrive}Program Files (x86)\\Microsoft\\Edge\" /r /d Y\r\n";
                    scriptNuke += $"{targetDrive.Substring(0, 2)}Windows\\System32\\icacls.exe \"{targetDrive}Program Files (x86)\\Microsoft\\Edge\" /grant Administrators:F /t\r\n";
                    scriptNuke += $"rd /s /q \"{targetDrive}Program Files (x86)\\Microsoft\\Edge\"\r\n";
                }

                File.WriteAllText(scriptPathNuke, scriptNuke);
                Process pnuke = new Process();
                pnuke.StartInfo.FileName = scriptPathNuke;
                pnuke.StartInfo.UseShellExecute = false;
                pnuke.StartInfo.RedirectStandardOutput = true;
                pnuke.StartInfo.RedirectStandardError = true;
                pnuke.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
                pnuke.StartInfo.CreateNoWindow = true;
                pnuke.OutputDataReceived += (s, ev) => Log(ev.Data);
                pnuke.ErrorDataReceived += (s, ev) => Log(ev.Data);
                pnuke.Start();
                pnuke.BeginOutputReadLine();
                pnuke.BeginErrorReadLine();
                pnuke.WaitForExit();

                UpdateStatus("Surgically scrubbing User AppData and Caches...");
                try {
                    string usersDir = Path.Combine(targetDrive, "Users");
                    if (Directory.Exists(usersDir)) {
                        foreach (string userDir in Directory.GetDirectories(usersDir)) {
                            string localAppData = Path.Combine(userDir, @"AppData\Local");
                            string roamingAppData = Path.Combine(userDir, @"AppData\Roaming");
                            
                            string packagesDir = Path.Combine(localAppData, "Packages");
                            if (Directory.Exists(packagesDir)) {
                                this.Invoke(new Action(() => {
                                    for (int i = 0; i < packageList.Items.Count; i++) {
                                        if (packageList.GetItemChecked(i)) {
                                            string baseName = packageList.Items[i].ToString().Split('_')[0];
                                            if (!string.IsNullOrWhiteSpace(baseName)) {
                                                foreach(string pkg in Directory.GetDirectories(packagesDir, baseName + "*")) {
                                                    try { Directory.Delete(pkg, true); } catch {}
                                                }
                                            }
                                        }
                                    }
                                }));
                            }
                        }
                    }
                } catch (Exception ex) { Log("AppData scrub error: " + ex.Message); }

                string scriptPathRegPriv = Path.Combine(Path.GetTempPath(), "reg_priv.bat");
                string scriptRegPriv = $"reg load HKLM\\zSOFTWARE {targetDrive}Windows\\System32\\config\\SOFTWARE\r\n" +
                "reg add HKLM\\zSOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection /v AllowTelemetry /t REG_DWORD /d 0 /f\r\n";
                
                if (killCopilot) {
                    scriptRegPriv += "reg add HKLM\\zSOFTWARE\\Policies\\Microsoft\\Windows\\WindowsCopilot /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f\r\n";
                    scriptRegPriv += "reg add HKLM\\zSOFTWARE\\Policies\\Microsoft\\Windows\\WindowsAI /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f\r\n";
                }
                if (killEdge) {
                    scriptRegPriv += "reg add HKLM\\zSOFTWARE\\Microsoft\\EdgeUpdate /v DoNotUpdateToEdgeWithChromium /t REG_DWORD /d 1 /f\r\n";
                }
                if (killDefender) {
                    scriptRegPriv += "reg add \"HKLM\\zSOFTWARE\\Policies\\Microsoft\\Windows Defender\" /v DisableAntiSpyware /t REG_DWORD /d 1 /f\r\n";
                }
                if (killXbox) {
                    scriptRegPriv += "reg add HKLM\\zSOFTWARE\\Policies\\Microsoft\\Windows\\GameDVR /v AllowGameDVR /t REG_DWORD /d 0 /f\r\n";
                    try {
                        foreach (string userDir in Directory.GetDirectories(Path.Combine(targetDrive, "Users"))) {
                            string ntuserPath = Path.Combine(userDir, "NTUSER.DAT");
                            if (File.Exists(ntuserPath)) {
                                string dirUsername = new DirectoryInfo(userDir).Name.Replace(" ", "");
                                scriptRegPriv += $"reg load HKU\\zUSER_{dirUsername} \"{ntuserPath}\"\r\n";
                                scriptRegPriv += $"reg add \"HKU\\zUSER_{dirUsername}\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\GameDVR\" /v AppCaptureEnabled /t REG_DWORD /d 0 /f\r\n";
                                scriptRegPriv += $"reg add \"HKU\\zUSER_{dirUsername}\\System\\GameConfigStore\" /v GameDVR_Enabled /t REG_DWORD /d 0 /f\r\n";
                                scriptRegPriv += $"reg unload HKU\\zUSER_{dirUsername}\r\n";
                            }
                        }
                        // Fallback for live systems
                        scriptRegPriv += "reg add \"HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\GameDVR\" /v AppCaptureEnabled /t REG_DWORD /d 0 /f\r\n";
                        scriptRegPriv += "reg add \"HKCU\\System\\GameConfigStore\" /v GameDVR_Enabled /t REG_DWORD /d 0 /f\r\n";
                    } catch { }
                }
                if (killUpdates) {
                    scriptRegPriv += "reg add HKLM\\zSOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU /v NoAutoUpdate /t REG_DWORD /d 1 /f\r\n";
                    scriptRegPriv += "reg add HKLM\\zSOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU /v AUOptions /t REG_DWORD /d 1 /f\r\n";
                    scriptRegPriv += "reg add \"HKLM\\zSOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Image File Execution Options\\WaaSMedicAgent.exe\" /v Debugger /t REG_SZ /d systray.exe /f\r\n";
                }
                if (installEssentials) {
                    try {
                        foreach (string userDir in Directory.GetDirectories(Path.Combine(targetDrive, "Users"))) {
                            string ntuserPath = Path.Combine(userDir, "NTUSER.DAT");
                            if (File.Exists(ntuserPath)) {
                                string dirUsername = new DirectoryInfo(userDir).Name.Replace(" ", "");
                                scriptRegPriv += $"reg load HKU\\zUSER_{dirUsername} \"{ntuserPath}\"\r\n";
                                scriptRegPriv += $"reg add \"HKU\\zUSER_{dirUsername}\\Software\\Classes\\CLSID\\{{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}}\\InprocServer32\" /ve /f\r\n";
                                scriptRegPriv += $"reg add \"HKU\\zUSER_{dirUsername}\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced\" /v TaskbarEndTask /t REG_DWORD /d 1 /f\r\n";
                                scriptRegPriv += $"reg unload HKU\\zUSER_{dirUsername}\r\n";
                            }
                        }
                    } catch {}
                    
                    scriptRegPriv += "reg add \"HKLM\\zSOFTWARE\\Microsoft\\Active Setup\\Installed Components\\SovereignContext\" /v StubPath /t REG_SZ /d \"reg.exe add \\\"HKCU\\Software\\Classes\\CLSID\\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\\InprocServer32\\\" /ve /f\" /f\r\n";
                    scriptRegPriv += "reg add \"HKLM\\zSOFTWARE\\Microsoft\\Active Setup\\Installed Components\\SovereignContext\" /v Version /t REG_SZ /d \"1,0\" /f\r\n";
                }
                
                scriptRegPriv += "reg unload HKLM\\zSOFTWARE\r\n" + 
                $"reg load HKLM\\zSYSTEM {targetDrive}Windows\\System32\\config\\SYSTEM\r\n" +
                "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\SysMain /v Start /t REG_DWORD /d 4 /f\r\n";

                if (manualServices) {
                    scriptRegPriv += "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\CscService /v Start /t REG_DWORD /d 4 /f\r\n";
                    scriptRegPriv += "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\DiagTrack /v Start /t REG_DWORD /d 4 /f\r\n";
                    scriptRegPriv += "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\MapsBroker /v Start /t REG_DWORD /d 3 /f\r\n";
                    scriptRegPriv += "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\StorSvc /v Start /t REG_DWORD /d 3 /f\r\n";
                    scriptRegPriv += "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\SharedAccess /v Start /t REG_DWORD /d 4 /f\r\n";
                    scriptRegPriv += "reg add HKLM\\zSYSTEM\\ControlSet001\\Control /v SvcHostSplitThresholdInKB /t REG_DWORD /d 33554432 /f\r\n";
                }
                
                if (killDefender) {
                    scriptRegPriv += "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\WinDefend /v Start /t REG_DWORD /d 4 /f\r\n" +
                                     "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\WdNisSvc /v Start /t REG_DWORD /d 4 /f\r\n" +
                                     "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\Sense /v Start /t REG_DWORD /d 4 /f\r\n" +
                                     "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\SecurityHealthService /v Start /t REG_DWORD /d 4 /f\r\n";
                }
                if (killUpdates) {
                    scriptRegPriv += "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\wuauserv /v Start /t REG_DWORD /d 4 /f\r\n" +
                                     "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\bits /v Start /t REG_DWORD /d 4 /f\r\n" +
                                     "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\dosvc /v Start /t REG_DWORD /d 4 /f\r\n" +
                                     "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\UsoSvc /v Start /t REG_DWORD /d 4 /f\r\n" +
                                     "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\WaaSMedicSvc /v Start /t REG_DWORD /d 4 /f\r\n";
                }
                if (killIndexing) {
                    scriptRegPriv += "reg add HKLM\\zSYSTEM\\ControlSet001\\Services\\WSearch /v Start /t REG_DWORD /d 4 /f\r\n";
                }
                
                scriptRegPriv += "reg unload HKLM\\zSYSTEM\r\n";
                File.WriteAllText(scriptPathRegPriv, scriptRegPriv);

                Process pregPriv = new Process();
                pregPriv.StartInfo.FileName = scriptPathRegPriv;
                pregPriv.StartInfo.UseShellExecute = false;
                pregPriv.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
                pregPriv.StartInfo.CreateNoWindow = true;
                pregPriv.Start();
                pregPriv.WaitForExit();

                if (killUpdates)
                {
                    UpdateStatus("Injecting WindowsUpdaterGUI to Public Desktop...");
                    string sourcePs1 = @"X:\Tools\WindowsUpdater\WindowsUpdaterGUI.ps1";
                    if (!File.Exists(sourcePs1)) sourcePs1 = @"WindowsUpdater\WindowsUpdaterGUI.ps1";
                    if (File.Exists(sourcePs1))
                    {
                        string publicDesktop = Path.Combine(targetDrive, @"Users\Public\Desktop");
                        if (!Directory.Exists(publicDesktop)) Directory.CreateDirectory(publicDesktop);
                        File.Copy(sourcePs1, Path.Combine(publicDesktop, "WindowsUpdaterGUI.ps1"), true);
                    }
                }

                // STEP 3.6: Native Unattend Inject
                if (injectUnattend) {
                    UpdateStatus("Generating Native Unattend.xml...");

                    string pantherDir = Path.Combine(targetDrive, @"Windows\Panther");
                    if (!Directory.Exists(pantherDir)) Directory.CreateDirectory(pantherDir);
                    
                    string firstLogonCommands = "";

                    string userAccountsBlock = "";
                    string autologonUser = "Administrator";
                    string autologonPass = "";
                    string pcnameOutput = string.IsNullOrWhiteSpace(pcname) ? "Sovereign-PC" : pcname;
                    
                    if (!useBuiltIn) {
                        autologonUser = username;
                        autologonPass = password;
                        userAccountsBlock = $@"
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action=""add"">
                        <Password>
                            <Value>{password}</Value>
                            <PlainText>true</PlainText>
                        </Password>
                        <Description>Sovereign Administrator</Description>
                        <DisplayName>{username}</DisplayName>
                        <Group>Administrators</Group>
                        <Name>{username}</Name>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>";
                    }

                    string passwordBlock = $@"
                <Password>
                    <Value>{autologonPass}</Value>
                    <PlainText>true</PlainText>
                </Password>";

                    string autoLogonBlock = $@"
            <AutoLogon>{passwordBlock}
                <Enabled>true</Enabled>
                <LogonCount>5</LogonCount>
                <Username>{autologonUser}</Username>
            </AutoLogon>";

                    string unattendXml = $@"<?xml version=""1.0"" encoding=""utf-8""?>
<unattend xmlns=""urn:schemas-microsoft-com:unattend"" xmlns:wcm=""http://schemas.microsoft.com/WMIConfig/2002/State"">
    <settings pass=""windowsPE"">
        <component name=""Microsoft-Windows-International-Core-WinPE"" processorArchitecture=""amd64"" publicKeyToken=""31bf3856ad364e35"" language=""neutral"" versionScope=""nonSxS"">
            <SetupUILanguage>
                <UILanguage>{language}</UILanguage>
            </SetupUILanguage>
            <InputLocale>{language}</InputLocale>
            <SystemLocale>{language}</SystemLocale>
            <UILanguage>{language}</UILanguage>
            <UserLocale>{language}</UserLocale>
        </component>
    </settings>
    <settings pass=""specialize"">
        <component name=""Microsoft-Windows-Shell-Setup"" processorArchitecture=""amd64"" publicKeyToken=""31bf3856ad364e35"" language=""neutral"" versionScope=""nonSxS"">
            <ComputerName>{pcnameOutput}</ComputerName>
        </component>
    </settings>
    <settings pass=""oobeSystem"">
        <component name=""Microsoft-Windows-International-Core"" processorArchitecture=""amd64"" publicKeyToken=""31bf3856ad364e35"" language=""neutral"" versionScope=""nonSxS"">
            <InputLocale>{language}</InputLocale>
            <SystemLocale>{language}</SystemLocale>
            <UILanguage>{language}</UILanguage>
            <UserLocale>{language}</UserLocale>
        </component>
        <component name=""Microsoft-Windows-Shell-Setup"" processorArchitecture=""amd64"" publicKeyToken=""31bf3856ad364e35"" language=""neutral"" versionScope=""nonSxS"">{userAccountsBlock}
{autoLogonBlock}
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>{firstLogonCommands}
        </component>
    </settings>
</unattend>";
                    File.WriteAllText(Path.Combine(pantherDir, "unattend.xml"), unattendXml);

                    string setupScriptsDir = Path.Combine(targetDrive, @"Windows\Setup\Scripts");
                    if (!Directory.Exists(setupScriptsDir)) Directory.CreateDirectory(setupScriptsDir);
                    string sovereignUnlockPath = Path.Combine(setupScriptsDir, "SetupComplete.cmd");
                    string sovereignUnlockCmd = "@echo off\r\n";
                    if (useBuiltIn) {
                        sovereignUnlockCmd += "net user Administrator /active:yes\r\n";
                        sovereignUnlockCmd += $"net user Administrator \"{password}\"\r\n";
                    } else {
                        sovereignUnlockCmd += $"net user \"{username}\" \"{password}\" /add\r\n";
                        sovereignUnlockCmd += $"net localgroup Administrators \"{username}\" /add\r\n";
                    }
                    sovereignUnlockCmd += "net user defaultuser0 /delete\r\n";
                    sovereignUnlockCmd += "reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\" /v AutoAdminLogon /t REG_SZ /d 1 /f\r\n";
                    sovereignUnlockCmd += $"reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\" /v DefaultUserName /t REG_SZ /d \"{autologonUser}\" /f\r\n";
                    sovereignUnlockCmd += $"reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\" /v DefaultPassword /t REG_SZ /d \"{autologonPass}\" /f\r\n";
                    
                    File.WriteAllText(sovereignUnlockPath, sovereignUnlockCmd);

                    if (isDebloatMode) {
                        string sysprepPath = Path.Combine(setupScriptsDir, "SovereignSysprep.cmd");
                        File.WriteAllText(sysprepPath, "%WINDIR%\\System32\\Sysprep\\Sysprep.exe /oobe /unattend:C:\\Windows\\Panther\\unattend.xml /reboot\r\n");
                    }

                    string scriptPathReg = Path.Combine(Path.GetTempPath(), "reg_hijack.bat");
                    string scriptReg = $"reg load HKLM\\zSOFTWARE {targetDrive}Windows\\System32\\config\\SOFTWARE\r\n" +
                    "reg add HKLM\\zSOFTWARE\\Microsoft\\Windows\\CurrentVersion\\OOBE /v BypassNRO /t REG_DWORD /d 1 /f\r\n" +
                    "reg add HKLM\\zSOFTWARE\\Microsoft\\Windows\\CurrentVersion\\OOBE /v SkipMachineOOBE /t REG_DWORD /d 1 /f\r\n" +
                    "reg add HKLM\\zSOFTWARE\\Microsoft\\Windows\\CurrentVersion\\OOBE /v SkipUserOOBE /t REG_DWORD /d 1 /f\r\n" +
                    "reg unload HKLM\\zSOFTWARE\r\n" +
                    $"reg load HKLM\\zSYSTEM {targetDrive}Windows\\System32\\config\\SYSTEM\r\n" +
                    "reg add HKLM\\zSYSTEM\\Setup /v SetupType /t REG_DWORD /d 1 /f\r\n";
                    
                    if (isDebloatMode) {
                        scriptReg += "reg add HKLM\\zSYSTEM\\Setup /v CmdLine /t REG_SZ /d \"cmd.exe /c C:\\Windows\\Setup\\Scripts\\SovereignSysprep.cmd\" /f\r\n";
                    } else {
                        scriptReg += "reg add HKLM\\zSYSTEM\\Setup /v CmdLine /t REG_SZ /d \"oobe\\windeploy.exe\" /f\r\n";
                    }
                    
                    scriptReg += "reg unload HKLM\\zSYSTEM\r\n";
                    File.WriteAllText(scriptPathReg, scriptReg);

                    Process preg = new Process();
                    preg.StartInfo.FileName = scriptPathReg;
                    preg.StartInfo.UseShellExecute = false;
                    preg.StartInfo.RedirectStandardOutput = true;
                    preg.StartInfo.RedirectStandardError = true;
                    preg.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
                    preg.StartInfo.CreateNoWindow = true;
                    
                    preg.OutputDataReceived += (s, ev) => Log(ev.Data);
                    preg.ErrorDataReceived += (s, ev) => Log(ev.Data);

                    preg.Start();
                    preg.BeginOutputReadLine();
                    preg.BeginErrorReadLine();
                    preg.WaitForExit();

                    // STEP 4: BCDBOOT
                    if (!isDebloatMode) {
                        UpdateStatus("Writing UEFI Bootloader...");
                        Log("Executing bcdboot...");
                        Process bcd = new Process();
                        bcd.StartInfo.FileName = "bcdboot.exe";
                        bcd.StartInfo.Arguments = $@"{targetDrive}Windows /s S: /f UEFI";
                        bcd.StartInfo.UseShellExecute = false;
                        bcd.StartInfo.RedirectStandardOutput = true;
                        bcd.StartInfo.RedirectStandardError = true;
                        bcd.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
                        bcd.StartInfo.CreateNoWindow = true;
                        
                        bcd.OutputDataReceived += (s, ev) => Log(ev.Data);
                        bcd.ErrorDataReceived += (s, ev) => Log(ev.Data);

                        bcd.Start();
                        bcd.BeginOutputReadLine();
                        bcd.BeginErrorReadLine();
                        bcd.WaitForExit();

                        if (bcd.ExitCode != 0) throw new Exception("Bcdboot failed!");
                    }
                }

                if (isDebloatMode) {
                    UpdateStatus("Wiping Start Menu Cache for all existing users...");
                    try {
                        string usersDir = Path.Combine(targetDrive, "Users");
                        if (Directory.Exists(usersDir)) {
                            foreach (string userDir in Directory.GetDirectories(usersDir)) {
                                string startBin = Path.Combine(userDir, @"AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin");
                                if (File.Exists(startBin)) {
                                    File.Delete(startBin);
                                    Log("Wiped Start Menu Cache: " + startBin);
                                }
                                
                                // Deploy GhostBuster Payload
                                if (runGhostBuster) {
                                    string ghostBusterContent = "@echo off\r\npowershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command \"Get-AppxPackage | Where-Object { -not $_.InstallLocation -or -not (Test-Path $_.InstallLocation) } | Remove-AppxPackage -ErrorAction SilentlyContinue\"\r\n";
                                    try {
                                        File.WriteAllText(Path.Combine(userDir, @"Desktop\Sovereign_GhostBuster.bat"), ghostBusterContent);
                                        string startupDir = Path.Combine(userDir, @"AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup");
                                        if (Directory.Exists(startupDir)) {
                                            File.WriteAllText(Path.Combine(startupDir, "Sovereign_GhostBuster_RunOnce.bat"), ghostBusterContent + "del \"%~f0\"\r\n");
                                        }
                                    } catch {}
                                }
                            }
                        }
                    } catch (Exception ex) { Log("Failed to wipe start menu: " + ex.Message); }
                }

                // CLEANUP
                if (mediaPath.ToLower().EndsWith(".iso") && File.Exists(finalWimPath))
                {
                    UpdateStatus("Cleaning up temporary WIM...");
                    File.Delete(finalWimPath);
                }

                if (isDebloatMode) {
                    UpdateStatus("DEBLOAT COMPLETE!");
                    UpdateProgress(100);
                    MessageBox.Show("System successfully tweaked!\n\nExplorer has been restarted to apply changes.", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
                } else {
                    UpdateStatus("DEPLOYMENT COMPLETE! Sovereign OS is ready to boot.");
                    UpdateProgress(100);
                    MessageBox.Show("Sovereign OS has been deployed successfully!\n\nYou can now Reboot your PC.", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
            }
            catch (Exception ex)
            {
                UpdateStatus("ERROR: " + ex.Message);
                try {
                    string logText = "";
                    if (this.InvokeRequired) { this.Invoke(new Action(() => logText = logBox.Text)); } else { logText = logBox.Text; }
                    File.WriteAllText(@"X:\Sovereign_Crash_Log.txt", logText + "\n\nEXCEPTION:\n" + ex.ToString()); 
                } catch {}
                MessageBox.Show("Operation failed:\n" + ex.Message + "\n\nA full log has been saved to X:\\Sovereign_Crash_Log.txt", "Fatal Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void UpdateStatus(string text)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => statusLabel.Text = text));
            }
            else
            {
                statusLabel.Text = text;
            }
        }

        private void UpdateProgress(int percent)
        {
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => progressBar.Value = percent));
            }
            else
            {
                progressBar.Value = percent;
            }
        }

        private void Log(string text)
        {
            if (string.IsNullOrEmpty(text)) return;
            if (this.InvokeRequired)
            {
                this.Invoke(new Action(() => {
                    logBox.AppendText(text + Environment.NewLine);
                    logBox.SelectionStart = logBox.Text.Length;
                    logBox.ScrollToCaret();
                }));
            }
            else
            {
                logBox.AppendText(text + Environment.NewLine);
                logBox.SelectionStart = logBox.Text.Length;
                logBox.ScrollToCaret();
            }
        }
    }
}
