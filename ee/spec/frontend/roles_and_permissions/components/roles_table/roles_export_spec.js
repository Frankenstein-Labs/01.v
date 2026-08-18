import { GlButton, GlSprintf, GlModal } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import groupMembersExportMutation from 'ee/roles_and_permissions/graphql/group_members_export.mutation.graphql';
import RolesExport from 'ee/roles_and_permissions/components/roles_table/roles_export.vue';
import { createAlert } from '~/alert';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('Roles export', () => {
  let wrapper;

  const createExportMutationHandler = (errors = []) =>
    jest.fn().mockResolvedValue({
      data: { groupMembersExport: { errors } },
    });
  const defaultExportMutationHandler = createExportMutationHandler();

  const createComponent = ({ exportMutationHandler = defaultExportMutationHandler } = {}) => {
    wrapper = shallowMountExtended(RolesExport, {
      apolloProvider: createMockApollo([[groupMembersExportMutation, exportMutationHandler]]),
      provide: { groupId: 5, currentUserEmail: 'abc@123.com' },
      stubs: { GlSprintf, ConfirmActionModal, GlModal },
    });
  };

  const findExportButton = () => wrapper.findComponent(GlButton);
  const findConfirmModal = () => wrapper.findComponent(ConfirmActionModal);

  it('shows export roles button', () => {
    createComponent();

    expect(findExportButton().text()).toBe('Export role report');
    expect(findExportButton().props('icon')).toBe('export');
  });

  describe('when export roles button is clicked', () => {
    beforeEach(() => {
      createComponent();
      findExportButton().vm.$emit('click');
    });

    it('shows confirmation modal', () => {
      expect(findConfirmModal().html()).toContain(
        'The CSV report contains a list of users, assigned role and access in all groups, subgroups, and projects. When the export is completed, it will be sent as an attachment to <code>abc@123.com</code>.',
      );
    });

    describe('when the modal is confirmed', () => {
      beforeEach(() => {
        findConfirmModal().vm.performAction();
        return waitForPromises();
      });

      it('runs export mutation', () => {
        expect(defaultExportMutationHandler).toHaveBeenCalledTimes(1);
        expect(defaultExportMutationHandler).toHaveBeenCalledWith({
          groupId: 'gid://gitlab/Group/5',
        });
      });

      it('shows alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Role report requested. CSV will be emailed to abc@123.com.',
          variant: 'info',
        });
      });
    });

    it('hides confirmation modal when it is closed', async () => {
      findConfirmModal().vm.$emit('close');
      await nextTick();

      expect(findConfirmModal().exists()).toBe(false);
    });
  });

  it('rejects promise when mutation has an error message', () => {
    createComponent({ exportMutationHandler: createExportMutationHandler(['error']) });

    return expect(wrapper.vm.exportRoles()).rejects.toEqual(
      'Unable to export role report. Contact support if this error persists.',
    );
  });
});
