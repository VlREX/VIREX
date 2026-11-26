using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class StudioLauncher
{
    [STAThread]
    private static int Main()
    {
        try
        {
            string directory = AppDomain.CurrentDomain.BaseDirectory;
            string shell = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
            var command = new ProcessStartInfo {
                FileName = shell,
                Arguments = "-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy RemoteSigned -File \"" +
                            Path.Combine(directory, "VIREX-Test-Studio.ps1") + "\"",
                WorkingDirectory = directory,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardError = true
            };
            using (var process = Process.Start(command))
            {
                string error = process.StandardError.ReadToEnd();
                process.WaitForExit();
                if (process.ExitCode != 0)
                {
                    MessageBox.Show(error.Length > 0 ? error : "A Studio indítása sikertelen. Nyisd meg a README.md fájlt.",
                                    "VIREX Test Studio", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
                return process.ExitCode;
            }
        }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, "VIREX Test Studio", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
