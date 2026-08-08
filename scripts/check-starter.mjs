import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
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

let failed = false;
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

if (migrations.length !== 17) {
  console.error(`Expected 17 migrations, found ${migrations.length}.`);
  failed = true;
}

const packageJson = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
console.log(`Starter: ${packageJson.name} ${packageJson.version}`);
console.log(`Migrations: ${migrations.length}`);
console.log(migrations.map((m) => `  - ${m}`).join("\n"));

const suspiciousFiles = readdirSync(root).filter(
  (name) => name === ".env.local" || name === ".env.production"
);

if (suspiciousFiles.length) {
  console.error(
    `Secret-bearing environment files should not be shipped: ${suspiciousFiles.join(", ")}`
  );
  failed = true;
}

if (failed) process.exit(1);
console.log("Starter structure check passed.");
