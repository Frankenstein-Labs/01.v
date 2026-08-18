import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { updateGroupSettings } from 'ee/api/groups_api';
import { refreshCurrentPageWithAlerts, visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert, VARIANT_INFO } from '~/alert';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import AiGroupSettings from 'ee/ai/settings/pages/ai_group_settings.vue';
import DuoToolSettingsForm from 'ee/ai/settings/components/duo_tool_settings_form.vue';
import DuoWorkflowPromptInjectionForm from 'ee/ai/settings/components/duo_workflow_prompt_injection_form.vue';
import AiUsageDataCollectionForm from 'ee/ai/settings/components/ai_usage_data_collection_form.vue';
import AiCatalogRestrictedToGroupHierarchyForm from 'ee/ai/settings/components/ai_catalog_restricted_to_group_hierarchy_form.vue';
import DuoAuditEventStorageForm from 'ee/ai/settings/components/duo_audit_event_storage_form.vue';
import NetworkAccessSettings from 'ee/ai/settings/components/network_access_settings.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import { mockAgentStatuses, expectedFilteredAgentStatuses } from '../../mocks';

jest.mock('ee/api/groups_api');
jest.mock('~/lib/utils/url_utility');
jest.mock('~/alert');

let wrapper;

const createComponent = ({ props = {}, provide = {} } = {}) => {
  wrapper = shallowMount(AiGroupSettings, {
    propsData: {
      redirectPath: '/groups/test-group',
      updateId: '100',
      ...props,
    },
    provide: {
      duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
      onGeneralSettingsPage: false,
      duoWorkflowAvailable: true,
      duoWorkflowMcpAvailable: true,
      duoWorkflowMcpEnabled: false,
      aiUsageDataCollectionAvailable: true,
      aiUsageDataCollectionEnabled: false,
      aiCatalogRestrictedToGroupHierarchy: false,
      aiCatalogRestrictedToGroupHierarchyAvailable: true,
      aiAuditEventsStorageEnabled: false,
      promptInjectionProtectionLevel: 'interrupt',
      promptInjectionProtectionAvailable: true,
      initialMinimumAccessLevelExecuteAsync: 30,
      initialMinimumAccessLevelExecuteSync: 30,
      glFeatures: {},
      groupFullPath: 'test-group',
      includeRecommendedAllowedDomains: false,
      allowAllUnixSockets: false,
      allowProjectExtension: true,
      initialCodeReviewFlowConsentGiven: false,
      ...provide,
    },
  });
};

const findAiCommonSettings = () => wrapper.findComponent(AiCommonSettings);
const findDuoToolSettingsForm = () => wrapper.findComponent(DuoToolSettingsForm);
const findDuoWorkflowPromptInjectionForm = () =>
  wrapper.findComponent(DuoWorkflowPromptInjectionForm);
const findAiUsageDataCollectionForm = () => wrapper.findComponent(AiUsageDataCollectionForm);
const findAiCatalogRestrictedToGroupHierarchyForm = () =>
  wrapper.findComponent(AiCatalogRestrictedToGroupHierarchyForm);
const findDuoAuditEventStorageForm = () => wrapper.findComponent(DuoAuditEventStorageForm);
const findNetworkAccessSettings = () => wrapper.findComponent(NetworkAccessSettings);
const emitSubmitNamespaceAccessRules = async (namespaceAccessRules) => {
  updateGroupSettings.mockResolvedValueOnce({});
  await findAiCommonSettings().vm.$emit('submit', {
    namespaceAccessRules,
  });
  await waitForPromises();
};

describe('AiGroupSettings', () => {
  describe('UI', () => {
    it('renders the component', () => {
      createComponent();
      expect(wrapper.exists()).toBe(true);
    });

    it.each`
      aiUsageDataCollectionAvailable | shouldRender
      ${true}                        | ${true}
      ${false}                       | ${false}
    `(
      'renders AiUsageDataCollectionForm component as $shouldRender when aiUsageDataCollectionAvailable is $aiUsageDataCollectionAvailable',
      ({ aiUsageDataCollectionAvailable, shouldRender }) => {
        createComponent({ provide: { aiUsageDataCollectionAvailable } });

        expect(findAiUsageDataCollectionForm().exists()).toBe(shouldRender);
      },
    );

    it.each`
      aiCatalogRestrictedToGroupHierarchyAvailable | shouldRender
      ${true}                                      | ${true}
      ${false}                                     | ${false}
    `(
      'renders AiCatalogRestrictedToGroupHierarchyForm as $shouldRender when aiCatalogRestrictedToGroupHierarchyAvailable is $aiCatalogRestrictedToGroupHierarchyAvailable',
      ({ aiCatalogRestrictedToGroupHierarchyAvailable, shouldRender }) => {
        createComponent({ provide: { aiCatalogRestrictedToGroupHierarchyAvailable } });

        expect(findAiCatalogRestrictedToGroupHierarchyForm().exists()).toBe(shouldRender);
      },
    );

    it.each`
      agentArtifactsPage | shouldRender
      ${true}            | ${true}
      ${false}           | ${false}
    `(
      'renders DuoAuditEventStorageForm as $shouldRender when agentArtifactsPage is $agentArtifactsPage',
      ({ agentArtifactsPage, shouldRender }) => {
        createComponent({
          provide: { glFeatures: { agentArtifactsPage } },
        });

        expect(findDuoAuditEventStorageForm().exists()).toBe(shouldRender);
      },
    );

    it('renders DuoWorkflowPromptInjectionForm component when duoWorkflowAvailable is true', () => {
      createComponent({ provide: { duoWorkflowAvailable: true } });
      expect(findDuoWorkflowPromptInjectionForm().exists()).toBe(true);
    });

    it('does not render DuoWorkflowPromptInjectionForm component when both are unavailable', () => {
      createComponent({
        provide: { duoWorkflowAvailable: false, promptInjectionProtectionAvailable: false },
      });
      expect(findDuoWorkflowPromptInjectionForm().exists()).toBe(false);
    });

    it('renders DuoToolSettingsForm with only MCP when protection is unavailable', () => {
      createComponent({ provide: { promptInjectionProtectionAvailable: false } });
      expect(findDuoWorkflowPromptInjectionForm().exists()).toBe(true);
      expect(findDuoToolSettingsForm().props('showMcp')).toBe(true);
      expect(findDuoWorkflowPromptInjectionForm().props('showProtection')).toBe(false);
    });

    it('renders DuoWorkflowPromptInjectionForm with only protection when MCP is unavailable', () => {
      createComponent({ provide: { duoWorkflowAvailable: false, duoWorkflowMcpAvailable: false } });
      expect(findDuoWorkflowPromptInjectionForm().exists()).toBe(true);
      expect(findDuoToolSettingsForm().props('showMcp')).toBe(false);
      expect(findDuoWorkflowPromptInjectionForm().props('showProtection')).toBe(true);
    });

    it('passes correct props to DuoWorkflowPromptInjectionForm when rendered', () => {
      createComponent({ provide: { duoWorkflowAvailable: true } });
      expect(findDuoToolSettingsForm().props('isMcpEnabled')).toBe(false);
      expect(findDuoWorkflowPromptInjectionForm().props('promptInjectionProtectionLevel')).toBe(
        'interrupt',
      );
    });

    it('passes hasFormChanged prop to AiCommonSettings', () => {
      createComponent();
      expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
    });
  });

  describe('data initialization', () => {
    it('initializes duoWorkflowMcp from injected value', () => {
      createComponent({ provide: { duoWorkflowMcpEnabled: true } });
      expect(findDuoToolSettingsForm().props('isMcpEnabled')).toBe(true);
    });

    it('initializes aiUsageDataCollection from injected value', () => {
      createComponent({ provide: { aiUsageDataCollectionEnabled: true } });
      expect(wrapper.vm.aiUsageDataCollection).toBe(true);
    });

    it('initializes aiCatalogRestrictedToGroupHierarchyValue from injected value', () => {
      createComponent({ provide: { aiCatalogRestrictedToGroupHierarchy: true } });
      expect(wrapper.vm.aiCatalogRestrictedToGroupHierarchyValue).toBe(true);
    });

    it('initializes aiAuditEventsStorage from injected value', () => {
      createComponent({ provide: { aiAuditEventsStorageEnabled: true } });
      expect(wrapper.vm.aiAuditEventsStorage).toBe(true);
    });

    it('initializes promptInjectionProtection from injected value', () => {
      createComponent({ provide: { promptInjectionProtectionLevel: 'log_only' } });
      expect(findDuoWorkflowPromptInjectionForm().props('promptInjectionProtectionLevel')).toBe(
        'log_only',
      );
    });
  });

  describe('computed properties', () => {
    describe('hasFormChanged', () => {
      it('returns false when duoWorkflowMcp, aiUsageDataCollection, and promptInjectionProtection match injected values', () => {
        createComponent({
          provide: {
            duoWorkflowMcpEnabled: false,
            aiUsageDataCollectionEnabled: false,
            promptInjectionProtectionLevel: 'interrupt',
          },
        });
        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
      });

      it('returns true when duoWorkflowMcp differs from injected value', async () => {
        createComponent({ provide: { duoWorkflowMcpEnabled: false } });
        findDuoToolSettingsForm().vm.$emit('mcp-change', true);
        await nextTick();

        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
      });

      it('returns true when aiUsageDataCollection differs from injected value', async () => {
        createComponent({ provide: { aiUsageDataCollectionEnabled: false } });
        findAiUsageDataCollectionForm().vm.$emit('change', true);

        await nextTick();

        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
      });

      it('returns true when aiCatalogRestrictedToGroupHierarchyValue differs from injected value', async () => {
        createComponent({ provide: { aiCatalogRestrictedToGroupHierarchy: false } });
        findAiCatalogRestrictedToGroupHierarchyForm().vm.$emit('change', true);

        await nextTick();

        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
      });

      it('returns true when aiAuditEventsStorage differs from injected value', async () => {
        createComponent({
          provide: {
            aiAuditEventsStorageEnabled: false,
            glFeatures: { agentArtifactsPage: true },
          },
        });
        findDuoAuditEventStorageForm().vm.$emit('change', true);

        await nextTick();

        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
      });

      it('returns true when promptInjectionProtection differs from injected value', async () => {
        createComponent({ provide: { promptInjectionProtectionLevel: 'interrupt' } });
        findDuoWorkflowPromptInjectionForm().vm.$emit('protection-level-change', 'log_only');

        await nextTick();

        expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
      });
    });

    describe('showWorkflowSettingsForm', () => {
      it.each([
        {
          description: 'when duoWorkflowAvailable is true',
          provide: { duoWorkflowAvailable: true },
          shouldRender: true,
        },
        {
          description: 'when promptInjectionProtectionAvailable is true',
          provide: { promptInjectionProtectionAvailable: true },
          shouldRender: true,
        },
        {
          description: 'when both are unavailable',
          provide: { duoWorkflowAvailable: false, promptInjectionProtectionAvailable: false },
          shouldRender: false,
        },
      ])('$description', ({ provide, shouldRender }) => {
        createComponent({ provide });
        expect(findDuoWorkflowPromptInjectionForm().exists()).toBe(shouldRender);
      });
    });
  });

  describe('methods', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('onDuoWorkflowMcpChanged', () => {
      describe('when mcp-change event is emitted', () => {
        it('updates duoWorkflowMcp value and marks form as changed', async () => {
          expect(findDuoToolSettingsForm().props('isMcpEnabled')).toBe(false);
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);

          findDuoToolSettingsForm().vm.$emit('mcp-change', true);
          await nextTick();

          expect(findDuoToolSettingsForm().props('isMcpEnabled')).toBe(true);
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
        });
      });
    });

    describe('onAiUsageDataCollectionChanged', () => {
      describe('when change event is emitted', () => {
        it('updates aiUsageDataCollection value and marks form as changed', async () => {
          expect(wrapper.vm.aiUsageDataCollection).toBe(false);
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);

          findAiUsageDataCollectionForm().vm.$emit('change', true);
          await nextTick();

          expect(wrapper.vm.aiUsageDataCollection).toBe(true);
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
        });
      });
    });

    describe('onAiCatalogRestrictedToGroupHierarchyChanged', () => {
      describe('when change event is emitted', () => {
        it('updates aiCatalogRestrictedToGroupHierarchyValue and marks form as changed', async () => {
          expect(wrapper.vm.aiCatalogRestrictedToGroupHierarchyValue).toBe(false);
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);

          findAiCatalogRestrictedToGroupHierarchyForm().vm.$emit('change', true);
          await nextTick();

          expect(wrapper.vm.aiCatalogRestrictedToGroupHierarchyValue).toBe(true);
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
        });
      });
    });

    describe('onAiAuditEventsStorageChanged', () => {
      describe('when change event is emitted', () => {
        it('updates aiAuditEventsStorage value and marks form as changed', async () => {
          createComponent({
            provide: { glFeatures: { agentArtifactsPage: true } },
          });

          expect(wrapper.vm.aiAuditEventsStorage).toBe(false);
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);

          findDuoAuditEventStorageForm().vm.$emit('change', true);
          await nextTick();

          expect(wrapper.vm.aiAuditEventsStorage).toBe(true);
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
        });
      });
    });

    describe('onPromptInjectionProtectionChanged', () => {
      describe('when protection-level-change event is emitted', () => {
        it('updates promptInjectionProtection value and marks form as changed', async () => {
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(false);
          expect(findDuoWorkflowPromptInjectionForm().props('promptInjectionProtectionLevel')).toBe(
            'interrupt',
          );

          findDuoWorkflowPromptInjectionForm().vm.$emit('protection-level-change', 'log_only');
          await nextTick();

          expect(findDuoWorkflowPromptInjectionForm().props('promptInjectionProtectionLevel')).toBe(
            'log_only',
          );
          expect(findAiCommonSettings().props('hasParentFormChanged')).toBe(true);
        });
      });
    });
  });

  describe('updateSettings', () => {
    it('calls updateGroupSettings with correct parameters', async () => {
      createComponent();

      updateGroupSettings.mockResolvedValue({});
      await findAiCommonSettings().vm.$emit('submit', {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experimentFeaturesEnabled: true,
        duoCoreFeaturesEnabled: true,
        promptCacheEnabled: true,
        duoRemoteFlowsAvailability: false,
        duoFoundationalFlowsAvailability: false,
        duoCustomAgentsAvailability: true,
        duoCustomFlowsAvailability: true,
        duoExternalAgentsAvailability: true,
        foundationalAgentsEnabled: true,
        foundationalAgentsStatuses: mockAgentStatuses,
        selectedFoundationalFlowIds: [],
        duoAgentPlatformEnabled: true,
        namespaceAccessRules: [
          { throughNamespace: { id: 1, name: 'Group' }, features: ['duo_classic'] },
        ],
      });
      expect(updateGroupSettings).toHaveBeenCalledTimes(1);
      expect(updateGroupSettings).toHaveBeenCalledWith('100', {
        duo_availability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        experiment_features_enabled: true,
        duo_core_features_enabled: true,
        model_prompt_cache_enabled: true,
        duo_remote_flows_availability: false,
        duo_foundational_flows_availability: false,
        duo_custom_agents_availability: true,
        duo_custom_flows_availability: true,
        duo_external_agents_availability: true,
        foundational_agents_statuses: expectedFilteredAgentStatuses,
        enabled_foundational_flows: [],
        ai_settings_attributes: {
          duo_agent_platform_enabled: true,
          duo_workflow_mcp_enabled: false,
          ai_usage_data_collection_enabled: false,
          ai_catalog_restricted_to_group_hierarchy: false,
          prompt_injection_protection_level: 'interrupt',
          foundational_agents_default_enabled: true,
        },
        duo_namespace_access_rules: [{ through_namespace: { id: 1 }, features: ['duo_classic'] }],
        duo_template_project_id: null,
      });
    });

    describe('when agentArtifactsPage feature flag is disabled', () => {
      it('does not include ai_audit_events_storage_enabled in the API call', async () => {
        createComponent({
          provide: { glFeatures: { agentArtifactsPage: false } },
        });

        updateGroupSettings.mockResolvedValue({});
        await findAiCommonSettings().vm.$emit('submit', {});

        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.not.objectContaining({
            ai_audit_events_storage_enabled: expect.anything(),
          }),
        );
      });
    });

    describe('when agentArtifactsPage feature flag is enabled', () => {
      it('includes ai_audit_events_storage_enabled in the API call', async () => {
        createComponent({
          provide: { glFeatures: { agentArtifactsPage: true } },
        });

        updateGroupSettings.mockResolvedValue({});
        findDuoAuditEventStorageForm().vm.$emit('change', true);
        await nextTick();

        await findAiCommonSettings().vm.$emit('submit', {});

        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.objectContaining({
            ai_audit_events_storage_enabled: true,
          }),
        );
      });
    });

    describe('when aiCatalogRestrictedToGroupHierarchyValue is changed', () => {
      beforeEach(async () => {
        createComponent();
        updateGroupSettings.mockResolvedValue({});
        findAiCatalogRestrictedToGroupHierarchyForm().vm.$emit('change', true);
        await nextTick();
      });

      it('includes the new value in ai_settings_attributes on API call', async () => {
        await findAiCommonSettings().vm.$emit('submit', {});

        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.objectContaining({
            ai_settings_attributes: expect.objectContaining({
              ai_catalog_restricted_to_group_hierarchy: true,
            }),
          }),
        );
      });
    });

    describe('when on general settings page', () => {
      it('calls updateApplicationSettings without namespace access rules', async () => {
        createComponent({ provide: { onGeneralSettingsPage: true } });

        updateGroupSettings.mockResolvedValue({});
        await findAiCommonSettings().vm.$emit('submit', {
          duo_namespace_access_rules: [{ through_namespace: { id: 1 }, features: ['duo_classic'] }],
        });
        await waitForPromises();

        expect(updateGroupSettings).toHaveBeenCalledTimes(1);
        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.not.objectContaining({
            duo_namespace_access_rules: expect.anything(),
          }),
        );
      });
    });

    describe('without namespace access rules', () => {
      it('does not include duo_namespace_access_rules when undefined', async () => {
        createComponent();

        updateGroupSettings.mockResolvedValue({});
        await findAiCommonSettings().vm.$emit('submit', { namespaceAccessRules: undefined });
        await waitForPromises();

        expect(updateGroupSettings).toHaveBeenCalledTimes(1);
        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.not.objectContaining({
            duo_namespace_access_rules: expect.anything(),
          }),
        );
      });
    });

    describe('when duoWorkflowMcp is changed', () => {
      beforeEach(async () => {
        createComponent();
        updateGroupSettings.mockResolvedValue({});
        findDuoToolSettingsForm().vm.$emit('mcp-change', true);
        await nextTick();
      });

      it('includes updated duoWorkflowMcp value in API call', async () => {
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: true,
          duoCoreFeaturesEnabled: true,
          promptCacheEnabled: true,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          selectedFoundationalFlowIds: [],
        });
        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.objectContaining({
            enabled_foundational_flows: [],
            ai_settings_attributes: {
              duo_workflow_mcp_enabled: true,
              ai_usage_data_collection_enabled: false,
              ai_catalog_restricted_to_group_hierarchy: false,
              prompt_injection_protection_level: 'interrupt',
            },
          }),
        );
      });
    });

    describe('when promptInjectionProtection is changed', () => {
      beforeEach(async () => {
        createComponent();
        updateGroupSettings.mockResolvedValue({});
        findDuoWorkflowPromptInjectionForm().vm.$emit('protection-level-change', 'log_only');
        await nextTick();
      });

      it('includes updated promptInjectionProtection value in API call', async () => {
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: true,
          duoCoreFeaturesEnabled: true,
          promptCacheEnabled: true,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          selectedFoundationalFlowIds: [],
        });
        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.objectContaining({
            enabled_foundational_flows: [],
            ai_settings_attributes: {
              duo_workflow_mcp_enabled: false,
              ai_usage_data_collection_enabled: false,
              ai_catalog_restricted_to_group_hierarchy: false,
              prompt_injection_protection_level: 'log_only',
            },
          }),
        );
      });
    });

    describe('when aiUsageDataCollection is changed', () => {
      beforeEach(async () => {
        createComponent();
        updateGroupSettings.mockResolvedValue({});
        findAiUsageDataCollectionForm().vm.$emit('change', true);
        await nextTick();
      });

      it('includes updated aiUsageDataCollection value in API call', async () => {
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: true,
          duoCoreFeaturesEnabled: true,
          promptCacheEnabled: true,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          duoSastFpDetectionAvailability: false,
          selectedFoundationalFlowIds: [],
        });
        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.objectContaining({
            enabled_foundational_flows: [],
            ai_settings_attributes: {
              duo_workflow_mcp_enabled: false,
              ai_usage_data_collection_enabled: true,
              ai_catalog_restricted_to_group_hierarchy: false,
              prompt_injection_protection_level: 'interrupt',
            },
          }),
        );
      });
    });

    describe('with minimum access levels', () => {
      it('maps minimum access levels in ai_settings_attributes correctly', async () => {
        createComponent();

        updateGroupSettings.mockResolvedValue({});
        await findAiCommonSettings().vm.$emit('submit', {
          minimumAccessLevelExecuteSync: 40,
          minimumAccessLevelExecuteAsync: 40,
        });

        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.objectContaining({
            ai_settings_attributes: expect.objectContaining({
              minimum_access_level_execute: 40,
              minimum_access_level_execute_async: 40,
            }),
          }),
        );
      });

      it('converts "Everyone" option for minimum access levels execute sync correctly', async () => {
        createComponent();

        updateGroupSettings.mockResolvedValue({});
        await findAiCommonSettings().vm.$emit('submit', {
          minimumAccessLevelExecuteSync: -1,
        });

        expect(updateGroupSettings).toHaveBeenCalledWith(
          '100',
          expect.objectContaining({
            ai_settings_attributes: expect.objectContaining({
              minimum_access_level_execute: null,
            }),
          }),
        );
      });
    });

    describe('when update succeeds', () => {
      beforeEach(async () => {
        createComponent();
        updateGroupSettings.mockResolvedValue({});
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: false,
          duoCoreFeaturesEnabled: false,
          promptCacheEnabled: false,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          selectedFoundationalFlowIds: [],
        });
        await waitForPromises();
      });

      it('shows success message', () => {
        expect(visitUrlWithAlerts).toHaveBeenCalledWith(
          expect.any(String),
          expect.arrayContaining([
            expect.objectContaining({
              id: 'organization-group-successfully-updated',
              message: 'Group was successfully updated.',
              variant: VARIANT_INFO,
            }),
          ]),
        );
      });

      it('does not reload the page', () => {
        expect(refreshCurrentPageWithAlerts).not.toHaveBeenCalled();
      });
    });

    // The expanded SettingsBlock leaves its anchor in the URL, so navigating to
    // the same URL would only move the fragment and skip the reload.
    describe('when update succeeds on the general settings page', () => {
      beforeEach(async () => {
        createComponent({ provide: { onGeneralSettingsPage: true } });
        updateGroupSettings.mockResolvedValue({});
        await findAiCommonSettings().vm.$emit('submit', {});
        await waitForPromises();
      });

      it('reloads the page with the success message instead of navigating', () => {
        expect(refreshCurrentPageWithAlerts).toHaveBeenCalledWith([
          expect.objectContaining({
            id: 'organization-group-successfully-updated',
            message: 'Group was successfully updated.',
            variant: VARIANT_INFO,
          }),
        ]);
        expect(visitUrlWithAlerts).not.toHaveBeenCalled();
      });
    });

    describe('when update fails', () => {
      beforeEach(async () => {
        createComponent();
        const error = new Error('API error');
        updateGroupSettings.mockRejectedValue(error);
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: false,
          duoCoreFeaturesEnabled: false,
          promptCacheEnabled: true,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          selectedFoundationalFlowIds: [],
        });
        await waitForPromises();
      });

      it('shows error message', () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message:
              'An error occurred while retrieving your settings. Reload the page to try again.',
            captureError: true,
            error: expect.any(Error),
          }),
        );
      });
    });

    describe('when on general settings section', () => {
      beforeEach(async () => {
        createComponent({ provide: { onGeneralSettingsPage: true } });
        updateGroupSettings.mockResolvedValue({});
        await findAiCommonSettings().vm.$emit('submit', {
          duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experimentFeaturesEnabled: false,
          duoCoreFeaturesEnabled: true,
          promptCacheEnabled: true,
          duoRemoteFlowsAvailability: false,
          duoFoundationalFlowsAvailability: false,
          selectedFoundationalFlowIds: [],
        });
      });

      it('does not update duo core setting', () => {
        expect(updateGroupSettings).toHaveBeenCalledTimes(1);
        expect(updateGroupSettings).toHaveBeenCalledWith('100', {
          duo_availability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
          experiment_features_enabled: false,
          model_prompt_cache_enabled: true,
          duo_remote_flows_availability: false,
          duo_foundational_flows_availability: false,
          duo_custom_agents_availability: undefined,
          duo_custom_flows_availability: undefined,
          duo_external_agents_availability: undefined,
          enabled_foundational_flows: [],
          duo_template_project_id: null,
          ai_settings_attributes: {
            duo_workflow_mcp_enabled: false,
            ai_usage_data_collection_enabled: false,
            ai_catalog_restricted_to_group_hierarchy: false,
            prompt_injection_protection_level: 'interrupt',
          },
        });
        expect(updateGroupSettings).not.toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            duo_core_features_enabled: expect.anything(),
          }),
        );
      });
    });

    describe('foundational flow selection', () => {
      describe('when selectedFoundationalFlowIds are provided', () => {
        beforeEach(async () => {
          createComponent();
          updateGroupSettings.mockResolvedValue({});
          await findAiCommonSettings().vm.$emit('submit', {
            duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
            experimentFeaturesEnabled: false,
            duoCoreFeaturesEnabled: false,
            promptCacheEnabled: false,
            duoRemoteFlowsAvailability: false,
            duoFoundationalFlowsAvailability: false,
            selectedFoundationalFlowIds: [1, 2, 3],
          });
        });

        it('passes selectedFoundationalFlowIds to API', () => {
          expect(updateGroupSettings).toHaveBeenCalledWith(
            '100',
            expect.objectContaining({
              enabled_foundational_flows: [1, 2, 3],
            }),
          );
        });
      });
    });

    describe('minimum access level conditional mutation', () => {
      describe('updateSettings mutation input', () => {
        beforeEach(() => {
          updateGroupSettings.mockClear();
        });

        it('excludes minimum_access_level_execute_async when unchanged', async () => {
          createComponent({
            provide: {
              initialMinimumAccessLevelExecuteSync: 30,
              initialMinimumAccessLevelExecuteAsync: 30,
            },
          });

          updateGroupSettings.mockResolvedValue({});
          await findAiCommonSettings().vm.$emit('submit', {
            minimumAccessLevelExecuteSync: 10,
            minimumAccessLevelExecuteAsync: 30,
          });

          const callArgs = updateGroupSettings.mock.calls[0][1];
          expect(callArgs.ai_settings_attributes.minimum_access_level_execute).toBe(10);
          expect(
            callArgs.ai_settings_attributes.minimum_access_level_execute_async,
          ).toBeUndefined();
        });

        it('excludes minimum_access_level_execute when unchanged', async () => {
          createComponent({
            provide: {
              initialMinimumAccessLevelExecuteSync: 30,
              initialMinimumAccessLevelExecuteAsync: 30,
            },
          });

          updateGroupSettings.mockResolvedValue({});
          await findAiCommonSettings().vm.$emit('submit', {
            minimumAccessLevelExecuteSync: 30,
            minimumAccessLevelExecuteAsync: 50,
          });

          const callArgs = updateGroupSettings.mock.calls[0][1];
          expect(callArgs.ai_settings_attributes.minimum_access_level_execute_async).toBe(50);
          expect(callArgs.ai_settings_attributes.minimum_access_level_execute).toBeUndefined();
        });

        it('excludes both fields when neither has changed', async () => {
          createComponent();

          updateGroupSettings.mockResolvedValue({});
          await findAiCommonSettings().vm.$emit('submit', {});

          const callArgs = updateGroupSettings.mock.calls[0][1];
          expect(callArgs.ai_settings_attributes.minimum_access_level_execute).toBeUndefined();
          expect(
            callArgs.ai_settings_attributes.minimum_access_level_execute_async,
          ).toBeUndefined();
        });
      });
    });
  });

  describe('formatNamespaceAccessRules', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not include duo_namespace_access_rules when undefined', async () => {
      await emitSubmitNamespaceAccessRules(undefined);

      expect(updateGroupSettings).toHaveBeenCalledWith(
        '100',
        expect.not.objectContaining({
          duo_namespace_access_rules: expect.anything(),
        }),
      );
    });

    it('correctly formats namespace access rules', async () => {
      await emitSubmitNamespaceAccessRules([
        {
          throughNamespace: { id: 1, name: 'Group A', fullPath: 'group-a' },
          features: ['duo_classic', 'duo_chat'],
        },
        {
          throughNamespace: { id: 2, name: 'Group B', fullPath: 'group-b' },
          features: ['duo_workflow'],
        },
      ]);

      expect(updateGroupSettings).toHaveBeenCalledWith(
        '100',
        expect.objectContaining({
          duo_namespace_access_rules: [
            { through_namespace: { id: 1 }, features: ['duo_classic', 'duo_chat'] },
            { through_namespace: { id: 2 }, features: ['duo_workflow'] },
          ],
        }),
      );
    });

    it('handles global rule with null throughNamespace correctly', async () => {
      await emitSubmitNamespaceAccessRules([
        {
          throughNamespace: null,
          features: ['duo_classic'],
        },
      ]);

      expect(updateGroupSettings).toHaveBeenCalledWith(
        '100',
        expect.objectContaining({
          duo_namespace_access_rules: [{ through_namespace: null, features: ['duo_classic'] }],
        }),
      );
    });
  });

  describe('NetworkAccessSettings', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders NetworkAccessSettings', () => {
      expect(findNetworkAccessSettings().exists()).toBe(true);
    });

    it('passes groupFullPath prop', () => {
      expect(findNetworkAccessSettings().props('groupFullPath')).toBe('test-group');
    });
  });
});
