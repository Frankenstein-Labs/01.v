import { nextTick } from 'vue';
import { noop } from 'lodash-es';
import { GlForm, GlFormGroup, GlFormRadioGroup, GlFormTextarea, GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';

import AiCatalogItemReportModal from 'ee/ai/catalog/components/ai_catalog_item_report_modal.vue';
import { mockFlow } from '../mock_data';

describe('AiCatalogItemReportModal', () => {
  let wrapper;

  const modalStub = { hide: jest.fn() };
  const GlModalStub = stubComponent(GlModal, { methods: modalStub });

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemReportModal, {
      propsData: {
        item: mockFlow,
        ...props,
      },
      stubs: {
        GlFormGroup,
        GlModal: GlModalStub,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findForm = () => wrapper.findComponent(GlForm);
  const findFormGroup = () => wrapper.findComponentByTestId('report-body');
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findTextarea = () => wrapper.findComponent(GlFormTextarea);
  const submitForm = () => findForm().vm.$emit('submit', { preventDefault: noop });

  describe('when rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('has default reason selected', () => {
      expect(findRadioGroup().attributes('checked')).toBe('IMMEDIATE_SECURITY_THREAT');
    });

    it('renders textarea as optional', () => {
      expect(findFormGroup().props('optional')).toBe(true);
    });
  });

  describe('when "OTHER" reason is selected', () => {
    beforeEach(() => {
      createComponent();
      findRadioGroup().vm.$emit('input', 'OTHER');
    });

    it('renders textarea as non-optional', () => {
      expect(findFormGroup().props('optional')).toBe(false);
    });

    it('does not allow submission when textarea contains only whitespace', () => {
      findTextarea().vm.$emit('input', '   ');
      submitForm();

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('allows submission when textarea has content', () => {
      findTextarea().vm.$emit('input', 'Additional details');
      submitForm();

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toEqual({
        reason: 'OTHER',
        body: 'Additional details',
      });
    });
  });

  describe('when "OTHER" reason is not selected', () => {
    beforeEach(() => {
      createComponent();
      findRadioGroup().vm.$emit('input', 'SPAM_OR_LOW_QUALITY');
    });

    it('renders textarea as optional', () => {
      expect(findFormGroup().props('optional')).toBe(true);
    });

    it('allows submission with empty textarea', () => {
      findTextarea().vm.$emit('input', '');
      submitForm();

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toEqual({
        reason: 'SPAM_OR_LOW_QUALITY',
        body: '',
      });
    });
  });

  describe('form submission', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits submit event with correct data when form is valid', () => {
      findRadioGroup().vm.$emit('input', 'SPAM_OR_LOW_QUALITY');
      findTextarea().vm.$emit('input', 'This is spam content');

      submitForm();

      expect(wrapper.emitted('submit')).toHaveLength(1);
      expect(wrapper.emitted('submit')[0][0]).toEqual({
        reason: 'SPAM_OR_LOW_QUALITY',
        body: 'This is spam content',
      });
    });

    it('trims whitespace from body before submission', () => {
      findRadioGroup().vm.$emit('input', 'OTHER');
      findTextarea().vm.$emit('input', '  text with spaces  ');

      submitForm();

      expect(wrapper.emitted('submit')[0][0].body).toBe('text with spaces');
    });

    it('hides the modal', () => {
      submitForm();

      expect(modalStub.hide).toHaveBeenCalled();
    });

    it('does not emit submit when form is invalid', () => {
      const longText = 'a'.repeat(1001);
      findTextarea().vm.$emit('input', longText);

      submitForm();

      expect(wrapper.emitted('submit')).toBeUndefined();
    });
  });

  describe('form reset', () => {
    beforeEach(() => {
      createComponent();
    });

    it('resets form data when modal is hidden', async () => {
      findRadioGroup().vm.$emit('input', 'EXCESSIVE_RESOURCE_USAGE');
      findTextarea().vm.$emit('input', 'Some report text');

      findModal().vm.$emit('hidden');
      await nextTick();

      expect(findRadioGroup().attributes('checked')).toBe('IMMEDIATE_SECURITY_THREAT');
      expect(findTextarea().props('value')).toBe('');
    });
  });
});
