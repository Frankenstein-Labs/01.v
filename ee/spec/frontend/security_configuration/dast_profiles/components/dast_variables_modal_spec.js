import {
  GlModal,
  GlCollapsibleListbox,
  GlFormInput,
  GlFormGroup,
  GlFormRadioGroup,
  GlFormRadio,
  GlFormTextarea,
  GlSprintf,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import DastVariablesModal from 'ee/security_configuration/dast_profiles/components/dast_variables_modal.vue';
import { mockAdditionalVariableOptions } from 'ee_jest/security_configuration/dast_profiles/mocks/mock_data';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('DastVariablesModal', () => {
  let wrapper;

  const descriptionLinkMock = 'More details [here](https://example.com)';
  const descriptionMock = {
    message: 'More details',
  };

  const variableMock = {
    id: 'DAST_ACTIVE_SCAN_TIMEOUT',
    type: 'Duration string',
    value: '3h',
    description: descriptionMock,
  };

  const createComponent = (props = {}, stubs = {}) => {
    wrapper = shallowMountExtended(DastVariablesModal, {
      propsData: props,
      provide: {
        additionalVariableOptions: mockAdditionalVariableOptions,
      },
      stubs: {
        GlFormGroup,
        GlSprintf,
        ...stubs,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findVariableSelector = () => wrapper.findComponent(GlCollapsibleListbox);
  const findValueInput = () => wrapper.findComponent(GlFormInput);
  const findAllFormsGroups = () => wrapper.findAllComponents(GlFormGroup);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findAllFormRadio = () => wrapper.findAllComponents(GlFormRadio);
  const findFormTextArea = () => wrapper.findComponent(GlFormTextarea);
  const findDeleteButton = () => wrapper.findComponentByTestId('delete-btn');
  const findSubmitButton = () => wrapper.findComponentByTestId('submit-btn');

  beforeEach(() => {
    createComponent();
  });

  it('renders the modal', () => {
    expect(findModal().exists()).toBe(true);
  });

  it('renders all necessary components', () => {
    expect(findVariableSelector().exists()).toBe(true);
    expect(findValueInput().exists()).toBe(false);
  });

  it('does not emit event when modal is submitted with invalid `variable` data', async () => {
    const preventDefault = jest.fn();
    await findModal().vm.$emit('primary', { preventDefault });
    expect(preventDefault).toHaveBeenCalled();
    expect(wrapper.emitted('add-variable')).toBeUndefined();
    expect(wrapper.emitted('update-variable')).toBeUndefined();
  });

  it('does not emit event when modal is submitted with invalid `value` data', async () => {
    const preventDefault = jest.fn();
    await findVariableSelector().vm.$emit('select', 'DAST_ACTIVE_SCAN_TIMEOUT');
    await findModal().vm.$emit('primary', { preventDefault });
    expect(preventDefault).toHaveBeenCalled();
    expect(wrapper.emitted('add-variable')).toBeUndefined();
    expect(wrapper.emitted('update-variable')).toBeUndefined();
  });

  it('emits resetModal event when modal is closed', async () => {
    await findModal().vm.$emit('hidden');
    await nextTick();
    expect(findModal().props('visible')).toBe(false);
  });

  it('displays DAST variable dropdown', () => {
    expect(findVariableSelector().exists()).toBe(true);
    const items = findVariableSelector().props('items');
    expect(items.length).toBeGreaterThan(0);
  });

  it('renders the description with a link', () => {
    createComponent({
      variable: { ...variableMock, description: descriptionLinkMock },
    });

    expect(findAllFormsGroups().at(1).attributes('label')).toBe('Value');
    expect(wrapper.html()).toContain('More details <a href="https://example.com">here</a>');
  });

  it('renders the description without a link', () => {
    createComponent({
      variable: variableMock,
    });

    expect(findAllFormsGroups().at(1).attributes('label')).toBe('Value');
    expect(wrapper.html()).not.toContain('<a href');
  });

  it('displays variable items with secondary text as description.message', () => {
    const preSelectedVariables = [
      {
        variable: 'DAST_ACTIVE_SCAN_TIMEOUT',
        value: 'Duration string',
        description: descriptionLinkMock,
      },
    ];
    createComponent({
      preSelectedVariables,
    });

    const items = findVariableSelector().props('items');
    expect(items[0].secondaryText).not.toBe('More details here');
  });

  describe('on create mode', () => {
    it('should display only one form-group when the modal is open', () => {
      expect(findAllFormsGroups()).toHaveLength(1);
    });

    it('displays radio buttons when a boolean variable is selected', async () => {
      await findVariableSelector().vm.$emit('select', 'DAST_AUTH_CLEAR_INPUT_FIELDS');
      expect(findRadioGroup().exists()).toBe(true);
    });

    it('displays form input when variable is not boolean or selector (for non-selector type)', async () => {
      await findVariableSelector().vm.$emit('select', 'DAST_ACTIVE_SCAN_TIMEOUT');
      expect(findValueInput().exists()).toBe(true);
    });

    it('displays textarea when variable type is selector', async () => {
      await findVariableSelector().vm.$emit('select', 'DAST_AUTH_BEFORE_LOGIN_ACTIONS');
      expect(findFormTextArea().exists()).toBe(true);
    });

    it('does not display any form input when type is null', async () => {
      await findVariableSelector().vm.$emit('select', null);
      expect(findAllFormsGroups().exists()).toBe(true);
      expect(findAllFormsGroups()).toHaveLength(1);
    });

    it('emits add-variable event when modal is submitted with valid data', async () => {
      createComponent(
        {},
        {
          GlModal: {
            template:
              '<div><slot name="modal-title"></slot><slot></slot><slot name="modal-footer"></slot></div>',
            methods: {
              hide: jest.fn(),
            },
          },
        },
      );
      await findVariableSelector().vm.$emit('select', 'DAST_ACTIVE_SCAN_TIMEOUT');
      await findValueInput().vm.$emit('input', '120');
      findSubmitButton().vm.$emit('click');
      expect(wrapper.emitted('update-variable')).toBeUndefined();
      expect(wrapper.emitted('add-variable')).toHaveLength(1);
      expect(wrapper.emitted('add-variable')).toEqual([
        [
          {
            variable: 'DAST_ACTIVE_SCAN_TIMEOUT',
            value: '120',
          },
        ],
      ]);
    });
  });

  describe('on edit mode', () => {
    it('displays the Delete button', async () => {
      createComponent(
        {
          variable: variableMock,
        },
        {
          GlModal: {
            template: '<div><slot name="modal-footer"></slot></div>',
            methods: {
              hide: jest.fn(),
              show: jest.fn(),
            },
          },
        },
      );
      wrapper.vm.editVariable();
      await findSubmitButton().vm.$emit('click');
      expect(findDeleteButton().exists()).toBe(true);
    });

    it('displays radio buttons when a boolean variable is selected', async () => {
      createComponent({
        variable: {
          id: 'DAST_AUTH_CLEAR_INPUT_FIELDS',
          value: 'true',
          type: 'boolean',
          description: descriptionMock,
        },
      });
      await nextTick();
      expect(findRadioGroup().exists()).toBe(true);
      expect(findAllFormRadio()).toHaveLength(2);
    });

    it('displays form input when variable is not boolean or selector (for non-selector type)', async () => {
      createComponent({
        variable: {
          id: 'DAST_ACTIVE_SCAN_TIMEOUT',
          value: '3h',
          type: 'Duration string',
          description: descriptionMock,
        },
      });
      await nextTick();
      expect(findValueInput().exists()).toBe(true);
    });

    it('displays textarea when variable type is selector', async () => {
      createComponent({
        variable: {
          id: 'DAST_AUTH_BEFORE_LOGIN_ACTIONS',
          value: 'css:.user',
          type: 'selector',
          description: descriptionMock,
        },
      });
      await nextTick();
      expect(findFormTextArea().exists()).toBe(true);
    });

    it('does not display any form input when type is null', () => {
      createComponent({ variable: { type: null } });
      expect(findAllFormsGroups().exists()).toBe(true);
      expect(findAllFormsGroups()).toHaveLength(1);
    });

    it('emits update-variable event when modal is submitted with valid data', () => {
      createComponent(
        {
          variable: variableMock,
        },
        {
          GlModal: {
            template: '<div><slot name="modal-footer"></slot></div>',
            methods: {
              hide: jest.fn(),
              show: jest.fn(),
            },
          },
        },
      );
      wrapper.vm.editVariable();
      findSubmitButton().vm.$emit('click');
      expect(wrapper.emitted('update-variable')).toHaveLength(1);
      expect(wrapper.emitted('add-variable')).toBeUndefined();
    });

    it('emits delete-variable event when the delete button is clicked', async () => {
      createComponent(
        {
          variable: variableMock,
        },
        {
          GlModal: {
            template: '<div><slot name="modal-footer"></slot></div>',
            methods: {
              hide: jest.fn(),
              show: jest.fn(),
            },
          },
        },
      );
      wrapper.vm.editVariable();
      await nextTick();
      findDeleteButton().vm.$emit('click');
      expect(wrapper.emitted('delete-variable')).toEqual([
        [{ variable: variableMock.id, value: variableMock.value }],
      ]);
    });

    it('while `preSelectedVariables`, the items array should exclude those values', () => {
      const preSelectedVariables = [
        { variable: 'DAST_ACTIVE_SCAN_TIMEOUT', value: 'Duration string' },
      ];
      createComponent({
        preSelectedVariables,
      });
      expect(findVariableSelector().props('items')).not.toContain(preSelectedVariables);
    });
  });
});
