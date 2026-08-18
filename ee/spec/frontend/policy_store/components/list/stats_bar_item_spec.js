import { shallowMount } from '@vue/test-utils';
import StatsBarItem from 'ee/policy_store/components/list/stats_bar_item.vue';

describe('StatsBarItem', () => {
  let wrapper;

  const createComponent = (propsData) => {
    wrapper = shallowMount(StatsBarItem, { propsData });
  };

  it('renders the label', () => {
    createComponent({ label: 'Active policies', value: 7 });

    expect(wrapper.text()).toContain('Active policies');
  });

  it('renders the value formatted with locale separators', () => {
    createComponent({ label: 'Evaluations this week', value: 1233 });

    expect(wrapper.text()).toContain((1233).toLocaleString());
  });
});
