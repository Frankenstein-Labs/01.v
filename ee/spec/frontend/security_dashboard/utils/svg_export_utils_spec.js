import {
  cropSvgWhitespace,
  exportChartSvgAtSize,
} from 'ee/security_dashboard/utils/svg_export_utils';

describe('exportChartSvgAtSize', () => {
  let chart;
  const mockDataUrl = 'data:image/svg+xml,<svg/>';

  beforeEach(() => {
    chart = {
      getDataURL: jest.fn(() => mockDataUrl),
      resize: jest.fn(),
    };
  });

  it('returns null when chart is falsy', () => {
    expect(exportChartSvgAtSize(null, 600, 400)).toBeNull();
    expect(exportChartSvgAtSize(undefined, 600, 400)).toBeNull();
  });

  it('resizes to the export dimensions before capturing', () => {
    exportChartSvgAtSize(chart, 600, 500);

    expect(chart.resize).toHaveBeenCalledWith({ width: 600, height: 500 });
  });

  it('calls getDataURL after the resize', () => {
    exportChartSvgAtSize(chart, 600, 500);

    expect(chart.getDataURL).toHaveBeenCalledWith({
      type: 'svg',
      excludeComponents: ['toolbox', 'dataZoom'],
    });
  });

  it('restores the chart to auto-sizing after capturing', () => {
    exportChartSvgAtSize(chart, 600, 500);

    expect(chart.resize).toHaveBeenLastCalledWith({ width: 'auto', height: 'auto' });
  });

  it('returns the data URL from getDataURL', () => {
    expect(exportChartSvgAtSize(chart, 600, 500)).toBe(mockDataUrl);
  });
});

describe('cropSvgWhitespace', () => {
  const SVG_DATA_URL_PREFIX = 'data:image/svg+xml;charset=UTF-8,';
  const exportWidth = 600;
  const exportHeight = 600;
  // cx = 600*0.5 = 300, cy = 600*0.6 = 360, radius = min(300,300,360,240) = 240
  const cx = 300;
  const cy = 360;

  const makeSvgDataUrl = (svgBody = '') =>
    `${SVG_DATA_URL_PREFIX}${encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600">${svgBody}</svg>`)}`;

  const opts = (overrides = {}) => ({ cx, cy, exportWidth, exportHeight, ...overrides });

  it('returns the original dataUrl when topTrim <= 0', () => {
    // cy=100, radius=min(300,300,100,500)=100 → topTrim=0
    const dataUrl = makeSvgDataUrl();
    expect(cropSvgWhitespace(dataUrl, opts({ cy: 100 }))).toBe(dataUrl);
  });

  it('returns the original dataUrl when the SVG cannot be parsed', () => {
    const dataUrl = `${SVG_DATA_URL_PREFIX}${encodeURIComponent('not valid svg')}`;
    expect(cropSvgWhitespace(dataUrl, opts())).toBe(dataUrl);
  });

  it('returns a data: URL after cropping', () => {
    const result = cropSvgWhitespace(makeSvgDataUrl(), opts());
    expect(result).toMatch(/^data:image\/svg\+xml;charset=UTF-8,/);
  });

  it('sets the cropped viewBox on the SVG element', () => {
    const result = cropSvgWhitespace(makeSvgDataUrl(), opts());
    const svgString = decodeURIComponent(result.slice(SVG_DATA_URL_PREFIX.length));
    const svgEl = new DOMParser().parseFromString(svgString, 'image/svg+xml').querySelector('svg');
    // radius=240, topTrim=120, diameter=480, newHeight=480
    expect(svgEl.getAttribute('viewBox')).toBe('60 120 480 480');
  });

  it('sets the correct width and height on the SVG element', () => {
    const result = cropSvgWhitespace(makeSvgDataUrl(), opts());
    const svgString = decodeURIComponent(result.slice(SVG_DATA_URL_PREFIX.length));
    const svgEl = new DOMParser().parseFromString(svgString, 'image/svg+xml').querySelector('svg');
    expect(svgEl.getAttribute('width')).toBe('600');
    // cropHeight = round((480/480)*600) = 600
    expect(svgEl.getAttribute('height')).toBe('600');
  });
});
