import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const migrationDir = join(root, "supabase/migrations");
const name = "20260808015000_grade1_math_mastery_points_fix.sql";
const path = join(migrationDir, name);

let failed = false;

if (!existsSync(path)) {
  console.error(`Missing migration: ${name}`);
  process.exit(1);
}

const migrations = readdirSync(migrationDir)
  .filter(f => f.endsWith(".sql"))
  .sort();

if (migrations.length !== 25) {
  console.error(`Expected 25 migrations after the audit fix; found ${migrations.length}.`);
  failed = true;
}

const sql = readFileSync(path, "utf8");

for (const code of [
  "1-MATH-Q1-MASTERY",
  "1-MATH-Q2-MASTERY",
  "1-MATH-Q3-MASTERY",
  "1-MATH-Q4-MASTERY",
]) {
  if (!sql.includes(code)) {
    console.error(`Missing mastery template code: ${code}`);
    failed = true;
  }
}

for (const marker of [
  "count(ati.id) <> 10",
  "coalesce(sum(ati.points), 0) <> 10",
  "public.grade_records",
  "update public.student_assignments",
  "update public.assignment_templates",
  "max_points = 10",
  "postcondition",
]) {
  if (!sql.includes(marker)) {
    console.error(`Missing safety/fix marker: ${marker}`);
    failed = true;
  }
}

console.log(`Migrations: ${migrations.length}`);
console.log("Fix QA: 4 quarterly mastery templates");
console.log("Expected question-bank scale: 10 items / 10 points");
console.log("Historical policy: refuses to rewrite already-graded student mastery assignments");

if (failed) process.exit(1);

console.log("Grade 1 Math mastery-points fix static checks passed.");
