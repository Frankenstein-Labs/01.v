import { GlButton, GlCollapsibleListbox, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RemoveStatusModalListbox from 'ee/groups/settings/work_items/custom_status/remove_status_modal_listbox.vue';
import { mockLifecycles } from '../mock_data';

describe('RemoveStatusModalListbox', () => {
  let wrapper;

  const defaultProps = {
    items: mockLifecycles[0].statuses.map((status) => ({
      ...status,
      text: status.name,
      value: status.id,
    })),
    selected: mockLifecycles[0].statuses[0],
    toggleId: 'test-toggle-id',
    value: mockLifecycles[0].statuses[0].id,
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findToggleButton = () => findListbox().findComponent(GlButton);
  const findToggleIcon = () => findToggleButton().findComponent(GlIcon);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(RemoveStatusModalListbox, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders GlCollapsibleListbox with correct props', () => {
    expect(findListbox().props('block')).toBe(true);
    expect(findListbox().props('items')).toEqual(defaultProps.items);
    expect(findListbox().props('selected')).toBe(defaultProps.value);
    expect(findListbox().props('toggleId')).toBe(defaultProps.toggleId);
  });

  it('renders the toggle button with selected status details', () => {
    expect(findToggleIcon().props('name')).toBe(defaultProps.selected.iconName);
    expect(findToggleButton().text()).toContain(defaultProps.selected.name);
  });

  it('emits input event when a new item is selected', () => {
    const newItemId = mockLifecycles[0].statuses[1].id;

    findListbox().vm.$emit('select', newItemId);

    expect(wrapper.emitted('input')).toEqual([[newItemId]]);
  });
});
