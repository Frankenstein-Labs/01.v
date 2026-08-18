// This is a shared helper module (not a test file): it intentionally exports
// reusable setup functions and `describe`-block factories that take a dynamic
// `it` title from the calling spec.
/* eslint-disable jest/no-export, jest/valid-title */
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import WorkItemsRoot from '~/work_items/components/app.vue';
import { createRouter } from '~/work_items/router';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import { workItemsRestResolver } from 'ee_else_ce/work_items/list/graphql/rest/work_items_rest_resolver';
import { isLoggedIn } from '~/lib/utils/common_utils';
import {
  assignRouter,
  fullMount,
  waitForElement,
  waitForAssertion,
} from 'ee_jest/msw_integration/test_helpers';
import * as testHelpers from 'ee_jest/msw_integration/test_helpers';
import * as workItemsHelpers from 'ee_jest/msw_integration/work_items/test_helpers';
import { expectGraphQLCalls, snapshotRequests } from 'ee_jest/msw_integration/operation_helpers';

// glFeatures shared by every work item list integration spec. Individual specs
// merge in the flags they exercise (e.g. workItemFeaturesField).
const BASE_GL_FEATURES = {
  workItemRestApiFrontendUsers: true,
};

/**
 * Registers the REST resolver on the shared Apollo client and installs VueApollo.
 *
 * issuable_client.js evaluates window.gon.features at import time (before tests
 * run), so the REST resolver is not registered automatically. Call this once at
 * the top of a spec module.
 */
export function setupWorkItemsListApollo() {
  apolloProvider.defaultClient.addResolvers({
    Namespace: { workItems: workItemsRestResolver },
  });
  Vue.use(VueApollo);
}

/**
 * Builds the work items router. Call this in the describe body (not a hook) so the
 * router is registered at the same time as the existing per-spec convention.
 */
export const createWorkItemsListRouter = () =>
  assignRouter(createRouter, {
    fullPath: 'gitlab-org/gitlab',
    routerPath: 'work_items',
  });

/**
 * Mounts the work items list app (which hosts the work item drawer) with the
 * standard provide/inject configuration used across the drawer integration specs.
 */
export function mountWorkItemsListApp({ router, glFeatures = {} } = {}) {
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
      glFeatures: { ...BASE_GL_FEATURES, ...glFeatures },
    },
  });
}

/**
 * Registers the beforeAll/beforeEach hooks shared by the drawer integration specs:
 * creates the drawer portal, resets gon/isLoggedIn, and resets the Apollo cache.
 */
export function setupWorkItemsDrawerHooks() {
  beforeAll(() => {
    workItemsHelpers.createPortalElement();
  });

  beforeEach(async () => {
    window.gon = { ...window.gon, api_version: 'v4' };
    isLoggedIn.mockReturnValue(true);
    await apolloProvider.defaultClient.cache.reset();
  });
}

/**
 * Runs a drawer mutation interaction under both workItemFeaturesField flag states
 * and asserts it updates the Apollo cache in place without refetching forbidden
 * queries (the most common cache-miss regression).
 *
 * @param {Object} options
 * @param {Object} options.router - Router from createWorkItemsListRouter().
 * @param {string} options.description - The `it` description.
 * @param {Function} options.perform - async () => baselineSnapshot. Performs the
 *   interaction and returns the snapshotRequests() baseline captured just before
 *   the mutation fires.
 * @param {Array<string>} options.expectOps - Operations that MUST fire.
 * @param {Array<string|RegExp>} options.forbidOps - Operations that must NOT fire.
 */
export function describeNoRefetchOnMutation({
  router,
  description,
  perform,
  expectOps,
  forbidOps,
}) {
  describe.each([false, true])(
    'when the workItemFeaturesField flag is %s',
    (workItemFeaturesField) => {
      beforeEach(async () => {
        // Keep gon and the provided glFeatures in sync so both the query/mutation
        // variables (from glFeatures) and cache_utils (which reads window.gon.features)
        // resolve to the same workItem.features cache variant.
        window.gon.features = { ...window.gon.features, workItemFeaturesField };
        mountWorkItemsListApp({ router, glFeatures: { workItemFeaturesField } });
        await waitForElement(workItemsHelpers.findIssueToEdit);
      });

      it(description, async () => {
        const baseline = await perform();

        await waitForAssertion(() => {
          expectGraphQLCalls(baseline, { expect: expectOps, forbid: forbidOps });
        });
      });
    },
  );
}

/**
 * Full work item list refetches.
 *
 * These are the most important operations to guard against: a mutation on a
 * single work item must NOT trigger a re-fetch of the entire list. The cache
 * should be updated in place instead.
 */
const FORBIDDEN_LIST_REFETCHES = [
  'getWorkItemsFullEE',
  'getWorkItemsFull',
  'getWorkItemsSlimEE',
  'getWorkItemsSlim',
];

export function describeDrawerInteractions() {
  describe('when navigating to a work item', () => {
    beforeEach(async () => {
      await workItemsHelpers.selectIssue();
    });

    it('opens the work item detail in the drawer', async () => {
      await testHelpers.waitForElement(workItemsHelpers.findWorkItemDetail);
    });
  });

  describe('when clicking the same issue again', () => {
    beforeEach(async () => {
      await workItemsHelpers.selectIssue();
      workItemsHelpers.clickIssue();
    });

    it('closes the drawer', async () => {
      await testHelpers.waitForElementToBeNull(workItemsHelpers.findWorkItemDetail);
    });
  });

  describe('when user adds a comment from the drawer', () => {
    // NOTE: A cache-integrity assertion (creating a comment must not refetch the
    // work item list) is intentionally omitted here because it currently fails
    // under Vue 3 - creating a comment refetches the list via cache.modify on
    // userDiscussionsCount. Tracked in:
    // https://gitlab.com/gitlab-org/gitlab/-/work_items/603641
    // Once fixed, re-add the `expectGraphQLCalls` assertion (see the issue).
    it('updates comment count', async () => {
      await workItemsHelpers.selectIssue();

      const findTextarea = () =>
        document.getElementById('contextual-panel-portal')?.querySelector('textarea');
      await testHelpers.waitForElement(findTextarea);
      await testHelpers.waitAndSetValue(findTextarea, 'Test comment from drawer');

      await testHelpers.waitAndClick(workItemsHelpers.findConfirmButton);

      await testHelpers.waitForAssertion(() => {
        expect(testHelpers.getText(workItemsHelpers.findIssuableComments())).toContain('1');
      });
    });
  });

  describe('with selected issue', () => {
    beforeEach(async () => {
      await workItemsHelpers.selectIssue();
    });

    describe('when title is edited in the drawer', () => {
      const newTitle = 'New title';

      it('updates work item title in the list', async () => {
        await testHelpers.waitAndClick(workItemsHelpers.findEditFormButton);
        await testHelpers.waitAndSetValue(workItemsHelpers.findTitleInput, newTitle);

        workItemsHelpers
          .findDescriptionWrapper()
          .querySelector('form')
          .dispatchEvent(new Event('submit', { bubbles: true }));

        await testHelpers.waitForAssertion(() => {
          expect(testHelpers.getText(workItemsHelpers.findWorkItemTitle())).toBe(newTitle);
          expect(testHelpers.getText(workItemsHelpers.findIssuableTitleLink())).toBe(newTitle);
        });
      });
    });

    describe('when assignee is changed in the drawer', () => {
      it('updates assignee in the list without refetching', async () => {
        await workItemsHelpers.startEditing(workItemsHelpers.findAssigneesWidget);

        await testHelpers.waitAndClick(workItemsHelpers.findUserListboxItem);
        await testHelpers.waitForAssertion(() => {
          expect(workItemsHelpers.findUserListboxItem().getAttribute('aria-selected')).toBe('true');
        });

        const baseline = snapshotRequests();

        workItemsHelpers.closeListbox(workItemsHelpers.findAssigneesWidget);

        await testHelpers.waitForAssertion(() => {
          expect(testHelpers.getText(workItemsHelpers.findAssigneesWidget())).toContain(
            workItemsHelpers.firstUser.name,
          );
          expect(workItemsHelpers.findAssigneeLink().getAttribute('href')).toBe(
            workItemsHelpers.firstUser.webPath,
          );

          // Updating the assignee must update the cache in place and NOT trigger
          // a refetch of the whole work item list.
          expectGraphQLCalls(baseline, {
            expect: ['workItemUpdate'],
            forbid: FORBIDDEN_LIST_REFETCHES,
          });
        });
      });
    });

    describe('when a label is added in the drawer', () => {
      it('updates labels in the list', async () => {
        await workItemsHelpers.startEditing(workItemsHelpers.findLabelsWidget);

        await testHelpers.waitAndClick(workItemsHelpers.findLabelListboxItem);
        await testHelpers.waitForAssertion(() => {
          expect(workItemsHelpers.findLabelListboxItem().getAttribute('aria-selected')).toBe(
            'true',
          );
        });

        workItemsHelpers.closeListbox(workItemsHelpers.findLabelsWidget);

        await testHelpers.waitForAssertion(() => {
          expect(testHelpers.getText(workItemsHelpers.findLabelsWidget())).toContain(
            workItemsHelpers.firstLabel.title,
          );
          expect(testHelpers.getText(workItemsHelpers.findIssueToEdit())).toContain(
            workItemsHelpers.firstLabel.title,
          );
        });
      });
    });

    describe('when confidentiality is toggled in the drawer', () => {
      beforeEach(async () => {
        const actionsButton = await testHelpers.waitForElement(
          workItemsHelpers.findActionsDropdown,
        );
        actionsButton.click();
        const confidentialityAction = await testHelpers.waitForElement(
          workItemsHelpers.findConfidentialityAction,
        );
        confidentialityAction.querySelector('button').click();
      });

      it('shows the confidential icon on the list', async () => {
        await testHelpers.waitForElement(workItemsHelpers.findConfidentialIcon);
      });
    });

    describe('when milestone is changed in the drawer', () => {
      beforeEach(async () => {
        await workItemsHelpers.startEditing(workItemsHelpers.findMilestoneWidget);
        await testHelpers.waitAndClick(workItemsHelpers.findMilestoneListboxItem);
      });

      it('updates milestone in the list', async () => {
        await testHelpers.waitForAssertion(() => {
          expect(testHelpers.getText(workItemsHelpers.findMilestoneWidget())).toContain(
            workItemsHelpers.firstMilestone.title,
          );
          expect(testHelpers.getText(workItemsHelpers.findIssueToEdit())).toContain(
            workItemsHelpers.firstMilestone.title,
          );
        });
      });
    });

    describe('when notifications subscription is toggled', () => {
      beforeEach(async () => {
        await testHelpers.waitForElement(workItemsHelpers.findSubscribeButton);
      });

      it('toggles subscription off and back on', async () => {
        await testHelpers.waitForAssertion(() => {
          expect(workItemsHelpers.findSubscribeButton().dataset.subscribed).toBe('true');
        });

        await testHelpers.waitAndClick(workItemsHelpers.findSubscribeButton);

        await testHelpers.waitForAssertion(() => {
          expect(workItemsHelpers.findSubscribeButton().dataset.subscribed).toBe('false');
        });

        await testHelpers.waitAndClick(workItemsHelpers.findSubscribeButton);

        await testHelpers.waitForAssertion(() => {
          expect(workItemsHelpers.findSubscribeButton().dataset.subscribed).toBe('true');
        });
      });
    });

    describe('when dates are changed in the drawer', () => {
      it('updates start and due date on the list', async () => {
        const portalEl = document.getElementById('contextual-panel-portal');

        const datesWidget = await testHelpers.waitForElement(workItemsHelpers.findDatesWidget);
        testHelpers.within(datesWidget).queryByTestId('edit-button').click();

        const findStartInput = () => portalEl.querySelector('#start-date-input');
        const findDueInput = () => portalEl.querySelector('#due-date-input');

        await testHelpers.waitAndSetValue(findStartInput, '2025-01-01', 'change');
        await testHelpers.waitAndSetValue(findDueInput, '2025-12-31', 'change');

        await testHelpers.waitAndClick(workItemsHelpers.findApplyButton);

        await testHelpers.waitForAssertion(() => {
          expect(testHelpers.getText(workItemsHelpers.findStartDateValue())).not.toBe('None');
          expect(testHelpers.getText(workItemsHelpers.findDueDateValue())).not.toBe('None');
          expect(workItemsHelpers.findIssuableDueDate()).not.toBe(null);
        });
      });
    });
  });
}
