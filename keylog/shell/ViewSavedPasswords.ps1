$keyFile = "$env:USERPROFILE\Documents\encryption_key.key"
$credFile = "$env:USERPROFILE\Documents\SavedCredentials.xlsx"

function Load-Key {
    return [System.IO.File]::ReadAllBytes($keyFile)
}

function Decrypt-Password($encryptedBase64, $key) {
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = @(0..15) # Must match how you encrypted it
    $decryptor = $aes.CreateDecryptor()
    $cipherBytes = [Convert]::FromBase64String($encryptedBase64)

    $ms = New-Object System.IO.MemoryStream(,$cipherBytes)
    $cs = New-Object System.Security.Cryptography.CryptoStream($ms, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Read)
    $sr = New-Object System.IO.StreamReader($cs)
    return $sr.ReadToEnd()
}

function Read-Logins {
    $excel = New-Object -ComObject Excel.Application
    $wb = $excel.Workbooks.Open($credFile)
    $ws = $wb.Sheets.Item(1)
    $rows = $ws.UsedRange.Rows.Count

    $key = Load-Key

    Write-Host "`n Decrypted Saved Credentials:`n"
    for ($i = 2; $i -le $rows; $i++) {
        $site = $ws.Cells.Item($i, 1).Value2
        $username = $ws.Cells.Item($i, 2).Value2
        $encrypted = $ws.Cells.Item($i, 3).Value2
        $password = Decrypt-Password $encrypted $key

        Write-Host "$site"
        Write-Host "$username"
        Write-Host "$password"
        Write-Host "-------------------------"
    }
    $wb.Close($false)
    $excel.Quit()
}

Read-Logins
