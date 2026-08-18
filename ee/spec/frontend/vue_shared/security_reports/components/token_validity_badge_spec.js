import { shallowMount } from '@vue/test-utils';
import { GlLabel } from '@gitlab/ui';
import { GL_COLOR_BLUE_400, GL_COLOR_NEUTRAL_50 } from '@gitlab/ui/src/tokens/build/js/tokens';
import TokenValidityBadge from 'ee/vue_shared/security_reports/components/token_validity_badge.vue';
import HelpPopover from '~/vue_shared/components/help_popover.vue';

describe('TokenValidityBadge', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(TokenValidityBadge, {
      propsData: {
        ...props,
      },
    });
  };

  const findGlLabel = () => wrapper.findComponent(GlLabel);
  const findHelpPopover = () => wrapper.findComponent(HelpPopover);

  describe('label', () => {
    it.each([
      ['active', '#c91c00', 'Active secret'],
      ['inactive', GL_COLOR_BLUE_400, 'Inactive secret'],
      ['unknown', GL_COLOR_NEUTRAL_50, 'Possibly active secret'],
    ])('renders correct label for status %s', (status, backgroundColor, title) => {
      createComponent({ status });

      expect(findGlLabel().attributes('data-testid')).toBe('validityCheckLabel');
      expect(findGlLabel().props()).toMatchObject({
        backgroundColor,
        title,
      });
    });

    it.each([
      ['ACTIVE', 'Active secret'],
      ['INACTIVE', 'Inactive secret'],
      ['UNKNOWN', 'Possibly active secret'],
    ])('handles case-insensitive status when status is "%s"', (status, expectedStatus) => {
      createComponent({ status });

      expect(findGlLabel().props('title')).toBe(expectedStatus);
    });

    it('uses unknown status by default', () => {
      createComponent();

      const label = wrapper.findComponent(GlLabel);
      expect(label.props('backgroundColor')).toBe(GL_COLOR_NEUTRAL_50);
      expect(label.props('title')).toContain('Possibly active secret');

      expect(findGlLabel().attributes('data-testid')).toBe('validityCheckLabel');
      expect(findGlLabel().props()).toMatchObject({
        backgroundColor: GL_COLOR_NEUTRAL_50,
        title: 'Possibly active secret',
      });
    });
  });

  describe('popover', () => {
    it('renders the HelpPopover component', () => {
      createComponent();

      expect(findHelpPopover().props('options')).toEqual({
        title: 'What is a validity check?',
        content:
          'GitLab checks if detected secrets are active. You should revoke and replace active secrets immediately, because they can be used to impersonate legitimate activity.',
      });
    });

    it('does not render the HelpPopover component when showHelpPopover is false', () => {
      createComponent({ showHelpPopover: false });

      expect(findHelpPopover().exists()).toBe(false);
      expect(findGlLabel().exists()).toBe(true);
    });
  });
});
