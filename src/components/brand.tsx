export function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex items-center gap-3">
      <div className="grid h-10 w-10 place-items-center rounded-xl bg-[#315c4d] font-bold text-white shadow-sm">
        H
      </div>
      {!compact && (
        <div>
          <div className="font-semibold leading-5">Homeschool Tracker</div>
          <div className="text-xs text-[#667085]">Learning + permanent records</div>
        </div>
      )}
    </div>
  );
}
