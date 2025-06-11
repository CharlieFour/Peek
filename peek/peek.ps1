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
            ip_address = if ($ipAddress) { $ipAddress } else { "Unknown" }
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
                    ip_address = if ($ipAddress) { $ipAddress } else { "Unknown" }
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

function Get-ActiveWindowTitle {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class User32 {
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
    }
"@

    $buffer = New-Object System.Text.StringBuilder 1024
    $handle = [User32]::GetForegroundWindow()
    [User32]::GetWindowText($handle, $buffer, $buffer.Capacity) | Out-Null
    return $buffer.ToString()
}


function Start-CombinedMonitoring {
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = ".\peek\keylogger.exe"
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $Global:KeyloggerProcess = New-Object System.Diagnostics.Process
    $Global:KeyloggerProcess.StartInfo = $psi
    $Global:KeyloggerProcess.Start() | Out-Null

    $Global:InputWriter = $Global:KeyloggerProcess.StandardInput
    $Global:OutputReader = $Global:KeyloggerProcess.StandardOutput

    function Send-Command($cmd) {
        try {
            $Global:InputWriter.WriteLine($cmd)
            $Global:InputWriter.Flush()
            Write-Host "Command '$cmd' sent to keylogger" -ForegroundColor Green
        }
        catch {
            Write-Host "Error sending command: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    function Read-KeyloggerOutput {
        try {
            $output = ""
            $timeout = 0
            
            # Wait up to 3 seconds for output
            while ($timeout -lt 30) {  # 30 * 100ms = 3 seconds
                if ($Global:OutputReader.Peek() -ne -1) {
                    $line = $Global:OutputReader.ReadLine()
                    if ($line -and $line.Trim() -ne "" -and $line -ne "Unknown command.") {
                        $output += $line
                        # Keep reading if there might be more
                        Start-Sleep -Milliseconds 50
                        if ($Global:OutputReader.Peek() -eq -1) {
                            break
                        }
                    }
                } else {
                    Start-Sleep -Milliseconds 100
                    $timeout++
                }
            }
            
            if ($output.Length -gt 0) {
                return $output
            }
        }
        catch {
            Write-Host "Error reading output: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $null
    }

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
                            $Global:IsRecording = $true
                            $Global:RecordingStartTime = Get-Date
                            $Global:KeystrokeBuffer = ""
                            Send-Command "start"
                            Write-Host "Keystroke recording started!" -ForegroundColor Green
                        } else {
                            Write-Host "Keystroke recording is already active." -ForegroundColor Yellow
                        }
                    }
                    
                    "STOP" {
                        if ($Global:IsRecording) {
                            Send-Command "stop"
                            
                            # Wait for and read the keystroke data
                            Write-Host "Waiting for keystroke data..." -ForegroundColor Yellow
                            
                            $keystrokeData = Read-KeyloggerOutput
                            if ($keystrokeData -and $keystrokeData.Length -gt 0) {
                                Write-Host "Received keystrokes: $($keystrokeData.Length) characters" -ForegroundColor Green
                                Write-Host "Preview: $($keystrokeData.Substring(0, [Math]::Min(50, $keystrokeData.Length)))..." -ForegroundColor Cyan
                                
                                # ⬇️ Forcefully get active window title once more at the end
                                $finalWindowTitle = Get-ActiveWindowTitle
                                if (-not $finalWindowTitle) {
                                    $finalWindowTitle = "(Unknown Window)"
                                }
                                
                                # Save locally
                                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                                $keystrokeFile = "$($Global:Config.LogsFolder)\Keystrokes\keystrokes_$timestamp.txt"
                                $keystrokeData | Out-File -FilePath $keystrokeFile -Encoding UTF8
                                Write-Host "Keystrokes saved to: $keystrokeFile" -ForegroundColor Green
                                
                                # Upload to Supabase with correct window title
                                $success = Send-KeystrokesToSupabase -Keystrokes $keystrokeData -WindowTitle $finalWindowTitle -StartTime $Global:RecordingStartTime -EndTime (Get-Date)
                                if ($success) {
                                    Write-Host "Keystrokes uploaded to database successfully!" -ForegroundColor Green
                                }
                            } else {
                                Write-Host "No keystroke data received (may be empty or no keys were pressed)" -ForegroundColor Yellow
                            }
                            
                            $Global:IsRecording = $false
                            $Global:RecordingStartTime = $null
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
                            Send-Command "stop"
                            Start-Sleep -Seconds 1
                        }
                        Send-Command "exit"
                        
                        # Clean up
                        if ($Global:KeyloggerProcess -and -not $Global:KeyloggerProcess.HasExited) {
                            $Global:KeyloggerProcess.WaitForExit(5000)  # Wait up to 5 seconds
                            if (-not $Global:KeyloggerProcess.HasExited) {
                                $Global:KeyloggerProcess.Kill()
                            }
                        }
                        
                        Stop-ActivityMonitor
                        Stop-DeviceInfoUpdater
                        $Global:Running = $false
                    }
                    
                    "" {
                        Write-Host "Type: START, STOP, DASHBOARD, STATUS, HELP, or QUIT" -ForegroundColor Yellow
                    }
                    
                    default {
                        Write-Host "Unknown command: '$command'" -ForegroundColor Red
                        Write-Host "Type HELP for available commands" -ForegroundColor Cyan
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
    Write-Host "PEEK - Enhanced Educational System Monitor - Usage:" -ForegroundColor Cyan
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
    Write-Host "* Real-time activity monitoring with 5-second intervals" -ForegroundColor White
    Write-Host "* User-controlled keystroke recording with consent" -ForegroundColor White
    Write-Host "* Automatic Supabase database synchronization" -ForegroundColor White
    Write-Host "* Organized local file storage in Logs folder" -ForegroundColor White
    Write-Host "* Real-time web dashboard with auto-refresh" -ForegroundColor White
    Write-Host "* Automatic browser opening for dashboard" -ForegroundColor White
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "* Update Supabase URL and Key in the script configuration" -ForegroundColor White
    Write-Host "* Logs are saved to: $($Global:Config.LogsFolder)" -ForegroundColor White
    Write-Host "* Dashboard is created in: $($Global:Config.WebDashboardPath)" -ForegroundColor White
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