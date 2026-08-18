import { shallowMount } from '@vue/test-utils';
import { GlBadge } from '@gitlab/ui';
import MultiBadgeSelector from 'ee/security_policies/components/create/multi_badge_selector.vue';

describe('MultiBadgeSelector', () => {
  let wrapper;

  const options = [
    { id: 'a', label: 'Alpha' },
    { id: 'b', label: 'Beta' },
    { id: 'c', label: 'Gamma' },
  ];

  const createComponent = ({ value = [] } = {}) => {
    wrapper = shallowMount(MultiBadgeSelector, {
      propsData: { options, value },
    });
  };

  const findBadges = () => wrapper.findAllComponents(GlBadge);

  it('renders all options as badges', () => {
    createComponent();

    expect(findBadges()).toHaveLength(3);
    expect(findBadges().at(0).text()).toBe('Alpha');
    expect(findBadges().at(1).text()).toBe('Beta');
    expect(findBadges().at(2).text()).toBe('Gamma');
  });

  it('applies info variant to selected badges', () => {
    createComponent({ value: ['a', 'c'] });

    expect(findBadges().at(0).props('variant')).toBe('info');
    expect(findBadges().at(2).props('variant')).toBe('info');
  });

  it('applies neutral variant to unselected badges', () => {
    createComponent({ value: ['a'] });

    expect(findBadges().at(1).props('variant')).toBe('neutral');
    expect(findBadges().at(2).props('variant')).toBe('neutral');
  });

  it('emits input including new id when clicking unselected badge', () => {
    createComponent({ value: ['a'] });

    findBadges().at(1).vm.$emit('click');

    expect(wrapper.emitted('input')[0][0]).toEqual(['a', 'b']);
  });

  it('emits input excluding id when clicking selected badge', () => {
    createComponent({ value: ['a', 'b'] });

    findBadges().at(0).vm.$emit('click');

    expect(wrapper.emitted('input')[0][0]).toEqual(['b']);
  });
});
