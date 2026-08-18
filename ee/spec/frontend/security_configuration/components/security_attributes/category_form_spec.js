import {
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlFormRadio,
  GlBadge,
  GlLabel,
  GlButton,
  GlTable,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlPopover,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import {
  CATEGORY_EDITABLE,
  CATEGORY_PARTIALLY_EDITABLE,
  CATEGORY_LOCKED,
} from 'ee/security_configuration/components/security_attributes/constants';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import CategoryForm from 'ee/security_configuration/components/security_attributes/category_form.vue';
import { mockSecurityAttributeCategories } from './mock_data';

const category = mockSecurityAttributeCategories[0];
const expectedAttributes = category.securityAttributes;

describe('Category form', () => {
  let wrapper;

  const createComponent = (props, mountFn = shallowMountExtended) => {
    wrapper = mountFn(CategoryForm, {
      propsData: {
        ...props,
      },
      stubs: {
        GlFormGroup,
        GlTable,
        GlDisclosureDropdown,
        GlDisclosureDropdownItem,
      },
    });
  };

  const findPopover = () => wrapper.findComponent(GlPopover);

  const addAnAttribute = async () => {
    // uses setProps because attributes are handled by the parent component
    wrapper.setProps({
      selectedCategory: {
        ...category,
        id: undefined,
        securityAttributes: [{ name: 'purple attribute', description: 'purple', color: '#9400d3' }],
      },
    });
    await nextTick();
  };

  describe.each`
    description                  | id           | editableState                  | multipleSelection | expectedBadge
    ${'locked category'}         | ${1}         | ${CATEGORY_LOCKED}             | ${false}          | ${'Category locked'}
    ${'limited edits category'}  | ${2}         | ${CATEGORY_PARTIALLY_EDITABLE} | ${true}           | ${'Limited edits allowed'}
    ${'fully editable category'} | ${3}         | ${CATEGORY_EDITABLE}           | ${true}           | ${false}
    ${'new category'}            | ${undefined} | ${CATEGORY_EDITABLE}           | ${false}          | ${false}
  `('$description', ({ id, editableState, multipleSelection, expectedBadge }) => {
    describe('category metadata', () => {
      beforeEach(() => {
        createComponent({
          selectedCategory: {
            ...category,
            id,
            editableState,
            multipleSelection,
          },
        });
      });

      it('shows the category name if saved, "Category details" if new', () => {
        expect(wrapper.findByTestId('category-form-title').text()).toBe(
          id === undefined ? 'Category details' : category.name,
        );
      });

      it('shows the appropriate badge', () => {
        if (expectedBadge === false) expect(wrapper.findComponent(GlBadge).exists()).toBe(false);
        else expect(wrapper.findComponent(GlBadge).text()).toBe(expectedBadge);
      });

      if (editableState === CATEGORY_EDITABLE && id) {
        it('shows the category delete action', async () => {
          wrapper.findComponentByTestId('delete-category-item').vm.$emit('action');

          await nextTick();

          expect(wrapper.emitted()).toMatchObject({
            'delete-category': [[{ name: 'Business Impact' }]],
          });
        });
      }
      if (editableState === CATEGORY_EDITABLE) {
        it('renders the category name and description form fields', () => {
          expect(wrapper.findComponent(GlFormInput).props('value')).toBe(category.name);
          expect(wrapper.findComponent(GlFormTextarea).props('value')).toBe(category.description);
        });
      } else {
        it('renders the category name and description as text', () => {
          expect(wrapper.findAllComponents(GlFormGroup).at(0).text()).toContain(category.name);
          expect(wrapper.findAllComponents(GlFormGroup).at(1).text()).toContain(
            category.description,
          );
        });
      }

      it('renders the selection type', () => {
        // if category is new
        if (id === undefined) {
          expect(wrapper.findAllComponents(GlFormRadio).at(0).text()).toBe('Single selection');
          expect(wrapper.findAllComponents(GlFormRadio).at(1).text()).toBe('Multiple selection');
        } else if (multipleSelection) {
          expect(wrapper.findComponent(GlFormRadio).exists()).toBe(false);
          expect(wrapper.findAllComponents(GlFormGroup).at(2).text()).toContain(
            'Multiple selection',
          );
        } else {
          expect(wrapper.findComponent(GlFormRadio).exists()).toBe(false);
          expect(wrapper.findAllComponents(GlFormGroup).at(2).text()).toContain('Single selection');
        }
      });
    });

    describe('attributes', () => {
      beforeEach(() => {
        createComponent(
          {
            selectedCategory: {
              ...category,
              id,
              editableState,
              multipleSelection,
              securityAttributes: expectedAttributes,
            },
          },
          mountExtended,
        );
      });

      // if category is not new (empty)
      if (id !== undefined) {
        it('renders the attributes in the category', () => {
          expectedAttributes.forEach((attribute, index) => {
            expect(wrapper.findAllComponents(GlLabel).at(index).props('title')).toBe(
              attribute.name,
            );
            expect(
              wrapper.findComponent(GlTable).find('tbody').findAll('tr').at(index).text(),
            ).toContain(attribute.description);
          });
        });
      }

      if (editableState !== CATEGORY_LOCKED) {
        it('shows an attribute create button that emits add-attribute', async () => {
          wrapper.findComponentByTestId('add-attribute-button').vm.$emit('click');
          await nextTick();

          expect(wrapper.emitted('add-attribute')).toStrictEqual([[]]);
        });
      }
      if (editableState !== CATEGORY_LOCKED && id !== undefined) {
        it('shows an attribute edit dropdown item that emits edit-attribute', async () => {
          wrapper.findComponentByTestId('edit-attribute-item').vm.$emit('action');

          await nextTick();

          expect(wrapper.emitted()).toMatchObject({
            'edit-attribute': [[{ name: 'Business Administrative' }]],
          });
        });

        it('shows an attribute delete dropdown item that emits delete-attribute', async () => {
          wrapper.findComponentByTestId('delete-attribute-item').vm.$emit('action');

          await nextTick();

          expect(wrapper.emitted()).toMatchObject({
            'delete-attribute': [[{ name: 'Business Administrative' }]],
          });
        });
      }
      if (editableState === CATEGORY_LOCKED) {
        it('does not show attribute create/edit actions', () => {
          expect(wrapper.findComponent(GlButton).exists()).toBe(false);
          expect(wrapper.findComponent(GlDisclosureDropdownItem).exists()).toBe(false);
        });
      }
    });
  });

  describe('form validation and submission', () => {
    beforeEach(() => {
      createComponent({
        selectedCategory: {
          ...category,
          id: undefined,
          name: '',
          multipleSelection: null,
          securityAttributes: [],
        },
      });
    });

    it('requires a name', async () => {
      wrapper.findComponentByTestId('save-button').vm.$emit('click');
      await nextTick();

      expect(wrapper.findByTestId('category-name-group').attributes('state')).toBe(undefined);

      wrapper.findComponentByTestId('category-name-input').vm.$emit('input', 'Category name');
      wrapper.findComponentByTestId('save-button').vm.$emit('click');
      await nextTick();

      expect(wrapper.findByTestId('category-name-group').attributes('state')).toBe('true');
    });

    it('requires a selection type', async () => {
      wrapper.findComponentByTestId('save-button').vm.$emit('click');
      await nextTick();

      expect(wrapper.findByTestId('selection-type-group').attributes('state')).toBe(undefined);

      wrapper.findComponentByTestId('selection-type-input').vm.$emit('input', false);
      wrapper.findComponentByTestId('save-button').vm.$emit('click');
      await nextTick();

      expect(wrapper.findByTestId('selection-type-group').attributes('state')).toBe('true');
    });

    it('requires at least one attribute', async () => {
      wrapper.findComponentByTestId('save-button').vm.$emit('click');
      await nextTick();

      expect(wrapper.findByTestId('attributes-group').attributes('state')).toBe(undefined);

      await addAnAttribute();
      wrapper.findComponentByTestId('save-button').vm.$emit('click');

      expect(wrapper.findByTestId('attributes-group').attributes('state')).toBe('true');
    });

    it('resets validation state when the selected category changes', async () => {
      wrapper.findComponentByTestId('save-button').vm.$emit('click');
      await nextTick();

      expect(wrapper.findByTestId('category-name-group').attributes('state')).toBe(undefined);
      expect(wrapper.findByTestId('selection-type-group').attributes('state')).toBe(undefined);
      expect(wrapper.findByTestId('attributes-group').attributes('state')).toBe(undefined);

      wrapper.setProps({ selectedCategory: category });
      await nextTick();

      expect(wrapper.findByTestId('category-name-group').attributes('state')).toBe('true');
      expect(wrapper.findByTestId('selection-type-group').attributes('state')).toBe('true');
      expect(wrapper.findByTestId('attributes-group').attributes('state')).toBe('true');
    });

    it('emits save-category on save when valid', async () => {
      await addAnAttribute();
      wrapper.findComponentByTestId('category-name-input').vm.$emit('input', 'Category name');
      wrapper.findComponentByTestId('selection-type-input').vm.$emit('input', false);
      wrapper.findComponentByTestId('save-button').vm.$emit('click');

      expect(wrapper.emitted('save-category')[0][0]).toMatchObject({
        name: 'Category name',
        multipleSelection: false,
      });
    });
  });

  describe('unsaved changes status', () => {
    it('with no changes, does not show unsaved changes warning', async () => {
      createComponent({
        selectedCategory: {
          ...category,
          id: 10,
          name: 'Network',
          description: 'Security-related category',
          multipleSelection: false,
        },
        unsavedAttributes: [],
      });

      await nextTick();

      const container = wrapper.findByTestId('unsaved-changes-container');
      expect(container.text()).toBe('');
      expect(wrapper.findComponent({ name: 'GlPopover' }).exists()).toBe(false);
    });

    it('with changes, shows unsaved changes warning and renders the popover', async () => {
      createComponent({
        selectedCategory: {
          ...category,
          id: 11,
          name: 'Network',
          description: 'Security category',
          multipleSelection: false,
        },
        unsavedAttributes: [{ name: 'New Attribute' }],
      });

      await nextTick();

      const container = wrapper.findByTestId('unsaved-changes-container');
      expect(container.text()).toContain('unsaved change');
      expect(findPopover().exists()).toBe(true);

      expect(findPopover().text()).toContain('Created the attribute "New Attribute"');
    });

    it('once saved, shows "All changes saved" message', async () => {
      createComponent({
        selectedCategory: {
          ...category,
          id: 10,
          name: 'Network',
          description: 'Security-related category',
          multipleSelection: false,
        },
        unsavedAttributes: [],
      });
      wrapper.findComponentByTestId('save-button').vm.$emit('click');

      await nextTick();

      const container = wrapper.findByTestId('unsaved-changes-container');
      expect(container.text()).toContain('All changes saved');
      expect(wrapper.findComponent({ name: 'GlPopover' }).exists()).toBe(false);
    });

    it('after a delay, "All changes saved" disappears', async () => {
      createComponent({
        selectedCategory: {
          ...category,
          id: 10,
          name: 'Network',
          description: 'Security-related category',
          multipleSelection: false,
        },
        unsavedAttributes: [],
      });
      wrapper.findComponentByTestId('save-button').vm.$emit('click');

      jest.runOnlyPendingTimers(); // wait for setTimeout
      await nextTick();

      const container = wrapper.findByTestId('unsaved-changes-container');
      expect(container.text()).toBe('');
      expect(wrapper.findComponent({ name: 'GlPopover' }).exists()).toBe(false);
    });
  });

  describe('new category with unsaved attributes', () => {
    beforeEach(async () => {
      createComponent({
        selectedCategory: {
          ...category,
          name: 'Network',
          description: 'Security category',
          multipleSelection: false,
          editableState: CATEGORY_EDITABLE,
        },
        unsavedAttributes: [{ name: 'New Attribute', description: 'test' }],
      });

      await nextTick();
    });
    it('does not render edit dropdown item', () => {
      expect(wrapper.findByTestId('edit-attribute-item').exists()).toBe(false);
    });
  });
});
