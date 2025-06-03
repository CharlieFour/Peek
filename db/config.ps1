# Replace with your Supabase project details
$SUPABASE_URL = "https://vxevbehqnjhqodybymto.supabase.co"
$SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4ZXZiZWhxbmpocW9keWJ5bXRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg5NTYzNDYsImV4cCI6MjA2NDUzMjM0Nn0.BHAltakl2-UqwFjMFvKJYIWw9NcZ064N5BWt1Z6uyiE"

# Headers for authentication
$headers = @{
    "apikey"        = $SUPABASE_KEY
    "Authorization" = "Bearer $SUPABASE_KEY"
    "Content-Type"  = "application/json"
}
