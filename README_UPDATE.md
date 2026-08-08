# Curriculum Authoring + Versioned Lesson Delivery

Migration 015 adds the curriculum-content engine.

## Instructor curriculum studio

Instructor navigation now points to:

`Dashboard → Curriculum`

The curriculum studio shows each course and:
- number of active lessons
- number of published lesson-content revisions
- number of current drafts

Open a course to see all lessons grouped by instructional week.

Open a lesson to author:
- teacher objective
- student-friendly goal
- materials
- vocabulary
- teacher introduction / warm-up
- modeling / direct instruction
- teaching notes
- student Learn content
- guided-practice directions
- independent-practice directions
- activity
- structured guided-practice items
- structured independent-practice items
- worksheet title/directions/items
- correct answers and answer explanations
- completion criteria
- accommodations
- enrichment
- student-safe lesson preview before publishing

## Draft and publish lifecycle

A lesson can have:
- one current Draft
- one current Published revision
- any number of immutable Superseded revisions

Editing a published lesson does not mutate it.

The first Save after publication creates a new draft revision.

Publishing:
1. supersedes the old published revision
2. publishes the current draft
3. leaves old published data immutable

## Student lesson delivery

Student navigation now includes `Lessons`.

For each active course, the student sees the next unfinished lesson.

When a student opens a lesson for the first time:
1. the system finds the current published content revision
2. it creates a `student_lesson_deliveries` record
3. that exact revision is permanently tied to the student's enrollment + lesson

If the instructor later publishes revision 2, a student who was already
delivered revision 1 continues to see revision 1.

This prevents curriculum edits from silently rewriting instructional history.

Students never receive:
- teacher introduction
- teacher modeling
- teaching notes
- accommodations
- enrichment
- student-safe lesson preview before publishing
- correct answers
- answer explanations

Students receive:
- goal
- materials
- vocabulary
- Learn content
- guided practice
- independent practice
- activity
- worksheet
- completion criteria
- item prompts / hints only

## Current safe test

No actual lesson content is seeded by this migration.

After installing:

Instructor:
1. Open Curriculum.
2. Open Grade 1 Mathematics.
3. Open Week 1 Day 1.
4. Verify the authoring interface loads.
5. You can save a small temporary Draft safely.
6. Do not Publish temporary filler content if you do not want the student to receive it.

Student:
1. Open Lessons.
2. Grade 1 Math should show the next unfinished lesson.
3. Open it.
4. Until content is published, the page should say `Content pending`.
5. The student can still record lesson completion using the existing academic-work system.

## Next step

After this infrastructure passes, build Grade 1 Math Week 1 as real curriculum:
- five complete lesson revisions
- teacher guides
- student content
- guided practice
- independent practice
- worksheets + answer keys
- existing Week 1 online assessment

That first week becomes the production template for the remaining 35 weeks.

## Install

1. Commit/push the working Year Closeout + Diploma feature first.
2. Stop the dev server if desired.
3. Copy this update into the project.
4. Run:
   - `npm run check:starter`
   - `npm run typecheck`
   - `npm run lint`
5. `npx supabase db push --dry-run`
6. Confirm only `20260808005000_curriculum_authoring_delivery.sql` is pending.
7. `npx supabase db push`
8. Restart `npm run dev`
