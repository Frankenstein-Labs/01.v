import Vue from 'vue';
import VueApollo from 'vue-apollo';
import WorkItemsRoot from '~/work_items/components/app.vue';
import { createRouter } from '~/work_items/router';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import { workItemsFullResponse } from 'ee_jest/msw_integration/work_items/handlers';
import { createGraphQLResolver } from 'ee_jest/msw_integration/work_items/resolver_utils';
import { server } from 'ee_jest/msw_integration/server';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

Vue.use(VueApollo);

describe('Work items list - empty state', () => {
  const router = assignRouter(createRouter, {
    fullPath: 'gitlab-org/gitlab',
    routerPath: 'work_items',
  });

  const namespaceId = workItemsFullResponse.data.namespace.id;
  const emptyWorkItems = {
    data: {
      namespace: {
        ...workItemsFullResponse.data.namespace,
        workItems: {
          ...workItemsFullResponse.data.namespace.workItems,
          nodes: [],
        },
      },
    },
  };

  beforeAll(() => {
    createPortalElement();

    server.use(
      createGraphQLResolver({
        getWorkItemsFullEE: emptyWorkItems,
        getWorkItemsSlimEE: emptyWorkItems,
        hasWorkItems: {
          data: {
            namespace: {
              id: namespaceId,
              workItems: { nodes: [], __typename: 'WorkItemConnection' },
              __typename: 'Namespace',
            },
          },
        },
        getWorkItemsCountOnlyEE: {
          data: { namespace: { id: namespaceId, name: 'group1', workItems: { count: 0 } } },
        },
        EEgetWorkItemStateCounts: {
          data: {
            project: {
              id: namespaceId,
              workItemStateCounts: {
                all: 0,
                closed: 0,
                opened: 0,
                __typename: 'WorkItemStateCountsType',
              },
              __typename: 'Project',
            },
          },
        },
        getUser: {
          data: {
            currentUser: {
              id: 'gid://gitlab/User/1',
              __typename: 'UserCore',
            },
          },
        },
      }),
    );
  });

  beforeEach(async () => {
    await apolloProvider.defaultClient.cache.reset();
  });

  it('shows empty state message when there are no work items', async () => {
    fullMount(WorkItemsRoot, {
      router,
      propsData: {
        rootPageFullPath: 'gitlab-org/gitlab',
      },
      apolloProvider,
      provide: {
        isGroup: false,
        isGroupIssuesList: false,
        fullPath: 'gitlab-org/gitlab',
        groupPath: 'gitlab-org',
        workItemType: 'Issue',
        isSignedIn: true,
        initialSort: 'created_desc',
        isServiceDeskSupported: false,
      },
    });

    await waitForAssertion(() => {
      expect(getText(document.body)).toContain('Track bugs, plan features');
    });
  });
});
