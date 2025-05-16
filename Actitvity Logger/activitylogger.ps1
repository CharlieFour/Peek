$desktopPath = [Environment]::GetFolderPath("Desktop")
$logPath = Join-Path $desktopPath "activity_log.txt"

if (-not (Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType File -Force | Out-Null
}

function Log-Activity {
    param (
        [string]$activity
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $activity"
    Add-Content -Path $logPath -Value $logMessage
}

$loginMessage = "User $env:USERNAME logged in."
Log-Activity -activity $loginMessage

$lastLoggedProcesses = @()

while ($true) {
    $activeWindow = (Get-Process | Where-Object { $_.MainWindowHandle -ne 0 } | Sort-Object StartTime -Descending | Select-Object -First 1)
    if ($activeWindow) {
        $activeWindowTitle = $activeWindow.MainWindowTitle
        $activeWindowName = $activeWindow.ProcessName
        $logMessage = "Foreground Window: $activeWindowName - $activeWindowTitle"
        Log-Activity -activity $logMessage
    }

    $currentProcesses = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 }
    foreach ($process in $currentProcesses) {
        if (-not ($lastLoggedProcesses -contains $process.Id)) {
            Log-Activity -activity "New process started: $($process.ProcessName)"
            $lastLoggedProcesses += $process.Id
        }
    }

    foreach ($processId in $lastLoggedProcesses) {
        if (-not ($currentProcesses.Id -contains $processId)) {
            $closedProcess = Get-Process -Id $processId -ErrorAction SilentlyContinue
            if ($closedProcess) {
                Log-Activity -activity "Process closed: $($closedProcess.ProcessName)"
            }
            $lastLoggedProcesses = $lastLoggedProcesses | Where-Object { $_ -ne $processId }
        }
    }

    $userLoggedOut = (Get-WmiObject -Class Win32_ComputerSystem).UserName
    if (-not $userLoggedOut) {
        Log-Activity -activity "User $env:USERNAME logged out."
        break
    }

    Start-Sleep -Seconds 5
}
