# Permanent Academic Record + Official Transcripts

Migration 013 completes the first transcript layer.

## Instructor

Student → Academic record

The live academic record shows:

- student identity
- academic-year / official-grade placement history
- confirmed attendance by academic year
- completed courses from permanent course completion records
- current / planned coursework
- current grade for active coursework
- course grade level, subject, and curriculum version
- credits when a course actually has credit values
- cumulative instructional days/minutes
- cumulative completed/current course counts

`Issue official transcript` recalculates the live record and freezes the exact
result in `transcript_snapshots`.

Each official transcript has:

- permanent version number
- official status
- SHA-256 JSON snapshot hash
- issue timestamp
- immutable snapshot data
- Print / Save PDF

Official transcripts may later be voided through a future explicit workflow, but
they cannot be silently edited or deleted.

## Student

The student portal now includes `Academic record`.

Students can:

- view their live current academic record
- Print / Save PDF the live record
- see official transcripts already issued to them
- open and Print / Save PDF those official transcripts

Students cannot issue an official transcript.

Existing RLS already restricts transcript snapshots so students can SELECT only
their own snapshots with `status = 'official'`.

## GPA

This update intentionally does not manufacture an elementary GPA.

Percentage grades, letter grades, and credits are preserved. A cumulative GPA
will be added only when a high-school grade-point policy is explicitly defined.

## Safe current test

The current Grade 1 Mathematics enrollment has not been completed, so the live
academic record should show:

- 0 completed courses
- Grade 1 Mathematics under current coursework
- current grade around 90%
- current Grade 1 placement
- current attendance/instructional totals

You may safely issue Transcript Version 1 now if you want to test the official
snapshot flow. It will truthfully show no completed courses yet and the active
course as current coursework.

## Install

1. Commit/push the working Course Completion update first if not already done.
2. Stop the dev server if desired.
3. Copy this update into the project.
4. Run:
   - `npm run check:starter`
   - `npm run typecheck`
   - `npm run lint`
5. Run `npx supabase db push --dry-run`.
6. Confirm only `20260808003000_official_transcripts.sql` is pending.
7. Run `npx supabase db push`.
8. Restart `npm run dev`.
