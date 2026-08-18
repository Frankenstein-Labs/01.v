// Exports query results as a sanitized CSV file download.
import Papa from 'papaparse';

const FORMULA_PREFIX = /^[=+\-@]/;

function sanitizeValue(val) {
  const str = String(val ?? '');
  return FORMULA_PREFIX.test(str) ? `'${str}` : str;
}

/** Sanitizes pre-flattened row objects for CSV export. */
export function prepareCsvRows(rows) {
  if (!rows?.length) return [];
  return rows.map((row) =>
    Object.fromEntries(Object.entries(row).map(([k, v]) => [k, sanitizeValue(v)])),
  );
}

/** Triggers a browser file download from a CSV string. */
export function triggerCsvDownload(csvString, filename = 'orbit-results.csv') {
  const blob = new Blob([csvString], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

/** Sanitizes pre-flattened rows and triggers a browser download. */
export function downloadCsv(rows, filename = 'orbit-results.csv') {
  const sanitized = prepareCsvRows(rows);
  if (!sanitized.length) return;
  const csv = Papa.unparse(sanitized);
  triggerCsvDownload(csv, filename);
}
