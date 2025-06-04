# Educational Keystroke Logger - Fixed Version
# Works without administrator privileges using console input detection

param(
    [switch]$StartRecording
)

# Global variables
$Global:IsRecording = $false
$Global:KeystrokeBuffer = ""
$Global:RecordingStartTime = $null
$Global:MaxRecordingDuration = 300 # 5 minutes max
$Global:RecordingWindow = ""
$Global:Running = $true

# Educational disclaimer
function Show-EducationalDisclaimer {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "   EDUCATIONAL KEYSTROKE LOGGER" -ForegroundColor Yellow
    Write-Host "   University Operating Systems Project" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This tool demonstrates system monitoring concepts" -ForegroundColor Green
    Write-Host "and is for educational purposes only!" -ForegroundColor Red
    Write-Host ""
    Write-Host "SIMPLIFIED VERSION - Console Input Mode" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Features:" -ForegroundColor Cyan
    Write-Host "- Type text and press Enter to capture it" -ForegroundColor White
    Write-Host "- Type 'STOP' to end recording session" -ForegroundColor White
    Write-Host "- Type 'QUIT' to exit the program" -ForegroundColor White
    Write-Host "- Automatic timeout after 5 minutes" -ForegroundColor White
    Write-Host "- Logs saved locally" -ForegroundColor White
    Write-Host ""
    
    do {
        $consent = Read-Host "Do you consent to keystroke recording for this educational demo? (yes/no)"
    } while ($consent -notin @("yes", "no", "y", "n"))
    
    if ($consent -notin @("yes", "y")) {
        Write-Host "Recording cancelled." -ForegroundColor Red
        exit
    }
    Write-Host ""
}

# Get process information for context
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

# Show current recording status
function Show-RecordingStatus {
    $status = if ($Global:IsRecording) { "[RECORDING ACTIVE]" } else { "[Ready to Record]" }
    $color = if ($Global:IsRecording) { "Red" } else { "Green" }
    
    Write-Host "`n=== STATUS: $status ===" -ForegroundColor $color
    
    if ($Global:IsRecording) {
        $elapsed = (Get-Date) - $Global:RecordingStartTime
        Write-Host "Recording Time: $([math]::Round($elapsed.TotalSeconds, 1)) seconds" -ForegroundColor Yellow
        Write-Host "Characters Captured: $($Global:KeystrokeBuffer.Length)" -ForegroundColor Yellow
    }
}

# Start recording session
function Start-Recording {
    $Global:IsRecording = $true
    $Global:RecordingStartTime = Get-Date
    $Global:KeystrokeBuffer = ""
    
    $context = Get-CurrentContext
    $Global:RecordingWindow = "$($context.ProcessName) - $($context.WindowTitle)"
    
    Write-Host ""
    Write-Host "[RECORDING STARTED]" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "Context: $Global:RecordingWindow" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Instructions:" -ForegroundColor Green
    Write-Host "- Type your text and press Enter to capture each line" -ForegroundColor White
    Write-Host "- Type 'STOP' to end this recording session" -ForegroundColor White
    Write-Host "- Type 'QUIT' to exit the program completely" -ForegroundColor White
    Write-Host ""
    Write-Host "Start typing (press Enter after each line):" -ForegroundColor Cyan
}

# Stop recording session
function Stop-Recording {
    if (-not $Global:IsRecording) {
        Write-Host "No active recording session." -ForegroundColor Yellow
        return
    }
    
    $Global:IsRecording = $false
    $endTime = Get-Date
    
    Write-Host ""
    Write-Host "[RECORDING STOPPED]" -ForegroundColor Green -BackgroundColor Black
    
    if ($Global:KeystrokeBuffer.Length -gt 0) {
        Write-Host "`nRecorded content ($($Global:KeystrokeBuffer.Length) characters):" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Gray
        Write-Host $Global:KeystrokeBuffer -ForegroundColor White
        Write-Host "========================================" -ForegroundColor Gray
        
        # Save the recording
        Save-KeystrokesToFile -Keystrokes $Global:KeystrokeBuffer -WindowTitle $Global:RecordingWindow -StartTime $Global:RecordingStartTime -EndTime $endTime
    } else {
        Write-Host "No content was recorded." -ForegroundColor Yellow
    }
}

# Show help
function Show-Help {
    Write-Host ""
    Write-Host "Available Commands:" -ForegroundColor Cyan
    Write-Host "- START  : Begin a new recording session" -ForegroundColor White
    Write-Host "- STOP   : End the current recording session" -ForegroundColor White
    Write-Host "- STATUS : Show current recording status" -ForegroundColor White
    Write-Host "- HELP   : Show this help message" -ForegroundColor White
    Write-Host "- QUIT   : Exit the program" -ForegroundColor White
    Write-Host ""
    Write-Host "During recording, type normally and press Enter to capture each line." -ForegroundColor Green
    Write-Host ""
}

# Save keystrokes to file
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
        
        # Save to local JSON file
        $logFileName = "keystroke_log_$timestamp.json"
        $keystrokeLog | ConvertTo-Json -Depth 3 | Out-File -FilePath $logFileName -Encoding UTF8
        Write-Host "`n[SUCCESS] Session saved to JSON: $logFileName" -ForegroundColor Green
        
        # Save to text file for easy reading
        $textFileName = "keystroke_log_$timestamp.txt"
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
        Write-Host "[SUCCESS] Readable log saved to: $textFileName" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Host "[ERROR] Error saving keystrokes: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Check for timeout
function Check-Timeout {
    if ($Global:IsRecording -and $Global:RecordingStartTime) {
        $elapsed = (Get-Date) - $Global:RecordingStartTime
        if ($elapsed.TotalSeconds -gt $Global:MaxRecordingDuration) {
            Write-Host "`n[TIMEOUT] Auto-stopping recording after $Global:MaxRecordingDuration seconds" -ForegroundColor Yellow
            Stop-Recording
        }
    }
}

# Main keystroke recording function with FIXED input handling
function Start-KeystrokeRecording {
    Show-EducationalDisclaimer
    
    Write-Host "Educational Keystroke Logger - Console Mode" -ForegroundColor Cyan
    Write-Host "===========================================" -ForegroundColor Cyan
    
    Show-RecordingStatus
    Show-Help
    
    Write-Host "Ready! Type 'START' to begin your first recording session..." -ForegroundColor Green
    Write-Host ""
    
    # Main input loop with COMPLETELY REWRITTEN logic
    while ($Global:Running) {
        try {
            # Check for timeout
            Check-Timeout
            
            # Display prompt
            $promptText = if ($Global:IsRecording) { "Recording> " } else { "Keylogger> " }
            Write-Host $promptText -NoNewline -ForegroundColor Cyan
            
            # Get input
            $userInput = Read-Host
            
            # FIXED: Direct command processing without function call
            if ($userInput -ne $null) {
                $command = $userInput.Trim().ToUpper()
                
                # Process commands directly
                switch ($command) {
                    "START" {
                        Write-Host "Command recognized: START" -ForegroundColor Green
                        if (-not $Global:IsRecording) {
                            Start-Recording
                        } else {
                            Write-Host "Recording is already active. Type 'STOP' to end current session." -ForegroundColor Yellow
                        }
                    }
                    
                    "STOP" {
                        Write-Host "Command recognized: STOP" -ForegroundColor Green
                        if ($Global:IsRecording) {
                            Stop-Recording
                        } else {
                            Write-Host "No active recording session to stop." -ForegroundColor Yellow
                        }
                    }
                    
                    "HELP" {
                        Write-Host "Command recognized: HELP" -ForegroundColor Green
                        Show-Help
                    }
                    
                    "STATUS" {
                        Write-Host "Command recognized: STATUS" -ForegroundColor Green
                        Show-RecordingStatus
                        if ($Global:IsRecording) {
                            Write-Host "Type 'STOP' to end recording, or continue typing to capture more content." -ForegroundColor Cyan
                        } else {
                            Write-Host "Type 'START' to begin a new recording session." -ForegroundColor Cyan
                        }
                    }
                    
                    "QUIT" {
                        Write-Host "Command recognized: QUIT" -ForegroundColor Green
                        if ($Global:IsRecording) {
                            Write-Host "Stopping current recording before exit..." -ForegroundColor Yellow
                            Stop-Recording
                        }
                        $Global:Running = $false
                    }
                    
                    "" {
                        Write-Host "Empty input. Type: START, STOP, HELP, STATUS, or QUIT" -ForegroundColor Yellow
                    }
                    
                    default {
                        # If recording, add to buffer, otherwise show error
                        if ($Global:IsRecording) {
                            $timestamp = Get-Date -Format "HH:mm:ss"
                            $Global:KeystrokeBuffer += "[$timestamp] $userInput`n"
                            Write-Host "Captured: $userInput" -ForegroundColor Green
                            Write-Host "         (Type 'STOP' to end recording)" -ForegroundColor DarkGray
                        } else {
                            Write-Host "Unknown command: '$command'" -ForegroundColor Red
                            Write-Host "Available commands: START, STOP, HELP, STATUS, QUIT" -ForegroundColor Cyan
                        }
                    }
                }
            }
        }
        catch [System.Management.Automation.PipelineStoppedException] {
            Write-Host "`n[INFO] Recording stopped by user." -ForegroundColor Yellow
            break
        }
        catch {
            Write-Host "[ERROR] An error occurred: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n[SUCCESS] Educational Keystroke Logger ended." -ForegroundColor Green
}

# Main execution
if ($StartRecording) {
    Start-KeystrokeRecording
} else {
    Write-Host "Educational Keystroke Logger - Console Version" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This version works without administrator privileges!" -ForegroundColor Green
    Write-Host "It captures console input line by line for educational purposes." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Usage: .\KeyLogger.ps1 -StartRecording" -ForegroundColor Yellow
    Write-Host ""
    
    $start = Read-Host "Would you like to start the console-based keylogger now? (y/n)"
    if ($start -eq 'y') {
        Start-KeystrokeRecording
    }
}