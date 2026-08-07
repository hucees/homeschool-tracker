# Student Login + Portal Update

This update adds the second working vertical slice.

Included:
- Instructor student detail page
- Instructor-managed student username/password creation
- Server-only Supabase admin client using SUPABASE_SECRET_KEY
- Student password reset
- Student sign-in with school code + username + password
- Chromebook-friendly student portal
- Next incomplete lesson selection per active course
- Student completion checkbox, minutes worked, and lesson note
- Atomic daily learning record RPC
- Migration 006
- Student roster links to student records

Security:
- The Supabase secret key stays server-only.
- Students remain protected by Row Level Security.
- Student daily writes are validated again inside PostgreSQL.
