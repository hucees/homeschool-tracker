# Instructor Daily Review + Attendance Update

This is Migration 007 and the next working vertical slice.

## Added
- `/dashboard/daily` instructor review screen
- daily student work display
- student notes visible to the instructor
- activity-based attendance suggestion
- instructor-controlled attendance confirmation
- official instructional-minute field
- teacher daily summary
- attendance notes
- Approved / Reviewed / Needs Revision states
- dashboard counters for today's learning and confirmed attendance
- permanent `daily_record_reviews` and `attendance_records` writes

## Record-integrity safeguard
If learning evidence is changed after an instructor has approved the day, the database
automatically reopens the daily record and changes the review to `needs_revision`.
This prevents a previously approved record from silently changing underneath the instructor.

## After copying
Run:
- `npm run check:starter`
- `npm run typecheck`
- `npm run lint`
- `npx supabase db push --dry-run`
- `npx supabase db push`
