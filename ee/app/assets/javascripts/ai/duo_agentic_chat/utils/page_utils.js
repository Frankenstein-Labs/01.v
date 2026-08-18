export function getPagePath() {
  return typeof window !== 'undefined' && window.location ? window.location.pathname : '';
}
