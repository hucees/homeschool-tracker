# Grade 1 Mathematics — Production Batch: Weeks 23–27

## Coverage

### Week 23 — `1-MATH-13` Compare and Order Lengths
- direct comparison
- indirect comparison using a common reference
- order three lengths
- longer / shorter / same-length language
- Week 23 online check

### Week 24 — `1-MATH-14` Time to the Hour
- hour hand vs minute hand
- read exact-hour analog descriptions
- write digital `:00` times
- match analog descriptions, digital time, and words
- first time check

### Week 25 — `1-MATH-14` Time to the Half-Hour
- 30 minutes / half-hour
- minute hand on 6
- hour hand halfway toward the next hour
- write digital `:30` times
- half-hour check

### Week 26 — `1-MATH-14` Mixed Hour and Half-Hour
- mixed `:00` / `:30`
- analog/digital reasoning
- simple schedule use
- explain clock-hand positions
- additional independent time evidence

### Week 27 — Quarter 3 Mastery Check
Cumulative review for:
- `1-MATH-11` equations and unknowns
- `1-MATH-12` repeated-unit measurement
- `1-MATH-13` compare/order lengths
- `1-MATH-14` tell/write time

## Totals
- 25 production lessons
- 375 lesson items
- 50 online assessment items

## Safety
Migration 022:
- one transaction
- preflights all Weeks 23–27 lessons/templates
- refuses to overwrite published/superseded content
- refuses to rewrite frozen student deliveries
- refuses to overwrite existing assessment banks
- introduces no separate hands-on mastery requirement

## Install

Checkpoint Weeks 18–22 first:

```bash
git add .
git commit -m "Add Grade 1 Math Weeks 18 through 22 production curriculum"
git push
```

Copy the extracted package:

```bash
cp -R ~/Downloads/homeschool-tracker-grade1-math-weeks23-27-update/. .
```

Validate:

```bash
npm run check:starter
npm run typecheck
npm run lint
```

Expected static check:

```text
Migrations: 22
Batch QA: Weeks 23–27 / 25 lessons / 50 online assessment items
Coverage: compare/order lengths + hour/half-hour time + Q3 mastery
Mastery policy: no separate hands-on evidence requirement
Starter structure and Weeks 23–27 static checks passed.
```

Dry run:

```bash
npx supabase db push --dry-run
```

Expected pending migration:

```text
20260808012000_grade1_math_weeks23_27_content.sql
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
20260808012000 | 20260808012000
```

## Instructor QA

Spot-check:
- Week 23 Day 3 — Order Three Lengths
- Week 24 Day 3 — Match Analog, Digital, and Words
- Week 25 Day 2 — Read Half-Hour Times
- Week 26 Day 2 — Time in a Daily Schedule
- Week 27 Day 5 — Quarter 3 Mastery Readiness

Confirm `Published r1`, lesson content, Teacher Guide, and Answer Key.
