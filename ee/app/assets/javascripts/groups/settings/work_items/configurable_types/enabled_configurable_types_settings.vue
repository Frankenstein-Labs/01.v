<script>
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import WorkItemTypesListEnabledDisabledView from 'ee/work_items/components/work_item_types_list_enabled_disabled_view.vue';

export default {
  name: 'EnabledConfigurableTypesSettings',
  components: {
    SettingsBlock,
    HelpPageLink,
    WorkItemTypesListEnabledDisabledView,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    id: {
      type: String,
      required: true,
    },
    expanded: {
      type: Boolean,
      required: true,
    },
    config: {
      type: Object,
      required: true,
    },
  },
  emits: ['toggle-expand'],
};
</script>

<template>
  <settings-block
    :id="id"
    :title="s__('WorkItem|Enabled work item types')"
    :expanded="expanded"
    @toggle-expand="$emit('toggle-expand', $event)"
  >
    <template #description>
      <p class="gl-mb-3 gl-text-subtle" data-testid="enabled-types-description">
        {{ config.enabledTypesSubtext }}
        <help-page-link href="user/work_items/configurable_work_item_types.md" target="_blank">
          {{ s__('WorkItem|How do I use or configure work item types?') }}
        </help-page-link>
      </p>
    </template>
    <template #default>
      <work-item-types-list-enabled-disabled-view :full-path="fullPath" :config="config" />
    </template>
  </settings-block>
</template>
