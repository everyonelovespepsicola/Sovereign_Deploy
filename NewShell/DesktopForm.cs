using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using System.Runtime.InteropServices;

namespace CustomShell
{
    public class DesktopForm : Form
    {
        [DllImport("user32.dll")]
        private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
        private static readonly IntPtr HWND_BOTTOM = new IntPtr(1);
        private const uint SWP_NOSIZE = 0x0001;
        private const uint SWP_NOMOVE = 0x0002;
        private const uint SWP_NOACTIVATE = 0x0010;

        public DesktopForm()
        {
            this.FormBorderStyle = FormBorderStyle.None;
            this.WindowState = FormWindowState.Maximized;
            this.ShowInTaskbar = false;
            this.BackColor = Color.FromArgb(10, 10, 30); // Fallback color

            // Load WinPE Wallpaper
            string wallpaperPath = @"X:\Windows\System32\winpe.jpg";
            if (!File.Exists(wallpaperPath))
            {
                // Fallback to local testing path
                wallpaperPath = @"C:\Windows\System32\winpe.jpg";
            }

            if (File.Exists(wallpaperPath))
            {
                try
                {
                    this.BackgroundImage = Image.FromFile(wallpaperPath);
                    this.BackgroundImageLayout = ImageLayout.Zoom; // or Stretch/Center based on preference
                }
                catch { }
            }
        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            
            // Force window to absolute bottom of Z-order
            SetWindowPos(this.Handle, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
            this.SendToBack();
        }

        // Prevent taking focus from other apps
        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
                return cp;
            }
        }
    }
}
