import { GlButton, GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { EMPTY_CATALOGS, fetchCatalogs } from 'ee/policy_store/catalog/catalogs';
import StepWizard from 'ee/policy_store/components/editor/step_wizard.vue';
import BuildPolicyStep from 'ee/policy_store/components/editor/steps/build_policy_step.vue';
import ScopeStep from 'ee/policy_store/components/editor/steps/scope_step.vue';
import ReviewStep from 'ee/policy_store/components/editor/steps/review_step.vue';
import PolicyNameField from 'ee/policy_store/components/editor/policy_name_field.vue';
import WizardControls from 'ee/policy_store/components/editor/wizard_controls.vue';

jest.mock('ee/policy_store/catalog/catalogs', () => ({
  ...jest.requireActual('ee/policy_store/catalog/catalogs'),
  fetchCatalogs: jest.fn(),
}));

describe('StepWizard', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(StepWizard, { propsData });
  };

  beforeEach(() => {
    fetchCatalogs.mockResolvedValue({ catalogs: EMPTY_CATALOGS, failedCatalogs: [] });
  });

  const findNameField = () => wrapper.findComponent(PolicyNameField);
  const findControls = () => wrapper.findComponent(WizardControls);
  const findStepContent = () => wrapper.findByTestId('wizard-step-content');
  const findBuildStep = () => wrapper.findComponent(BuildPolicyStep);
  const findModal = () => wrapper.findComponent(GlModal);
  const findScopeStep = () => wrapper.findComponent(ScopeStep);
  const findButtonByText = (text) =>
    wrapper.findAllComponents(GlButton).wrappers.find((button) => button.text() === text);

  const stepStatuses = () =>
    findControls()
      .props('steps')
      .map(({ status }) => status);

  it('starts with an empty name for a new policy', () => {
    createComponent();

    expect(findNameField().props('name')).toBe('');
  });

  it('seeds name and description from an existing policy', () => {
    createComponent({ policy: { name: 'My policy', description: 'Some description' } });

    expect(findNameField().props('name')).toBe('My policy');
    expect(findNameField().props('description')).toBe('Some description');
  });

  it('renders the steps in order with the first step current', () => {
    createComponent();

    expect(
      findControls()
        .props('steps')
        .map(({ label }) => label),
    ).toEqual(['Build policy', 'Select scope', 'Review impact']);
    expect(stepStatuses()).toEqual(['current', 'upcoming', 'upcoming']);
    expect(findBuildStep().exists()).toBe(true);
  });

  it('marks only the last step as last, which ends the connector line', () => {
    createComponent();

    expect(
      findControls()
        .props('steps')
        .map(({ isLast }) => isLast),
    ).toEqual([false, false, true]);
  });

  it('completes a step once it has been passed', async () => {
    createComponent();

    await findButtonByText('Next').vm.$emit('click');

    expect(stepStatuses()).toEqual(['complete', 'current', 'upcoming']);
  });

  it('keeps the header above the content on every step', async () => {
    createComponent();

    expect(findNameField().exists()).toBe(true);
    expect(findControls().exists()).toBe(true);

    await findButtonByText('Next').vm.$emit('click');

    expect(findNameField().exists()).toBe(true);
    expect(findControls().exists()).toBe(true);
    expect(findBuildStep().exists()).toBe(false);
  });

  it('renders the scope step when advancing to it', async () => {
    createComponent();

    expect(findScopeStep().exists()).toBe(false);

    await findButtonByText('Next').vm.$emit('click');

    expect(findScopeStep().exists()).toBe(true);
  });

  it('renders the enforcement mode selector defaulting to Enforce', () => {
    createComponent();

    expect(findControls().props('mode')).toBe('enforce');
  });

  it('fetches the catalogs when the editor opens and passes them to the steps', async () => {
    const catalogs = { triggers: [], rules: [], actions: [] };
    fetchCatalogs.mockResolvedValue({ catalogs, failedCatalogs: [] });

    createComponent();
    await waitForPromises();

    expect(findBuildStep().props('catalogs')).toBe(catalogs);

    await findButtonByText('Next').vm.$emit('click');
    await findButtonByText('Next').vm.$emit('click');

    expect(wrapper.findComponent(ReviewStep).props('catalogs')).toBe(catalogs);
  });

  it('marks the catalogs as loading while the fetch is in flight and disables Next', () => {
    fetchCatalogs.mockReturnValue(new Promise(() => {}));

    createComponent();

    expect(findBuildStep().props('catalogsLoading')).toBe(true);
    expect(findBuildStep().props('catalogs')).toBe(EMPTY_CATALOGS);
    expect(findButtonByText('Next').props('disabled')).toBe(true);
  });

  it('ends the loading state and enables Next once the fetch resolves', async () => {
    createComponent();
    await waitForPromises();

    expect(findBuildStep().props('catalogsLoading')).toBe(false);
    expect(findBuildStep().props('failedCatalogs')).toEqual([]);
    expect(findButtonByText('Next').props('disabled')).toBe(false);
  });

  it('passes the failing catalogs alongside the partial results', async () => {
    const catalogs = { triggers: [], rules: [{ id: 'custom' }], actions: [{ id: 'block' }] };
    fetchCatalogs.mockResolvedValue({ catalogs, failedCatalogs: ['triggers'] });

    createComponent();
    await waitForPromises();

    expect(findBuildStep().props('failedCatalogs')).toEqual(['triggers']);
    expect(findBuildStep().props('catalogs')).toBe(catalogs);
    expect(findBuildStep().props('catalogsLoading')).toBe(false);
  });

  it('treats an unexpected error as all catalogs failing', async () => {
    fetchCatalogs.mockRejectedValue(new Error('request failed'));

    createComponent();
    await waitForPromises();

    expect(findBuildStep().props('failedCatalogs')).toEqual(['triggers', 'rules', 'actions']);
    expect(findBuildStep().props('catalogsLoading')).toBe(false);
  });

  it('goes back to the previous step when Back is clicked', async () => {
    createComponent();

    await findButtonByText('Next').vm.$emit('click');
    await findButtonByText('Back').vm.$emit('click');

    expect(findBuildStep().exists()).toBe(true);
  });

  describe('build step', () => {
    it('renders the build step rather than a placeholder for the first step', () => {
      createComponent();

      expect(findBuildStep().exists()).toBe(true);
      expect(findStepContent().text()).not.toContain('coming soon');
    });

    it('starts with empty policy data for a new policy', () => {
      createComponent();

      expect(findBuildStep().props('policyData')).toEqual({
        trigger: null,
        triggerConfig: {},
        rules: [],
        ruleConfigs: {},
        actions: [],
        actionConfigs: {},
      });
    });

    it('seeds policy data from an existing policy', () => {
      createComponent({
        policy: {
          name: 'Prod gate',
          trigger_type: 'deployment_requested',
          rules: [{ type: 'custom', value: 'package governance' }],
          actions: [{ type: 'block' }],
        },
      });

      expect(findBuildStep().props('policyData')).toMatchObject({
        trigger: 'deployment_requested',
        rules: ['custom'],
        ruleConfigs: { custom: { policy: 'package governance' } },
        actions: ['block'],
      });
    });

    it('keeps policy data when navigating away and back', async () => {
      createComponent();

      findBuildStep().vm.$emit('update', {
        trigger: 'deployment_requested',
        triggerConfig: {},
        rules: ['custom'],
        ruleConfigs: {},
        actions: [],
        actionConfigs: {},
      });
      await findButtonByText('Next').vm.$emit('click');
      await findButtonByText('Back').vm.$emit('click');

      expect(findBuildStep().props('policyData')).toMatchObject({
        trigger: 'deployment_requested',
        rules: ['custom'],
      });
    });
  });

  it('hides Back on the first step and Next on the last step', async () => {
    createComponent();

    expect(findButtonByText('Back')).toBeUndefined();

    await findButtonByText('Next').vm.$emit('click');
    await findButtonByText('Next').vm.$emit('click');

    expect(findButtonByText('Next')).toBeUndefined();
    expect(findButtonByText('Back')).toBeDefined();
  });

  it('renders the review step on the last step seeded with the policy name', async () => {
    createComponent({ policy: { name: 'My policy' } });

    expect(wrapper.findComponent(ReviewStep).exists()).toBe(false);

    await findButtonByText('Next').vm.$emit('click');
    await findButtonByText('Next').vm.$emit('click');

    expect(wrapper.findComponent(ReviewStep).props('policy').name).toBe('My policy');
  });

  it('passes the mode, scope, and Build step selections to the review step', async () => {
    createComponent({
      policy: {
        name: 'My policy',
        mode: 'warn',
        policy_scope: { projects: { including: [1] } },
        trigger_type: 'deployment_requested',
        rules: [{ type: 'custom', value: 'package x' }],
        actions: [{ type: 'block' }],
      },
    });

    await findButtonByText('Next').vm.$emit('click');
    await findButtonByText('Next').vm.$emit('click');

    expect(wrapper.findComponent(ReviewStep).props('policy')).toMatchObject({
      mode: 'warn',
      scope: { mode: 'specific', projects: [{ id: 'gid://gitlab/Project/1' }] },
      trigger: 'deployment_requested',
      rules: ['custom'],
      actions: ['block'],
    });
  });

  describe('save button', () => {
    const findSaveButton = () => wrapper.findComponentByTestId('save-policy-button');
    const savablePolicy = {
      name: 'Prod gate',
      trigger_type: 'deployment_requested',
      rules: [{ type: 'custom', value: 'package governance' }],
    };

    const goToLastStep = async () => {
      await findButtonByText('Next').vm.$emit('click');
      await findButtonByText('Next').vm.$emit('click');
    };

    it('does not render before the last step', () => {
      createComponent();

      expect(findSaveButton().exists()).toBe(false);
    });

    it('is disabled while the policy lacks a name, trigger or rule', async () => {
      createComponent();
      await goToLastStep();

      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('is enabled once the policy has a name, a trigger and a rule', async () => {
      createComponent({ policy: savablePolicy });
      await goToLastStep();

      expect(findSaveButton().props('disabled')).toBe(false);
    });

    it('emits save with everything the wizard edits', async () => {
      createComponent({ policy: savablePolicy });
      await goToLastStep();

      findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('save')).toEqual([
        [
          {
            name: 'Prod gate',
            description: '',
            mode: 'enforce',
            scope: { mode: 'all', projects: [], exclusions: [] },
            scopeChanged: false,
            policyData: expect.objectContaining({
              trigger: 'deployment_requested',
              rules: ['custom'],
            }),
          },
        ],
      ]);
    });

    it('reports the scope as changed once the Scope step is touched', async () => {
      createComponent({ policy: savablePolicy });
      await findButtonByText('Next').vm.$emit('click');

      await findScopeStep().vm.$emit('update', {
        mode: 'specific',
        projects: [{ id: 'gid://gitlab/Project/1' }],
        exclusions: [],
      });
      await findButtonByText('Next').vm.$emit('click');

      findSaveButton().vm.$emit('click');

      expect(wrapper.emitted('save')[0][0]).toMatchObject({
        scopeChanged: true,
        scope: { mode: 'specific', projects: [{ id: 'gid://gitlab/Project/1' }] },
      });
    });

    it('shows as loading while the save is in flight', async () => {
      createComponent({ policy: savablePolicy, saving: true });
      await goToLastStep();

      expect(findSaveButton().props('loading')).toBe(true);
    });
  });

  it('returns to the first step when the review step emits edit', async () => {
    createComponent();
    await findButtonByText('Next').vm.$emit('click');
    await findButtonByText('Next').vm.$emit('click');

    await wrapper.findComponent(ReviewStep).vm.$emit('edit');

    expect(findBuildStep().exists()).toBe(true);
    expect(wrapper.findComponent(ReviewStep).exists()).toBe(false);
  });

  it('emits cancel immediately when there are no unsaved changes', () => {
    createComponent();

    findButtonByText('Cancel').vm.$emit('click');

    expect(findModal().props('visible')).toBe(false);
    expect(wrapper.emitted('cancel')).toHaveLength(1);
  });

  it('confirms before discarding when the name has changed', async () => {
    createComponent();

    await findNameField().vm.$emit('update:name', 'My new policy');
    await findButtonByText('Cancel').vm.$emit('click');

    expect(findModal().props('visible')).toBe(true);
    expect(wrapper.emitted('cancel')).toBeUndefined();
  });

  it('emits cancel when the discard action is confirmed', async () => {
    createComponent();
    await findNameField().vm.$emit('update:name', 'My new policy');
    await findButtonByText('Cancel').vm.$emit('click');

    findModal().vm.$emit('primary');

    expect(wrapper.emitted('cancel')).toHaveLength(1);
  });

  it('leaves immediately when an existing policy is opened and left unchanged', () => {
    createComponent({ policy: { name: 'My policy', description: 'Some description' } });

    findButtonByText('Cancel').vm.$emit('click');

    expect(findModal().props('visible')).toBe(false);
    expect(wrapper.emitted('cancel')).toHaveLength(1);
  });

  it('leaves immediately on cancel after only advancing a step', async () => {
    createComponent();
    await findButtonByText('Next').vm.$emit('click');

    findButtonByText('Cancel').vm.$emit('click');

    expect(findModal().props('visible')).toBe(false);
    expect(wrapper.emitted('cancel')).toHaveLength(1);
  });

  it('confirms before discarding when the enforcement mode has changed', async () => {
    createComponent();

    await findControls().vm.$emit('select-mode', 'audit');
    await findButtonByText('Cancel').vm.$emit('click');

    expect(findModal().props('visible')).toBe(true);
    expect(wrapper.emitted('cancel')).toBeUndefined();
  });

  it('confirms before discarding when the scope has changed', async () => {
    createComponent();
    await findButtonByText('Next').vm.$emit('click');

    await findScopeStep().vm.$emit('update', { mode: 'specific', projects: [{ id: '1' }] });
    await findButtonByText('Cancel').vm.$emit('click');

    expect(findModal().props('visible')).toBe(true);
    expect(wrapper.emitted('cancel')).toBeUndefined();
  });

  it('confirms before discarding when the Build step selections have changed', async () => {
    createComponent();

    await findBuildStep().vm.$emit('update', {
      trigger: null,
      triggerConfig: {},
      rules: ['custom'],
      ruleConfigs: {},
      actions: [],
      actionConfigs: {},
    });
    await findButtonByText('Cancel').vm.$emit('click');

    expect(findModal().props('visible')).toBe(true);
    expect(wrapper.emitted('cancel')).toBeUndefined();
  });
});
