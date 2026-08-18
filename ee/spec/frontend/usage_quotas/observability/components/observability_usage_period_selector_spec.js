import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useFakeDate } from 'helpers/fake_date';
import ObservabilityUsagePeriodSelector from 'ee/usage_quotas/observability/components/observability_usage_period_selector.vue';

describe('ObservabilityUsagePeriodSelector', () => {
  // Set fake date to a few months after hardcoded start date
  useFakeDate('2024-08-01');

  let wrapper;

  const mountComponent = (props = { value: { month: 6, year: 2024 } }) => {
    wrapper = shallowMountExtended(ObservabilityUsagePeriodSelector, {
      propsData: {
        ...props,
      },
    });
  };

  beforeEach(() => {
    mountComponent();
  });

  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);

  it('renders the label text correctly', () => {
    expect(wrapper.text()).toContain('Filter data by month:');
  });

  it('renders the list box correctly', () => {
    expect(findListBox().props('items')).toEqual([
      expect.objectContaining({
        text: 'August 2024',
        value: JSON.stringify({ month: 7, year: 2024 }),
      }),
      expect.objectContaining({
        text: 'July 2024',
        value: JSON.stringify({ month: 6, year: 2024 }),
      }),
      expect.objectContaining({
        text: 'June 2024',
        value: JSON.stringify({ month: 5, year: 2024 }),
      }),
    ]);
  });

  it('renders periods correctly based on initial props', () => {
    mountComponent({
      value: { month: 5, year: 2024 },
    });
    expect(findListBox().props('selected')).toEqual(JSON.stringify({ month: 5, year: 2024 }));
  });

  it('fallback to the first period if value is not a valid period', () => {
    mountComponent({
      value: { foo: 'bar' },
    });

    expect(findListBox().props('selected')).toEqual(JSON.stringify({ month: 7, year: 2024 }));
  });

  it('emits input event with correct payload', async () => {
    await findListBox().vm.$emit('select', JSON.stringify({ month: 5, year: 2024 }));

    expect(wrapper.emitted('input')).toHaveLength(1);
    expect(wrapper.emitted('input')[0]).toEqual([{ month: 5, year: 2024 }]);
  });

  describe('when date is before hardcoded start date', () => {
    useFakeDate('2024-05-01');

    it('renders an empty element', () => {
      mountComponent();

      expect(wrapper.findComponent(GlCollapsibleListbox).exists()).toBe(false);
      expect(wrapper.text()).toBe('');
    });
  });
});
