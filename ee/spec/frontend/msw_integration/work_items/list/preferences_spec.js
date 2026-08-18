import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import WorkItemsRoot from '~/work_items/components/app.vue';
import { createRouter } from '~/work_items/router';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import {
  baseUpdateResponse,
  workItemsFullResponse,
} from 'ee_jest/msw_integration/work_items/handlers';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

const workItemId = baseUpdateResponse.data.workItemUpdate.workItem.id;
const listNodes = workItemsFullResponse.data.namespace.workItems.nodes;
const secondWorkItemId = listNodes.find((n) => n.title === 'Second test issue')?.id;
const childTaskId = listNodes.find((n) => n.title === 'Child task')?.id;

Vue.use(VueApollo);

describe('Work items list - display preferences', () => {
  const router = assignRouter(createRouter, {
    fullPath: 'gitlab-org/gitlab',
    routerPath: 'work_items',
  });

  const findIssueCard = () => findByGraphQLId(workItemId, getIdFromGraphQLId);
  const findAssigneeLink = () => within(findIssueCard()).queryByTestId('assignee-link');
  const findMilestone = () => within(findIssueCard()).queryByTestId('issuable-milestone');
  const findStatusBadge = () => within(findIssueCard()).queryByTestId('work-item-status-badge');
  const findWeight = () => within(findIssueCard()).queryByTestId('issuable-weight-content');
  const findDates = () => within(findIssueCard()).queryByTestId('issuable-due-date');
  const findIteration = () => within(findIssueCard()).queryByTestId('iteration-attribute');
  const findHealthStatus = () => within(findIssueCard()).queryByTestId('status-text');

  const findSecondIssueCard = () => findByGraphQLId(secondWorkItemId, getIdFromGraphQLId);
  const findLabels = () => findSecondIssueCard()?.querySelector('.gl-label');
  const findBlockedIcon = () =>
    within(findSecondIssueCard()).queryByTestId('relationship-blocked-by-icon');
  const findUpvotes = () => within(findSecondIssueCard()).queryByTestId('issuable-upvotes');
  const findComments = () => within(findSecondIssueCard()).queryByTestId('issuable-comments');

  const findChildTaskCard = () => findByGraphQLId(childTaskId, getIdFromGraphQLId);
  const findParentMetadata = () =>
    within(findChildTaskCard()).queryByTestId('work-item-parent-metadata-link');

  const findWorkItemDrawer = () => findInDrawer('work-item-detail');
  const findDisplayOptionsButton = () => findButtonByText('Display');

  const toggleDisplayOption = async (optionText) => {
    await waitAndClick(findDisplayOptionsButton);

    let item;
    await waitForAssertion(() => {
      item = [...document.querySelectorAll('.work-item-dropdown-toggle')].find((el) =>
        el.textContent.includes(optionText),
      );
      expect(item).toBeDefined();
    });

    item.querySelector('button').click();

    await waitAndClick(findDisplayOptionsButton);
  };

  const createComponent = () => {
    fullMount(WorkItemsRoot, {
      router,
      propsData: {
        rootPageFullPath: 'gitlab-org/gitlab',
      },
      apolloProvider,
      provide: {
        isGroup: false,
        isProject: true,
        isGroupIssuesList: false,
        fullPath: 'gitlab-org/gitlab',
        groupPath: 'gitlab-org',
        workItemType: 'Issue',
        isSignedIn: true,
        initialSort: 'created_desc',
        isServiceDeskSupported: false,
        workItemsSavedViewsEnabled: false,
        glFeatures: {
          workItemViewForIssues: true,
        },
      },
    });
  };

  const mountAndWaitForList = async () => {
    createComponent();
    await waitForElement(findIssueCard);
  };

  beforeAll(() => {
    createPortalElement();
  });

  beforeEach(async () => {
    await apolloProvider.defaultClient.cache.reset();
  });

  it('hides assignee field when toggled off', async () => {
    await mountAndWaitForList();

    expect(findAssigneeLink()).not.toBe(null);

    await toggleDisplayOption('Assignee');

    await waitForElementToBeNull(findAssigneeLink);
  });

  it('disables drawer when side panel toggled off', async () => {
    await mountAndWaitForList();

    await toggleDisplayOption('Open items in side panel');

    findIssueCard().click();

    await waitForElementToBeNull(findWorkItemDrawer);
  });

  it('hides milestone when toggled off', async () => {
    await mountAndWaitForList();

    expect(findMilestone()).not.toBe(null);

    await toggleDisplayOption('Milestone');

    await waitForElementToBeNull(findMilestone);
  });

  it('hides status badge when toggled off', async () => {
    await mountAndWaitForList();

    expect(findStatusBadge()).not.toBe(null);

    await toggleDisplayOption('Status');

    await waitForElementToBeNull(findStatusBadge);
  });

  it('hides weight when toggled off', async () => {
    await mountAndWaitForList();

    expect(findWeight()).not.toBe(null);

    await toggleDisplayOption('Weight');

    await waitForElementToBeNull(findWeight);
  });

  it('hides dates when toggled off', async () => {
    await mountAndWaitForList();

    expect(findDates()).not.toBe(null);

    await toggleDisplayOption('Dates');

    await waitForElementToBeNull(findDates);
  });

  it('hides labels when toggled off', async () => {
    await mountAndWaitForList();

    expect(findLabels()).not.toBe(null);

    await toggleDisplayOption('Labels');

    await waitForElementToBeNull(findLabels);
  });

  it('hides iteration when toggled off', async () => {
    await mountAndWaitForList();

    expect(findIteration()).not.toBe(null);

    await toggleDisplayOption('Iteration');

    await waitForElementToBeNull(findIteration);
  });

  it('hides health status when toggled off', async () => {
    await mountAndWaitForList();

    expect(findHealthStatus()).not.toBe(null);

    await toggleDisplayOption('Health');

    await waitForElementToBeNull(findHealthStatus);
  });

  it('hides parent when toggled off', async () => {
    await mountAndWaitForList();

    expect(findParentMetadata()).not.toBe(null);

    await toggleDisplayOption('Parent');

    await waitForElementToBeNull(findParentMetadata);
  });

  it('hides blocked icon when toggled off', async () => {
    await mountAndWaitForList();

    expect(findBlockedIcon()).not.toBe(null);

    await toggleDisplayOption('Blocked');

    await waitForElementToBeNull(findBlockedIcon);
  });

  it('hides popularity when toggled off', async () => {
    await mountAndWaitForList();

    expect(findUpvotes()).not.toBe(null);

    await toggleDisplayOption('Popularity');

    await waitForElementToBeNull(findUpvotes);
  });

  it('hides comments when toggled off', async () => {
    await mountAndWaitForList();

    expect(findComments()).not.toBe(null);

    await toggleDisplayOption('Comments');

    await waitForElementToBeNull(findComments);
  });
});
