import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const root=process.cwd();
let failed=false;

const required=[
  "package.json",".env.example",
  "src/app/dashboard/curriculum/page.tsx",
  "src/app/dashboard/curriculum/lessons/[lessonId]/page.tsx",
  "src/app/dashboard/curriculum/lessons/[lessonId]/guide/page.tsx",
  "src/app/dashboard/curriculum/lessons/[lessonId]/worksheet/page.tsx",
  "src/app/student/lessons/[enrollmentId]/[lessonId]/page.tsx",
  "src/app/student/lessons/[enrollmentId]/[lessonId]/worksheet/page.tsx",
  "src/components/teacher-lesson-guide.tsx",
  "src/components/lesson-content-view.tsx",
  "src/lib/lesson-content.ts","supabase/migrations"
];

for (const p of required) if (!existsSync(join(root,p))) {
  console.error(`Missing required starter file: ${p}`); failed=true;
}

const dir=join(root,"supabase/migrations");
const migrations=existsSync(dir)?readdirSync(dir).filter(f=>f.endsWith(".sql")).sort():[];
if (migrations.length!==22) {
  console.error(`Expected 22 migrations, found ${migrations.length}.`); failed=true;
}

const name="20260808012000_grade1_math_weeks23_27_content.sql";
const path=join(dir,name);
if (!existsSync(path)) {
  console.error(`Missing batch migration: ${name}`); failed=true;
} else {
  const sql=readFileSync(path,"utf8");
  for (let w=23;w<=27;w++) {
    const ww=String(w).padStart(2,"0");
    for (let d=1;d<=5;d++) {
      const c=`1-MATH-W${ww}-D${d}`;
      if (!sql.includes(c)) { console.error(`Missing lesson code: ${c}`); failed=true; }
    }
    for (let q=1;q<=10;q++) {
      const qq=String(q).padStart(2,"0");
      const c=`1-MATH-W${ww}-Q${qq}`;
      if (!sql.includes(c)) { console.error(`Missing assessment item: ${c}`); failed=true; }
    }
  }
  if (/1-MATH-W(?:23|24|25|26|27)-D0[1-5]/.test(sql)) {
    console.error("Found invalid D01–D05 lesson code."); failed=true;
  }
  const lc=(sql.match(/insert into public\.lesson_content_versions/g)||[]).length;
  if (lc!==25) { console.error(`Expected 25 lesson-content inserts, found ${lc}.`); failed=true; }
  const qs=[...sql.matchAll(/1-MATH-W(?:23|24|25|26|27)-Q\d{2}/g)].map(m=>m[0]);
  if (new Set(qs).size!==50) {
    console.error(`Expected 50 unique assessment codes, found ${new Set(qs).size}.`); failed=true;
  }
  if (!sql.includes("for v_week in 23..27 loop")) {
    console.error("Missing Weeks 23–27 preflight loop."); failed=true;
  }
  if (!sql.includes("no separate hands-on mastery evidence requirement")) {
    console.error("Mastery policy marker missing."); failed=true;
  }
}
const pkg=JSON.parse(readFileSync(join(root,"package.json"),"utf8"));
console.log(`Starter: ${pkg.name} ${pkg.version}`);
console.log(`Migrations: ${migrations.length}`);
console.log("Batch QA: Weeks 23–27 / 25 lessons / 50 online assessment items");
console.log("Coverage: compare/order lengths + hour/half-hour time + Q3 mastery");
console.log("Mastery policy: no separate hands-on evidence requirement");
if (failed) process.exit(1);
console.log("Starter structure and Weeks 23–27 static checks passed.");
