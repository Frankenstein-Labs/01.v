import { nextTick } from 'vue';
import { GlForm, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCommonSettingsForm from 'ee/ai/settings/components/ai_common_settings_form.vue';
import DuoAvailabilityForm from 'ee/ai/settings/components/duo_availability_form.vue';
import DuoAvailabilityNamespaces from 'ee/ai/settings/components/duo_availability_namespaces.vue';
import DuoExperimentBetaFeaturesForm from 'ee/ai/settings/components/duo_experiment_beta_features_form.vue';
import DuoCoreFeaturesForm from 'ee/ai/settings/components/duo_core_features_form.vue';
import DuoPromptCacheForm from 'ee/ai/settings/components/duo_prompt_cache_form.vue';
import DuoFlowSettings from 'ee/ai/settings/components/duo_flow_settings.vue';
import DuoFoundationalAgentsSettings from 'ee/ai/settings/components/duo_foundational_agents_settings.vue';
import DuoAgentPlatformSettingsForm from 'ee/ai/settings/components/duo_agent_platform_settings_form.vue';
import DuoCliSettings from 'ee/ai/settings/components/duo_cli_settings.vue';
import DuoCustomAgentsAndFlowsSettings from 'ee/ai/settings/components/duo_custom_agents_and_flows_settings.vue';
import AiNamespaceAccessRules from 'ee/ai/settings/components/ai_namespace_access_rules.vue';
import AiRolePermissions from 'ee/ai/settings/components/ai_role_permissions.vue';
import DuoTemplateProjectSelector from 'ee/ai/settings/components/duo_template_project_selector.vue';
import ToolApprovalForSessionSettings from 'ee/ai/settings/components/tool_approval_for_session_settings.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import { mockAgentStatuses } from '../../mocks';

describe('AiCommonSettingsForm', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AiCommonSettingsForm, {
      propsData: {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        duoCoreFeaturesEnabled: true,
        duoRemoteFlowsAvailability: false,
        duoFoundationalFlowsAvailability: false,
        duoCustomAgentsAvailability: true,
        duoCustomFlowsAvailability: true,
        duoExternalAgentsAvailability: true,
        experimentFeaturesEnabled: true,
        promptCacheEnabled: false,
        hasParentFormChanged: false,
        foundationalAgentsEnabled: false,
        selectedFoundationalFlowIds: [],
        foundationalAgentsStatuses: mockAgentStatuses,
        duoAgentPlatformEnabled: true,
        duoCliEnabled: true,
        initialNamespaceAccessRules: [],
        duoWorkflowsDefaultImageRegistry: '',
        ...props,
      },
      provide: {
        onGeneralSettingsPage: false,
        initialMinimumAccessLevelExecuteAsync: 30,
        initialMinimumAccessLevelExecuteSync: 10,
        showFoundationalAgentsAvailability: false,
        ...provide,
        glFeatures: {
          dapGroupCustomizablePermissions: false,
          dapInstanceCustomizablePermissions: false,
          ...(provide.glFeatures || {}),
        },
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findDuoAvailability = () => wrapper.findComponent(DuoAvailabilityForm);
  const findDuoExperimentBetaFeatures = () => wrapper.findComponent(DuoExperimentBetaFeaturesForm);
  const findDuoCoreFeaturesForm = () => wrapper.findComponent(DuoCoreFeaturesForm);
  const findDuoPromptCache = () => wrapper.findComponent(DuoPromptCacheForm);
  const findDuoFlowSettings = () => wrapper.findComponent(DuoFlowSettings);
  const findDuoFoundationalAgentsSettings = () =>
    wrapper.findComponent(DuoFoundationalAgentsSettings);
  const findDuoAgentPlatformSettingsForm = () =>
    wrapper.findComponent(DuoAgentPlatformSettingsForm);
  const findDuoCliSettings = () => wrapper.findComponent(DuoCliSettings);
  const findDuoCustomAgentsAndFlowsSettings = () =>
    wrapper.findComponent(DuoCustomAgentsAndFlowsSettings);
  const findAiRolePermissions = () => wrapper.findComponent(AiRolePermissions);
  const findDuoSettingsWarningAlert = () => wrapper.findByTestId('duo-settings-show-warning-alert');
  const findDuoDisabledSettingsMessage = () =>
    wrapper.findByTestId('duo-disabled-settings-message');
  const findAiNamespaceAccessRules = () => wrapper.findComponent(AiNamespaceAccessRules);
  const findDuoAvailabilityNamespaces = () => wrapper.findComponent(DuoAvailabilityNamespaces);
  const findSaveButton = () => wrapper.findComponent(GlButton);
  const findDuoTemplateProjectSelector = () => wrapper.findComponent(DuoTemplateProjectSelector);
  const findToolApprovalForSessionSettings = () =>
    wrapper.findComponent(ToolApprovalForSessionSettings);
  const findDataAndPrivacyHeader = () => wrapper.findByTestId('data-privacy-subsection-header');
  const findDataAndPrivacyDescription = () =>
    wrapper.findByTestId('data-privacy-subsection-description');

  describe('when initialNamespaceAccessRules is null', () => {
    beforeEach(() => {
      createComponent({ props: { initialNamespaceAccessRules: null } });
    });

    it('does not render the namespace access rules component', () => {
      expect(findAiNamespaceAccessRules().exists()).toBe(false);
    });
  });

  describe('DuoCliSettings visibility', () => {
    describe('when on instance settings', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the DuoCliSettings component', () => {
        expect(findDuoCliSettings().exists()).toBe(true);
      });
    });

    describe('when on group settings', () => {
      beforeEach(() => {
        createComponent({ provide: { isGroupSettings: true } });
      });

      it('does not render the DuoCliSettings component', () => {
        expect(findDuoCliSettings().exists()).toBe(false);
      });
    });
  });

  describe('Duo Availability Namespaces visibility', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the DuoAvailabilityNamespaces component', () => {
      expect(findDuoAvailabilityNamespaces().exists()).toBe(true);
    });
  });

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders AI Namespace Access Rules component', () => {
      expect(findAiNamespaceAccessRules().exists()).toBe(true);
    });

    it('renders GlForm component', () => {
      expect(findForm().exists()).toBe(true);
    });

    it('renders the Duo Availability component', () => {
      expect(findDuoAvailability().exists()).toBe(true);
    });

    it('renders the duo core features form', () => {
      expect(findDuoCoreFeaturesForm().exists()).toBe(true);
    });

    it('renders DuoExperimentBetaFeatures component', () => {
      expect(findDuoExperimentBetaFeatures().exists()).toBe(true);
    });

    it('renders DuoPromptCache component', () => {
      expect(findDuoPromptCache().exists()).toBe(true);
    });

    it('renders DuoFlowSettings component', () => {
      expect(findDuoFlowSettings().exists()).toBe(true);
    });

    it('disables save button when no changes are made', () => {
      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('enables save button when changes are made', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_OFF);
      await findDuoExperimentBetaFeatures().vm.$emit('change', true);
      await findDuoCoreFeaturesForm().vm.$emit('change', true);
      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('enables save button when prompt cache changes are made', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoPromptCache().vm.$emit('change', true);

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('enables save button when duo flow changes are made', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change', true);

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('enables save button when duo foundational flow changes are made', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-foundational-flows', true);

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    describe('custom agents and flows', () => {
      it('renders the DuoCustomAgentsAndFlowsSettings component', () => {
        expect(findDuoCustomAgentsAndFlowsSettings().exists()).toBe(true);
      });

      it('passes each availability prop independently', () => {
        createComponent({
          props: {
            duoCustomAgentsAvailability: true,
            duoCustomFlowsAvailability: false,
            duoExternalAgentsAvailability: false,
          },
        });
        expect(findDuoCustomAgentsAndFlowsSettings().props('customAgentsEnabled')).toBe(true);
        expect(findDuoCustomAgentsAndFlowsSettings().props('customFlowsEnabled')).toBe(false);
        expect(findDuoCustomAgentsAndFlowsSettings().props('externalAgentsEnabled')).toBe(false);
      });

      it('enables save button when custom agents toggles', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findDuoCustomAgentsAndFlowsSettings().vm.$emit('change-custom-agents', false);

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('enables save button when custom flows toggles', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findDuoCustomAgentsAndFlowsSettings().vm.$emit('change-custom-flows', false);

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('enables save button when external agents toggles', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findDuoCustomAgentsAndFlowsSettings().vm.$emit('change-external-agents', false);

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('emits duo-custom-agents-changed when custom agents toggles', () => {
        findDuoCustomAgentsAndFlowsSettings().vm.$emit('change-custom-agents', false);

        expect(wrapper.emitted('duo-custom-agents-changed')).toEqual([[false]]);
        expect(wrapper.emitted('duo-custom-flows-changed')).toBeUndefined();
        expect(wrapper.emitted('duo-external-agents-changed')).toBeUndefined();
      });

      it('emits duo-custom-flows-changed when custom flows toggles', () => {
        findDuoCustomAgentsAndFlowsSettings().vm.$emit('change-custom-flows', false);

        expect(wrapper.emitted('duo-custom-flows-changed')).toEqual([[false]]);
        expect(wrapper.emitted('duo-custom-agents-changed')).toBeUndefined();
        expect(wrapper.emitted('duo-external-agents-changed')).toBeUndefined();
      });

      it('emits duo-external-agents-changed when external agents toggles', () => {
        findDuoCustomAgentsAndFlowsSettings().vm.$emit('change-external-agents', false);

        expect(wrapper.emitted('duo-external-agents-changed')).toEqual([[false]]);
        expect(wrapper.emitted('duo-custom-agents-changed')).toBeUndefined();
        expect(wrapper.emitted('duo-custom-flows-changed')).toBeUndefined();
      });

      it('cascade-disables all when the parent agent platform toggle goes off', async () => {
        await findDuoAgentPlatformSettingsForm().vm.$emit('selected', false);

        expect(findDuoCustomAgentsAndFlowsSettings().props('customAgentsEnabled')).toBe(false);
        expect(findDuoCustomAgentsAndFlowsSettings().props('customFlowsEnabled')).toBe(false);
        expect(findDuoCustomAgentsAndFlowsSettings().props('externalAgentsEnabled')).toBe(false);
        expect(wrapper.emitted('duo-custom-agents-changed')).toEqual([[false]]);
        expect(wrapper.emitted('duo-custom-flows-changed')).toEqual([[false]]);
        expect(wrapper.emitted('duo-external-agents-changed')).toEqual([[false]]);
      });
    });

    describe('when namespace access rules get extended by a group', () => {
      it('enables save button', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findAiNamespaceAccessRules().vm.$emit('change', [
          { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
        ]);

        expect(findSaveButton().props('disabled')).toBe(false);
      });
    });

    describe('when feature gets added to namespace access rule', () => {
      beforeEach(() => {
        createComponent({
          props: {
            initialNamespaceAccessRules: [
              { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
            ],
          },
        });
      });

      it('enables save button', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findAiNamespaceAccessRules().vm.$emit('change', [
          {
            throughNamespace: { id: 1, name: 'group' },
            features: ['duo_agent_platform', 'duo_classic'],
          },
        ]);

        expect(findSaveButton().props('disabled')).toBe(false);
      });
    });

    describe('when features of namespace access rule stay unchanged', () => {
      beforeEach(() => {
        createComponent({
          props: {
            initialNamespaceAccessRules: [
              { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
            ],
          },
        });
      });

      it('save button stays disabled', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findAiNamespaceAccessRules().vm.$emit('change', [
          {
            throughNamespace: { id: 1, name: 'group' },
            features: ['duo_agent_platform'],
          },
        ]);

        expect(findSaveButton().props('disabled')).toBe(true);
      });
    });

    describe('when features of namespace access rule gets removed', () => {
      beforeEach(() => {
        createComponent({
          props: {
            initialNamespaceAccessRules: [
              { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
            ],
          },
        });
      });

      it('enables save button', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findAiNamespaceAccessRules().vm.$emit('change', [
          {
            throughNamespace: { id: 1, name: 'group' },
            features: [],
          },
        ]);

        expect(findSaveButton().props('disabled')).toBe(false);
      });
    });

    describe('when order of features of namespace access rule gets changed', () => {
      beforeEach(() => {
        createComponent({
          props: {
            initialNamespaceAccessRules: [
              {
                throughNamespace: { id: 1, name: 'group' },
                features: ['duo_agent_platform', 'duo_classic'],
              },
            ],
          },
        });
      });

      it('save button stays disabled', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findAiNamespaceAccessRules().vm.$emit('change', [
          {
            throughNamespace: { id: 1, name: 'group' },
            features: ['duo_classic', 'duo_agent_platform'],
          },
        ]);

        expect(findSaveButton().props('disabled')).toBe(true);
      });
    });

    it('enables save button when parent form changes are made', () => {
      createComponent({ props: { hasParentFormChanged: true } });
      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('does not show warning alert when form unchanged', () => {
      expect(findDuoSettingsWarningAlert().exists()).toBe(false);
    });

    it('does not show warning alert when availability is changed to default_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_ON);
      expect(findDuoSettingsWarningAlert().exists()).toBe(false);
    });

    it('shows warning alert when availability is changed to default_off', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_OFF);
      expect(findDuoSettingsWarningAlert().exists()).toBe(true);
      expect(findDuoSettingsWarningAlert().text()).toContain(
        'When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
      );
    });

    it('shows warning alert when availability is changed to never_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);
      expect(findDuoSettingsWarningAlert().exists()).toBe(true);
      expect(findDuoSettingsWarningAlert().text()).toContain(
        'When you save, GitLab Duo will be turned off for all groups, subgroups, and projects.',
      );
    });

    it('does not show disabled settings message when availability is default_on', () => {
      expect(findDuoDisabledSettingsMessage().exists()).toBe(false);
    });

    it('does not show disabled settings message when availability is changed to default_off', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.DEFAULT_OFF);
      expect(findDuoDisabledSettingsMessage().exists()).toBe(false);
    });

    it('shows disabled settings message when availability is changed to never_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);
      expect(findDuoDisabledSettingsMessage().exists()).toBe(true);
      expect(findDuoDisabledSettingsMessage().text()).toContain(
        'These settings are disabled because GitLab Duo availability is set to always off.',
      );
    });

    it('shows disabled settings message when initial availability is never_on', () => {
      createComponent({ props: { duoAvailability: AVAILABILITY_OPTIONS.NEVER_ON } });
      expect(findDuoDisabledSettingsMessage().exists()).toBe(true);
    });

    it('disables the prompt cache checkbox when duo availability is set to never_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);
      expect(findDuoPromptCache().props('disabledCheckbox')).toBe(true);
    });

    it('disables the duo flow checkbox when duo availability is set to never_on', async () => {
      expect(findDuoFlowSettings().props('disabledCheckbox')).toBe(false);

      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);

      expect(findDuoFlowSettings().props('disabledCheckbox')).toBe(true);
    });

    it('disables the namespace access rules when duo availability is set to never_on', async () => {
      expect(findAiNamespaceAccessRules().props('disabledCheckbox')).toBe(false);

      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);

      expect(findAiNamespaceAccessRules().props('disabledCheckbox')).toBe(true);
    });

    it('shows disabled settings message when availability is changed to always_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.ALWAYS_ON);
      expect(findDuoDisabledSettingsMessage().exists()).toBe(true);
      expect(findDuoDisabledSettingsMessage().text()).toContain(
        'These settings are disabled because GitLab Duo availability is set to always on.',
      );
    });

    it('shows disabled settings message when initial availability is always_on', () => {
      createComponent({ props: { duoAvailability: AVAILABILITY_OPTIONS.ALWAYS_ON } });
      expect(findDuoDisabledSettingsMessage().exists()).toBe(true);
    });

    it('disables the prompt cache checkbox when duo availability is set to always_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.ALWAYS_ON);
      expect(findDuoPromptCache().props('disabledCheckbox')).toBe(true);
    });

    it('does not disable the duo flow checkbox when duo availability is set to always_on', async () => {
      expect(findDuoFlowSettings().props('disabledCheckbox')).toBe(false);

      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.ALWAYS_ON);

      expect(findDuoFlowSettings().props('disabledCheckbox')).toBe(false);
    });

    it('does not disable the namespace access rules when duo availability is set to always_on', async () => {
      expect(findAiNamespaceAccessRules().props('disabledCheckbox')).toBe(false);

      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.ALWAYS_ON);

      expect(findAiNamespaceAccessRules().props('disabledCheckbox')).toBe(false);
    });

    it('disables the experiment checkbox when duo availability is set to never_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);

      expect(findDuoExperimentBetaFeatures().props('disabledCheckbox')).toBe(true);
    });

    it('does not disable the experiment checkbox when duo availability is set to always_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.ALWAYS_ON);

      expect(findDuoExperimentBetaFeatures().props('disabledCheckbox')).toBe(false);
    });

    it('disables the tool approval dropdown when duo availability is set to never_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.NEVER_ON);

      expect(findToolApprovalForSessionSettings().props('disabled')).toBe(true);
    });

    it('does not disable the tool approval dropdown when duo availability is set to always_on', async () => {
      await findDuoAvailability().vm.$emit('change', AVAILABILITY_OPTIONS.ALWAYS_ON);

      expect(findToolApprovalForSessionSettings().props('disabled')).toBe(false);
    });
  });

  describe('prompt cache integration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits cache-checkbox-changed event when DuoPromptCache emits change', async () => {
      await findDuoPromptCache().vm.$emit('change', true);

      expect(wrapper.emitted('cache-checkbox-changed')[0]).toEqual([true]);
    });

    it('updates internal cacheEnabled data when change event is received', async () => {
      await findDuoPromptCache().vm.$emit('change', true);

      // Verify the form is changed (cacheEnabled is now different from initial prop)
      expect(findSaveButton().props('disabled')).toBe(false);

      // Change it back to initial value
      await findDuoPromptCache().vm.$emit('change', false);

      // Verify the form is unchanged
      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });

  describe('duo flow integration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits duo-flow-checkbox-changed event when DuoFlowSettings emits change', async () => {
      await findDuoFlowSettings().vm.$emit('change', true);

      expect(wrapper.emitted('duo-flow-checkbox-changed')[0]).toEqual([true]);
    });

    it('updates internal flowEnabled data when change event is received', async () => {
      await findDuoFlowSettings().vm.$emit('change', true);

      expect(findSaveButton().props('disabled')).toBe(false);

      await findDuoFlowSettings().vm.$emit('change', false);

      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });

  describe('duo foundational flow integration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits duo-foundational-flows-checkbox-changed event when DuoFlowSettings emits change-foundational-flows', async () => {
      await findDuoFlowSettings().vm.$emit('change-foundational-flows', true);

      expect(wrapper.emitted('duo-foundational-flows-checkbox-changed')[0]).toEqual([true]);
    });

    it('updates internal foundationalFlowsEnabled data when change-foundational-flows event is received', async () => {
      await findDuoFlowSettings().vm.$emit('change-foundational-flows', true);

      expect(findSaveButton().props('disabled')).toBe(false);

      await findDuoFlowSettings().vm.$emit('change-foundational-flows', false);

      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });

  describe('foundational flow selection integration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits change-selected-flow-ids event when DuoFlowSettings emits it', async () => {
      await findDuoFlowSettings().vm.$emit('change-selected-flow-ids', [
        'code_review/v1',
        'bug_triage/v1',
        'documentation/v1',
      ]);

      expect(wrapper.emitted('change-selected-flow-ids')[0]).toEqual([
        ['code_review/v1', 'bug_triage/v1', 'documentation/v1'],
      ]);
    });

    it('updates internal localSelectedFlowIds data when change-selected-flow-ids event is received', async () => {
      createComponent({ props: { selectedFoundationalFlowIds: ['code_review/v1'] } });

      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-selected-flow-ids', [
        'code_review/v1',
        'bug_triage/v1',
      ]);

      expect(findSaveButton().props('disabled')).toBe(false);

      await findDuoFlowSettings().vm.$emit('change-selected-flow-ids', ['code_review/v1']);

      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('enables save button when flow IDs change from empty to non-empty', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-selected-flow-ids', [
        'sast_fp_detection/v1',
        'resolve_sast_vulnerability/v1',
      ]);

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('enables save button when flow IDs order changes', async () => {
      createComponent({
        props: {
          selectedFoundationalFlowIds: ['code_review/v1', 'bug_triage/v1', 'documentation/v1'],
        },
      });

      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-selected-flow-ids', [
        'documentation/v1',
        'bug_triage/v1',
        'code_review/v1',
      ]);

      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('passes selectedFoundationalFlowIds prop to DuoFlowSettings', () => {
      createComponent({
        props: { selectedFoundationalFlowIds: ['code_review/v1', 'bug_triage/v1'] },
      });

      expect(findDuoFlowSettings().props('selectedFoundationalFlowIds')).toEqual([
        'code_review/v1',
        'bug_triage/v1',
      ]);
    });
  });

  describe('duo workflows default image registry integration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits change-default-image-registry event when DuoFlowSettings emits it', async () => {
      await findDuoFlowSettings().vm.$emit('change-default-image-registry', 'registry.example.com');

      expect(wrapper.emitted('change-default-image-registry')[0]).toEqual(['registry.example.com']);
    });

    it('updates internal localDefaultImageRegistry data when change-default-image-registry event is received', async () => {
      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-default-image-registry', 'registry.example.com');

      expect(findSaveButton().props('disabled')).toBe(false);

      await findDuoFlowSettings().vm.$emit('change-default-image-registry', '');

      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('enables save button when default image registry changes', async () => {
      createComponent({ props: { duoWorkflowsDefaultImageRegistry: 'registry.example.com' } });

      expect(findSaveButton().props('disabled')).toBe(true);

      await findDuoFlowSettings().vm.$emit('change-default-image-registry', 'registry.test.com');

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('passes duoWorkflowsDefaultImageRegistry prop to DuoFlowSettings', () => {
      createComponent({ props: { duoWorkflowsDefaultImageRegistry: 'registry.example.com' } });

      expect(findDuoFlowSettings().props('duoWorkflowsDefaultImageRegistry')).toEqual(
        'registry.example.com',
      );
    });
  });

  describe('with onGeneralSettingsPage true', () => {
    beforeEach(() => {
      createComponent({ provide: { onGeneralSettingsPage: true } });
    });

    it('does not render the Duo Core features form', () => {
      expect(findDuoCoreFeaturesForm().exists()).toBe(false);
    });

    it('does not render the namespace access rules component', () => {
      expect(findAiNamespaceAccessRules().exists()).toBe(false);
    });
  });

  describe('disabled state for foundational agents and flow settings', () => {
    describe('when DAP enablement setting is shown', () => {
      it('enables flow settings when duo agent platform is enabled', () => {
        createComponent({
          props: {
            duoAgentPlatformEnabled: true,
            duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
          },
          provide: { showDuoAgentPlatformEnablementSetting: true },
        });

        expect(findDuoFlowSettings().props('disabledCheckbox')).toBe(false);
      });

      it('disables flow settings when duo agent platform is disabled', () => {
        createComponent({
          props: { duoAgentPlatformEnabled: false },
          provide: { showDuoAgentPlatformEnablementSetting: true },
        });

        expect(findDuoFlowSettings().props('disabledCheckbox')).toBe(true);
      });

      it('disables flow settings when availability is never_on even if duo agent platform is enabled', () => {
        createComponent({
          props: { duoAgentPlatformEnabled: true, duoAvailability: AVAILABILITY_OPTIONS.NEVER_ON },
          provide: { showDuoAgentPlatformEnablementSetting: true },
        });

        expect(findDuoFlowSettings().props('disabledCheckbox')).toBe(true);
      });
    });

    describe('when DAP enablement setting is hidden (e.g. self-managed group)', () => {
      it('enables flow settings even when duo agent platform is disabled', () => {
        createComponent({
          props: {
            duoAgentPlatformEnabled: false,
            duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
          },
          provide: { showDuoAgentPlatformEnablementSetting: false },
        });

        expect(findDuoFlowSettings().props('disabledCheckbox')).toBe(false);
      });

      it('still disables flow settings when availability is never_on', () => {
        createComponent({
          props: { duoAgentPlatformEnabled: false, duoAvailability: AVAILABILITY_OPTIONS.NEVER_ON },
          provide: { showDuoAgentPlatformEnablementSetting: false },
        });

        expect(findDuoFlowSettings().props('disabledCheckbox')).toBe(true);
      });

      it('keeps foundational agents read-only when duo agent platform is disabled', () => {
        createComponent({
          props: {
            duoAgentPlatformEnabled: false,
            duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
          },
          provide: {
            showDuoAgentPlatformEnablementSetting: false,
            showFoundationalAgentsAvailability: true,
          },
        });

        expect(findDuoFoundationalAgentsSettings().props('readOnly')).toBe(true);
      });
    });
  });

  describe('foundational agents settings', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render the setting when showFoundationalAgentsAvailability is false', () => {
      expect(findDuoFoundationalAgentsSettings().exists()).toBe(false);
    });

    describe('when showFoundationalAgentsAvailability is true', () => {
      beforeEach(() => {
        createComponent({
          props: { foundationalAgentsEnabled: false },
          provide: { showFoundationalAgentsAvailability: true },
        });
      });

      it('renders setting when showFoundationalAgentsAvailability is true', () => {
        expect(findDuoFoundationalAgentsSettings().exists()).toBe(true);
        expect(findDuoFoundationalAgentsSettings().props('foundationalAgentsEnabled')).toEqual(
          false,
        );
      });

      it('passes foundationalAgentsStatuses to the component', () => {
        expect(findDuoFoundationalAgentsSettings().props('agentStatuses')).toEqual(
          mockAgentStatuses,
        );
      });

      it('emits duo-foundational-agents-changed event when DuoFoundationalAgentsSettings emits change', async () => {
        findDuoFoundationalAgentsSettings().vm.$emit('change', true);
        await nextTick();

        expect(wrapper.emitted('duo-foundational-agents-changed')).toHaveLength(1);
        expect(wrapper.emitted('duo-foundational-agents-changed')[0]).toEqual([true]);
      });

      it('enables save button when foundational agent enabled value changes', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findDuoFoundationalAgentsSettings().vm.$emit('change', true);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('keeps save button disabled when foundational agents enabled value is unchanged', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findDuoFoundationalAgentsSettings().vm.$emit('change', false);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(true);
      });

      describe('for per agent settings', () => {
        const updatedStatuses = [
          { reference: 'security-analyst', name: 'Security Analyst', enabled: false },
          { reference: 'code-reviewer', name: 'Code Reviewer', enabled: false },
        ];

        it('emits duo-foundational-agents-statuses-change event when agent is toggled', async () => {
          findDuoFoundationalAgentsSettings().vm.$emit('agent-toggle', updatedStatuses);
          await nextTick();

          expect(wrapper.emitted('duo-foundational-agents-statuses-change')).toHaveLength(1);
          expect(wrapper.emitted('duo-foundational-agents-statuses-change')[0]).toEqual([
            updatedStatuses,
          ]);
        });

        it('enables save button when agent statuses change', async () => {
          expect(findSaveButton().props('disabled')).toBe(true);

          findDuoFoundationalAgentsSettings().vm.$emit('agent-toggle', updatedStatuses);
          await nextTick();

          expect(findSaveButton().props('disabled')).toBe(false);
        });
      });
    });
  });

  describe('duo agent platform settings', () => {
    it.each([true, false])('renders form with correct enabled prop', (value) => {
      createComponent({ props: { duoAgentPlatformEnabled: value } });
      expect(findDuoAgentPlatformSettingsForm().props('enabled')).toBe(value);
    });

    it('emits duo-agent-platform-enabled-changed event when DuoAgentPlatformSettingsForm emits selected', async () => {
      createComponent();
      findDuoAgentPlatformSettingsForm().vm.$emit('selected', false);
      await nextTick();

      expect(wrapper.emitted('duo-agent-platform-enabled-changed')).toHaveLength(1);
      expect(wrapper.emitted('duo-agent-platform-enabled-changed')[0]).toEqual([false]);
    });

    it('enables save button when duo agent platform enabled value changes', async () => {
      createComponent();
      expect(findSaveButton().props('disabled')).toBe(true);

      findDuoAgentPlatformSettingsForm().vm.$emit('selected', false);
      await nextTick();

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('keeps save button disabled when duo agent platform enabled value is unchanged', async () => {
      createComponent();
      expect(findSaveButton().props('disabled')).toBe(true);

      findDuoAgentPlatformSettingsForm().vm.$emit('selected', true);
      await nextTick();

      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('disables DAP checkbox when duo availability is never_on', () => {
      createComponent({
        props: { duoAvailability: AVAILABILITY_OPTIONS.NEVER_ON },
      });

      expect(findDuoAgentPlatformSettingsForm().props('disabledCheckbox')).toBe(true);
    });

    it.each([AVAILABILITY_OPTIONS.DEFAULT_ON, AVAILABILITY_OPTIONS.DEFAULT_OFF])(
      'does not disable DAP checkbox when duo availability is %s',
      (availability) => {
        createComponent({
          props: { duoAvailability: availability },
        });

        expect(findDuoAgentPlatformSettingsForm().props('disabledCheckbox')).toBe(false);
      },
    );

    describe('cascade to child settings on toggle', () => {
      it('cascades child settings to false when DAP is disabled', async () => {
        createComponent({ props: { duoAgentPlatformEnabled: true } });

        findDuoAgentPlatformSettingsForm().vm.$emit('selected', false);
        await nextTick();

        expect(wrapper.vm.flowEnabled).toBe(false);
        expect(wrapper.vm.foundationalFlowsEnabled).toBe(false);
        expect(wrapper.vm.foundationalAgentsEnabledInput).toBe(false);
        expect(wrapper.emitted('duo-flow-checkbox-changed')[0]).toEqual([false]);
        expect(wrapper.emitted('duo-foundational-flows-checkbox-changed')[0]).toEqual([false]);
        expect(wrapper.emitted('duo-foundational-agents-changed')[0]).toEqual([false]);
      });

      it('does not cascade child settings when DAP value is enabled', async () => {
        createComponent({ props: { duoAgentPlatformEnabled: true } });

        findDuoAgentPlatformSettingsForm().vm.$emit('selected', true);
        await nextTick();

        expect(wrapper.emitted('duo-flow-checkbox-changed')).toBeUndefined();
        expect(wrapper.emitted('duo-foundational-flows-checkbox-changed')).toBeUndefined();
        expect(wrapper.emitted('duo-foundational-agents-changed')).toBeUndefined();
      });
    });
  });

  describe('duo template project selector', () => {
    describe('on admin page', () => {
      it('renders when showDuoTemplateProject is true', () => {
        createComponent({ provide: { showDuoTemplateProject: true } });
        expect(findDuoTemplateProjectSelector().exists()).toBe(true);
      });

      it('does not render when showDuoTemplateProject is false', () => {
        createComponent({ provide: { showDuoTemplateProject: false } });
        expect(findDuoTemplateProjectSelector().exists()).toBe(false);
      });
    });

    describe('on group settings', () => {
      it('does not render when showDuoTemplateProject is false', () => {
        createComponent({
          provide: {
            isGroupSettings: true,
            showDuoTemplateProject: false,
          },
        });
        expect(findDuoTemplateProjectSelector().exists()).toBe(false);
      });

      it('renders when showDuoTemplateProject is true', () => {
        createComponent({
          provide: {
            isGroupSettings: true,
            showDuoTemplateProject: true,
          },
        });
        expect(findDuoTemplateProjectSelector().exists()).toBe(true);
      });
    });

    describe('when rendered', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            rootNamespaceId: '42',
            isGroupSettings: true,
            showDuoTemplateProject: true,
          },
        });
      });

      it('passes selectedProject prop from localDuoTemplateProject', () => {
        expect(findDuoTemplateProjectSelector().props('selectedProject')).toBeNull();
      });

      it('enables save button when project-changed event is emitted', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findDuoTemplateProjectSelector().vm.$emit('project-changed', {
          id: 10,
          name: 'My Project',
          nameWithNamespace: 'Group / My Project',
          fullPath: 'group/my-project',
          avatarUrl: null,
        });

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('emits change-duo-template-project when project-changed fires', async () => {
        const project = {
          id: 10,
          name: 'My Project',
          nameWithNamespace: 'Group / My Project',
          fullPath: 'group/my-project',
          avatarUrl: null,
        };

        await findDuoTemplateProjectSelector().vm.$emit('project-changed', project);

        expect(wrapper.emitted('change-duo-template-project')).toEqual([[project]]);
      });

      it('keeps save button disabled when project-changed fires with the same project id', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        await findDuoTemplateProjectSelector().vm.$emit('project-changed', null);

        expect(findSaveButton().props('disabled')).toBe(true);
      });
    });
  });

  describe('data and privacy header and description', () => {
    it('does not render when all data privacy features are disabled', () => {
      createComponent({
        provide: {
          arePromptCacheSettingsAllowed: false,
          aiUsageDataCollectionAvailable: false,
          duoWorkflowAvailable: false,
          promptInjectionProtectionAvailable: false,
          canConfigureAiLogging: false,
        },
      });

      expect(findDataAndPrivacyHeader().exists()).toBe(false);
      expect(findDataAndPrivacyDescription().exists()).toBe(false);
    });

    it.each([
      { arePromptCacheSettingsAllowed: true },
      { aiUsageDataCollectionAvailable: true },
      { duoWorkflowAvailable: true },
      { promptInjectionProtectionAvailable: true },
      { canConfigureAiLogging: true },
    ])('renders header when feature is enabled', ({ ...provide }) => {
      createComponent({ provide });

      expect(findDataAndPrivacyHeader().text()).toBe('Data and privacy');
      expect(findDataAndPrivacyDescription().text()).toBe(
        'Control AI access to your data or external networks.',
      );
    });
  });

  describe('AI Role Permissions', () => {
    it('does not render when both feature flags are disabled', () => {
      createComponent({
        provide: {
          isSaaS: true,
          glFeatures: {
            dapGroupCustomizablePermissions: false,
            dapInstanceCustomizablePermissions: false,
          },
        },
      });

      expect(findAiRolePermissions().exists()).toBe(false);
    });

    it('does not render on SaaS when only instance flag is enabled', () => {
      createComponent({
        provide: {
          isSaaS: true,
          glFeatures: {
            dapGroupCustomizablePermissions: false,
            dapInstanceCustomizablePermissions: true,
          },
        },
      });

      expect(findAiRolePermissions().exists()).toBe(false);
    });

    it('does not render on Self-Managed when only group flag is enabled', () => {
      createComponent({
        provide: {
          isSaaS: false,
          glFeatures: {
            dapGroupCustomizablePermissions: true,
            dapInstanceCustomizablePermissions: false,
          },
        },
      });

      expect(findAiRolePermissions().exists()).toBe(false);
    });

    describe('when dapGroupCustomizablePermissions is enabled on SaaS', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isSaaS: true,
            initialMinimumAccessLevelExecuteAsync: 30,
            initialMinimumAccessLevelExecuteSync: 10,
            glFeatures: {
              dapGroupCustomizablePermissions: true,
            },
          },
        });
      });

      it('renders AiRolePermissions component', () => {
        expect(findAiRolePermissions().exists()).toBe(true);
      });

      it('passes correct initial props', () => {
        expect(findAiRolePermissions().props()).toMatchObject({
          initialMinimumAccessLevelExecuteAsync: 30,
          initialMinimumAccessLevelExecuteSync: 10,
        });
      });

      it('enables save button when minimum access level execute async changes', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findAiRolePermissions().vm.$emit('minimum-access-level-execute-async-change', 40);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('enables save button when minimum access level execute sync changes', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findAiRolePermissions().vm.$emit('minimum-access-level-execute-sync-change', 20);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('emits minimum-access-level-execute-async-changed event when AiRolePermissions emits change', async () => {
        findAiRolePermissions().vm.$emit('minimum-access-level-execute-async-change', 40);
        await nextTick();

        expect(wrapper.emitted('minimum-access-level-execute-async-changed')).toEqual([[40]]);
      });

      it('emits minimum-access-level-execute-sync-changed event when AiRolePermissions emits change', async () => {
        findAiRolePermissions().vm.$emit('minimum-access-level-execute-sync-change', 20);
        await nextTick();

        expect(wrapper.emitted('minimum-access-level-execute-sync-changed')).toEqual([[20]]);
      });
    });

    describe('when dapInstanceCustomizablePermissions is enabled on Self-Managed', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isSaaS: false,
            initialMinimumAccessLevelExecuteAsync: 30,
            initialMinimumAccessLevelExecuteSync: 10,
            glFeatures: {
              dapInstanceCustomizablePermissions: true,
            },
          },
        });
      });

      it('renders AiRolePermissions component', () => {
        expect(findAiRolePermissions().exists()).toBe(true);
      });

      it('passes correct initial props', () => {
        expect(findAiRolePermissions().props()).toMatchObject({
          initialMinimumAccessLevelExecuteAsync: 30,
          initialMinimumAccessLevelExecuteSync: 10,
        });
      });

      it('enables save button when minimum access level execute async changes', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findAiRolePermissions().vm.$emit('minimum-access-level-execute-async-change', 40);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(false);
      });

      it('enables save button when minimum access level execute sync changes', async () => {
        expect(findSaveButton().props('disabled')).toBe(true);

        findAiRolePermissions().vm.$emit('minimum-access-level-execute-sync-change', 20);
        await nextTick();

        expect(findSaveButton().props('disabled')).toBe(false);
      });
    });

    describe('when on SaaS and general settings page with enabled FF', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isSaaS: true,
            glFeatures: {
              dapGroupCustomizablePermissions: true,
            },
            onGeneralSettingsPage: true,
          },
        });
      });

      it('does not render AiRolePermissions component', () => {
        expect(findAiRolePermissions().exists()).toBe(false);
      });
    });

    describe('when on Self-Managed and general settings page with enabled FF', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isSaaS: false,
            glFeatures: {
              dapInstanceCustomizablePermissions: true,
            },
            onGeneralSettingsPage: true,
          },
        });
      });

      it('does not render AiRolePermissions component', () => {
        expect(findAiRolePermissions().exists()).toBe(false);
      });
    });
  });
});
