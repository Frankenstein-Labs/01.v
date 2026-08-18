import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { waitFor } from '@testing-library/vue';
import WorkItemsRoot from '~/work_items/components/app.vue';
import { createRouter } from '~/work_items/router';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import { workItemsRestResolver } from 'ee_else_ce/work_items/list/graphql/rest/work_items_rest_resolver';
import { findIssueToEdit } from 'ee_jest/msw_integration/work_items/test_helpers';
import { capturedRequests } from 'ee_jest/msw_integration/operation_helpers';
import { describeDrawerInteractions } from './drawer_shared_test_helpers';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

// issuable_client.js evaluates window.gon.features at import time (before tests run),
// so the REST resolver is not registered automatically. Register it dynamically here.
apolloProvider.defaultClient.addResolvers({
  Namespace: { workItems: workItemsRestResolver },
});

Vue.use(VueApollo);

describe('WorkItem integration test (REST API)', () => {
  const router = assignRouter(createRouter, {
    fullPath: 'gitlab-org/gitlab',
    routerPath: 'work_items',
  });

  const createComponent = () => {
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
        glFeatures: {
          workItemRestApiFrontendUsers: true,
        },
      },
    });
  };

  const mountAndWaitForList = async () => {
    createComponent();
    await waitForElement(findIssueToEdit);
  };

  beforeAll(() => {
    createPortalElement();
  });

  beforeEach(async () => {
    window.gon = { ...window.gon, api_version: 'v4' };
    await apolloProvider.defaultClient.cache.reset();
  });

  it('renders the work item list fetched via the REST API', async () => {
    createComponent();

    await waitFor(() => {
      expect(findIssueToEdit()).not.toBe(null);
    });

    const requests = capturedRequests.getWorkItemsRest;
    expect(requests).toHaveLength(1);
    expect(requests[0].url).toContain('/api/v4/namespaces/gitlab-org%2Fgitlab/-/work_items');
    expect(requests[0].method).toBe('GET');
    expect(requests[0].params.fields).toContain('id');
    expect(requests[0].params.fields).toContain('iid');
    expect(requests[0].params.fields).toContain('global_id');
    expect(requests[0].params.features).toBe(
      'labels,assignees,milestone,start_and_due_date,status,health_status,weight,iteration,hierarchy,linked_items,award_emoji,development',
    );
  });

  describe('with mounted list', () => {
    beforeEach(async () => {
      await mountAndWaitForList();
    });

    describeDrawerInteractions();
  });
});
