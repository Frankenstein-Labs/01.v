import { GlLineChart } from '@gitlab/ui/src/charts';
import { shallowMount } from '@vue/test-utils';
import BurndownChart from 'ee/burndown_chart/components/burndown_chart.vue';

describe('burndown_chart', () => {
  let wrapper;

  const defaultProps = {
    startDate: '2019-08-07T00:00:00.000Z',
    dueDate: '2019-09-09T00:00:00.000Z',
    openIssuesCount: [],
    openIssuesWeight: [],
  };

  const findChart = () => wrapper.findComponent(GlLineChart);

  const createComponent = (props = {}) => {
    wrapper = shallowMount(BurndownChart, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  it('hides chart while loading', () => {
    createComponent({ loading: true });

    expect(findChart().exists()).toBe(false);
  });

  it('shows chart when not loading', () => {
    createComponent({ loading: false });

    expect(findChart().exists()).toBe(true);
  });

  describe('with no points', () => {
    it('does not show guideline', () => {
      createComponent({
        openIssuesCount: [],
      });

      expect(findChart().props('data')).toHaveLength(1);
      expect(findChart().props('data')[0].name).not.toBe('Guideline');
    });
  });

  describe('with single point and zero issues', () => {
    it('shows guideline', () => {
      createComponent({
        openIssuesCount: [{ '2019-08-07T00:00:00.000Z': 0 }],
      });

      expect(findChart().props('data')).toHaveLength(2);
      expect(findChart().props('data')[1].name).toBe('Guideline');
    });
  });

  describe('with single point', () => {
    it('shows guideline', () => {
      createComponent({
        openIssuesCount: [{ '2019-08-07T00:00:00.000Z': 100 }],
      });

      expect(findChart().props('data')).toHaveLength(2);
      expect(findChart().props('data')[1].name).toBe('Guideline');
    });
  });

  describe('with multiple points', () => {
    beforeEach(() => {
      createComponent({
        openIssuesCount: [
          { '2019-08-07T00:00:00.000Z': 100 },
          { '2019-08-08T00:00:00.000Z': 99 },
          { '2019-09-08T00:00:00.000Z': 1 },
        ],
      });
    });

    it('shows guideline', () => {
      expect(findChart().props('data')).toHaveLength(2);
      expect(findChart().props('data')[1].name).toBe('Guideline');
    });

    it('only shows integers on axis labels', () => {
      const msInOneDay = 60 * 60 * 24 * 1000;
      expect(findChart().props('option')).toMatchObject({
        xAxis: {
          type: 'time',
          minInterval: msInOneDay,
        },
        yAxis: {
          minInterval: 1,
        },
      });
    });

    it('does not show average or max values in legend', () => {
      expect(findChart().props('includeLegendAvgMax')).toBe(false);
    });
  });
});
