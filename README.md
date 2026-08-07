# Homeschool Tracker

Starter repository for the K–12 homeschool learning and permanent-record system.

## Included now

- Next.js 16 App Router + TypeScript + Tailwind CSS
- Supabase SSR client/server/proxy wiring
- Instructor login screen
- First-time homeschool setup screen
- Instructor dashboard that reads real curriculum counts from Supabase
- Student roster read view
- Student portal placeholder for the next vertical slice
- Database migrations 001–004, including Grade 1 Math 2026.1
- RLS, audit/history protections, curriculum versioning, and permanent-record schema
- Verification SQL for Grade 1 Math

## First local run

```bash
npm install
npm run check:starter
npm run dev
```

Open http://localhost:3000. The app intentionally works in an unconfigured state so you can verify the UI before creating Supabase.

## Do not add secrets yet

`.env.local` is intentionally absent and ignored by Git. When the Supabase project exists, copy:

```bash
cp .env.example .env.local
```

Then fill in:

```text
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=...
```

The publishable key is designed for browser/client use with RLS. Never place a service-role or secret key in a `NEXT_PUBLIC_` variable.

## Database migrations

The real schema history lives in `supabase/migrations/`:

1. `20260807180000_initial_schema.sql`
2. `20260807180100_security_rls.sql`
3. `20260807180200_seed_reference_data.sql`
4. `20260807180300_grade1_math_curriculum.sql`

Do not edit an already-applied migration after the project goes live. Create a new migration for future changes.

## GitHub

This ZIP contains no Supabase credentials or `.env.local`, so after `npm install` and a local review it is safe to initialize Git and push the source repository.

```bash
git init
git add .
git commit -m "Initial homeschool tracker app"
```

We will connect Supabase and Vercel in the next guided steps.
