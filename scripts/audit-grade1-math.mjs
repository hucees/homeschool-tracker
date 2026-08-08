import { createClient } from "@supabase/supabase-js";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

function loadEnvFile(path) {
  if (!existsSync(path)) return;
  const text = readFileSync(path, "utf8");
  for (const rawLine of text.split(/\r?\n/)) {
    let line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    if (line.startsWith("export ")) line = line.slice(7).trim();
    const eq = line.indexOf("=");
    if (eq <= 0) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = value;
  }
}

loadEnvFile(join(process.cwd(), ".env.local"));
loadEnvFile(join(process.cwd(), ".env"));

const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL ||
  process.env.SUPABASE_URL;

const SUPABASE_SECRET =
  process.env.SUPABASE_SECRET_KEY ||
  process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL) {
  console.error("AUDIT ERROR: NEXT_PUBLIC_SUPABASE_URL or SUPABASE_URL is missing.");
  process.exit(2);
}
if (!SUPABASE_SECRET) {
  console.error("AUDIT ERROR: SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY is missing.");
  console.error("The audit is read-only and never prints the secret.");
  process.exit(2);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SECRET, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const EXPECTED_WEEKS = [
  [1,1,"Numbers to 120",["1-MATH-01"],"teach",false],
  [2,1,"Counting Forward and Backward",["1-MATH-02"],"teach",false],
  [3,1,"Counting Patterns by 2s, 5s, and 10s",["1-MATH-03"],"teach",false],
  [4,1,"Tens and Ones I",["1-MATH-04"],"teach",false],
  [5,1,"Tens and Ones II",["1-MATH-04"],"continue",false],
  [6,1,"Comparing Two-Digit Numbers I",["1-MATH-05"],"teach",false],
  [7,1,"Comparing Two-Digit Numbers II",["1-MATH-05"],"continue",false],
  [8,1,"Quarter 1 Spiral Review",["1-MATH-01","1-MATH-02","1-MATH-03","1-MATH-04","1-MATH-05"],"review",false],
  [9,1,"Quarter 1 Mastery Check",["1-MATH-01","1-MATH-02","1-MATH-03","1-MATH-04","1-MATH-05"],"mastery",true],
  [10,2,"Addition Within 20 I",["1-MATH-06"],"teach",false],
  [11,2,"Addition Within 20 II",["1-MATH-06"],"continue",false],
  [12,2,"Subtraction Within 20 I",["1-MATH-07"],"teach",false],
  [13,2,"Subtraction Within 20 II",["1-MATH-07"],"continue",false],
  [14,2,"Fact Fluency Within 10",["1-MATH-08"],"teach",false],
  [15,2,"Addition and Subtraction Relationships",["1-MATH-09"],"teach",false],
  [16,2,"One-Step Word Problems I",["1-MATH-10"],"teach",false],
  [17,2,"One-Step Word Problems II",["1-MATH-10"],"continue",false],
  [18,2,"Quarter 2 Mastery Check",["1-MATH-06","1-MATH-07","1-MATH-08","1-MATH-09","1-MATH-10"],"mastery",true],
  [19,3,"Equations and Unknowns I",["1-MATH-11"],"teach",false],
  [20,3,"Equations and Unknowns II",["1-MATH-11"],"continue",false],
  [21,3,"Measuring Length I",["1-MATH-12"],"teach",false],
  [22,3,"Measuring Length II",["1-MATH-12"],"continue",false],
  [23,3,"Comparing and Ordering Lengths",["1-MATH-13"],"teach",false],
  [24,3,"Time to the Hour and Half-Hour I",["1-MATH-14"],"teach",false],
  [25,3,"Time to the Hour and Half-Hour II",["1-MATH-14"],"continue",false],
  [26,3,"Time Application and Review",["1-MATH-14"],"continue",false],
  [27,3,"Quarter 3 Mastery Check",["1-MATH-11","1-MATH-12","1-MATH-13","1-MATH-14"],"mastery",true],
  [28,4,"Organizing and Interpreting Data",["1-MATH-15"],"teach",false],
  [29,4,"Representing Data",["1-MATH-16"],"teach",false],
  [30,4,"2D and 3D Shapes",["1-MATH-17"],"teach",false],
  [31,4,"Halves and Fourths",["1-MATH-18"],"teach",false],
  [32,4,"Adding Within 100 I",["1-MATH-19"],"teach",false],
  [33,4,"Adding Within 100 II",["1-MATH-19"],"continue",false],
  [34,4,"Ten More and Ten Less",["1-MATH-20"],"teach",false],
  [35,4,"Subtracting Multiples of 10",["1-MATH-21"],"teach",false],
  [36,4,"Quarter 4 and Year-End Mastery Check",["1-MATH-15","1-MATH-16","1-MATH-17","1-MATH-18","1-MATH-19","1-MATH-20","1-MATH-21"],"mastery",true],
];

const EXPECTED_THRESHOLDS = new Map(
  Array.from({ length: 21 }, (_, i) => [
    `1-MATH-${String(i + 1).padStart(2, "0")}`,
    (i + 1 === 8 || i + 1 === 20) ? 90 : 85,
  ])
);

const EXPECTED_DAY_TYPES = new Map([
  [1, "instruction"],
  [2, "guided_practice"],
  [3, "independent_practice"],
  [4, "application"],
  [5, "assessment"],
]);

const report = {
  generated_at: new Date().toISOString(),
  course: "1-MATH",
  release: "2026.1",
  summary: { pass: 0, warn: 0, fail: 0 },
  checks: [],
  details: {},
};

function addCheck(level, name, message, detail = undefined) {
  const key = level.toLowerCase();
  report.summary[key]++;
  report.checks.push({ level, name, message, ...(detail === undefined ? {} : { detail }) });
}

function pass(name, message, detail) { addCheck("PASS", name, message, detail); }
function warn(name, message, detail) { addCheck("WARN", name, message, detail); }
function fail(name, message, detail) { addCheck("FAIL", name, message, detail); }

function sorted(arr) {
  return [...arr].sort((a,b) => String(a).localeCompare(String(b)));
}

function sameSet(a, b) {
  const aa = sorted(a);
  const bb = sorted(b);
  return aa.length === bb.length && aa.every((v, i) => v === bb[i]);
}

function groupBy(rows, keyFn) {
  const m = new Map();
  for (const row of rows) {
    const key = keyFn(row);
    if (!m.has(key)) m.set(key, []);
    m.get(key).push(row);
  }
  return m;
}

async function q(table, select, configure = (x) => x) {
  let query = supabase.from(table).select(select);
  query = configure(query);
  const { data, error } = await query;
  if (error) throw new Error(`${table}: ${error.message}`);
  return data ?? [];
}

async function fetchInChunks(table, select, column, ids, chunkSize = 50) {
  const out = [];
  for (let i = 0; i < ids.length; i += chunkSize) {
    const chunk = ids.slice(i, i + chunkSize);
    const rows = await q(table, select, x => x.in(column, chunk));
    out.push(...rows);
  }
  return out;
}

async function main() {
  // -------------------------------------------------------------------------
  // Resolve release + course version
  // -------------------------------------------------------------------------
  const releases = await q(
    "curriculum_releases",
    "id,organization_id,version,name,status",
    x => x.eq("version", "2026.1")
  );

  if (releases.length === 0) {
    fail("release.exists", "Curriculum release 2026.1 was not found.");
    return finish();
  }

  const releaseIds = releases.map(r => r.id);
  const courseVersions = await q(
    "course_versions",
    "id,organization_id,curriculum_release_id,course_code,title,instructional_weeks,recommended_minutes_per_week,status",
    x => x.eq("course_code", "1-MATH").in("curriculum_release_id", releaseIds)
  );

  if (courseVersions.length !== 1) {
    fail(
      "course.unique",
      `Expected exactly one 1-MATH course version in release 2026.1; found ${courseVersions.length}.`,
      courseVersions.map(c => ({ id: c.id, organization_id: c.organization_id, title: c.title }))
    );
    return finish();
  }

  const cv = courseVersions[0];
  const release = releases.find(r => r.id === cv.curriculum_release_id);
  const courseVersionId = cv.id;
  const orgId = cv.organization_id;

  report.details.course_version = {
    id: courseVersionId,
    organization_id: orgId,
    title: cv.title,
    status: cv.status,
    release_status: release?.status ?? null,
  };

  pass("course.exists", `Found ${cv.title}.`);

  if (Number(cv.instructional_weeks) === 36) {
    pass("course.weeks_config", "Course is configured for 36 instructional weeks.");
  } else {
    fail("course.weeks_config", `Expected instructional_weeks=36; found ${cv.instructional_weeks}.`);
  }

  if (Number(cv.recommended_minutes_per_week) === 150) {
    pass("course.minutes", "Course is configured for 150 recommended minutes per week.");
  } else {
    warn("course.minutes", `Expected 150 recommended minutes/week; found ${cv.recommended_minutes_per_week}.`);
  }

  if (release?.status === "draft" || cv.status === "draft") {
    warn(
      "course.release_status",
      `Course/release is still draft (course=${cv.status}, release=${release?.status ?? "unknown"}). This is acceptable during authoring but not a final locked release.`
    );
  } else {
    pass("course.release_status", `Course/release status: course=${cv.status}, release=${release?.status}.`);
  }

  // -------------------------------------------------------------------------
  // Units / competencies / weeks / lessons
  // -------------------------------------------------------------------------
  const [units, competencies, weeks, lessons] = await Promise.all([
    q("units", "id,code,title,sequence,quarter", x => x.eq("course_version_id", courseVersionId).order("sequence")),
    q("competencies", "id,code,title,quarter,start_week,end_week,recommended_lesson_count,mastery_threshold_percent,minimum_independent_demonstrations,mastery_objective", x => x.eq("course_version_id", courseVersionId).order("code")),
    q("course_weeks", "id,week_number,quarter,title,week_mode,is_mastery_check", x => x.eq("course_version_id", courseVersionId).order("week_number")),
    q("lessons", "id,course_week_id,code,title,week_number,day_number,sequence,estimated_minutes,status,lesson_type,is_mastery_check", x => x.eq("course_version_id", courseVersionId).order("sequence")),
  ]);

  report.details.counts = {
    units: units.length,
    competencies: competencies.length,
    weeks: weeks.length,
    lessons: lessons.length,
  };

  if (units.length === 8 && sameSet(units.map(u => u.code), Array.from({length:8},(_,i)=>`1-MATH-U${String(i+1).padStart(2,"0")}`))) {
    pass("structure.units", "All 8 expected units are present.");
  } else {
    fail("structure.units", `Expected 8 units U01–U08; found ${units.length}.`, units.map(u => u.code));
  }

  const expectedCompetencyCodes = Array.from({length:21},(_,i)=>`1-MATH-${String(i+1).padStart(2,"0")}`);
  if (competencies.length === 21 && sameSet(competencies.map(c => c.code), expectedCompetencyCodes)) {
    pass("structure.competencies", "All 21 expected competencies are present.");
  } else {
    fail("structure.competencies", `Expected 21 competencies 1-MATH-01 through 1-MATH-21; found ${competencies.length}.`, competencies.map(c => c.code));
  }

  const badThresholds = [];
  const badDemoCounts = [];
  const missingObjectives = [];

  for (const c of competencies) {
    const expected = EXPECTED_THRESHOLDS.get(c.code);
    if (expected != null && Number(c.mastery_threshold_percent) !== expected) {
      badThresholds.push({ code: c.code, expected, found: Number(c.mastery_threshold_percent) });
    }
    if (Number(c.minimum_independent_demonstrations) !== 2) {
      badDemoCounts.push({ code: c.code, found: c.minimum_independent_demonstrations });
    }
    if (!String(c.mastery_objective ?? "").trim()) missingObjectives.push(c.code);
  }

  if (badThresholds.length === 0) {
    pass("mastery.thresholds", "All competency mastery thresholds match the curriculum map, including 1-MATH-08 and 1-MATH-20 at 90%.");
  } else {
    fail("mastery.thresholds", "One or more competency mastery thresholds are incorrect.", badThresholds);
  }

  if (badDemoCounts.length === 0) {
    pass("mastery.demonstrations", "All 21 competencies require two independent demonstrations.");
  } else {
    fail("mastery.demonstrations", "Unexpected minimum independent demonstration counts found.", badDemoCounts);
  }

  if (missingObjectives.length === 0) {
    pass("mastery.objectives", "All 21 competencies have measurable mastery objectives.");
  } else {
    fail("mastery.objectives", "Some competencies are missing mastery objectives.", missingObjectives);
  }

  if (weeks.length === 36 && weeks.every((w, i) => Number(w.week_number) === i + 1)) {
    pass("structure.weeks", "All 36 course weeks are present in sequence.");
  } else {
    fail("structure.weeks", `Expected sequential Weeks 1–36; found ${weeks.length}.`, weeks.map(w => w.week_number));
  }

  const weekErrors = [];
  for (const [num, quarter, title, _focus, mode, mastery] of EXPECTED_WEEKS) {
    const w = weeks.find(x => Number(x.week_number) === num);
    if (!w) {
      weekErrors.push({ week: num, issue: "missing" });
      continue;
    }
    if (
      Number(w.quarter) !== quarter ||
      w.title !== title ||
      w.week_mode !== mode ||
      Boolean(w.is_mastery_check) !== mastery
    ) {
      weekErrors.push({
        week: num,
        expected: { quarter, title, mode, mastery },
        found: { quarter: w.quarter, title: w.title, mode: w.week_mode, mastery: w.is_mastery_check },
      });
    }
  }

  if (weekErrors.length === 0) {
    pass("structure.week_map", "All 36 week titles, quarters, modes, and mastery flags match the approved map.");
  } else {
    fail("structure.week_map", "One or more weeks differ from the approved course map.", weekErrors);
  }

  const quarterCounts = new Map();
  for (const w of weeks) quarterCounts.set(Number(w.quarter), (quarterCounts.get(Number(w.quarter)) ?? 0) + 1);
  if ([1,2,3,4].every(qtr => quarterCounts.get(qtr) === 9)) {
    pass("structure.quarters", "Each quarter contains exactly 9 instructional weeks.");
  } else {
    fail("structure.quarters", "Quarter week counts are incorrect.", Object.fromEntries(quarterCounts));
  }

  if (lessons.length === 180) {
    pass("lessons.count", "All 180 daily lessons are present.");
  } else {
    fail("lessons.count", `Expected 180 lessons; found ${lessons.length}.`);
  }

  const lessonErrors = [];
  const lessonsByWeek = groupBy(lessons, l => Number(l.week_number));

  for (let week = 1; week <= 36; week++) {
    const rows = lessonsByWeek.get(week) ?? [];
    if (rows.length !== 5) {
      lessonErrors.push({ week, issue: `expected 5 lessons, found ${rows.length}` });
      continue;
    }
    for (let day = 1; day <= 5; day++) {
      const code = `1-MATH-W${String(week).padStart(2,"0")}-D${day}`;
      const l = rows.find(x => Number(x.day_number) === day);
      if (!l) {
        lessonErrors.push({ week, day, issue: "missing day" });
        continue;
      }
      const expectedSequence = ((week - 1) * 5) + day;
      const masteryWeek = [9,18,27,36].includes(week);
      const reviewWeek = week === 8;
      const expectedType = ((masteryWeek || reviewWeek) && day === 1)
        ? "review"
        : EXPECTED_DAY_TYPES.get(day);

      if (
        l.code !== code ||
        Number(l.sequence) !== expectedSequence ||
        Number(l.estimated_minutes) !== 30 ||
        l.status !== "active" ||
        l.lesson_type !== expectedType ||
        Boolean(l.is_mastery_check) !== (masteryWeek && day === 5)
      ) {
        lessonErrors.push({
          code,
          expected: {
            sequence: expectedSequence,
            minutes: 30,
            status: "active",
            lesson_type: expectedType,
            mastery: masteryWeek && day === 5,
          },
          found: {
            code: l.code,
            sequence: l.sequence,
            minutes: l.estimated_minutes,
            status: l.status,
            lesson_type: l.lesson_type,
            mastery: l.is_mastery_check,
          },
        });
      }
    }
  }

  if (lessonErrors.length === 0) {
    pass("lessons.structure", "All lesson codes, D1–D5 placement, sequence numbers, 30-minute durations, lesson types, and mastery flags are correct.");
  } else {
    fail("lessons.structure", "One or more daily lesson skeletons are incorrect.", lessonErrors.slice(0, 50));
  }

  const malformedLessonCodes = lessons
    .map(l => l.code)
    .filter(code => !/^1-MATH-W\d{2}-D[1-5]$/.test(code));
  if (malformedLessonCodes.length === 0) {
    pass("lessons.codes", "No malformed D01/D02-style lesson codes were found.");
  } else {
    fail("lessons.codes", "Malformed lesson codes found.", malformedLessonCodes);
  }

  // -------------------------------------------------------------------------
  // Lesson ↔ competency alignment
  // -------------------------------------------------------------------------
  const lessonIds = lessons.map(l => l.id);
  const competencyById = new Map(competencies.map(c => [c.id, c.code]));
  const lessonById = new Map(lessons.map(l => [l.id, l]));

  const lessonLinks = await fetchInChunks(
    "lesson_competencies",
    "lesson_id,competency_id,relationship_type",
    "lesson_id",
    lessonIds
  );

  const linksByLesson = groupBy(lessonLinks, x => x.lesson_id);
  const linkErrors = [];

  for (const [week, _quarter, _title, focusCodes] of EXPECTED_WEEKS) {
    for (const lessonRow of lessonsByWeek.get(week) ?? []) {
      const actualCodes = (linksByLesson.get(lessonRow.id) ?? [])
        .map(x => competencyById.get(x.competency_id))
        .filter(Boolean);

      if (!sameSet(actualCodes, focusCodes)) {
        linkErrors.push({
          lesson: lessonRow.code,
          expected: focusCodes,
          found: sorted(actualCodes),
        });
      }
    }
  }

  if (linkErrors.length === 0) {
    pass("alignment.lesson_competencies", "Every lesson is linked to the correct competency set for its week.");
  } else {
    fail("alignment.lesson_competencies", "Lesson-to-competency alignment errors found.", linkErrors.slice(0, 50));
  }

  // -------------------------------------------------------------------------
  // Published lesson content + item banks
  // -------------------------------------------------------------------------
  const contentVersions = await fetchInChunks(
    "lesson_content_versions",
    "id,lesson_id,revision_number,status,objective,student_goal,materials,vocabulary,teacher_introduction,teacher_modeling,teacher_notes,student_learn,guided_practice,independent_practice,activity,worksheet_title,worksheet_instructions,completion_criteria,accommodations,enrichment",
    "lesson_id",
    lessonIds
  );

  const versionsByLesson = groupBy(contentVersions, x => x.lesson_id);
  const contentErrors = [];
  const revisionWarnings = [];
  const publishedVersions = [];

  const requiredTextFields = [
    "objective","student_goal","teacher_introduction","teacher_modeling","teacher_notes",
    "student_learn","guided_practice","independent_practice","activity",
    "worksheet_title","worksheet_instructions","completion_criteria","accommodations","enrichment",
  ];

  for (const l of lessons) {
    const versions = versionsByLesson.get(l.id) ?? [];
    const published = versions.filter(v => v.status === "published");

    if (published.length !== 1) {
      contentErrors.push({ lesson: l.code, issue: `expected exactly 1 current published revision; found ${published.length}` });
      continue;
    }

    const v = published[0];
    publishedVersions.push(v);

    if (Number(v.revision_number) !== 1) {
      revisionWarnings.push({ lesson: l.code, revision: v.revision_number });
    }

    const missingFields = requiredTextFields.filter(field => !String(v[field] ?? "").trim());
    if (missingFields.length) {
      contentErrors.push({ lesson: l.code, issue: "missing required content fields", fields: missingFields });
    }

    if (!Array.isArray(v.materials)) {
      contentErrors.push({ lesson: l.code, issue: "materials is not an array" });
    }
    if (!Array.isArray(v.vocabulary)) {
      contentErrors.push({ lesson: l.code, issue: "vocabulary is not an array" });
    }
  }

  if (contentErrors.length === 0 && publishedVersions.length === 180) {
    pass("content.published", "All 180 lessons have exactly one complete current published content revision.");
  } else {
    fail("content.published", "Published lesson-content problems found.", contentErrors.slice(0, 50));
  }

  if (revisionWarnings.length === 0) {
    pass("content.revision", "All current lesson content is Published r1.");
  } else {
    warn("content.revision", "Some lessons are on a later published revision. This can be valid if intentionally revised.", revisionWarnings);
  }

  const publishedVersionIds = publishedVersions.map(v => v.id);
  const contentItems = await fetchInChunks(
    "lesson_content_items",
    "lesson_content_version_id,section,sequence,prompt,correct_answer,answer_explanation,points",
    "lesson_content_version_id",
    publishedVersionIds
  );

  const itemsByVersion = groupBy(contentItems, x => x.lesson_content_version_id);
  const itemErrors = [];

  for (const v of publishedVersions) {
    const l = lessonById.get(v.lesson_id);
    const rows = itemsByVersion.get(v.id) ?? [];
    const sectionCounts = new Map();
    for (const row of rows) sectionCounts.set(row.section, (sectionCounts.get(row.section) ?? 0) + 1);

    const badBlank = rows.filter(r => !String(r.prompt ?? "").trim() || !String(r.correct_answer ?? "").trim());
    const points = rows.reduce((sum, r) => sum + Number(r.points ?? 0), 0);

    if (
      rows.length !== 15 ||
      sectionCounts.get("guided_practice") !== 3 ||
      sectionCounts.get("independent_practice") !== 4 ||
      sectionCounts.get("worksheet") !== 8 ||
      badBlank.length > 0 ||
      points !== 15
    ) {
      itemErrors.push({
        lesson: l?.code ?? v.lesson_id,
        total: rows.length,
        guided: sectionCounts.get("guided_practice") ?? 0,
        independent: sectionCounts.get("independent_practice") ?? 0,
        worksheet: sectionCounts.get("worksheet") ?? 0,
        total_points: points,
        blank_prompt_or_answer: badBlank.length,
      });
    }
  }

  if (itemErrors.length === 0 && contentItems.length === 2700) {
    pass("content.items", "All 180 published lessons contain the expected 15 items (3 guided + 4 independent + 8 worksheet), for 2,700 lesson items total.");
  } else {
    fail("content.items", `Expected 2,700 structured lesson items; found ${contentItems.length}.`, itemErrors.slice(0, 50));
  }

  // -------------------------------------------------------------------------
  // Assignment templates + competency alignment + online question banks
  // -------------------------------------------------------------------------
  const templates = await q(
    "assignment_templates",
    "id,lesson_id,code,title,assignment_type,max_points,weight,sequence,active",
    x => x.eq("course_version_id", courseVersionId).order("sequence")
  );

  if (templates.length === 36) {
    pass("assessments.templates", "All 36 Friday assessment templates are present.");
  } else {
    fail("assessments.templates", `Expected 36 assessment templates; found ${templates.length}.`);
  }

  const templateErrors = [];
  for (let week = 1; week <= 36; week++) {
    const t = templates.find(x => Number(x.sequence) === week);
    const friday = (lessonsByWeek.get(week) ?? []).find(x => Number(x.day_number) === 5);
    const mastery = [9,18,27,36].includes(week);
    const expectedCode = mastery
      ? `1-MATH-Q${EXPECTED_WEEKS[week-1][1]}-MASTERY`
      : `1-MATH-W${String(week).padStart(2,"0")}-CHECK`;

    if (!t) {
      templateErrors.push({ week, issue: "missing template" });
      continue;
    }
    if (
      t.lesson_id !== friday?.id ||
      t.code !== expectedCode ||
      t.assignment_type !== (mastery ? "test" : "quiz") ||
      Boolean(t.active) !== true ||
      Number(t.weight) !== 1
    ) {
      templateErrors.push({
        week,
        expected: {
          lesson_id: friday?.id,
          code: expectedCode,
          type: mastery ? "test" : "quiz",
          active: true,
          weight: 1,
        },
        found: {
          lesson_id: t.lesson_id,
          code: t.code,
          type: t.assignment_type,
          active: t.active,
          weight: t.weight,
        },
      });
    }
  }

  if (templateErrors.length === 0) {
    pass("assessments.template_map", "All assessment templates are attached to the correct Friday lesson with the correct weekly/mastery codes.");
  } else {
    fail("assessments.template_map", "Assessment-template map errors found.", templateErrors);
  }

  const templateIds = templates.map(t => t.id);
  const templateLinks = await fetchInChunks(
    "assignment_template_competencies",
    "assignment_template_id,competency_id,relationship_type",
    "assignment_template_id",
    templateIds
  );

  const linksByTemplate = groupBy(templateLinks, x => x.assignment_template_id);
  const templateLinkErrors = [];

  for (const [week, _qtr, _title, focusCodes] of EXPECTED_WEEKS) {
    const t = templates.find(x => Number(x.sequence) === week);
    if (!t) continue;
    const actual = (linksByTemplate.get(t.id) ?? [])
      .map(x => competencyById.get(x.competency_id))
      .filter(Boolean);

    if (!sameSet(actual, focusCodes)) {
      templateLinkErrors.push({ week, expected: focusCodes, found: sorted(actual) });
    }
  }

  if (templateLinkErrors.length === 0) {
    pass("alignment.assessment_competencies", "Every weekly/mastery assessment template is linked to the correct competency set.");
  } else {
    fail("alignment.assessment_competencies", "Assessment-to-competency alignment errors found.", templateLinkErrors);
  }

  const assessmentItems = await fetchInChunks(
    "assessment_template_items",
    "assignment_template_id,code,sequence,question_type,prompt,options,correct_answer,points",
    "assignment_template_id",
    templateIds
  );

  const questionsByTemplate = groupBy(assessmentItems, x => x.assignment_template_id);
  const questionErrors = [];
  const pointMismatches = [];

  for (let week = 1; week <= 36; week++) {
    const t = templates.find(x => Number(x.sequence) === week);
    if (!t) continue;

    const rows = questionsByTemplate.get(t.id) ?? [];
    const expectedPrefix = `1-MATH-W${String(week).padStart(2,"0")}-Q`;
    const codes = rows.map(r => r.code);
    const expectedCodes = Array.from({length:10},(_,i)=>`${expectedPrefix}${String(i+1).padStart(2,"0")}`);
    const sequences = sorted(rows.map(r => Number(r.sequence)));
    const expectedSequences = Array.from({length:10},(_,i)=>i+1);
    const invalidMc = rows
      .filter(r => r.question_type === "multiple_choice")
      .filter(r => {
        const options = Array.isArray(r.options) ? r.options : [];
        return !options.some(o => String(o?.id) === String(r.correct_answer));
      });
    const blank = rows.filter(r => !String(r.prompt ?? "").trim() || !String(r.correct_answer ?? "").trim());
    const totalQuestionPoints = rows.reduce((sum, r) => sum + Number(r.points ?? 0), 0);

    if (
      rows.length !== 10 ||
      !sameSet(codes, expectedCodes) ||
      !sameSet(sequences, expectedSequences) ||
      invalidMc.length > 0 ||
      blank.length > 0
    ) {
      questionErrors.push({
        week,
        question_count: rows.length,
        codes_ok: sameSet(codes, expectedCodes),
        sequences_ok: sameSet(sequences, expectedSequences),
        invalid_multiple_choice_keys: invalidMc.map(r => r.code),
        blank_prompt_or_answer: blank.map(r => r.code),
      });
    }

    if (Number(t.max_points) !== totalQuestionPoints) {
      pointMismatches.push({
        week,
        template_code: t.code,
        template_max_points: Number(t.max_points),
        question_points: totalQuestionPoints,
      });
    }
  }

  if (questionErrors.length === 0 && assessmentItems.length === 360) {
    pass("assessments.questions", "All 36 Friday checks contain exactly 10 valid online questions, for 360 assessment items total.");
  } else {
    fail("assessments.questions", `Expected 360 valid online assessment items; found ${assessmentItems.length}.`, questionErrors);
  }

  const allQuestionCodes = assessmentItems.map(r => r.code);
  if (new Set(allQuestionCodes).size === allQuestionCodes.length) {
    pass("assessments.question_codes", "All 360 assessment question codes are unique.");
  } else {
    fail("assessments.question_codes", "Duplicate assessment question codes were found.");
  }

  if (pointMismatches.length === 0) {
    pass("assessments.points", "Every template max_points value matches the sum of its online question points.");
  } else {
    fail(
      "assessments.points",
      "Template max_points does not match the sum of online question points for one or more weeks. This can create inconsistent assignment/grade displays even though auto-percentage uses question points.",
      pointMismatches
    );
  }

  // -------------------------------------------------------------------------
  // Historical-delivery integrity
  // -------------------------------------------------------------------------
  const deliveries = await q(
    "student_lesson_deliveries",
    "id,lesson_id,lesson_content_version_id",
    x => x.eq("organization_id", orgId).in("lesson_id", lessonIds)
  );

  const contentById = new Map(contentVersions.map(v => [v.id, v]));
  const deliveryErrors = deliveries.filter(d => {
    const v = contentById.get(d.lesson_content_version_id);
    return !v || v.lesson_id !== d.lesson_id || !["published","superseded"].includes(v.status);
  });

  if (deliveryErrors.length === 0) {
    pass(
      "history.deliveries",
      `All ${deliveries.length} existing Grade 1 Math frozen student lesson deliveries point to a valid published/superseded revision.`
    );
  } else {
    fail("history.deliveries", "Broken frozen student lesson delivery references found.", deliveryErrors);
  }

  // -------------------------------------------------------------------------
  // Architectural warning: cumulative assessment granularity
  // -------------------------------------------------------------------------
  warn(
    "architecture.cumulative_item_mapping",
    "Cumulative mastery assessments are linked to multiple competencies at the assignment-template level, not per question. The current auto-grader therefore records the same overall cumulative percentage as evidence for every competency linked to that mastery assessment. Weekly evidence still provides competency-specific checks, but item-level competency tagging would make quarterly/year-end mastery evidence more precise."
  );

  finish();
}

function finish() {
  const reportPath = join(process.cwd(), "audit-reports", "grade1-math-2026.1.json");
  mkdirSync(dirname(reportPath), { recursive: true });
  writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n", "utf8");

  console.log("");
  console.log("============================================================");
  console.log(" GRADE 1 MATHEMATICS 2026.1 — LIVE DATABASE AUDIT");
  console.log("============================================================");

  for (const check of report.checks) {
    const symbol = check.level === "PASS" ? "✓" : check.level === "WARN" ? "!" : "✗";
    console.log(`${symbol} ${check.level.padEnd(4)}  ${check.message}`);
  }

  console.log("------------------------------------------------------------");
  console.log(`PASS: ${report.summary.pass}   WARN: ${report.summary.warn}   FAIL: ${report.summary.fail}`);
  console.log(`Report: ${reportPath}`);

  if (report.summary.fail > 0) {
    console.log("RESULT: NOT RELEASE-READY — fix the failed checks, then rerun.");
    process.exitCode = 1;
  } else if (report.summary.warn > 0) {
    console.log("RESULT: CORE AUDIT PASSED WITH WARNINGS — review warnings before final release.");
    process.exitCode = 0;
  } else {
    console.log("RESULT: RELEASE-READY — all automated checks passed.");
    process.exitCode = 0;
  }
}

main().catch(error => {
  console.error("");
  console.error("AUDIT ERROR:", error?.message ?? error);
  console.error("No database changes were made.");
  process.exit(2);
});
