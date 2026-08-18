<script>
import { getSettingsConfig } from 'ee/work_items/constants';
import SearchSettings from '~/search_settings/components/search_settings.vue';
import CustomFieldsList from './custom_fields/custom_fields_list.vue';
import CustomStatusSettings from './custom_status/custom_status_settings.vue';
import ConfigurableTypesSettings from './configurable_types/configurable_types_settings.vue';
import EnabledConfigurableTypesSettings from './configurable_types/enabled_configurable_types_settings.vue';

export const STATUS_SECTION_ID = 'js-custom-status-settings';
export const CUSTOM_FIELD_SECTION_ID = 'js-custom-fields-settings';
export const WORK_ITEM_TYPES_SECTION_ID = 'js-work-item-types-settings';
export const ENABLED_WORK_ITEM_TYPES_SECTION_ID = 'js-enabled-work-item-types-settings';

export default {
  name: 'WorkItemSettings',
  components: {
    CustomFieldsList,
    CustomStatusSettings,
    ConfigurableTypesSettings,
    EnabledConfigurableTypesSettings,
    SearchSettings,
  },
  props: {
    fullPath: {
      type: String,
      required: false,
      default: '',
    },
    config: {
      type: Object,
      required: false,
      default: () => getSettingsConfig(),
      validator: (config) => {
        return (
          typeof config === 'object' &&
          config !== null &&
          typeof config.showWorkItemTypesSettings === 'boolean' &&
          typeof config.showEnabledWorkItemTypesSettings === 'boolean' &&
          typeof config.showCustomFieldsSettings === 'boolean' &&
          typeof config.showCustomStatusSettings === 'boolean'
        );
      },
    },
  },
  STATUS_SECTION_ID,
  CUSTOM_FIELD_SECTION_ID,
  WORK_ITEM_TYPES_SECTION_ID,
  ENABLED_WORK_ITEM_TYPES_SECTION_ID,
  data() {
    return {
      sectionsExpandedState: {
        [STATUS_SECTION_ID]: false,
        [CUSTOM_FIELD_SECTION_ID]: false,
        [WORK_ITEM_TYPES_SECTION_ID]: false,
        [ENABLED_WORK_ITEM_TYPES_SECTION_ID]: false,
      },
      searchRoot: null,
    };
  },
  mounted() {
    this.searchRoot = this.$refs.searchRoot;
  },
  methods: {
    isExpanded(section) {
      const sectionId = section.getAttribute('id');

      return this.expandedProp(sectionId);
    },
    setSectionExpandedState(section, state) {
      const sectionId = section.getAttribute('id');

      this.sectionsExpandedState[sectionId] = state;
    },
    onSearchExpand(section) {
      this.setSectionExpandedState(section, true);
    },
    onSearchCollapse(section) {
      this.setSectionExpandedState(section, false);
    },
    onToggleExpand(sectionId, state) {
      this.sectionsExpandedState[sectionId] = state;

      if (!state && this.$route?.hash === '') {
        return;
      }

      this.$router?.push({
        name: 'workItemSettingsHome',
        hash: state ? `#${sectionId}` : '',
      });
    },
    expandedProp(sectionId) {
      return this.sectionsExpandedState[sectionId] || this.$route?.hash === `#${sectionId}`;
    },
  },
};
</script>

<template>
  <div class="gl-pt-5">
    <search-settings
      v-if="searchRoot"
      class="gl-mb-5"
      :search-root="searchRoot"
      section-selector=".vue-settings-block"
      :is-expanded-fn="isExpanded"
      @expand="onSearchExpand"
      @collapse="onSearchCollapse"
    />
    <h1 class="settings-title gl-heading-1 gl-mb-1">
      {{ __('Work items') }}
    </h1>
    <p class="gl-text-subtle">
      {{
        s__(
          'WorkItem|Configure work items such as epics, issues, and tasks to represent how your team works.',
        )
      }}
    </p>

    <div ref="searchRoot">
      <configurable-types-settings
        v-if="config.showWorkItemTypesSettings"
        :id="$options.WORK_ITEM_TYPES_SECTION_ID"
        :config="config"
        :full-path="fullPath"
        :expanded="expandedProp($options.WORK_ITEM_TYPES_SECTION_ID)"
        @toggle-expand="onToggleExpand($options.WORK_ITEM_TYPES_SECTION_ID, $event)"
      />
      <enabled-configurable-types-settings
        v-if="config.showEnabledWorkItemTypesSettings"
        :id="$options.ENABLED_WORK_ITEM_TYPES_SECTION_ID"
        :config="config"
        :full-path="fullPath"
        :expanded="expandedProp($options.ENABLED_WORK_ITEM_TYPES_SECTION_ID)"
        @toggle-expand="onToggleExpand($options.ENABLED_WORK_ITEM_TYPES_SECTION_ID, $event)"
      />
      <custom-status-settings
        v-if="config.showCustomStatusSettings"
        :id="$options.STATUS_SECTION_ID"
        :full-path="fullPath"
        :expanded="expandedProp($options.STATUS_SECTION_ID)"
        @toggle-expand="onToggleExpand($options.STATUS_SECTION_ID, $event)"
      />
      <custom-fields-list
        v-if="config.showCustomFieldsSettings"
        :id="$options.CUSTOM_FIELD_SECTION_ID"
        :full-path="fullPath"
        :expanded="expandedProp($options.CUSTOM_FIELD_SECTION_ID)"
        @toggle-expand="onToggleExpand($options.CUSTOM_FIELD_SECTION_ID, $event)"
      />
    </div>
  </div>
</template>
