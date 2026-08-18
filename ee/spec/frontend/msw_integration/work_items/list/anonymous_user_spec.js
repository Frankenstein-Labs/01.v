import Vue from 'vue';
import VueApollo from 'vue-apollo';
import workItemMetadataFixture from 'test_fixtures/graphql/work_items/integration/work_item_metadata.query.graphql.json';
import { findIssueToEdit } from 'ee_jest/msw_integration/work_items/test_helpers';
import {
  createGraphQLResolver,
  createNoPermissionsMetadata,
} from 'ee_jest/msw_integration/work_items/resolver_utils';
import { server } from 'ee_jest/msw_integration/server';
import WorkItemsRoot from '~/work_items/components/app.vue';
import { createRouter } from '~/work_items/router';
import { apolloProvider } from '~/graphql_shared/issuable_client';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(false),
}));

Vue.use(VueApollo);

describe('Work items list - anonymous user', () => {
  const router = assignRouter(createRouter, {
    fullPath: 'gitlab-org/gitlab',
    routerPath: 'work_items',
  });

  const noPermissionsMetadata = createNoPermissionsMetadata(workItemMetadataFixture);

  beforeAll(() => {
    createPortalElement();
  });

  beforeEach(async () => {
    delete window.gon.current_user_id;
    await apolloProvider.defaultClient.cache.reset();

    server.use(
      createGraphQLResolver({
        workItemMetadataEE: noPermissionsMetadata,
      }),
    );
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
        isSignedIn: false,
        initialSort: 'created_desc',
        isServiceDeskSupported: false,
      },
    });

    await waitForElement(findIssueToEdit);
  });

  it('renders the list and hides action buttons for anonymous user', () => {
    expect(findIssueToEdit()).not.toBe(null);

    const links = [...document.querySelectorAll('a')];
    expect(links.some((a) => a.textContent.includes('New item'))).toBe(false);
    expect(within(document.body).queryByTestId('bulk-edit-start-button')).toBe(null);
  });
});
