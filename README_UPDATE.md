# Progress Dashboard + Official Reports

Migration 010 and the accompanying UI add the first reporting layer.

## Live student progress

Student record → Progress & reports now shows:

- official grade placement and academic year
- confirmed attendance
- instructional minutes
- each enrolled course
- current course week
- lessons completed / total lessons
- lesson completion percentage
- report-period weighted grade
- letter grade
- graded assessment count
- competency totals:
  - Mastered
  - Proficient
  - Practicing
  - Needs review
  - Not started
- expandable competency detail

The competency calculation intentionally matches the gradebook behavior already
approved for this project: repeated qualifying demonstrations can satisfy the
configured mastery count.

## Official report snapshots

The instructor can select:

- Progress Report
- Quarter Report
- Semester Report
- Annual Report
- Attendance Report
- Competency Report

and choose a start/end date within the student's academic-year placement.

Teacher comments are optional.

Clicking "Generate official report":

1. recalculates the selected reporting period from permanent source records
2. freezes that exact data into `report_snapshots`
3. assigns the next permanent report version
4. stores a SHA-256 hash of the JSON snapshot
5. marks the snapshot `official`
6. redirects to a print-friendly official report

Official snapshots cannot be edited or deleted. A future void workflow may mark
one voided without changing the original data.

## Printing / PDF

The report viewer includes "Print / Save PDF", which uses the browser's print
dialog. On macOS, choose Save as PDF to create a local PDF copy of that exact
official report.

## Install

1. Copy the update into the current project.
2. `npm run check:starter`
3. `npm run typecheck`
4. `npm run lint`
5. `npx supabase db push --dry-run`
6. Confirm only `20260808000000_progress_reports.sql` is pending.
7. `npx supabase db push`
8. Restart `npm run dev`
9. Instructor → Students → student → View progress
