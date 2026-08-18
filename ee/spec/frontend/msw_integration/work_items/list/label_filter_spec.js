import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { lastRequestVariables } from 'ee_jest/msw_integration/operation_helpers';
import WorkItemsRoot from '~/work_items/components/app.vue';
import { createRouter } from '~/work_items/router';
import { apolloProvider } from '~/graphql_shared/issuable_client';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

Vue.use(VueApollo);

const LABEL = 'To Do';
const OTHER_LABEL = 'Doing';
const ITEM_WITH_LABEL = 'Second test issue';
const ITEM_WITH_OTHER_LABEL = 'Child task';
const ITEMS_WITHOUT_LABELS = ['Dependent test issue', 'Blocking issue', 'Linkable test issue'];

describe('Work items list - label filter', () => {
  const findList = () => document.querySelector('.issuable-list');

  const mountWithQuery = (search) => {
    const router = assignRouter(createRouter, {
      fullPath: 'gitlab-org/gitlab',
      routerPath: 'work_items',
      routerLocation: `/work_items/work_items${search}`,
    });

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

  const listedTitles = () =>
    [...findList().querySelectorAll('[data-testid="issuable-title-link"]')].map((el) =>
      getText(el),
    );

  const expectListToShow = (expectedTitles) =>
    waitForAssertion(() => {
      expect(listedTitles().sort()).toEqual([...expectedTitles].sort());
    });

  beforeAll(() => {
    createPortalElement();
  });

  beforeEach(async () => {
    await apolloProvider.defaultClient.cache.reset();
  });

  it('filters to work items carrying the label', async () => {
    mountWithQuery(`?label_name[]=${encodeURIComponent(LABEL)}`);

    await expectListToShow([ITEM_WITH_LABEL]);

    expect(lastRequestVariables('getWorkItemsSlimEE')).toMatchObject({ labelName: LABEL });
  });

  it('filters out work items carrying the label', async () => {
    mountWithQuery(`?not[label_name][]=${encodeURIComponent(LABEL)}`);

    await expectListToShow([ITEM_WITH_OTHER_LABEL, ...ITEMS_WITHOUT_LABELS]);

    expect(lastRequestVariables('getWorkItemsSlimEE')).toMatchObject({
      not: { labelName: [LABEL] },
    });
  });

  it('filters to work items with no labels', async () => {
    mountWithQuery('?label_name[]=None');

    await expectListToShow(ITEMS_WITHOUT_LABELS);

    expect(lastRequestVariables('getWorkItemsSlimEE')).toMatchObject({ labelName: 'None' });
  });

  it('filters to work items carrying any label', async () => {
    mountWithQuery('?label_name[]=Any');

    await expectListToShow([ITEM_WITH_LABEL, ITEM_WITH_OTHER_LABEL]);

    expect(lastRequestVariables('getWorkItemsSlimEE')).toMatchObject({ labelName: 'Any' });
  });

  it('filters to work items carrying one of several labels', async () => {
    mountWithQuery(
      `?or[label_name][]=${encodeURIComponent(LABEL)}` +
        `&or[label_name][]=${encodeURIComponent(OTHER_LABEL)}`,
    );

    await expectListToShow([ITEM_WITH_LABEL, ITEM_WITH_OTHER_LABEL]);

    expect(lastRequestVariables('getWorkItemsSlimEE')).toMatchObject({
      or: { labelNames: [LABEL, OTHER_LABEL] },
    });
  });
});
