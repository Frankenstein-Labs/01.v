import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ArchiveWorkItemTypeModal from 'ee/work_items/components/archive_work_item_type_modal.vue';
import workItemTypeUpdateMutation from 'ee/work_items/graphql/update_work_item_type.mutation.graphql';

Vue.use(VueApollo);

describe('ArchiveWorkItemTypeModal', () => {
  let wrapper;

  const mockActiveWorkItemType = {
    id: 'gid://gitlab/WorkItems::Type/1',
    name: 'Bug',
    archived: false,
    __typename: 'WorkItemType',
  };

  const successMutationHandler = jest.fn().mockResolvedValue({
    data: {
      workItemTypeUpdate: {
        workItemType: {
          id: 'gid://gitlab/WorkItems::Type/1',
          name: 'Bug',
          iconName: 'issue-type-issue',
          archived: true,
          __typename: 'WorkItemType',
        },
        errors: [],
        __typename: 'WorkItemTypeUpdatePayload',
      },
    },
  });

  const errorMutationHandler = jest.fn().mockResolvedValue({
    data: {
      workItemTypeUpdate: {
        workItemType: null,
        errors: ['Something went wrong'],
        __typename: 'WorkItemTypeUpdatePayload',
      },
    },
  });

  const networkErrorMutationHandler = jest.fn().mockRejectedValue(new Error('Network error'));

  const createWrapper = ({ props = {}, mutationHandler = successMutationHandler } = {}) => {
    const mockApollo = createMockApollo([[workItemTypeUpdateMutation, mutationHandler]]);

    wrapper = shallowMountExtended(ArchiveWorkItemTypeModal, {
      apolloProvider: mockApollo,
      propsData: {
        fullPath: 'test-group',
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  describe('visibility', () => {
    it('is not visible when workItemType is null', () => {
      createWrapper({ props: { workItemType: null } });

      expect(findModal().props('visible')).toBe(false);
    });

    it('is visible when workItemType is provided', () => {
      createWrapper({ props: { workItemType: mockActiveWorkItemType } });

      expect(findModal().props('visible')).toBe(true);
    });
  });

  describe('archive action', () => {
    beforeEach(() => {
      createWrapper({ props: { workItemType: mockActiveWorkItemType } });
    });

    it('displays archive title with type name', () => {
      expect(findModal().props('title')).toBe('Archive type: Bug');
    });

    it('displays archive confirmation message', () => {
      expect(wrapper.text()).toContain(
        'Archiving a work item type will make it unusable in all groups and projects. Items already using this type will keep this type and may be changed to other types.',
      );
    });

    it('displays archive as primary action with `confirm` variant', () => {
      expect(findModal().props('actionPrimary')).toEqual({
        text: 'Archive',
        attributes: { variant: 'confirm', loading: false },
      });
    });

    it('displays cancel button', () => {
      expect(findModal().props('actionCancel')).toEqual({
        text: 'Cancel',
        attributes: { disabled: false },
      });
    });
  });

  describe('mutation', () => {
    it('calls update mutation with archive=true', async () => {
      createWrapper({ props: { workItemType: mockActiveWorkItemType } });

      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await waitForPromises();

      expect(successMutationHandler).toHaveBeenCalledWith({
        input: {
          id: mockActiveWorkItemType.id,
          archive: true,
          fullPath: 'test-group',
        },
      });
    });

    it('does not include fullPath when it is empty', async () => {
      createWrapper({
        props: { workItemType: mockActiveWorkItemType, fullPath: '' },
      });

      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await waitForPromises();

      expect(successMutationHandler).toHaveBeenCalledWith({
        input: {
          id: mockActiveWorkItemType.id,
          archive: true,
        },
      });
    });

    it('emits success event on successful mutation', async () => {
      createWrapper({ props: { workItemType: mockActiveWorkItemType } });

      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await waitForPromises();

      expect(wrapper.emitted('success')).toEqual([
        [{ archived: true, workItemType: mockActiveWorkItemType }],
      ]);
    });

    it('emits close event after successful mutation', async () => {
      createWrapper({ props: { workItemType: mockActiveWorkItemType } });

      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await waitForPromises();

      expect(wrapper.emitted('close')).toHaveLength(1);
    });

    it('emits error event when mutation returns errors', async () => {
      createWrapper({
        props: { workItemType: mockActiveWorkItemType },
        mutationHandler: errorMutationHandler,
      });

      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([[{ message: 'Something went wrong' }]]);
    });

    it('emits error event on network error', async () => {
      createWrapper({
        props: { workItemType: mockActiveWorkItemType },
        mutationHandler: networkErrorMutationHandler,
      });

      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([[{ message: 'Network error' }]]);
    });

    it('emits close event even on error', async () => {
      createWrapper({
        props: { workItemType: mockActiveWorkItemType },
        mutationHandler: errorMutationHandler,
      });

      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await waitForPromises();

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });

  describe('modal hidden event', () => {
    it('emits close when modal is hidden', () => {
      createWrapper({ props: { workItemType: mockActiveWorkItemType } });

      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });
});
