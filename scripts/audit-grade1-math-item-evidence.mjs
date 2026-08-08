import { createClient } from "@supabase/supabase-js";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

function load(path) {
  if (!existsSync(path)) return;
  for (const raw of readFileSync(path, "utf8").split(/\r?\n/)) {
    let line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    if (line.startsWith("export ")) line = line.slice(7).trim();
    const i = line.indexOf("=");
    if (i < 1) continue;
    const key = line.slice(0,i).trim();
    let val = line.slice(i+1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) val = val.slice(1,-1);
    if (!(key in process.env)) process.env[key] = val;
  }
}
load(join(process.cwd(), ".env.local"));
load(join(process.cwd(), ".env"));

const url = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error("Missing Supabase URL or server-side secret environment variable.");
  process.exit(2);
}
const sb = createClient(url, key, {auth:{persistSession:false,autoRefreshToken:false}});

async function must(table, select, apply = q => q) {
  const {data,error} = await apply(sb.from(table).select(select));
  if (error) throw new Error(`${table}: ${error.message}`);
  return data ?? [];
}

const release = (await must("curriculum_releases","id",q=>q.eq("version","2026.1")))[0];
if (!release) throw new Error("Release 2026.1 not found.");

const cv = (await must("course_versions","id",q=>q.eq("curriculum_release_id",release.id).eq("course_code","1-MATH")))[0];
if (!cv) throw new Error("Grade 1 Math 2026.1 course version not found.");

const templates = await must("assignment_templates","id,code,sequence",q=>q.eq("course_version_id",cv.id));
const templateIds = templates.map(x=>x.id);

const items = [];
for (let i=0;i<templateIds.length;i+=25) {
  items.push(...await must("assessment_template_items","id,assignment_template_id,code,points",q=>q.in("assignment_template_id",templateIds.slice(i,i+25))));
}
const itemIds = items.map(x=>x.id);

const maps = [];
for (let i=0;i<itemIds.length;i+=50) {
  maps.push(...await must("assessment_template_item_competencies","assessment_template_item_id,competency_id",q=>q.in("assessment_template_item_id",itemIds.slice(i,i+50))));
}

const byItem = new Map();
for (const m of maps) {
  if (!byItem.has(m.assessment_template_item_id)) byItem.set(m.assessment_template_item_id, []);
  byItem.get(m.assessment_template_item_id).push(m.competency_id);
}

const unmapped = items.filter(i => !(byItem.get(i.id)?.length));
let fail = 0;
console.log("============================================================");
console.log(" GRADE 1 MATH — ITEM-LEVEL EVIDENCE LIVE AUDIT");
console.log("============================================================");

if (items.length === 360) console.log("✓ PASS  Found all 360 online assessment items.");
else { console.log(`✗ FAIL  Expected 360 online items; found ${items.length}.`); fail++; }

if (unmapped.length === 0) console.log("✓ PASS  Every online assessment item has at least one competency tag.");
else { console.log(`✗ FAIL  ${unmapped.length} online assessment item(s) have no competency tag.`); fail++; }

for (const week of [8,9,18,27,36]) {
  const prefix = `1-MATH-W${String(week).padStart(2,"0")}-Q`;
  const rows = items.filter(i=>i.code.startsWith(prefix));
  const mapped = rows.filter(i=>(byItem.get(i.id)?.length ?? 0)>0);
  if (rows.length === 10 && mapped.length === 10) {
    console.log(`✓ PASS  Week ${week} multi-competency assessment has item-level coverage for all 10 questions.`);
  } else {
    console.log(`✗ FAIL  Week ${week} mapping coverage is ${mapped.length}/${rows.length}.`);
    fail++;
  }
}

const studentItems = await must(
  "student_assignment_items",
  "id,student_assignment_id",
  q=>q
);
if (studentItems.length) {
  const studentItemIds = studentItems.map(x=>x.id);
  const studentMaps = [];
  for (let i=0;i<studentItemIds.length;i+=50) {
    studentMaps.push(...await must(
      "student_assignment_item_competencies",
      "student_assignment_item_id,competency_id",
      q=>q.in("student_assignment_item_id",studentItemIds.slice(i,i+50))
    ));
  }
  const mappedStudentIds = new Set(studentMaps.map(x=>x.student_assignment_item_id));
  const missing = studentItems.filter(x=>!mappedStudentIds.has(x.id));
  if (!missing.length) console.log(`✓ PASS  All ${studentItems.length} existing frozen student assessment item(s) have frozen competency tags.`);
  else { console.log(`✗ FAIL  ${missing.length} frozen student item(s) are missing competency tags.`); fail++; }
} else {
  console.log("✓ PASS  No existing frozen student assessment items require backfill.");
}

console.log("------------------------------------------------------------");
if (fail) {
  console.log(`RESULT: NOT READY — ${fail} item-level evidence check(s) failed.`);
  process.exit(1);
}
console.log("RESULT: ITEM-LEVEL COMPETENCY EVIDENCE READY.");
