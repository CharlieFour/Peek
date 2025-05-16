$nssm = "$PSScriptRoot\nssm.exe"
$script = "$PSScriptRoot\peek2.ps1"

& $nssm install Peek "powershell.exe" "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
& $nssm start Peek
