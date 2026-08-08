"use client";

export function PrintButton({ label = "Print / Save PDF" }: { label?: string }) {
  return (
    <button
      type="button"
      onClick={() => window.print()}
      className="print-hidden inline-flex items-center justify-center rounded-xl bg-[#23685a] px-4 py-2.5 text-sm font-bold text-white shadow-sm transition hover:bg-[#174d43]"
    >
      {label}
    </button>
  );
}
