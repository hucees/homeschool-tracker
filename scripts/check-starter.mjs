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

if (migrations.length !== 19) {
  console.error(`Expected 19 migrations, found ${migrations.length}.`);
  failed = true;
}

const batchName = "20260808009000_grade1_math_weeks8_12_content.sql";
const batchPath = join(migrationDir, batchName);

if (!existsSync(batchPath)) {
  console.error(`Missing batch migration: ${batchName}`);
  failed = true;
} else {
  const sql = readFileSync(batchPath, "utf8");

  for (let week = 8; week <= 12; week++) {
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

  if (/1-MATH-W(?:08|09|10|11|12)-D0[1-5]/.test(sql)) {
    console.error("Found invalid D01–D05 lesson code. Existing skeletons use D1–D5.");
    failed = true;
  }

  const lessonInsertCount = (sql.match(/insert into public\.lesson_content_versions/g) || []).length;
  if (lessonInsertCount !== 25) {
    console.error(`Expected 25 lesson-content inserts, found ${lessonInsertCount}.`);
    failed = true;
  }

  const qCodes = [...sql.matchAll(/1-MATH-W(?:08|09|10|11|12)-Q\d{2}/g)].map(m => m[0]);
  if (new Set(qCodes).size !== 50) {
    console.error(`Expected 50 unique assessment codes, found ${new Set(qCodes).size}.`);
    failed = true;
  }

  if (!sql.includes("for v_week in 8..12 loop")) {
    console.error("Missing Weeks 8–12 preflight loop.");
    failed = true;
  }
}

const pkg = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
console.log(`Starter: ${pkg.name} ${pkg.version}`);
console.log(`Migrations: ${migrations.length}`);
console.log("Batch QA: Weeks 8–12 / 25 lessons / 50 online assessment items");
console.log("Coverage: Q1 spiral review + Q1 mastery + addition within 20 + subtraction intro");

if (failed) process.exit(1);
console.log("Starter structure and Weeks 8–12 static checks passed.");
