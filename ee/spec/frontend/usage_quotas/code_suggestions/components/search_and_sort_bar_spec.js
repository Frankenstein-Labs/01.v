import { shallowMount } from '@vue/test-utils';
import SearchAndSortBar from 'ee/usage_quotas/code_suggestions/components/search_and_sort_bar.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import {
  FILTERED_SEARCH_TERM,
  OPERATORS_IS,
  TOKEN_TITLE_GROUP_INVITE,
  TOKEN_TITLE_PROJECT,
  TOKEN_TYPE_GROUP_INVITE,
  TOKEN_TYPE_PROJECT,
  TOKEN_TITLE_ASSIGNED_SEAT,
  TOKEN_TYPE_ASSIGNED_SEAT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import ProjectToken from 'ee/usage_quotas/code_suggestions/tokens/project_token.vue';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';

describe('SearchAndSortBar', () => {
  let wrapper;

  const fullPath = 'namespace/full-path';
  const tokens = [
    {
      type: TOKEN_TYPE_PROJECT,
      icon: 'project',
      title: TOKEN_TITLE_PROJECT,
      unique: true,
      token: ProjectToken,
      operators: OPERATORS_IS,
      fullPath,
    },
    {
      options: [
        { value: 'true', title: 'Yes' },
        { value: 'false', title: 'No' },
      ],
      type: TOKEN_TYPE_GROUP_INVITE,
      icon: 'user',
      title: TOKEN_TITLE_GROUP_INVITE,
      unique: true,
      token: BaseToken,
      operators: OPERATORS_IS,
    },
    {
      options: [
        { value: 'true', title: 'Yes' },
        { value: 'false', title: 'No' },
      ],
      type: TOKEN_TYPE_ASSIGNED_SEAT,
      icon: 'user',
      title: TOKEN_TITLE_ASSIGNED_SEAT,
      unique: true,
      token: BaseToken,
      operators: OPERATORS_IS,
    },
  ];

  const createComponent = ({ props = {}, provideProps = {} } = {}) => {
    wrapper = shallowMount(SearchAndSortBar, {
      propsData: props,
      provide: {
        ...provideProps,
      },
    });
  };

  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);

  describe('renders filtered search and sort bar', () => {
    it('renders search and sort bar with default params', () => {
      createComponent();

      expect(findFilteredSearchBar().props()).toMatchObject({
        namespace: '',
        searchInputPlaceholder: 'Filter users',
        sortOptions: [],
      });
    });

    describe('with sort options', () => {
      const options = ['option 1', 'option 2'];

      it('renders search and sort bar with default params', () => {
        createComponent({ props: { sortOptions: options } });

        expect(findFilteredSearchBar().props()).toMatchObject({
          namespace: '',
          searchInputPlaceholder: 'Filter users',
          sortOptions: options,
        });
      });
    });

    describe('with the tokens', () => {
      it('passes the correct tokens', () => {
        createComponent({
          props: { tokens },
          provideProps: { fullPath },
        });

        expect(findFilteredSearchBar().props('tokens')).toHaveLength(3);
        expect(findFilteredSearchBar().props('tokens')).toStrictEqual(tokens);
      });
    });

    it('renders search and sort bar with appropriate params', () => {
      createComponent({ provideProps: { fullPath } });

      expect(findFilteredSearchBar().props()).toMatchObject({
        namespace: fullPath,
        searchInputPlaceholder: 'Filter users',
      });
    });
  });

  describe('when searching', () => {
    describe('with search term only', () => {
      describe('when search term has no spaces', () => {
        it('emits search event with appropriate params', () => {
          const searchTerm = 'userone';
          const searchTokens = [
            { type: FILTERED_SEARCH_TERM, value: { data: searchTerm } },
            { type: FILTERED_SEARCH_TERM, value: { data: '' } },
          ];

          createComponent();
          findFilteredSearchBar().vm.$emit('on-filter', searchTokens);

          expect(wrapper.emitted('on-filter')[0][0]).toStrictEqual({
            search: searchTerm,
            filterByProjectId: undefined,
            filterByGroupInvite: undefined,
            filterByAssignedSeat: undefined,
          });
        });
      });

      describe('when search term has spaces', () => {
        it('emits search event with appropriate params', () => {
          const token1 = 'search';
          const token2 = 'with spaces';
          const searchTokens = [
            { type: FILTERED_SEARCH_TERM, value: { data: token1 } },
            { type: FILTERED_SEARCH_TERM, value: { data: token2 } },
            { type: FILTERED_SEARCH_TERM, value: { data: '' } },
          ];

          createComponent();
          findFilteredSearchBar().vm.$emit('on-filter', searchTokens);

          expect(wrapper.emitted('on-filter')[0][0]).toStrictEqual({
            search: 'search with spaces',
            filterByProjectId: undefined,
            filterByGroupInvite: undefined,
            filterByAssignedSeat: undefined,
          });
        });
      });
    });

    describe('with search and filter terms', () => {
      const groupInvite = 'yes';
      const projectId = 'project-id';
      const searchTerm = 'search term';
      const assignedSeat = 'yes';

      it('emits search event with appropriate params', () => {
        const searchTokens = [
          { type: FILTERED_SEARCH_TERM, value: { data: searchTerm } },
          { type: TOKEN_TYPE_PROJECT, value: { data: projectId } },
          { type: TOKEN_TYPE_GROUP_INVITE, value: { data: groupInvite } },
          { type: TOKEN_TYPE_ASSIGNED_SEAT, value: { data: assignedSeat } },
        ];
        createComponent();
        findFilteredSearchBar().vm.$emit('on-filter', searchTokens);

        expect(wrapper.emitted('on-filter')[0][0]).toStrictEqual({
          search: searchTerm,
          filterByProjectId: projectId,
          filterByGroupInvite: groupInvite,
          filterByAssignedSeat: assignedSeat,
        });
      });

      describe.each([
        [
          { type: FILTERED_SEARCH_TERM, value: { data: searchTerm } },
          {
            search: searchTerm,
            filterByProjectId: undefined,
            filterByGroupInvite: undefined,
            filterByAssignedSeat: undefined,
          },
        ],
        [
          { type: TOKEN_TYPE_GROUP_INVITE, value: { data: groupInvite } },
          {
            search: undefined,
            filterByProjectId: undefined,
            filterByGroupInvite: groupInvite,
            filterByAssignedSeat: undefined,
          },
        ],
        [
          { type: TOKEN_TYPE_PROJECT, value: { data: projectId } },
          {
            search: undefined,
            filterByProjectId: projectId,
            filterByGroupInvite: undefined,
            filterByAssignedSeat: undefined,
          },
        ],
        [
          { type: TOKEN_TYPE_ASSIGNED_SEAT, value: { data: assignedSeat } },
          {
            search: undefined,
            filterByProjectId: undefined,
            filterByGroupInvite: undefined,
            filterByAssignedSeat: assignedSeat,
          },
        ],
        [
          { type: 'status', value: { data: 'test' } },
          {
            search: undefined,
            filterByProjectId: undefined,
            filterByGroupInvite: undefined,
            filterByAssignedSeat: undefined,
          },
        ],
      ])('with invalid type or data: %s', (searchTokens, expected) => {
        it('emits the correct filter values', () => {
          createComponent();
          findFilteredSearchBar().vm.$emit('on-filter', [searchTokens]);

          expect(wrapper.emitted('on-filter')[0][0]).toStrictEqual(expected);
        });
      });

      describe.each([
        [{ type: FILTERED_SEARCH_TERM, value: { data: undefined } }],
        [{ type: TOKEN_TYPE_GROUP_INVITE, value: { data: undefined } }],
        [{ type: TOKEN_TYPE_PROJECT, value: { data: undefined } }],
        [{ type: TOKEN_TYPE_ASSIGNED_SEAT, value: { data: undefined } }],
        [{ type: 'status', value: { data: 'test' } }],
      ])('with invalid type or data: %s', (searchTokens) => {
        it('emits the correct filter values', () => {
          createComponent();
          findFilteredSearchBar().vm.$emit('on-filter', [searchTokens]);

          expect(wrapper.emitted('on-filter')[0][0]).toStrictEqual({
            search: undefined,
            filterByProjectId: undefined,
            filterByGroupInvite: undefined,
            filterByAssignedSeat: undefined,
          });
        });
      });

      it.each([
        undefined,
        {},
        { type: undefined, value: undefined },
        { type: FILTERED_SEARCH_TERM, value: { data: undefined } },
      ])('emits search event with params: %s', (token) => {
        const searchTokens = [
          { type: FILTERED_SEARCH_TERM, value: { data: searchTerm } },
          { type: TOKEN_TYPE_PROJECT, value: { data: projectId } },
          token,
        ];
        createComponent();
        findFilteredSearchBar().vm.$emit('on-filter', searchTokens);

        expect(wrapper.emitted('on-filter')[0][0]).toStrictEqual({
          search: searchTerm,
          filterByProjectId: projectId,
          filterByGroupInvite: undefined,
          filterByAssignedSeat: undefined,
        });
      });
    });

    describe('when sorting', () => {
      it('emits the sort event with the correct value', () => {
        const sort = 'sort_value_desc';
        createComponent();
        findFilteredSearchBar().vm.$emit('on-sort', sort);

        expect(wrapper.emitted('on-sort')[0][0]).toStrictEqual(sort);
      });
    });
  });
});
