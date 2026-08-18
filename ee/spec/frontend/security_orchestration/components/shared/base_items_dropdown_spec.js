import { GlCollapsibleListbox, GlTruncate } from '@gitlab/ui';
import BaseItemsDropdown from 'ee/security_orchestration/components/shared/base_items_dropdown.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';

describe('BaseItemsDropdown', () => {
  let wrapper;

  const mockedItemsIds = ['1', '2', '3'];
  const mockedItems = mockedItemsIds.map((id) => ({
    id,
    value: id,
    text: `text_${id}`,
    fullPath: `fullPath_${id}`,
  }));

  // Renders the listbox `#list-item` slot with a sample item so the passthrough
  // slot (and its default fallback) can be asserted under shallowMount.
  const listItemStub = (item) => ({
    stubs: {
      GlCollapsibleListbox: stubComponent(GlCollapsibleListbox, {
        data() {
          return { slotItem: item };
        },
        template: `<div><slot name="list-item" :item="slotItem"></slot></div>`,
      }),
    },
  });

  const createComponent = ({ propsData = {}, slots = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(BaseItemsDropdown, {
      propsData: {
        items: [],
        ...propsData,
      },
      slots,
      stubs,
    });
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('default rendering', () => {
    it('renders dropdown with default properties', () => {
      createComponent();

      expect(findDropdown().props('block')).toBe(true);
      expect(findDropdown().props('searchable')).toBe(true);
      expect(findDropdown().props('fluidWidth')).toBe(true);
      expect(findDropdown().props('isCheckCentered')).toBe(true);
      expect(findDropdown().props('headerText')).toBe('');
      expect(findDropdown().props('resetButtonLabel')).toBe('Clear all');

      expect(findDropdown().props('loading')).toBe(false);
      expect(findDropdown().props('searching')).toBe(false);
    });
  });

  describe('loading state', () => {
    it('renders loading and searching state', () => {
      createComponent({
        propsData: {
          loading: true,
          searching: true,
        },
      });

      expect(findDropdown().props('loading')).toBe(true);
      expect(findDropdown().props('searching')).toBe(true);
    });
  });

  describe('listbox items', () => {
    beforeEach(() => {
      createComponent({
        propsData: { items: mockedItems },
      });
    });

    it('renders listbox items', () => {
      expect(findDropdown().props('items')).toEqual(mockedItems);
    });

    it('selects items', () => {
      findDropdown().vm.$emit('select', mockedItemsIds[0]);
      expect(wrapper.emitted('select')).toEqual([[mockedItemsIds[0]]]);
    });

    it('selects all items', () => {
      findDropdown().vm.$emit('select-all');
      expect(wrapper.emitted('select-all')).toEqual([[mockedItemsIds]]);
    });

    it('renders correct default text', () => {
      expect(findDropdown().props('toggleText')).toBe('Select projects');
    });
  });

  describe('selected items', () => {
    const selected = [mockedItemsIds[0], mockedItemsIds[1]];
    it('renders selected items when ids are Strings', () => {
      createComponent({
        propsData: {
          items: mockedItems,
          selected,
        },
      });

      expect(findDropdown().props('selected')).toEqual(selected);
      expect(findDropdown().props('toggleText')).toBe('text_1, text_2');
    });

    it('renders selected items when ids are Numbers', () => {
      const selectedNumbers = selected.map(Number);
      createComponent({
        propsData: {
          items: mockedItems,
          selected: selectedNumbers,
        },
      });

      expect(findDropdown().props('selected')).toEqual(['1', '2']);
      expect(findDropdown().props('toggleText')).toBe('text_1, text_2');
    });
  });

  describe('single item selection', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          selected: mockedItemsIds[0],
          multiple: false,
        },
      });
    });

    it('does not render reset button label', () => {
      expect(findDropdown().props('resetButtonLabel')).toBe('');
    });

    it('renders selected id as string', () => {
      expect(findDropdown().props('selected')).toBe('1');
    });
  });

  describe('null/undefined selected handling', () => {
    it.each`
      selected     | multiple | expectedSelected | description
      ${null}      | ${false} | ${''}            | ${'null with multiple=false'}
      ${undefined} | ${false} | ${''}            | ${'undefined with multiple=false'}
      ${''}        | ${false} | ${''}            | ${'empty string with multiple=false'}
      ${null}      | ${true}  | ${[]}            | ${'null with multiple=true'}
    `(
      'does not crash when selected is $description',
      ({ selected, multiple, expectedSelected }) => {
        expect(() => {
          createComponent({
            propsData: {
              items: mockedItems,
              selected,
              multiple,
            },
          });
        }).not.toThrow();

        expect(findDropdown().props('selected')).toEqual(expectedSelected);
        expect(findDropdown().props('toggleText')).toBe('Select projects');
      },
    );
  });

  describe('select all button with infinite scroll', () => {
    it('shows select all label when infiniteScroll is false', () => {
      createComponent({
        propsData: {
          items: mockedItems,
          infiniteScroll: false,
        },
      });

      expect(findDropdown().props('showSelectAllButtonLabel')).toBe('Select all');
    });
  });

  describe('events', () => {
    it.each`
      event               | payload
      ${'reset'}          | ${undefined}
      ${'bottom-reached'} | ${undefined}
      ${'select-all'}     | ${mockedItemsIds}
      ${'search'}         | ${'abc'}
      ${'select'}         | ${[mockedItemsIds[0]]}
    `('emits events', ({ event, payload }) => {
      createComponent();
      findDropdown().vm.$emit(event, payload);

      expect(wrapper.emitted(event)).toHaveLength(1);
    });

    it('trims search event payload', () => {
      createComponent();
      findDropdown().vm.$emit('search', 'abc  ');

      expect(wrapper.emitted('search')).toEqual([['abc']]);
    });
  });

  describe('search', () => {
    it('renders correct text when search is performed with selected items', async () => {
      createComponent({
        propsData: {
          items: mockedItems,
          selected: [mockedItemsIds[0], mockedItemsIds[1]],
        },
      });

      expect(findDropdown().props('toggleText')).toEqual('text_1, text_2');

      await wrapper.setProps({ items: [mockedItems[2]] });
      await findDropdown().vm.$emit('search', 'text_3');

      expect(findDropdown().props('toggleText')).toEqual('text_1, text_2');
    });
  });

  describe('id prop', () => {
    it('forwards the id prop to the listbox', () => {
      createComponent({ propsData: { id: 'my-dropdown-id' } });

      expect(findDropdown().attributes('id')).toBe('my-dropdown-id');
    });
  });

  describe('list-item slot', () => {
    it('renders the default item content when no slot is provided', () => {
      createComponent({
        propsData: { items: mockedItems },
        ...listItemStub({ value: '1', text: 'text_1', fullPath: 'fullPath_1' }),
      });

      const truncates = wrapper.findAllComponents(GlTruncate);
      expect(truncates).toHaveLength(2);
      expect(truncates.at(0).props('text')).toBe('text_1');
      expect(truncates.at(1).props('text')).toBe('fullPath_1');
    });

    it('renders a caller-provided list-item slot instead of the default', () => {
      createComponent({
        propsData: { items: mockedItems },
        slots: { 'list-item': '<span data-testid="custom-item">custom</span>' },
        ...listItemStub({ value: '1', text: 'text_1', fullPath: 'fullPath_1' }),
      });

      expect(wrapper.findByTestId('custom-item').exists()).toBe(true);
      expect(wrapper.findComponent(GlTruncate).exists()).toBe(false);
    });
  });
});
