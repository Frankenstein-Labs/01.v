import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlIcon, GlFormRadio, GlCollapsibleListbox, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import LifecycleDetail from 'ee/groups/settings/work_items/custom_status/lifecycle_detail.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import LifecycleNameForm from 'ee/groups/settings/work_items/custom_status/lifecycle_name_form.vue';
import RemoveLifecycleConfirmationModal from 'ee/groups/settings/work_items/custom_status/remove_lifecycle_confirmation_modal.vue';
import removeLifecycleMutation from 'ee/groups/settings/work_items/custom_status/graphql/remove_lifecycle.mutation.graphql';
import { mockLifecycles, removeLifecycleSuccessResponse } from '../mock_data';

Vue.use(VueApollo);

describe('LifecycleDetail', () => {
  let wrapper;
  let mockApollo;

  const mockToast = {
    show: jest.fn(),
  };

  const mockLifecycle = {
    ...mockLifecycles[0],
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
  };

  const lifecycleWithoutTypes = {
    ...mockLifecycle,
    workItemTypes: [],
  };

  const lifecycleId = getIdFromGraphQLId(mockLifecycle.id);

  const findLifecycleDetail = () => wrapper.findByTestId('lifecycle-detail');
  const findRadioSelectionSlot = () => wrapper.findByTestId(`lifecycle-${lifecycleId}-select`);
  const findWorkItemTypeIcons = () =>
    wrapper.findByTestId(`lifecycle-${lifecycleId}-usage`).findAllComponents(GlIcon);
  const findWorkItemTypeNames = () => wrapper.findAllByTestId('work-item-type-name');
  const findUsageSection = () => wrapper.findByTestId(`lifecycle-${lifecycleId}-usage`);
  const findChangeLifecycleButton = () => findUsageSection().findComponent(GlButton);
  const findChangeLifecycleListBox = () => findUsageSection().findComponent(GlCollapsibleListbox);
  const findNotUsageSection = () => wrapper.findByTestId(`lifecycle-${lifecycleId}-no-usage`);
  const findLifecycleForm = () => wrapper.findComponent(LifecycleNameForm);
  const findRemoveLifecycleButton = () =>
    wrapper.findComponentByTestId(`remove-lifecycle-${lifecycleId}`);
  const findConfirmationModal = () => wrapper.findComponent(RemoveLifecycleConfirmationModal);
  const removeLifecycleSucessHandler = jest.fn().mockResolvedValue(removeLifecycleSuccessResponse);

  const createWrapper = (props = {}) => {
    mockApollo = createMockApollo([[removeLifecycleMutation, removeLifecycleSucessHandler]]);

    wrapper = shallowMountExtended(LifecycleDetail, {
      apolloProvider: mockApollo,
      propsData: {
        lifecycle: mockLifecycle,
        fullPath: 'test-group',
        ...props,
      },
      mocks: {
        $toast: mockToast,
      },
      stubs: {
        GlIcon,
        GlFormRadio,
        WorkItemStatusBadge,
        LifecycleNameForm,
        RemoveLifecycleConfirmationModal,
      },
    });
  };

  describe('default rendering', () => {
    beforeEach(() => {
      createWrapper({ showUsageSection: true });
    });

    it('renders the component with correct test id and styling', () => {
      expect(findLifecycleDetail().exists()).toBe(true);
      expect(findLifecycleDetail().classes()).toEqual([
        'gl-border',
        'gl-rounded-lg',
        'gl-bg-white',
        'gl-px-4',
        'gl-pt-4',
      ]);
    });

    it('renders lifecycle form with correct props when not a default cycle', () => {
      expect(findLifecycleForm().props('isLifecycleTemplate')).toBe(false);
    });

    it('displays work item types with icons and names', () => {
      expect(findWorkItemTypeIcons()).toHaveLength(mockLifecycle.workItemTypes.length);

      findWorkItemTypeIcons().wrappers.forEach((icon, index) => {
        expect(icon.props('name')).toBe(mockLifecycle.workItemTypes[index].iconName);
      });

      // Check that work item type names are displayed
      findWorkItemTypeNames().wrappers.forEach((span, index) => {
        expect(span.text()).toContain(mockLifecycle.workItemTypes[index].name);
      });
    });

    it('displays usage section when work item types exist', () => {
      expect(findUsageSection().exists()).toBe(true);
      expect(findUsageSection().text()).toContain('Usage:');
    });

    it('shows a list box to change lifecycle when the work item types length is more than one', () => {
      expect(findChangeLifecycleButton().exists()).toBe(false);
      expect(findChangeLifecycleListBox().exists()).toBe(true);
    });

    it('shows a button to change the lifecycle when the work item types length is one', () => {
      createWrapper({
        showUsageSection: true,
        lifecycle: {
          ...mockLifecycle,
          workItemTypes: [
            {
              id: 'gid://gitlab/WorkItems::Type/1',
              name: 'Issue',
              iconName: 'work-item-issue',
              __typename: 'WorkItemType',
            },
          ],
        },
      });

      expect(findChangeLifecycleButton().exists()).toBe(true);
      expect(findChangeLifecycleListBox().exists()).toBe(false);
    });

    it('displays the not usage section when `showNotInUseSection` to be true and no work item types associated to lifecycle', () => {
      createWrapper({
        showNotInUseSection: true,
        lifecycle: {
          ...mockLifecycle,
          workItemTypes: [],
        },
      });

      expect(findNotUsageSection().exists()).toBe(true);
    });

    it('does not display the not in use section when `showNotInUseSection` be true but has work item types associated to lifecycles', () => {
      createWrapper({ showNotInUseSection: true });
      expect(findNotUsageSection().exists()).toBe(false);
    });
  });

  describe('when `isLifecycleTemplate` is true', () => {
    beforeEach(() => {
      createWrapper({ isLifecycleTemplate: true });
    });

    it('renders lifecycle form with correct props when default lifecycle', () => {
      expect(findLifecycleForm().props('isLifecycleTemplate')).toBe(true);
    });
  });

  describe('when showRadioSelection is true', () => {
    beforeEach(() => {
      createWrapper({ showRadioSelection: true });
    });

    it('shows radio selection slot instead of heading', () => {
      expect(findLifecycleForm().exists()).toBe(false);
      expect(findRadioSelectionSlot().exists()).toBe(true);
    });
  });

  describe('when lifecycle has no work item types', () => {
    beforeEach(() => {
      createWrapper({ lifecycle: lifecycleWithoutTypes });
    });

    it('does not display the usage section', () => {
      expect(findUsageSection().exists()).toBe(false);
    });
  });

  describe('remove lifecycle', () => {
    beforeEach(() => {
      createWrapper({ lifecycle: lifecycleWithoutTypes, showNotInUseSection: true });
    });

    it('shows the remove lifecycle button in not in use section', () => {
      expect(findRemoveLifecycleButton().exists()).toBe(true);
      expect(findNotUsageSection().exists()).toBe(true);
    });

    it('does not show the remove lifecycle button when the showRemoveLifecycleCta is false', () => {
      createWrapper({ showRemoveLifecycleCta: false });
      expect(findRemoveLifecycleButton().exists()).toBe(false);
    });

    it('shows confirmation modal when remove button is clicked', async () => {
      findRemoveLifecycleButton().vm.$emit('click');
      await nextTick();

      expect(findConfirmationModal().props('isVisible')).toBe(true);
      expect(findConfirmationModal().props('lifecycleName')).toBe(mockLifecycle.name);
    });

    it('hides confirmation modal when cancel is emitted', async () => {
      // First show the modal
      findRemoveLifecycleButton().vm.$emit('click');
      await nextTick();
      expect(findConfirmationModal().props('isVisible')).toBe(true);

      // Then cancel
      findConfirmationModal().vm.$emit('cancel');
      await nextTick();

      expect(findConfirmationModal().props('isVisible')).toBe(false);
    });

    describe('remove action', () => {
      beforeEach(async () => {
        createWrapper({ lifecycle: lifecycleWithoutTypes, showNotInUseSection: true });

        // Show modal and confirm deletion
        findRemoveLifecycleButton().vm.$emit('click');
        await nextTick();
        findConfirmationModal().vm.$emit('continue');
        return waitForPromises();
      });

      it('calls mutation with correct variables', () => {
        expect(removeLifecycleSucessHandler).toHaveBeenCalledWith({
          input: {
            namespacePath: 'test-group',
            id: mockLifecycle.id,
          },
        });
      });

      it('hides the confirmation modal', () => {
        expect(findConfirmationModal().props('isVisible')).toBe(false);
      });

      it('emits deleted event', () => {
        expect(wrapper.emitted('deleted')).toHaveLength(1);
      });

      it('shows success toast message', async () => {
        await nextTick();
        expect(mockToast.show).toHaveBeenCalledWith('Lifecycle deleted.');
      });
    });
  });
});
