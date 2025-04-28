# Add necessary assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

# Define paths
$credFile = "$env:USERPROFILE\Documents\SavedCredentials.xlsx"
$keyFile = "$env:USERPROFILE\Documents\encryption_key.key"

# --- Key Management ---
function Generate-Key {
    $key = New-Object byte[] 32
    (New-Object Random).NextBytes($key)
    [System.IO.File]::WriteAllBytes($keyFile, $key)
}

function Load-Key {
    if (-Not (Test-Path $keyFile)) { Generate-Key }
    return [System.IO.File]::ReadAllBytes($keyFile)
}

# --- Password Encryption ---
function Encrypt-Password($password, $key) {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = @(0..15) # Fixed IV for simplicity
    $encryptor = $aes.CreateEncryptor()
    $ms = New-Object System.IO.MemoryStream
    $cs = New-Object System.Security.Cryptography.CryptoStream($ms, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
    $sw = New-Object System.IO.StreamWriter($cs)
    $sw.Write($password)
    $sw.Close(); $cs.Close()
    return [Convert]::ToBase64String($ms.ToArray())
}

# --- Excel File Handling ---
function Initialize-Excel {
    if (-Not (Test-Path $credFile)) {
        $excel = New-Object -ComObject Excel.Application
        $workbook = $excel.Workbooks.Add()
        $sheet = $workbook.Sheets.Item(1)
        $sheet.Name = "Credentials"
        $sheet.Cells.Item(1,1).Value2 = "App/Site"
        $sheet.Cells.Item(1,2).Value2 = "Username"
        $sheet.Cells.Item(1,3).Value2 = "Encrypted Password"
        $workbook.SaveAs($credFile)
        $excel.Quit()
    }
}

function Save-ToExcel($site, $username, $encPwd) {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $wb = $excel.Workbooks.Open($credFile)
    $ws = $wb.Sheets.Item(1)
    $lastRow = $ws.UsedRange.Rows.Count + 1
    $ws.Cells.Item($lastRow,1).Value2 = $site
    $ws.Cells.Item($lastRow,2).Value2 = $username
    $ws.Cells.Item($lastRow,3).Value2 = $encPwd
    $wb.Save()
    $wb.Close()
    $excel.Quit()
}

# --- Credential Extraction ---
function Get-LoginFields($window) {
    $textBoxes = $window.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        (New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Edit
        ))
    )

    $userField = $null
    $passField = $null

    foreach ($tb in $textBoxes) {
        try {
            $pattern = $tb.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
            $value = $pattern.Current.Value

            if ($value -and ($value.Length -gt 0)) {
                if (-not $userField) {
                    $userField = $value
                }
                elseif (-not $passField) {
                    $passField = $value
                }
            }
        } catch {
            # Skip problematic fields
        }
    }

    return @{
        "WindowTitle" = $window.Current.Name
        "Username"    = $userField
        "Password"    = $passField
    }
}

# --- Main Watcher ---
function Watch-LoginButtons {
    $key = Load-Key
    Initialize-Excel

    while ($true) {
        $root = [System.Windows.Automation.AutomationElement]::RootElement

        $windows = $root.FindAll(
            [System.Windows.Automation.TreeScope]::Children,
            (New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                [System.Windows.Automation.ControlType]::Window
            ))
        )

        foreach ($window in $windows) {
            $buttons = $window.FindAll(
                [System.Windows.Automation.TreeScope]::Descendants,
                (New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                    [System.Windows.Automation.ControlType]::Button
                ))
            )

            foreach ($btn in $buttons) {
                try {
                    $btnName = $btn.Current.Name
                    if ($btnName -match "(?i)(login|sign in|submit)") {
                        Write-Host "Detected Login Page: $($window.Current.Name)" -ForegroundColor Yellow
                        Write-Host "Found login button: $btnName in $($window.Current.Name)"

                        $invokePattern = $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)

                        Register-ObjectEvent -InputObject $btn -EventName "Invoked" -Action {
                            Start-Sleep -Milliseconds 500
                            $credentials = Get-LoginFields -window $window

                            if ($credentials -and $credentials.Username -and $credentials.Password) {
                                $ask = [System.Windows.Forms.MessageBox]::Show(
                                    "Detected login attempt:`n$($credentials.WindowTitle)`nUsername: $($credentials.Username)`nSave credentials?", 
                                    "Save Login?", 
                                    [System.Windows.Forms.MessageBoxButtons]::YesNo
                                )
                                if ($ask -eq [System.Windows.Forms.DialogResult]::Yes) {
                                    $encPwd = Encrypt-Password $credentials.Password $key
                                    Save-ToExcel $credentials.WindowTitle $credentials.Username $encPwd
                                    Write-Host "Credentials saved for $($credentials.WindowTitle)"
                                }
                            }
                        }
                    }
                } catch {
                    # Ignore errors
                }
            }
        }
        Start-Sleep -Seconds 3
    }
}

# Start watching for login buttons
Write-Host "Script is running... Listening for login activities!" -ForegroundColor Green
Watch-LoginButtons
