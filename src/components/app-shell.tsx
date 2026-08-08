import Link from "next/link";
import { Brand } from "@/components/brand";
import { signOut } from "@/actions/auth";

const nav = [
  ["Dashboard", "/dashboard"],
  ["Students", "/dashboard/students"],
  ["Daily review", "/dashboard/daily"],
  ["Curriculum", "/dashboard/curriculum"],
  ["Reports", "/dashboard#reports"],
];

function NavLinks({ mobile = false }: { mobile?: boolean }) {
  return (
    <nav className={mobile ? "flex min-w-max gap-2" : "grid gap-1.5"}>
      {nav.map(([label, href]) => (
        <Link
          key={href}
          href={href}
          className={
            mobile
              ? "rounded-xl border border-[#dfe7e3] bg-white px-3.5 py-2.5 text-sm font-semibold text-[#34484f] shadow-sm hover:border-[#b9cec5] hover:bg-[#edf7f3]"
              : "rounded-xl px-3 py-2.5 text-sm font-semibold text-[#405158] transition hover:bg-[#edf7f3] hover:text-[#174d43]"
          }
        >
          {label}
        </Link>
      ))}
    </nav>
  );
}

export function AppShell({
  children,
  organizationName,
}: {
  children: React.ReactNode;
  organizationName?: string;
}) {
  return (
    <div className="min-h-screen">
      <header className="sticky top-0 z-40 border-b border-[#dfe7e3]/90 bg-white/90 backdrop-blur-xl">
        <div className="mx-auto flex max-w-[1440px] items-center justify-between gap-3 px-3 py-3 sm:px-5 lg:px-8">
          <Brand />
          <div className="flex min-w-0 items-center gap-2 sm:gap-3">
            {organizationName && (
              <span className="hidden max-w-56 truncate rounded-full bg-[#f3f6f4] px-3 py-1.5 text-xs font-semibold text-[#617078] sm:inline">
                {organizationName}
              </span>
            )}
            <form action={signOut}>
              <button className="rounded-xl border border-[#cbd8d2] bg-white px-3 py-2 text-sm font-semibold text-[#405158] transition hover:border-[#9db9ad] hover:bg-[#f6faf8] sm:px-4">
                Sign out
              </button>
            </form>
          </div>
        </div>
      </header>

      <div className="border-b border-[#dfe7e3] bg-white/55 px-3 py-2 md:hidden">
        <div className="mobile-scrollbar-none mx-auto max-w-[1440px] overflow-x-auto">
          <NavLinks mobile />
        </div>
      </div>

      <div className="mx-auto grid max-w-[1440px] gap-6 px-3 py-4 sm:px-5 sm:py-6 md:grid-cols-[200px_minmax(0,1fr)] lg:gap-8 lg:px-8">
        <aside className="app-surface hidden self-start rounded-2xl p-3 md:sticky md:top-[88px] md:block md:min-h-[calc(100vh-116px)]">
          <div className="mb-3 px-3 pt-2 text-[11px] font-bold uppercase tracking-[0.15em] text-[#829098]">
            Instructor
          </div>
          <NavLinks />
        </aside>
        <main className="min-w-0">{children}</main>
      </div>
    </div>
  );
}
