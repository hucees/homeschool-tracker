-- Homeschool Tracker
-- Migration 001: Initial database schema
-- Target: Supabase PostgreSQL
--
-- Design principles:
--   1. Academic history is append-oriented and never inferred only from current state.
--   2. Official grade placement is separate from per-course/subject placement.
--   3. Student course enrollments point to immutable curriculum versions.
--   4. Human-readable curriculum codes coexist with UUID primary keys.
--   5. organization_id and student_id are intentionally denormalized on many
--      student records to simplify Row Level Security and reporting.

begin;

create extension if not exists pgcrypto;

create schema if not exists private;

-- -----------------------------------------------------------------------------
-- AUTH / ORGANIZATION
-- -----------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  legal_name text,
  school_type text not null default 'homeschool'
    check (school_type in ('homeschool', 'private_school', 'co_op', 'other')),
  timezone text not null default 'America/Denver',
  status text not null default 'active'
    check (status in ('active', 'archived')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null
    check (role in ('owner', 'administrator', 'instructor', 'student', 'guardian')),
  status text not null default 'active'
    check (status in ('active', 'disabled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, profile_id)
);

-- -----------------------------------------------------------------------------
-- REFERENCE DATA
-- -----------------------------------------------------------------------------

create table public.grade_levels (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  numeric_order integer not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  display_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- ACADEMIC CALENDAR
-- -----------------------------------------------------------------------------

create table public.academic_years (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  name text not null,
  start_date date not null,
  end_date date not null,
  status text not null default 'planned'
    check (status in ('planned', 'active', 'closed', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint academic_year_valid_dates check (end_date >= start_date),
  unique (organization_id, name)
);

create table public.academic_terms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  academic_year_id uuid not null references public.academic_years(id),
  name text not null,
  term_type text not null default 'quarter'
    check (term_type in ('quarter', 'semester', 'trimester', 'custom')),
  sequence integer not null check (sequence > 0),
  start_date date not null,
  end_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint academic_term_valid_dates check (end_date >= start_date),
  unique (academic_year_id, sequence),
  unique (academic_year_id, name)
);

create table public.school_calendar_days (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  academic_year_id uuid not null references public.academic_years(id),
  calendar_date date not null,
  day_type text not null default 'instructional'
    check (day_type in ('instructional', 'holiday', 'break', 'weekend', 'teacher_workday', 'other')),
  planned_minutes integer check (planned_minutes is null or planned_minutes >= 0),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (academic_year_id, calendar_date)
);

-- -----------------------------------------------------------------------------
-- STUDENTS
-- -----------------------------------------------------------------------------

create table public.students (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_number text not null,
  first_name text not null,
  middle_name text,
  last_name text not null,
  preferred_name text,
  date_of_birth date,
  enrollment_date date not null,
  graduation_date date,
  status text not null default 'active'
    check (status in ('active', 'inactive', 'graduated', 'archived')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (organization_id, student_number)
);

create table public.student_user_links (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  profile_id uuid references public.profiles(id) on delete set null,
  login_username text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  disabled_at timestamptz,
  unique (organization_id, profile_id)
);

create unique index student_user_links_username_ci_uq
  on public.student_user_links (organization_id, lower(login_username));

create table public.student_academic_years (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  academic_year_id uuid not null references public.academic_years(id),
  official_grade_level_id uuid not null references public.grade_levels(id),
  status text not null default 'planned'
    check (status in ('planned', 'active', 'completed', 'withdrawn')),
  start_date date not null,
  end_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint student_academic_year_valid_dates check (end_date is null or end_date >= start_date),
  unique (student_id, academic_year_id)
);

-- -----------------------------------------------------------------------------
-- VERSIONED CURRICULUM
-- -----------------------------------------------------------------------------

create table public.curriculum_releases (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  version text not null,
  name text not null,
  status text not null default 'draft'
    check (status in ('draft', 'published', 'retired')),
  effective_date date,
  published_at timestamptz,
  locked_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, version)
);

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  subject_id uuid not null references public.subjects(id),
  grade_level_id uuid references public.grade_levels(id),
  canonical_name text not null,
  course_type text not null default 'standard'
    check (course_type in ('standard', 'elective', 'high_school', 'other')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table public.course_versions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  course_id uuid not null references public.courses(id),
  curriculum_release_id uuid not null references public.curriculum_releases(id),
  -- Snapshot fields below belong to this curriculum version so later edits to
  -- the canonical course catalog cannot rewrite historical student records.
  course_code text not null,
  title text not null,
  subject_id uuid not null references public.subjects(id),
  grade_level_id uuid references public.grade_levels(id),
  description text,
  instructional_weeks integer not null default 36
    check (instructional_weeks between 1 and 52),
  recommended_minutes_per_week integer
    check (recommended_minutes_per_week is null or recommended_minutes_per_week >= 0),
  credit_value numeric(5,2)
    check (credit_value is null or credit_value >= 0),
  grading_method text not null default 'mixed'
    check (grading_method in ('percentage', 'mastery', 'pass_fail', 'mixed')),
  status text not null default 'draft'
    check (status in ('draft', 'published', 'retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_id, curriculum_release_id),
  unique (curriculum_release_id, course_code)
);

create table public.units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  course_version_id uuid not null references public.course_versions(id),
  code text not null,
  title text not null,
  description text,
  sequence integer not null check (sequence > 0),
  quarter integer check (quarter is null or quarter between 1 and 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_version_id, code),
  unique (course_version_id, sequence)
);

create table public.competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  course_version_id uuid not null references public.course_versions(id),
  unit_id uuid references public.units(id),
  code text not null,
  title text not null,
  description text,
  sequence integer not null check (sequence > 0),
  quarter integer check (quarter is null or quarter between 1 and 4),
  is_required boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_version_id, code),
  unique (course_version_id, sequence)
);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  course_version_id uuid not null references public.course_versions(id),
  unit_id uuid references public.units(id),
  code text not null,
  title text not null,
  description text,
  week_number integer not null check (week_number between 1 and 52),
  day_number integer check (day_number is null or day_number between 1 and 7),
  sequence integer not null check (sequence > 0),
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes >= 0),
  status text not null default 'active'
    check (status in ('active', 'retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_version_id, code),
  unique (course_version_id, sequence)
);

create table public.lesson_competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  lesson_id uuid not null references public.lessons(id),
  competency_id uuid not null references public.competencies(id),
  relationship_type text not null default 'practices'
    check (relationship_type in ('introduces', 'practices', 'assesses', 'reviews')),
  created_at timestamptz not null default now(),
  unique (lesson_id, competency_id)
);

create table public.assignment_templates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  course_version_id uuid not null references public.course_versions(id),
  lesson_id uuid references public.lessons(id),
  code text not null,
  title text not null,
  description text,
  assignment_type text not null default 'practice'
    check (assignment_type in ('practice', 'worksheet', 'quiz', 'test', 'project', 'essay', 'reading', 'activity', 'lab', 'oral', 'other')),
  max_points numeric(10,2) check (max_points is null or max_points >= 0),
  weight numeric(10,4) check (weight is null or weight >= 0),
  sequence integer check (sequence is null or sequence > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_version_id, code)
);

create table public.assignment_template_competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  assignment_template_id uuid not null references public.assignment_templates(id),
  competency_id uuid not null references public.competencies(id),
  relationship_type text not null default 'assesses'
    check (relationship_type in ('practices', 'assesses', 'reviews')),
  created_at timestamptz not null default now(),
  unique (assignment_template_id, competency_id)
);

-- -----------------------------------------------------------------------------
-- STUDENT COURSE PLACEMENT / INSTRUCTION
-- -----------------------------------------------------------------------------

create table public.student_course_enrollments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_academic_year_id uuid not null references public.student_academic_years(id),
  course_version_id uuid not null references public.course_versions(id),
  academic_term_id uuid references public.academic_terms(id),
  attempt_number integer not null default 1 check (attempt_number > 0),
  status text not null default 'planned'
    check (status in ('planned', 'active', 'completed', 'continued', 'withdrawn', 'superseded')),
  start_date date not null,
  end_date date,
  assigned_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint student_course_enrollment_valid_dates check (end_date is null or end_date >= start_date),
  unique (student_academic_year_id, course_version_id, attempt_number)
);

create table public.daily_assignments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_course_enrollment_id uuid not null references public.student_course_enrollments(id),
  lesson_id uuid references public.lessons(id),
  assigned_date date not null,
  due_date date,
  title text not null,
  instructions text,
  status text not null default 'assigned'
    check (status in ('assigned', 'completed', 'cancelled')),
  assigned_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint daily_assignment_valid_dates check (due_date is null or due_date >= assigned_date)
);

create table public.student_daily_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_academic_year_id uuid not null references public.student_academic_years(id),
  record_date date not null,
  status text not null default 'draft'
    check (status in ('draft', 'submitted', 'reopened')),
  student_summary text,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id, record_date)
);

create table public.daily_record_reviews (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  daily_record_id uuid not null unique references public.student_daily_records(id),
  review_status text not null default 'reviewed'
    check (review_status in ('reviewed', 'needs_revision', 'approved')),
  teacher_summary text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.daily_learning_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  daily_record_id uuid not null references public.student_daily_records(id),
  student_course_enrollment_id uuid not null references public.student_course_enrollments(id),
  daily_assignment_id uuid references public.daily_assignments(id),
  lesson_id uuid references public.lessons(id),
  status text not null default 'assigned'
    check (status in ('assigned', 'started', 'completed', 'partial', 'skipped', 'excused')),
  minutes_spent integer check (minutes_spent is null or minutes_spent >= 0),
  student_note text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index daily_learning_entries_daily_assignment_uq
  on public.daily_learning_entries (daily_record_id, daily_assignment_id)
  where daily_assignment_id is not null;

create unique index daily_learning_entries_lesson_uq
  on public.daily_learning_entries (daily_record_id, student_course_enrollment_id, lesson_id)
  where lesson_id is not null and daily_assignment_id is null;

-- -----------------------------------------------------------------------------
-- ATTENDANCE
-- -----------------------------------------------------------------------------

create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_academic_year_id uuid not null references public.student_academic_years(id),
  attendance_date date not null,
  status text not null
    check (status in ('present', 'partial', 'absent', 'excused', 'holiday', 'not_scheduled')),
  instructional_minutes integer check (instructional_minutes is null or instructional_minutes >= 0),
  source text not null default 'manual'
    check (source in ('manual', 'activity_suggested', 'imported')),
  teacher_confirmed boolean not null default false,
  confirmed_by uuid references public.profiles(id) on delete set null,
  confirmed_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_academic_year_id, attendance_date)
);

-- -----------------------------------------------------------------------------
-- ASSIGNMENTS / SUBMISSIONS / GRADES
-- -----------------------------------------------------------------------------

create table public.student_assignments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_course_enrollment_id uuid not null references public.student_course_enrollments(id),
  assignment_template_id uuid references public.assignment_templates(id),
  lesson_id uuid references public.lessons(id),
  academic_term_id uuid references public.academic_terms(id),
  title text not null,
  instructions text,
  assignment_type text not null default 'practice'
    check (assignment_type in ('practice', 'worksheet', 'quiz', 'test', 'project', 'essay', 'reading', 'activity', 'lab', 'oral', 'other')),
  max_points numeric(10,2) check (max_points is null or max_points >= 0),
  weight numeric(10,4) check (weight is null or weight >= 0),
  assigned_date date not null,
  due_date date,
  status text not null default 'assigned'
    check (status in ('assigned', 'submitted', 'graded', 'completed', 'excused', 'cancelled')),
  assigned_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_assignment_valid_dates check (due_date is null or due_date >= assigned_date)
);

create table public.assignment_submissions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_assignment_id uuid not null references public.student_assignments(id),
  attempt_number integer not null default 1 check (attempt_number > 0),
  student_response text,
  status text not null default 'submitted'
    check (status in ('submitted', 'returned', 'resubmitted')),
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_assignment_id, attempt_number)
);

create table public.grade_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_assignment_id uuid not null references public.student_assignments(id),
  assignment_submission_id uuid references public.assignment_submissions(id),
  revision_number integer not null default 1 check (revision_number > 0),
  supersedes_grade_record_id uuid references public.grade_records(id),
  points_earned numeric(10,2) check (points_earned is null or points_earned >= 0),
  points_possible numeric(10,2) check (points_possible is null or points_possible >= 0),
  percentage numeric(6,3) check (percentage is null or percentage between 0 and 100),
  letter_grade text,
  passed boolean,
  status text not null default 'current'
    check (status in ('current', 'superseded', 'voided')),
  teacher_feedback text,
  change_reason text,
  graded_by uuid references public.profiles(id) on delete set null,
  graded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (student_assignment_id, revision_number)
);

create unique index grade_records_one_current_uq
  on public.grade_records (student_assignment_id)
  where status = 'current';

-- -----------------------------------------------------------------------------
-- COMPETENCY / MASTERY EVIDENCE
-- -----------------------------------------------------------------------------

create table public.competency_evidence (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_course_enrollment_id uuid not null references public.student_course_enrollments(id),
  competency_id uuid not null references public.competencies(id),
  lesson_id uuid references public.lessons(id),
  student_assignment_id uuid references public.student_assignments(id),
  daily_learning_entry_id uuid references public.daily_learning_entries(id),
  evidence_type text not null default 'observation'
    check (evidence_type in ('observation', 'assignment', 'quiz', 'test', 'project', 'conversation', 'other')),
  rating text not null
    check (rating in ('introduced', 'practicing', 'proficient', 'mastered', 'needs_review')),
  score numeric(6,3) check (score is null or score between 0 and 100),
  recorded_by uuid references public.profiles(id) on delete set null,
  recorded_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- NOTES
-- -----------------------------------------------------------------------------

create table public.student_notes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  author_profile_id uuid references public.profiles(id) on delete set null,
  note_date date not null default current_date,
  note_type text not null default 'general'
    check (note_type in ('student_daily', 'teacher_observation', 'progress', 'behavior', 'academic', 'general')),
  visibility text not null default 'student_and_teacher'
    check (visibility in ('student_and_teacher', 'instructor_only')),
  student_academic_year_id uuid references public.student_academic_years(id),
  student_course_enrollment_id uuid references public.student_course_enrollments(id),
  daily_record_id uuid references public.student_daily_records(id),
  student_assignment_id uuid references public.student_assignments(id),
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

-- -----------------------------------------------------------------------------
-- COMPLETION / PROGRESSION
-- -----------------------------------------------------------------------------

create table public.course_completion_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_course_enrollment_id uuid not null unique references public.student_course_enrollments(id),
  completion_status text not null
    check (completion_status in ('completed', 'incomplete', 'continued', 'retained', 'withdrawn')),
  final_percentage numeric(6,3) check (final_percentage is null or final_percentage between 0 and 100),
  final_letter_grade text,
  credits_attempted numeric(5,2) check (credits_attempted is null or credits_attempted >= 0),
  credits_earned numeric(5,2) check (credits_earned is null or credits_earned >= 0),
  grade_points numeric(6,3) check (grade_points is null or grade_points >= 0),
  competencies_total integer check (competencies_total is null or competencies_total >= 0),
  competencies_mastered integer check (competencies_mastered is null or competencies_mastered >= 0),
  instructional_minutes integer check (instructional_minutes is null or instructional_minutes >= 0),
  teacher_summary text,
  completed_by uuid references public.profiles(id) on delete set null,
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint mastered_not_over_total check (
    competencies_total is null
    or competencies_mastered is null
    or competencies_mastered <= competencies_total
  )
);

create table public.progression_decisions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  source_enrollment_id uuid not null references public.student_course_enrollments(id),
  decision text not null
    check (decision in ('advance', 'continue', 'repeat', 'accelerate', 'complete', 'instructor_override')),
  target_course_version_id uuid references public.course_versions(id),
  reason text,
  decided_by uuid references public.profiles(id) on delete set null,
  decided_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.grade_level_decisions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_academic_year_id uuid not null references public.student_academic_years(id),
  current_grade_level_id uuid not null references public.grade_levels(id),
  next_grade_level_id uuid references public.grade_levels(id),
  decision text not null
    check (decision in ('promote', 'retain', 'graduate', 'continue', 'instructor_override')),
  reason text,
  decided_by uuid references public.profiles(id) on delete set null,
  decided_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- REPORT / TRANSCRIPT SNAPSHOTS
-- -----------------------------------------------------------------------------

create table public.report_snapshots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  academic_year_id uuid references public.academic_years(id),
  version integer not null default 1 check (version > 0),
  report_type text not null
    check (report_type in ('progress_report', 'quarter_report', 'semester_report', 'annual_report', 'attendance_report', 'competency_report')),
  status text not null default 'draft'
    check (status in ('draft', 'official', 'voided')),
  period_start date,
  period_end date,
  snapshot_data jsonb not null,
  pdf_storage_path text,
  pdf_sha256 text,
  generated_by uuid references public.profiles(id) on delete set null,
  generated_at timestamptz not null default now(),
  constraint report_snapshot_valid_dates check (period_end is null or period_start is null or period_end >= period_start)
);

create table public.transcript_snapshots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  version integer not null check (version > 0),
  status text not null default 'draft'
    check (status in ('draft', 'official', 'voided')),
  snapshot_data jsonb not null,
  pdf_storage_path text,
  pdf_sha256 text,
  generated_by uuid references public.profiles(id) on delete set null,
  generated_at timestamptz not null default now(),
  unique (student_id, version)
);

-- -----------------------------------------------------------------------------
-- FILE METADATA
-- -----------------------------------------------------------------------------

create table public.student_files (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.students(id),
  student_assignment_id uuid references public.student_assignments(id),
  daily_record_id uuid references public.student_daily_records(id),
  file_name text not null,
  storage_path text not null unique,
  mime_type text,
  file_size bigint check (file_size is null or file_size >= 0),
  uploaded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- AUDIT LOG
-- -----------------------------------------------------------------------------

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  actor_user_id uuid,
  entity_type text not null,
  entity_id uuid not null,
  action text not null
    check (action in ('insert', 'update', 'delete')),
  old_values jsonb,
  new_values jsonb,
  reason text,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- PERFORMANCE INDEXES
-- -----------------------------------------------------------------------------

create index organization_members_profile_idx
  on public.organization_members (profile_id, organization_id, status);
create index organization_members_org_role_idx
  on public.organization_members (organization_id, role, status);

create index academic_years_org_idx on public.academic_years (organization_id, start_date, end_date);
create index academic_terms_year_idx on public.academic_terms (academic_year_id, sequence);
create index school_calendar_days_org_date_idx on public.school_calendar_days (organization_id, calendar_date);

create index students_org_status_idx on public.students (organization_id, status);
create index students_name_idx on public.students (organization_id, last_name, first_name);
create index student_user_links_profile_idx on public.student_user_links (profile_id, is_active);
create index student_user_links_student_idx on public.student_user_links (student_id, is_active);
create index student_academic_years_student_idx on public.student_academic_years (student_id, academic_year_id);
create index student_academic_years_org_status_idx on public.student_academic_years (organization_id, status);

create index curriculum_releases_org_status_idx on public.curriculum_releases (organization_id, status);
create index courses_org_subject_grade_idx on public.courses (organization_id, subject_id, grade_level_id);
create index course_versions_release_idx on public.course_versions (curriculum_release_id, course_id);
create index units_course_version_idx on public.units (course_version_id, sequence);
create index competencies_course_version_idx on public.competencies (course_version_id, sequence);
create index competencies_code_idx on public.competencies (organization_id, code);
create index lessons_course_version_week_idx on public.lessons (course_version_id, week_number, sequence);
create index lesson_competencies_competency_idx on public.lesson_competencies (competency_id, lesson_id);
create index assignment_templates_course_idx on public.assignment_templates (course_version_id, sequence);

create index student_course_enrollments_student_status_idx
  on public.student_course_enrollments (student_id, status, start_date);
create index student_course_enrollments_year_idx
  on public.student_course_enrollments (student_academic_year_id, status);
create index student_course_enrollments_course_idx
  on public.student_course_enrollments (course_version_id, status);

create index daily_assignments_student_date_idx
  on public.daily_assignments (student_id, assigned_date, status);
create index daily_assignments_enrollment_idx
  on public.daily_assignments (student_course_enrollment_id, assigned_date);
create index student_daily_records_student_date_idx
  on public.student_daily_records (student_id, record_date desc);
create index daily_learning_entries_student_idx
  on public.daily_learning_entries (student_id, created_at desc);
create index daily_learning_entries_daily_record_idx
  on public.daily_learning_entries (daily_record_id);
create index daily_learning_entries_enrollment_idx
  on public.daily_learning_entries (student_course_enrollment_id, completed_at);

create index attendance_records_student_date_idx
  on public.attendance_records (student_id, attendance_date desc);
create index attendance_records_org_date_idx
  on public.attendance_records (organization_id, attendance_date);

create index student_assignments_student_status_idx
  on public.student_assignments (student_id, status, due_date);
create index student_assignments_enrollment_idx
  on public.student_assignments (student_course_enrollment_id, assigned_date);
create index assignment_submissions_assignment_idx
  on public.assignment_submissions (student_assignment_id, attempt_number desc);
create index grade_records_student_idx
  on public.grade_records (student_id, graded_at desc);
create index grade_records_assignment_idx
  on public.grade_records (student_assignment_id, status, revision_number desc);

create index competency_evidence_student_competency_idx
  on public.competency_evidence (student_id, competency_id, recorded_at desc);
create index competency_evidence_enrollment_idx
  on public.competency_evidence (student_course_enrollment_id, recorded_at desc);

create index student_notes_student_date_idx
  on public.student_notes (student_id, note_date desc);
create index student_notes_visibility_idx
  on public.student_notes (organization_id, visibility, note_date desc);

create index course_completion_records_student_idx
  on public.course_completion_records (student_id, completed_at desc);
create index progression_decisions_student_idx
  on public.progression_decisions (student_id, decided_at desc);
create index grade_level_decisions_student_idx
  on public.grade_level_decisions (student_id, decided_at desc);

create index report_snapshots_student_idx
  on public.report_snapshots (student_id, generated_at desc);
create index transcript_snapshots_student_idx
  on public.transcript_snapshots (student_id, version desc);
create index student_files_student_idx
  on public.student_files (student_id, created_at desc);
create index audit_log_org_created_idx
  on public.audit_log (organization_id, created_at desc);
create index audit_log_entity_idx
  on public.audit_log (entity_type, entity_id, created_at desc);

commit;
