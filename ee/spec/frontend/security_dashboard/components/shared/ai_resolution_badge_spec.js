import { GlBadge, GlIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import AiResolutionBadge from 'ee/security_dashboard/components/shared/ai_resolution_badge.vue';

describe('AI Resolution badge component', () => {
  let wrapper;
  const createWrapper = (props = { aiResolutionAvailable: true }) => {
    return mountExtended(AiResolutionBadge, {
      propsData: {
        ...props,
      },
    });
  };

  beforeEach(() => {
    wrapper = createWrapper();
  });

  const findBadge = () => wrapper.findComponent(GlBadge);
  const tooltipMessage = 'Use AI to understand a vulnerability and suggest a fix';

  it('has a badge with the correct variant', () => {
    expect(findBadge().props()).toMatchObject({
      variant: 'info',
    });
  });

  it('has an icon', () => {
    expect(wrapper.findComponent(GlIcon).props()).toMatchObject({
      name: 'tanuki-ai',
    });
  });

  it('has the tooltip message', () => {
    expect(findBadge().attributes('title')).toBe(tooltipMessage);
  });

  it('has the accessible tooltip text', () => {
    expect(findBadge().text()).toBe(tooltipMessage);
    expect(wrapper.findByTestId('ai-resolution-badge-text').classes()).toContain('gl-sr-only');
  });
});
