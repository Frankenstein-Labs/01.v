<script>
import { logError } from '~/lib/logger';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import LockButton from 'ee/repository/components/header_area/lock_button.vue';

export default {
  name: 'BlobControlsLockButton',
  components: {
    LockButton,
  },
  mixins: [glFeatureFlagMixin(), glLicensedFeaturesMixin()],
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
    projectInfo: {
      query: projectInfoQuery,
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      skip() {
        return !this.isLockAvailable;
      },
      update: (data) => data.project || {},
      error(error) {
        logError(
          `Failed to fetch project info. See exception details for more information.`,
          error,
        );
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      projectInfo: {},
    };
  },
  computed: {
    isLockAvailable() {
      return Boolean(
        this.glFeatures.repositoryLockInformation && this.glLicensedFeatures.fileLocks,
      );
    },
    pathLock() {
      return this.projectInfo?.pathLocks?.nodes?.find((node) => node.path === this.path);
    },
    lockState() {
      return {
        isLocked: Boolean(this.pathLock),
        lockUser: this.pathLock?.user ?? null,
        lockedAt: this.pathLock?.createdAt ?? null,
        canDestroyLock: Boolean(this.pathLock?.userPermissions?.destroyPathLock),
        canCreateLock: Boolean(this.projectInfo?.userPermissions?.createPathLock),
      };
    },
  },
};
</script>

<template>
  <lock-button
    v-if="isLockAvailable"
    :is-locked="lockState.isLocked"
    :lock-user="lockState.lockUser"
    :locked-at="lockState.lockedAt"
    :can-destroy-lock="lockState.canDestroyLock"
    :can-create-lock="lockState.canCreateLock"
    :project-path="projectPath"
    :path="path"
  />
</template>
