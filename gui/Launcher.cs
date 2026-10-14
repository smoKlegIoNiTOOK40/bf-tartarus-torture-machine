using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

namespace Tartarus.Gui {
    public static class Launcher {
        [STAThread]
        public static void Main() {
            try {
                string directory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                string script = Path.Combine(directory, "gui", "launch.ps1");
                if (!File.Exists(script)) throw new FileNotFoundException("Не найден файл окна Tartarus.", script);
                var start = new ProcessStartInfo {
                    FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe"),
                    Arguments = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File \"" + script + "\"",
                    WorkingDirectory = directory, UseShellExecute = false,
                    CreateNoWindow = true, WindowStyle = ProcessWindowStyle.Hidden
                };
                Process.Start(start);
            } catch (Exception error) {
                MessageBox.Show("Не удалось открыть Tartarus.\n\n" + error.Message,
                    "Tartarus", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
}
