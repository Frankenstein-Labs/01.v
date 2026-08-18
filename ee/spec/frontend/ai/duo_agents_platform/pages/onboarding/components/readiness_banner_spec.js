import { GlAlert } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ReadinessBanner from 'ee/ai/duo_agents_platform/pages/onboarding/components/readiness_banner.vue';
import {
  PROJECT_STATE_READY,
  PROJECT_STATE_ENVIRONMENT_PROBLEM,
  PROJECT_STATE_NOT_ENABLED,
} from 'ee/ai/duo_agents_platform/pages/onboarding/constants';

const GROUP_SETTINGS_PATH = '/groups/acme/-/settings/gitlab_duo';

describe('ReadinessBanner', () => {
  let wrapper;

  const createComponent = ({ state, groupSettingsPath = GROUP_SETTINGS_PATH } = {}) => {
    wrapper = shallowMountExtended(ReadinessBanner, {
      propsData: { state, groupSettingsPath },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);

  describe('ready state', () => {
    beforeEach(() => createComponent({ state: PROJECT_STATE_READY }));

    it('renders a dismissible success banner without a primary button', () => {
      expect(findAlert().props('variant')).toBe('success');
      expect(findAlert().props('dismissible')).toBe(true);
      expect(findAlert().props('title')).toBe('Your project environment is healthy');
      expect(findAlert().props('primaryButtonText')).toBe(null);
    });

    it('hides when dismissed', async () => {
      await findAlert().vm.$emit('dismiss');

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('environment problem state', () => {
    beforeEach(() => createComponent({ state: PROJECT_STATE_ENVIRONMENT_PROBLEM }));

    it('renders a dismissible warning banner linking to the setup guide', () => {
      expect(findAlert().props('variant')).toBe('warning');
      expect(findAlert().props('dismissible')).toBe(true);
      expect(findAlert().props('title')).toBe("Flows can't run yet");
      expect(findAlert().props('primaryButtonText')).toBe('Open setup guide');
      expect(findAlert().props('primaryButtonLink')).toContain('duo_agent_platform');
    });
  });

  describe('not enabled state', () => {
    beforeEach(() => createComponent({ state: PROJECT_STATE_NOT_ENABLED }));

    it('renders a non-dismissible warning banner linking to group settings', () => {
      expect(findAlert().props('variant')).toBe('warning');
      expect(findAlert().props('dismissible')).toBe(false);
      expect(findAlert().props('title')).toBe(
        "The Agent Platform isn't enabled for this project yet",
      );
      expect(findAlert().props('primaryButtonText')).toBe('Open group settings');
      expect(findAlert().props('primaryButtonLink')).toBe(GROUP_SETTINGS_PATH);
    });
  });
});
