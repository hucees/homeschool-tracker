export function StatusPill({ children, tone = "green" }: { children: React.ReactNode; tone?: "green" | "amber" | "gray" }) {
  const classes = {
    green: "bg-emerald-50 text-emerald-700 ring-emerald-600/20",
    amber: "bg-amber-50 text-amber-700 ring-amber-600/20",
    gray: "bg-slate-50 text-slate-600 ring-slate-500/20",
  }[tone];

  return <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-medium ring-1 ring-inset ${classes}`}>{children}</span>;
}
