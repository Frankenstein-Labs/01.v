import { nextTick } from 'vue';
import { setActivePinia, createPinia } from 'pinia';
import { GlChart } from '@gitlab/ui/src/charts';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import TotalRiskScore from 'ee/security_dashboard/components/shared/charts/total_risk_score.vue';
import { useChartExportStore } from 'ee/security_dashboard/stores/chart_export_store';
import { stubComponent } from 'helpers/stub_component';

describe('TotalRiskScore chart', () => {
  const mockSvgData = 'data:svg';
  let wrapper;
  let store;

  const DEFAULT_SCORE = 72;

  const createComponent = (props = {}, mountFn = shallowMountExtended, svgData = mockSvgData) => {
    setActivePinia(createPinia());

    store = useChartExportStore();

    wrapper = mountFn(TotalRiskScore, {
      propsData: {
        score: DEFAULT_SCORE,
        ...props,
      },
      directives: {
        GlResizeObserver: createMockDirective('gl-resize-observer'),
      },
      stubs: {
        GlChart: stubComponent(GlChart, {
          data() {
            return {
              chart: {
                getDataURL: jest.fn(() => svgData),
                resize: jest.fn(),
              },
            };
          },
        }),
      },
    });
  };

  const findGlChart = () => wrapper.findComponent(GlChart);
  const getSeries = () => findGlChart().props('options').series;
  const getOuterMeterSeries = () => getSeries()[0];
  const getProgressMeterSeries = () => getSeries()[1];

  it('renders GlChart responsively', () => {
    createComponent();

    expect(findGlChart().props()).toMatchObject({
      responsive: true,
      height: 'auto',
    });
  });

  describe('outer meter ring', () => {
    it('configures a gauge with the correct dimensions', () => {
      createComponent();

      expect(getOuterMeterSeries()).toMatchObject({
        type: 'gauge',
        startAngle: 220,
        endAngle: -40,
        min: 0,
        max: 100,
        splitNumber: 4,
        center: ['50%', '60%'],
      });
    });

    it('configures the outer meter ring with the correct colors', () => {
      createComponent();

      expect(getOuterMeterSeries().axisLine.lineStyle.color).toEqual([
        [0.25, 'var(--risk-score-color-low)'],
        [0.5, 'var(--risk-score-color-medium)'],
        [0.75, 'var(--risk-score-color-high)'],
        [1, 'var(--risk-score-color-critical)'],
      ]);
    });

    it.each`
      givenScore | expectedLabel      | expectedColor
      ${1}       | ${'Low risk'}      | ${'var(--risk-score-gauge-text-low)'}
      ${26}      | ${'Medium risk'}   | ${'var(--risk-score-gauge-text-medium)'}
      ${51}      | ${'High risk'}     | ${'var(--risk-score-gauge-text-high)'}
      ${76}      | ${'Critical risk'} | ${'var(--risk-score-gauge-text-critical)'}
    `(
      'when the score is "$givenScore", the outer meter ring has the correct title and detail colors',
      ({ givenScore, expectedLabel, expectedColor }) => {
        createComponent({ score: givenScore });

        const outerSeries = getOuterMeterSeries();

        expect(outerSeries.title.color).toBe(expectedColor);
        expect(outerSeries.detail.color).toBe(expectedColor);
        expect(outerSeries.data[0].name).toBe(expectedLabel);
      },
    );
  });

  describe('progress meter ring', () => {
    it('passes the correct data to the progress meter ring', () => {
      createComponent();

      expect(getProgressMeterSeries().data).toEqual([{ value: DEFAULT_SCORE }]);
    });

    it('configures the progress meter ring with the correct dimensions', () => {
      createComponent();

      expect(getProgressMeterSeries()).toMatchObject({
        type: 'gauge',
        startAngle: 220,
        endAngle: -40,
        min: 0,
        max: 100,
      });
    });

    it.each`
      givenScore | expectedColor
      ${1}       | ${'var(--risk-score-color-low)'}
      ${26}      | ${'var(--risk-score-color-medium)'}
      ${51}      | ${'var(--risk-score-color-high)'}
      ${76}      | ${'var(--risk-score-color-critical)'}
    `(
      'when the score is "$givenScore", the progress meter ring has the correct color',
      ({ givenScore, expectedColor }) => {
        createComponent({ score: givenScore });

        const progressSeries = getProgressMeterSeries();

        expect(progressSeries.axisLine.lineStyle.color[0][0]).toEqual(givenScore / 100);
        expect(progressSeries.axisLine.lineStyle.color[0][1]).toEqual(expectedColor);
      },
    );
  });

  describe('chart resizing', () => {
    it.each`
      givenChartWidth | givenChartHeight | expectedOuterRingWidth | expectedProgressRingWidth | expectedOuterRingRadius | expectedProgressRingRadius
      ${400}          | ${200}           | ${15}                  | ${30}                     | ${80}                   | ${64}
      ${200}          | ${100}           | ${8}                   | ${16}                     | ${40}                   | ${31}
      ${2000}         | ${1000}          | ${15}                  | ${30}                     | ${400}                  | ${384}
    `(
      'given a chart width of "$givenChartWidth" and a chart height of "$givenChartHeight", the chart is showing the correct ring widths and radii',
      async ({
        givenChartWidth,
        givenChartHeight,
        expectedOuterRingWidth,
        expectedProgressRingWidth,
        expectedOuterRingRadius,
        expectedProgressRingRadius,
      }) => {
        createComponent();

        const resizeObserverEntry = {
          contentRect: { width: givenChartWidth, height: givenChartHeight },
        };
        getBinding(wrapper.element, 'gl-resize-observer').value(resizeObserverEntry);
        await nextTick();

        const outerSeries = getOuterMeterSeries();
        const progressSeries = getProgressMeterSeries();

        expect(outerSeries.axisLine.lineStyle.width).toBe(expectedOuterRingWidth);
        expect(progressSeries.axisLine.lineStyle.width).toBe(expectedProgressRingWidth);

        expect(outerSeries.radius).toBe(expectedOuterRingRadius);
        expect(progressSeries.radius).toBe(expectedProgressRingRadius);
      },
    );
  });

  describe('chart export store integration', () => {
    beforeEach(() => {
      createComponent({}, mountExtended);
    });

    it('registers and unregisters the chart from the export store on destroy', async () => {
      let exporters = await store.getAll();
      expect(exporters.total_risk_score).toBeDefined();
      wrapper.destroy();
      exporters = await store.getAll();
      expect(exporters.total_risk_score).toBeUndefined();
    });

    it('returns SVG data when the exporter function is called', async () => {
      const exporters = await store.getAll();
      expect(exporters.total_risk_score).toEqual({ svg: mockSvgData });
    });

    describe('SVG top margin trimming', () => {
      // Export canvas is always 600×600.
      // cx=300, cy=360, radius=min(300,300,360,240)=240
      // topTrim=120, diameter=480, newHeight=480, cropHeight=600
      // viewBox = "60 120 480 480"
      const svgContent = `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600"><rect/></svg>`;
      const svgDataUrl = `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svgContent)}`;

      beforeEach(() => {
        createComponent({}, mountExtended, svgDataUrl);
      });

      it('crops top and side whitespace using fixed export geometry', async () => {
        const SVG_DATA_URL_PREFIX = 'data:image/svg+xml;charset=UTF-8,';
        const exporters = await store.getAll();
        const { svg } = exporters.total_risk_score;

        const croppedSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="60 120 480 480"><rect/></svg>`;
        expect(exporters.total_risk_score).toEqual({
          svg: `${SVG_DATA_URL_PREFIX}${encodeURIComponent(croppedSvg)}`,
        });

        const svgString = decodeURIComponent(svg.slice(SVG_DATA_URL_PREFIX.length));
        const doc = new DOMParser().parseFromString(svgString, 'image/svg+xml');
        const svgEl = doc.querySelector('svg');

        expect(svgEl.getAttribute('width')).toBe('600');
        expect(svgEl.getAttribute('height')).toBe('600');
        expect(svgEl.getAttribute('viewBox')).toBe('60 120 480 480');
      });
    });
  });
});
