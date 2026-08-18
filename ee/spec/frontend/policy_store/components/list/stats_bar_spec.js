import { shallowMount } from '@vue/test-utils';
import StatsBar from 'ee/policy_store/components/list/stats_bar.vue';
import StatsBarItem from 'ee/policy_store/components/list/stats_bar_item.vue';

describe('StatsBar', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(StatsBar, { propsData });
  };

  const findItems = () => wrapper.findAllComponents(StatsBarItem);

  it('renders an item for the active policies count', () => {
    createComponent({ activePolicies: 7 });

    expect(findItems().at(0).props()).toMatchObject({ label: 'Active policies', value: 7 });
  });

  it('renders an item for the weekly evaluations count', () => {
    createComponent({ evaluationsThisWeek: 1233 });

    expect(findItems().at(1).props()).toMatchObject({
      label: 'Evaluations this week',
      value: 1233,
    });
  });

  it('defaults both counts to zero', () => {
    createComponent();

    expect(findItems().at(0).props('value')).toBe(0);
    expect(findItems().at(1).props('value')).toBe(0);
  });
});
