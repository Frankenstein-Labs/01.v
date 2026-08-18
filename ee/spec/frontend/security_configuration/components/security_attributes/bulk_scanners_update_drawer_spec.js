import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { cloneDeep } from 'lodash-es';
import { GlDrawer } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BulkScannerUpdateDrawer from 'ee/security_inventory/components/bulk_scanners_update_drawer.vue';
import BulkScannerProfileConfiguration from 'ee/security_inventory/components/bulk_scanner_profile_configuration.vue';
import ScanProfileDetailsModal from 'ee/security_configuration/components/scan_profiles/scan_profile_details_modal.vue';
import SecurityScanProfileAttachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_attach.mutation.graphql';
import SecurityScanProfileDetachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_detach.mutation.graphql';

Vue.use(VueApollo);
jest.mock('~/alert');
jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');
const $toast = {
  show: jest.fn(),
};

describe('BulkScannerUpdateDrawer', () => {
  let wrapper;

  const mockProfile = {
    id: 'gid://gitlab/Security::ScanProfile/secret_detection',
    name: 'Secret Detection (default)',
  };
  const attachHandler = jest.fn().mockResolvedValue({
    data: {
      securityScanProfileAttach: { errors: [], clientMutationId: 1 },
    },
  });
  const detachHandler = jest.fn().mockResolvedValue({
    data: {
      securityScanProfileDetach: { errors: [], clientMutationId: 1 },
    },
  });
  const errorHandlers = [
    [SecurityScanProfileAttachMutation, jest.fn().mockRejectedValue()],
    [SecurityScanProfileDetachMutation, jest.fn().mockRejectedValue()],
  ];

  const createComponent = (
    handlers = [
      [SecurityScanProfileAttachMutation, attachHandler],
      [SecurityScanProfileDetachMutation, detachHandler],
    ],
  ) => {
    confirmAction.mockResolvedValue(true);
    wrapper = shallowMountExtended(BulkScannerUpdateDrawer, {
      provide: {
        groupFullPath: 'path/to/group',
      },
      propsData: {
        itemIds: ['gid://gitlab/Group/102', 'gid://gitlab/Project/23'],
      },
      apolloProvider: createMockApollo(handlers),
      mocks: {
        $toast,
      },
    });
  };

  describe('preview', () => {
    it('opens the modal to preview the profile', async () => {
      createComponent();

      wrapper
        .findComponent(BulkScannerProfileConfiguration)
        .vm.$emit('preview-profile', mockProfile);
      await waitForPromises();

      expect(wrapper.findComponent(ScanProfileDetailsModal).props()).toMatchObject({
        visible: true,
        profileId: mockProfile.id,
      });
    });

    it('calls the bulk scan profile attach mutation when the modal emits preview-profile', async () => {
      createComponent();

      wrapper.findComponent(ScanProfileDetailsModal).vm.$emit('apply', mockProfile.id);
      await waitForPromises();

      expect(attachHandler).toHaveBeenCalledWith({
        input: {
          groupIds: ['gid://gitlab/Group/102'],
          projectIds: ['gid://gitlab/Project/23'],
          securityScanProfileId: mockProfile.id,
        },
      });
      expect($toast.show).toHaveBeenCalledWith('Profile applied successfully.');
    });
  });

  describe('attach', () => {
    it('calls the bulk scan profile attach mutation when configuration emits attach-profile', async () => {
      createComponent();

      wrapper
        .findComponent(BulkScannerProfileConfiguration)
        .vm.$emit('attach-profile', mockProfile.id);
      await waitForPromises();

      expect(attachHandler).toHaveBeenCalledWith({
        input: {
          groupIds: ['gid://gitlab/Group/102'],
          projectIds: ['gid://gitlab/Project/23'],
          securityScanProfileId: mockProfile.id,
        },
      });
      expect($toast.show).toHaveBeenCalledWith('Profile applied successfully.');
      expect(
        cloneDeep(wrapper.findComponent(BulkScannerProfileConfiguration).props('statusPatches')),
      ).toMatchObject({
        [mockProfile.id]: { status: 'enabled' },
      });
    });

    it('shows an alert when attach fails', async () => {
      createComponent(errorHandlers);

      wrapper
        .findComponent(BulkScannerProfileConfiguration)
        .vm.$emit('attach-profile', mockProfile);
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        containerSelector: '.scanners-drawer-flash-container',
        error: expect.any(Error),
        message: 'An error has occurred while applying the scan profile.',
      });
    });
  });

  describe('detach', () => {
    it('calls the bulk scan profile detach mutation when configuration emits detach-profile', async () => {
      createComponent();

      wrapper
        .findComponent(BulkScannerProfileConfiguration)
        .vm.$emit('detach-profile', mockProfile);
      await waitForPromises();

      expect(detachHandler).toHaveBeenCalledWith({
        input: {
          groupIds: ['gid://gitlab/Group/102'],
          projectIds: ['gid://gitlab/Project/23'],
          securityScanProfileId: mockProfile.id,
        },
      });
      expect($toast.show).toHaveBeenCalledWith('Secret Detection (default) disabled');
      expect(
        cloneDeep(wrapper.findComponent(BulkScannerProfileConfiguration).props('statusPatches')),
      ).toMatchObject({
        [mockProfile.id]: { status: 'disabled' },
      });
    });

    it('shows an alert when detach fails', async () => {
      createComponent(errorHandlers);

      wrapper
        .findComponent(BulkScannerProfileConfiguration)
        .vm.$emit('detach-profile', mockProfile);
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        containerSelector: '.scanners-drawer-flash-container',
        error: expect.any(Error),
        message: 'An error has occurred while disabling the scan profile.',
      });
    });
  });

  describe('close', () => {
    it('triggers a refetch', async () => {
      createComponent();

      wrapper.findComponent(GlDrawer).vm.$emit('close');
      await waitForPromises();

      expect(wrapper.emitted('refetch')).toStrictEqual([[]]);
    });
  });
});
