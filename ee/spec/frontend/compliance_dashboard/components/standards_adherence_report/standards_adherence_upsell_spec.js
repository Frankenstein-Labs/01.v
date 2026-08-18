import { shallowMount } from '@vue/test-utils';
import { GlEmptyState, GlBadge } from '@gitlab/ui';
import StandardsAdherenceUpsell from 'ee/compliance_dashboard/components/standards_adherence_report/standards_adherence_upsell.vue';

describe('StandardsAdherenceUpsell component', () => {
  let wrapper;

  const upgradePath = '/groups/example-group/-/billings';

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findBadge = () => wrapper.findComponent(GlBadge);

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(StandardsAdherenceUpsell, {
      propsData: {
        upgradePath,
        ...propsData,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the tier badge with the Ultimate label', () => {
    expect(findBadge().props()).toMatchObject({ variant: 'tier' });
    expect(findBadge().text()).toBe('Ultimate');
  });

  it('renders a description mentioning Ultimate', () => {
    expect(findEmptyState().props('description')).toMatch(/Ultimate/);
  });

  it('links the upgrade CTA to the injected upgrade path', () => {
    expect(findEmptyState().props('primaryButtonLink')).toBe(upgradePath);
  });

  it('links the learn-more CTA to the compliance status report docs', () => {
    expect(findEmptyState().props('secondaryButtonLink')).toMatch(
      /\/help\/user\/compliance\/compliance_center/,
    );
  });
});
