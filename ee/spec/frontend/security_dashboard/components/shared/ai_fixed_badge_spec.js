import { GlBadge, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiFixedBadge from 'ee/security_dashboard/components/shared/ai_fixed_badge.vue';

describe('AiFixedBadge', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMountExtended(AiFixedBadge);
  };

  beforeEach(() => {
    createWrapper();
  });

  const findBadge = () => wrapper.findComponent(GlBadge);
  const tooltipMessage = 'AI has created a merge request to resolve this vulnerability';

  it('renders a badge with the correct variant', () => {
    expect(findBadge().props()).toMatchObject({
      variant: 'info',
    });
  });

  it('renders the duo icon', () => {
    expect(wrapper.findComponent(GlIcon).props()).toMatchObject({
      name: 'tanuki-ai',
    });
  });

  it('renders the tooltip message', () => {
    expect(findBadge().attributes('title')).toBe(tooltipMessage);
  });

  it('renders the accessible tooltip text', () => {
    const tooltip = wrapper.findByTestId('ai-fixed-badge-tooltip');

    expect(tooltip.text()).toBe(tooltipMessage);
    expect(tooltip.classes()).toContain('gl-sr-only');
  });
});
