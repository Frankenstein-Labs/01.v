import { GlAlert } from '@gitlab/ui';
import { shallowMount, mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import ExternalIssuesListRoot from 'ee/external_issues_list/components/external_issues_list_root.vue';
import jiraIssuesResolver from 'ee/integrations/jira/issues_list/graphql/resolvers/jira_issues';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import {
  FILTERED_SEARCH_TERM,
  TOKEN_TYPE_LABEL,
} from '~/vue_shared/components/filtered_search_bar/constants';
import IssuableList from '~/vue_shared/issuable/list/components/issuable_list_root.vue';
import { i18n } from '~/work_items/list/constants';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';

import {
  mockProvide,
  mockJiraIssues as mockExternalIssues,
  mockJiraIssue4 as mockJiraIssueNoReference,
} from '../mock_data';

jest.mock('~/alert');
jest.mock('~/vue_shared/issuable/list/constants', () => ({
  DEFAULT_PAGE_SIZE: 2,
  issuableListTabs: jest.requireActual('~/vue_shared/issuable/list/constants').issuableListTabs,
  availableSortOptions: jest.requireActual('~/vue_shared/issuable/list/constants')
    .availableSortOptions,
}));
jest.mock(
  '~/vue_shared/components/filtered_search_bar/tokens/label_token.vue',
  () => 'LabelTokenMock',
);

const resolvers = {
  Query: {
    externalIssues: jiraIssuesResolver,
  },
};

function createMockApolloProvider(mockResolvers = resolvers) {
  Vue.use(VueApollo);
  return createMockApollo([], mockResolvers);
}

describe('ExternalIssuesListRoot', () => {
  let wrapper;
  let mock;

  const mockProject = 'ES';
  const mockStatus = 'To Do';
  const mockAuthor = 'Author User';
  const mockAssignee = 'Assignee User';
  const mockLabel = 'ecosystem';
  const mockSearchTerm = 'test issue';

  const findIssuableList = () => wrapper.findComponent(IssuableList);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const createLabelFilterEvent = (data) => ({ type: TOKEN_TYPE_LABEL, value: { data } });
  const createSearchFilterEvent = (data) => ({ type: FILTERED_SEARCH_TERM, value: { data } });

  const expectErrorHandling = (expectedRenderedErrorMessage) => {
    const issuesList = findIssuableList();
    const alert = findAlert();

    expect(issuesList.exists()).toBe(false);
    expect(alert.exists()).toBe(true);
    expect(alert.text()).toBe(expectedRenderedErrorMessage);
    expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
  };

  const createComponent = ({
    mountFn = shallowMount,
    apolloProvider = createMockApolloProvider(),
    provide = mockProvide,
    initialFilterParams = {},
  } = {}) => {
    wrapper = mountFn(ExternalIssuesListRoot, {
      propsData: {
        initialFilterParams,
      },
      provide,
      apolloProvider,
    });
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe.each`
    deployment  | responseHeaders                                                                 | expectedBaseParams
    ${'cloud'}  | ${{ 'x-per-page': '2', 'x-next-page-token': 'token123', 'x-is-last': 'false' }} | ${{ with_labels_details: true, per_page: 2, sort: 'created_desc', state: 'opened', project: undefined, status: undefined, author_username: undefined, assignee_username: undefined, labels: undefined, search: undefined }}
    ${'server'} | ${{ 'x-page': 1, 'x-total': mockExternalIssues.length }}                        | ${{ with_labels_details: true, per_page: 2, page: 1, sort: 'created_desc', state: 'opened', project: undefined, status: undefined, author_username: undefined, assignee_username: undefined, labels: undefined, search: undefined }}
  `('with $deployment pagination', ({ deployment, responseHeaders, expectedBaseParams }) => {
    const isJiraCloud = deployment === 'cloud';

    const resolvedValue = {
      headers: responseHeaders,
      data: mockExternalIssues,
    };

    const provideWithDeployment = {
      ...mockProvide,
      deployment,
    };

    describe('while loading', () => {
      it('sets issuesListLoading to `true`', async () => {
        jest.spyOn(axios, 'get').mockResolvedValue(new Promise(() => {}));

        createComponent({ provide: provideWithDeployment });
        await nextTick();

        const issuableList = findIssuableList();
        expect(issuableList.props('issuablesLoading')).toBe(true);
      });

      it('calls `axios.get` with `issuesFetchPath` and query params', async () => {
        jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

        createComponent({ provide: provideWithDeployment });
        await waitForPromises();

        expect(axios.get).toHaveBeenCalledWith(
          mockProvide.issuesFetchPath,
          expect.objectContaining({
            params: expectedBaseParams,
          }),
        );
      });
    });

    describe('with `initialFilterParams` prop', () => {
      beforeEach(async () => {
        jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

        createComponent({
          provide: provideWithDeployment,
          initialFilterParams: {
            project: mockProject,
            status: mockStatus,
            authorUsername: mockAuthor,
            assigneeUsername: mockAssignee,
            labels: [mockLabel],
            search: mockSearchTerm,
          },
        });
        await waitForPromises();
      });

      it('calls `axios.get` with `issuesFetchPath` and query params', () => {
        expect(axios.get).toHaveBeenCalledWith(
          mockProvide.issuesFetchPath,
          expect.objectContaining({
            params: {
              ...expectedBaseParams,
              project: mockProject,
              status: mockStatus,
              author_username: mockAuthor,
              assignee_username: mockAssignee,
              labels: [mockLabel],
              search: mockSearchTerm,
            },
          }),
        );
      });

      it('renders issuable-list component with correct props', () => {
        const issuableList = findIssuableList();

        expect(issuableList.props('initialFilterValue')).toEqual([
          { type: TOKEN_TYPE_LABEL, value: { data: mockLabel } },
          { type: FILTERED_SEARCH_TERM, value: { data: mockSearchTerm } },
        ]);
        expect(issuableList.props('urlParams').project).toBe(mockProject);
        expect(issuableList.props('urlParams').status).toBe(mockStatus);
        expect(issuableList.props('urlParams').author_username).toBe(mockAuthor);
        expect(issuableList.props('urlParams').assignee_username).toBe(mockAssignee);
        expect(issuableList.props('urlParams')['labels[]']).toEqual([mockLabel]);
        expect(issuableList.props('urlParams').search).toBe(mockSearchTerm);
      });

      describe('issuable-list events', () => {
        it.each`
          desc             | input                                 | expected
          ${'with label'}  | ${[createLabelFilterEvent('label2')]} | ${{ labels: ['label2'] }}
          ${'with search'} | ${[createSearchFilterEvent('foo')]}   | ${{ search: 'foo' }}
        `(
          '$desc, filter event sets "filterParams" value and calls fetchIssues',
          async ({ input, expected }) => {
            const issuableList = findIssuableList();
            jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

            issuableList.vm.$emit('filter', input);
            await waitForPromises();

            const expectedParams = {
              ...expectedBaseParams,
              project: mockProject,
              status: mockStatus,
              author_username: mockAuthor,
              assignee_username: mockAssignee,
              ...expected,
            };

            // Reset pagination on filter
            if (!isJiraCloud) {
              expectedParams.page = 1;
            }

            expect(axios.get).toHaveBeenLastCalledWith(mockProvide.issuesFetchPath, {
              params: expectedParams,
            });
          },
        );
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

        createComponent({ provide: provideWithDeployment });
        await waitForPromises();
      });

      it('renders issuable-list component with correct props', () => {
        const issuableList = findIssuableList();
        expect(issuableList.exists()).toBe(true);

        if (isJiraCloud) {
          expect(issuableList.props()).toMatchObject({
            useKeysetPagination: true,
            hasNextPage: true,
            hasPreviousPage: false,
            totalItems: 0,
          });
        } else {
          expect(issuableList.props()).toMatchObject({
            currentPage: 1,
            previousPage: 0,
            nextPage: 2,
            totalItems: mockExternalIssues.length,
            useKeysetPagination: false,
            hasNextPage: true,
            hasPreviousPage: false,
          });
        }
      });

      describe('issuable-list reference section', () => {
        it('renders issuable-list component with correct reference', async () => {
          jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

          createComponent({ provide: provideWithDeployment, mountFn: mount });
          await waitForPromises();

          expect(wrapper.find('.issuable-info').text()).toContain(
            resolvedValue.data[0].references.relative,
          );
        });

        it('renders issuable-list component with id when references is not present', async () => {
          jest.spyOn(axios, 'get').mockResolvedValue({
            ...resolvedValue,
            data: [mockJiraIssueNoReference],
          });

          createComponent({ provide: provideWithDeployment, mountFn: mount });
          await waitForPromises();

          // Since Jira transformer transforms references.relative into id, we can only test
          // whether it exists.
          expect(wrapper.find('.issuable-info').exists()).toBe(false);
        });
      });

      describe('issuable-list events', () => {
        it('"click-tab" event executes GET request correctly', async () => {
          const issuableList = findIssuableList();
          jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

          issuableList.vm.$emit('click-tab', 'closed');
          await waitForPromises();

          const expectedParams = {
            ...expectedBaseParams,
            state: 'closed',
          };

          expect(axios.get).toHaveBeenLastCalledWith(mockProvide.issuesFetchPath, {
            params: expectedParams,
          });
          expect(issuableList.props('currentTab')).toBe('closed');
        });

        it('"sort" event executes GET request correctly', async () => {
          const mockSortBy = 'updated_asc';
          const issuableList = findIssuableList();
          jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

          issuableList.vm.$emit('sort', mockSortBy);
          await waitForPromises();

          const expectedParams = {
            ...expectedBaseParams,
            sort: 'updated_asc',
          };

          expect(axios.get).toHaveBeenLastCalledWith(mockProvide.issuesFetchPath, {
            params: expectedParams,
          });
          expect(issuableList.props('initialSortBy')).toBe(mockSortBy);
        });

        it.each`
          desc                        | input                                                                           | expected
          ${'with label and search'}  | ${[createLabelFilterEvent(mockLabel), createSearchFilterEvent(mockSearchTerm)]} | ${{ labels: [mockLabel], search: mockSearchTerm }}
          ${'with multiple lables'}   | ${[createLabelFilterEvent('label1'), createLabelFilterEvent('label2')]}         | ${{ labels: ['label1', 'label2'], search: undefined }}
          ${'with multiple searches'} | ${[createSearchFilterEvent('foo bar'), createSearchFilterEvent('lorem')]}       | ${{ labels: undefined, search: 'foo bar lorem' }}
        `(
          '$desc, filter event sets "filterParams" value and calls fetchIssues',
          async ({ input, expected }) => {
            const issuableList = findIssuableList();
            jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

            issuableList.vm.$emit('filter', input);
            await waitForPromises();

            const expectedParams = {
              ...expectedBaseParams,
              ...expected,
            };

            // Reset pagination on filter
            if (!isJiraCloud) {
              expectedParams.page = 1;
            }

            expect(axios.get).toHaveBeenLastCalledWith(mockProvide.issuesFetchPath, {
              params: expectedParams,
            });
          },
        );
      });
    });

    describe('pagination', () => {
      beforeEach(() => {
        mock.reset();
      });

      it.each`
        scenario                              | issues                            | totalIssues | currentPageNum | hasNextPage | hasPreviousPage | shouldShowPaginationControls
        ${'returns no issues'}                | ${[]}                             | ${0}        | ${1}           | ${false}    | ${false}        | ${false}
        ${'returns issues on one page'}       | ${mockExternalIssues.slice(0, 2)} | ${2}        | ${1}           | ${false}    | ${false}        | ${false}
        ${'returns issues on multiple pages'} | ${mockExternalIssues}             | ${3}        | ${1}           | ${true}     | ${false}        | ${true}
        ${'has previous page'}                | ${mockExternalIssues}             | ${6}        | ${2}           | ${true}     | ${true}         | ${true}
      `(
        'sets `showPaginationControls` prop to $shouldShowPaginationControls when request $scenario',
        async ({
          issues,
          totalIssues,
          currentPageNum,
          hasNextPage,
          hasPreviousPage,
          shouldShowPaginationControls,
        }) => {
          jest.spyOn(axios, 'get');

          const headers = isJiraCloud
            ? {
                'x-per-page': '2',
                'x-next-page-token': hasNextPage ? 'token123' : null,
                'x-is-last': !hasNextPage ? 'true' : 'false',
              }
            : {
                'x-page': currentPageNum.toString(),
                'x-total': totalIssues,
              };

          mock.onGet(mockProvide.issuesFetchPath).replyOnce(HTTP_STATUS_OK, issues, headers);

          const provideOverride = isJiraCloud
            ? provideWithDeployment
            : { ...provideWithDeployment, page: currentPageNum };

          createComponent({ provide: provideOverride });

          if (hasPreviousPage && isJiraCloud) {
            wrapper.vm.pageTokenHistory = ['token123'];
          }

          await waitForPromises();

          expect(findIssuableList().props('showPaginationControls')).toBe(
            shouldShowPaginationControls,
          );
          expect(findIssuableList().props('useKeysetPagination')).toBe(isJiraCloud);
          expect(findIssuableList().props('hasNextPage')).toBe(hasNextPage);
          expect(findIssuableList().props('hasPreviousPage')).toBe(hasPreviousPage);
        },
      );
    });
  });

  // Jira Cloud specific tests
  describe('Jira Cloud keyset pagination', () => {
    const provideWithDeployment = {
      ...mockProvide,
      deployment: 'cloud',
    };

    const resolvedValue = {
      headers: {
        'x-per-page': '2',
        'x-next-page-token': 'token123',
        'x-is-last': 'false',
      },
      data: mockExternalIssues,
    };

    beforeEach(async () => {
      jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);
      createComponent({ provide: provideWithDeployment });
      await waitForPromises();
    });

    it('"next-page" event executes GET request correctly', async () => {
      const issuableList = findIssuableList();
      jest.spyOn(axios, 'get').mockResolvedValue({
        ...resolvedValue,
        headers: {
          'x-per-page': '2',
          'x-next-page-token': 'token456',
          'x-is-last': 'true',
        },
      });

      issuableList.vm.$emit('next-page');
      await waitForPromises();

      expect(axios.get).toHaveBeenLastCalledWith(mockProvide.issuesFetchPath, {
        params: expect.objectContaining({
          next_page_token: 'token123',
        }),
      });

      await nextTick();
      expect(issuableList.props()).toMatchObject({
        useKeysetPagination: true,
        hasNextPage: false,
        hasPreviousPage: true,
      });
    });

    it('"previous-page" event executes GET request correctly', async () => {
      const issuableList = findIssuableList();
      jest.spyOn(axios, 'get').mockResolvedValue({
        ...resolvedValue,
        headers: {
          'x-per-page': '2',
          'x-next-page-token': null,
          'x-is-last': 'false',
        },
      });

      // Simulate being on a later page first
      wrapper.vm.pageTokenHistory = ['token123'];
      wrapper.vm.nextPageToken = 'token456';

      issuableList.vm.$emit('previous-page');
      await waitForPromises();

      expect(axios.get).toHaveBeenLastCalledWith(mockProvide.issuesFetchPath, {
        params: expect.objectContaining({
          next_page_token: 'token123',
        }),
      });

      await nextTick();
      expect(issuableList.props()).toMatchObject({
        useKeysetPagination: true,
        hasNextPage: true,
        hasPreviousPage: false,
      });
    });
  });

  // Jira Server specific tests
  describe('Jira Server offset pagination', () => {
    const provideWithDeployment = {
      ...mockProvide,
      deployment: 'server',
    };

    const resolvedValue = {
      headers: {
        'x-page': 1,
        'x-total': mockExternalIssues.length,
      },
      data: mockExternalIssues,
    };

    beforeEach(async () => {
      jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);
      createComponent({ provide: provideWithDeployment });
      await waitForPromises();
    });

    it('"page-change" event executes GET request correctly', async () => {
      const mockPage = 2;
      const issuableList = findIssuableList();
      jest.spyOn(axios, 'get').mockResolvedValue({
        ...resolvedValue,
        headers: { 'x-page': mockPage, 'x-total': mockExternalIssues.length },
      });

      issuableList.vm.$emit('page-change', mockPage);
      await waitForPromises();

      expect(axios.get).toHaveBeenCalledWith(mockProvide.issuesFetchPath, {
        params: expect.objectContaining({
          page: mockPage,
        }),
      });

      await nextTick();
      expect(issuableList.props()).toMatchObject({
        currentPage: mockPage,
        previousPage: mockPage - 1,
        nextPage: mockPage + 1,
      });
    });
  });

  // Shared error handling tests
  describe('error handling', () => {
    beforeEach(() => {
      jest.spyOn(Sentry, 'captureException');
    });

    describe('when request fails', () => {
      it.each`
        APIErrors                                         | expectedRenderedErrorText
        ${['API error']}                                  | ${'API error'}
        ${['API <a href="gitlab.com">error</a>']}         | ${'API error'}
        ${['API <script src="hax0r.xyz">error</script>']} | ${'API'}
        ${undefined}                                      | ${i18n.errorFetchingIssues}
      `(
        'displays error alert with "$expectedRenderedErrorText" when API responds with "$APIErrors"',
        async ({ APIErrors, expectedRenderedErrorText }) => {
          jest.spyOn(axios, 'get');
          mock
            .onGet(mockProvide.issuesFetchPath)
            .replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR, { errors: APIErrors });

          createComponent();
          await waitForPromises();

          expectErrorHandling(expectedRenderedErrorText);
        },
      );
    });

    describe('when GraphQL network error is encountered', () => {
      it('displays error alert with default error message', async () => {
        createComponent({
          apolloProvider: createMockApolloProvider({
            Query: {
              externalIssues: jest.fn().mockRejectedValue(new Error('GraphQL networkError')),
            },
          }),
        });
        await waitForPromises();

        expectErrorHandling(i18n.errorFetchingIssues);
      });
    });
  });
});
