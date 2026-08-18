import { GlLineChart, GlColumnChart } from '@gitlab/ui/src/charts';
import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TracingAnalytics from 'ee/tracing/list/tracing_analytics.vue';
import { stubComponent } from 'helpers/stub_component';

describe('TracingAnalytics', () => {
  let wrapper;

  const mockAnalytics = [
    {
      interval: 1706456580,
      count: 272,
      p90_duration_nano: 79431434,
      p95_duration_nano: 172512624,
      p75_duration_nano: 33666014,
      p50_duration_nano: 13540992,
      trace_rate: 4.533333333333333,
      error_rate: 1.2,
    },
    {
      interval: 1706456640,
      count: 322,
      p90_duration_nano: 245701137,
      p95_duration_nano: 410402110,
      p75_duration_nano: 126097516,
      p50_duration_nano: 26955796,
      trace_rate: 5.366666666666666,
      error_rate: undefined,
    },
    {
      interval: 1706456700,
      count: 317,
      p90_duration_nano: 57725645,
      p95_duration_nano: 108238301,
      p75_duration_nano: 22083152,
      p50_duration_nano: 9805219,
      trace_rate: 5.283333333333333,
      error_rate: 0.234235,
    },
  ];

  const TEST_CHART_HEIGHT = 123;

  const mountComponent = ({
    analytics = mockAnalytics,
    loading = false,
    chartHeight = TEST_CHART_HEIGHT,
    mockTooltipParams = { seriesData: [{ data: [[new Date('10-04-2024 17:14'), 1]] }] },
  } = {}) => {
    const mockChartWithTooltip = {
      data() {
        return { mockTooltipParams };
      },
      template: `<div><slot name="tooltip-title" :params="mockTooltipParams"></slot></div>`,
    };
    wrapper = shallowMountExtended(TracingAnalytics, {
      propsData: {
        analytics,
        loading,
        chartHeight,
      },
      stubs: {
        GlColumnChart: stubComponent(GlColumnChart, mockChartWithTooltip),
        GlLineChart: stubComponent(GlLineChart, mockChartWithTooltip),
      },
    });
  };

  beforeEach(() => {
    mountComponent();
  });

  const findSkeleton = () => wrapper.findComponent(GlSkeletonLoader);

  describe('skeleton', () => {
    it('does not render the skeleton if not loading', () => {
      mountComponent({ loading: false });

      expect(findSkeleton().exists()).toBe(false);
    });
    it('renders the skeleton if loading', () => {
      mountComponent({ loading: true });

      expect(findSkeleton().exists()).toBe(true);
    });
  });

  it('renders nothing if analytics is empty', () => {
    mountComponent({ analytics: [] });

    expect(findSkeleton().exists()).toBe(false);
    expect(wrapper.findComponent(GlColumnChart).exists()).toBe(false);
    expect(wrapper.findComponent(GlLineChart).exists()).toBe(false);
  });

  describe('volume chart', () => {
    it('renders a column chart with volume data', () => {
      const chart = wrapper.findComponent(GlColumnChart);
      expect(chart.props('bars')[0].data).toEqual([
        [new Date('2024-01-28T15:43:00.000Z'), '4.53'],
        [new Date('2024-01-28T15:44:00.000Z'), '5.37'],
        [new Date('2024-01-28T15:45:00.000Z'), '5.28'],
      ]);
    });
  });

  describe('error chart', () => {
    it('renders a line chart with error data', () => {
      const chart = wrapper.findComponent(GlLineChart);
      expect(chart.props('data')[0].data).toEqual([
        [new Date('2024-01-28T15:43:00.000Z'), '1.20'],
        [new Date('2024-01-28T15:44:00.000Z'), '0.00'],
        [new Date('2024-01-28T15:45:00.000Z'), '0.23'],
      ]);
    });
  });

  describe('duration chart', () => {
    it('renders a line chart with error data', () => {
      const chart = wrapper.findAllComponents(GlLineChart).at(1);
      expect(chart.props('data')[0].data).toEqual([
        [new Date('2024-01-28T15:43:00.000Z'), '79.43'],
        [new Date('2024-01-28T15:44:00.000Z'), '245.70'],
        [new Date('2024-01-28T15:45:00.000Z'), '57.73'],
      ]);
    });
  });

  describe('height', () => {
    it('sets the chart height to 20% of the container height', () => {
      mountComponent();

      expect(wrapper.findComponent(GlColumnChart).props('height')).toBe(TEST_CHART_HEIGHT);
      expect(wrapper.findAllComponents(GlLineChart).at(0).props('height')).toBe(TEST_CHART_HEIGHT);
      expect(wrapper.findAllComponents(GlLineChart).at(1).props('height')).toBe(TEST_CHART_HEIGHT);
    });
  });

  describe('tooltip', () => {
    it('renders the tooltip title as a formatted date', () => {
      const expectedDate = 'Oct 04 2024 17:14:00 UTC';
      expect(wrapper.findComponent(GlColumnChart).text()).toBe(expectedDate);
      expect(wrapper.findAllComponents(GlLineChart).at(0).text()).toBe(expectedDate);
      expect(wrapper.findAllComponents(GlLineChart).at(1).text()).toBe(expectedDate);
    });

    it.each([{}, { seriesData: [] }, { seriesData: [{}] }, { seriesData: [{ data: [] }] }])(
      'handles incomplete data',
      (data) => {
        mountComponent({ mockTooltipParams: data });

        expect(wrapper.findAllComponents(GlLineChart).at(1).text()).toBe('');
      },
    );
  });
});
