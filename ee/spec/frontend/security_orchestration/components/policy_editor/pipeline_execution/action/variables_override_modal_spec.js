import { GlModal } from '@gitlab/ui';
import VariablesOverrideModal from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/variables_override_modal.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VariablesSelector from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/variables_selector.vue';
import { FLAT_LIST_OPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/ci_variable_constants';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';

describe('VariablesOverrideModal', () => {
  let wrapper;

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(VariablesOverrideModal, {
      propsData,
      stubs: {
        GlModal: stubComponent(GlModal, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
    });
  };

  const findAddButton = () => wrapper.findComponentByTestId('add-button');
  const findTableHeader = () => wrapper.findByTestId('table-header');
  const findModal = () => wrapper.findComponent(GlModal);
  const findVariablesSelectors = () => wrapper.findAllComponents(VariablesSelector);

  describe('default rendering', () => {
    it('renders modal with default variable selector', () => {
      createComponent();

      expect(findModal().props('title')).toBe('Edit allowlist');
      expect(findVariablesSelectors()).toHaveLength(1);
      expect(findVariablesSelectors().at(0).props('selected')).toBe('');
      expect(findModal().props('actionPrimary').text).toEqual('Save allowlist');
      expect(findTableHeader().text()).toBe('Variables that can be overridden:');
    });

    it('renders denylist', () => {
      createComponent({ propsData: { isVariablesOverrideAllowed: true } });

      expect(findModal().props('title')).toBe('Edit denylist');
      expect(findModal().props('actionPrimary').text).toEqual('Save denylist');
      expect(findTableHeader().text()).toBe('Variables that cannot be overridden:');
    });
  });

  describe('selection', () => {
    it('selects variables', async () => {
      createComponent();

      expect(findAddButton().props('disabled')).toBe(true);

      await findVariablesSelectors().at(0).vm.$emit('select', FLAT_LIST_OPTIONS[0]);

      expect(findAddButton().props('disabled')).toBe(false);

      await findAddButton().vm.$emit('click');

      await findVariablesSelectors().at(1).vm.$emit('select', FLAT_LIST_OPTIONS[1]);

      await findModal().vm.$emit('primary');

      expect(wrapper.emitted('select-exceptions')).toEqual([
        [[FLAT_LIST_OPTIONS[0], FLAT_LIST_OPTIONS[1]]],
      ]);
    });

    it('reselects variables when modal is reopened', async () => {
      createComponent();

      expect(findVariablesSelectors()).toHaveLength(1);
      expect(findVariablesSelectors().at(0).props('selected')).toBe('');

      await wrapper.setProps({ exceptions: [FLAT_LIST_OPTIONS[0], FLAT_LIST_OPTIONS[1]] });

      expect(findVariablesSelectors()).toHaveLength(2);
      expect(findVariablesSelectors().at(0).props('selected')).toBe(FLAT_LIST_OPTIONS[0]);
      expect(findVariablesSelectors().at(1).props('selected')).toBe(FLAT_LIST_OPTIONS[1]);
    });
  });

  describe('selected variables', () => {
    it('renders selected exceptions', () => {
      createComponent({
        propsData: { exceptions: FLAT_LIST_OPTIONS.slice(0, 2) },
      });

      expect(findVariablesSelectors()).toHaveLength(2);
      expect(findVariablesSelectors().at(0).props('selected')).toBe(FLAT_LIST_OPTIONS[0]);
      expect(findVariablesSelectors().at(0).props('items')).toEqual([
        FLAT_LIST_OPTIONS[0],
        ...FLAT_LIST_OPTIONS.slice(2),
      ]);
      expect(findVariablesSelectors().at(1).props('selected')).toBe(FLAT_LIST_OPTIONS[1]);
      expect(findVariablesSelectors().at(1).props('items')).toEqual([
        ...FLAT_LIST_OPTIONS.slice(1),
      ]);
    });

    it('removes selected variables from the selected list', async () => {
      createComponent({
        propsData: { exceptions: FLAT_LIST_OPTIONS.slice(0, 2) },
      });

      expect(findVariablesSelectors()).toHaveLength(2);

      await findVariablesSelectors().at(0).vm.$emit('remove');

      expect(findVariablesSelectors()).toHaveLength(1);

      await findModal().vm.$emit('primary');

      expect(wrapper.emitted('select-exceptions')).toEqual([[[FLAT_LIST_OPTIONS[1]]]]);
    });

    it('removes empty string from selection', async () => {
      createComponent();

      expect(findAddButton().props('disabled')).toBe(true);

      await findVariablesSelectors().at(0).vm.$emit('select', FLAT_LIST_OPTIONS[0]);

      await findAddButton().vm.$emit('click');

      expect(findVariablesSelectors().at(1).props('selected')).toBe('');

      await findModal().vm.$emit('primary');

      expect(wrapper.emitted('select-exceptions')).toEqual([[[FLAT_LIST_OPTIONS[0]]]]);
    });
  });

  describe('validation', () => {
    it('identifies duplicate validation error', async () => {
      createComponent({
        propsData: { exceptions: FLAT_LIST_OPTIONS.slice(0, 3) },
      });

      await findVariablesSelectors().at(1).vm.$emit('select', FLAT_LIST_OPTIONS[0]);

      expect(findVariablesSelectors().at(0).props('hasValidationError')).toBe(true);
      expect(findVariablesSelectors().at(1).props('hasValidationError')).toBe(true);
      expect(findVariablesSelectors().at(2).props('hasValidationError')).toBe(false);
    });
  });

  describe('canceling', () => {
    it('resets items to initial state if editing is cancelled', async () => {
      const exceptions = FLAT_LIST_OPTIONS.slice(0, 2);

      createComponent({
        propsData: { exceptions },
      });

      await findAddButton().vm.$emit('click');
      await findVariablesSelectors().at(2).vm.$emit('select', FLAT_LIST_OPTIONS[2]);

      expect(findVariablesSelectors()).toHaveLength(3);

      await findAddButton().vm.$emit('click');
      expect(findVariablesSelectors()).toHaveLength(4);

      await findModal().vm.$emit('canceled');

      expect(findVariablesSelectors()).toHaveLength(exceptions.length);

      expect(wrapper.emitted('select-exceptions')).toBeUndefined();
    });
  });
});
