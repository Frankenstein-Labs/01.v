<script>
import WebBasedCommitSigningCheckbox from './checkbox.vue';

export default {
  name: 'WebBasedCommitSigningSettings',
  components: {
    WebBasedCommitSigningCheckbox,
  },
  inject: {
    fullPath: { default: null },
    groupSettingsRepositoryPath: { default: null },
  },
  props: {
    canAdminGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
    isGroupLevel: {
      type: Boolean,
      required: true,
    },
  },
};
</script>

<template>
  <web-based-commit-signing-checkbox
    :has-group-permissions="canAdminGroup"
    :group-settings-repository-path="groupSettingsRepositoryPath"
    :is-group-level="isGroupLevel"
    :full-path="fullPath"
  />
</template>
