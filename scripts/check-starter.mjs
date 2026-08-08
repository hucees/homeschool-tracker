import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const required = [
  "package.json",
  ".env.example",
  "src/app/page.tsx",
  "src/app/login/page.tsx",
  "src/app/dashboard/page.tsx",
  "src/app/dashboard/daily/page.tsx",
  "src/app/dashboard/students/[studentId]/gradebook/page.tsx",
  "src/app/dashboard/students/[studentId]/progress/page.tsx",
  "src/app/dashboard/students/[studentId]/courses/[enrollmentId]/page.tsx",
  "src/app/dashboard/students/[studentId]/reports/[reportId]/page.tsx",
  "src/app/student/page.tsx",
  "src/app/student/progress/page.tsx",
  "src/app/student/reports/[reportId]/page.tsx",
  "src/app/student/assessments/[assignmentId]/page.tsx",
  "src/components/student-shell.tsx",
  "src/components/progress-report-document.tsx",
  "src/lib/student-progress.ts",
  "src/lib/supabase/server.ts",
  "src/proxy.ts",
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

if (migrations.length !== 12) {
  console.error(`Expected 12 migrations, found ${migrations.length}.`);
  failed = true;
}

const packageJson = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
console.log(`Starter: ${packageJson.name} ${packageJson.version}`);
console.log(`Migrations: ${migrations.length}`);
console.log(migrations.map((m) => `  - ${m}`).join("\n"));

const suspiciousFiles = readdirSync(root).filter((name) => name === ".env.local" || name === ".env.production");
if (suspiciousFiles.length) {
  console.error(`Secret-bearing environment files should not be shipped: ${suspiciousFiles.join(", ")}`);
  failed = true;
}

if (failed) process.exit(1);
console.log("Starter structure check passed.");
