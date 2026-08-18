<script>
import {
  GlAvatar,
  GlAvatarLabeled,
  GlAvatarLink,
  GlButton,
  GlDisclosureDropdown,
  GlIcon,
  GlModal,
  GlToastMixin,
} from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { sprintf, __ } from '~/locale';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import UsersCache from '~/lib/utils/users_cache';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';

export default {
  name: 'LockButton',
  i18n: {
    locked: __('Locked'),
    byResourceType: {
      file: {
        unlockAction: __('Unlock file'),
        lockModalTitle: __('Lock file?'),
        unlockModalTitle: __('Unlock file?'),
        lockConfirmText: __('Are you sure you want to lock the "%{name}" file?'),
        unlockConfirmText: __('Are you sure you want to unlock the "%{name}" file?'),
        lockedToast: __('The file is locked.'),
        unlockedToast: __('The file is unlocked.'),
        noPermissionMessage: __('You do not have permission to unlock this file.'),
      },
      directory: {
        unlockAction: __('Unlock directory'),
        lockModalTitle: __('Lock directory?'),
        unlockModalTitle: __('Unlock directory?'),
        lockConfirmText: __('Are you sure you want to lock the "%{name}" directory?'),
        unlockConfirmText: __('Are you sure you want to unlock the "%{name}" directory?'),
        lockedToast: __('The directory is locked.'),
        unlockedToast: __('The directory is unlocked.'),
        noPermissionMessage: __('You do not have permission to unlock this directory.'),
      },
    },
  },
  components: {
    GlAvatar,
    GlAvatarLabeled,
    GlAvatarLink,
    GlButton,
    GlDisclosureDropdown,
    GlIcon,
    GlModal,
    TimeAgoTooltip,
  },
  mixins: [glFeatureFlagsMixin(), GlToastMixin],
  props: {
    isLocked: {
      type: Boolean,
      required: true,
    },
    lockUser: {
      type: Object,
      required: false,
      default: null,
    },
    lockedAt: {
      type: String,
      required: false,
      default: null,
    },
    canDestroyLock: {
      type: Boolean,
      required: false,
      default: false,
    },
    canCreateLock: {
      type: Boolean,
      required: false,
      default: false,
    },
    projectPath: {
      type: String,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
    resourceType: {
      type: String,
      required: false,
      default: 'file',
      validator: (value) => ['file', 'directory'].includes(value),
    },
  },
  data() {
    return {
      modalId: uniqueId('lock-modal-'),
      isUpdating: false,
      isModalVisible: false,
      lockUserDetails: null,
    };
  },
  computed: {
    showComponent() {
      if (!this.glFeatures.repositoryLockInformation) return false;
      return this.isLocked || this.canCreateLock;
    },
    lockedByText() {
      return sprintf(__('Locked by %{locker}'), { locker: this.lockUser?.name }, false);
    },
    lockedAriaLabel() {
      return this.lockUser?.name ? this.lockedByText : this.$options.i18n.locked;
    },
    resourceI18n() {
      return this.$options.i18n.byResourceType[this.resourceType];
    },
    resourceName() {
      return this.path.split('/').pop();
    },
    lockActionText() {
      return this.isLocked ? __('Unlock') : __('Lock');
    },
    modalTitle() {
      return this.isLocked ? this.resourceI18n.unlockModalTitle : this.resourceI18n.lockModalTitle;
    },
    lockConfirmText() {
      const template = this.isLocked
        ? this.resourceI18n.unlockConfirmText
        : this.resourceI18n.lockConfirmText;
      return sprintf(template, { name: this.resourceName }, false);
    },
    modalActions() {
      return {
        primary: {
          text: this.lockActionText,
          attributes: { variant: 'confirm', 'data-testid': 'confirm-ok-button' },
        },
        cancel: {
          text: __('Cancel'),
        },
      };
    },
    lockUserInfoRows() {
      if (!this.lockUserDetails) return [];

      return [
        { icon: 'work', text: this.lockUserDetails.jobTitle },
        { icon: 'organization', text: this.lockUserDetails.organization },
        { icon: 'location', text: this.lockUserDetails.location },
        { icon: 'clock', text: this.lockUserDetails.localTime },
      ].filter((row) => row.text);
    },
  },
  watch: {
    'lockUser.id': function resetDetails() {
      this.lockUserDetails = null;
    },
  },
  methods: {
    showModal() {
      this.isModalVisible = true;
    },
    hideModal() {
      this.isModalVisible = false;
    },
    fetchLockUserDetails() {
      if (this.lockUserDetails || !this.lockUser?.id) return;

      UsersCache.retrieveById(getIdFromGraphQLId(this.lockUser.id))
        .then((userData) => {
          this.lockUserDetails = {
            jobTitle: userData.job_title,
            organization: userData.organization,
            location: userData.location,
            localTime: userData.local_time,
          };
        })
        .catch(() => {
          // Extra user details are non-critical; the disclosure stays usable without them.
        });
    },
    toggleLock() {
      const lock = !this.isLocked;
      this.isUpdating = true;
      this.$apollo
        .mutate({
          mutation: lockPathMutation,
          variables: {
            filePath: this.path,
            projectPath: this.projectPath,
            lock,
          },
          refetchQueries: [
            { query: projectInfoQuery, variables: { projectPath: this.projectPath } },
          ],
          awaitRefetchQueries: true,
        })
        .then(({ data }) => {
          const [error] = data?.projectSetLocked?.errors ?? [];
          if (error) {
            createAlert({ message: error });
            return;
          }
          this.$toast.show(lock ? this.resourceI18n.lockedToast : this.resourceI18n.unlockedToast);
        })
        .catch((error) => {
          createAlert({
            message: __('An error occurred while editing lock information, please try again.'),
            captureError: true,
            error,
          });
        })
        .finally(() => {
          this.isUpdating = false;
        });
    },
  },
};
</script>

<template>
  <div v-if="showComponent" class="gl-inline-flex">
    <gl-button v-if="!isLocked" data-testid="lock-button" :loading="isUpdating" @click="showModal">
      {{ lockActionText }}
    </gl-button>

    <gl-disclosure-dropdown
      v-else
      data-testid="lock-disclosure"
      placement="bottom-end"
      fluid-width
      @shown="fetchLockUserDetails"
    >
      <template #toggle="{ accessibilityAttributes }">
        <gl-button
          v-bind="accessibilityAttributes"
          data-testid="lock-disclosure-toggle"
          :loading="isUpdating"
          :aria-label="lockedAriaLabel"
        >
          <gl-avatar
            v-if="lockUser"
            :src="lockUser.avatarUrl"
            :size="16"
            :alt="''"
            class="gl-mr-2"
          />
          {{ $options.i18n.locked }}
        </gl-button>
      </template>

      <template v-if="lockUser" #header>
        <div
          class="gl-flex gl-items-baseline gl-gap-2 gl-whitespace-nowrap gl-px-4 gl-pt-4 gl-text-sm"
          data-testid="lock-disclosure-header"
        >
          <span class="gl-font-bold">{{ lockedByText }}</span>
          <time-ago-tooltip v-if="lockedAt" :time="lockedAt" class="gl-text-subtle" />
        </div>
      </template>

      <div v-if="lockUser" class="gl-min-w-37 gl-px-4 gl-py-3" data-testid="lock-user-card">
        <div class="gl-mb-3">
          <gl-avatar-link :href="lockUser.webPath" data-testid="lock-user-link">
            <gl-avatar-labeled
              :src="lockUser.avatarUrl"
              :size="48"
              :label="lockUser.name"
              :sub-label="`@${lockUser.username}`"
              class="gl-w-full gl-break-anywhere"
            />
          </gl-avatar-link>
        </div>
        <div class="gl-w-full gl-text-sm gl-text-subtle gl-break-anywhere">
          <div v-for="row in lockUserInfoRows" :key="row.icon" class="gl-mb-2 gl-flex">
            <gl-icon :name="row.icon" class="gl-shrink-0" />
            <span class="gl-ml-2">{{ row.text }}</span>
          </div>
        </div>
      </div>

      <!-- Extra disclosure content, e.g. an upstream/downstream lock alert for directories -->
      <slot name="disclosure-alert"></slot>

      <template #footer>
        <div class="gl-px-4 gl-pb-4">
          <slot name="footer">
            <gl-button
              v-if="canDestroyLock"
              data-testid="unlock-button"
              size="small"
              @click="showModal"
            >
              {{ resourceI18n.unlockAction }}
            </gl-button>
            <p v-else class="gl-mb-0 gl-text-sm gl-text-subtle" data-testid="no-permission-message">
              {{ resourceI18n.noPermissionMessage }}
            </p>
          </slot>
        </div>
      </template>
    </gl-disclosure-dropdown>

    <gl-modal
      :modal-id="modalId"
      size="sm"
      :visible="isModalVisible"
      :title="modalTitle"
      :action-primary="modalActions.primary"
      :action-cancel="modalActions.cancel"
      @primary="toggleLock"
      @hide="hideModal"
    >
      <p class="gl-break-anywhere">
        {{ lockConfirmText }}
      </p>
    </gl-modal>
  </div>
</template>
