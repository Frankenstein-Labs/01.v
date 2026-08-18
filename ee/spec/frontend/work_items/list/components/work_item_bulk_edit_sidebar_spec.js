import { GlForm } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import workItemBulkUpdateMutation from '~/work_items/list/graphql/work_item_bulk_update.mutation.graphql';
import getAvailableBulkEditWidgets from '~/work_items/list/graphql/get_available_bulk_edit_widgets.query.graphql';
import WorkItemBulkEditAssignee from '~/work_items/list/components/work_item_bulk_edit_assignee.vue';
import WorkItemBulkEditLabels from '~/work_items/list/components/work_item_bulk_edit_labels.vue';
import WorkItemBulkEditMilestone from '~/work_items/list/components/work_item_bulk_edit_milestone.vue';
import WorkItemBulkEditParent from '~/work_items/list/components/work_item_bulk_edit_parent.vue';
import WorkItemBulkEditSidebar from '~/work_items/list/components/work_item_bulk_edit_sidebar.vue';
import WorkItemBulkMove from '~/work_items/list/components/work_item_bulk_move.vue';
import { createAlert } from '~/alert';
import WorkItemBulkEditStatus from 'ee_component/work_items/list/components/work_item_bulk_edit_status.vue';
import WorkItemBulkEditIteration from 'ee_component/work_items/list/components/work_item_bulk_edit_iteration.vue';
import { BULK_EDIT_NO_VALUE, WIDGET_TYPE_ITERATION } from '~/work_items/constants';
import { availableBulkEditWidgetsQueryResponse } from '../../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

const availableWidgetsWithout = (widgetToExclude) => {
  const widgetNames = availableBulkEditWidgetsQueryResponse.data.namespace.workItemsWidgets.filter(
    (name) => name !== widgetToExclude,
  );
  return {
    data: {
      namespace: {
        ...availableBulkEditWidgetsQueryResponse.data.namespace,
        workItemsWidgets: widgetNames,
      },
    },
  };
};

const advanceApolloTimers = async () => {
  jest.runOnlyPendingTimers();
  await waitForPromises();
};

describe('WorkItemBulkEditSidebar component EE', () => {
  let wrapper;

  const checkedItems = [
    {
      id: 'gid://gitlab/WorkItem/11',
      title: 'Work Item 11',
      workItemType: { id: 'gid://gitlab/WorkItems::Type/8' },
    },
    {
      id: 'gid://gitlab/WorkItem/22',
      title: 'Work Item 22',
      workItemType: { id: 'gid://gitlab/WorkItems::Type/5' },
    },
  ];

  const workItemBulkUpdateHandler = jest
    .fn()
    .mockResolvedValue({ data: { workItemBulkUpdate: { updatedWorkItemCount: 1 } } });
  const defaultAvailableWidgetsHandler = jest
    .fn()
    .mockResolvedValue(availableBulkEditWidgetsQueryResponse);

  const createComponent = ({
    provide = {},
    props = {},
    mutationHandler = workItemBulkUpdateHandler,
    availableWidgetsHandler = defaultAvailableWidgetsHandler,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemBulkEditSidebar, {
      apolloProvider: createMockApollo([
        [workItemBulkUpdateMutation, mutationHandler],
        [getAvailableBulkEditWidgets, availableWidgetsHandler],
      ]),
      provide: {
        hasIssuableHealthStatusFeature: true,
        hasIterationsFeature: true,
        hasStatusFeature: true,
        ...provide,
      },
      propsData: {
        checkedItems,
        fullPath: 'group/project',
        isGroup: false,
        ...props,
      },
      stubs: {
        WorkItemBulkEditIteration: stubComponent(WorkItemBulkEditIteration),
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findStatusComponent = () => wrapper.findComponent(WorkItemBulkEditStatus);
  const findIterationComponent = () => wrapper.findComponent(WorkItemBulkEditIteration);
  const findAddLabelsComponent = () => wrapper.findAllComponents(WorkItemBulkEditLabels).at(0);
  const findRemoveLabelsComponent = () => wrapper.findAllComponents(WorkItemBulkEditLabels).at(1);

  const findStateComponent = () => wrapper.findComponentByTestId('bulk-edit-state');
  const findAssigneeComponent = () => wrapper.findComponent(WorkItemBulkEditAssignee);
  const findHealthStatusComponent = () => wrapper.findComponentByTestId('bulk-edit-health-status');
  const findSubscriptionComponent = () => wrapper.findComponentByTestId('bulk-edit-subscription');
  const findConfidentialityComponent = () =>
    wrapper.findComponentByTestId('bulk-edit-confidentiality');
  const findMilestoneComponent = () => wrapper.findComponent(WorkItemBulkEditMilestone);
  const findParentComponent = () => wrapper.findComponent(WorkItemBulkEditParent);
  const findBulkMoveComponent = () => wrapper.findComponent(WorkItemBulkMove);

  describe('when epics list', () => {
    it('calls mutation to bulk edit', async () => {
      const addLabelIds = ['gid://gitlab/Label/1'];
      const removeLabelIds = ['gid://gitlab/Label/2'];
      createComponent({
        props: { isEpicsList: true, fullPath: 'group/subgroup', isGroup: true },
      });
      await waitForPromises();

      findAddLabelsComponent().vm.$emit('select', addLabelIds);
      findRemoveLabelsComponent().vm.$emit('select', removeLabelIds);
      findForm().vm.$emit('submit', { preventDefault: () => {} });

      expect(workItemBulkUpdateHandler).toHaveBeenCalledWith({
        input: {
          fullPath: 'group/subgroup',
          ids: ['gid://gitlab/WorkItem/11', 'gid://gitlab/WorkItem/22'],
          labelsWidget: {
            addLabelIds,
            removeLabelIds,
          },
        },
      });
      expect(findAddLabelsComponent().props('selectedLabelsIds')).toEqual([]);
      expect(findRemoveLabelsComponent().props('selectedLabelsIds')).toEqual([]);
    });

    it('renders error when there is a mutation error', async () => {
      createComponent({
        props: { isEpicsList: true },
        mutationHandler: jest.fn().mockRejectedValue(new Error('oh no')),
      });

      findForm().vm.$emit('submit', { preventDefault: () => {} });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        captureError: true,
        error: new Error('1 out of 1 chunk(s) failed to update'),
        message: 'Something went wrong while bulk editing.',
      });
    });

    describe('widget visibility', () => {
      it('shows the correct widgets', () => {
        createComponent({
          provide: { hasIssuableHealthStatusFeature: true },
        });

        // visible
        expect(findStateComponent().exists()).toBe(true);
        expect(findAssigneeComponent().exists()).toBe(true);
        expect(findAddLabelsComponent().exists()).toBe(true);
        expect(findRemoveLabelsComponent().exists()).toBe(true);
        expect(findHealthStatusComponent().exists()).toBe(true);
        expect(findSubscriptionComponent().exists()).toBe(true);
        expect(findConfidentialityComponent().exists()).toBe(true);
        expect(findMilestoneComponent().exists()).toBe(true);
        expect(findParentComponent().exists()).toBe(true);
        expect(findBulkMoveComponent().exists()).toBe(true);
      });

      it('shows the correct widgets on epics list', () => {
        createComponent({
          props: { isEpicsList: true },
          provide: { hasIssuableHealthStatusFeature: true },
        });

        // visible
        expect(findAssigneeComponent().exists()).toBe(true);
        expect(findAddLabelsComponent().exists()).toBe(true);
        expect(findRemoveLabelsComponent().exists()).toBe(true);
        expect(findHealthStatusComponent().exists()).toBe(true);
        expect(findSubscriptionComponent().exists()).toBe(true);
        expect(findConfidentialityComponent().exists()).toBe(true);
        expect(findMilestoneComponent().exists()).toBe(true);

        // hidden
        expect(findStateComponent().exists()).toBe(false);
        expect(findBulkMoveComponent().exists()).toBe(false);
      });
    });
  });

  it('calls mutation to bulk edit ee attributes', async () => {
    const status = 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/2';
    const iterationId = 'gid://gitlab/Iteration/1215';
    createComponent({
      props: { isEpicsList: false },
    });
    await waitForPromises();

    findIterationComponent().vm.$emit('input', iterationId);
    findStatusComponent().vm.$emit('input', status);
    findForm().vm.$emit('submit', { preventDefault: () => {} });

    expect(workItemBulkUpdateHandler).toHaveBeenCalledWith({
      input: {
        fullPath: 'group/project',
        ids: ['gid://gitlab/WorkItem/11', 'gid://gitlab/WorkItem/22'],
        iterationWidget: {
          iterationId,
        },
        statusWidget: {
          status,
        },
        assigneesWidget: undefined,
        confidential: undefined,
        healthStatusWidget: undefined,
        hierarchyWidget: undefined,
        labelsWidget: undefined,
        milestoneWidget: undefined,
        stateEvent: undefined,
        subscriptionEvent: undefined,
      },
    });
  });

  it('calls mutation with null values to bulk edit when "No value" is chosen', async () => {
    createComponent({
      props: { isEpicsList: false },
    });
    await waitForPromises();

    findIterationComponent().vm.$emit('input', BULK_EDIT_NO_VALUE);
    findForm().vm.$emit('submit', { preventDefault: () => {} });

    expect(workItemBulkUpdateHandler).toHaveBeenCalledWith({
      input: {
        fullPath: 'group/project',
        ids: ['gid://gitlab/WorkItem/11', 'gid://gitlab/WorkItem/22'],
        iterationWidget: {
          iterationId: null,
        },
      },
    });
  });

  describe('"Status" component', () => {
    it('renders status dropdown when required feature is available', async () => {
      createComponent({
        props: {
          isEpicsList: false,
        },
      });

      await nextTick();
      await advanceApolloTimers();

      expect(findStatusComponent().exists()).toBe(true);
    });
  });

  describe('"Iteration" component', () => {
    it.each([true, false])('renders depending on isEpicsList prop', (isEpicsList) => {
      createComponent({
        props: { isEpicsList },
      });

      expect(findIterationComponent().exists()).toBe(!isEpicsList);
    });

    it('updates iteration when "Iteration" component emits "input" event', async () => {
      createComponent({
        props: { isEpicsList: false },
      });

      findIterationComponent().vm.$emit('input', 'gid://gitlab/Iteration/1215');
      await nextTick();

      expect(findIterationComponent().props('value')).toBe('gid://gitlab/Iteration/1215');
    });

    it('enables "Iteration" component when "Iteration" widget is available', async () => {
      createComponent({
        props: { isEpicsList: false },
      });

      await nextTick();
      await advanceApolloTimers();

      expect(findIterationComponent().props('disabled')).toBe(false);
    });

    it('disables "Iteration" component when "Iteration" widget is unavailable', async () => {
      createComponent({
        props: { isEpicsList: false },
        availableWidgetsHandler: jest
          .fn()
          .mockResolvedValue(availableWidgetsWithout(WIDGET_TYPE_ITERATION)),
      });

      await nextTick();
      await advanceApolloTimers();

      expect(findIterationComponent().props('disabled')).toBe(true);
    });
  });
});
