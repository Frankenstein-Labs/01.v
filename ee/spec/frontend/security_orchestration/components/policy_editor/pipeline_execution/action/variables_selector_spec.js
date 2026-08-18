import { GlCollapsibleListbox, GlDropdownItem, GlFormInput } from '@gitlab/ui';
import VariablesSelector from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/variables_selector.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { FLAT_LIST_OPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/ci_variable_constants';

describe('VariablesSelector', () => {
  let wrapper;

  const createComponent = ({ propsData, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(VariablesSelector, {
      propsData: {
        items: FLAT_LIST_OPTIONS,
        ...propsData,
      },
      stubs,
    });
  };

  const listBoxItems = FLAT_LIST_OPTIONS.map((item) => ({ value: item, text: item }));
  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSectionLayout = () => wrapper.findComponent(SectionLayout);
  const findAddCustomVariableButton = () => wrapper.findComponent(GlDropdownItem);
  const findCustomVariableInput = () => wrapper.findComponent(GlFormInput);
  const findErrorMessage = () => wrapper.findByTestId('error-message');

  describe('default rendering', () => {
    it('renders variable selector', () => {
      createComponent();

      expect(findListBox().props('items')).toEqual(listBoxItems);
      expect(findListBox().props('toggleText')).toBe('Select a variable');
      expect(findListBox().props('selected')).toBe('');
    });
  });

  describe('selected variables', () => {
    it('renders selected variables', () => {
      createComponent({ propsData: { selected: FLAT_LIST_OPTIONS[0] } });

      expect(findListBox().props('selected')).toBe(FLAT_LIST_OPTIONS[0]);
    });
  });

  describe('searching', () => {
    it('searches through variables list', async () => {
      createComponent();

      await findListBox().vm.$emit('search', FLAT_LIST_OPTIONS[0]);

      expect(findListBox().props('items')).toEqual([listBoxItems[0]]);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('selects a variable', () => {
      findListBox().vm.$emit('select', FLAT_LIST_OPTIONS[0]);

      expect(wrapper.emitted('select')).toEqual([[FLAT_LIST_OPTIONS[0]]]);
    });

    it('removes selector', () => {
      findSectionLayout().vm.$emit('remove');

      expect(wrapper.emitted('remove')).toHaveLength(1);
    });
  });

  describe('custom variables', () => {
    const CUSTOM_VARIABLE = 'CUSTOM_VARIABLE';

    it('creates custom variables', async () => {
      createComponent();

      expect(findCustomVariableInput().exists()).toBe(false);

      await findAddCustomVariableButton().vm.$emit('click');

      expect(findCustomVariableInput().exists()).toBe(true);

      await findCustomVariableInput().vm.$emit('input', CUSTOM_VARIABLE);

      expect(wrapper.emitted('select')).toEqual([[CUSTOM_VARIABLE]]);
    });

    it('renders existing custom variables', () => {
      createComponent({
        propsData: {
          selected: CUSTOM_VARIABLE,
          isCustom: true,
        },
      });

      expect(findCustomVariableInput().exists()).toBe(true);
      expect(findCustomVariableInput().props('value')).toBe(CUSTOM_VARIABLE);
    });

    it('renders error message for custom variable duplicates', () => {
      createComponent({
        propsData: {
          hasValidationError: true,
          selected: CUSTOM_VARIABLE,
          isCustom: true,
        },
      });

      expect(findErrorMessage().text()).toBe('Please remove duplicates.');
    });

    it('renders custom error message for custom variable duplicates', () => {
      createComponent({
        propsData: {
          hasValidationError: true,
          errorMessage: 'custom message',
          selected: CUSTOM_VARIABLE,
          isCustom: true,
        },
      });

      expect(findErrorMessage().text()).toBe('custom message');
    });
  });
});
