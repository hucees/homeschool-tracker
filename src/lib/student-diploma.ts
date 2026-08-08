import type { StudentTranscriptSnapshot } from "@/lib/student-transcript";

export type DiplomaSnapshot = {
  schema_version: 1;
  generated_at: string;
  organization: {
    id: string;
    name: string;
    timezone: string;
  };
  student: {
    id: string;
    student_number: string;
    legal_name: string;
    preferred_name: string | null;
  };
  diploma: {
    title: string;
    statement: string;
    honors: string | null;
    signatory_name: string;
    signatory_title: string;
  };
  academic_record: StudentTranscriptSnapshot;
  diploma_number?: string;
  version?: number;
  graduation_date?: string;
  issue_date?: string;
  issued_at?: string;
};

export function buildDiplomaSnapshot({
  transcript,
  title,
  statement,
  honors,
  signatoryName,
  signatoryTitle,
  graduationDate,
  markGraduated,
}: {
  transcript: StudentTranscriptSnapshot;
  title: string;
  statement: string;
  honors: string | null;
  signatoryName: string;
  signatoryTitle: string;
  graduationDate: string;
  markGraduated: boolean;
}): DiplomaSnapshot {
  const legalName = [
    transcript.student.first_name,
    transcript.student.middle_name,
    transcript.student.last_name,
  ]
    .filter(Boolean)
    .join(" ");

  return {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    organization: transcript.organization,
    student: {
      id: transcript.student.id,
      student_number: transcript.student.student_number,
      legal_name: legalName,
      preferred_name: transcript.student.preferred_name,
    },
    diploma: {
      title,
      statement,
      honors,
      signatory_name: signatoryName,
      signatory_title: signatoryTitle,
    },
    academic_record: markGraduated
      ? {
          ...transcript,
          student: {
            ...transcript.student,
            status: "graduated",
            graduation_date: graduationDate,
          },
        }
      : transcript,
  };
}
