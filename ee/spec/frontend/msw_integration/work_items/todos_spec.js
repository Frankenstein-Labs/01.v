import * as testHelpers from 'ee_jest/msw_integration/test_helpers';
import * as workItemsHelpers from 'ee_jest/msw_integration/work_items/test_helpers';
import { snapshotRequests } from 'ee_jest/msw_integration/operation_helpers';
import {
  setupWorkItemsListApollo,
  createWorkItemsListRouter,
  setupWorkItemsDrawerHooks,
  describeNoRefetchOnMutation,
} from './drawer_shared_test_helpers';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

setupWorkItemsListApollo();

describe('Work item to-do toggle integration test', () => {
  const router = createWorkItemsListRouter();

  setupWorkItemsDrawerHooks();

  const markTodoDoneFromDrawer = async () => {
    await workItemsHelpers.selectIssue();

    // The detail query seeds one pending to-do, so the toggle renders in
    // "mark as done" state once the drawer is open.
    await testHelpers.waitForElement(workItemsHelpers.findTodosToggleButton);

    // Snapshot once the drawer detail query has resolved, just before the
    // mark-as-done mutation fires.
    const baseline = snapshotRequests();

    await testHelpers.waitAndClick(workItemsHelpers.findTodosToggleButton);

    // Wait until the mark-as-done mutation has completed, then allow any
    // cache-miss-triggered refetch of the detail query to round-trip before asserting.
    await testHelpers.waitForAssertion(() => {
      expect(snapshotRequests().workItemUpdateCurrentUserTodos).toBe(
        (baseline.workItemUpdateCurrentUserTodos || 0) + 1,
      );
    });
    await new Promise((resolve) => {
      setTimeout(resolve, 0);
    });

    return baseline;
  };

  // Marking the to-do done must update the Apollo cache in place via the
  // workItemUpdateCurrentUserTodos mutation and must NOT trigger a refetch of the
  // namespaceWorkItem detail query. On the features path, a mismatch between the
  // mutation's currentUserTodos selection and the query fragment (e.g. a missing
  // `state: pending` argument) writes to a different cache slot and causes a refetch.
  describeNoRefetchOnMutation({
    router,
    description: 'marks the to-do done without refetching the work item',
    perform: markTodoDoneFromDrawer,
    expectOps: ['workItemUpdateCurrentUserTodos'],
    forbidOps: ['namespaceWorkItem'],
  });
});
