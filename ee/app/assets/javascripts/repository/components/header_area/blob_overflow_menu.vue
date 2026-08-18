<script>
import CeBlobOverflowMenu from '~/repository/components/header_area/blob_overflow_menu.vue';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import { DEFAULT_BLOB_INFO } from '~/repository/constants';
import { createAlert } from '~/alert';

export default {
  name: 'BlobOverflowMenuEE',
  components: { CeBlobOverflowMenu },
  inject: ['blobInfo', 'currentRef', 'rootRef'],
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    isBinaryFileType: {
      type: Boolean,
      required: false,
      default: false,
    },
    overrideCopy: {
      type: Boolean,
      required: false,
      default: false,
    },
    isEmptyRepository: {
      type: Boolean,
      required: false,
      default: false,
    },
    isUsingLfs: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['copy', 'show-fork-suggestion'],
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
        this.pathLocks = project?.pathLocks || DEFAULT_BLOB_INFO.pathLocks;
        this.userPermissions = project?.userPermissions || DEFAULT_BLOB_INFO.userPermissions;
      },
      error() {
        createAlert({ message: this.$options.i18n.fetchError });
      },
    },
  },
  data() {
    return {
      userPermissions: DEFAULT_BLOB_INFO.userPermissions,
      pathLocks: DEFAULT_BLOB_INFO.pathLocks,
    };
  },
  computed: {
    isOnDefaultBranch() {
      return this.currentRef === this.rootRef;
    },
    pathLock() {
      return this.pathLocks?.nodes.find((node) => {
        return node.path === this.blobInfo.path;
      });
    },
    isLocked() {
      return Boolean(this.pathLock);
    },
    canCreatePathLock() {
      return Boolean(this.userPermissions.createPathLock);
    },
    canDestroyPathLock() {
      return Boolean(this.pathLock?.userPermissions.destroyPathLock);
    },
    canModifyFile() {
      return !this.isOnDefaultBranch || this.canDestroyPathLock;
    },
  },
  methods: {
    onCopy() {
      this.$emit('copy');
    },
    onShowForkSuggestion() {
      this.$emit('show-fork-suggestion');
    },
  },
};
</script>
<template>
  <ce-blob-overflow-menu
    :project-path="projectPath"
    :is-binary-file-type="isBinaryFileType"
    :override-copy="overrideCopy"
    :is-empty-repository="isEmptyRepository"
    :is-using-lfs="isUsingLfs"
    :ee-can-modify-file="canModifyFile"
    :ee-is-locked="isLocked"
    :ee-can-create-lock="canCreatePathLock"
    :ee-can-destroy-lock="canDestroyPathLock"
    @copy="onCopy"
    @show-fork-suggestion="onShowForkSuggestion"
  />
</template>
