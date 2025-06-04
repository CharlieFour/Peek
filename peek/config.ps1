# config.ps1
# Configuration file for Activity Monitor Service

# Supabase Configuration
$env:SUPABASE_URL = "https://vxevbehqnjhqodybymto.supabase.co"
$env:SUPABASE_API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4ZXZiZWhxbmpocW9keWJ5bXRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg5NTYzNDYsImV4cCI6MjA2NDUzMjM0Nn0.BHAltakl2-UqwFjMFvKJYIWw9NcZ064N5BWt1Z6uyiE"

# Service Configuration
$global:ServiceConfig = @{
    Name = "ActivityMonitorService"
    DisplayName = "Enhanced Activity Monitor Service"
    Description = "Enhanced activity and keystroke monitoring service with remote management capabilities"
    LogRetentionDays = 7
    MaxLogSize = 10MB
}