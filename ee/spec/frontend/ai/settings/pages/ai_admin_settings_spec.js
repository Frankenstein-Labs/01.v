import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import createMockApollo from 'helpers/mock_apollo_helper';
import { updateApplicationSettings } from '~/rest_api';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import AiGtewayUrlInputForm from 'ee/ai/settings/components/ai_gateway_url_input_form.vue';
import AiGatewayTimeoutInputForm from 'ee/ai/settings/components/ai_gateway_timeout_input_form.vue';
import DuoAgentPlatformServiceUrlInputForm from 'ee/ai/settings/components/duo_agent_platform_service_url_input_form.vue';
import DuoAgentPlatformSecurityForm from 'ee/ai/settings/components/duo_agent_platform_security_form.vue';
import CodeSuggestionsConnectionForm from 'ee/ai/settings/components/code_suggestions_connection_form.vue';
import AiModelsForm from 'ee/ai/settings/components/ai_models_form.vue';
import AiAdminSettings from 'ee/ai/settings/pages/ai_admin_settings.vue';
import NetworkAccessSettings from 'ee/ai/settings/components/network_access_settings.vue';
import MissingSelfHostedModelsAlert from 'ee/ai/settings/components/missing_self_hosted_models_alert.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { AVAILABILITY_OPTIONS, AI_GATEWAY_TIMEOUT_SECONDS_DEFAULT } from 'ee/ai/settings/constants';
import getDuoSettingsQuery from 'ee/ai/graphql/get_ai_settings.query.graphql';
import updateAiSettingsMutation from 'ee/ai/graphql/update_ai_settings.mutation.graphql';
import DuoExpandedLoggingForm from 'ee/ai/settings/components/duo_expanded_logging_form.vue';
import DuoChatHistoryExpirationForm from 'ee/ai/settings/components/duo_chat_history_expiration.vue';
import { mockAgentStatuses, expectedFilteredAgentStatuses } from '../../mocks';

jest.mock('~/rest_api');
jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');

Vue.use(VueApollo);

let wrapper;
let axiosMock;

const aiGatewayTimeoutSeconds = 120;
const aiGatewayUrl = 'http://localhost:5052';
const duoAgentPlatformServiceUrl = 'localhost:50052';
const selfHostedDuoAgentPlatformServiceSecure = false;
const toggleBetaModelsPath = '/admin/ai/duo_self_hosted/terms_and_condition';
const getAiSettingsSuccessHandler = jest.fn().mockResolvedValue({
  data: {
    duoSettings: {
      aiGatewayUrl,
      aiGatewayTimeoutSeconds,
      duoCoreFeaturesEnabled: false,
      duoCliEnabled: true,
      duoAgentPlatformServiceUrl,
      selfHostedDuoAgentPlatformServiceSecure,
    },
  },
});
const updateAiSettingsSuccessHandler = jest.fn().mockResolvedValue({
  data: {
    duoSettingsUpdate: {
      aiGatewayUrl: 'http://new-aigw-url.com',
      aiGatewayTimeoutSeconds: 300,
      duoAgentPlatformServiceUrl: 'new-duo-agent-platform-url:50052',
      selfHostedDuoAgentPlatformServiceSecure: false,
      errors: [],
    },
  },
});

const createComponent = async ({
  props = {},
  provide = {},
  apolloHandlers = [
    [getDuoSettingsQuery, getAiSettingsSuccessHandler],
    [updateAiSettingsMutation, updateAiSettingsSuccessHandler],
  ],
} = {}) => {
  const mockApollo = createMockApollo(apolloHandlers);

  wrapper = shallowMount(AiAdminSettings, {
    apolloProvider: mockApollo,
    propsData: {
      redirectPath: '/admin/application_settings',
      duoProVisible: true,
      ...props,
    },
    provide: {
      duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
      disabledDirectConnectionMethod: false,
      betaSelfHostedModelsEnabled: false,
      canManageSelfHostedModels: true,
      canManageAigwTimeout: true,
      canConfigureAiLogging: true,
      enabledExpandedLogging: false,
      aiAuditEventsStreamingEnabled: false,
      toggleBetaModelsPath,
      exposeDuoAgentPlatformServiceUrl: false,
      duoChatExpirationDays: 30,
      duoChatExpirationColumn: 'last_updated_at',
      duoCoreFeaturesEnabled: false,
      initialDuoCliEnabled: true,
      initialMinimumAccessLevelExecuteAsync: 30,
      initialMinimumAccessLevelExecuteSync: 30,
      initialDuoTemplateProject: null,
      glFeatures: {},
      includeRecommendedAllowedDomains: false,
      allowAllUnixSockets: false,
      allowProjectExtension: true,
      duoInstanceModelSelectionPath: '/admin/gitlab_duo/model_selection',
      showGitlabManagedModelAlert: false,
      ...provide,
    },
  });

  await waitForPromises();
};

const findAiCommonSettings = () => wrapper.findComponent(AiCommonSettings);
const findCodeSuggestionsConnectionForm = () =>
  wrapper.findComponent(CodeSuggestionsConnectionForm);
const findAiModelsForm = () => wrapper.findComponent(AiModelsForm);
const findAiGatewayUrlInputForm = () => wrapper.findComponent(AiGtewayUrlInputForm);
const findAiGatewayTimeoutInputForm = () => wrapper.findComponent(AiGatewayTimeoutInputForm);
const findDuoAgentPlatformServiceUrlInputForm = () =>
  wrapper.findComponent(DuoAgentPlatformServiceUrlInputForm);
const findDuoExpandedLoggingForm = () => wrapper.findComponent(DuoExpandedLoggingForm);
const findDuoChatHistoryExpirationForm = () => wrapper.findComponent(DuoChatHistoryExpirationForm);
const findDuoAgentPlatformSecurityForm = () => wrapper.findComponent(DuoAgentPlatformSecurityForm);
const findHostingHeader = () => wrapper.find('[data-testid="hosting-subsection-header"]');
const findHostingDescription = () => wrapper.find('[data-testid="hosting-subsection-description"]');
const findNetworkAccessSettings = () => wrapper.findComponent(NetworkAccessSettings);
const findMissingSelfHostedModelsAlert = () => wrapper.findComponent(MissingSelfHostedModelsAlert);

describe('AiAdminSettings', () => {
  beforeEach(async () => {
    await createComponent();
  });

  describe('UI', () => {
    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('renders the hosting section header', () => {
      expect(findHostingHeader().text()).toBe('Hosting');
    });

    it('renders the hosting section description', () => {
      expect(findHostingDescription().text()).toBe(
        'Define how your GitLab instance communicates with AI infrastructure.',
      );
    });

    it('passes correct props to AiCommonSettings', () => {
      expect(findAiCommonSettings().props()).toEqual({
        hasParentFormChanged: false,
      });
    });
  });

  describe('getDuoSettings query', () => {
    it('is called on mount', () => {
      expect(getAiSettingsSuccessHandler).toHaveBeenCalledTimes(1);
    });

    it('passes correct value to input forms', async () => {
      await createComponent({
        provide: { exposeDuoAgentPlatformServiceUrl: true },
      });

      expect(findAiGatewayUrlInputForm().props('value')).toBe(aiGatewayUrl);
      expect(findAiGatewayTimeoutInputForm().props('value')).toBe(aiGatewayTimeoutSeconds);
      expect(findDuoAgentPlatformSecurityForm().props('value')).toBe(
        selfHostedDuoAgentPlatformServiceSecure,
      );
      expect(findDuoAgentPlatformServiceUrlInputForm().props('value')).toBe(
        duoAgentPlatformServiceUrl,
      );
    });

    describe('when the query fails', () => {
      beforeEach(async () => {
        await createComponent({
          provide: { exposeDuoAgentPlatformServiceUrl: true },
          apolloHandlers: [
            [getDuoSettingsQuery, jest.fn().mockRejectedValue(new Error('GraphQL error'))],
            [updateAiSettingsMutation, updateAiSettingsSuccessHandler],
          ],
        });
      });

      it('renders gracefully with default values', () => {
        expect(findAiCommonSettings().exists()).toBe(true);
        expect(findAiGatewayUrlInputForm().props('value')).toBe('');
        expect(findAiGatewayTimeoutInputForm().props('value')).toBe(
          AI_GATEWAY_TIMEOUT_SECONDS_DEFAULT,
        );
        expect(findDuoAgentPlatformSecurityForm().props('value')).toBe(false);
        expect(findDuoAgentPlatformServiceUrlInputForm().props('value')).toBe('');
      });

      it('shows an error alert', () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while loading GitLab Duo settings. Please try again.',
            captureError: true,
          }),
        );
      });
    });
  });

  describe('updateSettings', () => {
    it('calls updateApplicationSettings with correct params', async () => {
      updateApplicationSettings.mockResolvedValue();
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
        duoCoreFeaturesEnabled: false,
        duoCliEnabled: true,
        promptCacheEnabled: true,
        foundationalAgentsEnabled: true,
        duoRemoteFlowsAvailability: false,
        duoFoundationalFlowsAvailability: false,
        duoCustomAgentsAvailability: true,
        duoCustomFlowsAvailability: true,
        duoExternalAgentsAvailability: true,
        duoWorkflowsDefaultImageRegistry: 'registry.example.com',
        foundationalAgentsStatuses: mockAgentStatuses,
        selectedFoundationalFlowIds: [],
        duoAgentPlatformEnabled: true,
        namespaceAccessRules: [{ throughNamespace: { id: 1 }, features: ['duo_classic'] }],
        minimumAccessLevelExecuteSync: 30,
        minimumAccessLevelExecuteAsync: 30,
        includeRecommendedAllowedDomains: false,
        allowAllUnixSockets: false,
        allowProjectExtension: true,
      });

      const transformedFilteredAgentStatuses = expectedFilteredAgentStatuses.map((agent) => ({
        reference: agent.reference,
        enabled: agent.enabled,
      }));

      expect(updateApplicationSettings).toHaveBeenCalledTimes(1);
      expect(updateApplicationSettings).toHaveBeenCalledWith({
        duo_availability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        instance_level_ai_beta_features_enabled: false,
        model_prompt_cache_enabled: true,
        duo_remote_flows_availability: false,
        duo_foundational_flows_availability: false,
        duo_custom_agents_availability: true,
        duo_custom_flows_availability: true,
        duo_external_agents_availability: true,
        duo_workflows_default_image_registry: 'registry.example.com',
        duo_namespace_access_rules: [{ through_namespace: { id: 1 }, features: ['duo_classic'] }],
        enabled_foundational_flows: [],
        disabled_direct_code_suggestions: false,
        enabled_expanded_logging: false,
        ai_audit_events_streaming_enabled: false,
        duo_chat_expiration_days: 30,
        duo_chat_expiration_column: 'last_updated_at',
        duo_agent_platform_enabled: true,
        foundational_agents_default_enabled: true,
        foundational_agents_statuses: transformedFilteredAgentStatuses,
        duo_template_project_id: null,
      });
    });

    it('includes the template project id when a project is set', async () => {
      updateApplicationSettings.mockResolvedValue();
      await findAiCommonSettings().vm.$emit('submit', {
        duoTemplateProject: { id: 42, name: 'My Template', fullPath: 'group/my-template' },
      });
      await waitForPromises();

      expect(updateApplicationSettings).toHaveBeenCalledWith(
        expect.objectContaining({ duo_template_project_id: 42 }),
      );
    });

    it('sends null for duo_template_project_id when no project is set', async () => {
      updateApplicationSettings.mockResolvedValue();
      await findAiCommonSettings().vm.$emit('submit', { duoTemplateProject: null });
      await waitForPromises();

      expect(updateApplicationSettings).toHaveBeenCalledWith(
        expect.objectContaining({ duo_template_project_id: null }),
      );
    });

    describe('without namespace access rules', () => {
      it('does not include duo_namespace_access_rules when undefined', async () => {
        updateApplicationSettings.mockResolvedValue();
        await findAiCommonSettings().vm.$emit('submit', { namespaceAccessRules: undefined });
        await waitForPromises();

        expect(updateApplicationSettings).toHaveBeenCalledTimes(1);
        expect(updateApplicationSettings).toHaveBeenCalledWith(
          expect.not.objectContaining({
            duo_namespace_access_rules: expect.anything(),
          }),
        );
      });

      it('does include duo_namespace_access_rules when empty', async () => {
        updateApplicationSettings.mockResolvedValue();
        await findAiCommonSettings().vm.$emit('submit', { namespaceAccessRules: [] });
        await waitForPromises();

        expect(updateApplicationSettings).toHaveBeenCalledTimes(1);
        expect(updateApplicationSettings).toHaveBeenCalledWith(
          expect.objectContaining({
            duo_namespace_access_rules: [],
          }),
        );
      });

      it('handles global rule with null throughNamespace correctly', async () => {
        updateApplicationSettings.mockResolvedValue();
        await findAiCommonSettings().vm.$emit('submit', {
          namespaceAccessRules: [{ throughNamespace: null, features: ['duo_classic'] }],
        });
        await waitForPromises();

        expect(updateApplicationSettings).toHaveBeenCalledTimes(1);
        expect(updateApplicationSettings).toHaveBeenCalledWith(
          expect.objectContaining({
            duo_namespace_access_rules: [{ through_namespace: null, features: ['duo_classic'] }],
          }),
        );
      });
    });

    describe('when AI settings have changed', () => {
      describe('with canManageSelfHostedModels true', () => {
        it('updates aiGatewayUrl', async () => {
          const newAiGatewayUrl = 'http://new-ai-gateway-url.com';

          await findAiGatewayUrlInputForm().vm.$emit('change', newAiGatewayUrl);

          await findAiCommonSettings().vm.$emit('submit', {
            duoCoreFeaturesEnabled: false,
          });

          expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              aiGatewayUrl: 'http://new-ai-gateway-url.com',
              aiGatewayTimeoutSeconds: 120,
              duoAgentPlatformServiceUrl: 'localhost:50052',
              selfHostedDuoAgentPlatformServiceSecure: false,
              duoCoreFeaturesEnabled: false,
            },
          });
        });

        it('updates duoAgentPlatformServiceUrl', async () => {
          await createComponent({ provide: { exposeDuoAgentPlatformServiceUrl: true } });
          const newDuoAgentPlatformServiceUrl = 'new-duo-agent-platform-url:50052';

          await findDuoAgentPlatformServiceUrlInputForm().vm.$emit(
            'change',
            newDuoAgentPlatformServiceUrl,
          );

          await findAiCommonSettings().vm.$emit('submit', {
            duoCoreFeaturesEnabled: false,
          });

          expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              aiGatewayUrl: 'http://localhost:5052',
              aiGatewayTimeoutSeconds: 120,
              duoAgentPlatformServiceUrl: 'new-duo-agent-platform-url:50052',
              selfHostedDuoAgentPlatformServiceSecure: false,
              duoCoreFeaturesEnabled: false,
            },
          });
        });

        it('updates selfHostedDuoAgentPlatformServiceSecure when changed', async () => {
          await createComponent({ provide: { exposeDuoAgentPlatformServiceUrl: true } });

          await findDuoAgentPlatformSecurityForm().vm.$emit('secure-change', true);
          await findAiCommonSettings().vm.$emit('submit', {
            duoCoreFeaturesEnabled: false,
          });

          expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              aiGatewayUrl: 'http://localhost:5052',
              aiGatewayTimeoutSeconds: 120,
              duoAgentPlatformServiceUrl: 'localhost:50052',
              selfHostedDuoAgentPlatformServiceSecure: true,
              duoCoreFeaturesEnabled: false,
            },
          });
        });

        it('updates aiGatewayTimeoutSeconds', async () => {
          const newTimeout = 300;

          await findAiGatewayTimeoutInputForm().vm.$emit('change', newTimeout);

          await findAiCommonSettings().vm.$emit('submit', {
            duoCoreFeaturesEnabled: false,
          });

          expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              aiGatewayUrl: 'http://localhost:5052',
              aiGatewayTimeoutSeconds: newTimeout,
              duoAgentPlatformServiceUrl: 'localhost:50052',
              selfHostedDuoAgentPlatformServiceSecure: false,
              duoCoreFeaturesEnabled: false,
            },
          });
        });

        it('updates both aiGatewayUrl and duoAgentPlatformServiceUrl when both change', async () => {
          await createComponent({ provide: { exposeDuoAgentPlatformServiceUrl: true } });
          const newAiGatewayUrl = 'http://new-ai-gateway-url.com';
          const newDuoAgentPlatformServiceUrl = 'new-duo-agent-platform-url:50052';

          await findAiGatewayUrlInputForm().vm.$emit('change', newAiGatewayUrl);
          await findDuoAgentPlatformServiceUrlInputForm().vm.$emit(
            'change',
            newDuoAgentPlatformServiceUrl,
          );

          await findAiCommonSettings().vm.$emit('submit', {
            duoCoreFeaturesEnabled: false,
          });

          expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              aiGatewayUrl: 'http://new-ai-gateway-url.com',
              aiGatewayTimeoutSeconds: 120,
              duoAgentPlatformServiceUrl: 'new-duo-agent-platform-url:50052',
              selfHostedDuoAgentPlatformServiceSecure: false,
              duoCoreFeaturesEnabled: false,
            },
          });
        });
      });

      describe('with canManageSelfHostedModels false', () => {
        beforeEach(() => {
          createComponent({ provide: { canManageSelfHostedModels: false } });
        });

        it('does not update self-hosted models settings', async () => {
          await findAiCommonSettings().vm.$emit('submit', {
            duoCoreFeaturesEnabled: true,
          });

          expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              aiGatewayTimeoutSeconds: expect.any(Number),
              duoCoreFeaturesEnabled: true,
            },
          });
        });
      });

      describe('with canManageSelfHostedModels false and canManageAigwTimeout false', () => {
        beforeEach(() => {
          createComponent({
            provide: { canManageSelfHostedModels: false, canManageAigwTimeout: false },
          });
        });

        it.each([
          'aiGatewayUrl',
          'duoAgentPlatformServiceUrl',
          'selfHostedDuoAgentPlatformServiceSecure',
          'aiGatewayTimeoutSeconds',
        ])('does not update %s', async () => {
          await findAiCommonSettings().vm.$emit('submit', {
            duoCoreFeaturesEnabled: true,
          });

          expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
            input: {
              duoCoreFeaturesEnabled: true,
            },
          });
        });
      });

      it('updates duoCoreFeaturesEnabled', async () => {
        await findAiCommonSettings().vm.$emit('submit', {
          duoCoreFeaturesEnabled: true,
        });

        expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
          input: {
            aiGatewayUrl: 'http://localhost:5052',
            aiGatewayTimeoutSeconds: 120,
            duoAgentPlatformServiceUrl: 'localhost:50052',
            selfHostedDuoAgentPlatformServiceSecure: false,
            duoCoreFeaturesEnabled: true,
          },
        });
      });

      it('updates duoCliEnabled', async () => {
        await findAiCommonSettings().vm.$emit('submit', {
          duoCoreFeaturesEnabled: false,
          duoCliEnabled: false,
        });

        expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
          input: {
            aiGatewayUrl: 'http://localhost:5052',
            aiGatewayTimeoutSeconds: 120,
            duoAgentPlatformServiceUrl: 'localhost:50052',
            selfHostedDuoAgentPlatformServiceSecure: false,
            duoCoreFeaturesEnabled: false,
            duoCliEnabled: false,
          },
        });
      });
    });

    describe('when the beta models setting has changed', () => {
      beforeEach(() => {
        axiosMock = new MockAdapter(axios);
        jest.spyOn(axios, 'post');

        createComponent({ provide: { betaSelfHostedModelsEnabled: true } });
      });

      afterEach(() => {
        axiosMock.restore();
      });

      it('triggers a post request to persist the change', async () => {
        await findAiModelsForm().vm.$emit('change', false);
        await findAiCommonSettings().vm.$emit('submit', {
          duoCoreFeaturesEnabled: false,
          minimumAccessLevelExecuteSync: 30,
          minimumAccessLevelExecuteAsync: 30,
        });
        await waitForPromises();

        expect(axios.post).toHaveBeenCalledWith(toggleBetaModelsPath);
      });
    });

    it('shows success message on successful update', async () => {
      updateApplicationSettings.mockResolvedValue();
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
        duoCoreFeaturesEnabled: false,
        duoRemoteFlowsAvailability: false,
        duoFoundationalFlowsAvailability: false,
        minimumAccessLevelExecuteSync: 30,
        minimumAccessLevelExecuteAsync: 30,
      });
      await waitForPromises();
      expect(visitUrlWithAlerts).toHaveBeenCalledWith(
        expect.any(String),
        expect.arrayContaining([
          expect.objectContaining({
            message: 'Application settings saved successfully.',
          }),
        ]),
      );
    });

    it('shows error message on failed update', async () => {
      const error = new Error('Update failed');
      updateApplicationSettings.mockRejectedValue(error);

      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: false,
        duoCoreFeaturesEnabled: false,
        duoRemoteFlowsAvailability: false,
        duoFoundationalFlowsAvailability: false,
        minimumAccessLevelExecuteSync: 30,
        minimumAccessLevelExecuteAsync: 30,
      });

      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: error.message,
          error,
        }),
      );
    });
  });

  describe('when duoProVisible', () => {
    it('is availabile it does display the connection form', () => {
      createComponent({ props: { duoProVisible: true } });
      expect(findCodeSuggestionsConnectionForm().exists()).toBe(true);
    });

    it('is not availabile it does not display the connection form', () => {
      createComponent({ props: { duoProVisible: false } });
      expect(findCodeSuggestionsConnectionForm().exists()).toBe(false);
    });
  });

  describe('canManageSelfHostedModels', () => {
    describe('when canManageSelfHostedModels is true', () => {
      it('renders AI models form', () => {
        expect(findAiModelsForm().exists()).toBe(true);
      });

      it('renders AI gateway URL input form', () => {
        expect(findAiGatewayUrlInputForm().exists()).toBe(true);
      });

      describe('when exposeDuoAgentPlatformServiceUrl is false', () => {
        it('does not render Duo Agent Platform Service URL input form', () => {
          expect(findDuoAgentPlatformServiceUrlInputForm().exists()).toBe(false);
        });
      });

      describe('when exposeDuoAgentPlatformServiceUrl is true', () => {
        it('renders Duo Agent Platform Service URL input form', () => {
          createComponent({
            provide: { exposeDuoAgentPlatformServiceUrl: true },
          });

          expect(findDuoAgentPlatformServiceUrlInputForm().exists()).toBe(true);
        });
      });

      it('renders the expanded logging form', () => {
        expect(findDuoExpandedLoggingForm().exists()).toBe(true);
      });
    });

    describe('NetworkAccessSettings', () => {
      it('renders NetworkAccessSettings', () => {
        expect(findNetworkAccessSettings().exists()).toBe(true);
      });
    });

    describe('when canConfigureAiLogging is false', () => {
      beforeEach(() => {
        createComponent({ provide: { canConfigureAiLogging: false } });
      });

      it('does not render the expanded logging form', () => {
        expect(findDuoExpandedLoggingForm().exists()).toBe(false);
      });
    });

    describe('when canManageSelfHostedModels is false', () => {
      beforeEach(() => {
        createComponent({ provide: { canManageSelfHostedModels: false } });
      });

      it('does not render self-hosted models form', () => {
        expect(findAiModelsForm().exists()).toBe(false);
      });

      it('does not render AI gateway URL input form', () => {
        expect(findAiGatewayUrlInputForm().exists()).toBe(false);
      });

      it('does not render Duo Agent Platform Service URL input form', () => {
        expect(findDuoAgentPlatformServiceUrlInputForm().exists()).toBe(false);
      });
    });
  });

  describe('canManageAigwTimeout', () => {
    describe('when canManageAigwTimeout is true', () => {
      it('renders the AI gateway timeout input form', () => {
        expect(findAiGatewayTimeoutInputForm().exists()).toBe(true);
      });
    });

    describe('when canManageAigwTimeout is false', () => {
      beforeEach(() => {
        createComponent({ provide: { canManageAigwTimeout: false } });
      });

      it('does not render the AI gateway timeout input form', () => {
        expect(findAiGatewayTimeoutInputForm().exists()).toBe(false);
      });
    });

    describe('when canManageSelfHostedModels is false but canManageAigwTimeout is true', () => {
      beforeEach(() => {
        createComponent({
          provide: { canManageSelfHostedModels: false, canManageAigwTimeout: true },
        });
      });

      it('renders the AI gateway timeout input form', () => {
        expect(findAiGatewayTimeoutInputForm().exists()).toBe(true);
      });

      it('does not render self-hosted models form', () => {
        expect(findAiModelsForm().exists()).toBe(false);
      });
    });
  });

  describe('Missing self-hosted models alert', () => {
    // The alert reflects that no self-hosted endpoint is configured yet, so it
    // is triggered identically by EITHER the AI Gateway URL or the Duo Agent
    // Platform service URL. This handler starts with both saved URLs empty.
    const emptyUrlsHandler = jest.fn().mockResolvedValue({
      data: {
        duoSettings: {
          aiGatewayUrl: '',
          aiGatewayTimeoutSeconds,
          duoCoreFeaturesEnabled: false,
          duoCliEnabled: true,
          duoAgentPlatformServiceUrl: '',
          selfHostedDuoAgentPlatformServiceSecure,
        },
      },
    });

    const createWithEmptyUrls = (provide = {}) =>
      createComponent({
        provide: {
          showGitlabManagedModelAlert: true,
          exposeDuoAgentPlatformServiceUrl: true,
          ...provide,
        },
        apolloHandlers: [
          [getDuoSettingsQuery, emptyUrlsHandler],
          [updateAiSettingsMutation, updateAiSettingsSuccessHandler],
        ],
      });

    // Both URL inputs gate the alert the same way. Each case proves the alert
    // responds independently to whichever input the admin edits.
    describe.each`
      inputName                           | findInput                                  | enteredValue
      ${'AI Gateway URL'}                 | ${findAiGatewayUrlInputForm}               | ${'http://localhost:5052'}
      ${'Duo Agent Platform service URL'} | ${findDuoAgentPlatformServiceUrlInputForm} | ${'localhost:50052'}
    `('when triggered via the $inputName', ({ findInput, enteredValue }) => {
      it('does not render when the saved URL is empty and no URL is entered', async () => {
        await createWithEmptyUrls();

        expect(findMissingSelfHostedModelsAlert().exists()).toBe(false);
      });

      it('renders when the saved URL was empty and a URL is entered', async () => {
        await createWithEmptyUrls();

        expect(findMissingSelfHostedModelsAlert().exists()).toBe(false);

        await findInput().vm.$emit('change', enteredValue);
        await nextTick();

        expect(findMissingSelfHostedModelsAlert().exists()).toBe(true);
        expect(findMissingSelfHostedModelsAlert().props('modelSelectionPath')).toBe(
          '/admin/gitlab_duo/model_selection',
        );
      });

      it('hides again when the entered URL is cleared', async () => {
        await createWithEmptyUrls();

        await findInput().vm.$emit('change', enteredValue);
        await nextTick();
        expect(findMissingSelfHostedModelsAlert().exists()).toBe(true);

        await findInput().vm.$emit('change', '');
        await nextTick();
        expect(findMissingSelfHostedModelsAlert().exists()).toBe(false);
      });
    });

    it('does not render when showGitlabManagedModelAlert is false', async () => {
      await createWithEmptyUrls({ showGitlabManagedModelAlert: false });

      await findAiGatewayUrlInputForm().vm.$emit('change', 'http://localhost:5052');
      await nextTick();

      expect(findMissingSelfHostedModelsAlert().exists()).toBe(false);
    });

    it('does not render when the URLs are already saved', async () => {
      // Default handler returns non-empty saved URLs.
      await createComponent({ provide: { showGitlabManagedModelAlert: true } });

      expect(findMissingSelfHostedModelsAlert().exists()).toBe(false);
    });

    it('does not render when self-hosted models cannot be managed', async () => {
      await createWithEmptyUrls({ canManageSelfHostedModels: false });

      expect(findAiGatewayUrlInputForm().exists()).toBe(false);
      expect(findMissingSelfHostedModelsAlert().exists()).toBe(false);
    });

    // never_on is the only availability that suppresses the alert. The others
    // render it (default_off included, since Duo can be turned on downstream).
    describe.each`
      availability                        | shouldRender
      ${AVAILABILITY_OPTIONS.NEVER_ON}    | ${false}
      ${AVAILABILITY_OPTIONS.DEFAULT_OFF} | ${true}
      ${AVAILABILITY_OPTIONS.DEFAULT_ON}  | ${true}
      ${AVAILABILITY_OPTIONS.ALWAYS_ON}   | ${true}
    `('when availability is $availability', ({ availability, shouldRender }) => {
      it(`${shouldRender ? 'renders' : 'does not render'} once a URL is entered`, async () => {
        await createWithEmptyUrls({ duoAvailability: availability });

        await findAiGatewayUrlInputForm().vm.$emit('change', 'http://localhost:5052');
        await nextTick();

        expect(findMissingSelfHostedModelsAlert().exists()).toBe(shouldRender);
      });
    });

    it('hides when availability is changed to never_on', async () => {
      await createWithEmptyUrls();

      await findAiGatewayUrlInputForm().vm.$emit('change', 'http://localhost:5052');
      await nextTick();
      expect(findMissingSelfHostedModelsAlert().exists()).toBe(true);

      await findAiCommonSettings().vm.$emit('radio-changed', AVAILABILITY_OPTIONS.NEVER_ON);
      await nextTick();
      expect(findMissingSelfHostedModelsAlert().exists()).toBe(false);
    });
  });

  describe('onConnectionFormChange', () => {
    beforeEach(async () => {
      await createComponent({ props: { duoProVisible: true } });
    });

    it('sets hasParentFormChanged to true when event emitted', async () => {
      await findCodeSuggestionsConnectionForm().vm.$emit('change', true);
      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });

    it('sets hasParentFormChanged to false when event emitted', async () => {
      await findCodeSuggestionsConnectionForm().vm.$emit('change', false);
      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
    });
  });

  describe('onAiModelsFormChange', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('updates hasParentFormChanged when ai models form changes', async () => {
      await findAiModelsForm().vm.$emit('change', true);

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });
  });

  describe('onAiGatewayUrlChange', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('updates hasParentFormChanged when the AI gateway url value changes', async () => {
      await findAiGatewayUrlInputForm().vm.$emit('change', 'http://new-ai-gateway-url.com');

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });
  });

  describe('onAiGatewayTimeoutChange', () => {
    beforeEach(async () => {
      await createComponent({ provide: { canManageSelfHostedModels: true } });
    });

    it('passes the correct initial value to the timeout form', () => {
      expect(findAiGatewayTimeoutInputForm().props('value')).toBe(aiGatewayTimeoutSeconds);
    });

    it('updates hasParentFormChanged when the AI gateway timeout value changes', async () => {
      await findAiGatewayTimeoutInputForm().vm.$emit('change', 300);

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });
  });

  describe('onDuoAgentPlatformServiceUrlChange', () => {
    beforeEach(async () => {
      await createComponent({ provide: { exposeDuoAgentPlatformServiceUrl: true } });
    });

    it('updates hasParentFormChanged when the Duo Agent Platform Service URL value changes', async () => {
      await findDuoAgentPlatformServiceUrlInputForm().vm.$emit('change', 'new-url:50052');

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });
  });

  describe('onSelfHostedDuoAgentPlatformServiceSecureChange', () => {
    beforeEach(async () => {
      await createComponent({ provide: { exposeDuoAgentPlatformServiceUrl: true } });
    });

    it('updates hasParentFormChanged when secure checkbox value changes', async () => {
      await findDuoAgentPlatformSecurityForm().vm.$emit('secure-change', true);

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });
  });

  describe('onExpandedLoggingFormChanged', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('updates hasParentFormChanged when Duo expanded logging form changes', async () => {
      await findDuoExpandedLoggingForm().vm.$emit('change', true);

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });
  });

  describe('onDuoChatHistoryExpirationFormChanged', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders the DuoChatHistoryExpirationForm component', () => {
      expect(findDuoChatHistoryExpirationForm().exists()).toBe(true);
    });

    it('updates chatExpirationDays when days value changes', async () => {
      await findDuoChatHistoryExpirationForm().vm.$emit('change-expiration-days', 15);

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });

    it('updates chatExpirationColumn when column value changes', async () => {
      await findDuoChatHistoryExpirationForm().vm.$emit('change-expiration-column', 'created_at');

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
    });

    it('does not update hasParentFormChanged when the default expiration values are provided', async () => {
      await findDuoChatHistoryExpirationForm().vm.$emit('change-expiration-days', 30);
      await findDuoChatHistoryExpirationForm().vm.$emit(
        'change-expiration-column',
        'last_updated_at',
      );

      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
    });
  });

  describe('minimum access level permissions integration', () => {
    it('calls mutation with new minimumAccessLevelExecuteAsync value', async () => {
      await createComponent({
        provide: { initialMinimumAccessLevelExecuteAsync: 30 },
      });

      await findAiCommonSettings().vm.$emit('submit', {
        minimumAccessLevelExecuteAsync: 50,
      });

      expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
        input: expect.objectContaining({
          minimumAccessLevelExecuteAsync: 'OWNER',
        }),
      });
    });

    it('calls mutation with both values when both change', async () => {
      await createComponent();

      await findAiCommonSettings().vm.$emit('submit', {
        minimumAccessLevelExecuteAsync: 50,
        minimumAccessLevelExecuteSync: 10,
      });

      expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
        input: expect.objectContaining({
          minimumAccessLevelExecute: 'GUEST',
          minimumAccessLevelExecuteAsync: 'OWNER',
        }),
      });
    });

    describe('with "Everyone" support', () => {
      it('maps -1 to null when changing from role to Everyone', async () => {
        await createComponent({
          provide: {
            initialMinimumAccessLevelExecuteAsync: 30,
            initialMinimumAccessLevelExecuteSync: 30,
          },
        });

        // Change to Everyone
        await findAiCommonSettings().vm.$emit('submit', {
          minimumAccessLevelExecuteAsync: 40,
          minimumAccessLevelExecuteSync: -1,
        });

        expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
          input: expect.objectContaining({
            minimumAccessLevelExecute: null,
            minimumAccessLevelExecuteAsync: 'MAINTAINER',
          }),
        });
      });

      it('maps role to string when changing from Everyone to role', async () => {
        // Start with Everyone
        await createComponent({
          provide: {
            initialMinimumAccessLevelExecuteAsync: -1,
            initialMinimumAccessLevelExecuteSync: -1,
          },
        });

        await findAiCommonSettings().vm.$emit('submit', {
          minimumAccessLevelExecuteAsync: 30,
          minimumAccessLevelExecuteSync: 30,
        });

        expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
          input: expect.objectContaining({
            minimumAccessLevelExecute: 'DEVELOPER',
            minimumAccessLevelExecuteAsync: 'DEVELOPER',
          }),
        });
      });
    });

    describe('minimum access level conditional mutation', () => {
      beforeEach(() => {
        updateAiSettingsSuccessHandler.mockClear();
      });

      it('calls mutation with both values when both change', async () => {
        await createComponent();

        await findAiCommonSettings().vm.$emit('submit', {
          minimumAccessLevelExecuteAsync: 60,
          minimumAccessLevelExecuteSync: 50,
        });

        expect(updateAiSettingsSuccessHandler).toHaveBeenCalledWith({
          input: expect.objectContaining({
            minimumAccessLevelExecute: 'OWNER',
            minimumAccessLevelExecuteAsync: 'ADMIN',
          }),
        });
      });

      it('excludes minimumAccessLevelExecuteAsync when unchanged', async () => {
        await createComponent({
          provide: { initialMinimumAccessLevelExecuteSync: 30 },
        });

        await findAiCommonSettings().vm.$emit('submit', {
          minimumAccessLevelExecuteAsync: 30,
          minimumAccessLevelExecuteSync: 10,
        });

        const { input } = updateAiSettingsSuccessHandler.mock.calls[0][0];
        expect(input.minimumAccessLevelExecute).toBe('GUEST');
        expect(input.minimumAccessLevelExecuteAsync).toBeUndefined();
      });

      it('excludes minimumAccessLevelExecute when unchanged', async () => {
        await createComponent({
          provide: { initialMinimumAccessLevelExecuteAsync: 30 },
        });

        await findAiCommonSettings().vm.$emit('submit', {
          minimumAccessLevelExecuteAsync: 50,
          minimumAccessLevelExecuteSync: 30,
        });

        const { input } = updateAiSettingsSuccessHandler.mock.calls[0][0];
        expect(input.minimumAccessLevelExecuteAsync).toBe('OWNER');
        expect(input.minimumAccessLevelExecute).toBeUndefined();
      });

      it('excludes both fields when neither has changed', async () => {
        await createComponent();

        await findAiCommonSettings().vm.$emit('submit', {
          minimumAccessLevelExecuteAsync: 30,
          minimumAccessLevelExecuteSync: 30,
        });

        const { input } = updateAiSettingsSuccessHandler.mock.calls[0][0];
        expect(input.minimumAccessLevelExecute).toBeUndefined();
        expect(input.minimumAccessLevelExecuteAsync).toBeUndefined();
      });
    });
  });
});
