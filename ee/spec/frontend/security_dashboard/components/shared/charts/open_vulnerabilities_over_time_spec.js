import { nextTick } from 'vue';
import { setActivePinia, createPinia } from 'pinia';
import { GlLink } from '@gitlab/ui';
import { GlLineChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import OpenVulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import * as ChartUtils from 'ee/security_dashboard/utils/chart_utils';
import {
  listenSystemColorSchemeChange,
  removeListenerSystemColorSchemeChange,
} from '~/lib/utils/css_utils';
import { REPORT_TYPE_COLORS } from 'ee/security_dashboard/components/shared/vulnerability_report/constants';
import { useChartExportStore } from 'ee/security_dashboard/stores/chart_export_store';

const mockSeverityColors = {
  critical: '#000000',
  high: '#111111',
  medium: '#222222',
  low: '#333333',
  info: '#444444',
  unknown: '#555555',
};
jest.mock('~/lib/utils/css_utils');

describe('OpenVulnerabilitiesOverTimeChart', () => {
  let wrapper;
  let store;

  const firstDayOfChartSeries = '2025-04-17';
  const mockChartSeries = [
    {
      name: 'Critical',
      id: 'CRITICAL',
      data: [
        [firstDayOfChartSeries, 5],
        ['2025-04-18', 5],
        ['2025-04-19', 7],
      ],
    },
    {
      name: 'High',
      id: 'HIGH',
      data: [
        [firstDayOfChartSeries, 25],
        ['2025-04-18', 27],
        ['2025-04-19', 30],
      ],
    },
  ];

  const findLineChart = () => wrapper.findComponent(GlLineChart);

  const defaultProps = {
    chartSeries: mockChartSeries,
    groupedBy: 'severity',
  };

  const defaultProvide = {
    securityVulnerabilitiesPath: 'namespace/security/vulnerabilities',
  };

  beforeEach(() => {
    setActivePinia(createPinia());
    jest.spyOn(ChartUtils, 'getSeverityColors').mockImplementation(() => mockSeverityColors);
  });

  const createComponent = ({ props = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = shallowMount(OpenVulnerabilitiesOverTimeChart, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        ...stubs,
      },
    });
  };

  it.each(mockChartSeries)('passes chart data to GlLineChart via props', (expectedSeries) => {
    createComponent();

    const chartData = findLineChart().props('data');
    const chartSeries = chartData.find((series) => series.name === expectedSeries.name);

    // Note: using `toMatchObject`, because in some cases we dynamically augment the series with additional data (e.g. color). This is tested separately below
    expect(chartSeries).toMatchObject(expectedSeries);
  });

  it('does not include legend avg/max values', () => {
    createComponent();

    expect(findLineChart().props('includeLegendAvgMax')).toBe(false);
  });

  it('enables the chart to have click-to-pin tooltip functionality so links within the tooltip can be accessed', () => {
    createComponent();

    expect(findLineChart().props('clickToPinTooltip')).toBe(true);
  });

  describe('tooltip configuration', () => {
    describe('tooltip content', () => {
      const mockTooltipParams = {
        seriesName: 'Severity',
        color: 'red',
        value: ['2025-04-18', 5],
        seriesId: 'CRITICAL',
      };

      const createComponentWithStubbedTooltip = ({ props = {}, provide = {} } = {}) => {
        createComponent({
          props,
          provide,
          stubs: {
            GlLineChart: stubComponent(GlLineChart, {
              data() {
                return {
                  params: {
                    seriesData: [mockTooltipParams],
                  },
                };
              },
              template: `
                <div>
                  <slot name="tooltip-content" :params="params"></slot>
                </div>`,
            }),
          },
        });
      };

      describe('when there is a securityVulnerabilitiesPath provided', () => {
        it('renders the chart label correctly', () => {
          createComponentWithStubbedTooltip();

          expect(wrapper.findComponent(GlChartSeriesLabel).text()).toBe(
            mockTooltipParams.seriesName,
          );
          expect(wrapper.findComponent(GlChartSeriesLabel).props('color')).toBe(
            mockTooltipParams.color,
          );
        });

        describe('link to vulnerabilities report', () => {
          const findLinkToVulnerabilitiesReport = () =>
            wrapper.findComponent(GlLink).attributes('href');

          it('renders the tooltip content with the correct link', () => {
            createComponentWithStubbedTooltip();

            expect(wrapper.findComponent(GlLink).text()).toBe(`${mockTooltipParams.value[1]}`);
            expect(findLinkToVulnerabilitiesReport()).toBe(
              `${defaultProvide.securityVulnerabilitiesPath}?${defaultProps.groupedBy}=${mockTooltipParams.seriesId}`,
            );
          });

          it('adds additional filters to the link when they are provided', () => {
            createComponentWithStubbedTooltip({
              props: { filters: { projectId: '123' } },
            });

            expect(wrapper.findComponent(GlLink).attributes('href')).toContain('&projectId=123');
          });

          it('does not add the additional filter if it has the same key as the `groupedBy` prop', () => {
            createComponentWithStubbedTooltip({
              props: { filters: { severity: ['SHOULD_NOT_BE_ADDED'] }, groupedBy: 'severity' },
            });

            expect(findLinkToVulnerabilitiesReport()).toContain(
              `?severity=${mockTooltipParams.seriesId}`,
            );
            expect(findLinkToVulnerabilitiesReport()).not.toContain('SHOULD_NOT_BE_ADDED');
          });

          it('does not add the additional filter if it is empty', () => {
            createComponentWithStubbedTooltip({
              props: { filters: { projectId: [] } },
            });

            expect(findLinkToVulnerabilitiesReport()).not.toContain('&projectId=');
          });
        });
      });

      describe('when there is no securityVulnerabilitiesPath provided', () => {
        it('renders the count as plain text without a link', () => {
          createComponentWithStubbedTooltip({ provide: { securityVulnerabilitiesPath: null } });

          expect(wrapper.findComponent(GlLink).exists()).toBe(false);
          expect(wrapper.text()).toContain(`${mockTooltipParams.value[1]}`);
        });
      });
    });

    describe.each`
      condition                                    | componentSetup
      ${'no securityVulnerabilitiesPath provided'} | ${{ provide: { securityVulnerabilitiesPath: null } }}
      ${'no usable groupedBy-prop passed in'}      | ${{ props: { groupedBy: '' } }}
    `('when there is $condition', ({ componentSetup }) => {
      beforeEach(() => {
        createComponent(componentSetup);
      });

      it('does not render link in tooltip', () => {
        expect(wrapper.findComponent(GlLink).exists()).toBe(false);
      });

      it('does not enable click-to-pin tooltip functionality', () => {
        expect(findLineChart().props('clickToPinTooltip')).toBe(false);
      });
    });
  });

  describe('chartOptions', () => {
    it('configures the x-axis correctly', () => {
      createComponent();

      expect(findLineChart().props('option').xAxis).toMatchObject({
        name: null,
        key: 'date',
        type: 'category',
      });
    });

    it('configures the y-axis correctly', () => {
      createComponent();

      expect(findLineChart().props('option').yAxis).toMatchObject({
        name: null,
        key: 'vulnerabilities',
        type: 'value',
        minInterval: 1,
      });
    });

    it('configures dataZoom with the correct start date when chartStartDate is available', () => {
      createComponent();

      expect(findLineChart().props('option').dataZoom[0].startValue).toBe(firstDayOfChartSeries);
    });

    it('does not include dataZoom when chartStartDate is null', async () => {
      createComponent({ props: { chartSeries: [] } });

      await nextTick();

      expect(findLineChart().props('option').dataZoom).toBeUndefined();
    });
  });

  describe('custom chart line- and label colors', () => {
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
      const series = [{ name: seriesName, id: seriesId, data: [] }];

      createComponent({ props: { chartSeries: series } });
      await nextTick();

      const [coloredSeries] = findLineChart().props('data');

      expect(coloredSeries.itemStyle.color).toBe(expectedColor);
      expect(coloredSeries.lineStyle.color).toBe(expectedColor);
    });

    it('returns the original series if there is no color defined so the chart can set the color', () => {
      const customSeries = [{ name: 'No color defined', id: 'NO_COLOR_DEFINED', data: [] }];

      createComponent({ props: { chartSeries: customSeries } });
      const [coloredSeries] = findLineChart().props('data');

      expect(coloredSeries).toEqual(customSeries[0]);
    });

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
    const mockSvgData = 'data:svg';
    let getDataURLfn;
    let resizeFn;

    const createChartStub = () => {
      getDataURLfn = jest.fn(() => mockSvgData);
      resizeFn = jest.fn();

      return stubComponent(GlLineChart, {
        data() {
          return {
            chart: {
              getDataURL: getDataURLfn,
              getWidth: jest.fn(() => 1200),
              getHeight: jest.fn(() => 400),
              resize: resizeFn,
            },
          };
        },
      });
    };

    beforeEach(async () => {
      store = useChartExportStore();

      createComponent(
        {
          stubs: {
            GlLineChart: createChartStub(),
          },
        },
        shallowMount,
      );

      await nextTick();
    });

    it('registers the chart from the export store on mount', async () => {
      const exporters = await store.getAll();
      expect(exporters.open_vulnerabilities_over_time).toBeDefined();
    });

    it('unregisters the chart from the export store on destroy', async () => {
      let exporters = await store.getAll();
      expect(exporters.open_vulnerabilities_over_time).toBeDefined();

      wrapper.destroy();

      exporters = await store.getAll();
      expect(exporters.open_vulnerabilities_over_time).toBeUndefined();
    });

    it('returns SVG data when the exporter function is called', async () => {
      const exporters = await store.getAll();
      expect(exporters.open_vulnerabilities_over_time).toEqual({ svg: mockSvgData });
    });

    it('resizes to fixed export dimensions before capturing and restores to auto-sizing afterwards', async () => {
      await store.getAll();

      expect(resizeFn).toHaveBeenCalledWith({ width: 600, height: 500 });
      expect(resizeFn).toHaveBeenLastCalledWith({ width: 'auto', height: 'auto' });
    });
  });
});
