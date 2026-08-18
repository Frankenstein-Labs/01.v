import { GlAlert, GlPopover, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ResolveWithAiInfoPopover from 'ee/vulnerabilities/components/shared/resolve_with_ai_info_popover.vue';

describe('ee/vulnerabilities/components/shared/resolve_with_ai_info_popover.vue', () => {
  let wrapper;

  const createWrapper = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(ResolveWithAiInfoPopover, {
      propsData: {
        target: 'resolve-with-ai-button-id',
        ...propsData,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findPublicProjectWarningAlert = () => wrapper.findComponent(GlAlert);

  it('renders a popover with the correct content', () => {
    createWrapper();

    expect(wrapper.findComponent(GlPopover).text()).toBe(
      'Use GitLab Duo to generate a merge request with a suggested solution.',
    );
  });

  it('does not render the public-project warning by default', () => {
    createWrapper();

    expect(findPublicProjectWarningAlert().exists()).toBe(false);
  });

  describe('public-project warning alert', () => {
    beforeEach(() => {
      createWrapper({ propsData: { showPublicProjectWarning: true } });
    });

    it('renders as a warning variant', () => {
      expect(findPublicProjectWarningAlert().props('variant')).toBe('warning');
    });

    it('contains the correct message', () => {
      expect(findPublicProjectWarningAlert().text()).toMatchInterpolatedText(
        'Creating an MR from a public project will publicly expose the vulnerability and offered resolution. To create the MR privately, see Resolving a vulnerability privately.',
      );
    });

    it('renders a link to the related documentation', () => {
      const link = findPublicProjectWarningAlert().findComponent(GlLink);
      expect(link.attributes('href')).toBe(
        '/help/user/application_security/vulnerabilities/_index#vulnerability-resolution',
      );
      expect(link.text()).toBe('Resolving a vulnerability privately');
    });
  });
});
