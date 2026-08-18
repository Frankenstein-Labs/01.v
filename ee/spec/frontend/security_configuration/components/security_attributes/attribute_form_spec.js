import { GlFormInput, GlFormTextarea, GlFormGroup, GlForm } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AttributeForm from 'ee/security_configuration/components/security_attributes/attribute_form.vue';
import ColorPicker from '~/vue_shared/components/color_picker/color_picker.vue';

describe('AttributeForm', () => {
  let wrapper;

  const attribute = {
    id: 101,
    name: 'Internal::Finance',
    description: 'Sensitive Finance Data',
    color: '#000000',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AttributeForm, {
      propsData: {
        attribute,
        mode: 'edit',
        ...props,
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findNameInput = () => wrapper.findComponent(GlFormInput);
  const findDescriptionTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findColorPicker = () => wrapper.findComponent(ColorPicker);
  const findFormGroups = () => wrapper.findAllComponents(GlFormGroup);
  const findNameFormGroup = () => findFormGroups().at(0);
  const findDescriptionFormGroup = () => findFormGroups().at(1);

  beforeEach(() => {
    createComponent();
  });

  describe('initial render', () => {
    it('sets initial form values from props', () => {
      expect(findNameInput().attributes('value')).toBe(attribute.name);
      expect(findDescriptionTextarea().attributes('value')).toBe(attribute.description);
      expect(findColorPicker().props('value')).toBe(attribute.color);
    });
  });

  describe('validation', () => {
    it('marks name as invalid when empty', async () => {
      findNameInput().vm.$emit('input', '');
      findForm().vm.$emit('submit', { preventDefault: jest.fn() });
      await nextTick();

      expect(findNameFormGroup().attributes('invalid-feedback')).toBe('Name is required');
      expect(findNameFormGroup().attributes('state')).toBeUndefined();
    });

    it('marks description as invalid when empty', async () => {
      findDescriptionTextarea().vm.$emit('input', '');
      findForm().vm.$emit('submit', { preventDefault: jest.fn() });
      await nextTick();

      expect(findDescriptionFormGroup().attributes('invalid-feedback')).toBe(
        'Description is required',
      );
      expect(findDescriptionFormGroup().attributes('state')).toBeUndefined();
    });

    it('sets both fields valid when non-empty input is emitted', async () => {
      findNameInput().vm.$emit('input', 'Some name');
      findDescriptionTextarea().vm.$emit('input', 'Some desc');
      await nextTick();

      expect(findNameFormGroup().attributes('state')).toBe('true');
      expect(findDescriptionFormGroup().attributes('state')).toBe('true');
    });
  });

  describe('submit behavior', () => {
    describe('invalid field blocking submit', () => {
      it.each([
        ['name', '', findNameInput],
        ['description', '', findDescriptionTextarea],
        ['color', 'not-a-color', findColorPicker],
      ])('does not emit saved if %s is invalid', async (_fieldName, value, findField) => {
        findField().vm.$emit('input', value);
        await nextTick();

        findForm().vm.$emit('submit', { preventDefault: jest.fn() });

        expect(wrapper.emitted('saved')).toBeUndefined();
      });
    });

    it('emits saved with correct payload when valid', async () => {
      findNameInput().vm.$emit('input', 'NewAttribute');
      findDescriptionTextarea().vm.$emit('input', 'New description');
      findColorPicker().vm.$emit('input', '#ff0000');
      await nextTick();

      findForm().vm.$emit('submit', { preventDefault: jest.fn() });

      const emittedData = wrapper.emitted('saved')[0][0];
      expect(emittedData).toEqual({
        id: attribute.id,
        name: 'NewAttribute',
        description: 'New description',
        color: '#ff0000',
      });
    });
  });
});
