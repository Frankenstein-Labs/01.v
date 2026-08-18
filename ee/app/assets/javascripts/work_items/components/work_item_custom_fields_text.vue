<script>
import {
  GlButton,
  GlFormGroup,
  GlFormInput,
  GlLink,
  GlTooltipDirective,
  GlTruncate,
} from '@gitlab/ui';
import { n__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { newWorkItemId } from '~/work_items/utils';
import { CUSTOM_FIELDS_TYPE_TEXT, I18N_WORK_ITEM_ERROR_UPDATING } from '~/work_items/constants';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import { isValidURL } from '~/lib/utils/url_utility';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export const CHARACTER_LIMIT = 1024;

export default {
  name: 'WorkItemCustomFieldsText',
  CHARACTER_LIMIT,
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlLink,
    GlTruncate,
    WorkItemSidebarWidget,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemId: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: false,
      default: '',
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
    charactersRemaining() {
      return this.value == null || this.isValueEmpty
        ? CHARACTER_LIMIT
        : CHARACTER_LIMIT - this.value.length;
    },
    hasValue() {
      if (this.isValueValid) {
        return !this.isValueEmpty;
      }
      return false;
    },
    inputWarning() {
      // only display warning if we're over 90% the characters limit
      return this.charactersRemaining <= CHARACTER_LIMIT * 0.1
        ? n__('%d character remaining.', '%d characters remaining.', this.charactersRemaining)
        : undefined;
    },
    isLink() {
      return isValidURL(this.customField.value);
    },
    isValueValid() {
      return this.value !== null && typeof this.value === 'string';
    },
    isValueEmpty() {
      return !this.value.trim();
    },
    showRemoveValue() {
      return this.hasValue && !this.isUpdating;
    },
    displayWidget() {
      return this.customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_TEXT;
    },
  },
  watch: {
    // Need this check to manage the update, specifically when clearing the value
    customField: {
      immediate: true,
      handler(customField) {
        this.value = customField.value;
      },
    },
  },
  methods: {
    cancelEditing(stopEditing) {
      this.resetText();
      stopEditing();
    },
    clearText(stopEditing) {
      this.value = '';
      stopEditing();
      this.updateText();
    },
    resetText() {
      this.value = this.customField.value;
    },
    updateText() {
      if (!this.canUpdate) return;

      const textValue = this.value?.trim() === '' ? null : this.value;

      if (textValue === this.customField.value) {
        return;
      }

      this.isUpdating = true;
      this.isEditing = false;

      // Create work item flow
      if (this.workItemId === newWorkItemId(this.workItemType)) {
        this.$emit('update-widget-draft', {
          customField: {
            id: this.customFieldId,
            textValue,
          },
        });

        this.isUpdating = false;
        return;
      }

      this.$apollo
        .mutate({
          mutation: updateWorkItemCustomFieldsMutation,
          variables: {
            input: {
              id: this.workItemId,
              customFieldsWidget: [
                {
                  customFieldId: this.customFieldId,
                  textValue,
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
          this.resetText();
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
    @stop-editing="updateText"
  >
    <template #title>
      {{ customFieldName }}
    </template>
    <template #content>
      <template v-if="hasValue">
        <div v-if="isLink" class="gl-flex">
          <gl-link
            v-gl-tooltip
            is-unsafe-link
            target="_blank"
            class="gl-truncate"
            :href="value"
            :title="value"
            data-testid="custom-field-value"
          >
            {{ value }}
          </gl-link>
        </div>
        <span v-else v-gl-tooltip :title="value">
          <gl-truncate :text="value" data-testid="custom-field-value" />
        </span>
      </template>
      <div v-else class="gl-text-subtle" data-testid="custom-field-value">{{ __('None') }}</div>
    </template>
    <template #editing-content="{ stopEditing }">
      <div class="gl-relative gl-px-2">
        <gl-form-group
          :description="inputWarning"
          :label="customFieldName"
          label-for="custom-field-text-input"
          label-sr-only
        >
          <gl-form-input
            id="custom-field-text-input"
            v-model="value"
            autofocus
            :disabled="isUpdating"
            :maxlength="$options.CHARACTER_LIMIT"
            :placeholder="__('Enter text')"
            @keydown.enter="stopEditing"
            @keydown.exact.esc.stop="cancelEditing(stopEditing)"
          />
        </gl-form-group>
        <gl-button
          v-if="showRemoveValue"
          v-gl-tooltip
          class="gl-absolute gl-right-3 gl-top-2"
          category="tertiary"
          icon="clear"
          size="small"
          :title="__('Remove text')"
          :aria-label="__('Remove text')"
          @click="clearText(stopEditing)"
        />
      </div>
    </template>
  </work-item-sidebar-widget>
</template>

<style scoped>
input {
  padding-right: 28px !important;
}
</style>
