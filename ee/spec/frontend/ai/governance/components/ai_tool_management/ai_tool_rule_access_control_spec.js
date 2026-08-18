import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlIcon, GlLoadingIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import AiToolRuleAccessControl from 'ee/ai/governance/components/ai_tool_management/ai_tool_rule_access_control.vue';
import updateAiToolRuleMutation from 'ee/ai/governance/graphql/mutations/update_ai_tool_rule.mutation.graphql';

jest.mock('~/alert');

Vue.use(VueApollo);

const mockToolRule = {
  id: 'list_issues',
  name: 'list_issues',
  webAccess: 'ALLOW',
  localAccess: null,
  backgroundAccess: null,
  __typename: 'AiToolRule',
};

const mockMutationSuccess = ({ toolRule: toolRuleOverrides, ...overrides } = {}) => {
  const toolRule =
    toolRuleOverrides === null
      ? null
      : {
          id: 'list_issues',
          webAccess: 'ASK',
          localAccess: null,
          backgroundAccess: null,
          __typename: 'AiToolRule',
          ...toolRuleOverrides,
        };

  return {
    data: {
      updateAiToolRule: {
        toolRule,
        errors: [],
        __typename: 'UpdateAiToolRulePayload',
        ...overrides,
      },
    },
  };
};

describe('AiToolRuleAccessControl', () => {
  let wrapper;
  let mutationHandler;
  let apolloProvider;

  const createComponent = ({
    toolRule = mockToolRule,
    accessType = 'webAccess',
    groupFullPath = 'gitlab-org',
    projectFullPath = '',
    floorValue = null,
    disabled = false,
    disabledTooltip = '',
    mutationHandlerImpl = jest.fn().mockResolvedValue(mockMutationSuccess()),
  } = {}) => {
    mutationHandler = mutationHandlerImpl;
    apolloProvider = createMockApollo([[updateAiToolRuleMutation, mutationHandler]]);

    wrapper = mountExtended(AiToolRuleAccessControl, {
      apolloProvider,
      propsData: {
        toolRule,
        accessType,
        groupFullPath,
        projectFullPath,
        floorValue,
        disabled,
        disabledTooltip,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findToggle = () => wrapper.findByTestId('access-control-toggle');
  const findToggleText = () => wrapper.findByTestId('access-control-toggle-text');
  const findToggleLoadingIcon = () => findToggle().findComponent(GlLoadingIcon);
  const findListItem = (value) => wrapper.findByTestId(`access-option-${value.toLowerCase()}`);
  const findStatic = () => wrapper.findByTestId('access-control-static');
  const findStaticText = () => wrapper.findByTestId('access-control-static-text');
  const selectOption = (value) => findListbox().vm.$emit('select', value);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a collapsible listbox', () => {
      expect(findListbox().exists()).toBe(true);
    });

    it('renders the toggle with the selected option text', () => {
      expect(findToggleText().text()).toBe('Always allow');
    });
  });

  describe('selected state', () => {
    it('reflects the value from toolRule[accessType] for webAccess', () => {
      createComponent({
        toolRule: { ...mockToolRule, webAccess: 'ASK' },
        accessType: 'webAccess',
      });

      expect(findToggleText().text()).toBe('Always ask');
    });

    it('reflects the value from toolRule[accessType] for localAccess', () => {
      createComponent({
        toolRule: { ...mockToolRule, localAccess: 'DENY' },
        accessType: 'localAccess',
      });

      expect(findToggleText().text()).toBe('Always deny');
    });

    it('renders the toggle blank when no value is set', () => {
      createComponent({
        toolRule: { ...mockToolRule, webAccess: null, localAccess: null },
        accessType: 'webAccess',
      });

      expect(findToggleText().exists()).toBe(false);
    });
  });

  describe('list items', () => {
    beforeEach(() => {
      createComponent({ toolRule: { ...mockToolRule, webAccess: 'ASK' } });
    });

    it.each(['ALLOW', 'ASK', 'DENY'])('renders the %s option with its icon', (value) => {
      const item = findListItem(value);
      expect(item.exists()).toBe(true);
      expect(item.findComponent(GlIcon).exists()).toBe(true);
    });
  });

  describe('when an option is selected', () => {
    it('does not call the mutation when the already-selected value is chosen', async () => {
      createComponent({ toolRule: { ...mockToolRule, webAccess: 'ASK' } });

      selectOption('ASK');
      await waitForPromises();

      expect(mutationHandler).not.toHaveBeenCalled();
    });

    it('calls the mutation with only the changed accessType for webAccess', async () => {
      createComponent({ accessType: 'webAccess' });

      selectOption('ASK');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          fullPath: 'gitlab-org',
          toolId: 'list_issues',
          webAccess: 'ASK',
        },
      });
    });

    describe('disabled (read-only) state', () => {
      it('renders the value statically instead of a listbox', () => {
        createComponent({ disabled: true });

        expect(findListbox().exists()).toBe(false);
        expect(findStatic().exists()).toBe(true);
        expect(findStaticText().text()).toBe('Always allow');
      });
    });

    it('calls the mutation with only the changed accessType for localAccess', async () => {
      createComponent({
        toolRule: { ...mockToolRule, localAccess: null },
        accessType: 'localAccess',
      });

      selectOption('DENY');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          fullPath: 'gitlab-org',
          toolId: 'list_issues',
          localAccess: 'DENY',
        },
      });
    });

    it('disables the listbox and shows a loading indicator in the toggle while the mutation is in flight', async () => {
      let resolveMutation;
      createComponent({
        mutationHandlerImpl: jest.fn(
          () =>
            new Promise((resolve) => {
              resolveMutation = resolve;
            }),
        ),
      });

      selectOption('ASK');
      await Vue.nextTick();

      expect(findListbox().props('disabled')).toBe(true);
      expect(findToggleLoadingIcon().exists()).toBe(true);

      resolveMutation(mockMutationSuccess());
      await waitForPromises();

      expect(findListbox().props('disabled')).toBe(false);
      expect(findToggleLoadingIcon().exists()).toBe(false);
    });

    it('does not call the mutation while a previous request is in flight', async () => {
      createComponent({
        mutationHandlerImpl: jest.fn(() => new Promise(() => {})),
      });

      selectOption('ASK');
      await Vue.nextTick();
      selectOption('DENY');
      await Vue.nextTick();

      expect(mutationHandler).toHaveBeenCalledTimes(1);
    });

    it('writes the updated value to the Apollo cache for the AiToolRule entity', async () => {
      createComponent({ accessType: 'webAccess' });
      const writeFragmentSpy = jest.spyOn(apolloProvider.defaultClient, 'writeFragment');

      selectOption('ASK');
      await waitForPromises();

      expect(writeFragmentSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          id: 'AiToolRule:list_issues',
          data: expect.objectContaining({
            __typename: 'AiToolRule',
            webAccess: 'ASK',
            localAccess: null,
          }),
        }),
      );
    });

    it('writes the updated backgroundAccess value to the Apollo cache', async () => {
      createComponent({
        toolRule: { ...mockToolRule, backgroundAccess: null },
        accessType: 'backgroundAccess',
        mutationHandlerImpl: jest.fn().mockResolvedValue(
          mockMutationSuccess({
            toolRule: { backgroundAccess: 'DENY' },
          }),
        ),
      });
      const writeFragmentSpy = jest.spyOn(apolloProvider.defaultClient, 'writeFragment');

      selectOption('DENY');
      await waitForPromises();

      expect(writeFragmentSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          id: 'AiToolRule:list_issues',
          data: expect.objectContaining({
            __typename: 'AiToolRule',
            backgroundAccess: 'DENY',
          }),
        }),
      );
    });
  });

  describe('error handling', () => {
    afterEach(() => {
      createAlert.mockClear();
    });

    it('shows an alert and does not write to the cache when the mutation returns errors', async () => {
      createComponent({
        mutationHandlerImpl: jest.fn().mockResolvedValue(
          mockMutationSuccess({
            toolRule: null,
            errors: ['Something went wrong'],
          }),
        ),
      });
      const writeFragmentSpy = jest.spyOn(apolloProvider.defaultClient, 'writeFragment');

      selectOption('ASK');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to update tool rule. Please try again.',
        captureError: true,
      });
      expect(writeFragmentSpy).not.toHaveBeenCalled();
    });

    it('shows an alert and does not write to the cache when the mutation throws', async () => {
      createComponent({
        mutationHandlerImpl: jest.fn().mockRejectedValue(new Error('Network error')),
      });
      const writeFragmentSpy = jest.spyOn(apolloProvider.defaultClient, 'writeFragment');

      selectOption('ASK');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to update tool rule. Please try again.',
        captureError: true,
      });
      expect(writeFragmentSpy).not.toHaveBeenCalled();
    });

    it('clears the loading state after a failed mutation', async () => {
      createComponent({
        mutationHandlerImpl: jest.fn().mockRejectedValue(new Error('Network error')),
      });

      selectOption('ASK');
      await waitForPromises();

      expect(findListbox().props('disabled')).toBe(false);
      expect(findToggleLoadingIcon().exists()).toBe(false);
    });
  });

  describe('project mode', () => {
    const findItem = (value) =>
      findListbox()
        .props('items')
        .find((item) => item.value === value);

    it('includes projectPath in the mutation input when projectFullPath is set', async () => {
      createComponent({
        accessType: 'webAccess',
        projectFullPath: 'gitlab-org/my-project',
      });

      selectOption('DENY');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          fullPath: 'gitlab-org',
          projectPath: 'gitlab-org/my-project',
          toolId: 'list_issues',
          webAccess: 'DENY',
        },
      });
    });

    it('preserves the other surface value so it is not wiped when creating a project rule', async () => {
      createComponent({
        toolRule: { ...mockToolRule, webAccess: 'ALLOW', localAccess: 'ASK' },
        accessType: 'webAccess',
        projectFullPath: 'gitlab-org/my-project',
      });

      selectOption('DENY');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          fullPath: 'gitlab-org',
          projectPath: 'gitlab-org/my-project',
          toolId: 'list_issues',
          webAccess: 'DENY',
          localAccess: 'ASK',
        },
      });
    });

    it('preserves every other access type, including backgroundAccess, when creating a project rule', async () => {
      // Regression guard: this only passes if the carry-over logic iterates all known
      // access-type keys rather than a binary web/local ternary. If backgroundAccess were
      // dropped from that iteration, the mutation input below would be missing the key.
      createComponent({
        toolRule: {
          ...mockToolRule,
          webAccess: 'ALLOW',
          localAccess: 'ASK',
          backgroundAccess: 'DENY',
        },
        accessType: 'webAccess',
        projectFullPath: 'gitlab-org/my-project',
      });

      selectOption('DENY');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          fullPath: 'gitlab-org',
          projectPath: 'gitlab-org/my-project',
          toolId: 'list_issues',
          webAccess: 'DENY',
          localAccess: 'ASK',
          backgroundAccess: 'DENY',
        },
      });
    });

    it('preserves webAccess and localAccess when updating backgroundAccess on a project rule', async () => {
      createComponent({
        toolRule: {
          ...mockToolRule,
          webAccess: 'ALLOW',
          localAccess: 'ASK',
          backgroundAccess: null,
        },
        accessType: 'backgroundAccess',
        projectFullPath: 'gitlab-org/my-project',
      });

      selectOption('DENY');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          fullPath: 'gitlab-org',
          projectPath: 'gitlab-org/my-project',
          toolId: 'list_issues',
          backgroundAccess: 'DENY',
          webAccess: 'ALLOW',
          localAccess: 'ASK',
        },
      });
    });

    describe('floor enforcement', () => {
      it('keeps a listbox and disables options less restrictive than an ASK floor', () => {
        createComponent({
          toolRule: { ...mockToolRule, webAccess: 'ASK' },
          floorValue: 'ASK',
        });

        expect(findListbox().exists()).toBe(true);
        expect(findItem('ALLOW').disabled).toBe(true);
        expect(findItem('ASK').disabled).toBe(false);
        expect(findItem('DENY').disabled).toBe(false);
      });

      it('does not show the floor tooltip while the dropdown is still interactive', () => {
        createComponent({
          toolRule: { ...mockToolRule, webAccess: 'ASK' },
          floorValue: 'ASK',
        });

        expect(findListbox().exists()).toBe(true);
        expect(wrapper.vm.staticTooltip).toBe('');
      });

      it('renders the value statically when the floor leaves a single option (DENY)', () => {
        createComponent({
          toolRule: { ...mockToolRule, webAccess: 'DENY' },
          floorValue: 'DENY',
        });

        expect(findListbox().exists()).toBe(false);
        expect(findStatic().exists()).toBe(true);
        expect(findStaticText().text()).toBe('Always deny');
      });

      it('leaves every option enabled when no floor value is provided (group mode)', () => {
        createComponent({ floorValue: null });

        expect(findListbox().exists()).toBe(true);
        expect(findItem('ALLOW').disabled).toBeUndefined();
        expect(findItem('ASK').disabled).toBeUndefined();
        expect(findItem('DENY').disabled).toBeUndefined();
      });
    });
  });

  describe('accessType prop validator', () => {
    const { validator } = AiToolRuleAccessControl.props.accessType;

    it('accepts webAccess, localAccess, and backgroundAccess', () => {
      expect(validator('webAccess')).toBe(true);
      expect(validator('localAccess')).toBe(true);
      expect(validator('backgroundAccess')).toBe(true);
    });

    it('rejects an unknown access type', () => {
      expect(validator('runnerAccess')).toBe(false);
      expect(validator('somethingElse')).toBe(false);
    });
  });

  describe('backgroundAccess (Runner)', () => {
    const findItem = (value) =>
      findListbox()
        .props('items')
        .find((item) => item.value === value);

    it('never offers the ASK option', () => {
      createComponent({
        toolRule: { ...mockToolRule, backgroundAccess: 'ALLOW' },
        accessType: 'backgroundAccess',
      });

      const values = findListbox()
        .props('items')
        .map((item) => item.value);

      expect(values).toEqual(['ALLOW', 'DENY']);
      expect(values).not.toContain('ASK');
      expect(findListItem('ASK').exists()).toBe(false);
    });

    it('offers only ALLOW and DENY, both enabled, when no floor is set', () => {
      createComponent({
        toolRule: { ...mockToolRule, backgroundAccess: 'ALLOW' },
        accessType: 'backgroundAccess',
        floorValue: null,
      });

      expect(findItem('ALLOW').disabled).toBeUndefined();
      expect(findItem('DENY').disabled).toBeUndefined();
    });

    it('renders the value statically when a DENY floor collapses to a single option', () => {
      createComponent({
        toolRule: { ...mockToolRule, backgroundAccess: 'DENY' },
        accessType: 'backgroundAccess',
        floorValue: 'DENY',
      });

      expect(findListbox().exists()).toBe(false);
      expect(findStatic().exists()).toBe(true);
      expect(findStaticText().text()).toBe('Always deny');
    });

    it('calls the mutation with only backgroundAccess when changed at the group level', async () => {
      createComponent({
        toolRule: { ...mockToolRule, backgroundAccess: 'ALLOW' },
        accessType: 'backgroundAccess',
      });

      selectOption('DENY');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: {
          fullPath: 'gitlab-org',
          toolId: 'list_issues',
          backgroundAccess: 'DENY',
        },
      });
    });
  });
});
