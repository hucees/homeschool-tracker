# Grade 1 Mathematics 2026.1 — Final Live Audit

This package adds a **read-only** audit script.

It does not create a Supabase migration and does not modify curriculum, student
records, grades, or deliveries.

## What the audit checks

The audit verifies the live Supabase database for:

- Grade 1 Math 2026.1 course presence
- 8 units
- 21 competencies
- competency mastery thresholds
- two-demonstration mastery configuration
- 36 exact instructional weeks
- 9 weeks per quarter
- exact week titles/modes/mastery flags
- 180 daily lessons
- correct `Wxx-D1` through `D5` codes
- correct daily lesson types and 30-minute duration
- lesson-to-competency mappings
- exactly one current published lesson revision per lesson
- complete teacher/student lesson fields
- 2,700 structured lesson content items
- 36 Friday assessment templates
- assessment-to-competency mappings
- 360 online assessment questions
- unique question codes and valid multiple-choice answer keys
- assessment max-points consistency
- frozen student-delivery integrity
- Week 34 / `1-MATH-20` 90% threshold
- Year-end mastery configuration

It also records an architectural warning about cumulative mastery assessments:
they currently map competencies at the whole-assessment level rather than at the
individual-question level.

## Install

Copy the extracted package into the project root:

```bash
cp -R ~/Downloads/homeschool-tracker-grade1-math-final-audit/. .
```

## Run

```bash
node scripts/audit-grade1-math.mjs
```

The script automatically reads the existing `.env.local`.

It accepts:

- `NEXT_PUBLIC_SUPABASE_URL` or `SUPABASE_URL`
- `SUPABASE_SECRET_KEY` or `SUPABASE_SERVICE_ROLE_KEY`

The secret is **never printed**.

## Output

A console summary is printed and a detailed JSON report is written to:

```text
audit-reports/grade1-math-2026.1.json
```

### Result meanings

**RELEASE-READY**
All automated checks passed.

**CORE AUDIT PASSED WITH WARNINGS**
No hard failures, but review the warnings before locking the curriculum.

**NOT RELEASE-READY**
At least one structural/content/database inconsistency was found. Fix it and
rerun the audit.

## Important

Do not send or paste your Supabase secret key. If the script reports that the
key is missing, only the environment-variable name/error message is needed for
troubleshooting.
