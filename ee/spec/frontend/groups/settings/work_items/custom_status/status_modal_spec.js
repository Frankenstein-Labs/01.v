import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlSprintf, GlDisclosureDropdown } from '@gitlab/ui';
import Draggable from '~/lib/utils/vue3compat/draggable_compat.vue';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import StatusLifecycleModal from 'ee/groups/settings/work_items/custom_status/status_modal.vue';
import RemoveStatusModal from 'ee/groups/settings/work_items/custom_status/remove_status_modal.vue';
import StatusForm from 'ee/groups/settings/work_items/custom_status/status_form.vue';
import WorkItemStateBadge from '~/work_items/components/work_item_state_badge.vue';
import lifecycleUpdateMutation from 'ee/groups/settings/work_items/custom_status/graphql/lifecycle_update.mutation.graphql';
import namespaceMetadataQuery from 'ee/groups/settings/work_items/custom_status/graphql/namespace_metadata.query.graphql';
import { mockNamespaceMetadata, mockLifecycles } from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('StatusLifecycleModal', () => {
  let wrapper;
  let mockApollo;

  const mockLifecycle = {
    id: 'gid://gitlab/WorkItems::Lifecycle/1',
    name: 'Lifecycle 1',
    workItemTypes: [
      {
        id: 'gid://gitlab/WorkItems::Type/1',
        name: 'Issue',
        iconName: 'work-item-issue',
        __typename: 'WorkItemType',
      },
      {
        id: 'gid://gitlab/WorkItems::Type/2',
        name: 'Task',
        iconName: 'work-item-task',
        __typename: 'WorkItemType',
      },
    ],
    statuses: [
      {
        id: 'status-1',
        name: 'Open',
        color: '#1f75cb',
        iconName: 'status-waiting',
        description: 'New issues',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'status-2',
        name: 'In Progress',
        color: '#1f75cb',
        iconName: 'status-running',
        description: 'In progress',
        __typename: 'WorkItemStatus',
      },
      {
        id: 'status-3',
        name: 'Done',
        color: '#108548',
        iconName: 'status-success',
        description: 'Information regarding done',
        __typename: 'WorkItemStatus',
      },
    ],
    defaultOpenStatus: {
      id: 'status-1',
      name: 'Open',
    },
    defaultClosedStatus: {
      id: 'status-3',
      name: 'Done',
    },
    defaultDuplicateStatus: {
      id: 'status-3',
      name: 'Done',
    },
  };

  const mockUpdateResponse = {
    data: {
      lifecycleUpdate: {
        lifecycle: {
          ...mockLifecycle,
          statuses: [
            ...mockLifecycle.statuses,
            {
              id: 'status-4',
              name: 'New Status',
              color: '#ff0000',
              iconName: 'status-neutral',
              description: '',
              __typename: 'WorkItemStatus',
            },
          ],
          __typename: 'WorkItemLifecycle',
        },
        __typename: 'LifecycleUpdatePayload',
        errors: [],
      },
    },
  };

  const newFormData = {
    name: 'Updated Name',
    color: '#00ff00',
    description: 'Updated description',
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findStatusInfo = () => wrapper.findByTestId('status-info-alert');
  const findLifecycleInfo = () => wrapper.findAllByTestId('lifecycle-info');
  const findCategorySection = (category) => wrapper.findByTestId(`category-${category}`);
  const findStatusBadges = () => wrapper.findAllByTestId('status-badge');
  const findHelpPageLink = () => wrapper.findComponentByTestId('help-page-link');
  const findDefaultStatusBadges = () => wrapper.findAllByTestId('default-status-badge');
  const findStatusForm = () => wrapper.findComponent(StatusForm);
  const findRemoveStatusModal = () => wrapper.findComponent(RemoveStatusModal);
  const findEditStatusButton = (statusId) =>
    wrapper.findComponentByTestId(`edit-status-${statusId}`);
  const findErrorMessage = () => wrapper.findByTestId('error-alert');
  const findDraggable = () => wrapper.findComponent(Draggable);
  const findAllDropdowns = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const defaultOpenStatus = mockLifecycle.statuses[0]; // Open (default)
  const findDefaultOpenDropdownItem = () =>
    wrapper.findByTestId(`make-default-${defaultOpenStatus.id}`);

  const nonDefaultStatus = mockLifecycle.statuses[1]; // In progress
  const findNonDefaultDropdownItem = () =>
    wrapper.findComponentByTestId(`make-default-${nonDefaultStatus.id}`);

  const updateLifecycleHandler = jest.fn().mockResolvedValue(mockUpdateResponse);
  const metadataQueryHandler = jest.fn().mockResolvedValue(mockNamespaceMetadata);

  const addStatus = async (save = true) => {
    const addButton = findCategorySection('triage').findComponent(
      '[data-testid="add-status-button"]',
    );
    addButton.vm.$emit('click');
    await nextTick();

    findStatusForm().vm.$emit('update', newFormData);
    await nextTick();

    if (save) {
      findStatusForm().vm.$emit('save');
    }
  };

  const emitDragEnd = async (oldIndex, newIndex) => {
    await findDraggable().vm.$emit('end', {
      oldIndex,
      newIndex,
      item: document.createElement('div'),
      from: document.createElement('div'),
      to: document.createElement('div'),
    });
  };

  const createComponent = ({
    props = {},
    lifecycle = mockLifecycle,
    updateHandler = updateLifecycleHandler,
    statuses = [
      ...mockLifecycles[0].statuses,
      ...mockLifecycles[1].statuses,
      ...mockLifecycles[2].statuses,
    ],
  } = {}) => {
    mockApollo = createMockApollo([
      [lifecycleUpdateMutation, updateHandler],
      [namespaceMetadataQuery, metadataQueryHandler],
    ]);

    wrapper = shallowMountExtended(StatusLifecycleModal, {
      apolloProvider: mockApollo,
      propsData: {
        visible: true,
        lifecycle,
        fullPath: 'group/project',
        statuses,
        ...props,
      },
      stubs: {
        GlModal,
        GlSprintf,
        GlDisclosureDropdown: stubComponent(GlDisclosureDropdown, {
          methods: {
            close: jest.fn(),
          },
        }),
      },
    });
  };

  beforeEach(() => {
    // Mock gon for suggested colors
    global.gon = {
      suggested_label_colors: {
        '#FF0000': 'Red',
        '#00FF00': 'Green',
        '#0000FF': 'Blue',
      },
    };
  });

  describe('initial rendering', () => {
    it('displays modal when visible prop is true', () => {
      createComponent();

      expect(findModal().props('visible')).toBe(true);
    });

    it('shows lifecycle name and status info', () => {
      createComponent();

      expect(findStatusInfo().exists()).toBe(false);
      expect(findLifecycleInfo().exists()).toBe(true);
    });

    it('displays statuses grouped by category', () => {
      createComponent();

      expect(findCategorySection('to_do')).toBeDefined();
      expect(findCategorySection('in_progress')).toBeDefined();
      expect(findCategorySection('done')).toBeDefined();
      expect(findStatusBadges()).toHaveLength(3);
    });

    it('shows description of each category', () => {
      createComponent();

      expect(
        findCategorySection('to_do').find('[data-testid="category-description"]').exists(),
      ).toBe(true);
    });

    it('shows state of category when `workItemState` is CLOSED', () => {
      createComponent();

      expect(findCategorySection('done').findComponent(WorkItemStateBadge).exists()).toBe(true);
    });

    it('does not show state of category when `workItemState` is OPEN', () => {
      createComponent();

      expect(findCategorySection('to_do').findComponent(WorkItemStateBadge).exists()).toBe(false);
    });

    it('shows default status badges for default statuses', () => {
      createComponent();

      const badges = findDefaultStatusBadges();
      expect(badges).toHaveLength(2);
      expect(badges.at(0).text()).toBe('Open default');
      expect(badges.at(1).text()).toBe('Closed default');
    });

    it('shows add status buttons for each category', () => {
      createComponent();

      const categories = ['triage', 'to_do', 'in_progress', 'done', 'canceled'];
      categories.forEach((category) => {
        const section = findCategorySection(category);
        expect(section.find('[data-testid="add-status-button"]').exists()).toBe(true);
      });
    });

    it('shows the status help page link', () => {
      createComponent();

      expect(findHelpPageLink().exists()).toBe(true);
      expect(findHelpPageLink().props('href')).toBe('user/work_items/status');
    });
  });

  describe('modal visibility', () => {
    it('emits close event when modal is hidden', () => {
      createComponent();

      findModal().vm.$emit('hide');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('hides modal when visible prop is false', () => {
      createComponent({ props: { visible: false } });

      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('adding status', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows inline form when add status button is clicked', async () => {
      const addButton = findCategorySection('triage').findComponent(
        '[data-testid="add-status-button"]',
      );

      addButton.vm.$emit('click');
      await nextTick();

      expect(findStatusForm().exists()).toBe(true);
      expect(findStatusForm().props('isEditing')).toBe(false);
    });

    it('passes the `statuses` to the statusform excluding the current lifecycle', async () => {
      const addButton = findCategorySection('triage').findComponent(
        '[data-testid="add-status-button"]',
      );

      addButton.vm.$emit('click');
      await nextTick();

      const statusPropNames = findStatusForm()
        .props('statuses')
        .map((item) => item.name);
      const currentLifecycleStatusNames = mockLifecycle.statuses.map((item) => item.name);

      const overlappingStatusNames = statusPropNames.filter((name) =>
        currentLifecycleStatusNames.includes(name),
      );

      expect(overlappingStatusNames).toEqual([]);
    });

    it('pre-fills color based on category when adding status', async () => {
      const addButton = findCategorySection('done').findComponent(
        '[data-testid="add-status-button"]',
      );

      addButton.vm.$emit('click');
      await nextTick();

      expect(findStatusForm().props().formData.color).toBe('#108548'); // DONE category color
    });

    it('cancels add form when cancel event is emitted', async () => {
      const addButton = findCategorySection('triage').findComponent(
        '[data-testid="add-status-button"]',
      );
      addButton.vm.$emit('click');
      await nextTick();

      expect(findStatusForm().exists()).toBe(true);

      findStatusForm().vm.$emit('cancel');
      await nextTick();

      expect(findStatusForm().exists()).toBe(false);
    });
  });

  describe('editing status', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows inline edit form when edit button is clicked', async () => {
      findEditStatusButton('status-1').vm.$emit('action');
      await nextTick();

      expect(findStatusForm().exists()).toBe(true);
      expect(findStatusForm().props('isEditing')).toBe(true);
    });

    it('pre-fills form with existing status data when editing', async () => {
      findEditStatusButton('status-1').vm.$emit('action');
      await nextTick();

      expect(findStatusForm().props().formData).toEqual({
        name: 'Open',
        color: '#1f75cb',
        description: 'New issues',
      });
    });

    it('passes correct form data to inline form component', async () => {
      findEditStatusButton('status-1').vm.$emit('action');
      await nextTick();

      const inlineForm = findStatusForm();
      expect(inlineForm.props('formData')).toEqual({
        name: 'Open',
        color: '#1f75cb',
        description: 'New issues',
      });
    });
  });

  describe('form handling', () => {
    it('updates form data when inline form emits update event', async () => {
      createComponent();

      await addStatus(false);

      expect(findStatusForm().props().formData).toEqual(newFormData);
    });

    it('calls the update handler when adding status', async () => {
      createComponent();

      await addStatus();
      expect(updateLifecycleHandler).toHaveBeenCalled();
    });

    it('does not call the update handler when adding more than 30 statuses and shows error', async () => {
      const limitStatuses = [];

      for (let i = 0; i < 30; i += 1) {
        limitStatuses.push({
          id: `status-${i + 1}`,
          name: `Status-${i}`,
          color: '#ff0000',
          iconName: 'status-neutral',
          description: '',
          __typename: 'WorkItemStatus',
        });
      }

      const mockLimitLifecycle = {
        ...mockLifecycle,
        statuses: limitStatuses,
      };

      const mockLimitStatusResponse = {
        data: {
          lifecycleUpdate: {
            lifecycle: {
              ...mockLimitLifecycle,
              __typename: 'WorkItemLifecycle',
            },
            __typename: 'LifecycleUpdatePayload',
            errors: [],
          },
        },
      };

      const limitReachedHandler = jest.fn().mockResolvedValue(mockLimitStatusResponse);

      createComponent({ updateHandler: limitReachedHandler, lifecycle: mockLimitLifecycle });

      expect(findErrorMessage().exists()).toBe(false);

      await addStatus();

      expect(updateLifecycleHandler).not.toHaveBeenCalled();
      expect(findErrorMessage().exists()).toBe(true);
    });
  });

  describe('Reordering status', () => {
    it('can reorder within category when it has atleast 2 statuses', async () => {
      const lifecycle = {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/20',
        name: 'Default',
        defaultOpenStatus: {
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/165',
          name: 'To do',
          __typename: 'WorkItemStatus',
        },
        defaultClosedStatus: {
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
          name: 'Done',
          __typename: 'WorkItemStatus',
        },
        defaultDuplicateStatus: {
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/169',
          name: 'Duplicate',
          __typename: 'WorkItemStatus',
        },
        workItemTypes: [
          {
            id: 'gid://gitlab/WorkItems::Type/1',
            name: 'Issue',
            iconName: 'work-item-issue',
            __typename: 'WorkItemType',
          },
          {
            id: 'gid://gitlab/WorkItems::Type/5',
            name: 'Task',
            iconName: 'work-item-task',
            __typename: 'WorkItemType',
          },
        ],
        statuses: [
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/171',
            name: 'Triage 2',
            iconName: 'status-neutral',
            color: '#995715',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/172',
            name: 'Triage 3',
            iconName: 'status-neutral',
            color: '#995715',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/170',
            name: 'Triage',
            iconName: 'status-neutral',
            color: '#995715',
            description: '',
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/165',
            name: 'To do',
            iconName: 'status-waiting',
            color: '#737278',
            description: null,
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/166',
            name: 'In progress',
            iconName: 'status-running',
            color: '#1f75cb',
            description: null,
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
            name: 'Done',
            iconName: 'status-success',
            color: '#108548',
            description: null,
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/168',
            name: "Won't do",
            iconName: 'status-cancelled',
            color: '#DD2B0E',
            description: null,
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/169',
            name: 'Duplicate',
            iconName: 'status-cancelled',
            color: '#DD2B0E',
            description: null,
            __typename: 'WorkItemStatus',
          },
        ],
        __typename: 'WorkItemLifecycle',
      };

      const response = {
        data: {
          namespace: {
            id: 'gid://gitlab/Group/24',
            lifecycles: {
              nodes: [
                {
                  id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/20',
                  name: 'Default',
                  defaultOpenStatus: {
                    id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/165',
                    name: 'To do',
                    __typename: 'WorkItemStatus',
                  },
                  defaultClosedStatus: {
                    id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
                    name: 'Done',
                    __typename: 'WorkItemStatus',
                  },
                  defaultDuplicateStatus: {
                    id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/169',
                    name: 'Duplicate',
                    __typename: 'WorkItemStatus',
                  },
                  workItemTypes: [
                    {
                      id: 'gid://gitlab/WorkItems::Type/1',
                      name: 'Issue',
                      iconName: 'work-item-issue',
                      __typename: 'WorkItemType',
                    },
                    {
                      id: 'gid://gitlab/WorkItems::Type/5',
                      name: 'Task',
                      iconName: 'work-item-task',
                      __typename: 'WorkItemType',
                    },
                  ],
                  statuses: [
                    {
                      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/172',
                      name: 'Triage 3',
                      iconName: 'status-neutral',
                      color: '#995715',
                      description: '',
                      __typename: 'WorkItemStatus',
                    },
                    {
                      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/171',
                      name: 'Triage 2',
                      iconName: 'status-neutral',
                      color: '#995715',
                      description: '',
                      __typename: 'WorkItemStatus',
                    },
                    {
                      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/170',
                      name: 'Triage',
                      iconName: 'status-neutral',
                      color: '#995715',
                      description: '',
                      __typename: 'WorkItemStatus',
                    },
                    {
                      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/165',
                      name: 'To do',
                      iconName: 'status-waiting',
                      color: '#737278',
                      description: null,
                      __typename: 'WorkItemStatus',
                    },
                    {
                      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/166',
                      name: 'In progress',
                      iconName: 'status-running',
                      color: '#1f75cb',
                      description: null,
                      __typename: 'WorkItemStatus',
                    },
                    {
                      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
                      name: 'Done',
                      iconName: 'status-success',
                      color: '#108548',
                      description: null,
                      __typename: 'WorkItemStatus',
                    },
                    {
                      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/168',
                      name: "Won't do",
                      iconName: 'status-cancelled',
                      color: '#DD2B0E',
                      description: null,
                      __typename: 'WorkItemStatus',
                    },
                    {
                      id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/169',
                      name: 'Duplicate',
                      iconName: 'status-cancelled',
                      color: '#DD2B0E',
                      description: null,
                      __typename: 'WorkItemStatus',
                    },
                  ],
                  __typename: 'WorkItemLifecycle',
                },
              ],
              __typename: 'WorkItemLifecycleConnection',
            },
            __typename: 'Namespace',
          },
        },
      };

      const lifecycleUpdateHandler = jest.fn().mockResolvedValue(response);

      createComponent({ updateHandler: lifecycleUpdateHandler, lifecycle });

      // Make sure the draggable is not disabled
      expect(findDraggable().exists()).toBe(true);
      expect(findDraggable().attributes('disabled')).toBeUndefined();

      await emitDragEnd(0, 2);

      await waitForPromises();

      expect(lifecycleUpdateHandler).toHaveBeenCalled();
    });

    it('cannot reorder within category when it has 1 status', () => {
      const lifecycle = {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/20',
        name: 'Default',
        defaultOpenStatus: {
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/165',
          name: 'To do',
          __typename: 'WorkItemStatus',
        },
        defaultClosedStatus: {
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
          name: 'Done',
          __typename: 'WorkItemStatus',
        },
        defaultDuplicateStatus: {
          id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/169',
          name: 'Duplicate',
          __typename: 'WorkItemStatus',
        },
        workItemTypes: [
          {
            id: 'gid://gitlab/WorkItems::Type/1',
            name: 'Issue',
            iconName: 'work-item-issue',
            __typename: 'WorkItemType',
          },
          {
            id: 'gid://gitlab/WorkItems::Type/5',
            name: 'Task',
            iconName: 'work-item-task',
            __typename: 'WorkItemType',
          },
        ],
        statuses: [
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/165',
            name: 'To do',
            iconName: 'status-waiting',
            color: '#737278',
            description: null,
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/167',
            name: 'Done',
            iconName: 'status-success',
            color: '#108548',
            description: null,
            __typename: 'WorkItemStatus',
          },
          {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/169',
            name: 'Duplicate',
            iconName: 'status-cancelled',
            color: '#DD2B0E',
            description: null,
            __typename: 'WorkItemStatus',
          },
        ],
        __typename: 'WorkItemLifecycle',
      };

      createComponent({ lifecycle });

      // draggable exists but is disabled
      expect(findDraggable().exists()).toBe(true);
      expect(findDraggable().attributes('disabled')).toBeDefined();
    });

    it('network error handling', async () => {
      const updateHandler = jest.fn().mockRejectedValue('Ooopsie, error');

      createComponent({ updateHandler });

      expect(findErrorMessage().exists()).toBe(false);

      await emitDragEnd(0, 1);

      await waitForPromises();

      expect(findErrorMessage().exists()).toBe(true);
    });

    it('GraphQL error handling', async () => {
      const updateHandler = jest.fn().mockResolvedValue({
        data: {
          lifecycleUpdate: {
            lifecycle: null,
            __typename: 'WorkItemLifecycle',
          },
          __typename: 'LifecycleUpdatePayload',
          errors: ['Reorder failed'],
        },
      });

      createComponent({ updateHandler });

      expect(findErrorMessage().exists()).toBe(false);

      await emitDragEnd(0, 1);

      await waitForPromises();

      expect(findErrorMessage().exists()).toBe(true);
    });
  });

  describe('Status dropdown options', () => {
    it('all statuses of the lifecycle have the three dot options', () => {
      createComponent();

      expect(findAllDropdowns()).toHaveLength(mockLifecycle.statuses.length);
    });

    describe('Delete action', () => {
      it('shows "Remove status" modal', async () => {
        createComponent();
        const statusToRemove = mockLifecycle.statuses[0];
        const findFirstStatus = wrapper.findComponentByTestId(`remove-status-${statusToRemove.id}`);

        findFirstStatus.vm.$emit('action', statusToRemove);
        await nextTick();

        expect(findRemoveStatusModal().props()).toMatchObject({
          lifecycle: mockLifecycle,
          statusToRemove,
        });
      });
    });

    describe('Default action', () => {
      it('shows make default option for non-default statuses', () => {
        createComponent();

        expect(findNonDefaultDropdownItem().exists()).toBe(true);
        expect(findNonDefaultDropdownItem().text()).toBe('Make default for open items');
      });

      it('does not show make default option for default statuses', () => {
        createComponent();

        expect(findDefaultOpenDropdownItem().exists()).toBe(false);
      });

      it('calls `updateLifecycle` with correct default status', async () => {
        createComponent();

        findNonDefaultDropdownItem().vm.$emit('action', nonDefaultStatus, 'open');
        await waitForPromises();

        expect(updateLifecycleHandler).toHaveBeenCalled();
        expect(updateLifecycleHandler).toHaveBeenCalledWith({
          input: expect.objectContaining({
            defaultOpenStatusIndex: 1,
          }),
        });
      });
    });
  });
});
