import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import AiCatalogListWrapper from 'ee/ai/catalog/components/ai_catalog_list_wrapper.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import { SORT_OPTIONS } from 'ee/ai/catalog/constants';
import { mockAgents, mockPageInfo, mockItemTypeConfig } from '../mock_data';

describe('AiCatalogListWrapper', () => {
  let wrapper;

  const mockItems = mockAgents;
  const mockEmptyStateTitle = 'Get started with AI';
  const mockEmptyStateDescription = 'Build agents and flows';
  const mockEmptyStateButtonHref = '/explore/ai-catalog';
  const mockEmptyStateButtonText = 'Explore AI Catalog';

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogListWrapper, {
      propsData: {
        items: mockItems,
        itemTypeConfig: mockItemTypeConfig,
        isLoading: false,
        pageInfo: mockPageInfo,
        emptyStateTitle: mockEmptyStateTitle,
        emptyStateDescription: mockEmptyStateDescription,
        emptyStateButtonHref: mockEmptyStateButtonHref,
        emptyStateButtonText: mockEmptyStateButtonText,
        initialSortBy: '',
        ...props,
      },
    });
  };

  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);
  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders FilteredSearchBar component when items are present', () => {
      expect(findFilteredSearchBar().exists()).toBe(true);
    });

    it('hides FilteredSearchBar when there are no items and no search term', () => {
      createComponent({ props: { items: [], searchTerm: '' } });

      expect(findFilteredSearchBar().exists()).toBe(false);
    });

    it('shows FilteredSearchBar when there are no items but a search term is active', () => {
      createComponent({ props: { items: [], searchTerm: 'foo' } });

      expect(findFilteredSearchBar().exists()).toBe(true);
    });

    it('shows FilteredSearchBar while loading even with no items', () => {
      createComponent({ props: { items: [], isLoading: true } });

      expect(findFilteredSearchBar().exists()).toBe(true);
    });

    it('renders AiCatalogList component', () => {
      expect(findAiCatalogList().exists()).toBe(true);
    });

    it('passes correct props to AiCatalogList', () => {
      const catalogList = findAiCatalogList();

      expect(catalogList.props()).toMatchObject({
        items: mockItems,
        isLoading: false,
        emptyStateTitle: mockEmptyStateTitle,
        emptyStateDescription: mockEmptyStateDescription,
        emptyStateButtonHref: mockEmptyStateButtonHref,
        emptyStateButtonText: mockEmptyStateButtonText,
      });
    });

    it('initializes with empty search term', () => {
      expect(findAiCatalogList().props('search')).toBe('');
    });
  });

  describe('search and filter functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits filter event when FilteredSearchBar emits on-filter', () => {
      findFilteredSearchBar().vm.$emit('on-filter', []);

      expect(wrapper.emitted('filter')).toHaveLength(1);
    });
  });

  describe('sort functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits sort event when FilteredSearchBar emits on-sort', () => {
      findFilteredSearchBar().vm.$emit('on-sort', 'STAR_COUNT_DESC');

      expect(wrapper.emitted('sort')).toHaveLength(1);
      expect(wrapper.emitted('sort')[0]).toEqual(['STAR_COUNT_DESC']);
    });

    it('passes sortOptions prop to FilteredSearchBar', () => {
      expect(findFilteredSearchBar().props('sortOptions')).toEqual(SORT_OPTIONS);
    });

    it('passes empty initialSortBy for directionless default sort', () => {
      createComponent({ props: { initialSortBy: '' } });

      expect(findFilteredSearchBar().props('initialSortBy')).toBe('');
    });

    it('passes sortDirectionToggleClass to suppress direction button for default sort', () => {
      createComponent({ props: { initialSortBy: '' } });

      expect(findFilteredSearchBar().props('sortDirectionToggleClass')).toBe(
        'gl-pointer-events-none gl-opacity-50',
      );
    });

    it('does not suppress direction button for directional sorts', () => {
      createComponent({ props: { initialSortBy: 'STAR_COUNT_DESC' } });

      expect(findFilteredSearchBar().props('sortDirectionToggleClass')).toBe('');
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes pageInfo to AiCatalogList', () => {
      expect(findAiCatalogList().props('pageInfo')).toMatchObject(mockPageInfo);
    });

    it('emits next-page event when AiCatalogList emits next-page', () => {
      findAiCatalogList().vm.$emit('next-page');

      expect(wrapper.emitted('next-page')).toHaveLength(1);
    });

    it('emits prev-page event when AiCatalogList emits prev-page', () => {
      findAiCatalogList().vm.$emit('prev-page');

      expect(wrapper.emitted('prev-page')).toHaveLength(1);
    });
  });

  describe('loading state', () => {
    it('passes loading state to AiCatalogList', () => {
      createComponent({ props: { isLoading: true } });

      expect(findAiCatalogList().props('isLoading')).toBe(true);
    });

    it('passes false loading state to AiCatalogList', () => {
      createComponent({ props: { isLoading: false } });

      expect(findAiCatalogList().props('isLoading')).toBe(false);
    });
  });

  describe('empty state props', () => {
    it('passes all empty state props to AiCatalogList', () => {
      createComponent();
      const catalogList = findAiCatalogList();

      expect(catalogList.props()).toMatchObject({
        emptyStateTitle: mockEmptyStateTitle,
        emptyStateDescription: mockEmptyStateDescription,
        emptyStateButtonHref: mockEmptyStateButtonHref,
        emptyStateButtonText: mockEmptyStateButtonText,
      });
    });

    it('uses fallback text when no empty state props are passed', () => {
      createComponent({
        props: {
          emptyStateTitle: undefined,
          emptyStateDescription: undefined,
          emptyStateButtonHref: undefined,
          emptyStateButtonText: undefined,
        },
      });
      const catalogList = findAiCatalogList();

      expect(catalogList.props()).toMatchObject({
        emptyStateTitle: 'Get started with the AI Catalog',
        emptyStateDescription:
          'Build agents and flows to automate tasks and solve complex problems.',
        emptyStateButtonHref: null,
        emptyStateButtonText: null,
      });
    });
  });
});
