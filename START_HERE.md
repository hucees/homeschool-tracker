# Start Here

This ZIP is deliberately at the point immediately before cloud setup.

## Right now

1. Unzip the project.
2. Open Terminal in the project directory.
3. Run `npm install`.
4. Run `npm run check:starter`.
5. Run `npm run dev`.
6. Open `http://localhost:3000`.
7. Push the source to a new GitHub repository.

The home page and login page will load even though Supabase is not configured yet.

## What we do together next

1. Create the hosted Supabase project.
2. Initialize/link the Supabase CLI workspace.
3. Apply migrations 001–004 to a blank database.
4. Run the Grade 1 Math verification SQL.
5. Put the Supabase URL and publishable key in `.env.local`.
6. Create the first instructor Auth user.
7. Sign in and run `/setup` to create the homeschool organization and academic year.
8. Confirm the dashboard reads 21 competencies, 36 weeks, and 180 lessons from PostgreSQL.
9. Build Add Student + course assignment + student login + daily Chromebook logging.
10. Deploy the app through GitHub → Vercel.

Do not create `.env.local` with guessed values and do not commit Supabase service-role keys.
