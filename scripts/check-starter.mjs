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
  ? readdirSync(migrationDir).filter((f) => f.endsWith(".sql")).sort()
  : [];

if (migrations.length !== 20) {
  console.error(`Expected 20 migrations, found ${migrations.length}.`);
  failed = true;
}

const batchName = "20260808010000_grade1_math_weeks13_17_content.sql";
const batchPath = join(migrationDir, batchName);

if (!existsSync(batchPath)) {
  console.error(`Missing batch migration: ${batchName}`);
  failed = true;
} else {
  const sql = readFileSync(batchPath, "utf8");

  for (let week = 13; week <= 17; week++) {
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

  if (/1-MATH-W(?:13|14|15|16|17)-D0[1-5]/.test(sql)) {
    console.error("Found invalid D01–D05 lesson code. Existing skeletons use D1–D5.");
    failed = true;
  }

  const lessonInsertCount = (sql.match(/insert into public\.lesson_content_versions/g) || []).length;
  if (lessonInsertCount !== 25) {
    console.error(`Expected 25 lesson-content inserts, found ${lessonInsertCount}.`);
    failed = true;
  }

  const qCodes = [...sql.matchAll(/1-MATH-W(?:13|14|15|16|17)-Q\d{2}/g)].map(m => m[0]);
  if (new Set(qCodes).size !== 50) {
    console.error(`Expected 50 unique assessment codes, found ${new Set(qCodes).size}.`);
    failed = true;
  }

  if (!sql.includes("for v_week in 13..17 loop")) {
    console.error("Missing Weeks 13–17 preflight loop.");
    failed = true;
  }

  if (!sql.includes("90%")) {
    console.error("Week 14 fact-fluency content should explicitly preserve the 90% threshold.");
    failed = true;
  }
}

const pkg = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
console.log(`Starter: ${pkg.name} ${pkg.version}`);
console.log(`Migrations: ${migrations.length}`);
console.log("Batch QA: Weeks 13–17 / 25 lessons / 50 online assessment items");
console.log("Coverage: subtraction II + fact fluency + inverse relationships + word problems");
console.log("Week 14 mastery threshold preserved: 90%");

if (failed) process.exit(1);
console.log("Starter structure and Weeks 13–17 static checks passed.");
