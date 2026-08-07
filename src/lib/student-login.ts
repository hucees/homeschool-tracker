export function normalizeStudentUsername(value: string) {
  return value.trim().toLowerCase();
}

export function isValidStudentUsername(value: string) {
  return /^[a-z0-9][a-z0-9._-]{2,19}$/.test(value);
}

export function studentAuthEmail(organizationId: string, username: string) {
  const orgToken = organizationId.replaceAll("-", "");
  return `s.${orgToken}.${normalizeStudentUsername(username)}@students.homeschooltracker.app`;
}

export function localDateInTimezone(timezone: string, date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);

  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}
