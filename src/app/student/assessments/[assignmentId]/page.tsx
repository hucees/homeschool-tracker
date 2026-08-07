import Link from "next/link";
import { notFound } from "next/navigation";
import { Brand } from "@/components/brand";
import { StatusPill } from "@/components/status-pill";
import { requireStudent } from "@/lib/auth";
import { submitAssessment } from "./actions";

type Choice = { id: string; label: string };

type AssessmentItem = {
  item_id: string;
  sequence: number;
  question_type: string;
  prompt: string;
  options: Choice[] | unknown;
  points: number;
};

function choices(value: unknown): Choice[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is Choice =>
    typeof item === "object" &&
    item !== null &&
    typeof (item as Choice).id === "string" &&
    typeof (item as Choice).label === "string"
  );
}

export default async function StudentAssessmentPage({
  params,
  searchParams,
}: {
  params: Promise<{ assignmentId: string }>;
  searchParams: Promise<{ submitted?: string; error?: string }>;
}) {
  const { assignmentId } = await params;
  const query = await searchParams;
  const { supabase, student, organization } = await requireStudent();

  const [{ data: assignment }, { data: itemData }] = await Promise.all([
    supabase
      .from("student_assignments")
      .select("id,title,instructions,assignment_type,max_points,assigned_date,due_date,status")
      .eq("organization_id", organization.id)
      .eq("student_id", student.id)
      .eq("id", assignmentId)
      .maybeSingle(),
    supabase.rpc("get_student_assessment_items", {
      p_student_assignment_id: assignmentId,
    }),
  ]);

  if (!assignment) notFound();

  const items = (itemData ?? []) as AssessmentItem[];

  const [{ data: submission }, { data: grade }] = await Promise.all([
    supabase
      .from("assignment_submissions")
      .select("id,submitted_at,auto_points_earned,auto_points_possible,auto_percentage,auto_graded")
      .eq("student_id", student.id)
      .eq("student_assignment_id", assignmentId)
      .order("attempt_number", { ascending: false })
      .limit(1)
      .maybeSingle(),
    supabase
      .from("grade_records")
      .select("id,points_earned,points_possible,percentage,letter_grade,teacher_feedback,grading_source")
      .eq("student_id", student.id)
      .eq("student_assignment_id", assignmentId)
      .eq("status", "current")
      .maybeSingle(),
  ]);

  const canTake = assignment.status === "assigned" && !submission && !grade && items.length > 0;

  return (
    <main className="min-h-screen bg-[#f7f8fb] px-5 py-6">
      <div className="mx-auto max-w-3xl">
        <header className="rounded-2xl border border-[#e4e7ec] bg-white px-5 py-4">
          <Brand />
        </header>

        <div className="mt-6">
          <Link href="/student" className="text-sm font-semibold text-[#315c4d] hover:underline">← Back to student portal</Link>
        </div>

        <section className="mt-5 rounded-2xl border border-[#e4e7ec] bg-white p-6 sm:p-8">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <div className="text-sm font-semibold text-[#315c4d]">ONLINE ASSESSMENT</div>
              <h1 className="mt-1 text-3xl font-bold">{assignment.title}</h1>
              <p className="mt-2 text-sm text-[#667085]">
                {items.length} questions · {assignment.max_points ?? items.reduce((sum, item) => sum + Number(item.points), 0)} points
              </p>
            </div>
            <StatusPill tone={grade ? "green" : "amber"}>
              {grade ? "Graded" : assignment.status}
            </StatusPill>
          </div>

          {assignment.instructions && (
            <p className="mt-4 leading-7 text-[#475467]">{assignment.instructions}</p>
          )}
        </section>

        {query.error && (
          <div className="mt-5 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">{query.error}</div>
        )}

        {(query.submitted || submission || grade) && grade ? (
          <section className="mt-5 rounded-2xl border border-emerald-200 bg-emerald-50 p-6">
            <div className="text-sm font-semibold text-emerald-700">ASSESSMENT COMPLETE</div>
            <div className="mt-2 text-4xl font-bold text-emerald-900">{grade.percentage?.toFixed(1)}%</div>
            <div className="mt-1 text-emerald-800">
              {grade.points_earned}/{grade.points_possible} points · {grade.letter_grade}
            </div>
            <p className="mt-4 text-sm leading-6 text-emerald-800">
              Your answers and this exact version of the assessment have been saved to your school record.
            </p>
            {grade.teacher_feedback && (
              <div className="mt-4 rounded-xl bg-white/70 p-4 text-sm text-emerald-900">
                <strong>Teacher feedback:</strong> {grade.teacher_feedback}
              </div>
            )}
            <Link href="/student" className="mt-5 inline-flex rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white">
              Return to school work
            </Link>
          </section>
        ) : canTake ? (
          <form action={submitAssessment} className="mt-5 grid gap-5">
            <input type="hidden" name="assignment_id" value={assignment.id} />

            {items.map((item) => {
              const itemChoices = choices(item.options);
              return (
                <fieldset key={item.item_id} className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
                  <legend className="sr-only">Question {item.sequence}</legend>
                  <div className="text-xs font-semibold uppercase tracking-wide text-[#667085]">
                    Question {item.sequence} · {Number(item.points)} point{Number(item.points) === 1 ? "" : "s"}
                  </div>
                  <div className="mt-2 text-lg font-bold leading-7">{item.prompt}</div>

                  {item.question_type === "multiple_choice" ? (
                    <div className="mt-4 grid gap-3">
                      {itemChoices.map((choice) => (
                        <label key={choice.id} className="flex cursor-pointer items-center gap-3 rounded-xl border border-[#d0d5dd] p-4 hover:bg-[#f8faf9]">
                          <input
                            type="radio"
                            name={`answer_${item.item_id}`}
                            value={choice.id}
                            required
                            className="h-5 w-5"
                          />
                          <span>{choice.label}</span>
                        </label>
                      ))}
                    </div>
                  ) : (
                    <label className="mt-4 grid gap-1.5 text-sm font-medium">
                      Your answer
                      <input
                        name={`answer_${item.item_id}`}
                        inputMode="numeric"
                        required
                        className="max-w-xs rounded-xl border border-[#d0d5dd] px-3.5 py-3 text-lg"
                      />
                    </label>
                  )}
                </fieldset>
              );
            })}

            <div className="rounded-2xl border border-[#e4e7ec] bg-white p-5">
              <p className="text-sm leading-6 text-[#667085]">
                Check your answers before submitting. This assessment can only be submitted once.
              </p>
              <button className="mt-4 rounded-xl bg-[#315c4d] px-6 py-3 font-semibold text-white hover:bg-[#24483c]">
                Submit assessment
              </button>
            </div>
          </form>
        ) : (
          <section className="mt-5 rounded-2xl border border-[#e4e7ec] bg-white p-6 text-sm text-[#667085]">
            This assessment is not currently available to take online.
          </section>
        )}
      </div>
    </main>
  );
}
