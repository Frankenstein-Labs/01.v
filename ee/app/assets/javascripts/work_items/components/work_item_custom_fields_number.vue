<script>
import { GlButton, GlFormGroup, GlFormInput, GlTooltipDirective } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { newWorkItemId } from '~/work_items/utils';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';
import { CUSTOM_FIELDS_TYPE_NUMBER, I18N_WORK_ITEM_ERROR_UPDATING } from '~/work_items/constants';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import { isNumeric } from '~/lib/utils/number_utils';
import { sprintf } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export default {
  name: 'WorkItemCustomFieldsNumber',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
    GlFormGroup,
    GlFormInput,
    WorkItemSidebarWidget,
  },
  mixins: [glFeatureFlagsMixin()],
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
    customField: {
      type: Object,
      required: true,
    },
  },
  emits: ['error', 'update-widget-draft'],
  data() {
    return {
      isUpdating: false,
      value: this.customField.value,
    };
  },
  computed: {
    customFieldId() {
      return this.customField.customField?.id;
    },
    customFieldName() {
      return this.customField.customField?.name;
    },
    hasValue() {
      return this.value !== null && Number.isFinite(Number(this.value));
    },
    showRemoveValue() {
      return this.hasValue && !this.isUpdating;
    },
    displayWidget() {
      return this.customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_NUMBER;
    },
  },
  watch: {
    customField: {
      immediate: true,
      handler(customField) {
        this.value = customField.value;
      },
    },
  },
  methods: {
    cancelEditing(stopEditing) {
      this.resetNumber();
      stopEditing();
    },
    clearNumber(stopEditing) {
      this.value = '';
      stopEditing();
      this.updateNumber();
    },
    resetNumber() {
      this.value = this.customField.value;
    },
    async updateNumber() {
      if (!this.canUpdate) return;

      const numberValue = isNumeric(this.value) ? Number(this.value) : null;

      if (numberValue === this.customField.value) {
        return;
      }

      this.isUpdating = true;

      // Create work item flow
      if (this.workItemId === newWorkItemId(this.workItemType)) {
        this.$emit('update-widget-draft', {
          customField: {
            id: this.customFieldId,
            numberValue,
          },
        });

        this.isUpdating = false;
        return;
      }

      await this.$apollo
        .mutate({
          mutation: updateWorkItemCustomFieldsMutation,
          variables: {
            input: {
              id: this.workItemId,
              customFieldsWidget: [
                {
                  customFieldId: this.customFieldId,
                  numberValue,
                },
              ],
            },
            useWorkItemFeatures: Boolean(this.glFeatures?.workItemFeaturesField),
          },
        })
        .then(({ data }) => {
          if (data.workItemUpdate.errors.length) {
            throw new Error(data.workItemUpdate.errors.join('\n'));
          }
        })
        .catch((error) => {
          this.resetNumber();
          // Send error event up to work_item_detail to show alert on page
          this.$emit(
            'error',
            sprintf(I18N_WORK_ITEM_ERROR_UPDATING, {
              workItemType: this.workItemType,
            }),
          );
          Sentry.captureException(error);
        })
        .finally(() => {
          this.isUpdating = false;
        });
    },
  },
};
</script>

<template>
  <work-item-sidebar-widget
    v-if="displayWidget"
    :can-update="canUpdate"
    :is-updating="isUpdating"
    @stop-editing="updateNumber"
  >
    <template #title>
      {{ customFieldName }}
    </template>
    <template #content>
      <div v-if="hasValue" data-testid="custom-field-value">{{ value }}</div>
      <div v-else class="gl-text-subtle" data-testid="custom-field-value">{{ __('None') }}</div>
    </template>
    <template #editing-content="{ stopEditing }">
      <div class="gl-relative gl-px-2">
        <gl-form-group :label="customFieldName" label-for="custom-field-number-input" label-sr-only>
          <gl-form-input
            id="custom-field-number-input"
            v-model="value"
            class="gl-block"
            autofocus
            :disabled="isUpdating"
            min="0"
            :placeholder="__('Enter a number')"
            type="number"
            @keydown.enter="stopEditing"
            @keydown.exact.esc.stop="cancelEditing(stopEditing)"
          />
        </gl-form-group>
        <gl-button
          v-if="showRemoveValue"
          v-gl-tooltip
          class="gl-absolute gl-right-7 gl-top-2"
          category="tertiary"
          icon="clear"
          size="small"
          :title="__('Remove number')"
          :aria-label="__('Remove number')"
          @click="clearNumber(stopEditing)"
        />
      </div>
    </template>
  </work-item-sidebar-widget>
</template>
