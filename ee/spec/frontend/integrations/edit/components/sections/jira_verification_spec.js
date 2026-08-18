import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import JiraVerificationSection from 'ee/integrations/edit/components/sections/jira_verification.vue';
import JiraVerificationFields from 'ee/integrations/edit/components/jira_verification_fields.vue';
import { useIntegrationForm } from '~/integrations/edit/store';

Vue.use(PiniaVuePlugin);

describe('JiraVerificationSection', () => {
  let wrapper;

  const createComponent = () => {
    const pinia = createTestingPinia({ stubActions: false });
    const store = useIntegrationForm();
    Object.assign(store, {
      customState: {
        jiraVerificationProps: {
          initialJiraCheckEnabled: false,
          initialJiraExistsCheckEnabled: false,
          initialJiraAssigneeCheckEnabled: false,
          initialJiraStatusCheckEnabled: false,
          initialJiraAllowedStatusesAsString: '',
          showJiraIssuesIntegration: false,
        },
      },
    });

    wrapper = shallowMount(JiraVerificationSection, {
      pinia,
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the JiraVerificationFields component with the correct props', () => {
      const jiraVerificationFields = wrapper.findComponent(JiraVerificationFields);

      expect(jiraVerificationFields.exists()).toBe(true);
      expect(jiraVerificationFields.props()).toEqual({
        initialJiraCheckEnabled: false,
        initialJiraExistsCheckEnabled: false,
        initialJiraAssigneeCheckEnabled: false,
        initialJiraStatusCheckEnabled: false,
        initialJiraAllowedStatusesAsString: '',
        showJiraIssuesIntegration: false,
      });
      expect(jiraVerificationFields.vm.$vnode.key).toBe('custom-jira-verification-fields');
    });
  });
});
