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

Vue.use(VueApollo);

describe('Work items list - views', () => {
  const router = assignRouter(createRouter, {
    fullPath: 'gitlab-org/gitlab',
    routerPath: 'work_items',
  });

  const findIssueCard = () => findByGraphQLId(workItemId, getIdFromGraphQLId);
  const findSecondIssueCard = () => findByGraphQLId(secondWorkItemId, getIdFromGraphQLId);

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

  beforeAll(() => {
    createPortalElement();
  });

  beforeEach(async () => {
    await apolloProvider.defaultClient.cache.reset();
  });

  describe('when the work items list page renders', () => {
    beforeEach(async () => {
      createComponent();
      await waitForElement(findIssueCard);
    });

    it('shows action buttons for signed-in user', () => {
      expect(findButtonByText('Bulk edit')).not.toBe(null);

      const links = [...document.querySelectorAll('a')];
      expect(links.some((a) => a.textContent.includes('New item'))).toBe(true);
    });

    it('shows default sort order', async () => {
      await waitAndClick(() => findButtonByText('Display'));

      await waitForAssertion(() => {
        const drawer = within(document.body).queryByTestId('display-settings-drawer');
        expect(getText(drawer)).toContain('Created date');
      });
    });

    it('displays assignee on the work item card', () => {
      expect(within(findIssueCard()).queryByTestId('assignee-link')).not.toBe(null);
    });

    it('displays milestone on the work item card', () => {
      expect(within(findIssueCard()).queryByTestId('issuable-milestone')).not.toBe(null);
      expect(getText(findIssueCard())).toContain('v1.0');
    });

    it('displays due date on the work item card', () => {
      expect(findIssueCard().querySelector('.issuable-due-date')).not.toBe(null);
    });

    it('displays labels on the work item card', () => {
      expect(findSecondIssueCard().querySelector('.gl-label')).not.toBe(null);
      expect(getText(findSecondIssueCard())).toContain('To Do');
    });

    it('displays upvotes on the work item card', () => {
      expect(within(findSecondIssueCard()).queryByTestId('issuable-upvotes')).not.toBe(null);
    });

    it('displays health status on the work item card', () => {
      expect(within(findIssueCard()).queryByTestId('status-text')).not.toBe(null);
    });

    it('displays weight on the work item card', () => {
      expect(within(findIssueCard()).queryByTestId('issuable-weight-content')).not.toBe(null);
    });

    it('shows open items and does not show closed items', () => {
      const list = document.querySelector('.issuable-list');
      const listText = getText(list);
      expect(listText).toContain('Dependent test issue');
      expect(listText).toContain('Second test issue');
      expect(listText).not.toContain('Closed test issue');
    });
  });
});
