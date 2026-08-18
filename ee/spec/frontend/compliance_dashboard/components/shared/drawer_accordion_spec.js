import { shallowMount } from '@vue/test-utils';
import { GlAnimatedChevronLgRightDownIcon, GlCollapse } from '@gitlab/ui';
import DrawerAccordion from 'ee/compliance_dashboard/components/shared/drawer_accordion.vue';

describe('DrawerAccordion', () => {
  let wrapper;
  const mockItems = [
    { id: 1, title: 'Item 1' },
    { id: 2, title: 'Item 2' },
  ];
  const toggleItem = (index) =>
    wrapper.findAllComponents(GlAnimatedChevronLgRightDownIcon).at(index).trigger('click');
  const findCollapses = () => wrapper.findAllComponents(GlCollapse);

  const createComponent = (props = {}) => {
    wrapper = shallowMount(DrawerAccordion, {
      propsData: {
        items: mockItems,
        ...props,
      },
      scopedSlots: {
        header: '<span class="test-header">{{ props.item.title }}</span>',
        default: '<div class="test-content">Content for {{ props.item.title }}</div>',
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders header slot for each item', () => {
    const itemElements = wrapper.findAll('.test-header');
    expect(itemElements.at(0).html()).toContain('Item 1');
    expect(itemElements.at(1).html()).toContain('Item 2');
  });

  it('renders GlCollapse for each item', () => {
    expect(findCollapses()).toHaveLength(mockItems.length);
  });

  it('all items are collapsed by default', () => {
    expect(findCollapses().wrappers.every((c) => c.props('visible') === false)).toBe(true);
  });

  it('toggles item visibility when clicked', async () => {
    await toggleItem(0);

    expect(findCollapses().at(0).props('visible')).toBe(true);
  });

  it('does not close previously opened item when another item is clicked', async () => {
    const items = wrapper.findAll('.gl-flex.gl-cursor-pointer');
    await items.at(0).trigger('click');
    await items.at(1).trigger('click');

    expect(findCollapses().at(0).props('visible')).toBe(true);
    expect(findCollapses().at(1).props('visible')).toBe(true);
  });

  it('toggles off an item when clicked twice', async () => {
    await toggleItem(0);
    await toggleItem(0);

    expect(findCollapses().at(0).props('visible')).toBe(false);
  });

  it('renders empty component when items are empty', () => {
    createComponent({ items: [] });
    expect(wrapper.text()).toBe('');
    expect(findCollapses()).toHaveLength(0);
  });
});
