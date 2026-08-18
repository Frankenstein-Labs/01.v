import { GlAlert, GlModal, GlIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import lifecycleUpdateMutation from 'ee/groups/settings/work_items/custom_status/graphql/lifecycle_update.mutation.graphql';
import RemoveStatusModal from 'ee/groups/settings/work_items/custom_status/remove_status_modal.vue';
import RemoveStatusModalListbox from 'ee/groups/settings/work_items/custom_status/remove_status_modal_listbox.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mockLifecycles } from '../mock_data';

Vue.use(VueApollo);

describe('RemoveStatusModal', () => {
  let wrapper;

  const triageStatus = {
    id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/10',
    name: 'Triage!',
    iconName: 'status-neutral',
    color: '#995715',
    description: null,
    category: 'triage',
    __typename: 'WorkItemStatus',
  };
  const toDoStatus = {
    id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/20',
    name: 'To do!',
    iconName: 'status-waiting',
    color: '#737278',
    description: null,
    category: 'to_do',
    __typename: 'WorkItemStatus',
  };
  const inProgressStatus = {
    id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/30',
    name: 'In progress!',
    iconName: 'status-running',
    color: '#1f75cb',
    description: null,
    category: 'in_progress',
    __typename: 'WorkItemStatus',
  };
  const doneStatus = {
    id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/40',
    name: 'Mignon Kub',
    iconName: 'status-success',
    color: '#108548',
    description: null,
    category: 'done',
    __typename: 'WorkItemStatus',
  };
  const canceledStatus = {
    id: 'gid://gitlab/WorkItems::Statuses::Custom::Status/50',
    name: `Won't do!`,
    iconName: 'status-cancelled',
    color: '#DD2B0E',
    description: null,
    category: 'canceled',
    __typename: 'WorkItemStatus',
  };

  const lifecycleUpdateMutationHandler = jest.fn().mockResolvedValue({
    data: {
      lifecycleUpdate: {
        lifecycle: mockLifecycles[0],
        errors: [],
        __typename: 'LifecycleUpdatePayload',
      },
    },
  });

  const findModal = () => wrapper.findComponent(GlModal);
  const findCurrentStatus = () => wrapper.findByTestId('current-status-value');
  const findListboxLabels = () => wrapper.findAll('label');
  const findNewStatusListbox = () => wrapper.findComponent(RemoveStatusModalListbox);
  const findNewDefaultListbox = () => wrapper.findComponentByTestId('new-default-listbox');

  const createComponent = ({ props = {}, updateHandler = lifecycleUpdateMutationHandler } = {}) => {
    wrapper = shallowMountExtended(RemoveStatusModal, {
      apolloProvider: createMockApollo([[lifecycleUpdateMutation, updateHandler]]),
      propsData: {
        fullPath: 'full/path',
        lifecycle: mockLifecycles[0],
        statusToRemove: mockLifecycles[0].statuses[0],
        ...props,
      },
    });
  };

  describe('when status has items and other statuses exist in same state', () => {
    beforeEach(() => {
      const lifecycle = {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/9',
        name: 'Lifecycle!',
        workItemTypes: [],
        statuses: [triageStatus, toDoStatus, inProgressStatus, doneStatus, canceledStatus],
        statusCounts: [{ status: toDoStatus, count: '10' }],
        __typename: 'WorkItemLifecycle',
      };
      createComponent({ props: { lifecycle, statusToRemove: toDoStatus } });
    });

    it('renders the modal with title', () => {
      expect(findModal().props('title')).toBe('Remove status');
    });

    it('renders "new status" body text', () => {
      expect(wrapper.text()).toContain(
        'Select a new status to use for any items currently using this status.',
      );
    });

    it('renders the current status details', () => {
      expect(findCurrentStatus().findComponent(GlIcon).props('name')).toBe('status-waiting');
      expect(findCurrentStatus().findComponent(GlIcon).attributes('style')).toBe(
        'color: rgb(115, 114, 120);',
      );
      expect(findCurrentStatus().text()).toBe('To do!');
    });

    it('renders the new status selection label', () => {
      expect(findListboxLabels()).toHaveLength(1);
      expect(findListboxLabels().at(0).text()).toBe('New status');
    });

    it('filters listbox items to remove statusToRemove and keep statuses from same open/closed state', () => {
      // toDoStatus is not included since we're deleting it
      // doneStatus and canceledStatus are not included since they are closed states, and toDoStatus is an open state
      expect(findNewStatusListbox().props('items')).toMatchObject([triageStatus, inProgressStatus]);
    });

    it('pre-selects the first available status in the listbox', () => {
      expect(findNewStatusListbox().props('selected')).toEqual(triageStatus);
    });

    it('updates selectedNewStatusId when a new status is selected', async () => {
      findNewStatusListbox().vm.$emit('input', inProgressStatus.id);
      await nextTick();

      expect(findNewStatusListbox().props('value')).toBe(inProgressStatus.id);
    });

    it('emits hidden event when modal is hidden', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('hidden')).toEqual([[]]);
    });

    describe('when deleting status', () => {
      it('sends mutation to map old status to new status', async () => {
        findNewStatusListbox().vm.$emit('input', inProgressStatus.id);
        findModal().vm.$emit('primary', { preventDefault: jest.fn() });
        await waitForPromises();

        // Remove toDoStatus and map it to inProgressStatus
        expect(lifecycleUpdateMutationHandler).toHaveBeenCalledWith({
          input: {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/9',
            namespacePath: 'full/path',
            statuses: [triageStatus, inProgressStatus, doneStatus, canceledStatus].map(
              ({ id }) => ({ id }),
            ),
            statusMappings: [
              {
                newStatusId: inProgressStatus.id,
                oldStatusId: toDoStatus.id,
              },
            ],
          },
        });
        expect(wrapper.emitted('lifecycle-updated')).toEqual([[]]);
      });
    });
  });

  describe('when status is default status and other statuses exist in same state', () => {
    beforeEach(() => {
      const lifecycle = {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/9',
        name: 'Lifecycle!',
        defaultClosedStatus: doneStatus,
        workItemTypes: [],
        statuses: [triageStatus, toDoStatus, inProgressStatus, doneStatus, canceledStatus],
        statusCounts: [{ status: toDoStatus, count: '10' }],
        __typename: 'WorkItemLifecycle',
      };
      createComponent({ props: { lifecycle, statusToRemove: doneStatus } });
    });

    it('renders the modal with title', () => {
      expect(findModal().props('title')).toBe('Remove status');
    });

    it('renders "new status" body text', () => {
      expect(wrapper.text()).toContain(
        'This status is set as the Closed default. Select a new Closed default to remove this status.',
      );
    });

    it('renders the new status selection label', () => {
      expect(findListboxLabels()).toHaveLength(2);
      expect(findListboxLabels().at(0).text()).toBe('New status');
      expect(findListboxLabels().at(1).text()).toBe('Closed default');
    });

    it('filters listbox items to remove statusToRemove and keep statuses from same open/closed state', () => {
      // toDoStatus is not included since we're deleting it
      // doneStatus and canceledStatus are not included since they are closed states, and toDoStatus is an open state
      expect(findNewStatusListbox().props('items')).toMatchObject([canceledStatus]);
    });

    it('pre-selects the first available status in the listbox', () => {
      expect(findNewStatusListbox().props('selected')).toEqual(canceledStatus);
    });

    it('updates selectedNewStatusId when a new status is selected', async () => {
      findNewStatusListbox().vm.$emit('input', canceledStatus.id);
      await nextTick();

      expect(findNewStatusListbox().props('value')).toBe(canceledStatus.id);
    });

    it('emits hidden event when modal is hidden', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('hidden')).toEqual([[]]);
    });

    describe('when deleting status', () => {
      it('sends mutation to update to a new default status', async () => {
        findNewDefaultListbox().vm.$emit('input', canceledStatus.id);
        findModal().vm.$emit('primary', { preventDefault: jest.fn() });
        await waitForPromises();

        // Remove doneStatus, map it to canceledStatus, set default closed status to canceledStatus
        expect(lifecycleUpdateMutationHandler).toHaveBeenCalledWith({
          input: {
            id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/9',
            namespacePath: 'full/path',
            defaultClosedStatusIndex: 3,
            statuses: [triageStatus, toDoStatus, inProgressStatus, canceledStatus].map(
              ({ id }) => ({ id }),
            ),
            statusMappings: [
              {
                newStatusId: canceledStatus.id,
                oldStatusId: doneStatus.id,
              },
            ],
          },
        });
        expect(wrapper.emitted('lifecycle-updated')).toEqual([[]]);
      });
    });
  });

  describe('when status is default status and no other statuses exist in same state', () => {
    beforeEach(() => {
      const lifecycle = {
        id: 'gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/9',
        name: 'Lifecycle!',
        defaultClosedStatus: doneStatus,
        workItemTypes: [],
        statuses: [toDoStatus, doneStatus],
        statusCounts: [{ status: toDoStatus, count: '10' }],
        __typename: 'WorkItemLifecycle',
      };
      createComponent({ props: { lifecycle, statusToRemove: doneStatus } });
    });

    it('renders text', () => {
      expect(wrapper.text()).toBe(
        'This status is set as the Closed default, and no other Closed statuses exist. Create a "Done" or "Canceled" status to remove this status.',
      );
    });
  });

  it('displays an error message if the update fails', async () => {
    const mockErrorUpdateResponse = {
      data: {
        lifecycleUpdate: {
          lifecycle: null,
          errors: ['I am error'],
          __typename: 'LifecycleUpdatePayload',
        },
      },
    };
    createComponent({ updateHandler: jest.fn().mockResolvedValue(mockErrorUpdateResponse) });

    findModal().vm.$emit('primary', { preventDefault: jest.fn() });
    await waitForPromises();

    expect(wrapper.findComponent(GlAlert).text()).toBe('I am error');
    expect(wrapper.emitted('lifecycle-updated')).toBeUndefined();
  });
});
