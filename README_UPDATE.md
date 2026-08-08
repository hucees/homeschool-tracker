# Academic Year Closeout + Grade Promotion + Homeschool Diplomas

Migration 014 adds two permanent-record workflows.

## Academic-year closeout

Instructor → Student → Year-end closeout

The review page shows the current official grade placement, completed and unfinished courses, confirmed instructional days/minutes, and official report count.

Year-end decisions:
- Promote
- Retain
- Continue
- Instructor override
- Graduate when there are no unresolved active/planned courses

A closeout decision is permanently stored in `grade_level_decisions` with a frozen closeout snapshot.

For promote/retain/continue/override, the current academic-year placement is closed, the next placement is created, and unfinished subject enrollments are carried forward without changing their course grade level. The source enrollments remain in history as continued/superseded.

For Graduate, no next academic-year placement is created and the student is marked graduated. Active/planned courses must already be resolved.

**Do not close the current real 2026–2027 year merely to test the write path.**

## Official homeschool diploma

Instructor → Student → Diploma control

The application intentionally allows an authorized homeschool administrator to issue a diploma for any student. It does not automatically gate issuance by grade level, completed-course count, or credits.

Before issuance, the administrator sees the current academic record and must explicitly attest that they authorize the diploma.

Each issued diploma receives:
- unique diploma number
- per-student version number
- official status
- graduation and issue dates
- diploma title and statement
- signatory name/title
- optional honors
- frozen cumulative academic-record snapshot
- SHA-256 integrity hash
- immutable permanent record
- Print / Save PDF view

The administrator may choose whether diploma issuance also marks the student as graduated.

Students can view and save only their own official diplomas from Academic Record. They cannot issue diplomas.

The application does not claim that a software-issued diploma automatically satisfies every outside institution's or jurisdiction's legal requirements.

## Safe current test

With the current real Grade 1 student:
1. Open **Year-end closeout** and verify the review values.
2. Do **not** click the permanent closeout button.
3. Open **Diploma control** and verify the academic summary and issuance form.
4. Do **not** issue a diploma merely as a test on the real student.

Use a dedicated test student later if you want to exercise both permanent write paths before year end.

## Install

1. Commit/push the working Transcript update first.
2. Stop the dev server if desired.
3. Copy this update into the project.
4. Run:
   - `npm run check:starter`
   - `npm run typecheck`
   - `npm run lint`
5. Run `npx supabase db push --dry-run`.
6. Confirm only `20260808004000_year_closeout_diplomas.sql` is pending.
7. Run `npx supabase db push`.
8. Restart `npm run dev`.
