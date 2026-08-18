import { GlFormGroup } from '@gitlab/ui';
import { nextTick } from 'vue';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FormGroup from 'ee/ai/catalog/components/form_group.vue';

describe('FormGroup', () => {
  let wrapper;

  const defaultField = {
    id: 'test-field',
    label: 'Test Field',
    groupAttrs: {
      labelDescription: 'Test description',
    },
    validations: {},
  };

  const GlFormGroupStub = stubComponent(GlFormGroup, {
    props: ['state', 'invalidFeedback'],
  });

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(FormGroup, {
      propsData: {
        field: {
          id: 'test-field',
          label: 'Test Field',
          groupAttrs: {
            labelDescription: 'Test description',
          },
          validations: {},
        },
        fieldValue: null,
        ...props,
      },
      slots: {
        default: '<input data-testid="test-input" />',
      },
      stubs: {
        GlFormGroup: GlFormGroupStub,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findSlotContent = () => wrapper.findByTestId('test-input');

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a GlFormGroup with correct props', () => {
      const formGroup = findFormGroup();

      expect(formGroup.exists()).toBe(true);
      expect(formGroup.attributes()).toMatchObject(
        expect.anything(),
        expect.objectContaining({
          label: 'Test Field',
          labelDescription: 'Test description',
          labelFor: 'test-field',
          invalidFeedback: null,
          state: '',
        }),
      );
    });

    it('renders slot content', () => {
      expect(findSlotContent().exists()).toBe(true);
    });
  });

  describe('validations', () => {
    describe('required field validations', () => {
      const fieldWithRequired = {
        ...defaultField,
        validations: {
          requiredLabel: 'This field is required',
        },
      };

      it('validates as invalid when field is empty and required', async () => {
        createComponent({
          field: fieldWithRequired,
          fieldValue: '',
        });

        wrapper.vm.validate();
        await nextTick();

        expect(findFormGroup().props('state')).toBe(false);
        expect(findFormGroup().props('invalidFeedback')).toBe('This field is required');
      });

      it('validates as invalid when field is null and required', async () => {
        createComponent({
          field: fieldWithRequired,
          fieldValue: null,
        });

        wrapper.vm.validate();
        await nextTick();

        expect(findFormGroup().props('state')).toBe(false);
        expect(findFormGroup().props('invalidFeedback')).toBe('This field is required');
      });

      it('validates as valid when field has value and is required', async () => {
        createComponent({
          field: fieldWithRequired,
          fieldValue: 'some value',
        });

        wrapper.vm.validate();
        await nextTick();

        expect(findFormGroup().props('state')).toBe(true);
        expect(findFormGroup().props('invalidFeedback')).toBe('This field is required');
      });
    });

    describe('max length validations', () => {
      const fieldWithMaxLength = {
        ...defaultField,
        validations: {
          maxLength: 10,
        },
      };

      it('validates as valid when field value is within max length', async () => {
        createComponent({
          field: fieldWithMaxLength,
          fieldValue: 'short',
        });

        wrapper.vm.validate();
        await nextTick();

        expect(findFormGroup().props('state')).toBe(true);
      });

      it('validates as valid when field value equals max length', async () => {
        createComponent({
          field: fieldWithMaxLength,
          fieldValue: '1234567890', // exactly 10 characters
        });

        wrapper.vm.validate();
        await nextTick();

        expect(findFormGroup().props('state')).toBe(true);
      });

      it('validates as invalid when field value exceeds max length', async () => {
        createComponent({
          field: fieldWithMaxLength,
          fieldValue: 'this is too long', // more than 10 characters
        });

        wrapper.vm.validate();
        await nextTick();

        expect(findFormGroup().props('state')).toBe(false);
      });
    });

    describe('onBlur method', () => {
      it('calls validate when onBlur is triggered', () => {
        const validateSpy = jest.spyOn(wrapper.vm, 'validate');

        wrapper.vm.onBlur();

        expect(validateSpy).toHaveBeenCalled();
      });

      it('updates state and feedback when onBlur is called with invalid data', async () => {
        createComponent({
          field: {
            ...defaultField,
            validations: {
              requiredLabel: 'Required field',
            },
          },
          fieldValue: '',
        });

        wrapper.vm.onBlur();
        await nextTick();

        expect(findFormGroup().props('state')).toBe(false);
        expect(findFormGroup().props('invalidFeedback')).toBe('Required field');
      });
    });

    describe('prop changes', () => {
      it('updates required validations when fieldValue prop changes', async () => {
        const fieldWithRequired = {
          ...defaultField,
          validations: {
            requiredLabel: 'This field is required',
          },
        };

        createComponent({
          field: fieldWithRequired,
          fieldValue: '',
        });

        // Initially invalid
        wrapper.vm.validate();
        await nextTick();
        expect(findFormGroup().props('state')).toBe(false);

        // Update to valid value
        await wrapper.setProps({ fieldValue: 'valid value' });
        wrapper.vm.validate();
        await nextTick();
        expect(findFormGroup().props('state')).toBe(true);
      });

      it('updates maxLength validations when fieldValue prop changes', async () => {
        createComponent({
          field: {
            ...defaultField,
            validations: {
              maxLength: 6,
            },
          },
          fieldValue: 'test',
        });

        // Initially no validations error
        wrapper.vm.validate();
        await nextTick();
        expect(findFormGroup().props('state')).toBe(true);

        // Update field to have validations error
        await wrapper.setProps({
          fieldValue: 'test is too long',
        });

        wrapper.vm.validate();
        await nextTick();
        expect(findFormGroup().props('state')).toBe(false);
      });
    });

    describe('data types', () => {
      it('handles string fieldValue', async () => {
        createComponent({
          field: {
            ...defaultField,
            validations: { requiredLabel: 'Required' },
          },
          fieldValue: 'string value',
        });

        wrapper.vm.validate();
        await nextTick();

        expect(findFormGroup().props('state')).toBe(true);
      });

      it('handles number fieldValue', async () => {
        createComponent({
          field: {
            ...defaultField,
            validations: { requiredLabel: 'Required' },
          },
          fieldValue: 42,
        });

        wrapper.vm.validate();
        await nextTick();

        expect(findFormGroup().props('state')).toBe(true);
      });

      it('handles array fieldValue', async () => {
        createComponent({
          field: {
            ...defaultField,
            validations: { requiredLabel: 'Required' },
          },
          fieldValue: ['item1', 'item2'],
        });

        wrapper.vm.validate();
        await nextTick();

        expect(findFormGroup().props('state')).toBe(true);
      });
    });
  });
});
