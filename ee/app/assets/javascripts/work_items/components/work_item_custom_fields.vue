<script>
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  CUSTOM_FIELDS_TYPE_NUMBER,
  CUSTOM_FIELDS_TYPE_TEXT,
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
} from '~/work_items/constants';
import WorkItemCustomFieldNumber from './work_item_custom_fields_number.vue';
import WorkItemCustomFieldText from './work_item_custom_fields_text.vue';
import WorkItemCustomFieldSingleSelect from './work_item_custom_fields_single_select.vue';
import WorkItemCustomFieldMultiSelect from './work_item_custom_fields_multi_select.vue';

export default {
  name: 'WorkItemCustomFields',
  components: {
    WorkItemCustomFieldNumber,
    WorkItemCustomFieldText,
    WorkItemCustomFieldSingleSelect,
    WorkItemCustomFieldMultiSelect,
  },
  props: {
    workItemId: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: false,
      default: '',
    },
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    customFields: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['error', 'update-widget-draft'],
  computed: {
    hasCustomFields() {
      return this.customFields?.length;
    },
  },
  methods: {
    customFieldComponent(customField) {
      switch (customField.fieldType) {
        case CUSTOM_FIELDS_TYPE_NUMBER:
          return WorkItemCustomFieldNumber;
        case CUSTOM_FIELDS_TYPE_TEXT:
          return WorkItemCustomFieldText;
        case CUSTOM_FIELDS_TYPE_SINGLE_SELECT:
          return WorkItemCustomFieldSingleSelect;
        case CUSTOM_FIELDS_TYPE_MULTI_SELECT:
          return WorkItemCustomFieldMultiSelect;
        default:
          Sentry.captureException(new Error(`Unknown custom field type: ${customField.fieldType}`));
          return null;
      }
    },
  },
};
</script>

<template>
  <div v-if="hasCustomFields" data-testid="work-item-custom-field">
    <component
      :is="customFieldComponent(customFieldData.customField)"
      v-for="customFieldData in customFields"
      :key="customFieldData.customField.id"
      class="gl-border-t gl-mb-5 gl-border-subtle gl-pt-5"
      :work-item-id="workItemId"
      :custom-field="customFieldData"
      :can-update="canUpdate"
      :work-item-type="workItemType"
      @update-widget-draft="$emit('update-widget-draft', $event)"
      @error="$emit('error', $event)"
    />
  </div>
</template>
