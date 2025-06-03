# Replace with your Supabase project details
$SUPABASE_URL = "https://your-project.supabase.co"
$SUPABASE_KEY = "your-anon-api-key"

# Headers for authentication
$headers = @{
    "apikey"        = $SUPABASE_KEY
    "Authorization" = "Bearer $SUPABASE_KEY"
    "Content-Type"  = "application/json"
}
