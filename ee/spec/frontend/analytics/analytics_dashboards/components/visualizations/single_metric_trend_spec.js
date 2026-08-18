import { GlSingleStat, GlSparklineChart } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SingleMetricTrend from 'ee/analytics/analytics_dashboards/components/visualizations/single_metric_trend.vue';

describe('Single Metric Trend Visualization', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findSingleStat = () => wrapper.findComponent(GlSingleStat);
  const findTrend = () => wrapper.findComponent(GlSparklineChart);

  const mockTrend = [
    ['Mon', 0],
    ['Tues', 5],
    ['Wed', 2],
  ];

  const createWrapper = ({ data, options } = {}) => {
    wrapper = shallowMountExtended(SingleMetricTrend, {
      propsData: {
        data,
        options,
      },
      stubs: { GlSparklineChart },
    });
  };

  describe('with no data and trend', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should render the single stat with default props', () => {
      expect(findSingleStat().props()).toMatchObject({
        value: 0,
        title: '',
        variant: 'neutral',
        shouldAnimate: true,
        animationDecimalPlaces: 0,
        useDelimiters: true,
      });
    });

    it('does not render the trend', () => {
      expect(findTrend().exists()).toBe(false);
    });
  });

  describe('with data and a trend', () => {
    beforeEach(() => {
      createWrapper({ data: { value: 35, trend: mockTrend } });
    });

    it('should pass the visualization data to the single stat value', () => {
      expect(findSingleStat().props('value')).toBe(35);
    });

    it('renders the trend', () => {
      expect(findTrend().exists()).toBe(true);
    });
  });

  describe('when there are user defined options that include decimal places', () => {
    const options = {
      title: 'Sessions',
      decimalPlaces: 2,
      metaText: 'meta text',
      metaIcon: 'project',
      metricIcon: 'users',
      unit: 'days',
    };

    it('should pass the visualization options to the single stat', () => {
      createWrapper({ options });

      expect(findSingleStat().props()).toMatchObject({
        title: 'Sessions',
        metaText: 'meta text',
        metaIcon: 'project',
        titleIcon: 'users',
        unit: 'days',
      });
    });

    it.each`
      data             | animationDecimalPlaces
      ${undefined}     | ${0}
      ${{ value: 35 }} | ${options.decimalPlaces}
    `(
      'should display $animationDecimalPlaces decimal places when the value is "$value"',
      ({ data, animationDecimalPlaces }) => {
        createWrapper({ data, options });

        expect(findSingleStat().props()).toMatchObject({ animationDecimalPlaces });
      },
    );
  });
});
