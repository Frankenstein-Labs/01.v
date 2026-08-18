const SVG_DATA_URL_PREFIX = 'data:image/svg+xml;charset=UTF-8,';

/**
 * Resizes an ECharts instance to the given export dimensions, captures its
 * SVG data URL, then restores the chart to its container size.  This
 * guarantees a resolution-independent export regardless of the user's screen.
 */
export const exportChartSvgAtSize = (chart, exportWidth, exportHeight) => {
  if (!chart) return null;

  chart.resize({ width: exportWidth, height: exportHeight });
  const dataUrl = chart.getDataURL({ type: 'svg', excludeComponents: ['toolbox', 'dataZoom'] });
  // Restore auto-sizing: passing 'auto' resets the stored opts so future resize()
  // calls re-read from the DOM container instead of returning the stale export size.
  chart.resize({ width: 'auto', height: 'auto' });

  return dataUrl;
};

/**
 * Crops the blank strip above a gauge SVG by adjusting its viewBox, then
 * re-encodes the result as a data: URL.  Returns the original dataUrl unchanged
 * when no crop is needed or when parsing fails.
 */
export const cropSvgWhitespace = (dataUrl, { cx, cy, exportWidth, exportHeight }) => {
  const radius = Math.min(cx, exportWidth - cx, cy, exportHeight - cy);
  const topTrim = cy - radius;
  if (topTrim <= 0) return dataUrl;

  const svgString = dataUrl.startsWith(SVG_DATA_URL_PREFIX)
    ? decodeURIComponent(dataUrl.slice(SVG_DATA_URL_PREFIX.length))
    : dataUrl;

  // DOMParser.parseFromString turns SVG markup into an in-memory document (a DOM tree) so we can
  // read and mutate the root <svg> element with DOM APIs instead of rewriting the raw string.
  const doc = new DOMParser().parseFromString(svgString, 'image/svg+xml');
  const svgEl = doc.querySelector('svg');
  if (!svgEl) return dataUrl;

  const diameter = radius * 2;
  const newHeight = exportHeight - topTrim;
  const cropHeight = Math.round((newHeight / diameter) * exportWidth);

  svgEl.setAttribute('viewBox', `${cx - radius} ${topTrim} ${diameter} ${newHeight}`);
  svgEl.setAttribute('width', String(exportWidth));
  svgEl.setAttribute('height', String(cropHeight));

  return `${SVG_DATA_URL_PREFIX}${encodeURIComponent(new XMLSerializer().serializeToString(svgEl))}`;
};
