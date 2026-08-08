# Grade 1 Math Audit Fix — Quarterly Mastery Max Points

The audit found these four mismatches:

- Week 9 `1-MATH-Q1-MASTERY`: template 20, questions 10
- Week 18 `1-MATH-Q2-MASTERY`: template 20, questions 10
- Week 27 `1-MATH-Q3-MASTERY`: template 20, questions 10
- Week 36 `1-MATH-Q4-MASTERY`: template 20, questions 10

Migration 025 changes the four template `max_points` values to **10**.

It also updates any already-created but ungraded student assignments copied from
those templates. If any target assignment already has a grade record, the
migration aborts rather than rewriting historical scoring.

## Install

```bash
cp -R ~/Downloads/homeschool-tracker-grade1-math-points-fix/. .
```

## Static check

```bash
node scripts/check-grade1-math-points-fix.mjs
```

Expected:

```text
Migrations: 25
Fix QA: 4 quarterly mastery templates
Expected question-bank scale: 10 items / 10 points
Historical policy: refuses to rewrite already-graded student mastery assignments
Grade 1 Math mastery-points fix static checks passed.
```

Then:

```bash
npm run typecheck
npm run lint
npx supabase db push --dry-run
```

The dry run should show only:

```text
20260808015000_grade1_math_mastery_points_fix.sql
```

Then push:

```bash
npx supabase db push 2>&1 | tee ~/Desktop/supabase-push-log.txt
```

Verify:

```bash
npx supabase migration list
```

Then rerun:

```bash
node scripts/audit-grade1-math.mjs
```
