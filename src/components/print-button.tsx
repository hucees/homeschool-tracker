"use client";

export function PrintButton() {
  return (
    <button
      type="button"
      onClick={() => window.print()}
      className="rounded-xl bg-[#315c4d] px-4 py-2.5 text-sm font-semibold text-white hover:bg-[#24483c] print:hidden"
    >
      Print / Save PDF
    </button>
  );
}
