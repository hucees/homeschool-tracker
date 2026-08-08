export function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex min-w-0 items-center gap-3">
      <div className="grid h-10 w-10 shrink-0 place-items-center rounded-2xl bg-gradient-to-br from-[#23685a] to-[#456f91] font-bold text-white shadow-[0_8px_22px_rgba(35,104,90,0.22)]">
        H
      </div>
      {!compact && (
        <div className="min-w-0">
          <div className="truncate font-bold leading-5 text-[#172329]">Homeschool Tracker</div>
          <div className="truncate text-xs text-[#617078]">Learning + permanent records</div>
        </div>
      )}
    </div>
  );
}
