<script>
import {
  GlAlert,
  GlButton,
  GlButtonGroup,
  GlCollapsibleListbox,
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlIcon,
  GlLink,
  GlLoadingIcon,
  GlTooltipDirective,
  GlToastMixin,
} from '@gitlab/ui';
import { PROMO_URL } from '~/constants';
import { InternalEvents } from '~/tracking';
import {
  SCAN_PROFILE_CATEGORIES,
  SCAN_PROFILE_PROMO_ITEMS,
  SCAN_PROFILE_I18N,
  SCAN_PROFILE_SCANNER_HEALTH_FAILED,
  SCAN_PROFILE_SCANNER_HEALTH_UNCONFIGURED,
  SCAN_PROFILE_SCANNER_HEALTH_WARNING,
  EVENT_PREVIEW_SCAN_PROFILE,
  GRAPHQL_STATUS_MAP,
} from '~/security_configuration/constants';
import ScanProfileTable from '~/security_configuration/components/scan_profiles/scan_profile_table.vue';
import availableProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/group_available_security_scan_profiles.query.graphql';
import projectProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/project_security_scan_profiles.query.graphql';
import attachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_attach.mutation.graphql';
import detachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_detach.mutation.graphql';
import scanProfileStatusesQuery from 'ee/security_configuration/graphql/scan_profiles/scan_profile_statuses.query.graphql';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DisableScanProfileConfirmationModal from './disable_scan_profile_confirmation_modal.vue';
import ScannerStatusIcon from './scanner_status_icon.vue';
import ScanProfileDetailsModal from './scan_profile_details_modal.vue';
import InsufficientPermissionsPopover from './insufficient_permissions_popover.vue';
import ScanProfileLaunchModal from './scan_profile_launch_modal.vue';
import LastScanCell from './last_scan_cell.vue';
import TroubleshootJobDrawer from './troubleshoot_job_drawer.vue';

const APPLICATION_SECURITY_TESTING_PROMO_URL = `${PROMO_URL}/solutions/application-security-testing/`;

export default {
  name: 'ScanProfileConfigurationEE',
  components: {
    GlButtonGroup,
    GlButton,
    GlCollapsibleListbox,
    GlIcon,
    GlAlert,
    GlLink,
    ScanProfileTable,
    DisableScanProfileConfirmationModal,
    ScanProfileDetailsModal,
    LastScanCell,
    InsufficientPermissionsPopover,
    ScanProfileLaunchModal,
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlLoadingIcon,
    TroubleshootJobDrawer,
    ScannerStatusIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin(), InternalEvents.mixin(), GlToastMixin],
  inject: ['projectFullPath', 'groupFullPath', 'canApplyProfiles', 'securityScanProfilesLicensed'],
  SCAN_PROFILE_I18N,
  APPLICATION_SECURITY_TESTING_PROMO_URL,
  apollo: {
    availableProfiles: {
      skip() {
        return !this.securityScanProfilesLicensed;
      },
      query: availableProfilesQuery,
      variables() {
        return { fullPath: this.groupFullPath };
      },
      update: (data) => data?.group?.availableSecurityScanProfiles || [],
      error(error) {
        this.showError(SCAN_PROFILE_I18N.errorLoadingProfiles);
        Sentry.captureException(error);
      },
    },
    attachedProfiles: {
      skip() {
        return !this.securityScanProfilesLicensed;
      },
      query: projectProfilesQuery,
      variables() {
        return { fullPath: this.projectFullPath };
      },
      update: (data) => data?.project?.securityScanProfiles || [],
      result({ data, error }) {
        if (!error && data) {
          this.projectId = data?.project?.id;
        }
      },
      error(error) {
        this.showError(SCAN_PROFILE_I18N.errorLoadingProfiles);
        Sentry.captureException(error);
      },
    },
    statuses: {
      skip() {
        return (
          !this.glFeatures.securityScanProfilesStatusIndicators ||
          !this.securityScanProfilesLicensed
        );
      },
      query: scanProfileStatusesQuery,
      variables() {
        return { fullPath: this.projectFullPath };
      },
      update: (data) => data?.project?.scanProfileStatuses || [],
      error(error) {
        this.showError(SCAN_PROFILE_I18N.errorLoadingStatuses);
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      drawerData: null,
      isDrawerOpen: false,
      projectId: null,
      submittingProfileId: null,
      errorMessage: null,
      previewProfileId: '',
      previewScanType: '',
      previewModalVisible: false,
      disableModalVisible: false,
      disablingScanType: null,
      availableProfiles: [],
      attachedProfiles: [],
      statuses: [],
      selectedProfileIds: {},
    };
  },
  computed: {
    isLoading() {
      return (
        this.$apollo.queries.availableProfiles.loading ||
        this.$apollo.queries.attachedProfiles.loading ||
        this.$apollo.queries.statuses.loading
      );
    },
    getScannerMetadata() {
      return (scanType) => SCAN_PROFILE_CATEGORIES[scanType] || {};
    },
    isProfileAttached() {
      return (profileId) => {
        return this.attachedProfiles.some((p) => p.id === profileId);
      };
    },
    getAttachedProfileForScanType() {
      return (scanType) => {
        return this.attachedProfiles.find((p) => p.scanType === scanType);
      };
    },
    profileGroups() {
      const groups = {};
      this.availableProfiles
        .filter((profile) => Boolean(SCAN_PROFILE_CATEGORIES[profile.scanType]))
        .forEach((profile) => {
          (groups[profile.scanType] ??= []).push(profile);
        });
      return groups;
    },
    tableItems() {
      if (!this.securityScanProfilesLicensed) return SCAN_PROFILE_PROMO_ITEMS;

      return Object.entries(this.profileGroups).map(([scanType, profiles]) => {
        const attached = this.getAttachedProfileForScanType(scanType);
        const recommended = profiles.find((profile) => profile.gitlabRecommended) ?? profiles[0];
        const displayed = attached
          ? (profiles.find((profile) => profile.id === attached.id) ?? attached)
          : (profiles.find((profile) => profile.id === this.selectedProfileIds[scanType]) ??
            recommended);
        const statusData = this.getStatusForProfile(displayed);
        return {
          id: displayed.id,
          name: displayed.name,
          description: displayed.description,
          scanType,
          gitlabRecommended: displayed.gitlabRecommended,
          isConfigured: Boolean(attached),
          profiles,
          hasMultipleProfiles: profiles.length > 1,
          ...statusData,
        };
      });
    },
    disableDropdownItem() {
      return {
        text: this.$options.SCAN_PROFILE_I18N.disable,
        extraAttrs: {
          disabled: !this.canApplyProfiles || !this.securityScanProfilesLicensed,
        },
      };
    },
  },
  methods: {
    getStatusForProfile(profile) {
      const defaultStatus = {
        status: null,
        consecutiveFailureCount: null,
        consecutiveSuccessCount: null,
        lastScanAt: null,
        buildId: null,
      };

      if (!this.glFeatures.securityScanProfilesStatusIndicators) return defaultStatus;

      const matchedStatus = this.statuses.find((s) => s.scanProfile?.id === profile.id);

      if (matchedStatus) {
        return {
          ...matchedStatus,
          status: GRAPHQL_STATUS_MAP[matchedStatus.status] ?? matchedStatus.status,
        };
      }

      return { ...defaultStatus, status: SCAN_PROFILE_SCANNER_HEALTH_UNCONFIGURED };
    },
    selectProfile(scanType, profileId) {
      this.selectedProfileIds = { ...this.selectedProfileIds, [scanType]: profileId };
    },
    listboxItems(profiles) {
      return profiles.map((profile) => ({ value: profile.id, text: profile.name }));
    },
    applyButtonLabel(item) {
      return item.gitlabRecommended
        ? SCAN_PROFILE_I18N.applyDefault
        : SCAN_PROFILE_I18N.applyProfile;
    },
    previewButtonLabel(item) {
      return item.gitlabRecommended
        ? SCAN_PROFILE_I18N.previewDefault
        : SCAN_PROFILE_I18N.previewProfile;
    },
    showError(message) {
      this.errorMessage = message;
      setTimeout(() => {
        this.errorMessage = null;
      }, 5000);
    },
    showToast(message) {
      this.$toast.show(message);
    },
    getButtonId(item) {
      return item.isConfigured ? `disable-button-${item.id}` : `apply-button-${item.id}`;
    },
    async applyProfile(profileId) {
      if (!this.projectId || !profileId) return;

      this.submittingProfileId = profileId;
      this.errorMessage = null;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: attachMutation,
          variables: {
            input: {
              securityScanProfileId: profileId,
              projectIds: [this.projectId],
            },
          },
          refetchQueries: [
            {
              query: projectProfilesQuery,
              variables: { fullPath: this.projectFullPath },
            },
            {
              query: scanProfileStatusesQuery,
              variables: { fullPath: this.projectFullPath },
            },
          ],
        });

        const mutationErrors = data?.securityScanProfileAttach?.errors;
        if (mutationErrors?.length) {
          this.showError(mutationErrors.join(', '));
        } else {
          this.showToast(SCAN_PROFILE_I18N.successApplying);
          if (this.previewModalVisible) {
            this.closePreview();
          }
        }
      } catch (error) {
        this.showError(SCAN_PROFILE_I18N.errorApplying);
      } finally {
        this.submittingProfileId = null;
      }
    },
    openDisableModal(scanType) {
      this.disablingScanType = scanType;
      this.disableModalVisible = true;
    },
    async detachProfile() {
      const attachedProfile = this.getAttachedProfileForScanType(this.disablingScanType);
      if (!attachedProfile || !this.projectId) return;

      this.disableModalVisible = false;
      this.submittingProfileId = attachedProfile.id;
      this.errorMessage = null;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: detachMutation,
          variables: {
            input: {
              securityScanProfileId: attachedProfile.id,
              projectIds: [this.projectId],
            },
          },
          refetchQueries: [
            {
              query: projectProfilesQuery,
              variables: { fullPath: this.projectFullPath },
            },
            {
              query: scanProfileStatusesQuery,
              variables: { fullPath: this.projectFullPath },
            },
          ],
        });

        const mutationErrors = data?.securityScanProfileDetach?.errors;
        if (mutationErrors?.length) {
          this.showError(mutationErrors.join(', '));
        } else {
          this.showToast(SCAN_PROFILE_I18N.successDetaching);
        }
      } catch (error) {
        this.showError(SCAN_PROFILE_I18N.errorDetaching);
      } finally {
        this.submittingProfileId = null;
        this.disablingScanType = null;
      }
    },
    openPreview(profileId, scanType) {
      this.trackEvent(EVENT_PREVIEW_SCAN_PROFILE);
      this.previewProfileId = profileId;
      this.previewScanType = scanType;
      this.previewModalVisible = true;
    },
    closePreview() {
      this.previewModalVisible = false;
      this.previewProfileId = '';
      this.previewScanType = '';
    },
    isFailedOrWarningStatus(item) {
      return [SCAN_PROFILE_SCANNER_HEALTH_WARNING, SCAN_PROFILE_SCANNER_HEALTH_FAILED].includes(
        item.status,
      );
    },
    openDrawer(item, jobData = {}) {
      this.drawerData = {
        jobData: { ...jobData },
        profileData: { ...item },
        fullPath: this.projectFullPath,
      };
      this.isDrawerOpen = true;
    },
  },
};
</script>

<template>
  <div>
    <gl-alert
      v-if="errorMessage"
      variant="danger"
      class="gl-mb-5"
      dismissible
      @dismiss="errorMessage = null"
    >
      {{ errorMessage }}
    </gl-alert>

    <scan-profile-table :table-items="tableItems" :loading="isLoading">
      <template #cell(name)="{ item }">
        <div class="gl-flex gl-items-center">
          <template v-if="item.isConfigured">
            <gl-link @click="openPreview(item.id, item.scanType)">
              {{ item.name }}
            </gl-link>
          </template>
          <gl-collapsible-listbox
            v-else-if="item.hasMultipleProfiles"
            data-testid="profile-picker"
            :items="listboxItems(item.profiles)"
            :selected="item.id"
            :toggle-text="item.name"
            @select="(profileId) => selectProfile(item.scanType, profileId)"
          />
          <span v-else class="gl-text-subtle">
            {{ $options.SCAN_PROFILE_I18N.noProfile }}
          </span>
        </div>
      </template>

      <template v-if="securityScanProfilesLicensed" #cell(status)="{ item }">
        <div v-if="glFeatures.securityScanProfilesStatusIndicators" class="gl-flex gl-items-center">
          <scanner-status-icon
            data-testid="status-icon"
            class="gl-mr-3 gl-self-start"
            :status="item.status"
            :consecutive-success-count="item.consecutiveSuccessCount"
            :consecutive-failure-count="item.consecutiveFailureCount"
          />
        </div>
        <div v-else class="gl-flex gl-items-center">
          <gl-icon
            :name="item.isConfigured ? 'check-circle-filled' : 'close'"
            :class="item.isConfigured ? 'gl-text-success' : 'gl-text-subtle'"
            class="gl-mr-3 gl-self-start"
          />
          <div class="gl-flex gl-flex-col">
            <span class="gl-font-weight-bold">
              {{
                item.isConfigured
                  ? $options.SCAN_PROFILE_I18N.active
                  : $options.SCAN_PROFILE_I18N.notConfigured
              }}
            </span>
            <span v-if="!item.isConfigured" class="gl-mt-1 gl-text-sm gl-text-subtle">
              {{ $options.SCAN_PROFILE_I18N.applyToEnable }}
            </span>
          </div>
        </div>
      </template>

      <template #cell(last-scan)="{ item }">
        <last-scan-cell
          :target-id="`scanner-details-${item.id}`"
          :last-scan-at="item.lastScanAt"
          :build-id="item.buildId"
          :status="item.status"
          :project-full-path="projectFullPath"
          @open-drawer="openDrawer(item, $event)"
        />
      </template>

      <template #cell(actions)="{ item }">
        <div v-if="!item.isConfigured">
          <gl-button-group>
            <!-- Apply button -->
            <gl-button
              :id="getButtonId(item)"
              data-testid="apply-profile-button"
              variant="confirm"
              category="secondary"
              :loading="submittingProfileId === item.id"
              :disabled="!canApplyProfiles || !securityScanProfilesLicensed || !item.id"
              class="!gl-rounded-r-none"
              @click="applyProfile(item.id)"
            >
              {{ applyButtonLabel(item) }}
              <gl-icon
                v-if="!canApplyProfiles"
                name="lock"
                class="gl-ml-2"
                :aria-label="$options.SCAN_PROFILE_I18N.accessLevelTooltipDescription"
              />
            </gl-button>
            <!-- Preview button -->
            <gl-button
              v-gl-tooltip
              data-testid="preview-button"
              variant="confirm"
              category="secondary"
              icon="eye"
              :aria-label="previewButtonLabel(item)"
              :title="previewButtonLabel(item)"
              :disabled="submittingProfileId === item.id || !securityScanProfilesLicensed"
              @click="openPreview(item.id, item.scanType)"
            />
          </gl-button-group>
          <insufficient-permissions-popover
            v-if="!canApplyProfiles && securityScanProfilesLicensed"
            :target="getButtonId(item)"
            placement="top"
          />
        </div>

        <div v-else>
          <div v-if="glFeatures.securityScanProfilesStatusIndicators">
            <gl-disclosure-dropdown
              class="gl-flex gl-justify-end"
              category="tertiary"
              variant="default"
              size="small"
              icon="ellipsis_v"
              no-caret
            >
              <!-- Troubleshoot Failure button -->
              <gl-disclosure-dropdown-item
                v-if="isFailedOrWarningStatus(item)"
                @action="openDrawer(item)"
              >
                <template #list-item>
                  {{ $options.SCAN_PROFILE_I18N.troubleshootFailure }}
                </template>
              </gl-disclosure-dropdown-item>

              <!-- Disable button -->
              <gl-disclosure-dropdown-item
                :id="getButtonId(item)"
                :item="disableDropdownItem"
                variant="danger"
                category="secondary"
                @action="openDisableModal(item.scanType)"
              >
                <template #list-item>
                  <span class="gl-flex gl-items-center gl-gap-2">
                    {{ $options.SCAN_PROFILE_I18N.disable }}
                    <gl-icon
                      v-if="!canApplyProfiles"
                      name="lock"
                      class="gl-ml-2"
                      :aria-label="$options.SCAN_PROFILE_I18N.accessLevelTooltipDescription"
                    />
                    <gl-loading-icon v-if="submittingProfileId === item.id" />
                  </span>
                </template>
              </gl-disclosure-dropdown-item>
            </gl-disclosure-dropdown>
          </div>

          <div v-else :id="getButtonId(item)">
            <gl-button
              data-testid="disable-button"
              variant="danger"
              category="secondary"
              :loading="submittingProfileId === item.id"
              :disabled="!canApplyProfiles || !securityScanProfilesLicensed"
              @click="openDisableModal(item.scanType)"
            >
              {{ $options.SCAN_PROFILE_I18N.disable }}
              <gl-icon
                v-if="!canApplyProfiles"
                name="lock"
                class="gl-ml-2"
                :aria-label="$options.SCAN_PROFILE_I18N.accessLevelTooltipDescription"
              />
            </gl-button>
          </div>

          <insufficient-permissions-popover
            v-if="!canApplyProfiles"
            :target="getButtonId(item)"
            placement="bottom"
          />
        </div>
      </template>
    </scan-profile-table>

    <scan-profile-details-modal
      :profile-id="previewProfileId"
      :scan-type="previewScanType"
      :visible="previewModalVisible"
      :is-attached="isProfileAttached(previewProfileId)"
      @apply="applyProfile"
      @close="closePreview"
    />

    <disable-scan-profile-confirmation-modal
      :visible="disableModalVisible"
      :scanner-name="disablingScanType ? getScannerMetadata(disablingScanType).name : ''"
      @confirm="detachProfile"
      @cancel="disableModalVisible = false"
    />

    <scan-profile-launch-modal v-if="securityScanProfilesLicensed" />

    <troubleshoot-job-drawer
      v-if="isDrawerOpen"
      :job-data="drawerData.jobData"
      :build-id="drawerData.profileData.buildId"
      :scan-type="drawerData.profileData.scanType"
      :status="drawerData.profileData.status"
      :full-path="drawerData.fullPath"
      :open-drawer="isDrawerOpen"
      @close-drawer="isDrawerOpen = false"
    />
  </div>
</template>
