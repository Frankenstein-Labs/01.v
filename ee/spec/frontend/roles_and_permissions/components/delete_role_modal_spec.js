import { GlModal } from '@gitlab/ui';
import Vue from 'vue';
import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import DeleteRoleModal from 'ee/roles_and_permissions/components/delete_role_modal.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import deleteMemberRoleMutation from 'ee/roles_and_permissions/graphql/delete_member_role.mutation.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';

Vue.use(VueApollo);

const defaultRole = { id: 5 };

const getDeleteMutationHandler = (error) =>
  jest.fn().mockResolvedValue({ data: { memberRoleDelete: { errors: error ? [error] : [] } } });

const defaultDeleteMutationHandler = getDeleteMutationHandler();

describe('Delete role modal', () => {
  let wrapper;

  const createComponent = ({
    role = defaultRole,
    deleteMutationHandler = defaultDeleteMutationHandler,
  } = {}) => {
    wrapper = shallowMount(DeleteRoleModal, {
      propsData: { role },
      apolloProvider: createMockApollo([[deleteMemberRoleMutation, deleteMutationHandler]]),
      stubs: { ConfirmActionModal },
    });
  };

  const findModal = () => wrapper.findComponent(ConfirmActionModal);
  const confirmModalAction = () => {
    findModal().findComponent(GlModal).vm.$emit('primary', { preventDefault: jest.fn() });
    return waitForPromises();
  };

  describe('when there is no role', () => {
    beforeEach(() => createComponent({ role: null }));

    it('does not show modal', () => {
      expect(findModal().exists()).toBe(false);
    });
  });

  describe('when there is a role', () => {
    beforeEach(() => createComponent());

    it('shows modal', () => {
      expect(findModal().text()).toBe('Are you sure you want to delete this role?');
      expect(findModal().props()).toMatchObject({
        title: 'Delete role?',
        actionText: 'Delete role',
        actionFn: wrapper.vm.deleteRole,
        modalId: 'delete-role-modal',
      });
    });

    describe('when the modal is closed', () => {
      it('emits close event', () => {
        findModal().vm.$emit('close');

        expect(wrapper.emitted('close')).toHaveLength(1);
      });
    });

    describe('when the modal action is confirmed', () => {
      beforeEach(() => confirmModalAction());

      it('runs delete mutation', () => {
        expect(defaultDeleteMutationHandler).toHaveBeenCalledTimes(1);
        expect(defaultDeleteMutationHandler).toHaveBeenCalledWith({
          id: 'gid://gitlab/MemberRole/5',
        });
      });

      it('emits deleted event', () => {
        expect(wrapper.emitted('deleted')).toHaveLength(1);
      });
    });
  });

  describe('when the mutation succeeds but returns an error', () => {
    beforeEach(() => {
      createComponent({ deleteMutationHandler: getDeleteMutationHandler('some error') });
      return confirmModalAction();
    });

    it('shows specific error in the modal', () => {
      expect(findModal().text()).toContain('Failed to delete role. some error');
    });
  });

  describe('when the mutation call itself fails', () => {
    beforeEach(() => {
      createComponent({ deleteMutationHandler: jest.fn().mockRejectedValue() });
      return confirmModalAction();
    });

    it('shows general error in the modal', () => {
      expect(findModal().text()).toContain('Failed to delete role.');
    });
  });
});
