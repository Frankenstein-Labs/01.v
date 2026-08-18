import { GlCollapsibleListbox, GlSorting } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoListFilteredSearchBar from 'ee/geo_shared/list/components/geo_list_filtered_search_bar.vue';
import GeoListFilteredSearch from 'ee/geo_shared/list/components/geo_list_filtered_search.vue';
import { SORT_DIRECTION } from 'ee/geo_shared/constants';
import {
  MOCK_LISTBOX_ITEMS,
  MOCK_FILTER_A,
  MOCK_FILTER_B,
  MOCK_SORT,
  MOCK_SORT_OPTIONS,
} from '../mock_data';

describe('GeoListFilteredSearchBar', () => {
  let wrapper;

  const defaultProps = {
    listboxHeaderText: 'Select item',
    activeListboxItem: MOCK_LISTBOX_ITEMS[0].value,
    activeFilteredSearchFilters: [MOCK_FILTER_A],
    filteredSearchOptionLabel: 'Test Label',
    activeSort: MOCK_SORT,
  };

  const defaultProvide = {
    listboxItems: MOCK_LISTBOX_ITEMS,
    sortOptions: MOCK_SORT_OPTIONS,
  };

  const createComponent = ({ props = {} } = {}) => {
    const propsData = {
      ...defaultProps,
      ...props,
    };

    wrapper = shallowMountExtended(GeoListFilteredSearchBar, {
      propsData,
      provide: {
        ...defaultProvide,
      },
    });
  };

  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findFilteredSearch = () => wrapper.findComponent(GeoListFilteredSearch);
  const findGlSorting = () => wrapper.findComponent(GlSorting);

  describe('Collapsible Listbox', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with the correct selected filter', () => {
      expect(findCollapsibleListbox().props('selected')).toBe(MOCK_LISTBOX_ITEMS[0].value);
    });

    it('renders with the provided listbox options', () => {
      expect(findCollapsibleListbox().props('items')).toStrictEqual(MOCK_LISTBOX_ITEMS);
    });

    it('on search updates the items retaining the selected item', async () => {
      const mockSearch = MOCK_LISTBOX_ITEMS[2].text;
      const expectedSearchedItems = [MOCK_LISTBOX_ITEMS[0], MOCK_LISTBOX_ITEMS[2]];

      findCollapsibleListbox().vm.$emit('search', mockSearch);
      await nextTick();

      expect(findCollapsibleListbox().props('items')).toStrictEqual(expectedSearchedItems);
    });

    it('on select emits listbox-change to the parent with selected filter', async () => {
      findCollapsibleListbox().vm.$emit('select', MOCK_LISTBOX_ITEMS[2].value);
      await nextTick();

      expect(wrapper.emitted('listbox-change')).toStrictEqual([[MOCK_LISTBOX_ITEMS[2].value]]);
    });
  });

  describe('Filtered search', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with the correct active filters', () => {
      expect(findFilteredSearch().props('activeFilters')).toStrictEqual([MOCK_FILTER_A]);
    });

    it('renders with the correct filtered search option label', () => {
      expect(findFilteredSearch().props('filteredSearchOptionLabel')).toBe('Test Label');
    });

    it('on search event emits search to the parent with the passed arguments', async () => {
      findFilteredSearch().vm.$emit('search', [MOCK_FILTER_B]);
      await nextTick();

      expect(wrapper.emitted('search')).toStrictEqual([[[MOCK_FILTER_B]]]);
    });
  });

  describe('Sorting', () => {
    it.each`
      direction              | expectedIsAscending
      ${SORT_DIRECTION.DESC} | ${false}
      ${SORT_DIRECTION.ASC}  | ${true}
    `(
      'renders with the correct props when provided sort is $direction',
      ({ direction, expectedIsAscending }) => {
        createComponent({
          props: { activeSort: { value: MOCK_SORT.value, direction } },
        });

        expect(findGlSorting().props()).toStrictEqual(
          expect.objectContaining({
            sortBy: MOCK_SORT.value,
            isAscending: expectedIsAscending,
            sortOptions: MOCK_SORT_OPTIONS,
          }),
        );
      },
    );

    describe('events', () => {
      beforeEach(() => {
        createComponent();
      });

      it('handleSortChange passes the correct data through the sort event', async () => {
        findGlSorting().vm.$emit('sortByChange', 'new_value');
        await nextTick();

        expect(wrapper.emitted('sort')).toStrictEqual([[{ value: 'new_value', direction: 'asc' }]]);
      });

      it('handleSortDirectionChange passes the correct data through the sort event', async () => {
        findGlSorting().vm.$emit('sortDirectionChange', false);
        await nextTick();

        expect(wrapper.emitted('sort')).toStrictEqual([
          [{ value: MOCK_SORT.value, direction: 'desc' }],
        ]);
      });
    });
  });
});
