#Add-Type -AssemblyName System.Net.HttpListener
#Add-Type -AssemblyName Microsoft.Office.Interop.Excel

# Define where to save credentials
$credFile = "$env:USERPROFILE\Documents\SavedCredentials.xlsx"
$keyFile = "$env:USERPROFILE\Documents\encryption_key.key"

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
    $aes.IV = @(0..15) # Zero IV for simplicity
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

# Start HTTP listener
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:5050/save/")
$listener.Start()
Write-Host "Listening for login data on http://localhost:5050/save ..."

Initialize-Excel
$key = Load-Key

while ($true) {
    $context = $listener.GetContext()
    $reader = New-Object System.IO.StreamReader($context.Request.InputStream)
    $body = $reader.ReadToEnd()
    $reader.Close()

    $data = $body | ConvertFrom-Json
    $encPwd = Encrypt-Password $data.password $key
    Save-ToExcel $data.site $data.username $encPwd

    $response = $context.Response
    $response.StatusCode = 200
    $response.Close()

    Write-Host "Saved credentials for $($data.site)"
}
``