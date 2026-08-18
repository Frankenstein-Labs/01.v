import { nextTick } from 'vue';
import { GlFormRadioGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogItemDeleteModal from 'ee/ai/catalog/components/ai_catalog_item_delete_modal.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { mockAgent } from '../mock_data';

describe('AiCatalogItemDeleteModal', () => {
  let wrapper;

  const deleteFn = jest.fn();

  beforeEach(() => {
    deleteFn.mockClear();
  });

  const createComponent = (props = {}, glAbilities = {}) => {
    wrapper = shallowMountExtended(AiCatalogItemDeleteModal, {
      propsData: {
        item: mockAgent,
        deleteFn,
        ...props,
      },
      provide: { glAbilities },
    });
  };

  const findConfirmModal = () => wrapper.findComponent(ConfirmActionModal);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);

  describe('when user can hard delete', () => {
    beforeEach(() => {
      createComponent(
        {
          item: {
            ...mockAgent,
            userPermissions: mockAgent.userPermissions,
          },
        },
        { forceHardDeleteAiCatalogItem: true },
      );
    });

    it('renders the confirm modal with a "Delete" title', () => {
      expect(findConfirmModal().props('title')).toContain('Delete');
    });

    it('renders the deletion method radio group', () => {
      expect(findRadioGroup().exists()).toBe(true);
    });

    it('selects hard delete by default', () => {
      expect(findRadioGroup().attributes('checked')).toBe('true');
    });

    it('calls deleteFn with true when confirmed without changing the selection', async () => {
      const actionFn = findConfirmModal().props('actionFn');
      await actionFn();

      expect(deleteFn).toHaveBeenCalledWith(true);
    });

    it('calls deleteFn with false when soft delete is selected', async () => {
      findRadioGroup().vm.$emit('input', false);
      await nextTick();

      const actionFn = findConfirmModal().props('actionFn');
      await actionFn();

      expect(deleteFn).toHaveBeenCalledWith(false);
    });
  });

  describe('when user cannot hard delete', () => {
    beforeEach(() => {
      createComponent(
        {
          item: {
            ...mockAgent,
            userPermissions: mockAgent.userPermissions,
          },
        },
        { forceHardDeleteAiCatalogItem: false },
      );
    });

    it('renders the confirm modal with a "Hide" title', () => {
      expect(findConfirmModal().props('title')).toContain('Hide');
    });

    it('does not render the deletion method radio group', () => {
      expect(findRadioGroup().exists()).toBe(false);
    });

    it('calls deleteFn with false when confirmed', async () => {
      const actionFn = findConfirmModal().props('actionFn');
      await actionFn();

      expect(deleteFn).toHaveBeenCalledWith(false);
    });
  });

  it('emits close when the confirm modal emits close', () => {
    createComponent();

    findConfirmModal().vm.$emit('close');

    expect(wrapper.emitted('close')).toHaveLength(1);
  });
});
