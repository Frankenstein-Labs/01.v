import { mountExtended } from 'helpers/vue_test_utils_helper';
import DuoDisabledNonAdminEmptyState from 'ee/ai/duo_agentic_chat/components/duo_disabled_non_admin_empty_state.vue';

describe('DuoDisabledNonAdminEmptyState', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(DuoDisabledNonAdminEmptyState, {
      propsData: { ...props },
    });
  };

  const findEmptyState = () => wrapper.findByTestId('duo-disabled-non-admin-empty-state');
  const findLearnMoreLink = () => wrapper.findByTestId('duo-learn-more');
  const findDescription = () => wrapper.findByTestId('description');
  const findTurnOnInstructions = () => wrapper.findByTestId('turn-on-instructions');

  describe('rendering', () => {
    it('renders the empty state container with group container type by default', () => {
      createComponent();

      const container = findEmptyState();
      expect(container.exists()).toBe(true);
      expect(container.find('h2').text()).toBe('GitLab Duo Agent Platform is turned off');
      expect(findDescription().text()).toBe('GitLab Duo is disabled for this group. Learn more.');
      expect(findLearnMoreLink().attributes('href')).toBe('/help/user/duo_agent_platform/_index');
      expect(findTurnOnInstructions().text()).toBe(
        'An Owner or administrator can turn on GitLab Duo for this group.',
      );
    });

    it('renders project container type when specified', () => {
      createComponent({ containerType: 'project' });

      expect(findDescription().text()).toBe('GitLab Duo is disabled for this project. Learn more.');
      expect(findTurnOnInstructions().text()).toBe(
        'An Owner, Maintainer, or administrator can turn on GitLab Duo for this project.',
      );
    });
  });
});
