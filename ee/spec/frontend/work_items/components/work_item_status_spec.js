import { GlButton } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { newWorkItemId } from '~/work_items/utils';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import WorkItemStatus from 'ee/work_items/components/work_item_status.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import groupWorkspacePermissionsQuery from '~/work_items/graphql/group_workspace_permissions.query.graphql';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import {
  mockWorkItemStatus,
  namespaceWorkItemTypesQueryResponse,
  updateWorkItemMutationResponse,
  updateWorkItemMutationResponseFactory,
  workItemByIidResponseFactory,
  mockGroupPermissionsQueryResponse,
} from '../mock_data';

describe('WorkItemStatus component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemIid = '1';
  const workItemType = 'Task';
  const allowedStatus = namespaceWorkItemTypesQueryResponse.data.namespace.workItemTypes.nodes
    .find((node) => node.name === workItemType)
    .widgetDefinitions?.find((item) => {
      return item.type === 'STATUS';
    })?.allowedStatuses;

  const findSidebarDropdownWidget = () => wrapper.findComponent(WorkItemSidebarDropdownWidget);
  const findWorkItemStatusBadge = () => wrapper.findComponent(WorkItemStatusBadge);
  const findManageStatusButton = () => wrapper.findComponent(GlButton);

  const showDropdown = () => {
    findSidebarDropdownWidget().vm.$emit('dropdown-shown');
  };

  const successUpdateWorkItemMutationHandler = jest.fn().mockResolvedValue(
    updateWorkItemMutationResponseFactory({
      statusWidgetPresent: true,
      statusWidgetValues: {
        ...mockWorkItemStatus,
        id: 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/1',
        name: 'To do',
      },
    }),
  );

  const workItemUpdateNetworkErrorHandler = jest.fn().mockRejectedValue('Oops ! Problem');
  const workItemUpdateBackendErrorHandler = jest.fn().mockResolvedValue({
    errors: [
      {
        message: "Status doesn't exist.",
        locations: [
          {
            line: 2,
            column: 3,
          },
        ],
        path: ['workItemUpdate'],
      },
    ],
    data: {
      workItemUpdate: null,
    },
  });

  const createComponent = ({
    mountFn = shallowMountExtended,
    canUpdate = true,
    status = mockWorkItemStatus,
    workItemTypesHandler = jest.fn().mockResolvedValue(namespaceWorkItemTypesQueryResponse),
    mutationHandler = successUpdateWorkItemMutationHandler,
    workItemId = 'gid://gitlab/WorkItem/1',
    workspacePermissionsResponse = mockGroupPermissionsQueryResponse(),
    glFeatures = {},
    features = null,
  } = {}) => {
    const workItemResponse = workItemByIidResponseFactory({
      statusWidgetPresent: true,
      statusWidgetValues: status,
      canUpdate,
      features,
    });
    const workItemByIidSuccessHandler = jest.fn().mockResolvedValue(workItemResponse);
    const workspacePermissionsHandler = jest.fn().mockResolvedValue(workspacePermissionsResponse);

    wrapper = mountFn(WorkItemStatus, {
      apolloProvider: createMockApollo([
        [namespaceWorkItemTypesQuery, workItemTypesHandler],
        [workItemByIidQuery, workItemByIidSuccessHandler],
        [updateWorkItemMutation, mutationHandler],
        [groupWorkspacePermissionsQuery, workspacePermissionsHandler],
      ]),
      propsData: {
        canUpdate,
        fullPath: 'test-project-path',
        workItemIid,
        workItemType,
        workItemId,
      },
      provide: {
        issuesSettings: '/groups/test-project-path/-/settings/issues',
        glFeatures,
      },
    });
  };

  const createComponentAndShowDropdown = async () => {
    createComponent();
    await waitForPromises();
    showDropdown();
  };

  it('has "Status" label', async () => {
    createComponent();
    await waitForPromises();

    expect(findSidebarDropdownWidget().props('dropdownLabel')).toBe('Status');
  });

  describe('Default text with canUpdate false and status value', () => {
    it('shows None for no status response', async () => {
      createComponent({
        mountFn: mountExtended,
        canUpdate: false,
        status: null,
      });
      await waitForPromises();

      expect(wrapper.text()).toContain('None');
      expect(findSidebarDropdownWidget().props('canUpdate')).toBe(false);
    });

    it('shows In progress when status set', async () => {
      createComponent({
        mountFn: mountExtended,
        canUpdate: false,
        status: mockWorkItemStatus,
      });
      await waitForPromises();

      expect(wrapper.text()).toContain('In progress');
      expect(findSidebarDropdownWidget().props('canUpdate')).toBe(false);
    });
  });

  describe('Dropdown options', () => {
    it('calls `namespaceWorkItemTypesHandler` with variables when dropdown is opened', async () => {
      const workItemTypesHandler = jest.fn().mockResolvedValue(namespaceWorkItemTypesQueryResponse);
      createComponent({ workItemTypesHandler });
      await waitForPromises();

      showDropdown();
      await waitForPromises();

      expect(workItemTypesHandler).toHaveBeenCalledWith({
        fullPath: 'test-project-path',
      });
    });

    it('searches the options on frontend', async () => {
      await createComponentAndShowDropdown();

      await waitForPromises();
      findSidebarDropdownWidget().vm.$emit('search-started', 'to do');
      await nextTick();

      expect(findSidebarDropdownWidget().props('listItems')).toHaveLength(1);
    });

    it('resets the options on frontend when dropdown hidden after search', async () => {
      await createComponentAndShowDropdown();

      await waitForPromises();
      findSidebarDropdownWidget().vm.$emit('search-started', 'to do');
      await nextTick();

      expect(findSidebarDropdownWidget().props('listItems')).toHaveLength(1);

      await findSidebarDropdownWidget().vm.$emit('dropdown-hidden');

      showDropdown();
      await waitForPromises();

      expect(findSidebarDropdownWidget().props('listItems')).toHaveLength(allowedStatus.length);
    });

    it('shows the skeleton loader when the items are being fetched on click', async () => {
      await createComponentAndShowDropdown();

      expect(findSidebarDropdownWidget().props('loading')).toBe(true);
    });

    it('shows the status in dropdown when the items have finished fetching', async () => {
      await createComponentAndShowDropdown();

      await waitForPromises();

      expect(findSidebarDropdownWidget().props('loading')).toBe(false);
      expect(findSidebarDropdownWidget().props('listItems')).toHaveLength(allowedStatus.length);
    });

    it('changes the status to the selected status', async () => {
      createComponent();
      await waitForPromises();

      showDropdown();
      await waitForPromises();

      const firstStatus = allowedStatus[0];

      findSidebarDropdownWidget().vm.$emit('update-value', firstStatus.id);
      await nextTick();
      await waitForPromises();

      expect(successUpdateWorkItemMutationHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: {
            id: 'gid://gitlab/WorkItem/1',
            statusWidget: {
              status: firstStatus.id,
            },
          },
        }),
      );

      expect(findSidebarDropdownWidget().props('itemValue')).toBe(firstStatus.id);
    });

    describe('when workItemFeaturesField feature flag is enabled', () => {
      let mutationSpy;

      beforeEach(async () => {
        mutationSpy = jest.fn().mockResolvedValue(updateWorkItemMutationResponse);
        createComponent({
          mutationHandler: mutationSpy,
          glFeatures: { workItemFeaturesField: true },
          features: { status: { status: mockWorkItemStatus } },
        });
        await waitForPromises();

        showDropdown();
        await waitForPromises();
      });

      it('passes useWorkItemFeatures as true to the mutation', async () => {
        const firstStatus = allowedStatus[0];

        findSidebarDropdownWidget().vm.$emit('update-value', firstStatus.id);
        await nextTick();
        await waitForPromises();

        expect(mutationSpy).toHaveBeenCalledWith(
          expect.objectContaining({
            input: {
              id: 'gid://gitlab/WorkItem/1',
              statusWidget: {
                status: firstStatus.id,
              },
            },
            useWorkItemFeatures: true,
          }),
        );
      });
    });

    it('emits the `statusUpdated` to the parent to make sure the board lists are updated', async () => {
      createComponent();
      await waitForPromises();

      showDropdown();
      await waitForPromises();

      const firstStatus = allowedStatus[0];

      findSidebarDropdownWidget().vm.$emit('update-value', firstStatus.id);
      await nextTick();
      await waitForPromises();

      expect(wrapper.emitted('statusUpdated')).toEqual([[firstStatus.id]]);
    });

    it('calls error handler when there is an error in updating', async () => {
      createComponent({ mutationHandler: workItemUpdateNetworkErrorHandler });
      await waitForPromises();

      showDropdown();
      await waitForPromises();

      const firstStatus = allowedStatus[0];

      findSidebarDropdownWidget().vm.$emit('update-value', firstStatus.id);
      await nextTick();
      await waitForPromises();

      expect(successUpdateWorkItemMutationHandler).not.toHaveBeenCalledWith();
      expect(workItemUpdateNetworkErrorHandler).toHaveBeenCalled();
    });

    it('emits error from the backend rather than general error when there is an error', async () => {
      createComponent({ mutationHandler: workItemUpdateBackendErrorHandler });
      await waitForPromises();

      showDropdown();
      await waitForPromises();

      const firstStatus = allowedStatus[0];

      findSidebarDropdownWidget().vm.$emit('update-value', firstStatus.id);
      await nextTick();
      await waitForPromises();

      expect(wrapper.emitted('error')).toStrictEqual([["Status doesn't exist."]]);
    });

    it('calls the update work item local mutation for new work items', async () => {
      createComponent({ workItemId: newWorkItemId('task') });

      await waitForPromises();

      expect(findWorkItemStatusBadge().props().item).toMatchObject({
        name: mockWorkItemStatus.name,
        iconName: mockWorkItemStatus.iconName,
        color: mockWorkItemStatus.color,
      });

      showDropdown();
      await waitForPromises();

      const firstStatus = allowedStatus[0];

      findSidebarDropdownWidget().vm.$emit('update-value', firstStatus.id);
      await waitForPromises();

      expect(findWorkItemStatusBadge().props().item).toMatchObject({
        name: firstStatus.name,
        iconName: firstStatus.iconName,
        color: firstStatus.color,
      });
    });

    it('shows the `Manage status` in footer when it has permisions', async () => {
      createComponentAndShowDropdown();
      await waitForPromises();

      expect(findSidebarDropdownWidget().props('showFooter')).toBe(true);
      expect(findManageStatusButton().exists()).toBe(true);
      expect(findManageStatusButton().props('href')).toBe(
        '/groups/test-project-path/-/settings/issues/#js-custom-status-settings',
      );
    });

    it('does not show the `Manage status` in footer when it does not have permissions', () => {
      createComponent({
        workspacePermissionsResponse: {
          ...mockGroupPermissionsQueryResponse({ adminWorkItemLifecycle: false }),
        },
      });

      expect(findSidebarDropdownWidget().props('showFooter')).toBe(false);
    });

    describe('Tracking event', () => {
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      it('tracks updating the status', async () => {
        createComponent();
        await waitForPromises();

        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        findSidebarDropdownWidget().vm.$emit('update-value', null);

        await waitForPromises();

        expect(trackEventSpy).toHaveBeenCalledWith('work_item_status_updated', {}, undefined);
      });
    });
  });
});
