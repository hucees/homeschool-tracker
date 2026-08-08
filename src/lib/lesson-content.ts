export type VocabularyItem = {
  term: string;
  definition: string;
};

export type LessonPracticeItem = {
  id?: string;
  section: "guided_practice" | "independent_practice" | "worksheet";
  sequence: number;
  prompt: string;
  student_support: string | null;
  correct_answer?: string | null;
  answer_explanation?: string | null;
  points: number | null;
};

export type LessonContentRecord = {
  id: string;
  revision_number: number;
  status: "draft" | "published" | "superseded";
  objective: string | null;
  student_goal: string | null;
  materials: string[];
  vocabulary: VocabularyItem[];
  teacher_introduction: string | null;
  teacher_modeling: string | null;
  teacher_notes: string | null;
  student_learn: string | null;
  guided_practice: string | null;
  independent_practice: string | null;
  activity: string | null;
  worksheet_title: string | null;
  worksheet_instructions: string | null;
  completion_criteria: string | null;
  accommodations: string | null;
  enrichment: string | null;
  published_at?: string | null;
};

export type StudentLessonDelivery = {
  available: boolean;
  delivery_id?: string;
  revision_number?: number;
  lesson: {
    id: string;
    code: string;
    title: string;
    description: string | null;
    week_number: number;
    day_number: number | null;
    sequence: number;
    estimated_minutes: number | null;
    lesson_type: string | null;
  };
  content?: {
    student_goal: string | null;
    materials: string[];
    vocabulary: VocabularyItem[];
    student_learn: string | null;
    guided_practice: string | null;
    independent_practice: string | null;
    activity: string | null;
    worksheet_title: string | null;
    worksheet_instructions: string | null;
    completion_criteria: string | null;
  };
  items?: Array<Omit<LessonPracticeItem, "correct_answer" | "answer_explanation">>;
};
