<script>
import WorkItemSettings from 'ee/groups/settings/work_items/work_item_settings_home.vue';
import { getSettingsConfig } from 'ee/work_items/constants';

export default {
  name: 'AdminWorkItemSettings',
  components: {
    WorkItemSettings,
  },
  data() {
    return {
      viewConfig: {
        ...getSettingsConfig('admin'),
        showEnabledWorkItemTypesSettings: false,
        showCustomFieldsSettings: false,
        showCustomStatusSettings: false,
      },
    };
  },
};
</script>

<template>
  <work-item-settings :config="viewConfig" />
</template>
