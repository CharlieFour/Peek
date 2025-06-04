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

function Start-KeystrokeRecording {
    $Global:IsRecording = $true
    $Global:RecordingStartTime = Get-Date
    $Global:KeystrokeBuffer = ""
    
    $context = Get-CurrentContext
    $Global:RecordingWindow = "$($context.ProcessName) - $($context.WindowTitle)"
    
    Write-Host ""
    Write-Host "[KEYSTROKE RECORDING STARTED]" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "Context: $Global:RecordingWindow" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Instructions:" -ForegroundColor Green
    Write-Host "- Type your text and press Enter to capture each line" -ForegroundColor White
    Write-Host "- Type 'STOP' to end keystroke recording" -ForegroundColor White
    Write-Host "- Type 'QUIT' to exit the program completely" -ForegroundColor White
    Write-Host ""
    Write-Host "Start typing (press Enter after each line):" -ForegroundColor Cyan
}

function Stop-KeystrokeRecording {
    if (-not $Global:IsRecording) {
        Write-Host "No active keystroke recording session." -ForegroundColor Yellow
        return
    }
    
    $Global:IsRecording = $false
    $endTime = Get-Date
    
    Write-Host ""
    Write-Host "[KEYSTROKE RECORDING STOPPED]" -ForegroundColor Green -BackgroundColor Black
    
    if ($Global:KeystrokeBuffer.Length -gt 0) {
        Write-Host "`nRecorded content ($($Global:KeystrokeBuffer.Length) characters):" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Gray
        Write-Host $Global:KeystrokeBuffer -ForegroundColor White
        Write-Host "========================================" -ForegroundColor Gray
        
        # Save locally and to Supabase
        Save-KeystrokesToFile -Keystrokes $Global:KeystrokeBuffer -WindowTitle $Global:RecordingWindow -StartTime $Global:RecordingStartTime -EndTime $endTime
        Send-KeystrokesToSupabase -Keystrokes $Global:KeystrokeBuffer -WindowTitle $Global:RecordingWindow -StartTime $Global:RecordingStartTime -EndTime $endTime
    } else {
        Write-Host "No content was recorded." -ForegroundColor Yellow
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
        $logFileName = "$keystrokesFolder\keystroke_log_$timestamp.json"
        $keystrokeLog | ConvertTo-Json -Depth 3 | Out-File -FilePath $logFileName -Encoding UTF8
        Write-Host "[SUCCESS] Keystroke session saved to: $logFileName" -ForegroundColor Green
        
        # Save readable text version
        $textFileName = "$keystrokesFolder\keystroke_log_$timestamp.txt"
        $textContent = @"
=== EDUCATIONAL KEYSTROKE LOG ===
Device: $deviceId
Context: $WindowTitle
Start Time: $($StartTime.ToString("yyyy-MM-dd HH:mm:ss"))
End Time: $($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))
Duration: $([math]::Round(($EndTime - $StartTime).TotalSeconds, 1)) seconds
Character Count: $($Keystrokes.Length)
Line Count: $(($Keystrokes -split "`n").Count)

=== CAPTURED CONTENT ===
$Keystrokes
=== END OF LOG ===
"@
        $textContent | Out-File -FilePath $textFileName -Encoding UTF8
        Write-Host "[SUCCESS] Readable keystroke log saved to: $textFileName" -ForegroundColor Green
        
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
    
    $keystrokeData = @{
        device_id = "$env:COMPUTERNAME-$env:USERNAME"
        keystrokes = $Keystrokes
        window_title = $WindowTitle
        timestamp = $StartTime.ToString("o")
    }
    
    Send-ToSupabase -Table "key_logs" -Data $keystrokeData
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
    
    # Start activity monitor
    Start-ActivityMonitor
    
    # Create and open dashboard
    Open-Dashboard
    
    Show-RecordingStatus
    Show-Help
    
    Write-Host "Ready! Activity monitor is running. Type 'START' to begin keystroke recording..." -ForegroundColor Green
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