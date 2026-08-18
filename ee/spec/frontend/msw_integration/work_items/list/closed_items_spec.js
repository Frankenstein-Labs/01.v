import Vue from 'vue';
import VueApollo from 'vue-apollo';
import closedWorkItemsFixture from 'test_fixtures/graphql/work_items/integration/get_work_items_full_closed.query.graphql.json';
import WorkItemsRoot from '~/work_items/components/app.vue';
import { createRouter } from '~/work_items/router';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import { createGraphQLResolver } from 'ee_jest/msw_integration/work_items/resolver_utils';
import { server } from 'ee_jest/msw_integration/server';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

Vue.use(VueApollo);

describe('Work items list - closed items view', () => {
  const router = assignRouter(createRouter, {
    fullPath: 'gitlab-org/gitlab',
    routerPath: 'work_items',
  });

  beforeAll(() => {
    createPortalElement();

    const closedResponse = { data: closedWorkItemsFixture.data };

    server.use(
      createGraphQLResolver({
        getWorkItemsFullEE: closedResponse,
        getWorkItemsSlimEE: closedResponse,
      }),
    );
  });

  beforeEach(async () => {
    await apolloProvider.defaultClient.cache.reset();
  });

  it('shows closed items and does not show open items', async () => {
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
      const listText = getText(document.querySelector('.issuable-list'));
      expect(listText).toContain('Closed test issue');
      expect(listText).not.toContain('Dependent test issue');
      expect(listText).not.toContain('Second test issue');
    });
  });
});
