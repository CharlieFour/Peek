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
    WebDashboardPath = "$PSScriptRoot\dashboard"
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

# Initialize folder structure
function Initialize-Folders {
    if (-not (Test-Path $Global:Config.LogsFolder)) {
        New-Item -ItemType Directory -Path $Global:Config.LogsFolder -Force | Out-Null
        New-Item -ItemType Directory -Path "$($Global:Config.LogsFolder)\Activity" -Force | Out-Null
        New-Item -ItemType Directory -Path "$($Global:Config.LogsFolder)\Keystrokes" -Force | Out-Null
        Write-Host "[INFO] Created logs folder structure" -ForegroundColor Green
    }
    
    if (-not (Test-Path $Global:Config.WebDashboardPath)) {
        New-Item -ItemType Directory -Path $Global:Config.WebDashboardPath -Force | Out-Null
        Write-Host "[INFO] Created dashboard folder" -ForegroundColor Green
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
    Write-Host "   ENHANCED EDUCATIONAL MONITOR" -ForegroundColor Yellow
    Write-Host "   University Operating Systems Project" -ForegroundColor Yellow
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
        $consent = Read-Host "Do you consent to comprehensive monitoring for this educational demo? (yes/no)"
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
    Create-WebDashboard
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

function Create-WebDashboard {
    Write-Host "[INFO] Creating enhanced web dashboard..." -ForegroundColor Green
    
    $dashboardPath = "$($Global:Config.WebDashboardPath)\index.html"
    
    # Create the enhanced HTML dashboard
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enhanced Educational Monitor Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }

        .header {
            background: rgba(255, 255, 255, 0.95);
            padding: 20px;
            text-align: center;
            box-shadow: 0 2px 20px rgba(0, 0, 0, 0.1);
            backdrop-filter: blur(10px);
        }

        .header h1 {
            color: #2c3e50;
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.1);
        }

        .header .subtitle {
            color: #7f8c8d;
            font-size: 1.1em;
        }

        .container {
            max-width: 1200px;
            margin: 30px auto;
            padding: 0 20px;
        }

        .status-bar {
            background: rgba(255, 255, 255, 0.9);
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 30px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        }

        .status-item {
            text-align: center;
        }

        .status-value {
            font-size: 2em;
            font-weight: bold;
            color: #3498db;
        }

        .status-label {
            color: #7f8c8d;
            font-size: 0.9em;
            margin-top: 5px;
        }

        .dashboard-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 30px;
            margin-bottom: 30px;
        }

        @media (max-width: 768px) {
            .dashboard-grid {
                grid-template-columns: 1fr;
            }
        }

        .panel {
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.1);
            backdrop-filter: blur(10px);
        }

        .panel-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid #ecf0f1;
        }

        .panel-title {
            font-size: 1.5em;
            color: #2c3e50;
            font-weight: 600;
        }

        .refresh-btn {
            background: linear-gradient(45deg, #3498db, #2980b9);
            color: white;
            border: none;
            padding: 8px 15px;
            border-radius: 20px;
            cursor: pointer;
            font-size: 0.9em;
            transition: all 0.3s ease;
        }

        .refresh-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(52, 152, 219, 0.4);
        }

        .log-container {
            height: 400px;
            overflow-y: auto;
            border: 1px solid #bdc3c7;
            border-radius: 8px;
            padding: 15px;
            background: #f8f9fa;
        }

        .log-entry {
            background: white;
            margin-bottom: 10px;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #3498db;
            box-shadow: 0 2px 5px rgba(0, 0, 0, 0.05);
            transition: all 0.3s ease;
        }

        .log-entry:hover {
            transform: translateX(5px);
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        }

        .log-entry.keystroke {
            border-left-color: #e74c3c;
        }

        .log-entry.activity {
            border-left-color: #27ae60;
        }

        .log-timestamp {
            font-size: 0.8em;
            color: #7f8c8d;
            margin-bottom: 5px;
        }

        .log-content {
            color: #2c3e50;
            line-height: 1.4;
        }

        .log-meta {
            font-size: 0.85em;
            color: #95a5a6;
            margin-top: 8px;
            font-style: italic;
        }

        .loading {
            text-align: center;
            padding: 40px;
            color: #7f8c8d;
            font-size: 1.1em;
        }

        .error {
            background: #e74c3c;
            color: white;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            text-align: center;
        }

        .success {
            background: #27ae60;
            color: white;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            text-align: center;
        }

        .config-panel {
            background: rgba(255, 255, 255, 0.9);
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 30px;
        }

        .config-row {
            display: flex;
            gap: 10px;
            margin-bottom: 15px;
            align-items: center;
        }

        .config-input {
            flex: 1;
            padding: 10px;
            border: 1px solid #bdc3c7;
            border-radius: 5px;
            font-size: 0.9em;
        }

        .config-status {
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 1.1em;
        }

        .status-indicator {
            font-size: 1.2em;
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }

        .stat-card {
            background: linear-gradient(45deg, #f39c12, #e67e22);
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        }

        .stat-number {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }

        .stat-label {
            font-size: 0.9em;
            opacity: 0.9;
        }

        .auto-refresh {
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 0.9em;
            color: #7f8c8d;
        }

        .switch {
            position: relative;
            display: inline-block;
            width: 50px;
            height: 24px;
        }

        .switch input {
            opacity: 0;
            width: 0;
            height: 0;
        }

        .slider {
            position: absolute;
            cursor: pointer;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-color: #ccc;
            transition: .4s;
            border-radius: 24px;
        }

        .slider:before {
            position: absolute;
            content: "";
            height: 18px;
            width: 18px;
            left: 3px;
            bottom: 3px;
            background-color: white;
            transition: .4s;
            border-radius: 50%;
        }

        input:checked + .slider {
            background-color: #3498db;
        }

        input:checked + .slider:before {
            transform: translateX(26px);
        }

        .filter-bar {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }

        .filter-btn {
            background: #ecf0f1;
            border: none;
            padding: 8px 15px;
            border-radius: 20px;
            cursor: pointer;
            font-size: 0.9em;
            transition: all 0.3s ease;
        }

        .filter-btn.active {
            background: #3498db;
            color: white;
        }

        .filter-btn:hover {
            background: #d5dbdb;
        }

        .log-type-badge {
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 0.75em;
            font-weight: bold;
            text-transform: uppercase;
        }

        .log-type-badge.keystroke {
            background: #e74c3c;
            color: white;
        }

        .log-type-badge.activity {
            background: #27ae60;
            color: white;
        }

        .device-info, .stat-info, .handle-info {
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }

        .no-data {
            text-align: center;
            padding: 40px;
            color: #95a5a6;
            font-style: italic;
            background: #f8f9fa;
            border-radius: 8px;
            margin: 20px 0;
        }

        .connection-status {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 0.9em;
            margin-top: 10px;
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: #e74c3c;
            animation: pulse 2s infinite;
        }

        .status-dot.connected {
            background: #27ae60;
        }

        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }

        .refresh-all-btn {
            background: linear-gradient(45deg, #8e44ad, #9b59b6);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 25px;
            cursor: pointer;
            font-size: 1em;
            font-weight: 600;
            margin: 20px auto;
            display: block;
            transition: all 0.3s ease;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .refresh-all-btn:hover {
            transform: translateY(-3px);
            box-shadow: 0 8px 25px rgba(142, 68, 173, 0.4);
        }

        .error-details {
            background: #fff5f5;
            border: 1px solid #fed7d7;
            color: #c53030;
            padding: 15px;
            border-radius: 8px;
            margin: 10px 0;
            font-family: 'Courier New', monospace;
            font-size: 0.85em;
            white-space: pre-wrap;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🖥️ Enhanced Educational Monitor</h1>
        <div class="subtitle">University Operating Systems Project - Real-time Activity & Keystroke Dashboard</div>
    </div>

    <div class="container">
        <!-- Status Bar -->
        <div class="status-bar">
            <div class="status-item">
                <div class="status-value" id="totalLogs">0</div>
                <div class="status-label">Total Logs</div>
            </div>
            <div class="status-item">
                <div class="status-value" id="keystrokeLogs">0</div>
                <div class="status-label">Keystroke Logs</div>
            </div>
            <div class="status-item">
                <div class="status-value" id="activityLogs">0</div>
                <div class="status-label">Activity Logs</div>
            </div>
            <div class="status-item">
                <div class="status-value" id="lastUpdate">Never</div>
                <div class="status-label">Last Update</div>
            </div>
        </div>

        <!-- Configuration Status -->
        <div class="config-panel">
            <h3>Configuration Status</h3>
            <div class="config-row">
                <div class="config-status" id="configStatus">
                    <span class="status-indicator" id="statusIndicator">🔴</span>
                    <span id="statusText">Checking configuration...</span>
                </div>
                <div class="connection-status">
                    <div class="status-dot" id="connectionDot"></div>
                    <span id="connectionText">Connecting...</span>
                </div>
            </div>
            <button class="refresh-all-btn" onclick="loadAllData()">🔄 Refresh All Data</button>
            <div class="auto-refresh">
                <label class="switch">
                    <input type="checkbox" id="autoRefresh" checked>
                    <span class="slider"></span>
                </label>
                <span>Auto-refresh every 5 seconds</span>
            </div>
        </div>

        <!-- Statistics Cards -->
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-number" id="todayKeystokes">0</div>
                <div class="stat-label">Today's Keystrokes</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="activeApps">0</div>
                <div class="stat-label">Active Applications</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="totalSessions">0</div>
                <div class="stat-label">Recording Sessions</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="avgSessionLength">0s</div>
                <div class="stat-label">Avg Session Length</div>
            </div>
        </div>

        <!-- Main Dashboard Grid -->
        <div class="dashboard-grid">
            <!-- Keystroke Logs Panel -->
            <div class="panel">
                <div class="panel-header">
                    <h3 class="panel-title">🔤 Keystroke Logs</h3>
                    <button class="refresh-btn" onclick="loadKeystrokeLogs()">Refresh</button>
                </div>
                <div class="filter-bar">
                    <button class="filter-btn active" onclick="filterLogs('keystroke', 'all')">All</button>
                    <button class="filter-btn" onclick="filterLogs('keystroke', 'today')">Today</button>
                    <button class="filter-btn" onclick="filterLogs('keystroke', 'recent')">Last Hour</button>
                </div>
                <div class="log-container" id="keystrokeLogs">
                    <div class="loading">Loading keystroke logs...</div>
                </div>
            </div>

            <!-- Activity Logs Panel -->
            <div class="panel">
                <div class="panel-header">
                    <h3 class="panel-title">🖱️ Activity Logs</h3>
                    <button class="refresh-btn" onclick="loadActivityLogs()">Refresh</button>
                </div>
                <div class="filter-bar">
                    <button class="filter-btn active" onclick="filterLogs('activity', 'all')">All</button>
                    <button class="filter-btn" onclick="filterLogs('activity', 'today')">Today</button>
                    <button class="filter-btn" onclick="filterLogs('activity', 'recent')">Last Hour</button>
                </div>
                <div class="log-container" id="activityLogs">
                    <div class="loading">Loading activity logs...</div>
                </div>
            </div>
        </div>

        <!-- Combined Timeline View -->
        <div class="panel">
            <div class="panel-header">
                <h3 class="panel-title">📊 Combined Timeline</h3>
                <button class="refresh-btn" onclick="loadCombinedTimeline()">Refresh</button>
            </div>
            <div class="log-container" id="combinedTimeline">
                <div class="loading">Loading combined timeline...</div>
            </div>
        </div>
    </div>

    <script>
        // Configuration - automatically loaded from PowerShell script
        let config = {
            supabaseUrl: 'https://vxevbehqnjhqodybymto.supabase.co',
            supabaseKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4ZXZiZWhxbmpocW9keWJ5bXRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg5NTYzNDYsImV4cCI6MjA2NDUzMjM0Nn0.BHAltakl2-UqwFjMFvKJYIWw9NcZ064N5BWt1Z6uyiE',
            autoRefresh: true,
            refreshInterval: 5000
        };

        let refreshTimer;
        let currentFilters = {
            keystroke: 'all',
            activity: 'all'
        };

        // Initialize dashboard
        document.addEventListener('DOMContentLoaded', function() {
            checkConfiguration();
            initializeAutoRefresh();
            loadAllData();
        });

        function checkConfiguration() {
            const statusIndicator = document.getElementById('statusIndicator');
            const statusText = document.getElementById('statusText');
            
            if (config.supabaseUrl && config.supabaseKey) {
                statusIndicator.textContent = '🟢';
                statusText.textContent = 'Configuration loaded from config.ps1 - Ready';
                statusText.style.color = '#27ae60';
            } else {
                statusIndicator.textContent = '🔴';
                statusText.textContent = 'Configuration missing - Check config.ps1';
                statusText.style.color = '#e74c3c';
            }
        }

        function initializeAutoRefresh() {
            const autoRefreshToggle = document.getElementById('autoRefresh');
            autoRefreshToggle.addEventListener('change', function() {
                config.autoRefresh = this.checked;
                if (config.autoRefresh) {
                    startAutoRefresh();
                } else {
                    stopAutoRefresh();
                }
            });

            if (config.autoRefresh) {
                startAutoRefresh();
            }
        }

        function startAutoRefresh() {
            stopAutoRefresh();
            refreshTimer = setInterval(loadAllData, config.refreshInterval);
        }

        function stopAutoRefresh() {
            if (refreshTimer) {
                clearInterval(refreshTimer);
            }
        }

        async function makeSupabaseRequest(table, filter = '') {
            if (!config.supabaseUrl || !config.supabaseKey) {
                throw new Error('Supabase configuration not set');
            }

            const url = `${config.supabaseUrl}/rest/v1/${table}${filter ? '?' + filter : ''}`;
            const response = await fetch(url, {
                headers: {
                    'apikey': config.supabaseKey,
                    'Authorization': `Bearer ${config.supabaseKey}`,
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            return await response.json();
        }

        async function loadKeystrokeLogs() {
            try {
                document.getElementById('keystrokeLogs').innerHTML = '<div class="loading">🔄 Loading keystroke logs...</div>';
                
                let filter = 'order=timestamp.desc&limit=50';
                
                if (currentFilters.keystroke === 'today') {
                    const today = new Date().toISOString().split('T')[0];
                    filter += `&timestamp=gte.${today}T00:00:00`;
                } else if (currentFilters.keystroke === 'recent') {
                    const oneHourAgo = new Date(Date.now() - 3600000).toISOString();
                    filter += `&timestamp=gte.${oneHourAgo}`;
                }

                const logs = await makeSupabaseRequest('key_logs', filter);
                displayKeystrokeLogs(logs);
                updateKeystrokeStats(logs);
                showConnectionStatus(true);
            } catch (error) {
                console.error('Keystroke logs error:', error);
                document.getElementById('keystrokeLogs').innerHTML = 
                    `<div class="error">❌ Error loading keystroke logs
                     <div class="error-details">${error.message}</div>
                     <button class="refresh-btn" onclick="loadKeystrokeLogs()">🔄 Retry</button></div>`;
                showConnectionStatus(false);
            }
        }

        async function loadActivityLogs() {
            try {
                document.getElementById('activityLogs').innerHTML = '<div class="loading">🔄 Loading activity logs...</div>';
                
                let filter = 'order=timestamp.desc&limit=50';
                
                if (currentFilters.activity === 'today') {
                    const today = new Date().toISOString().split('T')[0];
                    filter += `&timestamp=gte.${today}T00:00:00`;
                } else if (currentFilters.activity === 'recent') {
                    const oneHourAgo = new Date(Date.now() - 3600000).toISOString();
                    filter += `&timestamp=gte.${oneHourAgo}`;
                }

                const logs = await makeSupabaseRequest('activity_logs', filter);
                displayActivityLogs(logs);
                updateActivityStats(logs);
                showConnectionStatus(true);
            } catch (error) {
                console.error('Activity logs error:', error);
                document.getElementById('activityLogs').innerHTML = 
                    `<div class="error">❌ Error loading activity logs
                     <div class="error-details">${error.message}</div>
                     <button class="refresh-btn" onclick="loadActivityLogs()">🔄 Retry</button></div>`;
                showConnectionStatus(false);
            }
        }

        async function loadCombinedTimeline() {
            try {
                const [keystrokeLogs, activityLogs] = await Promise.all([
                    makeSupabaseRequest('key_logs', 'order=timestamp.desc&limit=25'),
                    makeSupabaseRequest('activity_logs', 'order=timestamp.desc&limit=25')
                ]);

                const combinedLogs = [
                    ...keystrokeLogs.map(log => ({...log, type: 'keystroke'})),
                    ...activityLogs.map(log => ({...log, type: 'activity'}))
                ].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

                displayCombinedTimeline(combinedLogs);
            } catch (error) {
                document.getElementById('combinedTimeline').innerHTML = 
                    `<div class="error">Error loading combined timeline: ${error.message}</div>`;
            }
        }

        function displayKeystrokeLogs(logs) {
            const container = document.getElementById('keystrokeLogs');
            
            if (logs.length === 0) {
                container.innerHTML = '<div class="loading">No keystroke logs found</div>';
                return;
            }

            const html = logs.map(log => `+"`"+`
                <div class="log-entry keystroke">
                    <div class="log-timestamp">`+"`"+`${formatDateTime(log.timestamp)}</div>
                    <div class="log-content">
                        <strong>Window:</strong> `+"`"+`${escapeHtml(log.window_title || 'Unknown')}<br>
                        <strong>Content:</strong> `+"`"+`${escapeHtml(log.keystrokes || '').substring(0, 200)}`+"`"+`${log.keystrokes && log.keystrokes.length > 200 ? '...' : ''}
                    </div>
                    <div class="log-meta">
                        Device: `+"`"+`${escapeHtml(log.device_id || 'Unknown')} | 
                        Characters: `+"`"+`${log.keystrokes ? log.keystrokes.length : 0}
                    </div>
                </div>
            `+"`"+`).join('');

            container.innerHTML = html;
        }

        function displayActivityLogs(logs) {
            const container = document.getElementById('activityLogs');
            
            if (logs.length === 0) {
                container.innerHTML = '<div class="loading">No activity logs found</div>';
                return;
            }

            const html = logs.map(log => `+"`"+`
                <div class="log-entry activity">
                    <div class="log-timestamp">`+"`"+`${formatDateTime(log.timestamp)}</div>
                    <div class="log-content">
                        <strong>Application:</strong> `+"`"+`${escapeHtml(log.process_name || 'Unknown')}<br>
                        <strong>Window:</strong> `+"`"+`${escapeHtml(log.window_title || 'Unknown')}
                    </div>
                    <div class="log-meta">
                        Device: `+"`"+`${escapeHtml(log.device_id || 'Unknown')} | 
                        Handle: `+"`"+`${log.window_handle || 'N/A'}
                    </div>
                </div>
            `+"`"+`).join('');

            container.innerHTML = html;
        }

        function displayCombinedTimeline(logs) {
            const container = document.getElementById('combinedTimeline');
            
            if (logs.length === 0) {
                container.innerHTML = '<div class="loading">No logs found</div>';
                return;
            }

            const html = logs.map(log => `+"`"+`
                <div class="log-entry `+"`"+`${log.type}">
                    <div class="log-timestamp">`+"`"+`${formatDateTime(log.timestamp)} - `+"`"+`${log.type.toUpperCase()}</div>
                    <div class="log-content">
                        `+"`"+`${log.type === 'keystroke' ? 
                            `+"`"+`<strong>Keystroke Session:</strong> `+"`"+`${escapeHtml(log.window_title || 'Unknown')}<br>
                             <strong>Content:</strong> `+"`"+`${escapeHtml(log.keystrokes || '').substring(0, 150)}...`+"`"+` :
                            `+"`"+`<strong>Activity:</strong> `+"`"+`${escapeHtml(log.process_name || 'Unknown')}<br>
                             <strong>Window:</strong> `+"`"+`${escapeHtml(log.window_title || 'Unknown')}`+"`"+`
                        }
                    </div>
                    <div class="log-meta">
                        Device: `+"`"+`${escapeHtml(log.device_id || 'Unknown')} | 
                        `+"`"+`${log.type === 'keystroke' ? 
                            `+"`"+`Characters: `+"`"+`${log.keystrokes ? log.keystrokes.length : 0}`+"`"+` :
                            `+"`"+`Handle: `+"`"+`${log.window_handle || 'N/A'}`+"`"+`
                        }
                    </div>
                </div>
            `+"`"+`).join('');

            container.innerHTML = html;
        }

        function updateKeystrokeStats(logs) {
            const today = new Date().toISOString().split('T')[0];
            const todayLogs = logs.filter(log => log.timestamp.startsWith(today));
            const totalKeystrokes = todayLogs.reduce((sum, log) => sum + (log.keystrokes ? log.keystrokes.length : 0), 0);
            
            document.getElementById('todayKeystokes').textContent = totalKeystrokes;
            document.getElementById('keystrokeLogs').textContent = logs.length;
        }

        function updateActivityStats(logs) {
            const uniqueApps = new Set(logs.map(log => log.process_name)).size;
            document.getElementById('activeApps').textContent = uniqueApps;
            document.getElementById('activityLogs').textContent = logs.length;
        }

        function showConnectionStatus(connected) {
            const dot = document.getElementById('connectionDot');
            const text = document.getElementById('connectionText');
            
            if (connected) {
                dot.classList.add('connected');
                text.textContent = 'Connected to Supabase';
                text.style.color = '#27ae60';
            } else {
                dot.classList.remove('connected');
                text.textContent = 'Connection Failed';
                text.style.color = '#e74c3c';
            }
        }

        function updateGeneralStats() {
            const keystrokeCount = parseInt(document.getElementById('keystrokeLogs').textContent || 0);
            const activityCount = parseInt(document.getElementById('activityLogs').textContent || 0);
            const totalLogs = keystrokeCount + activityCount;
            
            document.getElementById('totalLogs').textContent = totalLogs;
            document.getElementById('lastUpdate').textContent = new Date().toLocaleTimeString();
            
            // Update individual counters in status bar
            document.getElementById('keystrokeLogs').textContent = keystrokeCount;
            document.getElementById('activityLogs').textContent = activityCount;
        }

        function filterLogs(type, filter) {
            currentFilters[type] = filter;
            
            // Update active button
            const buttons = document.querySelectorAll(`.panel:has(#${type}Logs) .filter-btn`);
            buttons.forEach(btn => btn.classList.remove('active'));
            event.target.classList.add('active');
            
            // Reload data
            if (type === 'keystroke') {
                loadKeystrokeLogs();
            } else {
                loadActivityLogs();
            }
        }

        async function loadAllData() {
            await Promise.all([
                loadKeystrokeLogs(),
                loadActivityLogs(),
                loadCombinedTimeline()
            ]);
            updateGeneralStats();
        }

        function formatDateTime(timestamp) {
            return new Date(timestamp).toLocaleString();
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        function showMessage(message, type) {
            const messageDiv = document.createElement('div');
            messageDiv.className = type;
            messageDiv.textContent = message;
            
            const container = document.querySelector('.container');
            container.insertBefore(messageDiv, container.firstChild);
            
            setTimeout(() => {
                messageDiv.remove();
            }, 3000);
        }

        // Handle visibility change for performance
        document.addEventListener('visibilitychange', function() {
            if (document.hidden) {
                stopAutoRefresh();
            } else if (config.autoRefresh) {
                startAutoRefresh();
            }
        });
    </script>
</body>
</html>
"@

    $htmlContent | Out-File -FilePath $dashboardPath -Encoding UTF8
    
    Write-Host "[SUCCESS] Enhanced dashboard created at: $dashboardPath" -ForegroundColor Green
    return $dashboardPath
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