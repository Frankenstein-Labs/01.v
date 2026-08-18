<script>
import WorkItemSettings from 'ee/groups/settings/work_items/work_item_settings_home.vue';
import { getSettingsConfig } from 'ee/work_items/constants';

export default {
  name: 'ProjectWorkItemSettings',
  components: {
    WorkItemSettings,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      viewConfig: {
        ...getSettingsConfig('project'),
        showWorkItemTypesSettings: false,
        showEnabledWorkItemTypesSettings: true,
        showCustomFieldsSettings: false,
        showCustomStatusSettings: false,
      },
    };
  },
};
</script>

<template>
  <work-item-settings :config="viewConfig" :full-path="fullPath" />
</template>
