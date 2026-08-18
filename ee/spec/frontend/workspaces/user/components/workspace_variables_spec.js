import { GlTable, GlButton, GlFormInput, GlFormGroup } from '@gitlab/ui';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import WorkspaceVariables from 'ee/workspaces/user/components/workspace_variables.vue';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import { extendedWrapper, mountExtended } from 'helpers/vue_test_utils_helper';
import { WORKSPACE_VARIABLE_INPUT_TYPE_ENUM } from 'ee/workspaces/user/constants';

describe('workspaces/user/components/workspace_variables.vue', () => {
  let wrapper;
  let mockApollo;

  const buildMockApollo = () => {
    mockApollo = createMockApollo([]);
  };

  const GlFormGroupStub = stubComponent(GlFormGroup, {
    props: {
      ...GlFormGroup.props,
      state: {
        type: Boolean,
        required: false,
        default: undefined,
      },
    },
  });

  const buildWrapper = ({ mountFn = mountExtended, variables, showValidations = false } = {}) => {
    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = mountFn(WorkspaceVariables, {
      apolloProvider: mockApollo,
      propsData: {
        variables,
        showValidations,
      },
      stubs: {
        GlTable,
        GlButton,
        GlFormInput,
        GlFormGroup: GlFormGroupStub,
      },
    });
  };

  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findTable = () => extendedWrapper(wrapper.findComponent(GlTable));
  const findAddButton = () =>
    extendedWrapper(wrapper.findByRole('button', { name: /Add variable/i }));

  beforeEach(() => {
    buildMockApollo();
  });

  it('renders empty state', () => {
    const variables = [];
    buildWrapper({ variables });
    expect(findCrudComponent().props('title')).toBe('Variables');
    expect(findCrudComponent().props('icon')).toBe('code');
    expect(findCrudComponent().props('count')).toBe(0);
    expect(findCrudComponent().text()).toContain('There are no variables yet.');
    expect(findAddButton().exists()).toBe(true);
  });

  it('renders table with variables', () => {
    const variables = [
      {
        key: 'foo1',
        value: 'bar1',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
      {
        key: 'foo2',
        value: 'bar2',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    buildWrapper({ variables });

    const keys = wrapper.findAllByTestId('key');
    const values = wrapper.findAllByTestId('value');
    const removeButtons = wrapper.findAllByTestId('remove-variable');
    variables.forEach((variable, index) => {
      expect(keys.at(index).element.value).toBe(variable.key);
      expect(values.at(index).element.value).toBe(variable.value);
      expect(removeButtons.at(index).exists()).toBe(true);
    });
  });

  it('adds a new variable', async () => {
    const variables = [
      {
        key: 'foo1',
        value: 'bar1',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    buildWrapper({ variables });

    await findAddButton().trigger('click');
    const emittedEvents = wrapper.emitted();
    expect(emittedEvents['add-variable']).toHaveLength(1);
    expect(emittedEvents.input).toMatchObject([
      [[...variables, { key: '', value: '', valid: false }]],
    ]);
  });

  it('removes a variable', () => {
    const variables = [
      {
        key: 'foo1',
        value: 'bar1',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
      {
        key: 'foo2',
        value: 'bar2',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
      {
        key: 'foo3',
        value: 'bar3',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    buildWrapper({ variables });

    wrapper.findAllComponentsByTestId('remove-variable').at(1).vm.$emit('click');
    const emittedEvents = wrapper.emitted();
    expect(emittedEvents.input).toMatchObject([[[...variables.toSpliced(1, 1)]]]);
  });

  it('updates a variable key', async () => {
    const variables = [
      {
        key: '',
        value: '',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    const expectedVariables = [
      {
        key: 'foo1',
        value: '',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: true,
      },
    ];
    buildWrapper({ variables });

    const keys = wrapper.findAllComponentsByTestId('key');
    await keys.at(0).vm.$emit('input', 'foo1');
    const emittedEvents = wrapper.emitted();
    expect(emittedEvents.input).toMatchObject([[[...expectedVariables]]]);
  });

  it('updates a variable value', async () => {
    const variables = [
      {
        key: '',
        value: '',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    const expectedVariables = [
      {
        key: '',
        value: 'bar1',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
    ];
    buildWrapper({ variables });

    const values = wrapper.findAllComponentsByTestId('value');
    await values.at(0).vm.$emit('input', 'bar1');
    const emittedEvents = wrapper.emitted();
    expect(emittedEvents.input).toMatchObject([[[...expectedVariables]]]);
  });

  it('shows validations', () => {
    const variables = [
      {
        key: '',
        value: '',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: false,
      },
      {
        key: 'foo2',
        value: '',
        variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
        valid: true,
      },
    ];
    const showValidations = true;
    buildWrapper({ variables, showValidations });

    variables.forEach((variable, index) => {
      const row = findTable().findAll('tbody tr').at(index);
      const formGroups = row.findAllComponents(GlFormGroupStub);
      const [keyFormGroup, valueFormGroup] = formGroups.wrappers;

      expect(keyFormGroup.props().state).toBe(variable.valid);
      // Value form group is not validated
      expect(valueFormGroup.props().state).toBe(undefined);
    });
  });
});
