# Student Reports + Responsive UI Refresh

This update finishes the reporting feature for students and refreshes the shared
visual system. It does not add a database migration.

## Student reporting

Students now have:

- `Progress & reports` navigation in the student portal
- a live Current Progress Report generated from their own latest records
- confirmed attendance totals
- instructional minutes
- course grades
- lesson completion
- competency progress
- Print / Save PDF
- a list of their own instructor-issued official reports
- read-only access to each official report
- Print / Save PDF for official reports

The live report is explicitly marked `Unofficial · live` and does not create a
permanent report snapshot.

Only an instructor can create an `official` frozen snapshot.

Existing RLS already permits a student to SELECT only their own report snapshot
when its status is `official`, so no broader database access was added.

## Responsive UI refresh

Shared UI now uses a calmer teal/blue academic palette with stronger text
contrast and softer warm surfaces.

Instructor:
- sticky header
- mobile horizontal navigation instead of a cramped sidebar
- desktop sticky sidebar
- responsive content width and spacing
- better touch targets

Student:
- reusable sticky student header
- School work / Progress & reports navigation
- mobile-first cards and forms
- full-width primary buttons on narrow screens
- two-column layouts only when enough width is available

Reports:
- one shared report renderer for instructor and student
- improved phone/tablet layouts
- clearer attendance and academic sections
- responsive competency rows
- print-specific styling
- official vs unofficial status is visually obvious

## Install

No Supabase migration is required.

1. Stop `npm run dev` if that is your normal workflow.
2. Copy this update into the existing project.
3. `npm run check:starter`
4. `npm run typecheck`
5. `npm run lint`
6. Restart `npm run dev`

## Test

Student:
1. Sign in.
2. Confirm the new `Progress & reports` navigation.
3. Open `View / Save current report`.
4. Confirm it says `Unofficial · live`.
5. Use Print / Save PDF.
6. Open an existing official report.
7. Confirm it says `Official`, shows the version and SHA-256, and can be saved as PDF.

Instructor:
1. Confirm the top/mobile navigation is readable.
2. Open an existing official report.
3. Confirm it uses the refreshed report layout.
