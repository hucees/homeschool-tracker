export function StatusPill({
  children,
  tone = "green",
}: {
  children: React.ReactNode;
  tone?: "green" | "amber" | "gray" | "blue";
}) {
  const classes = {
    green: "bg-[#e6f5ee] text-[#17644f] ring-[#4b9b80]/25",
    amber: "bg-[#fff3df] text-[#8b5a18] ring-[#d7a257]/30",
    gray: "bg-[#f1f4f3] text-[#5f6d73] ring-[#74838a]/20",
    blue: "bg-[#eaf2f8] text-[#345f80] ring-[#668ba7]/25",
  }[tone];

  return (
    <span className={`inline-flex max-w-full items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 ring-inset ${classes}`}>
      {children}
    </span>
  );
}
