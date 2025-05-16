# Add-Type -AssemblyName System.Net.HttpListener
# Add-Type -AssemblyName Microsoft.Office.Interop.Excel

# Paths
$credFile = "$env:USERPROFILE\Documents\SavedCredentials.xlsx"
$keyFile = "$env:USERPROFILE\Documents\encryption_key.key"
$desktopPath = [Environment]::GetFolderPath("Desktop")
$logPath = Join-Path $desktopPath "activity_log.txt"

# --- Encryption and Excel Setup Functions ---

function Generate-Key {
    $key = New-Object byte[] 32
    (New-Object Random).NextBytes($key)
    [System.IO.File]::WriteAllBytes($keyFile, $key)
}

function Load-Key {
    if (-Not (Test-Path $keyFile)) { Generate-Key }
    return [System.IO.File]::ReadAllBytes($keyFile)
}

function Encrypt-Password($password, $key) {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = @(0..15)
    $encryptor = $aes.CreateEncryptor()
    $ms = New-Object System.IO.MemoryStream
    $cs = New-Object System.Security.Cryptography.CryptoStream($ms, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
    $sw = New-Object System.IO.StreamWriter($cs)
    $sw.Write($password)
    $sw.Close(); $cs.Close()
    return [Convert]::ToBase64String($ms.ToArray())
}

function Initialize-Excel {
    if (-Not (Test-Path $credFile)) {
        $excel = New-Object -ComObject Excel.Application
        $workbook = $excel.Workbooks.Add()
        $sheet = $workbook.Sheets.Item(1)
        $sheet.Name = "Credentials"
        $sheet.Cells.Item(1,1).Value2 = "Website"
        $sheet.Cells.Item(1,2).Value2 = "Username"
        $sheet.Cells.Item(1,3).Value2 = "Encrypted Password"
        $workbook.SaveAs($credFile)
        $excel.Quit()
    }
}

function Save-ToExcel($site, $user, $encPwd) {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $wb = $excel.Workbooks.Open($credFile)
    $ws = $wb.Sheets.Item(1)
    $lastRow = $ws.UsedRange.Rows.Count + 1
    $ws.Cells.Item($lastRow,1).Value2 = $site
    $ws.Cells.Item($lastRow,2).Value2 = $user
    $ws.Cells.Item($lastRow,3).Value2 = $encPwd
    $wb.Save()
    $wb.Close()
    $excel.Quit()
}

# --- Activity Logging Functions ---

if (-not (Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType File -Force | Out-Null
}

function Log-Activity {
    param ([string]$activity)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $activity"
}

# --- Initialize Files ---
Initialize-Excel
$key = Load-Key

# --- Job 1: Credential HTTP Listener ---
Start-Job -ScriptBlock {
    param($credFile, $keyFile)
    
    function Load-Key { return [System.IO.File]::ReadAllBytes($keyFile) }

    function Encrypt-Password($password, $key) {
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key
        $aes.IV = @(0..15)
        $encryptor = $aes.CreateEncryptor()
        $ms = New-Object System.IO.MemoryStream
        $cs = New-Object System.Security.Cryptography.CryptoStream($ms, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
        $sw = New-Object System.IO.StreamWriter($cs)
        $sw.Write($password)
        $sw.Close(); $cs.Close()
        return [Convert]::ToBase64String($ms.ToArray())
    }

    function Save-ToExcel($site, $user, $encPwd, $credFile) {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $wb = $excel.Workbooks.Open($credFile)
        $ws = $wb.Sheets.Item(1)
        $lastRow = $ws.UsedRange.Rows.Count + 1
        $ws.Cells.Item($lastRow,1).Value2 = $site
        $ws.Cells.Item($lastRow,2).Value2 = $user
        $ws.Cells.Item($lastRow,3).Value2 = $encPwd
        $wb.Save()
        $wb.Close()
        $excel.Quit()
    }

    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:5050/save/")
    $listener.Start()
    Write-Host "HTTP Listener running at http://localhost:5050/save/"

    $key = Load-Key

    while ($true) {
        $context = $listener.GetContext()
        $reader = New-Object System.IO.StreamReader($context.Request.InputStream)
        $body = $reader.ReadToEnd()
        $reader.Close()

        $data = $body | ConvertFrom-Json
        $encPwd = Encrypt-Password $data.password $key
        Save-ToExcel $data.site $data.username $encPwd $credFile

        $response = $context.Response
        $response.StatusCode = 200
        $response.Close()

        Write-Host "Saved credentials for $($data.site)"
    }
} -ArgumentList $credFile, $keyFile

# --- Job 2: Activity Logger ---
Start-Job -ScriptBlock {
    param($logPath)
    
    function Log-Activity($activity) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $logPath -Value "$timestamp - $activity"
    }

    $loginMessage = "User $env:USERNAME logged in."
    Log-Activity -activity $loginMessage

    $lastLoggedProcesses = @()

    while ($true) {
        $activeWindow = (Get-Process | Where-Object { $_.MainWindowHandle -ne 0 } | Sort-Object StartTime -Descending | Select-Object -First 1)
        if ($activeWindow) {
            $activeWindowTitle = $activeWindow.MainWindowTitle
            $activeWindowName = $activeWindow.ProcessName
            Log-Activity "Foreground Window: $activeWindowName - $activeWindowTitle"
        }

        $currentProcesses = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 }
        foreach ($process in $currentProcesses) {
            if (-not ($lastLoggedProcesses -contains $process.Id)) {
                Log-Activity "New process started: $($process.ProcessName)"
                $lastLoggedProcesses += $process.Id
            }
        }

        foreach ($processId in $lastLoggedProcesses) {
            if (-not ($currentProcesses.Id -contains $processId)) {
                Log-Activity "Process closed: PID $processId"
                $lastLoggedProcesses = $lastLoggedProcesses | Where-Object { $_ -ne $processId }
            }
        }

        $userLoggedOut = (Get-WmiObject -Class Win32_ComputerSystem).UserName
        if (-not $userLoggedOut) {
            Log-Activity "User $env:USERNAME logged out."
            break
        }

        Start-Sleep -Seconds 5
    }
} -ArgumentList $logPath

Write-Host "Both jobs started: HTTP Listener and Activity Logger"
