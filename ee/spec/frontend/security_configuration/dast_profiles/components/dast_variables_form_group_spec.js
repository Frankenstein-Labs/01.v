import { nextTick } from 'vue';
import {
  GlFormGroup,
  GlButton,
  GlSprintf,
  GlLink,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlTableLite,
  GlFriendlyWrap,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DastVariablesFormGroup from 'ee/security_configuration/dast_profiles/components/dast_variables_form_group.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import DastVariablesModal from 'ee/security_configuration/dast_profiles/components/dast_variables_modal.vue';
import { getEmptyVariable } from 'ee/security_configuration/dast_profiles/constants';
import { stubComponent } from 'helpers/stub_component';
import { mockVariables } from '../mocks/mock_data';

describe('DastVariablesFormGroup', () => {
  let wrapper;

  const modalStub = { createVariable: jest.fn(), editVariable: jest.fn() };
  const DastVariablesModalStub = stubComponent(DastVariablesModal, { methods: modalStub });

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DastVariablesFormGroup, {
      propsData: {
        value: mockVariables,
        ...props,
      },
      stubs: {
        GlFormGroup,
        GlSprintf,
        GlLink,
        GlTableLite,
        DastVariablesModal: DastVariablesModalStub,
        GlDisclosureDropdownItem,
        GlFriendlyWrap,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findAddVariableButton = () => wrapper.findComponent(GlButton);
  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findHelpText = () => wrapper.findComponent(GlSprintf);
  const findModal = () => wrapper.findComponent(DastVariablesModal);
  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findTableLite = () => wrapper.findByTestId('variables-table');

  beforeEach(() => {
    createComponent();
  });

  it('mounts correctly', () => {
    expect(wrapper.exists()).toBe(true);
    expect(findFormGroup().exists()).toBe(true);
    expect(findTableLite().exists()).toBe(true);
  });

  it('renders the add variable button correctly', () => {
    expect(findAddVariableButton().exists()).toBe(true);
    expect(findAddVariableButton().text()).toBe('Add variable');
  });

  it('renders the help text and link correctly', () => {
    expect(findHelpText().exists()).toBe(true);
    expect(findHelpLink().exists()).toBe(true);
    expect(findHelpLink().attributes('href')).toBe(
      helpPagePath('user/application_security/dast/browser/configuration/variables'),
    );
  });

  it('renders the action buttons', () => {
    createComponent({
      value: [
        {
          id: 'DAST_CRAWL_GRAPH',
          value: 'true',
        },
      ],
    });
    expect(findDropdown().exists()).toBe(true);

    const dropdownItems = findDropdown().findAllComponents(GlDisclosureDropdownItem);
    expect(dropdownItems).toHaveLength(2);
    expect(dropdownItems.at(0).text()).toBe('Edit');
    expect(dropdownItems.at(1).text()).toBe('Delete');
  });

  it('show variable table only if variableList not empty', () => {
    createComponent({
      value: [
        {
          id: 'DAST_CRAWL_GRAPH',
          value: 'true',
        },
      ],
    });
    expect(findTableLite().exists()).toBe(true);
  });

  it('hide variable table while variableList is empty', () => {
    createComponent({
      value: [],
    });
    expect(findTableLite().exists()).toBe(false);
  });

  describe('add variable modal', () => {
    it('renders the component', () => {
      expect(findModal().exists()).toBe(true);
    });

    it('shows modal when add variable button is clicked', () => {
      findAddVariableButton().vm.$emit('click');
      expect(modalStub.createVariable).toHaveBeenCalled();
    });

    it('passes the correct pre-selected variables and edited variable to the modal', () => {
      createComponent({ value: [] });
      const emptyVariable = getEmptyVariable();
      expect(findModal().props('preSelectedVariables')).toEqual([]);
      expect(findModal().props('variable')).toEqual(emptyVariable);
    });
  });

  describe('events emitted by the modal', () => {
    const emitFromModal = async (event, payload) => {
      findModal().vm.$emit(event, payload);
      await nextTick();
    };

    it('adds the variable on `add-variable`', async () => {
      const newVariable = { variable: 'DAST_CRAWL_GRAPH', value: 'true' };
      await emitFromModal('add-variable', newVariable);

      expect(findModal().props('preSelectedVariables')).toEqual([...mockVariables, newVariable]);
    });

    it('replaces the matching variable on `update-variable`', async () => {
      const updatedVariable = { variable: 'DAST_ACTIVE_SCAN_TIMEOUT', value: '5h' };
      await emitFromModal('update-variable', updatedVariable);

      expect(findModal().props('preSelectedVariables')).toEqual([
        mockVariables[1],
        updatedVariable,
      ]);
    });

    it('removes the matching variable on `delete-variable`', async () => {
      await emitFromModal('delete-variable', mockVariables[0]);

      expect(findModal().props('preSelectedVariables')).toEqual([mockVariables[1]]);
    });
  });

  describe('while `variableList` is not empty', () => {
    it('needs to set `preSelectedVariables` input', () => {
      const preSelectedVariable = [
        { variable: 'DAST_ACTIVE_SCAN_TIMEOUT', value: 'Duration string' },
      ];
      createComponent({
        value: preSelectedVariable,
      });
      expect(findModal().props('preSelectedVariables')).toEqual(preSelectedVariable);
    });
  });
});
