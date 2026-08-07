import Link from "next/link";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { StatusPill } from "@/components/status-pill";
import { requireOrganization } from "@/lib/auth";

type Choice = { id: string; label: string };

function choices(value: unknown): Choice[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is Choice =>
    typeof item === "object" &&
    item !== null &&
    typeof (item as Choice).id === "string" &&
    typeof (item as Choice).label === "string"
  );
}

function answerLabel(options: unknown, value: string | null) {
  if (!value) return "No answer";
  return choices(options).find((choice) => choice.id === value)?.label ?? value;
}

export default async function InstructorAssessmentReviewPage({
  params,
}: {
  params: Promise<{ studentId: string; assignmentId: string }>;
}) {
  const { studentId, assignmentId } = await params;
  const { supabase, organization } = await requireOrganization();

  const [{ data: student }, { data: assignment }, { data: grade }, { data: submission }] = await Promise.all([
    supabase
      .from("students")
      .select("id,first_name,last_name,preferred_name,student_number")
      .eq("organization_id", organization.id)
      .eq("id", studentId)
      .maybeSingle(),
    supabase
      .from("student_assignments")
      .select("id,title,assignment_type,max_points,assigned_date,due_date,status,curriculum_instance_number")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .eq("id", assignmentId)
      .maybeSingle(),
    supabase
      .from("grade_records")
      .select("id,points_earned,points_possible,percentage,letter_grade,teacher_feedback,graded_at,grading_source,revision_number")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .eq("student_assignment_id", assignmentId)
      .eq("status", "current")
      .maybeSingle(),
    supabase
      .from("assignment_submissions")
      .select("id,submitted_at,auto_graded")
      .eq("organization_id", organization.id)
      .eq("student_id", studentId)
      .eq("student_assignment_id", assignmentId)
      .order("attempt_number", { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);

  if (!student || !assignment) notFound();

  const { data: itemData } = await supabase
    .from("student_assignment_items")
    .select("id,source_code,sequence,question_type,prompt,options,correct_answer,points")
    .eq("organization_id", organization.id)
    .eq("student_id", studentId)
    .eq("student_assignment_id", assignmentId)
    .order("sequence");

  const items = itemData ?? [];

  let responses: {
    student_assignment_item_id: string;
    response_value: string | null;
    is_correct: boolean;
    points_earned: number;
  }[] = [];

  if (submission?.id) {
    const { data } = await supabase
      .from("assignment_item_responses")
      .select("student_assignment_item_id,response_value,is_correct,points_earned")
      .eq("assignment_submission_id", submission.id);
    responses = data ?? [];
  }

  const responseByItem = new Map(responses.map((response) => [response.student_assignment_item_id, response]));

  return (
    <AppShell organizationName={organization.name}>
      <div className="grid gap-6">
        <div>
          <Link href={`/dashboard/students/${studentId}/gradebook`} className="text-sm font-semibold text-[#315c4d] hover:underline">
            ← Back to gradebook
          </Link>
        </div>

        <section className="rounded-2xl border border-[#e4e7ec] bg-white p-6 sm:p-8">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <p className="text-sm font-medium text-[#667085]">
                {student.preferred_name || student.first_name} {student.last_name} · Assessment review
              </p>
              <h1 className="mt-1 text-3xl font-bold">{assignment.title}</h1>
              <p className="mt-2 text-sm text-[#667085]">
                {student.student_number} · Assigned {assignment.assigned_date}
                {submission?.submitted_at ? ` · Submitted ${new Date(submission.submitted_at).toLocaleString()}` : ""}
              </p>
            </div>

            {grade ? (
              <div className="text-right">
                <div className="text-3xl font-bold">{grade.percentage?.toFixed(1)}%</div>
                <div className="text-sm text-[#667085]">
                  {grade.points_earned}/{grade.points_possible} · {grade.letter_grade}
                </div>
                <div className="mt-2">
                  <StatusPill tone={grade.grading_source === "automatic" ? "green" : "gray"}>
                    {grade.grading_source === "automatic" ? "Auto-scored" : "Instructor graded"}
                  </StatusPill>
                </div>
              </div>
            ) : (
              <StatusPill tone="amber">Not graded</StatusPill>
            )}
          </div>
        </section>

        <section className="grid gap-4">
          {items.length ? items.map((item) => {
            const response = responseByItem.get(item.id);
            return (
              <article key={item.id} className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <div className="text-xs font-semibold uppercase tracking-wide text-[#667085]">
                      Question {item.sequence} · {item.source_code}
                    </div>
                    <div className="mt-2 text-lg font-bold">{item.prompt}</div>
                  </div>
                  {response ? (
                    <StatusPill tone={response.is_correct ? "green" : "amber"}>
                      {response.is_correct ? "Correct" : "Incorrect"}
                    </StatusPill>
                  ) : (
                    <StatusPill tone="gray">No online response</StatusPill>
                  )}
                </div>

                {item.question_type === "multiple_choice" && (
                  <div className="mt-4 grid gap-2">
                    {choices(item.options).map((choice) => (
                      <div
                        key={choice.id}
                        className={`rounded-xl border p-3 text-sm ${
                          choice.id === item.correct_answer
                            ? "border-emerald-200 bg-emerald-50"
                            : "border-[#eaecf0]"
                        }`}
                      >
                        {choice.label}
                        {choice.id === item.correct_answer ? " — Correct answer" : ""}
                      </div>
                    ))}
                  </div>
                )}

                <div className="mt-4 grid gap-3 rounded-xl bg-[#f8faf9] p-4 text-sm md:grid-cols-2">
                  <div>
                    <span className="font-semibold">Student answer:</span>{" "}
                    {answerLabel(item.options, response?.response_value ?? null)}
                  </div>
                  <div>
                    <span className="font-semibold">Correct answer:</span>{" "}
                    {answerLabel(item.options, item.correct_answer)}
                  </div>
                </div>
              </article>
            );
          }) : (
            <div className="rounded-2xl border border-[#e4e7ec] bg-white p-6 text-sm text-[#667085]">
              This assignment does not contain an online question snapshot.
            </div>
          )}
        </section>

        {grade?.teacher_feedback && (
          <section className="rounded-2xl border border-[#e4e7ec] bg-white p-6">
            <h2 className="font-bold">Teacher feedback</h2>
            <p className="mt-2 text-sm leading-6 text-[#475467]">{grade.teacher_feedback}</p>
          </section>
        )}
      </div>
    </AppShell>
  );
}
