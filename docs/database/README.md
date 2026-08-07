# Homeschool Tracker Database Foundation

This folder contains the first production-oriented Supabase/PostgreSQL schema for the K–12 homeschool tracking application.

## Migration order

1. `001_initial_schema.sql` — tables, keys, constraints, indexes
2. `002_security_rls.sql` — Supabase Auth profile trigger, RLS, curriculum locking, append-oriented grade history, audit logging
3. `003_seed_reference_data.sql` — K–12 grade levels and core subjects

In an actual Supabase project, rename/copy these into timestamped files under `supabase/migrations/` so Supabase applies them in order.

Example:

```text
supabase/
  migrations/
    20260807110000_initial_schema.sql
    20260807110100_security_rls.sql
    20260807110200_seed_reference_data.sql
```

## Recommended workflow

Supabase recommends testing schema changes locally as migrations before pushing them to the hosted project.

```bash
supabase init
supabase start
supabase db reset
```

After the local migrations succeed, link the hosted project and preview the deployment:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push --dry-run
supabase db push
```

Do not make later production schema changes directly in the Supabase Table Editor once migration-based development begins. Add another migration instead so the database history remains reproducible.

## Important architectural rules implemented here

### Student grade placement is separate from subject/course placement

`student_academic_years.official_grade_level_id` stores the student's official grade for that school year.

`student_course_enrollments` independently stores each course the student is actually taking. This allows a Grade 2 student to take Grade 1 Math, Grade 2 English, and Grade 3 Reading without changing the student's official grade.

### Curriculum history is versioned

A student enrollment points to a `course_version`, which points to a `curriculum_release`.

A curriculum release begins as `draft`. Once it is changed to `published`, Migration 002 prevents its versioned curriculum rows from being edited or deleted. Future curriculum changes must be made in a new release.

`course_versions` also snapshots course code, title, subject, and grade level so later edits to the canonical `courses` catalog do not rewrite the student's historical curriculum.

### Grades are revision-based

A grade row is not edited to change 78% into 88%.

The intended workflow is:

1. mark the old `grade_records` row as `superseded`;
2. create a new `grade_records` row with the next `revision_number`;
3. set `supersedes_grade_record_id` to the previous grade;
4. supply `change_reason` when appropriate.

The previous grade survives permanently and the audit log also records the change.

### Attendance is instructor-controlled

Students do not have INSERT or UPDATE RLS policies for `attendance_records`. Their daily work can later be used by the application to *suggest* attendance, but the instructor remains the authority for the official attendance record.

### Student notes and instructor-only notes are separated by database policy

`student_notes.visibility` can be:

- `student_and_teacher`
- `instructor_only`

Student RLS policies never expose `instructor_only` rows.

### Official reports are snapshots

Generated progress reports and transcripts store a JSON snapshot of the data used at generation time. This is intentional: a report issued in 2027 must not silently change because grading logic or curriculum structures are modified in 2030.

### Hard deletes are intentionally limited

Many permanent academic tables have no DELETE policy for authenticated users. Corrections should generally be represented by new revisions, status changes, superseding records, or explicit progression decisions rather than erasing history.

## Student usernames

Supabase Auth is authentication-oriented and does not provide a native school-style username/password identity separate from its Auth user identity. The schema therefore stores a student-facing `login_username` in `student_user_links` while keeping the underlying Supabase Auth account separate.

For the Next.js application, the recommended flow is:

1. Instructor creates the student account through a protected server action.
2. The server creates the Supabase Auth user using the Supabase Admin API.
3. The server creates/updates `student_user_links` with the simple username the child will use.
4. The login screen accepts username + password and the server resolves the username to the underlying Auth identity.

Do not expose the Supabase service-role key to the browser.

## First organization bootstrap

After the instructor creates their Supabase Auth account, the profile row is created automatically by the `on_auth_user_created` trigger.

The application can then create an organization with the logged-in profile as `created_by` and immediately insert its first `organization_members` row as:

```text
role = owner
status = active
```

The RLS migration includes a one-time bootstrap rule allowing the creator to become owner when the organization has no members yet.

## What should come next

The next database migration should load the first real curriculum slice:

```text
Curriculum Release: 2026.1
Course: 1-MATH
Course Version: Grade 1 Mathematics
Units
Competencies such as 1-MATH-01, 1-MATH-02, ...
36-week lesson structure
lesson ↔ competency mappings
```

That provides real data for building the first instructor dashboard and student “Today” screen.


## Migration 004 — Grade 1 Mathematics curriculum model

`004_grade1_math_curriculum.sql` adds the curriculum-detail layer needed by the revised Grade 1 Math model:

- `course_weeks`
- `competency_prerequisites`
- `competency_mastery_evidence_requirements`
- competency mastery/window/lesson-plan fields
- lesson types and mastery-check flags

It also installs `public.install_grade1_math_2026_1(organization_id)`. Call that function while signed in as active organization staff **after** the organization has been created:

```sql
select public.install_grade1_math_2026_1('<ORGANIZATION_UUID>');
```

The installer creates/reseeds the draft `2026.1` release for that organization with:

- 1 Grade 1 Mathematics course/version (`1-MATH`)
- 8 units
- 21 competencies
- 36 course weeks
- 180 daily math lessons
- 36 Friday assessment templates
- lesson-to-competency mappings
- prerequisite relationships
- structured mastery-evidence requirements

The installer refuses to reseed if student enrollments already reference the course version. It deliberately leaves the release in `draft`; do not publish/lock the release until all curriculum content intended for `2026.1` is ready.

See `GRADE1_MATH_2026_1_MODEL.md` for the human-readable specification.
Run `verify_grade1_math_2026_1.sql` after installation to confirm the expected 8 units, 21 competencies, 36 weeks, 180 lessons, and 36 assessment templates.
