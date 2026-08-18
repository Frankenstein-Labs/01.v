<script>
import { GlDrawer, GlSprintf, GlToastMixin } from '@gitlab/ui';
import { __, n__, s__, sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { createAlert } from '~/alert';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import {
  SCAN_PROFILE_I18N,
  SCAN_PROFILE_STATUS_APPLIED,
  SCAN_PROFILE_STATUS_DISABLED,
  EVENT_PREVIEW_SCAN_PROFILE,
} from '~/security_configuration/constants';
import ScanProfileDetailsModal from 'ee/security_configuration/components/scan_profiles/scan_profile_details_modal.vue';
import SecurityScanProfileAttachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_attach.mutation.graphql';
import SecurityScanProfileDetachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_detach.mutation.graphql';
import BulkScannerProfileConfiguration from './bulk_scanner_profile_configuration.vue';

export default {
  name: 'BulkScannersUpdateDrawer',
  components: {
    GlDrawer,
    GlSprintf,
    BulkScannerProfileConfiguration,
    ScanProfileDetailsModal,
  },
  mixins: [InternalEvents.mixin(), GlToastMixin],
  inject: ['groupFullPath'],
  props: {
    itemIds: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['refetch'],
  data() {
    return {
      isDrawerOpen: false,
      previewProfileId: '',
      previewModalVisible: false,
      statusPatches: {},
      lastStatusPatch: '',
    };
  },
  computed: {
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
    groupIds() {
      return this.itemIds.filter((id) => id.includes('Group'));
    },
    projectIds() {
      return this.itemIds.filter((id) => id.includes('Project'));
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties
    openDrawer() {
      this.isDrawerOpen = true;
    },
    closeDrawer() {
      this.$emit('refetch');
      this.isDrawerOpen = false;

      // clear temporary status patches
      this.statusPatches = {};
      this.lastStatusPatch = '';
    },
    openPreview({ id }) {
      this.trackEvent(EVENT_PREVIEW_SCAN_PROFILE);
      this.previewProfileId = id;
      this.previewModalVisible = true;
    },
    closePreview() {
      this.previewModalVisible = false;
      this.previewProfileId = '';
    },
    async attachProfile(profileOrId) {
      const { id = profileOrId, name } = profileOrId;
      await this.$apollo
        .mutate({
          mutation: SecurityScanProfileAttachMutation,
          variables: {
            input: {
              securityScanProfileId: id,
              groupIds: this.groupIds,
              projectIds: this.projectIds,
            },
          },
        })
        .then(() => {
          // set profile status when attach request succeeds
          this.statusPatches[id] = { status: SCAN_PROFILE_STATUS_APPLIED };
          this.lastStatusPatch = `${id}:${SCAN_PROFILE_STATUS_APPLIED}`;

          if (name) {
            this.$toast.show(sprintf(s__('SecurityInventory|%{name} applied'), { name }));
          } else {
            this.$toast.show(SCAN_PROFILE_I18N.successApplying);
          }
          this.closePreview();
        })
        .catch((error) => {
          createAlert({
            message: s__(
              'SecurityInventory|An error has occurred while applying the scan profile.',
            ),
            containerSelector: `.${this.$options.DRAWER_FLASH_CONTAINER_CLASS}`,
            error,
          });
        });
    },
    async detachProfile({ id, name }) {
      const confirmed = await confirmAction(
        sprintf(
          n__(
            'SecurityInventory|You are about to disable %{name} for %{count} item. Are you sure you want to proceed?',
            'SecurityInventory|You are about to disable %{name} for %{count} items. Are you sure you want to proceed?',
            this.itemIds.length,
          ),
          { name, count: this.itemIds.length },
        ),
        {
          primaryBtnText: sprintf(__('Disable %{name}'), { name }),
          primaryBtnVariant: 'danger',
        },
      );
      if (!confirmed) {
        return;
      }
      await this.$apollo
        .mutate({
          mutation: SecurityScanProfileDetachMutation,
          variables: {
            input: {
              securityScanProfileId: id,
              groupIds: this.groupIds,
              projectIds: this.projectIds,
            },
          },
        })
        .then(() => {
          // set profile status when detach request succeeds
          this.statusPatches[id] = { status: SCAN_PROFILE_STATUS_DISABLED };
          this.lastStatusPatch = `${id}:${SCAN_PROFILE_STATUS_DISABLED}`;

          this.$toast.show(sprintf(s__('SecurityInventory|%{name} disabled'), { name }));
        })
        .catch((error) => {
          createAlert({
            message: s__(
              'SecurityInventory|An error has occurred while disabling the scan profile.',
            ),
            containerSelector: `.${this.$options.DRAWER_FLASH_CONTAINER_CLASS}`,
            error,
          });
        });
    },
  },
  DRAWER_Z_INDEX,
  DRAWER_FLASH_CONTAINER_CLASS: 'scanners-drawer-flash-container',
};
</script>

<template>
  <gl-drawer
    :open="isDrawerOpen"
    :header-height="getDrawerHeaderHeight"
    class="!gl-w-[100cqw] !gl-max-w-5xl"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="closeDrawer"
  >
    <template #title>
      <h4 class="gl-my-0 gl-mr-3 gl-text-size-h2">
        <gl-sprintf
          :message="
            n__(
              'SecurityInventory|Edit security scanners for %d item',
              'SecurityInventory|Edit security scanners for %d items',
              itemIds.length,
            )
          "
        >
          <template #itemCount>{{ itemIds.length }}</template>
        </gl-sprintf>
      </h4>
    </template>

    <div :class="$options.DRAWER_FLASH_CONTAINER_CLASS" class="!gl-py-0"></div>

    <bulk-scanner-profile-configuration
      :status-patches="statusPatches"
      :last-status-patch="lastStatusPatch"
      @preview-profile="openPreview"
      @attach-profile="attachProfile"
      @detach-profile="detachProfile"
    />
    <scan-profile-details-modal
      :profile-id="previewProfileId"
      :visible="previewModalVisible"
      @apply="attachProfile"
      @close="closePreview"
    />
  </gl-drawer>
</template>
