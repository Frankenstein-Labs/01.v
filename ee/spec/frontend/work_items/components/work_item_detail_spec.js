import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { isLoggedIn } from '~/lib/utils/common_utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import WorkItemDetailEE from 'ee/work_items/components/work_item_detail.vue';
import WorkItemDetailCE from '~/work_items/components/work_item_detail.vue';
import BaseLayout from '~/vue_shared/components/base_layout.vue';
import WorkItemTree from '~/work_items/components/work_item_links/work_item_tree.vue';
import DetailLayout from '~/vue_shared/components/detail_layout.vue';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import workItemUpdatedSubscription from '~/work_items/graphql/work_item_updated.subscription.graphql';
import workspacePermissionsQuery from '~/work_items/graphql/workspace_permissions.query.graphql';
import getAllowedWorkItemChildTypes from '~/work_items/graphql/work_item_allowed_children.query.graphql';
import DuoWorkItemToMrAction from 'ee_component/ai/shared/widgets/duo_work_item_to_mr_action.vue';
import WorkItemAiWidget from 'ee/work_items/components/ai_widget/work_item_ai_widget.vue';
import WorkItemAgentSessions from 'ee/work_items/components/agent_sessions/index.vue';
import WorkItemDecisionLog from 'ee/work_items/components/decision_log/work_item_decision_log.vue';

import {
  workItemByIidResponseFactory,
  workItemResponseFactory,
  mockProjectPermissionsQueryResponse,
  allowedChildrenTypesResponse,
} from 'ee_else_ce_jest/work_items/mock_data';

jest.mock('~/lib/utils/common_utils');

describe('EE WorkItemDetail component', () => {
  let wrapper;

  Vue.use(VueApollo);

  const workItemByIidQueryResponse = workItemByIidResponseFactory({
    canUpdate: true,
    canDelete: true,
  });
  const successHandler = jest.fn().mockResolvedValue(workItemByIidQueryResponse);
  const workItemUpdatedSubscriptionHandler = jest
    .fn()
    .mockResolvedValue({ data: { workItemUpdated: null } });
  const workspacePermissionsAllowedHandler = jest
    .fn()
    .mockResolvedValue(mockProjectPermissionsQueryResponse());
  const allowedChildrenTypesHandler = jest.fn().mockResolvedValue(allowedChildrenTypesResponse);

  const createComponent = ({
    component = WorkItemDetailCE,
    workItemIid = '1',
    handler = successHandler,
    glFeatures = {},
    provide = {},
    workItem = null,
    stubs = {},
  } = {}) => {
    wrapper = shallowMountExtended(component, {
      apolloProvider: createMockApollo([
        [workItemByIidQuery, handler],
        [workItemUpdatedSubscription, workItemUpdatedSubscriptionHandler],
        [getAllowedWorkItemChildTypes, allowedChildrenTypesHandler],
        [workspacePermissionsQuery, workspacePermissionsAllowedHandler],
      ]),
      isLoggedIn: isLoggedIn(),
      propsData: {
        workItemIid,
        workItemFullPath: 'group/project',
      },
      provide: {
        glFeatures: {
          ...glFeatures,
        },
        duoRemoteFlowsAvailability: true,
        hasSubepicsFeature: true,
        hasLinkedItemsEpicsFeature: true,
        fullPath: 'group/project',
        groupPath: 'group',
        reportAbusePath: '/report/abuse/path',
        isGroup: true,
        ...provide,
      },
      mocks: {
        $router: true,
      },
      stubs: {
        BaseLayout,
        DetailLayout,
        WorkItemDetail: stubComponent(WorkItemDetailCE, {
          template: `<div>
            <slot
              name="widgets-top"
              :work-item="workItem"
              :is-detail-panel="false"
              :active-panel="null"
              :edit-mode="false"
              :request-panel="() => {}"
            />
            <slot name="widgets" :work-item="workItem" />
          </div>`,
          data() {
            return { workItem };
          },
        }),
        WorkItemVulnerabilities: true,
        DuoWorkItemToMrAction: true,
        WorkItemAiWidget: stubComponent(WorkItemAiWidget),
        WorkItemAgentSessions: stubComponent(WorkItemAgentSessions),
        WorkItemDecisionLog: stubComponent(WorkItemDecisionLog),
        ...stubs,
      },
    });
  };

  beforeEach(() => {
    isLoggedIn.mockReturnValue(true);
  });

  const findCeComponent = () => wrapper.findComponent(WorkItemDetailCE);
  const findVulnerabilitiesWidget = () =>
    wrapper.findComponentByTestId('work-item-vulnerabilities');
  const findDuoWorkItemToMrAction = () => wrapper.findComponent(DuoWorkItemToMrAction);
  const findWorkItemAiWidget = () => wrapper.findComponent(WorkItemAiWidget);
  const findAgentSessions = () => wrapper.findComponent(WorkItemAgentSessions);
  const findDecisionLog = () => wrapper.findComponent(WorkItemDecisionLog);
  const findHierarchyTree = () => wrapper.findComponent(WorkItemTree);

  describe('vulnerabilities widget', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('shows vulnerabilities widget', () => {
      expect(findVulnerabilitiesWidget().exists()).toBe(true);
    });
  });

  describe('Duo Work Item to MR Action', () => {
    beforeEach(async () => {
      createComponent({});
      await waitForPromises();
    });

    it('renders the component', () => {
      expect(findDuoWorkItemToMrAction().exists()).toBe(true);
    });

    it('passes correct props', () => {
      const { workItem } = workItemByIidQueryResponse.data.namespace;

      expect(findDuoWorkItemToMrAction().props()).toMatchObject({
        projectPath: 'group/project',
        workItemIid: workItem.iid,
        workItemType: workItem.workItemType.name,
        workItemWebUrl: workItem.webUrl,
      });
    });

    describe('when agent plan widget is present on the work item', () => {
      it('does not render the component', async () => {
        const response = workItemByIidResponseFactory();
        response.data.namespace.workItem.widgets.push({
          __typename: 'WorkItemWidgetAgentPlan',
          type: 'AGENT_PLAN',
        });
        const handlerWithAgentPlan = jest.fn().mockResolvedValue(response);

        createComponent({
          handler: handlerWithAgentPlan,
          provide: { duoRemoteFlowsAvailability: true },
        });
        await waitForPromises();

        expect(findDuoWorkItemToMrAction().exists()).toBe(false);
      });
    });
  });

  describe('AgentPlan', () => {
    const agentPlanWidget = { __typename: 'WorkItemWidgetAgentPlan', type: 'AGENT_PLAN' };

    const createWorkItemWithAgentPlanWidget = (options = {}) => {
      const {
        data: { workItem },
      } = workItemResponseFactory(options);
      workItem.widgets.push(agentPlanWidget);
      return workItem;
    };

    describe('CE component rendering', () => {
      it('renders the CE WorkItemDetail component', () => {
        createComponent({ component: WorkItemDetailEE });

        expect(findCeComponent().exists()).toBe(true);
      });
    });

    describe('when agent plan is not available', () => {
      it.each`
        description                              | workItem            | isAsync
        ${'features.agentPlan is missing'}       | ${{ features: {} }} | ${false}
        ${'workItem has neither path populated'} | ${undefined}        | ${true}
      `('does not render when $description', async ({ workItem, isAsync }) => {
        createComponent({ component: WorkItemDetailEE, workItem });
        if (isAsync) await waitForPromises();

        expect(findWorkItemAiWidget().exists()).toBe(false);
      });
    });

    describe('when agent plan is available', () => {
      it.each`
        description                           | workItem
        ${'via the features.agentPlan path'}  | ${{ features: { agentPlan: true } }}
        ${'via the widgets[AGENT_PLAN] path'} | ${{ widgets: [{ __typename: 'WorkItemWidgetAgentPlan', type: 'AGENT_PLAN' }] }}
      `('renders $description', ({ workItem }) => {
        createComponent({ component: WorkItemDetailEE, workItem });

        expect(findWorkItemAiWidget().exists()).toBe(true);
      });

      it('passes workItem object as a prop', () => {
        const workItem = createWorkItemWithAgentPlanWidget();
        createComponent({
          component: WorkItemDetailEE,
          workItem,
        });

        expect(findWorkItemAiWidget().props('workItem')).toBe(workItem);
      });

      it('passes canUpdate from workItem permissions', () => {
        const workItem = createWorkItemWithAgentPlanWidget({ canUpdate: true });
        createComponent({
          component: WorkItemDetailEE,
          workItem,
        });

        expect(findWorkItemAiWidget().props('canUpdate')).toBe(true);
      });

      it('passes canUpdate as false when user cannot update', () => {
        const workItem = createWorkItemWithAgentPlanWidget({ canUpdate: false });
        createComponent({
          component: WorkItemDetailEE,
          workItem,
        });

        expect(findWorkItemAiWidget().props('canUpdate')).toBe(false);
      });
    });
  });

  describe('WorkItemAgentSessions', () => {
    it('renders when workItem is available', () => {
      const {
        data: { workItem },
      } = workItemResponseFactory();
      createComponent({ component: WorkItemDetailEE, workItem });

      expect(findAgentSessions().exists()).toBe(true);
    });

    it('does not render when workItem is not available', () => {
      createComponent({ component: WorkItemDetailEE, workItem: null });

      expect(findAgentSessions().exists()).toBe(false);
    });

    it('passes workItemId from workItem', () => {
      const {
        data: { workItem },
      } = workItemResponseFactory();
      createComponent({ component: WorkItemDetailEE, workItem });

      expect(findAgentSessions().props('workItemId')).toBe(workItem.id);
    });
  });

  describe('WorkItemDecisionLog', () => {
    // `id` keeps the sibling agent sessions widget from warning about a missing prop.
    const workItemWithAgentPlan = {
      id: 'gid://gitlab/WorkItem/1',
      features: { agentPlan: true },
    };
    const workItemWithoutAgentPlan = { id: 'gid://gitlab/WorkItem/1', features: {} };

    it.each`
      workplanDecisionLog | workItem                    | scenario                            | rendered
      ${true}             | ${workItemWithAgentPlan}    | ${'a work item with an agent plan'} | ${true}
      ${true}             | ${workItemWithoutAgentPlan} | ${'a work item with no agent plan'} | ${false}
      ${true}             | ${null}                     | ${'no work item'}                   | ${false}
      ${false}            | ${workItemWithAgentPlan}    | ${'a work item with an agent plan'} | ${false}
    `(
      'rendered is $rendered with the flag $workplanDecisionLog and $scenario',
      async ({ workplanDecisionLog, workItem, rendered }) => {
        createComponent({
          component: WorkItemDetailEE,
          workItem,
          glFeatures: { workplanDecisionLog },
        });
        await waitForPromises();

        expect(findDecisionLog().exists()).toBe(rendered);
      },
    );
  });

  describe('showWidgets slot-presence check (regression)', () => {
    // Regression test: `showWidgets` reads `this.glSlots().widgets` purely
    // to check whether a "widgets" slot was provided. The other specs in
    // this file stub out the CE WorkItemDetail component with a hand-rolled
    // template, which hides how the real component actually resolves this
    // check under @vue/compat -- deep-mount the real CE component, plus the
    // real DetailLayout/BaseLayout it renders through, so the real
    // `showWidgets` computed and the real EE `#widgets="{ workItem }"`
    // slot participate. Before the glSlotsMixin fix, merely reading
    // `glSlots().widgets` auto-invoked that slot function with no
    // arguments and crashed on the `{ workItem }` destructure.
    it('does not throw when the real CE component and layout wrappers render the EE widgets slot', async () => {
      const {
        data: { workItem },
      } = workItemResponseFactory();

      createComponent({
        component: WorkItemDetailEE,
        workItem,
        stubs: {
          WorkItemDetail: false,
          BaseLayout: false,
          DetailLayout: false,
        },
      });
      await waitForPromises();

      // The assertion that matters is that mounting above didn't throw.
      // Also confirm the real (unstubbed) CE component actually
      // participated, so this isn't accidentally testing a stub.
      expect(findCeComponent().exists()).toBe(true);
    });
  });

  describe('iteration', () => {
    describe('when features.iteration is present', () => {
      const iteration = {
        id: 'gid://gitlab/Iteration/5',
        title: 'Features iteration',
        startDate: '2024-01-01',
        dueDate: '2024-01-31',
        webUrl: 'http://example.com/iteration/5',
        iterationCadence: {
          id: 'gid://gitlab/Iterations::Cadence/9',
          title: 'Cadence',
          __typename: 'IterationCadence',
        },
      };

      beforeEach(async () => {
        createComponent({
          handler: jest.fn().mockResolvedValue(
            workItemByIidResponseFactory({
              canUpdate: true,
              canDelete: true,
              features: { iteration: { iteration } },
            }),
          ),
          glFeatures: { workItemFeaturesField: true },
        });
        await waitForPromises();
      });

      it('passes the iteration from features as `parentIteration` to the work item tree', () => {
        expect(findHierarchyTree().props('parentIteration')).toEqual(iteration);
      });
    });
  });
});
