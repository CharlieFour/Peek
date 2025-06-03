# Collect basic device info
$hostname = $env:COMPUTERNAME
$ip = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip
$os = (Get-CimInstance Win32_OperatingSystem).Caption

# Create or update device in Supabase
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
