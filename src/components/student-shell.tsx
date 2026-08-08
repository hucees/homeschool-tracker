import Link from "next/link";
import { Brand } from "@/components/brand";
import { studentSignOut } from "@/app/student/actions";

const nav = [
  ["School work", "/student"],
  ["Progress & reports", "/student/progress"],
];

export function StudentShell({
  children,
  studentName,
  organizationName,
}: {
  children: React.ReactNode;
  studentName: string;
  organizationName: string;
}) {
  return (
    <main className="min-h-screen">
      <header className="print-hidden sticky top-0 z-40 border-b border-[#dfe7e3]/90 bg-white/92 backdrop-blur-xl">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-3 py-3 sm:px-5">
          <Brand />
          <div className="flex min-w-0 items-center gap-2">
            <div className="hidden min-w-0 text-right sm:block">
              <div className="truncate text-sm font-bold text-[#26363d]">{studentName}</div>
              <div className="truncate text-xs text-[#718087]">{organizationName}</div>
            </div>
            <form action={studentSignOut}>
              <button className="rounded-xl border border-[#cbd8d2] bg-white px-3 py-2 text-sm font-semibold text-[#405158] hover:bg-[#f6faf8]">
                Sign out
              </button>
            </form>
          </div>
        </div>

        <div className="border-t border-[#edf1ef] bg-[#f9fbfa]">
          <div className="mobile-scrollbar-none mx-auto flex max-w-6xl gap-2 overflow-x-auto px-3 py-2 sm:px-5">
            {nav.map(([label, href]) => (
              <Link
                key={href}
                href={href}
                className="whitespace-nowrap rounded-xl px-3.5 py-2 text-sm font-semibold text-[#456069] transition hover:bg-[#e5f3ed] hover:text-[#174d43]"
              >
                {label}
              </Link>
            ))}
          </div>
        </div>
      </header>

      <div className="mx-auto w-full max-w-6xl px-3 py-4 sm:px-5 sm:py-7">
        {children}
      </div>
    </main>
  );
}
