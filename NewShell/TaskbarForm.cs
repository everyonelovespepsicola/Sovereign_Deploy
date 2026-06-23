using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace CustomShell
{
    public class TaskbarForm : Form
    {
        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll")]
        private static extern int GetWindowTextLength(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);

        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool IsIconic(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        private const int SW_RESTORE = 9;
        private const uint GW_OWNER = 4;

        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        private Button startButton;
        private Label timeLabel;
        private FlowLayoutPanel appPanel;
        private System.Windows.Forms.Timer clockTimer;
        private System.Windows.Forms.Timer windowTimer;
        private StartMenuForm startMenu;
        private DesktopForm desktop;

        private Dictionary<IntPtr, Button> windowButtons = new Dictionary<IntPtr, Button>();

        public TaskbarForm()
        {
            // Taskbar visual settings
            this.FormBorderStyle = FormBorderStyle.None;
            this.TopMost = true;
            this.BackColor = Color.FromArgb(30, 30, 30);
            this.ForeColor = Color.White;
            this.Height = 40;
            this.StartPosition = FormStartPosition.Manual;
            this.ShowInTaskbar = false;

            // Start Button
            startButton = new Button();
            startButton.Text = "Sovereign";
            startButton.Font = new Font("Segoe UI", 10, FontStyle.Bold);
            startButton.FlatStyle = FlatStyle.Flat;
            startButton.FlatAppearance.BorderSize = 0;
            startButton.BackColor = Color.FromArgb(0, 120, 215);
            startButton.ForeColor = Color.White;
            startButton.Size = new Size(100, 40);
            startButton.Location = new Point(0, 0);
            startButton.Click += StartButton_Click;
            this.Controls.Add(startButton);

            // FlowLayoutPanel for open windows
            appPanel = new FlowLayoutPanel();
            appPanel.Location = new Point(105, 0);
            appPanel.Height = 40;
            appPanel.WrapContents = false;
            this.Controls.Add(appPanel);

            // Clock Label
            timeLabel = new Label();
            timeLabel.Font = new Font("Segoe UI", 10, FontStyle.Regular);
            timeLabel.TextAlign = ContentAlignment.MiddleRight;
            timeLabel.Size = new Size(150, 40);
            this.Controls.Add(timeLabel);

            // Clock Timer
            clockTimer = new System.Windows.Forms.Timer();
            clockTimer.Interval = 1000;
            clockTimer.Tick += ClockTimer_Tick;
            clockTimer.Start();
            ClockTimer_Tick(null, null);

            // Window Manager Timer
            windowTimer = new System.Windows.Forms.Timer();
            windowTimer.Interval = 500;
            windowTimer.Tick += WindowTimer_Tick;
            windowTimer.Start();

            this.Resize += TaskbarForm_Resize;
        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            
            // Position at bottom of the primary screen
            Rectangle screen = Screen.PrimaryScreen.Bounds;
            this.Width = screen.Width;
            this.Location = new Point(screen.X, screen.Height - this.Height);

            // Resize appPanel to take available space
            appPanel.Width = this.Width - startButton.Width - timeLabel.Width - 15;

            // Launch the desktop wallpaper form
            desktop = new DesktopForm();
            desktop.Show();
        }

        private void TaskbarForm_Resize(object sender, EventArgs e)
        {
            timeLabel.Location = new Point(this.Width - timeLabel.Width - 10, 0);
            appPanel.Width = this.Width - startButton.Width - timeLabel.Width - 15;
        }

        private void ClockTimer_Tick(object sender, EventArgs e)
        {
            timeLabel.Text = DateTime.Now.ToString("h:mm tt\nMMM d, yyyy");
        }

        private void StartButton_Click(object sender, EventArgs e)
        {
            if (startMenu == null || startMenu.IsDisposed)
            {
                startMenu = new StartMenuForm();
                startMenu.Location = new Point(this.Location.X, this.Location.Y - startMenu.Height);
                startMenu.Show();
            }
            else
            {
                if (startMenu.Visible)
                    startMenu.Hide();
                else
                {
                    startMenu.Location = new Point(this.Location.X, this.Location.Y - startMenu.Height);
                    startMenu.Show();
                    startMenu.BringToFront();
                }
            }
        }

        // --- Window Manager Logic ---

        private void WindowTimer_Tick(object sender, EventArgs e)
        {
            List<IntPtr> openWindows = new List<IntPtr>();

            EnumWindows((hWnd, lParam) =>
            {
                if (IsWindowVisible(hWnd) && GetWindow(hWnd, GW_OWNER) == IntPtr.Zero)
                {
                    int length = GetWindowTextLength(hWnd);
                    if (length > 0)
                    {
                        StringBuilder sb = new StringBuilder(length + 1);
                        GetWindowText(hWnd, sb, sb.Capacity);
                        string title = sb.ToString();

                        // Filter out our own shell windows
                        if (title != "CustomShell.TaskbarForm" && title != "CustomShell.DesktopForm" && title != "CustomShell.StartMenuForm" && title != "Program Manager")
                        {
                            // Filter out "Default IME" or other hidden system overlays
                            if (title != "Default IME" && title != "MSCTFIME UI")
                            {
                                openWindows.Add(hWnd);
                            }
                        }
                    }
                }
                return true;
            }, IntPtr.Zero);

            // Remove closed windows
            List<IntPtr> toRemove = new List<IntPtr>();
            foreach (var kvp in windowButtons)
            {
                if (!openWindows.Contains(kvp.Key))
                {
                    appPanel.Controls.Remove(kvp.Value);
                    kvp.Value.Dispose();
                    toRemove.Add(kvp.Key);
                }
            }
            foreach (var hWnd in toRemove) windowButtons.Remove(hWnd);

            // Add new windows
            foreach (var hWnd in openWindows)
            {
                if (!windowButtons.ContainsKey(hWnd))
                {
                    int length = GetWindowTextLength(hWnd);
                    StringBuilder sb = new StringBuilder(length + 1);
                    GetWindowText(hWnd, sb, sb.Capacity);
                    string title = sb.ToString();

                    Button btn = new Button();
                    btn.Text = title.Length > 20 ? title.Substring(0, 17) + "..." : title;
                    btn.Font = new Font("Segoe UI", 9, FontStyle.Regular);
                    btn.FlatStyle = FlatStyle.Flat;
                    btn.FlatAppearance.BorderSize = 0;
                    btn.BackColor = Color.FromArgb(50, 50, 50);
                    btn.ForeColor = Color.White;
                    btn.Size = new Size(150, 36);
                    btn.Margin = new Padding(2);
                    btn.Tag = hWnd;
                    btn.Click += WindowButton_Click;

                    windowButtons[hWnd] = btn;
                    appPanel.Controls.Add(btn);
                }
                else
                {
                    // Update title in case it changed
                    int length = GetWindowTextLength(hWnd);
                    StringBuilder sb = new StringBuilder(length + 1);
                    GetWindowText(hWnd, sb, sb.Capacity);
                    string title = sb.ToString();
                    string shortTitle = title.Length > 20 ? title.Substring(0, 17) + "..." : title;
                    if (windowButtons[hWnd].Text != shortTitle)
                        windowButtons[hWnd].Text = shortTitle;
                }
            }
        }

        private void WindowButton_Click(object sender, EventArgs e)
        {
            if (sender is Button btn && btn.Tag is IntPtr hWnd)
            {
                if (IsIconic(hWnd))
                {
                    ShowWindow(hWnd, SW_RESTORE);
                }
                SetForegroundWindow(hWnd);
            }
        }
    }
}
