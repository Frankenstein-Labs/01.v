import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import InventoryDashboardFilteredSearchBar from 'ee/security_inventory/components/inventory_dashboard_filtered_search_bar.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { queryToObject } from '~/lib/utils/url_utility';
import { toolCoverageTokens } from 'ee/security_inventory/components/tool_coverage_tokens';
import { vulnerabilityCountTokens } from 'ee/security_inventory/components/vulnerability_count_tokens';
import { statusTokens } from 'ee/security_inventory/components/status_tokens';
import { mockAnalyzerFilter, mockVulnerabilityFilter } from '../mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  queryToObject: jest.fn().mockReturnValue({}),
  setUrlParams: jest.fn().mockReturnValue(''),
}));

describe('InventoryDashboardFilteredSearchBar', () => {
  let wrapper;

  const createComponent = ({ props = {}, securityInventoryFiltering = true } = {}) => {
    wrapper = shallowMount(InventoryDashboardFilteredSearchBar, {
      provide: {
        glFeatures: {
          securityInventoryFiltering,
        },
      },
      propsData: {
        namespace: 'group1',
        ...props,
      },
    });
  };

  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);

  const emptyFilters = {
    securityAnalyzerFilters: [],
    vulnerabilityCountFilters: [],
    attributeFilters: [],
  };

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the filtered search component', () => {
      expect(findFilteredSearchBar().exists()).toBe(true);
    });

    it('passes the correct props to filtered search', () => {
      expect(findFilteredSearchBar().props()).toMatchObject({
        initialFilterValue: [],
        tokens: [
          { title: 'Security attributes', type: 'gl-filtered-search-suggestion-group-attributes' },
          ...vulnerabilityCountTokens,
          ...toolCoverageTokens,
        ],
        termsAsTokens: true,
      });
    });

    it('does not include status tokens when showStatusFilter is not set', () => {
      expect(findFilteredSearchBar().props('tokens')).not.toEqual(
        expect.arrayContaining(statusTokens),
      );
    });

    it('includes status tokens when showStatusFilter is true', () => {
      createComponent({ props: { showStatusFilter: true } });

      expect(findFilteredSearchBar().props('tokens')).toMatchObject([
        ...statusTokens,
        { title: 'Security attributes', type: 'gl-filtered-search-suggestion-group-attributes' },
        ...vulnerabilityCountTokens,
        ...toolCoverageTokens,
      ]);
    });

    it('has no tokens when filtering feature flag is disabled', () => {
      createComponent({ securityInventoryFiltering: false });

      expect(findFilteredSearchBar().props('tokens')).toStrictEqual([]);
    });
  });

  describe('initialFilterValue', () => {
    it('use initialFilters prop when search is provided', () => {
      createComponent({
        props: {
          initialFilters: { search: 'test-search' },
        },
      });
      expect(findFilteredSearchBar().props('initialFilterValue')).toEqual(['test-search']);
    });

    it('use URL search parameter when available and initialFilters is not provided', () => {
      queryToObject.mockReturnValue({ search: 'url-search' });
      createComponent();
      expect(findFilteredSearchBar().props('initialFilterValue')).toEqual(['url-search']);
    });

    it('returns empty array when no search is available', () => {
      queryToObject.mockReturnValue({});
      createComponent();
      expect(findFilteredSearchBar().props('initialFilterValue')).toEqual([]);
    });
  });

  describe('onFilter method', () => {
    it('emits filter-subgroups-and-projects event with search param when filtered with text', async () => {
      const searchTerm = 'test project';
      const filters = [
        {
          type: 'filtered-search-term',
          value: { data: searchTerm },
        },
      ];
      findFilteredSearchBar().vm.$emit('on-filter', filters);
      await nextTick();

      expect(wrapper.emitted('filter-subgroups-and-projects')[0][0]).toEqual({
        search: searchTerm,
        ...emptyFilters,
      });
    });

    it('emits filter-subgroups-and-projects event with combined search terms when multiple terms are provided', async () => {
      const searchTerms = ['test', 'project'];
      const filters = searchTerms.map((term) => ({
        type: 'filtered-search-term',
        value: { data: term },
      }));
      findFilteredSearchBar().vm.$emit('on-filter', filters);
      await nextTick();

      expect(wrapper.emitted('filter-subgroups-and-projects')[0][0]).toEqual({
        search: 'test project',
        ...emptyFilters,
      });
    });

    it('emits filter-subgroups-and-projects event without search when no search terms are provided', async () => {
      findFilteredSearchBar().vm.$emit('on-filter', []);
      await nextTick();
      expect(wrapper.emitted('filter-subgroups-and-projects')[0][0]).toEqual({
        ...emptyFilters,
      });
    });

    it('emits filter-subgroups-and-projects with vulnerability count filter', async () => {
      const filters = [
        {
          id: 'token-1',
          type: 'critical',
          value: { operator: '=', data: '0' },
        },
      ];
      findFilteredSearchBar().vm.$emit('on-filter', filters);
      await nextTick();
      expect(wrapper.emitted('filter-subgroups-and-projects')[0][0]).toEqual({
        securityAnalyzerFilters: [],
        vulnerabilityCountFilters: [mockVulnerabilityFilter],
        attributeFilters: [],
      });
    });

    it('emits filter-subgroups-and-projects with tool coverage filter', async () => {
      const filters = [
        {
          id: 'token-2',
          type: 'SAST_ADVANCED',
          value: { operator: '=', data: 'NOT_CONFIGURED' },
        },
      ];
      findFilteredSearchBar().vm.$emit('on-filter', filters);
      await nextTick();
      expect(wrapper.emitted('filter-subgroups-and-projects')[0][0]).toEqual({
        securityAnalyzerFilters: [mockAnalyzerFilter],
        vulnerabilityCountFilters: [],
        attributeFilters: [],
      });
    });

    it('emits filter-subgroups-and-projects with attribute filter', async () => {
      const filters = [
        {
          type: 'attribute-token-location',
          value: {
            operator: '||',
            data: ['gid://gitlab/Security::Attribute/6', 'gid://gitlab/Security::Attribute/7'],
          },
        },
      ];
      findFilteredSearchBar().vm.$emit('on-filter', filters);
      await nextTick();
      expect(wrapper.emitted('filter-subgroups-and-projects')[0][0]).toEqual({
        securityAnalyzerFilters: [],
        vulnerabilityCountFilters: [],
        attributeFilters: [
          {
            operator: 'IS_ONE_OF',
            attributes: [
              'gid://gitlab/Security::Attribute/6',
              'gid://gitlab/Security::Attribute/7',
            ],
          },
        ],
      });
    });

    it('skips filters without value data', async () => {
      const filters = [
        {
          type: 'filtered-search-term',
          value: { data: 'test search' },
        },
        {
          type: 'filtered-search-term',
          value: {},
        },
      ];
      findFilteredSearchBar().vm.$emit('on-filter', filters);
      await nextTick();

      expect(wrapper.emitted('filter-subgroups-and-projects')[0][0]).toEqual({
        search: 'test search',
        ...emptyFilters,
      });
    });

    it('ignores non-text filter types', async () => {
      const filters = [
        {
          type: 'filtered-search-term',
          value: { data: 'test search' },
        },
        {
          type: 'other-type',
          value: { data: 'should be ignored' },
        },
      ];
      findFilteredSearchBar().vm.$emit('on-filter', filters);
      await nextTick();

      expect(wrapper.emitted('filter-subgroups-and-projects')[0][0]).toEqual({
        search: 'test search',
        ...emptyFilters,
      });
    });

    describe('status filter', () => {
      it.each`
        selected             | expected
        ${'NEEDS_ATTENTION'} | ${{ hasFailedOrWarning: true }}
        ${'STALE_SCANS'}     | ${{ hasStale: true }}
        ${'UNPROTECTED'}     | ${{ hasScanners: false }}
      `(
        'emits filter-subgroups-and-projects with $expected when status is $selected',
        async ({ selected, expected }) => {
          const filters = [
            {
              type: 'STATUS',
              value: { operator: '=', data: selected },
            },
          ];
          findFilteredSearchBar().vm.$emit('on-filter', filters);
          await nextTick();

          expect(wrapper.emitted('filter-subgroups-and-projects')[0][0]).toEqual({
            ...emptyFilters,
            ...expected,
          });
        },
      );

      it('ignores unknown status values', async () => {
        const filters = [
          {
            type: 'STATUS',
            value: { operator: '=', data: 'UNKNOWN_STATUS' },
          },
        ];
        findFilteredSearchBar().vm.$emit('on-filter', filters);
        await nextTick();

        expect(wrapper.emitted('filter-subgroups-and-projects')[0][0]).toEqual({
          ...emptyFilters,
        });
      });
    });
  });
});
