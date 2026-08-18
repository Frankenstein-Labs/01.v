<script>
import CeBlobButtonGroup from '~/repository/components/header_area/blob_button_group.vue';
import { DEFAULT_BLOB_INFO } from '~/repository/constants';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import LockFileDropdownItem from 'ee_component/repository/components/header_area/lock_file_dropdown_item.vue';

export default {
  name: 'BlobButtonGroupEE',
  components: {
    CeBlobButtonGroup,
    LockFileDropdownItem,
  },
  mixins: [glLicensedFeaturesMixin(), glFeatureFlagsMixin()],
  inject: {
    blobInfo: {
      default: () => DEFAULT_BLOB_INFO.repository.blobs.nodes[0],
    },
  },
  props: {
    ...CeBlobButtonGroup.props,
    projectPath: {
      type: String,
      required: true,
    },
    canCreateLock: {
      type: Boolean,
      required: true,
    },
    canDestroyLock: {
      type: Boolean,
      required: true,
    },
    isLocked: {
      type: Boolean,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['show-fork-suggestion'],
  methods: {
    onShowForkSuggestion() {
      this.$emit('show-fork-suggestion');
    },
  },
};
</script>

<template>
  <ce-blob-button-group v-bind="$props" @show-fork-suggestion="onShowForkSuggestion">
    <template
      v-if="glLicensedFeatures.fileLocks && !glFeatures.repositoryLockInformation"
      #lock-file-item
    >
      <lock-file-dropdown-item
        :name="blobInfo.name"
        :path="blobInfo.path"
        :project-path="projectPath"
        :user-permissions="userPermissions"
        :is-loading="isLoading"
        :can-create-lock="canCreateLock"
        :can-destroy-lock="canDestroyLock"
        :is-locked="isLocked"
      />
    </template>
  </ce-blob-button-group>
</template>
