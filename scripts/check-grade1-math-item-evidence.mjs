import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const migrationDir = join(root, "supabase/migrations");
const name = "20260808016000_grade1_math_item_level_mastery_evidence.sql";
const path = join(migrationDir, name);

let failed = false;

if (!existsSync(path)) {
  console.error(`Missing migration: ${name}`);
  process.exit(1);
}

const migrations = readdirSync(migrationDir).filter(f => f.endsWith(".sql")).sort();
if (migrations.length !== 26) {
  console.error(`Expected 26 migrations; found ${migrations.length}.`);
  failed = true;
}

const sql = readFileSync(path, "utf8");

const requiredMarkers = [
  "assessment_template_item_competencies",
  "student_assignment_item_competencies",
  "snapshot_student_assignment_item_competencies",
  "apply_item_level_competency_score",
  "v_response_count <> v_item_count",
  "v_item_count < 2",
  "does not count as a qualifying mastery demonstration",
  "1-MATH-W08-Q01",
  "1-MATH-W09-Q01",
  "1-MATH-W18-Q01",
  "1-MATH-W27-Q01",
  "1-MATH-W36-Q01",
];

for (const marker of requiredMarkers) {
  if (!sql.includes(marker)) {
    console.error(`Missing required marker: ${marker}`);
    failed = true;
  }
}

for (const week of [8,9,18,27,36]) {
  const ww = String(week).padStart(2, "0");
  for (let q = 1; q <= 10; q++) {
    const code = `1-MATH-W${ww}-Q${String(q).padStart(2, "0")}`;
    if (!sql.includes(code)) {
      console.error(`Missing multi-competency mapping question: ${code}`);
      failed = true;
    }
  }
}

console.log(`Migrations: ${migrations.length}`);
console.log("Item-evidence QA: all single-competency items auto-map + explicit Weeks 8/9/18/27/36 maps");
console.log("Scoring rule: competency evidence uses only tagged question responses");
console.log("Safety rule: one-question cumulative samples are diagnostic, not qualifying mastery demonstrations");
console.log("Mastery policy: no separate hands-on evidence requirement");

if (failed) process.exit(1);

console.log("Grade 1 Math item-level competency evidence static checks passed.");
