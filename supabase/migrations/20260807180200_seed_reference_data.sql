-- Homeschool Tracker
-- Migration 003: Seed stable reference data

begin;

insert into public.grade_levels (code, name, numeric_order)
values
  ('K',  'Kindergarten', 0),
  ('1',  'Grade 1', 1),
  ('2',  'Grade 2', 2),
  ('3',  'Grade 3', 3),
  ('4',  'Grade 4', 4),
  ('5',  'Grade 5', 5),
  ('6',  'Grade 6', 6),
  ('7',  'Grade 7', 7),
  ('8',  'Grade 8', 8),
  ('9',  'Grade 9', 9),
  ('10', 'Grade 10', 10),
  ('11', 'Grade 11', 11),
  ('12', 'Grade 12', 12)
on conflict (code) do update
set
  name = excluded.name,
  numeric_order = excluded.numeric_order,
  active = true,
  updated_at = now();

insert into public.subjects (code, name, display_order)
values
  ('MATH',   'Mathematics', 10),
  ('ELA',    'English Language Arts', 20),
  ('SCI',    'Science', 30),
  ('SS',     'Social Studies', 40),
  ('PE',     'Physical Education', 50),
  ('HEALTH', 'Health', 60),
  ('ART',    'Art', 70),
  ('MUS',    'Music', 80),
  ('TECH',   'Technology and Digital Literacy', 90),
  ('WL',     'World Languages', 100)
on conflict (code) do update
set
  name = excluded.name,
  display_order = excluded.display_order,
  active = true,
  updated_at = now();

commit;
