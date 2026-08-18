import { GlSparklineChart } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SummaryMetricTile from 'ee/ai/governance/components/dashboard/summary_metric_tile.vue';

describe('SummaryMetricTile', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(SummaryMetricTile, {
      propsData: { label: 'AI agents', ...props },
    });
  };

  const findChart = () => wrapper.findComponent(GlSparklineChart);
  const findDelta = () => wrapper.findComponentByTestId('summary-metric-delta');

  it('renders the label and a placeholder value by default', () => {
    createComponent();

    expect(wrapper.text()).toContain('AI agents');
    expect(wrapper.text()).toContain('—');
  });

  it('does not render the delta when no delta is provided', () => {
    createComponent();

    expect(findDelta().exists()).toBe(false);
  });

  it('renders the value and delta when provided', () => {
    createComponent({ value: '47', delta: '+9 this week' });

    expect(wrapper.text()).toContain('47');
    expect(findDelta().exists()).toBe(true);
    expect(findDelta().text()).toBe('+9 this week');
  });

  it.each`
    deltaDirection | expectedVariant
    ${'up'}        | ${'success'}
    ${'down'}      | ${'danger'}
    ${'neutral'}   | ${'muted'}
  `(
    'renders a $expectedVariant delta badge when direction is $deltaDirection',
    ({ deltaDirection, expectedVariant }) => {
      createComponent({ delta: '+9 this week', deltaDirection });

      expect(findDelta().props('variant')).toBe(expectedVariant);
    },
  );

  it.each`
    deltaDirection | expectedIcon
    ${'up'}        | ${'arrow-up'}
    ${'down'}      | ${'arrow-down'}
  `(
    'shows a $expectedIcon trend icon when direction is $deltaDirection',
    ({ deltaDirection, expectedIcon }) => {
      createComponent({ delta: '+9 this week', deltaDirection });

      expect(findDelta().props('icon')).toBe(expectedIcon);
    },
  );

  it('renders the sparkline only when chart data is present', () => {
    createComponent();
    expect(findChart().exists()).toBe(false);

    createComponent({
      chartData: [
        [1, 2],
        [2, 4],
      ],
    });
    expect(findChart().exists()).toBe(true);
  });
});
