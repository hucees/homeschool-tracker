# Grade 1 Mathematics — Production Batch: Weeks 13–17

## Coverage

### Week 13 — 1-MATH-07 Subtraction Within 20 II
- flexible subtraction strategy use
- choose efficient strategies
- mixed subtraction
- explain subtraction reasoning
- second independent subtraction check

### Week 14 — 1-MATH-08 Fact Fluency Within 10
- efficient addition facts within 10
- efficient subtraction facts within 10
- mixed operation fluency
- derive facts from known facts
- fluency check at the competency's configured **90%** threshold

This week treats fluency as accurate, increasingly efficient recall/derivation.
It does not turn fluency into a speed-only exercise.

### Week 15 — 1-MATH-09 Addition and Subtraction Relationships
- fact families
- use addition to solve subtraction
- use inverse operations to check answers
- parts and whole
- mixed relationship check

### Week 16 — 1-MATH-10 One-Step Word Problems I
- join/result-unknown situations
- separate/result-unknown situations
- choose addition vs subtraction
- identify the unknown and represent the story
- first online word-problem check

### Week 17 — 1-MATH-10 One-Step Word Problems II
- part-part-whole situations
- compare situations
- distinguish all four story structures
- justify equation/model choices
- second online word-problem check

## Package totals

- 25 full production lessons
- 375 guided / independent / worksheet items
- 5 online assessments
- 50 auto-scored assessment items

## Historical safety

Migration 020:
- runs as one transaction
- validates all 25 lesson skeletons before writing
- validates all five Friday templates before writing
- refuses to overwrite published/superseded content
- refuses to rewrite frozen student deliveries
- refuses to overwrite existing question banks

No separate hands-on mastery requirement is introduced. The content supports
models, drawings, and explanations instructionally, while mastery continues to
follow the application's repeated qualifying evidence model.

## Install

Checkpoint the verified Weeks 8–12 batch:

```bash
git add .
git commit -m "Add Grade 1 Math Weeks 8 through 12 production curriculum"
git push
```

Copy the extracted package into the project:

```bash
cp -R ~/Downloads/homeschool-tracker-grade1-math-weeks13-17-update/. .
```

Validate:

```bash
npm run check:starter
npm run typecheck
npm run lint
```

Expected check output:

```text
Migrations: 20
Batch QA: Weeks 13–17 / 25 lessons / 50 online assessment items
Coverage: subtraction II + fact fluency + inverse relationships + word problems
Week 14 mastery threshold preserved: 90%
Starter structure and Weeks 13–17 static checks passed.
```

Dry run:

```bash
npx supabase db push --dry-run
```

Expected only:

```text
20260808010000_grade1_math_weeks13_17_content.sql
```

Push:

```bash
npx supabase db push 2>&1 | tee ~/Desktop/supabase-push-log.txt
```

Verify:

```bash
npx supabase migration list
```

Expected final migration:

```text
20260808010000 | 20260808010000
```

## Instructor QA

Confirm five `Published r1` lessons in each week 13–17.

Spot-check:
- Week 13 Day 4 — Explain Your Subtraction Strategy
- Week 14 Day 4 — Derive Facts Efficiently
- Week 14 Day 5 — Fact Fluency Check
- Week 15 Day 3 — Check with the Inverse Operation
- Week 16 Day 3 — Choose the Operation
- Week 17 Day 2 — Compare Word Problems
- Week 17 Day 4 — Explain Your Word-Problem Model

Open Teacher Guide and Answer Key for each sample.

Do not artificially advance the real student just to test later weeks.
