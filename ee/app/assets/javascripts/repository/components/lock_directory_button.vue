<script>
import { GlAlert, GlButton, GlButtonGroup, GlTooltip, GlModal, GlModalDirective } from '@gitlab/ui';
import { sprintf, __ } from '~/locale';
import { joinPaths, escapeFileUrl } from '~/lib/utils/url_utility';
import { projectTreePath } from '~/lib/utils/path_helpers/repository';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { logError } from '~/lib/logger';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import LockButton from 'ee_component/repository/components/header_area/lock_button.vue';
import currentUserQuery from '~/graphql_shared/queries/current_user.query.graphql';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';
import { DEFAULT_BLOB_INFO } from '~/repository/constants';

export default {
  name: 'LockDirectoryButton',
  i18n: {
    fetchError: __('An error occurred while fetching lock information, please try again.'),
    mutationError: __('An error occurred while editing lock information, please try again.'),
    upstreamLockAlert: __(
      'The parent directory "%{path}" is locked. To unlock this directory, unlock "%{path}".',
    ),
    downstreamLockAlert: __(
      'You cannot lock this directory because "%{path}" inside it is locked.',
    ),
    viewLock: __('View lock'),
  },
  modal: {
    modalTitle: __('Lock directory?'),
    actionPrimary: {
      text: __('Ok'),
      attributes: { variant: 'confirm', 'data-testid': 'confirm-ok-button' },
    },
    actionCancel: {
      text: __('Cancel'),
    },
  },
  components: {
    GlAlert,
    GlButton,
    GlButtonGroup,
    GlModal,
    GlTooltip,
    LockButton,
  },
  directives: {
    GlModalDirective,
  },
  mixins: [glLicensedFeaturesMixin(), glFeatureFlagsMixin()],
  inject: {
    currentRef: {
      default: '',
    },
  },
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    projectInfo: {
      query: projectInfoQuery,
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update({ project }) {
        const allPathLocks = project?.pathLocks?.nodes?.map((lock) => this.mapPathLocks(lock));
        this.pathLock =
          allPathLocks?.find(
            (lock) =>
              this.isDownstreamLock(lock) || this.isUpstreamLock(lock) || this.isExactLock(lock),
          ) || {};
        this.projectUserPermissions = project?.userPermissions || {
          ...DEFAULT_BLOB_INFO.userPermissions,
          createPathLock: false,
        };
        this.rootRef = project?.repository?.rootRef || '';
      },
      error(error) {
        logError(`Unexpected error while fetching projectInfo query`, error);
        this.onFetchError(error);
      },
    },
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    currentUser: {
      query: currentUserQuery,
      update({ currentUser }) {
        this.user = { ...currentUser };
      },
      error(error) {
        logError(`Unexpected error while fetching currentUser query`, error);
        this.onFetchError(error);
      },
    },
  },
  data() {
    return {
      isUpdating: false,
      pathLock: {},
      rootRef: '',
      user: {},
      projectUserPermissions: {},
    };
  },
  computed: {
    useLockButton() {
      return Boolean(
        this.glFeatures.repositoryLockInformation &&
        this.glLicensedFeatures.fileLocks &&
        this.user?.id,
      );
    },
    showLockButton() {
      return Boolean(this.glLicensedFeatures.fileLocks && this.user?.id);
    },
    canDestroyDirectoryLock() {
      return Boolean(this.pathLock.isExactLock && this.canDestroyExactLock);
    },
    relatedLockAlert() {
      if (!this.pathLock.isUpstreamLock && !this.pathLock.isDownstreamLock) return null;

      const template = this.pathLock.isUpstreamLock
        ? this.$options.i18n.upstreamLockAlert
        : this.$options.i18n.downstreamLockAlert;
      return sprintf(template, { path: this.pathLock.path }, false);
    },
    lockedPathHref() {
      // The route helper's glob encoding misses `#` and `?`, so escape the lock path ourselves.
      // The parent provides currentRef as null when the page has no explicit ref,
      // which bypasses the inject default, so fall back to the repository root ref.
      return joinPaths(
        projectTreePath(this.projectPath, this.currentRef || this.rootRef),
        escapeFileUrl(this.pathLock.path),
      );
    },
    isLoading() {
      return this.$apollo?.queries.projectInfo.loading;
    },
    isLocked() {
      return this.pathLock.isExactLock || this.pathLock.isUpstreamLock;
    },
    hasPathLocks() {
      return Object.keys(this.pathLock).length > 0;
    },
    locker() {
      return this.pathLock.user?.name || this.pathLock.user?.username;
    },
    buttonLabel() {
      return this.isLocked ? __('Unlock') : __('Lock');
    },
    buttonState() {
      return this.isLocked ? 'unlock' : 'lock';
    },
    isLockAuthor() {
      return this.pathLock.user?.id === this.user.id;
    },
    canCreatePathLock() {
      return this.projectUserPermissions.createPathLock;
    },
    canDestroyExactLock() {
      return this.pathLock?.userPermissions.destroyPathLock;
    },
    isDisabled() {
      return (
        this.pathLock.isUpstreamLock ||
        this.pathLock.isDownstreamLock ||
        (this.pathLock.isExactLock && !this.canDestroyExactLock) ||
        !this.canCreatePathLock ||
        this.isUpdating
      );
    },
    getExactLockTooltip() {
      if (!this.canCreatePathLock) {
        return sprintf(__('Locked by %{locker}. You do not have permission to unlock this'), {
          locker: this.locker,
        });
      }
      return this.isLockAuthor ? '' : sprintf(__('Locked by %{locker}'), { locker: this.locker });
    },
    getUpstreamLockTooltip() {
      const additionalPhrase = this.canCreatePathLock
        ? __('Unlock that directory in order to unlock this')
        : __('You do not have permission to unlock it');
      return sprintf(__('%{locker} has a lock on "%{path}". %{additionalPhrase}'), {
        locker: this.locker,
        path: this.pathLock.path,
        additionalPhrase,
      });
    },
    getDownstreamLockTooltip() {
      const additionalPhrase = this.canCreatePathLock
        ? __('Unlock this in order to proceed')
        : __('You do not have permission to unlock it');
      return sprintf(
        __(
          'This directory cannot be locked while %{locker} has a lock on "%{path}". %{additionalPhrase}',
        ),
        {
          locker: this.locker,
          path: this.pathLock.path,
          additionalPhrase,
        },
      );
    },
    tooltipText() {
      if (!this.canCreatePathLock && !this.hasPathLocks) {
        return __('You do not have permission to lock this');
      }
      if (this.pathLock.isDownstreamLock) {
        return this.getDownstreamLockTooltip;
      }
      if (this.pathLock.isUpstreamLock) {
        return this.getUpstreamLockTooltip;
      }
      if (this.pathLock.isExactLock) {
        return this.getExactLockTooltip;
      }
      return '';
    },
    modalId() {
      return `lock-directory-modal-${this.path.replaceAll('/', '-')}`;
    },
    modalContent() {
      return this.isLocked
        ? __('Are you sure you want to unlock this directory?')
        : __('Are you sure you want to lock this directory?');
    },
  },
  watch: {
    async path() {
      try {
        await this.$apollo.queries.projectInfo.refetch();
      } catch (error) {
        logError(`Unexpected error while refetch projectInfo query`, error);
        this.onFetchError(error);
      }
    },
  },
  methods: {
    onFetchError(error) {
      Sentry.captureException(error);
      createAlert({ message: this.$options.i18n.fetchError });
    },
    isExactLock(lock) {
      return lock.path === this.path;
    },
    isUpstreamLock(lock) {
      return this.path.startsWith(lock.path) && this.path !== lock.path;
    },
    isDownstreamLock(lock) {
      return lock.path.startsWith(this.path) && this.path !== lock.path;
    },
    mapPathLocks(lock) {
      return {
        ...lock,
        isExactLock: this.isExactLock(lock),
        isUpstreamLock: this.isUpstreamLock(lock),
        isDownstreamLock: this.isDownstreamLock(lock),
      };
    },
    toggleLock() {
      const locked = !this.isLocked;
      this.isUpdating = true;
      this.$apollo
        .mutate({
          mutation: lockPathMutation,
          variables: {
            filePath: this.path,
            projectPath: this.projectPath,
            lock: locked,
          },
        })
        .then(() => {
          window.location.reload();
        })
        .catch((error) => {
          logError(`Unexpected error while Locking/Unlocking path`, error);
          Sentry.captureException(error);
          createAlert({ message: this.$options.i18n.mutationError, error, captureError: true });
        });
    },
  },
};
</script>
<template>
  <lock-button
    v-if="useLockButton"
    :is-locked="hasPathLocks"
    :lock-user="pathLock.user || null"
    :locked-at="pathLock.createdAt || null"
    :can-destroy-lock="canDestroyDirectoryLock"
    :can-create-lock="canCreatePathLock"
    :project-path="projectPath"
    :path="path"
    resource-type="directory"
  >
    <template v-if="relatedLockAlert" #disclosure-alert>
      <gl-alert
        variant="warning"
        :dismissible="false"
        class="gl-mx-4 gl-my-3 gl-rounded-base"
        data-testid="related-lock-alert"
      >
        {{ relatedLockAlert }}
      </gl-alert>
    </template>
    <template v-if="relatedLockAlert" #footer>
      <gl-button size="small" :href="lockedPathHref" data-testid="view-locked-path-button">
        {{ $options.i18n.viewLock }}
      </gl-button>
    </template>
  </lock-button>
  <gl-button-group
    v-else-if="showLockButton"
    ref="buttonWrapper"
    class="gl-w-full @md/panel:gl-w-auto"
  >
    <gl-tooltip v-if="tooltipText" :target="() => $refs.buttonWrapper && $refs.buttonWrapper.$el">
      {{ tooltipText }}
    </gl-tooltip>
    <gl-button
      v-gl-modal-directive="modalId"
      :loading="isLoading"
      :disabled="isDisabled"
      class="path-lock js-path-lock"
      :data-testid="isDisabled ? 'disabled-lock-button' : 'lock-button'"
      :data-state="buttonState"
    >
      {{ buttonLabel }}
    </gl-button>
    <gl-modal
      size="sm"
      :modal-id="modalId"
      :title="$options.modal.modalTitle"
      :action-primary="$options.modal.actionPrimary"
      :action-cancel="$options.modal.actionCancel"
      @primary="toggleLock"
    >
      <p>{{ modalContent }}</p>
    </gl-modal>
  </gl-button-group>
</template>
