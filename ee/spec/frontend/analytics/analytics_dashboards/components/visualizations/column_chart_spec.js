import { GlColumnChart } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ColumnChart from 'ee/analytics/analytics_dashboards/components/visualizations/column_chart.vue';

describe('ColumnChart Visualization', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findColumnChart = () => wrapper.findComponent(GlColumnChart);

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(ColumnChart, {
      propsData: {
        data: [],
        options: {},
        ...props,
      },
    });
  };

  describe('when mounted', () => {
    it('should render the column chart with the provided data and option', () => {
      createWrapper({
        data: [{ name: 'foo' }],
        options: {
          yAxis: { name: 'y axis', min: 23 },
          xAxis: { name: 'x axis', type: 'category' },
        },
      });

      expect(findColumnChart().props()).toMatchObject({
        bars: [{ name: 'foo' }],
        option: { yAxis: { name: 'y axis', min: 23 }, xAxis: { name: 'x axis', type: 'category' } },
        xAxisType: 'category',
        xAxisTitle: 'x axis',
        yAxisTitle: 'y axis',
        height: 'auto',
      });
      expect(findColumnChart().attributes('responsive')).toBe('');
    });

    it('should add minimum y-axis option when not defined', () => {
      createWrapper({
        data: [{ name: 'foo' }],
        options: { yAxis: { name: 'y axis' }, xAxis: { name: 'x axis', type: 'category' } },
      });

      expect(findColumnChart().props().option).toMatchObject({
        yAxis: { name: 'y axis', min: 0 },
        xAxis: { name: 'x axis', type: 'category' },
      });
    });

    it('does not pass `tooltip` option to chart options', () => {
      createWrapper({
        options: {
          yAxis: { name: 'y axis' },
          xAxis: { name: 'x axis', type: 'category' },
          tooltip: { description: 'Panel tooltip' },
        },
      });

      expect(findColumnChart().props().option).not.toHaveProperty('tooltip');
    });
  });
});
