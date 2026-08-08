# Grade 1 Math — Item-Level Competency Evidence Fix

This is Migration 026.

## What it fixes

The current grade functions correctly preserve grades and evidence history, but a
multi-competency assessment currently gives every linked competency the same
overall percentage.

That affects:
- Week 8 Quarter 1 spiral review
- Week 9 Quarter 1 mastery
- Week 18 Quarter 2 mastery
- Week 27 Quarter 3 mastery
- Week 36 Quarter 4 / year-end mastery

Migration 026 tags each online question to the competency or competencies it
actually measures.

Future competency evidence is then calculated only from the student's answers to
the questions tagged to that competency.

## Important mastery safeguard

If a cumulative test contains only **one** tagged question for a competency, that
result is stored as diagnostic evidence and cannot become a qualifying mastery
demonstration by itself.

This matters especially in the broad Week 36 year-end assessment.

Weekly 10-question competency checks remain the stronger evidence source.

There is still **no separate hands-on evidence requirement**.

## Historical safety

- Existing grade records are not changed.
- Existing competency evidence is not rewritten.
- Existing frozen student assessment questions receive frozen competency tags.
- Future frozen questions automatically snapshot the tags.
- Question mappings are protected by the curriculum-release immutability system.

## Install

```bash
cp -R ~/Downloads/homeschool-tracker-grade1-math-item-level-evidence/. .
```

Static check:

```bash
node scripts/check-grade1-math-item-evidence.mjs
```

Expected:

```text
Migrations: 26
Item-evidence QA: all single-competency items auto-map + explicit Weeks 8/9/18/27/36 maps
Scoring rule: competency evidence uses only tagged question responses
Safety rule: one-question cumulative samples are diagnostic, not qualifying mastery demonstrations
Mastery policy: no separate hands-on evidence requirement
Grade 1 Math item-level competency evidence static checks passed.
```

Then:

```bash
npm run typecheck
npm run lint
npx supabase db push --dry-run
```

Expected pending migration:

```text
20260808016000_grade1_math_item_level_mastery_evidence.sql
```

After the real push, run:

```bash
node scripts/audit-grade1-math-item-evidence.mjs
```

## About the remaining draft warning

Do **not** publish the shared `Homeschool Curriculum 2026.1` release just to clear
the Grade 1 Math audit warning. Other 2026.1 courses still need to be authored.

Grade 1 Math can be treated as curriculum-complete and QA-complete while the
parent release remains draft.
