import Link from "next/link";
import { Brand } from "@/components/brand";
import { signOut } from "@/actions/auth";

const nav = [
  ["Dashboard", "/dashboard"],
  ["Students", "/dashboard/students"],
  ["Daily review", "/dashboard/daily"],
  ["Curriculum", "/dashboard#curriculum"],
  ["Reports", "/dashboard#reports"],
];

export function AppShell({ children, organizationName }: { children: React.ReactNode; organizationName?: string }) {
  return (
    <div className="min-h-screen bg-[#f7f8fb]">
      <header className="border-b border-[#e4e7ec] bg-white">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-5 py-4">
          <Brand />
          <div className="flex items-center gap-3 text-sm">
            {organizationName && <span className="hidden text-[#667085] sm:inline">{organizationName}</span>}
            <form action={signOut}>
              <button className="rounded-lg border border-[#d0d5dd] bg-white px-3 py-2 font-medium hover:bg-slate-50">Sign out</button>
            </form>
          </div>
        </div>
      </header>
      <div className="mx-auto grid max-w-7xl gap-6 px-5 py-6 md:grid-cols-[190px_1fr]">
        <aside className="rounded-2xl border border-[#e4e7ec] bg-white p-3 md:min-h-[calc(100vh-120px)]">
          <nav className="grid gap-1">
            {nav.map(([label, href]) => (
              <Link key={href} href={href} className="rounded-xl px-3 py-2.5 text-sm font-medium text-[#344054] hover:bg-[#f2f4f7]">{label}</Link>
            ))}
          </nav>
        </aside>
        <main>{children}</main>
      </div>
    </div>
  );
}
