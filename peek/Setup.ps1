# Setup.ps1 - Installation Script for Activity Monitor Service

param(
    [switch]$Uninstall,
    [string]$SupabaseUrl = "https://vxevbehqnjhqodybymto.supabase.co",
    [string]$SupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4ZXZiZWhxbmpocW9keWJ5bXRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg5NTYzNDYsImV4cCI6MjA2NDUzMjM0Nn0.BHAltakl2-UqwFjMFvKJYIWw9NcZ064N5BWt1Z6uyiE"
)

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Request administrator privileges if not running as admin
if (-not (Test-Administrator)) {
    Write-Host "This script requires administrator privileges. Restarting as administrator..." -ForegroundColor Yellow
    
    $arguments = ""
    if ($Uninstall) { $arguments += " -Uninstall" }
    if ($SupabaseUrl) { $arguments += " -SupabaseUrl '$SupabaseUrl'" }
    if ($SupabaseKey) { $arguments += " -SupabaseKey '$SupabaseKey'" }
    
    Start-Process PowerShell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"$arguments"
    exit
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Activity Monitor Service Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Installation directory
$InstallPath = "$env:ProgramFiles\ActivityMonitor"
$ServiceName = "ActivityMonitorService"

# Create installation directory
if (!(Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-Host "Created installation directory: $InstallPath" -ForegroundColor Green
}

# Uninstall function
function Remove-ActivityMonitor {
    Write-Host "Uninstalling Activity Monitor Service..." -ForegroundColor Yellow
    
    try {
        # Stop and remove service
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service) {
            if ($service.Status -eq "Running") {
                Write-Host "Stopping service..." -ForegroundColor Yellow
                Stop-Service -Name $ServiceName -Force
            }
            
            Write-Host "Removing service..." -ForegroundColor Yellow
            Remove-Service -Name $ServiceName
        }
        
        # Remove installation directory
        if (Test-Path $InstallPath) {
            Write-Host "Removing installation files..." -ForegroundColor Yellow
            Remove-Item -Path $InstallPath -Recurse -Force
        }
        
        # Remove environment variables
        [Environment]::SetEnvironmentVariable("SUPABASE_URL", $null, "Machine")
        [Environment]::SetEnvironmentVariable("SUPABASE_API_KEY", $null, "Machine")
        
        Write-Host "Activity Monitor Service uninstalled successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error during uninstallation: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Install function
function Install-ActivityMonitor {
    Write-Host "Installing Activity Monitor Service..." -ForegroundColor Green
    
    # Get Supabase configuration if not provided
    if (-not $SupabaseUrl) {
        $SupabaseUrl = Read-Host "Enter your Supabase URL"
    }
    if (-not $SupabaseKey) {
        $SupabaseKey = Read-Host "Enter your Supabase API Key"
    }
    
    if (-not $SupabaseUrl -or -not $SupabaseKey) {
        Write-Host "Supabase URL and API Key are required!" -ForegroundColor Red
        return $false
    }
    
    try {
        # Set environment variables
        [Environment]::SetEnvironmentVariable("SUPABASE_URL", $SupabaseUrl, "Machine")
        [Environment]::SetEnvironmentVariable("SUPABASE_API_KEY", $SupabaseKey, "Machine")
        Write-Host "Environment variables configured" -ForegroundColor Green
        
        # Create config file
        $configContent = @"
# Configuration for Activity Monitor Service
`$env:SUPABASE_URL = "$SupabaseUrl"
`$env:SUPABASE_API_KEY = "$SupabaseKey"
"@
        $configContent | Out-File -FilePath "$InstallPath\config.ps1" -Encoding UTF8
        Write-Host "Configuration file created" -ForegroundColor Green
        
        # Copy service files
        $serviceContent = Get-Content "$PSScriptRoot\ActivityMonitorService.ps1" -Raw
        $serviceContent | Out-File -FilePath "$InstallPath\ActivityMonitorService.ps1" -Encoding UTF8
        
        # Create service runner
        $runnerContent = @"
# Service Runner
`$ServicePath = Split-Path -Parent `$MyInvocation.MyCommand.Path
Set-Location `$ServicePath

# Load configuration
. "`$ServicePath\config.ps1"

# Import service module
. "`$ServicePath\ActivityMonitorService.ps1"

# Start monitoring
Start-Monitoring
"@
        $runnerContent | Out-File -FilePath "$InstallPath\ServiceRunner.ps1" -Encoding UTF8
        
        # Create the Windows service
        $serviceBinaryPath = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$InstallPath\ServiceRunner.ps1`""
        
        New-Service -Name $ServiceName -BinaryPathName $serviceBinaryPath -DisplayName "Activity Monitor Service" -Description "Monitors system activity and keystrokes" -StartupType Automatic
        
        # Start the service
        Start-Service -Name $ServiceName
        
        Write-Host "Service installed and started successfully!" -ForegroundColor Green
        
        # Create uninstall shortcut
        $uninstallScript = @"
# Uninstall Activity Monitor Service
`$InstallPath = "$InstallPath"
PowerShell -ExecutionPolicy Bypass -File "`$InstallPath\Setup.ps1" -Uninstall
"@
        $uninstallScript | Out-File -FilePath "$InstallPath\Uninstall.ps1" -Encoding UTF8
        
        Write-Host "Installation completed!" -ForegroundColor Green
        Write-Host "Service Status: " -NoNewline
        $service = Get-Service -Name $ServiceName
        Write-Host $service.Status -ForegroundColor $(if($service.Status -eq "Running"){"Green"}else{"Red"})
        
        return $true
    }
    catch {
        Write-Host "Error during installation: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
if ($Uninstall) {
    Remove-ActivityMonitor
} else {
    # Check if already installed
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service) {
        $choice = Read-Host "Service already installed. Do you want to reinstall? (y/N)"
        if ($choice -eq "y" -or $choice -eq "Y") {
            Remove-ActivityMonitor
            Start-Sleep -Seconds 2
            Install-ActivityMonitor
        } else {
            Write-Host "Installation cancelled." -ForegroundColor Yellow
        }
    } else {
        Install-ActivityMonitor
    }
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")