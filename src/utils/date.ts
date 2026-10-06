export function formatFrontmatterDate(date: Date): string {
  return `${date
    .toLocaleDateString("fr-FR", {
      month: "short",
      day: "numeric",
      year: "numeric",
    })
    .toUpperCase()} à ${date.toLocaleTimeString("fr-FR", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  })}`;
}
