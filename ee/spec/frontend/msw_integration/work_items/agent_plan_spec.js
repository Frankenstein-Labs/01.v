import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { within } from '@testing-library/vue';
import namespaceWorkItemFixture from 'test_fixtures/graphql/work_items/integration/namespace_work_item.query.graphql.json';
import WorkItemsRoot from '~/work_items/components/app.vue';
import { createRouter } from '~/work_items/router';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import {
  findIssueToEdit,
  findWorkItemDetail,
  selectIssue,
} from 'ee_jest/msw_integration/work_items/test_helpers';
import { createGraphQLResolver } from 'ee_jest/msw_integration/work_items/resolver_utils';
import { server } from 'ee_jest/msw_integration/server';
import { WIDGET_TYPE_AGENT_PLAN, MANAGED_WIDGET_TYPES } from 'ee/work_items/constants';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

Vue.use(VueApollo);

describe('Work item agent plan integration test', () => {
  const router = assignRouter(createRouter, {
    fullPath: 'gitlab-org/gitlab',
    routerPath: 'work_items',
  });

  const buildWorkItemResponse = ({ content = '', canUpdate = true, withWidget = true } = {}) => {
    const response = JSON.parse(JSON.stringify(namespaceWorkItemFixture));
    const { workItem } = response.data.namespace;

    workItem.userPermissions.updateWorkItem = canUpdate;
    workItem.widgets = workItem.widgets.filter(
      (widget) => !MANAGED_WIDGET_TYPES.includes(widget.type),
    );

    if (withWidget) {
      workItem.widgets.push({
        __typename: 'WorkItemWidgetAgentPlan',
        type: WIDGET_TYPE_AGENT_PLAN,
        content,
      });
    }

    return response;
  };

  const useWorkItemResponse = (options) => {
    server.use(
      createGraphQLResolver({
        namespaceWorkItem: buildWorkItemResponse(options),
      }),
    );
  };

  const withinDrawer = () => within(document.getElementById('contextual-panel-portal'));
  const findInlineRow = () => withinDrawer().queryByTestId('work-plan-inline-row');
  const findOpenButton = () => withinDrawer().queryByTestId('open-work-plan-button');
  const findRenderedPlan = () => withinDrawer().queryByTestId('work-plan-rendered');
  const findEmptyState = () => withinDrawer().queryByTestId('work-plan-empty-state');
  const findCreateWorkplanDropdown = () => withinDrawer().queryByTestId('create-workplan-dropdown');
  const mountAndOpenWorkItem = async () => {
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

    await waitForElement(findIssueToEdit);
    await selectIssue();
  };

  beforeAll(() => {
    createPortalElement();
  });

  beforeEach(async () => {
    await apolloProvider.defaultClient.cache.reset();
  });

  describe('when the work item has no agent plan widget', () => {
    beforeEach(async () => {
      useWorkItemResponse({ withWidget: false });
      await mountAndOpenWorkItem();
    });

    it('does not render the workplan', async () => {
      await waitForElement(findWorkItemDetail);

      expect(findInlineRow()).toBe(null);
    });
  });

  describe('when the work item has an agent plan widget', () => {
    describe('when the user has update permission', () => {
      describe('when there is no saved workplan', () => {
        beforeEach(async () => {
          useWorkItemResponse({ canUpdate: true, content: '' });
          await mountAndOpenWorkItem();
        });

        it('shows the workplan inline row with a create action', async () => {
          await waitForElement(findInlineRow);

          expect(getText(findInlineRow())).toContain('Not yet created');
          expect(findCreateWorkplanDropdown()).not.toBe(null);
        });

        describe('when the user opens the panel through the create dropdown', () => {
          beforeEach(async () => {
            const dropdownToggle = await waitForElement(() =>
              within(findCreateWorkplanDropdown()).queryByTestId('base-dropdown-toggle'),
            );
            dropdownToggle.click();
            await waitAndClick(() => withinDrawer().queryByTestId('create-workplan-dropdown-item'));
          });

          it('opens the panel showing the empty state', async () => {
            await waitForElement(findEmptyState);

            expect(getText(findEmptyState())).toContain('Create a workplan');
          });
        });
      });

      describe('when there is a saved workplan', () => {
        beforeEach(async () => {
          useWorkItemResponse({ canUpdate: true, content: 'Existing workplan content' });
          await mountAndOpenWorkItem();
        });

        it('shows the workplan inline row ready to review', async () => {
          await waitForElement(findInlineRow);

          expect(getText(findInlineRow())).toContain('Ready for review');
          expect(findOpenButton()).not.toBe(null);
        });

        describe('when the user opens the panel', () => {
          beforeEach(async () => {
            await waitForElement(findInlineRow);
            await waitAndClick(findOpenButton);
          });

          it('renders the saved workplan content', async () => {
            await waitForElement(findRenderedPlan);

            expect(getText(findRenderedPlan())).toContain('Existing workplan content');
          });
        });
      });
    });

    describe('when the user has no update permission', () => {
      beforeEach(async () => {
        useWorkItemResponse({ canUpdate: false, content: '' });
        await mountAndOpenWorkItem();
      });

      it('shows the workplan inline row without a create action', async () => {
        await waitForElement(findInlineRow);

        expect(getText(findInlineRow())).toContain('No workplan');
        expect(findOpenButton()).toBe(null);
        expect(findCreateWorkplanDropdown()).toBe(null);
      });
    });
  });
});
