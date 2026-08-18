import { nextTick } from 'vue';
import { GlDisclosureDropdown, GlIcon, GlFormCombobox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import InlineStatusForm from 'ee/groups/settings/work_items/custom_status/status_form.vue';

describe('StatusForm', () => {
  let wrapper;

  const defaultProps = {
    categoryIcon: 'status-neutral',
    categoryName: 'TRIAGE',
    formData: {
      name: 'Test Status',
      color: '#ff0000',
      description: 'Test description',
    },
    formErrors: {
      name: '',
      color: '',
    },
  };

  const findColorDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDescriptionInput = () => wrapper.findComponentByTestId('status-description-input');
  const findAddDescriptionButton = () => wrapper.findComponentByTestId('add-description-button');
  const findSaveButton = () => wrapper.findComponentByTestId('save-status');
  const findUpdateButton = () => wrapper.findComponentByTestId('update-status');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-status');
  const findCategoryIcon = () => wrapper.findComponent(GlIcon);
  const findAutoSuggestionsBox = () => wrapper.findComponent(GlFormCombobox);

  const createComponent = (props = {}) => {
    // Mock gon for suggested colors
    global.gon = {
      suggested_label_colors: {
        '#FF0000': 'Red',
        '#00FF00': 'Green',
        '#0000FF': 'Blue',
      },
    };

    wrapper = shallowMountExtended(InlineStatusForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('initial rendering', () => {
    beforeEach(async () => {
      createComponent({ isEditing: true });
      await nextTick();
    });

    it('displays category icon with correct color', () => {
      const icon = findCategoryIcon();
      expect(icon.props('name')).toBe('status-neutral');
      expect(icon.attributes('style')).toContain('color: rgb(255, 0, 0)');
    });

    it('shows status name in auto-suggestions value', () => {
      expect(findAutoSuggestionsBox().props('value')).toBe('Test Status');
    });

    it('displays color input with correct values', () => {
      const colorInput = wrapper.findByTestId('status-color-input');
      expect(colorInput.attributes('value')).toBe('#ff0000');
    });

    it('shows description field when description exists', () => {
      expect(findDescriptionInput().exists()).toBe(true);
      expect(findDescriptionInput().attributes('value')).toBe('Test description');
    });

    it('hides description field when no description', () => {
      createComponent({
        formData: {
          name: 'Test Status',
          color: '#ff0000',
          description: '',
        },
      });

      expect(findDescriptionInput().exists()).toBe(false);
      expect(findAddDescriptionButton().exists()).toBe(true);
    });
  });

  describe('form interactions', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('status name interactions', () => {
      beforeEach(() => {
        createComponent(defaultProps);
      });

      it('shows the combobox instead of form input', () => {
        expect(findAutoSuggestionsBox().exists()).toBe(true);
      });

      it('passes `name` as the matching value attribute in the token list', () => {
        expect(findAutoSuggestionsBox().props('matchValueToAttr')).toBe('name');
      });
    });

    it('emits update when color input changes', () => {
      const colorInputs = wrapper.findAllComponentsByTestId('status-color-input');
      colorInputs.at(0).vm.$emit('input', '#00ff00');

      expect(wrapper.emitted('update')).toHaveLength(1);
      expect(wrapper.emitted('update')[0][0]).toEqual({
        ...defaultProps.formData,
        color: '#00ff00',
      });
    });

    it('emits update when description input changes', () => {
      findDescriptionInput().vm.$emit('input', 'New description');

      expect(wrapper.emitted('update')).toHaveLength(1);
      expect(wrapper.emitted('update')[0][0]).toEqual({
        ...defaultProps.formData,
        description: 'New description',
      });
    });

    it('trims whitespace from color input', () => {
      const colorInputs = wrapper.findAllComponentsByTestId('status-color-input');
      colorInputs.at(0).vm.$emit('input', '  #00ff00  ');

      expect(wrapper.emitted('update')[0][0].color).toBe('#00ff00');
    });
  });

  describe('description field toggle', () => {
    beforeEach(() => {
      createComponent({
        formData: {
          name: 'Test Status',
          color: '#ff0000',
          description: '',
        },
      });
    });

    it('shows description field when add description button is clicked', async () => {
      expect(findDescriptionInput().exists()).toBe(false);

      findAddDescriptionButton().vm.$emit('click');
      await nextTick();

      expect(findDescriptionInput().exists()).toBe(true);
      expect(findAddDescriptionButton().exists()).toBe(false);
    });
  });

  describe('color dropdown', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays suggested colors in dropdown', () => {
      const dropdown = findColorDropdown();
      expect(dropdown.exists()).toBe(true);
    });
  });

  describe('save and cancel actions', () => {
    describe('when not editing', () => {
      beforeEach(() => {
        createComponent({ isEditing: false });
      });

      it('shows save button with correct text', () => {
        expect(findSaveButton().exists()).toBe(true);
        expect(findSaveButton().text()).toBe('Save');
        expect(findUpdateButton().exists()).toBe(false);
      });

      it('emits save event when save button is clicked', () => {
        findSaveButton().vm.$emit('click');
        expect(wrapper.emitted('save')).toHaveLength(1);
      });
    });

    describe('when editing', () => {
      beforeEach(() => {
        createComponent({ isEditing: true });
      });

      it('shows update button with correct text', () => {
        expect(findUpdateButton().exists()).toBe(true);
        expect(findUpdateButton().text()).toBe('Update');
        expect(findSaveButton().exists()).toBe(false);
      });

      it('emits save event when update button is clicked', () => {
        findUpdateButton().vm.$emit('click');
        expect(wrapper.emitted('save')).toHaveLength(1);
      });
    });

    it('emits cancel event when cancel button is clicked', () => {
      createComponent();
      findCancelButton().vm.$emit('click');
      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });

  it('limits name input to 32 characters', () => {
    createComponent();

    const validName = 'a'.repeat(32);
    const invalidName = 'a'.repeat(33);

    findAutoSuggestionsBox().vm.$emit('input', validName);
    expect(wrapper.emitted('update')).toBeDefined();

    createComponent();

    findAutoSuggestionsBox().vm.$emit('input', invalidName);
    expect(wrapper.emitted('update')).toBeUndefined();
  });

  describe('color validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('triggers validate function on blur of color text input with invalid color', () => {
      const colorTextInput = wrapper.findComponentByTestId('status-color-input-text');

      colorTextInput.vm.$emit('input', 'invalid-color');

      colorTextInput.vm.$emit('blur');

      expect(wrapper.emitted('validate')).toHaveLength(1);
    });
  });
});
