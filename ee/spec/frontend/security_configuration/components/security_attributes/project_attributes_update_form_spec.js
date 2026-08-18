import { GlIcon, GlEmptyState } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectAttributesUpdateForm from 'ee/security_configuration/security_attributes/components/project_attributes_update_form.vue';
import AttributesCategoryDropdown from 'ee/security_configuration/security_attributes/components/attributes_category_dropdown.vue';
import { mockSecurityAttributeCategories } from './mock_data';

describe('ProjectAttributesDrawer', () => {
  let wrapper;

  const createComponent = ({
    categories = mockSecurityAttributeCategories,
    filteredCategories = mockSecurityAttributeCategories,
  } = {}) => {
    wrapper = shallowMountExtended(ProjectAttributesUpdateForm, {
      propsData: {
        categories,
        filteredCategories,
        selectedAttributes: [],
      },
    });
  };

  const findDropdowns = () => wrapper.findAllComponents(AttributesCategoryDropdown);
  const findIcons = () => wrapper.findAllComponents(GlIcon);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  beforeEach(() => {
    createComponent();
  });

  it('renders one dropdown for each category with attributes', () => {
    expect(findDropdowns()).toHaveLength(3);
  });

  it('filters out categories without security attributes', () => {
    const categories = [
      ...mockSecurityAttributeCategories,
      { id: 999, name: 'Empty category', securityAttributes: [] },
    ];
    createComponent({ categories });
    expect(findDropdowns()).toHaveLength(3);
  });

  it('passes correct props to category dropdown', () => {
    const dropdown = findDropdowns().at(0);
    const category = mockSecurityAttributeCategories[0];
    expect(dropdown.props('category')).toEqual(category);
    expect(dropdown.props('attributes')).toEqual(category.securityAttributes);
  });

  it('renders proper icon for each category depending on multipleSelection', () => {
    const icons = findIcons();
    expect(icons.at(0).props('name')).toBe('label'); // multipleSelection true
    expect(icons.at(1).props('name')).toBe('labels'); // multipleSelection false
  });

  it('emits flattened update when dropdown emits change', async () => {
    const category = mockSecurityAttributeCategories[0];
    const dropdown = findDropdowns().at(0);

    dropdown.vm.$emit('change', {
      categoryId: category.id,
      selectedAttributes: [100, 200],
    });

    await nextTick();

    const emitted = wrapper.emitted('update');
    expect(emitted).toHaveLength(2);

    // We have [1] because [0] is from the watcher
    expect(emitted[1][0]).toEqual([100, 200]);
  });

  it('shows an empty state when no categories have attributes', () => {
    const emptyCategory = {
      ...mockSecurityAttributeCategories[0],
      securityAttributes: [],
    };
    createComponent({ categories: [emptyCategory], filteredCategories: [] });

    expect(findEmptyState().props('title')).toBe(
      "There are no attributes for this project's group.",
    );
  });

  it('handles properly when categories is null or empty array', () => {
    createComponent({ categories: null, filteredCategories: [] });
    expect(wrapper.exists()).toBe(true);

    createComponent({ categories: [], filteredCategories: [] });
    expect(wrapper.exists()).toBe(true);
  });
});
