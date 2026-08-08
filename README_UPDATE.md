# Grade 1 Mathematics — Production Batch: Weeks 18–22

## Coverage

### Week 18 — Quarter 2 Mastery Check
Cumulative review/evidence for:
- `1-MATH-06` Add within 20
- `1-MATH-07` Subtract within 20
- `1-MATH-08` Fact fluency within 10
- `1-MATH-09` Addition/subtraction relationships
- `1-MATH-10` One-step word problems

The Week 18 assessment should be interpreted with the existing per-competency
thresholds. In particular, `1-MATH-08` retains its 90% threshold.

### Week 19 — `1-MATH-11` Equations and Unknowns I
- meaning of the equals sign
- true/false equations
- result unknowns
- missing addends
- unknowns in subtraction
- first online check

### Week 20 — `1-MATH-11` Equations and Unknowns II
- unknowns in varied positions
- inverse operations to solve/check
- true/false equation repair
- explain equality reasoning
- second online check

### Week 21 — `1-MATH-12` Measuring Length I
- repeated equal-size units
- end-to-end placement
- no gaps or overlaps
- number + unit reporting
- first online measurement check

### Week 22 — `1-MATH-12` Measuring Length II
- independent repeated-unit measurement reasoning
- effect of unit size on numeric measurement
- measurement error analysis
- explain reliable measurement
- second online measurement check

## Package totals

- 25 full production lessons
- 375 guided / independent / worksheet items
- 5 online assessments
- 50 auto-scored assessment items

## Mastery policy

Practical measurement with cubes, paper clips, or other equal units is useful
instruction and appears as optional activities. It is **not** installed as a
separate mastery-evidence requirement.

The app's established repeated qualifying evidence model remains authoritative.

## Historical safety

Migration 021:
- runs in one transaction
- preflights all 25 lesson skeletons before writing
- checks all five Friday assessment templates
- refuses to overwrite published/superseded content
- refuses to rewrite frozen student deliveries
- refuses to overwrite existing assessment banks

## Install

Checkpoint the verified Weeks 13–17 batch:

```bash
git add .
git commit -m "Add Grade 1 Math Weeks 13 through 17 production curriculum"
git push
```

Copy the extracted update into the project:

```bash
cp -R ~/Downloads/homeschool-tracker-grade1-math-weeks18-22-update/. .
```

Validate:

```bash
npm run check:starter
npm run typecheck
npm run lint
```

Expected static check:

```text
Migrations: 21
Batch QA: Weeks 18–22 / 25 lessons / 50 online assessment items
Coverage: Q2 mastery + equations/unknowns + repeated-unit length measurement
Mastery policy: no separate hands-on evidence requirement
Starter structure and Weeks 18–22 static checks passed.
```

Dry run:

```bash
npx supabase db push --dry-run
```

Expected pending migration:

```text
20260808011000_grade1_math_weeks18_22_content.sql
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
20260808011000 | 20260808011000
```

## Instructor QA

Confirm five `Published r1` lessons in Weeks 18–22.

Spot-check:
- Week 18 Day 5 — Quarter 2 Mastery Readiness
- Week 19 Day 1 — What the Equals Sign Means
- Week 19 Day 4 — Unknowns in Subtraction
- Week 20 Day 4 — Explain Equation Reasoning
- Week 21 Day 2 — No Gaps, No Overlaps
- Week 22 Day 2 — How Unit Size Changes the Count
- Week 22 Day 4 — Explain a Reliable Measurement

Open Teacher Guide and Answer Key for each spot-check.

Do not artificially advance the real student to test later weeks.
