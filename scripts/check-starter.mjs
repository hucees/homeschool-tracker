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

if (migrations.length !== 18) {
  console.error(`Expected 18 migrations, found ${migrations.length}.`);
  failed = true;
}

const batchName = "20260808008000_grade1_math_weeks3_7_content.sql";
const batchPath = join(migrationDir, batchName);
if (!existsSync(batchPath)) {
  console.error(`Missing batch migration: ${batchName}`);
  failed = true;
} else {
  const sql = readFileSync(batchPath, "utf8");

  for (let week = 3; week <= 7; week++) {
    const ww = String(week).padStart(2, "0");
    for (let day = 1; day <= 5; day++) {
      const code = `1-MATH-W${ww}-D${day}`;
      if (!sql.includes(code)) {
        console.error(`Missing lesson code in batch migration: ${code}`);
        failed = true;
      }
    }

    for (let q = 1; q <= 10; q++) {
      const qq = String(q).padStart(2, "0");
      const code = `1-MATH-W${ww}-Q${qq}`;
      if (!sql.includes(code)) {
        console.error(`Missing assessment item code: ${code}`);
        failed = true;
      }
    }
  }

  if (/1-MATH-W0[3-7]-D0[1-5]/.test(sql)) {
    console.error("Found invalid zero-padded day code (D01–D05). Existing lesson skeletons use D1–D5.");
    failed = true;
  }

  const questionCodes = [...sql.matchAll(/1-MATH-W0[3-7]-Q\d{2}/g)].map((m) => m[0]);
  const uniqueQuestionCodes = new Set(questionCodes);
  if (uniqueQuestionCodes.size !== 50) {
    console.error(`Expected 50 unique Week 3–7 assessment codes, found ${uniqueQuestionCodes.size}.`);
    failed = true;
  }

  const lessonInsertCount = (sql.match(/insert into public\.lesson_content_versions/g) || []).length;
  if (lessonInsertCount !== 25) {
    console.error(`Expected 25 lesson-content inserts, found ${lessonInsertCount}.`);
    failed = true;
  }
}

const packageJson = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
console.log(`Starter: ${packageJson.name} ${packageJson.version}`);
console.log(`Migrations: ${migrations.length}`);
console.log(`Batch QA: Weeks 3–7 / 25 lessons / 50 online assessment items`);

if (failed) process.exit(1);
console.log("Starter structure and Weeks 3–7 static checks passed.");
