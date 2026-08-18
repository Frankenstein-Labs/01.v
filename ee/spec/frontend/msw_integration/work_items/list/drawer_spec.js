import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { waitFor } from '@testing-library/vue';
import {
  findIssueToEdit,
  createPortalElement,
} from 'ee_jest/msw_integration/work_items/test_helpers';
import { waitForElement } from 'ee_jest/msw_integration/test_helpers';
import { capturedRequests } from 'ee_jest/msw_integration/operation_helpers';
import WorkItemsRoot from '~/work_items/components/app.vue';
import { createRouter } from '~/work_items/router';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import { describeDrawerInteractions } from '../drawer_shared_test_helpers';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

Vue.use(VueApollo);

describe('WorkItem integration test', () => {
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
    await apolloProvider.defaultClient.cache.reset();
  });

  it('renders the work item issues list', async () => {
    createComponent();

    await waitFor(() => {
      expect(findIssueToEdit()).not.toBe(null);
    });
  });

  it('does not call REST endpoint', async () => {
    createComponent();

    await waitFor(() => {
      expect(findIssueToEdit()).not.toBe(null);
    });

    const restRequests = capturedRequests.getWorkItemsRest;
    expect(restRequests).toBeUndefined();
  });

  describe('with mounted list', () => {
    beforeEach(async () => {
      await mountAndWaitForList();
    });

    describeDrawerInteractions();
  });
});
