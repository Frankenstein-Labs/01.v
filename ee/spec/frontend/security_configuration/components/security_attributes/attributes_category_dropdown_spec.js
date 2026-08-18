import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { GlCollapsibleListbox, GlButton } from '@gitlab/ui';
import AttributesCategoryDropdown from 'ee/security_configuration/security_attributes/components/attributes_category_dropdown.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { mockSecurityAttributeCategories } from './mock_data';

Vue.use(VueApollo);

describe('AttributesCategoryDropdown', () => {
  let wrapper;

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findButton = () => wrapper.findComponent(GlButton);

  const createComponent = ({
    category = {},
    attributes = [],
    selectedAttributesInCategory = [],
    canManageAttributes = false,
    groupManageAttributesPath = 'path/to/group/-/security/configuration',
  } = {}) => {
    wrapper = shallowMount(AttributesCategoryDropdown, {
      provide: {
        canManageAttributes,
        groupManageAttributesPath,
      },
      propsData: {
        category,
        attributes,
        selectedAttributesInCategory,
      },
      stubs: {
        GlCollapsibleListbox,
        GlButton,
      },
    });
  };

  const mockMultipleSelection = {
    category: mockSecurityAttributeCategories.find((c) => c.id === 12), // Example category
    attributes: mockSecurityAttributeCategories.find((c) => c.id === 12).securityAttributes,
    selectedAttributesInCategory: [
      { id: 14, text: 'One' },
      { id: 15, text: 'Onee' },
      { id: 999, text: 'Extra' },
    ],
  };

  const mockSingleSelection = {
    category: mockSecurityAttributeCategories.find((c) => c.id === 6), // Business Impact
    attributes: mockSecurityAttributeCategories.find((c) => c.id === 6).securityAttributes,
    selectedAttributesInCategory: [{ id: 11, text: 'Non-essential' }],
  };

  describe.each`
    description             | category                          | attributes                          | selectedAttributesInCategory
    ${'multiple selection'} | ${mockMultipleSelection.category} | ${mockMultipleSelection.attributes} | ${mockMultipleSelection.selectedAttributesInCategory}
    ${'single selection'}   | ${mockSingleSelection.category}   | ${mockSingleSelection.attributes}   | ${mockSingleSelection.selectedAttributesInCategory}
  `('$description category', ({ category, attributes, selectedAttributesInCategory }) => {
    beforeEach(async () => {
      createComponent({
        category,
        attributes,
        selectedAttributesInCategory,
      });
      await waitForPromises();
    });

    it('renders list items based on provided attributes', () => {
      const items = attributes.map(({ id, name }) => ({
        value: id,
        text: name,
      }));

      const simplified = findListbox()
        .props('items')
        .map(({ value, text }) => ({ value, text }));
      expect(simplified).toEqual(expect.arrayContaining(items));
    });

    it('filters items based on search term', async () => {
      const searchTerm = category.multipleSelection ? 'one' : 'business';
      findListbox().vm.$emit('search', searchTerm);
      await nextTick();
      const filteredItems = findListbox()
        .props('items')
        .filter((i) => i.text.toLowerCase().includes(searchTerm));
      expect(filteredItems.length).toBeGreaterThan(0);
    });

    it('respects multiple selection setting', () => {
      expect(findListbox().props('multiple')).toBe(category.multipleSelection);
    });
  });

  describe('multiple selection behavior', () => {
    beforeEach(async () => {
      createComponent({
        category: mockMultipleSelection.category,
        attributes: mockMultipleSelection.attributes,
        selectedAttributesInCategory: mockMultipleSelection.selectedAttributesInCategory,
      });
      await waitForPromises();
    });

    it('starts with attributes from props selected', () => {
      // Computed: first two + “+1 more”
      expect(wrapper.vm.toggleText).toBe('One, Onee, +1 more');
    });

    it('changes selection correctly', async () => {
      findListbox().vm.$emit('select', [14, 15]);
      await nextTick();
      expect(wrapper.vm.toggleText).toBe('One, Onee');
    });

    it('clears selection', async () => {
      findListbox().vm.$emit('reset');
      await nextTick();
      expect(wrapper.vm.toggleText).toBe('None');
    });
  });

  describe('single selection behavior', () => {
    beforeEach(async () => {
      createComponent({
        category: mockSingleSelection.category,
        attributes: mockSingleSelection.attributes,
        selectedAttributesInCategory: mockSingleSelection.selectedAttributesInCategory,
      });
      await waitForPromises();
    });

    it('starts with attribute from props selected', () => {
      expect(wrapper.vm.toggleText).toBe('Non-essential');
    });

    it('updates selection correctly', async () => {
      const newSelection = mockSingleSelection.attributes.find((a) => a.id === 10);
      findListbox().vm.$emit('select', newSelection.id);
      await nextTick();
      expect(wrapper.vm.toggleText).toBe('Business Administrative');
    });

    it('clears selection correctly', async () => {
      findListbox().vm.$emit('reset');
      await nextTick();
      expect(wrapper.vm.toggleText).toBe('None');
    });
  });

  describe('footer section', () => {
    it('shows Manage Attributes link when permission is true', () => {
      createComponent({
        category: mockSingleSelection.category,
        attributes: mockSingleSelection.attributes,
        canManageAttributes: true,
      });
      expect(findButton().exists()).toBe(true);
      expect(findButton().text()).toContain('Manage security attributes');
    });

    it('does not show link when permission is false', () => {
      createComponent({
        category: mockSingleSelection.category,
        attributes: mockSingleSelection.attributes,
        canManageAttributes: false,
      });
      expect(findButton().exists()).toBe(false);
    });
  });
});
