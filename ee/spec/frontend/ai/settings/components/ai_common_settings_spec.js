import { GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCommonSettings from 'ee/ai/settings/components/ai_common_settings.vue';
import AiCommonSettingsForm from 'ee/ai/settings/components/ai_common_settings_form.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import { mockAgentStatuses } from '../../mocks';

describe('AiCommonSettings', () => {
  let wrapper;
  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(AiCommonSettings, {
      propsData: {
        hasParentFormChanged: false,
        ...props,
      },
      provide: {
        duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
        experimentFeaturesEnabled: false,
        duoCoreFeaturesEnabled: false,
        promptCacheEnabled: true,
        initialDuoRemoteFlowsAvailability: false,
        initialDuoSastFpDetectionAvailability: false,
        foundationalAgentsDefaultEnabled: true,
        initialFoundationalAgentsStatuses: mockAgentStatuses,
        initialDuoFoundationalFlowsAvailability: false,
        initialDuoCustomAgentsAvailability: true,
        initialDuoCustomFlowsAvailability: true,
        initialDuoExternalAgentsAvailability: true,
        initialDuoWorkflowsDefaultImageRegistry: '',
        initialSelectedFoundationalFlowIds: [],
        initialDuoAgentPlatformEnabled: true,
        initialDuoCliEnabled: true,
        initialToolApprovalForSessionAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        initialNamespaceAccessRules: [],
        initialMinimumAccessLevelExecuteAsync: 30,
        initialMinimumAccessLevelExecuteSync: 10,
        initialDuoTemplateProject: null,
        includeRecommendedAllowedDomains: false,
        allowAllUnixSockets: false,
        allowProjectExtension: true,
        onGeneralSettingsPage: false,
        ...provide,
      },
      stubs: {
        GlSprintf: {
          template: `
            <span>
              <slot name="link" v-bind="{ content: $attrs.message }">
              </slot>
            </span>
          `,
          components: {
            GlLink,
          },
        },
      },
      slots: {
        'ai-common-settings-top': '<div data-testid="top-slot-content">Top slot content</div>',
        'ai-common-settings-tools':
          '<div data-testid="tools-slot-content">Tools slot content</div>',
        'ai-common-settings-data-privacy':
          '<div data-testid="data-privacy-slot-content">Data privacy slot content</div>',
        'ai-common-settings-hosting':
          '<div data-testid="hosting-slot-content">Hosting slot content</div>',
        'ai-common-settings-bottom':
          '<div data-testid="bottom-slot-content">Bottom slot content</div>',
      },
    });
  };

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);
  const findGeneralSettingsDescriptionText = () =>
    wrapper.findByTestId('general-settings-subtitle');
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findForm = () => wrapper.findComponent(AiCommonSettingsForm);
  const findTopSettingsSlot = () => wrapper.findByTestId('top-slot-content');
  const findToolsSettingsSlot = () => wrapper.findByTestId('tools-slot-content');
  const findDataPrivacySettingsSlot = () => wrapper.findByTestId('data-privacy-slot-content');
  const findHostingSettingsSlot = () => wrapper.findByTestId('hosting-slot-content');
  const findBottomSettingsSlot = () => wrapper.findByTestId('bottom-slot-content');

  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('renders the AiCommonSettingsForm component', () => {
    expect(findForm().exists()).toBe(true);
  });

  // Regression coverage for https://gitlab.com/gitlab-org/gitlab/-/work_items/599212
  // Every availability setter also writes a cascading `lock_*` column, so an
  // untouched value that an ancestor has locked failed the whole PUT with 400.
  describe('availability params', () => {
    const submitForm = () => findForm().vm.$emit('submit', { preventDefault: jest.fn() });
    const emittedPayload = () => wrapper.emitted('submit')[0][0];

    describe.each`
      param                                   | event                                        | initialValue     | changedValue
      ${'duoAvailability'}                    | ${'radio-changed'}                           | ${'default_on'}  | ${'never_on'}
      ${'duoRemoteFlowsAvailability'}         | ${'duo-flow-checkbox-changed'}               | ${false}         | ${true}
      ${'duoFoundationalFlowsAvailability'}   | ${'duo-foundational-flows-checkbox-changed'} | ${false}         | ${true}
      ${'duoCustomAgentsAvailability'}        | ${'duo-custom-agents-changed'}               | ${true}          | ${false}
      ${'duoCustomFlowsAvailability'}         | ${'duo-custom-flows-changed'}                | ${true}          | ${false}
      ${'duoExternalAgentsAvailability'}      | ${'duo-external-agents-changed'}             | ${true}          | ${false}
      ${'toolApprovalForSessionAvailability'} | ${'tool-approval-for-session-changed'}       | ${'default_off'} | ${'default_on'}
    `('$param', ({ param, event, initialValue, changedValue }) => {
      it('is omitted when untouched', () => {
        submitForm();

        expect(emittedPayload()).not.toHaveProperty(param);
      });

      it('is omitted when set back to its initial value', async () => {
        await findForm().vm.$emit(event, changedValue);
        await findForm().vm.$emit(event, initialValue);
        submitForm();

        expect(emittedPayload()).not.toHaveProperty(param);
      });

      it('is sent when changed', async () => {
        await findForm().vm.$emit(event, changedValue);
        submitForm();

        expect(emittedPayload()[param]).toBe(changedValue);
      });
    });
  });

  it('emits submit event with correct data when form is submitted via AiCommonSettingsForm component', async () => {
    await findForm().vm.$emit('radio-changed', AVAILABILITY_OPTIONS.DEFAULT_OFF);
    await findForm().vm.$emit('experiment-checkbox-changed', true);
    await findForm().vm.$emit('duo-core-checkbox-changed', true);
    await findForm().vm.$emit('duo-flow-checkbox-changed', true);
    await findForm().vm.$emit('duo-foundational-agents-changed', true);
    await findForm().vm.$emit('duo-foundational-flows-checkbox-changed', true);
    await findForm().vm.$emit('duo-external-agents-changed', false);
    await findForm().vm.$emit('duo-custom-agents-changed', false);
    await findForm().vm.$emit('duo-custom-flows-changed', false);
    await findForm().vm.$emit('tool-approval-for-session-changed', AVAILABILITY_OPTIONS.DEFAULT_ON);
    await findForm().vm.$emit('change-selected-flow-ids', [1, 2]);
    await findForm().vm.$emit('duo-agent-platform-enabled-changed', false);
    await findForm().vm.$emit('duo-cli-enabled-changed', false);
    await findForm().vm.$emit('namespace-access-rules-changed', [
      { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
    ]);
    await findForm().vm.$emit('minimum-access-level-execute-async-changed', 40);
    await findForm().vm.$emit('minimum-access-level-execute-sync-changed', 20);
    await findForm().vm.$emit('change-default-image-registry', 'registry.example.com');
    findForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
    });
    const emittedData = wrapper.emitted('submit')[0][0];
    expect(emittedData).toEqual({
      duoAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
      experimentFeaturesEnabled: true,
      duoCoreFeaturesEnabled: true,
      promptCacheEnabled: true,
      duoRemoteFlowsAvailability: true,
      duoFoundationalFlowsAvailability: true,
      duoCustomAgentsAvailability: false,
      duoCustomFlowsAvailability: false,
      duoExternalAgentsAvailability: false,
      foundationalAgentsEnabled: true,
      selectedFoundationalFlowIds: [1, 2],
      foundationalAgentsStatuses: mockAgentStatuses,
      duoAgentPlatformEnabled: false,
      duoCliEnabled: false,
      toolApprovalForSessionAvailability: AVAILABILITY_OPTIONS.DEFAULT_ON,
      namespaceAccessRules: [
        { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
      ],
      minimumAccessLevelExecuteAsync: 40,
      minimumAccessLevelExecuteSync: 20,
      duoWorkflowsDefaultImageRegistry: 'registry.example.com',
      duoTemplateProject: null,
    });
  });

  it('re-emits radio-changed event to parent when form emits radio-changed', async () => {
    await findForm().vm.$emit('radio-changed', AVAILABILITY_OPTIONS.NEVER_ON);

    expect(wrapper.emitted('radio-changed')).toEqual([[AVAILABILITY_OPTIONS.NEVER_ON]]);
  });

  it('does not include namespaceAccessRules in submit event when they have not been changed', async () => {
    await findForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
    });

    const emittedData = wrapper.emitted('submit')[0][0];

    expect(emittedData).not.toHaveProperty('namespaceAccessRules');
  });

  it('includes namespaceAccessRules when a change has been made', async () => {
    await findForm().vm.$emit('namespace-access-rules-changed', [
      { throughNamespace: { id: 1, name: 'group' }, features: ['duo_agent_platform'] },
    ]);

    await findForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
    });

    const emittedData = wrapper.emitted('submit')[0][0];

    expect(emittedData).toHaveProperty('namespaceAccessRules');
  });

  describe('when on general settings page', () => {
    beforeEach(() => {
      createComponent({ provide: { onGeneralSettingsPage: true } });
    });

    it('renders SettingsBlock component', () => {
      expect(findSettingsBlock().exists()).toBe(true);
    });

    it('passes props to settings-block component', () => {
      expect(findSettingsBlock().props()).toEqual({
        expanded: false,
        id: 'js-gitlab-duo-settings',
        title: 'GitLab Duo features',
      });
    });

    it('renders the settings block description text', () => {
      expect(findGeneralSettingsDescriptionText().text()).toContain(
        'Configure AI-native GitLab Duo features',
      );
    });

    it('renders ai-common-settings slots', () => {
      expect(findTopSettingsSlot().exists()).toBe(true);
      expect(findToolsSettingsSlot().exists()).toBe(true);
      expect(findDataPrivacySettingsSlot().exists()).toBe(true);
      expect(findHostingSettingsSlot().exists()).toBe(true);
      expect(findBottomSettingsSlot().exists()).toBe(true);
    });
  });

  describe('when not on general settings page', () => {
    beforeEach(() => {
      createComponent({ provide: { onGeneralSettingsPage: false } });
    });

    it('renders PageHeading component', () => {
      expect(findPageHeading().exists()).toBe(true);
    });

    it('renders correct title in PageHeading', () => {
      expect(findPageHeading().props('heading')).toBe('Configuration');
    });

    it('renders correct subtitle in PageHeading', () => {
      expect(wrapper.findByTestId('configuration-page-subtitle').exists()).toBe(true);
    });

    it('renders ai-common-settings slots', () => {
      expect(findTopSettingsSlot().exists()).toBe(true);
      expect(findToolsSettingsSlot().exists()).toBe(true);
      expect(findDataPrivacySettingsSlot().exists()).toBe(true);
      expect(findHostingSettingsSlot().exists()).toBe(true);
      expect(findBottomSettingsSlot().exists()).toBe(true);
    });

    it('passes initialNamespaceAccessRules prop to form', () => {
      expect(findForm().props('initialNamespaceAccessRules')).toEqual([]);
    });

    it('re-emits code-review-flow-consent-given event when form emits code-review-flow-consent-given', async () => {
      await findForm().vm.$emit('code-review-flow-consent-given');

      expect(wrapper.emitted('code-review-flow-consent-given')).toHaveLength(1);
    });
  });

  describe('duo CLI enabled', () => {
    it('passes initialDuoCliEnabled to the form', () => {
      expect(findForm().props('duoCliEnabled')).toBe(true);
    });

    it('includes updated duoCliEnabled in submit event', async () => {
      await findForm().vm.$emit('duo-cli-enabled-changed', false);
      findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      const [[{ duoCliEnabled }]] = wrapper.emitted('submit');
      expect(duoCliEnabled).toBe(false);
    });
  });

  describe('foundational agents', () => {
    it('passes foundational-agents-enabled value to the form', () => {
      expect(findForm().props('foundationalAgentsEnabled')).toEqual(true);
    });

    it('includes foundational agents enabled in submit event', async () => {
      await findForm().vm.$emit('duo-foundational-agents-changed', false);
      findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      const [[{ foundationalAgentsEnabled }]] = wrapper.emitted('submit');
      expect(foundationalAgentsEnabled).toEqual(false);
    });

    describe('per agent settings', () => {
      it('passes foundational-agents-statuses to the form', () => {
        expect(findForm().props('foundationalAgentsStatuses')).toEqual(mockAgentStatuses);
      });

      it('includes foundational agents statuses in submit event', async () => {
        const updatedStatuses = [
          { reference: 'security-analyst', name: 'Security Analyst', enabled: false },
          { reference: 'code-reviewer', name: 'Code Reviewer', enabled: true },
          { reference: 'test-agent', name: 'Test Agent', enabled: null },
        ];

        await findForm().vm.$emit('duo-foundational-agents-statuses-change', updatedStatuses);
        findForm().vm.$emit('submit', { preventDefault: jest.fn() });

        const [[{ foundationalAgentsStatuses }]] = wrapper.emitted('submit');
        expect(foundationalAgentsStatuses).toEqual(updatedStatuses);
      });
    });
  });

  describe('minimum access level permissions', () => {
    it('updates internal state when form emits minimum-access-level-execute-async-changed', async () => {
      expect(wrapper.vm.minimumAccessLevelExecuteAsync).toBe(30);

      await findForm().vm.$emit('minimum-access-level-execute-async-changed', 40);

      expect(wrapper.vm.minimumAccessLevelExecuteAsync).toBe(40);
    });

    it('updates internal state when form emits minimum-access-level-execute-sync-changed', async () => {
      expect(wrapper.vm.minimumAccessLevelExecuteSync).toBe(10);

      await findForm().vm.$emit('minimum-access-level-execute-sync-changed', 20);

      expect(wrapper.vm.minimumAccessLevelExecuteSync).toBe(20);
    });

    it('includes minimum access levels in submit event', async () => {
      await findForm().vm.$emit('minimum-access-level-execute-async-changed', 40);
      await findForm().vm.$emit('minimum-access-level-execute-sync-changed', 20);
      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      const emittedData = wrapper.emitted('submit')[0][0];
      expect(emittedData).toMatchObject({
        minimumAccessLevelExecuteAsync: 40,
        minimumAccessLevelExecuteSync: 20,
      });
    });
  });

  describe('duo workflows default image registry', () => {
    it('updates internal state when form emits change-default-image-registry', async () => {
      expect(wrapper.vm.duoWorkflowsDefaultImageRegistry).toBe('');

      await findForm().vm.$emit('change-default-image-registry', 'registry.example.com');

      expect(wrapper.vm.duoWorkflowsDefaultImageRegistry).toBe('registry.example.com');
    });

    it('includes duo workflows default image registry in submit event', async () => {
      await findForm().vm.$emit('change-default-image-registry', 'registry.example.com');
      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });

      const emittedData = wrapper.emitted('submit')[0][0];
      expect(emittedData).toMatchObject({
        duoWorkflowsDefaultImageRegistry: 'registry.example.com',
      });
    });
  });
});
