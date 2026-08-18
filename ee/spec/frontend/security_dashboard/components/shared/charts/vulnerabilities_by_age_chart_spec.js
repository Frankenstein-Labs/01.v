import { nextTick } from 'vue';
import { setActivePinia, createPinia } from 'pinia';
import { GlStackedColumnChart } from '@gitlab/ui/src/charts';
import { shallowMount, mountExtended } from '@vue/test-utils';
import { GRAY_500 } from '@gitlab/ui/src/tokens/build/js/tokens';
import VulnerabilitiesByAgeChart from 'ee/security_dashboard/components/shared/charts/vulnerabilities_by_age_chart.vue';
import * as ChartUtils from 'ee/security_dashboard/utils/chart_utils';
import { REPORT_TYPE_COLORS } from 'ee/security_dashboard/components/shared/vulnerability_report/constants';
import {
  listenSystemColorSchemeChange,
  removeListenerSystemColorSchemeChange,
} from '~/lib/utils/css_utils';
import { useChartExportStore } from 'ee/security_dashboard/stores/chart_export_store';
import { stubComponent } from 'helpers/stub_component';

const mockSeverityColors = {
  critical: '#000000',
  high: '#111111',
  medium: '#222222',
  low: '#333333',
  info: '#444444',
  unknown: '#555555',
};
jest.mock('~/lib/utils/css_utils');

describe('VulnerabilitiesByAgeChart', () => {
  const mockSvgData = 'data:svg';
  let wrapper;
  let store;
  let getDataURL;

  const mockBars = [
    { name: 'Critical', id: 'CRITICAL', data: [10, 5] },
    { name: 'High', id: 'HIGH', data: [15, 20] },
  ];
  const mockLabels = ['<7 days', '7-14 days'];

  const findStackedColumnChart = () => wrapper.findComponent(GlStackedColumnChart);

  const defaultProps = {
    bars: mockBars,
    labels: mockLabels,
  };

  beforeEach(() => {
    jest.spyOn(ChartUtils, 'getSeverityColors').mockImplementation(() => mockSeverityColors);
  });

  const createComponent = ({ props = {} } = {}, mountFn = shallowMount) => {
    setActivePinia(createPinia());

    store = useChartExportStore();
    getDataURL = jest.fn(() => mockSvgData);

    wrapper = mountFn(VulnerabilitiesByAgeChart, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlStackedColumnChart: stubComponent(GlStackedColumnChart, {
          data() {
            return {
              chart: {
                getDataURL,
              },
            };
          },
        }),
      },
    });
  };

  it('passes bars to GlStackedColumnChart', () => {
    createComponent();
    expect(findStackedColumnChart().props('bars')).toBe(mockBars);
  });

  it('passes labels to GlStackedColumnChart', () => {
    createComponent();
    expect(findStackedColumnChart().props('groupBy')).toBe(mockLabels);
  });

  describe('customPalette', () => {
    it.each([
      ['Critical', 'CRITICAL', mockSeverityColors.critical],
      ['High', 'HIGH', mockSeverityColors.high],
      ['Medium', 'MEDIUM', mockSeverityColors.medium],
      ['Low', 'LOW', mockSeverityColors.low],
      ['Info', 'INFO', mockSeverityColors.info],
      ['Unknown', 'UNKNOWN', mockSeverityColors.unknown],
      ['ApiFuzzing', 'API_FUZZING', REPORT_TYPE_COLORS.apiFuzzing],
      ['ContainerScanning', 'CONTAINER_SCANNING', REPORT_TYPE_COLORS.containerScanning],
      [
        'ContainerScanningForRegistry',
        'CONTAINER_SCANNING_FOR_REGISTRY',
        REPORT_TYPE_COLORS.containerScanningForRegistry,
      ],
      ['CoverageFuzzing', 'COVERAGE_FUZZING', REPORT_TYPE_COLORS.coverageFuzzing],
      ['Dast', 'DAST', REPORT_TYPE_COLORS.dast],
      ['DependencyScanning', 'DEPENDENCY_SCANNING', REPORT_TYPE_COLORS.dependencyScanning],
      ['Sast', 'SAST', REPORT_TYPE_COLORS.sast],
      ['SecretDetection', 'SECRET_DETECTION', REPORT_TYPE_COLORS.secretDetection],
    ])('applies the correct color for "%s" series', async (seriesName, seriesId, expectedColor) => {
      const bars = [{ name: seriesName, id: seriesId, data: [] }];

      createComponent({ props: { bars } });
      await nextTick();

      expect(findStackedColumnChart().props('customPalette')).toEqual([expectedColor]);
    });

    it('uses fallback color for unknown series', () => {
      const bars = [{ name: 'Unknown Type', id: 'UNKNOWN_TYPE', data: [] }];

      createComponent({ props: { bars } });

      expect(findStackedColumnChart().props('customPalette')).toEqual([GRAY_500]);
    });

    it('returns colors in the same order as bars', async () => {
      const bars = [
        { name: 'High', id: 'HIGH', data: [] },
        { name: 'Critical', id: 'CRITICAL', data: [] },
      ];

      createComponent({ props: { bars } });
      await nextTick();

      expect(findStackedColumnChart().props('customPalette')).toEqual([
        mockSeverityColors.high,
        mockSeverityColors.critical,
      ]);
    });
  });

  describe('system color scheme change listener', () => {
    it('calls "listenSystemColorSchemeChange" when mounted', () => {
      createComponent();
      expect(listenSystemColorSchemeChange).toHaveBeenCalled();
    });

    it('calls "removeListenerSystemColorSchemeChange" when component is destroyed', () => {
      createComponent();
      wrapper.destroy();

      expect(removeListenerSystemColorSchemeChange).toHaveBeenCalled();
    });
  });

  describe('chart export store integration', () => {
    beforeEach(async () => {
      createComponent({}, mountExtended);
      await nextTick();
    });

    it('registers and unregisters the chart from the export store on destroy', async () => {
      let exporters = await store.getAll();
      expect(exporters.vulnerabilities_by_age).toBeDefined();
      wrapper.destroy();
      exporters = await store.getAll();
      expect(exporters.vulnerabilities_by_age).toBeUndefined();
    });

    it('returns SVG data when the exporter function is called', async () => {
      const exporters = await store.getAll();
      expect(exporters.vulnerabilities_by_age).toEqual({ svg: mockSvgData });
      expect(getDataURL).toHaveBeenCalledWith({
        excludeComponents: ['toolbox', 'dataZoom'],
        type: 'svg',
      });
    });
  });
});
