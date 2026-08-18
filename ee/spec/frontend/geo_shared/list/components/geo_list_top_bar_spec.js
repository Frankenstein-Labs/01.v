import { GlIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoListTopBar from 'ee/geo_shared/list/components/geo_list_top_bar.vue';
import GeoListFilteredSearchBar from 'ee/geo_shared/list/components/geo_list_filtered_search_bar.vue';
import GeoListBulkActions from 'ee/geo_shared/list/components/geo_list_bulk_actions.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { MOCK_LISTBOX_ITEMS, MOCK_FILTER_A, MOCK_BULK_ACTIONS, MOCK_SORT } from '../mock_data';

describe('GeoListTopBar', () => {
  let wrapper;

  const defaultProps = {
    listboxHeaderText: 'Select item',
    activeListboxItem: MOCK_LISTBOX_ITEMS[0].value,
    activeFilteredSearchFilters: [MOCK_FILTER_A],
    activeSort: MOCK_SORT,
    showActions: true,
    bulkActions: MOCK_BULK_ACTIONS,
    pageHeadingTitle: 'Test Title',
    pageHeadingDescription: 'Test Description',
    filteredSearchOptionLabel: 'Test Label',
  };

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMountExtended(GeoListTopBar, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        PageHeading,
      },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(GeoListFilteredSearchBar);
  const findBulkActions = () => wrapper.findComponent(GeoListBulkActions);
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findListCount = () => wrapper.findByTestId('list-count');
  const findListCountIcon = () => wrapper.findComponent(GlIcon);

  describe('GeoListFilteredSearchBar', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with correct props', () => {
      expect(findFilteredSearch().props()).toStrictEqual({
        listboxHeaderText: 'Select item',
        activeListboxItem: MOCK_LISTBOX_ITEMS[0].value,
        activeFilteredSearchFilters: [MOCK_FILTER_A],
        filteredSearchOptionLabel: 'Test Label',
        activeSort: MOCK_SORT,
      });
    });

    it('handleListboxChange properly passes along the event', async () => {
      findFilteredSearch().vm.$emit('listbox-change', 'test-value');
      await nextTick();

      expect(wrapper.emitted('listbox-change')).toStrictEqual([['test-value']]);
    });

    it('handleSearch properly passes along the event', async () => {
      findFilteredSearch().vm.$emit('search', 'test-search');
      await nextTick();

      expect(wrapper.emitted('search')).toStrictEqual([['test-search']]);
    });

    it('handleSort properly passes along the event', async () => {
      findFilteredSearch().vm.$emit('sort', { value: 'test_sort', direction: 'asc' });
      await nextTick();

      expect(wrapper.emitted('sort')).toStrictEqual([[{ value: 'test_sort', direction: 'asc' }]]);
    });
  });

  describe('PageHeading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with correct props and text', () => {
      expect(findPageHeading().props('heading')).toBe(defaultProps.pageHeadingTitle);
      expect(findPageHeading().text()).toContain(defaultProps.pageHeadingDescription);
    });
  });

  describe.each`
    description                               | props                                                        | showText | showIcon
    ${'when no count is provided'}            | ${null}                                                      | ${false} | ${false}
    ${'when count is provided without icon'}  | ${{ listCountText: '1000 Results' }}                         | ${true}  | ${false}
    ${'when both count and icon is provided'} | ${{ listCountIcon: 'earth', listCountText: '1000 Results' }} | ${true}  | ${true}
  `('list count $description', ({ props, showText, showIcon }) => {
    beforeEach(() => {
      createComponent({ props });
    });

    it(`${showText ? 'does' : 'does not'} render the list count text`, () => {
      expect(findListCount().exists()).toBe(showText);
    });

    it(`${showIcon ? 'does' : 'does not'} render the list count icon`, () => {
      expect(findListCountIcon().exists()).toBe(showIcon);
    });
  });

  describe('GeoListBulkActions', () => {
    describe('when showActions is false', () => {
      beforeEach(() => {
        createComponent({ props: { showActions: false } });
      });

      it('does not render bulk actions', () => {
        expect(findBulkActions().exists()).toBe(false);
      });
    });

    describe('when showActions is true', () => {
      beforeEach(() => {
        createComponent({ props: { showActions: true } });
      });

      it('renders with correct props', () => {
        expect(findBulkActions().props('bulkActions')).toStrictEqual(MOCK_BULK_ACTIONS);
      });

      it('handleBulkAction properly passes along the event', async () => {
        findBulkActions().vm.$emit('bulk-action', 'test-action');
        await nextTick();

        expect(wrapper.emitted('bulk-action')).toStrictEqual([['test-action']]);
      });
    });
  });
});
