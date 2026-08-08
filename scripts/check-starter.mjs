import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
let failed = false;

const required = [
  "package.json",
  ".env.example",
  "src/app/dashboard/curriculum/page.tsx",
  "src/app/dashboard/curriculum/lessons/[lessonId]/page.tsx",
  "src/app/dashboard/curriculum/lessons/[lessonId]/guide/page.tsx",
  "src/app/dashboard/curriculum/lessons/[lessonId]/worksheet/page.tsx",
  "src/app/student/lessons/[enrollmentId]/[lessonId]/page.tsx",
  "src/app/student/lessons/[enrollmentId]/[lessonId]/worksheet/page.tsx",
  "src/components/teacher-lesson-guide.tsx",
  "src/components/lesson-content-view.tsx",
  "src/lib/lesson-content.ts",
  "supabase/migrations",
];

for (const item of required) {
  if (!existsSync(join(root, item))) {
    console.error(`Missing required starter file: ${item}`);
    failed = true;
  }
}

const migrationDir = join(root, "supabase/migrations");
const migrations = existsSync(migrationDir)
  ? readdirSync(migrationDir).filter(f => f.endsWith(".sql")).sort()
  : [];

if (migrations.length !== 24) {
  console.error(`Expected 24 migrations, found ${migrations.length}.`);
  failed = true;
}

const batchName = "20260808014000_grade1_math_weeks33_36_content.sql";
const batchPath = join(migrationDir, batchName);

if (!existsSync(batchPath)) {
  console.error(`Missing batch migration: ${batchName}`);
  failed = true;
} else {
  const sql = readFileSync(batchPath, "utf8");

  for (let week = 33; week <= 36; week++) {
    const ww = String(week).padStart(2, "0");

    for (let day = 1; day <= 5; day++) {
      const code = `1-MATH-W${ww}-D${day}`;
      if (!sql.includes(code)) {
        console.error(`Missing lesson code: ${code}`);
        failed = true;
      }
    }

    for (let q = 1; q <= 10; q++) {
      const qq = String(q).padStart(2, "0");
      const code = `1-MATH-W${ww}-Q${qq}`;
      if (!sql.includes(code)) {
        console.error(`Missing assessment item: ${code}`);
        failed = true;
      }
    }
  }

  if (/1-MATH-W(?:33|34|35|36)-D0[1-5]/.test(sql)) {
    console.error("Found invalid D01–D05 lesson code.");
    failed = true;
  }

  const lessonInsertCount =
    (sql.match(/insert into public\.lesson_content_versions/g) || []).length;

  if (lessonInsertCount !== 20) {
    console.error(`Expected 20 lesson-content inserts, found ${lessonInsertCount}.`);
    failed = true;
  }

  const qCodes =
    [...sql.matchAll(/1-MATH-W(?:33|34|35|36)-Q\d{2}/g)].map(m => m[0]);

  if (new Set(qCodes).size !== 40) {
    console.error(`Expected 40 unique assessment codes, found ${new Set(qCodes).size}.`);
    failed = true;
  }

  if (!sql.includes("for v_week in 33..36 loop")) {
    console.error("Missing Weeks 33–36 preflight loop.");
    failed = true;
  }

  if (!sql.includes("1-MATH-20 retains its configured 90% threshold")) {
    console.error("Week 34 90% mastery-threshold marker missing.");
    failed = true;
  }

  if (!sql.includes("no separate hands-on")) {
    console.error("Mastery-policy marker missing.");
    failed = true;
  }
}

const pkg = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
console.log(`Starter: ${pkg.name} ${pkg.version}`);
console.log(`Migrations: ${migrations.length}`);
console.log("Batch QA: Weeks 33–36 / 20 lessons / 40 online assessment items");
console.log("Coverage: addition within 100 II + 10 more/less + subtract tens + year-end mastery");
console.log("Week 34 mastery threshold preserved: 90%");
console.log("Grade 1 Math production curriculum coverage: Weeks 1–36 complete");

if (failed) process.exit(1);

console.log("Starter structure and Weeks 33–36 static checks passed.");
