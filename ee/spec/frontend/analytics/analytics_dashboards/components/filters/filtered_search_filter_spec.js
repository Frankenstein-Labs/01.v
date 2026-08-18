import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FilteredSearchFilter from 'ee/analytics/analytics_dashboards/components/filters/filtered_search_filter.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import {
  mockAssigneeToken,
  mockAuthorToken,
  mockLabelToken,
  mockMilestoneToken,
  mockFilteredSearchFilters,
  mockFilteredSearchChangePayload,
  mockGroupLabelsResponse,
  mockProjectLabelsResponse,
  mockRepositoryBranchNamesResponse,
  mockSourceBranchToken,
  mockTargetBranchToken,
} from 'ee_jest/analytics/analytics_dashboards/mock_data';
import searchLabelsQuery from 'ee/analytics/analytics_dashboards/graphql/queries/search_labels.query.graphql';
import searchBranchesQuery from 'ee/analytics/analytics_dashboards/graphql/queries/search_branches.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  OPERATORS_IS,
  OPERATORS_IS_NOT,
  OPERATORS_IS_NOT_OR,
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_SOURCE_BRANCH,
  TOKEN_TYPE_TARGET_BRANCH,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  FILTERED_SEARCH_OPERATOR_IS,
  FILTERED_SEARCH_OPERATOR_IS_NOT,
  FILTERED_SEARCH_OPERATOR_IS_NOT_OR,
  FILTERED_SEARCH_SUPPORTED_TOKENS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

Vue.use(VueApollo);

describe('FilteredSearchFilter', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const namespaceFullPath = 'gitlab';
  const defaultProvide = {
    namespaceFullPath,
    hasScopedLabelsFeature: false,
  };

  const defaultFilteredSearchBarProps = {
    namespace: 'gitlab',
    recentSearchesStorageKey: 'analytics-dashboard',
    searchInputPlaceholder: 'Filter results',
    termsAsTokens: true,
  };

  const allTokenOptions = FILTERED_SEARCH_SUPPORTED_TOKENS.map((token) => ({
    token,
  }));

  const projectOnlyTokenOptions = [
    { token: TOKEN_TYPE_SOURCE_BRANCH },
    { token: TOKEN_TYPE_TARGET_BRANCH },
  ];

  const groupLabelsQueryHandler = jest.fn().mockResolvedValue(mockGroupLabelsResponse);
  const projectLabelsQueryHandler = jest.fn().mockResolvedValue(mockProjectLabelsResponse);
  const repoBranchesQueryHandler = jest.fn().mockResolvedValue(mockRepositoryBranchNamesResponse);

  const createWrapper = ({
    props = {},
    provide = defaultProvide,
    isProject = false,
    labelsQueryHandler = groupLabelsQueryHandler,
  } = {}) => {
    const mockApollo = createMockApollo([
      [searchLabelsQuery, labelsQueryHandler],
      [searchBranchesQuery, repoBranchesQueryHandler],
    ]);

    wrapper = shallowMountExtended(FilteredSearchFilter, {
      apolloProvider: mockApollo,
      provide: {
        isProject,
        ...provide,
      },
      propsData: {
        ...props,
      },
    });
  };

  const getTokenWithNamespaceProps = ({
    token = {},
    fullPath = namespaceFullPath,
    isProject = false,
  } = {}) => ({
    ...token,
    fullPath,
    isProject,
  });

  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);
  const findToken = (token) =>
    findFilteredSearchBar()
      .props('tokens')
      .find(({ type }) => type === token);

  describe('default', () => {
    describe.each([true, false])('isProject=%s', (isProject) => {
      it('renders filtered search bar with default tokens', () => {
        createWrapper({ isProject });

        expect(findFilteredSearchBar().props()).toMatchObject({
          ...defaultFilteredSearchBarProps,
          tokens: expect.arrayContaining([
            expect.objectContaining(
              getTokenWithNamespaceProps({ token: mockMilestoneToken, isProject }),
            ),
            expect.objectContaining(mockLabelToken),
            expect.objectContaining(
              getTokenWithNamespaceProps({ token: mockAuthorToken, isProject }),
            ),
            expect.objectContaining(
              getTokenWithNamespaceProps({ token: mockAssigneeToken, isProject }),
            ),
          ]),
        });
      });

      it('fetches and displays correct labels upon selecting label token', async () => {
        const labelsQueryHandler = isProject ? projectLabelsQueryHandler : groupLabelsQueryHandler;

        createWrapper({ isProject, labelsQueryHandler });

        findToken(TOKEN_TYPE_LABEL).fetchLabels('search');

        await waitForPromises();

        expect(labelsQueryHandler).toHaveBeenCalledWith({
          fullPath: namespaceFullPath,
          search: 'search',
          isProject,
        });
      });
    });

    it('emits `change` event with selected filters upon filtered search bar submission', async () => {
      createWrapper();

      findFilteredSearchBar().vm.$emit('on-filter', mockFilteredSearchFilters);

      await nextTick();

      expect(wrapper.emitted('change')).toEqual([[mockFilteredSearchChangePayload]]);
    });
  });

  describe('initial filter value', () => {
    const initialFilterValue = {
      [TOKEN_TYPE_AUTHOR]: [
        {
          operator: '=',
          value: 'john_smith',
        },
      ],
    };

    beforeEach(() => {
      createWrapper({ props: { initialFilterValue } });
    });

    it('passes initial filter value to filtered search bar', () => {
      expect(findFilteredSearchBar().props('initialFilterValue')).toEqual([
        { type: TOKEN_TYPE_AUTHOR, value: { data: 'john_smith', operator: '=' } },
      ]);
    });
  });

  describe('options', () => {
    it('overrides default tokens in correct order', () => {
      const mockTokenOptions = [
        { token: TOKEN_TYPE_ASSIGNEE, unique: true },
        { token: TOKEN_TYPE_MILESTONE, maxSuggestions: 10 },
      ];

      createWrapper({ props: { options: mockTokenOptions } });

      expect(findFilteredSearchBar().props('tokens')).toEqual([
        expect.objectContaining({ ...mockAssigneeToken, unique: true }),
        expect.objectContaining({ ...mockMilestoneToken, maxSuggestions: 10 }),
      ]);
    });

    it.each`
      operatorEnumValue                     | expectedOperator
      ${FILTERED_SEARCH_OPERATOR_IS}        | ${OPERATORS_IS}
      ${FILTERED_SEARCH_OPERATOR_IS_NOT}    | ${OPERATORS_IS_NOT}
      ${FILTERED_SEARCH_OPERATOR_IS_NOT_OR} | ${OPERATORS_IS_NOT_OR}
      ${undefined}                          | ${undefined}
    `(
      "sets correct operator when token option's operator value is `$operatorEnumValue`",
      ({ operatorEnumValue, expectedOperator }) => {
        const mockTokenOption = { token: TOKEN_TYPE_MILESTONE, operator: operatorEnumValue };

        createWrapper({
          props: { options: [mockTokenOption] },
        });

        expect(findFilteredSearchBar().props('tokens')).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              ...mockMilestoneToken,
              operators: expectedOperator,
            }),
          ]),
        );
      },
    );

    describe.each`
      isProject | expectedTokensLength
      ${true}   | ${allTokenOptions.length}
      ${false}  | ${allTokenOptions.length - projectOnlyTokenOptions.length}
    `('isProject=$isProject', ({ isProject, expectedTokensLength }) => {
      beforeEach(() => {
        createWrapper({
          props: { options: allTokenOptions },
          isProject,
        });
      });

      it('passes correct number of tokens to filtered search bar', () => {
        expect(findFilteredSearchBar().props('tokens')).toHaveLength(expectedTokensLength);
      });
    });

    describe.each`
      branchTokenOption  | branchToken
      ${'source_branch'} | ${mockSourceBranchToken}
      ${'target_branch'} | ${mockTargetBranchToken}
    `('with `$branchTokenOption` token', ({ branchTokenOption, branchToken }) => {
      beforeEach(() => {
        createWrapper({ props: { options: [{ token: branchTokenOption }] }, isProject: true });
      });

      it('passes branch token to filtered search bar', () => {
        expect(findFilteredSearchBar().props('tokens')).toEqual(
          expect.arrayContaining([expect.objectContaining(branchToken)]),
        );
      });

      it('fetches all branches when token selected', async () => {
        findToken(branchToken.type).fetchBranches();

        await waitForPromises();

        expect(repoBranchesQueryHandler).toHaveBeenCalledWith({
          fullPath: namespaceFullPath,
          searchPattern: '*',
        });
      });

      it('searches for branch names that match the search pattern', async () => {
        findToken(branchToken.type).fetchBranches('test');

        await waitForPromises();

        expect(repoBranchesQueryHandler).toHaveBeenCalledWith({
          fullPath: namespaceFullPath,
          searchPattern: '*test*',
        });
      });
    });
  });
});
