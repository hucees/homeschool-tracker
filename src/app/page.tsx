import Link from "next/link";
import { Brand } from "@/components/brand";
import { isSupabaseConfigured } from "@/lib/env";

export default function Home() {
  const configured = isSupabaseConfigured();

  return (
    <main className="min-h-screen bg-[linear-gradient(135deg,#f7f8fb_0%,#eef5f1_100%)] px-5 py-10">
      <div className="mx-auto max-w-5xl">
        <nav className="flex items-center justify-between">
          <Brand />
          <Link href="/login" className="rounded-xl bg-[#315c4d] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[#24483c]">Instructor login</Link>
        </nav>

        <section className="grid gap-10 py-20 lg:grid-cols-[1.2fr_.8fr] lg:items-center">
          <div>
            <div className="mb-4 inline-flex rounded-full bg-[#e8f2ed] px-3 py-1 text-sm font-medium text-[#315c4d]">K–12 homeschool record platform</div>
            <h1 className="max-w-3xl text-4xl font-bold tracking-tight text-[#18212f] sm:text-6xl">One permanent record of what each student actually learns.</h1>
            <p className="mt-6 max-w-2xl text-lg leading-8 text-[#667085]">Curriculum, daily learning logs, attendance, assignments, mastery, reports, promotion decisions, and transcripts—built around historical records that are never silently overwritten.</p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link href="/login" className="rounded-xl bg-[#315c4d] px-5 py-3 font-semibold text-white hover:bg-[#24483c]">Open instructor portal</Link>
              <Link href="/student/login" className="rounded-xl border border-[#d0d5dd] bg-white px-5 py-3 font-semibold text-[#344054] hover:bg-slate-50">Student portal</Link>
            </div>
          </div>

          <div className="rounded-3xl border border-[#dce5df] bg-white p-6 shadow-xl shadow-slate-200/50">
            <div className="text-sm font-semibold text-[#667085]">Starter status</div>
            <div className="mt-4 grid gap-3">
              {[
                ["Next.js application", true],
                ["Supabase SSR wiring", true],
                ["Migrations 001–006", true],
                ["Supabase credentials", configured],
                ["Hosted database applied", false],
              ].map(([label, done]) => (
                <div key={String(label)} className="flex items-center justify-between rounded-xl border border-[#eaecf0] px-4 py-3">
                  <span className="text-sm font-medium">{label}</span>
                  <span className={`text-sm font-semibold ${done ? "text-emerald-600" : "text-amber-600"}`}>{done ? "Ready" : "Next"}</span>
                </div>
              ))}
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}
