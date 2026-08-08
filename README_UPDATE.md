# Grade 1 Mathematics — Production Batch: Weeks 28–32

## Coverage

### Week 28 — `1-MATH-15` Organizing and Interpreting Data
- sort data into categories
- count each category
- read simple tables
- how many more / fewer
- totals
- online check

### Week 29 — `1-MATH-16` Representing Data
- one-for-one picture representations
- complete simple graphs
- interpret graph counts
- create/describe simple data displays
- online check

### Week 30 — `1-MATH-17` 2D and 3D Shapes
- defining attributes of common 2D shapes
- defining attributes of common 3D shapes
- sides, vertices, faces, curved surfaces
- compose larger shapes from smaller shapes
- online check

### Week 31 — `1-MATH-18` Halves and Fourths
- whole and equal shares
- halves
- fourths / quarters
- distinguish equal from unequal partitions
- compare one half and one fourth of the same whole
- online check

### Week 32 — `1-MATH-19` Adding Within 100 I
- two-digit + one-digit
- two-digit + multiple of 10
- explain which place changes
- tens/ones reasoning
- first addition-within-100 online check

Week 33 continues `1-MATH-19`.

## Totals

- 25 production lessons
- 375 lesson items
- 50 online assessment items

## Mastery policy

Optional sorting, graph drawing, shape building, folding, and base-ten modeling are
included as instructional activities. They do **not** create a separate hands-on
mastery-evidence requirement. The existing repeated qualifying evidence model
remains authoritative.

## Safety

Migration 023:
- runs in one transaction
- preflights every Week 28–32 lesson skeleton
- preflights every Friday assignment template
- refuses to overwrite published/superseded content
- refuses to rewrite frozen student deliveries
- refuses to overwrite existing question banks

## Install

Checkpoint Weeks 23–27:

```bash
git add .
git commit -m "Add Grade 1 Math Weeks 23 through 27 production curriculum"
git push
```

Copy this package into the project:

```bash
cp -R ~/Downloads/homeschool-tracker-grade1-math-weeks28-32-update/. .
```

Validate:

```bash
npm run check:starter
npm run typecheck
npm run lint
```

Expected static check:

```text
Migrations: 23
Batch QA: Weeks 28–32 / 25 lessons / 50 online assessment items
Coverage: data + graphs + shapes + halves/fourths + addition within 100 I
Mastery policy: no separate hands-on evidence requirement
Starter structure and Weeks 28–32 static checks passed.
```

Dry run:

```bash
npx supabase db push --dry-run
```

Expected pending migration:

```text
20260808013000_grade1_math_weeks28_32_content.sql
```

Push:

```bash
npx supabase db push 2>&1 | tee ~/Desktop/supabase-push-log.txt
```

Verify:

```bash
npx supabase migration list
```

Expected final row:

```text
20260808013000 | 20260808013000
```

## Instructor QA

Confirm five `Published r1` lessons in each of Weeks 28–32.

Spot-check:
- Week 28 Day 3 — Compare Data Categories
- Week 29 Day 3 — Create a Simple Data Display
- Week 30 Day 3 — Compose Larger Shapes
- Week 31 Day 4 — Equal Shares Matter
- Week 32 Day 3 — Explain How Tens and Ones Change

For each spot-check, open the lesson, Teacher Guide, and Answer Key.

Do not artificially advance the real student to later weeks merely for testing.
