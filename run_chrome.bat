@echo off
set SUPABASE_URL=https://kmcykmpimhyculcnshmp.supabase.co
set SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImttY3lrbXBpbWh5Y3VsY25zaG1wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI5NTEzNDAsImV4cCI6MjA3ODUyNzM0MH0.7A5JAm_hSnlT84w-nsb84rLYyPJUMdqVkbDmVmSCMyo

flutter run -d chrome ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

pause
