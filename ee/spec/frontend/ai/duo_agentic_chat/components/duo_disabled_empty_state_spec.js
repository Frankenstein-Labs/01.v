import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoDisabledEmptyState from 'ee/ai/duo_agentic_chat/components/duo_disabled_empty_state.vue';

describe('DuoDisabledEmptyState', () => {
  let wrapper;

  const defaultProps = {
    duoSettingsPath: '/test/project/edit#js-gitlab-duo-settings',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DuoDisabledEmptyState, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findEmptyState = () => wrapper.findByTestId('duo-disabled-empty-state');
  const findSettingsCta = () => wrapper.findByTestId('duo-settings-cta');
  const findLearnMoreCta = () => wrapper.findByTestId('duo-settings-learn-more');

  describe('rendering', () => {
    it('renders the empty state container with group namespace type by default', () => {
      createComponent();

      const container = findEmptyState();
      expect(container.exists()).toBe(true);
      expect(container.find('h2').text()).toBe('Turn on GitLab Duo Agent Platform');
      expect(container.find('p').text()).toBe(
        'As Owner of the group, you can turn on GitLab Duo Agent Platform and its AI features for your team.',
      );
      expect(container.findAll('li')).toHaveLength(3);
    });

    it('renders project container type when specified', () => {
      createComponent({ containerType: 'project' });

      expect(findEmptyState().find('p').text()).toBe(
        'As Owner of the project, you can turn on GitLab Duo Agent Platform and its AI features for your team.',
      );
    });
  });

  describe('settings CTA button', () => {
    it('renders the CTAs with correct href', () => {
      createComponent({ duoSettingsPath: '/test/path' });

      const cta = findSettingsCta();
      expect(cta.exists()).toBe(true);
      expect(cta.attributes('href')).toBe('/test/path');

      const learnMore = findLearnMoreCta();
      expect(learnMore.exists()).toBe(true);
      expect(learnMore.attributes('href')).toBe('/help/user/permissions');
    });
  });
});
