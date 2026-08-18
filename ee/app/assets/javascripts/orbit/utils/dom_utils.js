/**
 * Measures the height of the static Orbit chrome (header row + tab bar +
 * padding) so the map canvas can be sized to fill the remaining viewport.
 *
 * "Static" means everything in the chrome wrapper except the connect section,
 * which is collapsible and must not affect the map height.
 *
 * @param {Element} orbitApp   - the .orbit-app root element
 * @param {Element} chromeWrapper - [data-testid="orbit-chrome-wrapper"]
 * @param {number}  belowMapPx - extra px below the map (gap + status bar)
 * @returns {number} total chrome height in px, or 0 if elements are missing
 */
export function measureOrbitChromeHeight(orbitApp, chromeWrapper, belowMapPx) {
  if (!orbitApp || !chromeWrapper) return 0;

  const paddingTop = parseInt(getComputedStyle(orbitApp).paddingTop, 10) || 0;
  const gap = parseInt(getComputedStyle(chromeWrapper).gap, 10) || 8;

  const staticEls = Array.from(chromeWrapper.children).filter(
    (child) => child.dataset.testid !== 'connect-section',
  );

  const childrenHeight = staticEls.reduce((sum, el) => sum + el.getBoundingClientRect().height, 0);
  const gapHeight = gap * Math.max(0, staticEls.length - 1);

  return Math.round(paddingTop + childrenHeight + gapHeight) + belowMapPx;
}
