<script>
import {
  GlButton,
  GlCollapsibleListbox,
  GlFormGroup,
  GlFormInput,
  GlFormSelect,
  GlIcon,
  GlModal,
  GlAlert,
  GlLoadingIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import { uniqueId } from 'lodash-es';
import Draggable from '~/lib/utils/vue3compat/draggable_compat.vue';
import { defaultSortableOptions, DRAG_DELAY } from '~/sortable/constants';
import { __, s__, sprintf } from '~/locale';
import { WIDGET_TYPE_CUSTOM_FIELDS } from '~/work_items/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createCustomFieldMutation from './create_custom_field.mutation.graphql';
import updateCustomFieldMutation from './update_custom_field.mutation.graphql';
import groupCustomFieldQuery from './group_custom_field.query.graphql';
import namespaceWorkItemTypesQuery from './group_work_item_types_for_select.query.graphql';

export const FIELD_TYPE_OPTIONS = [
  { value: 'SINGLE_SELECT', text: s__('WorkItem|Single select') },
  { value: 'MULTI_SELECT', text: s__('WorkItem|Multi select') },
  { value: 'NUMBER', text: s__('WorkItem|Number') },
  { value: 'TEXT', text: s__('WorkItem|Text') },
];

export default {
  name: 'CustomFieldForm',
  components: {
    Draggable,
    GlButton,
    GlCollapsibleListbox,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlIcon,
    GlModal,
    GlAlert,
    GlLoadingIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    customFieldId: {
      type: String,
      required: false,
      default: null,
    },
    customFieldName: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['created', 'updated'],
  data() {
    return {
      visible: false,
      loading: false,
      fieldTypes: FIELD_TYPE_OPTIONS,
      formData: {
        fieldType: FIELD_TYPE_OPTIONS[0].value,
        fieldName: '',
        workItemTypes: [],
        selectOptions: [{ localId: uniqueId(), value: '' }],
      },
      formState: {
        fieldName: null,
        selectOptions: null,
      },
      mutationError: '',
      workItemTypes: [],
    };
  },
  apollo: {
    workItemTypes: {
      query: namespaceWorkItemTypesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.namespace?.workItemTypes?.nodes || [];
      },
      error(error) {
        Sentry.captureException(error);
        this.mutationError = s__('WorkItem|Error loading work item types');
      },
    },
  },
  computed: {
    isSelect() {
      return ['SINGLE_SELECT', 'MULTI_SELECT'].includes(this.formData.fieldType);
    },
    isEditing() {
      return Boolean(this.customFieldId);
    },
    editButtonText() {
      return sprintf(s__('WorkItem|Edit %{fieldName}'), { fieldName: this.customFieldName });
    },
    modalTitle() {
      return this.isEditing
        ? sprintf(s__('WorkItem|Edit custom field %{fieldName}'), {
            fieldName: this.customFieldName,
          })
        : s__('WorkItem|New custom field');
    },
    saveButtonText() {
      return this.isEditing ? __('Update') : __('Save');
    },
    dropdownToggleText() {
      if (this.formData.workItemTypes.length === 0) {
        return s__('WorkItem|Select types');
      }

      return this.formData.workItemTypes
        .filter((id) => {
          // Prob unnecessary. or should log error?
          // this maybe only happens if the work item type is deleted
          // or if an ID is malformed
          return Boolean(this.workItemTypes.find((type) => type.id === id));
        })
        .map((id) => {
          const { name } = this.workItemTypes.find((type) => type.id === id);
          return name;
        })
        .join(', ');
    },
    workItemTypesForListbox() {
      return this.workItemTypes
        ?.filter((type) =>
          // Only include Work Item types that support `CUSTOM_FIELDS` as
          // supported widget type.
          type.widgetDefinitions.some(
            (definition) => definition.type === WIDGET_TYPE_CUSTOM_FIELDS,
          ),
        )
        ?.map((type) => ({
          value: type.id,
          text: type.name,
          name: type.name,
        }));
    },
    dragOptions() {
      return {
        ...defaultSortableOptions,
        handle: '.drag-handle',
        delay: DRAG_DELAY,
        delayOnTouchOnly: true,
      };
    },
  },
  methods: {
    async addSelectOption() {
      this.formData.selectOptions.push({ localId: uniqueId(), value: '' });
      await nextTick();
      this.$refs[`selectOptions${this.formData.selectOptions.length - 1}`][0].$el.focus();
    },
    removeSelectOption(index) {
      this.formData.selectOptions.splice(index, 1);
      this.validateSelectOptions();
    },
    workItemTypeSelected(selected) {
      this.formData.workItemTypes = selected;
    },
    focusNameInput() {
      this.$refs.nameInput?.$el.focus();
    },
    validateForm() {
      this.validateFieldName();
      if (this.isSelect) {
        this.validateSelectOptions();
      }
      return Object.values(this.formState).every((state) => state !== false);
    },
    validateFieldName() {
      this.formState.fieldName = this.formData.fieldName.trim() !== '';
    },
    validateSelectOptions() {
      this.formState.selectOptions = this.formData.selectOptions.some(
        (option) => option.value.trim() !== '',
      );
    },
    removeEmptyOptions() {
      this.formData.selectOptions = this.formData.selectOptions.filter((option) =>
        option.value.trim(),
      );
    },
    // Support pasting many lines at once and translate them to new options
    parsePastedOptions(event) {
      const clipboardData = event.clipboardData || window.clipboardData;
      const pastedText = clipboardData.getData('text');

      if (!pastedText.trim()) return;

      const lines = pastedText
        .split('\n')
        .map((line) => line.trim())
        .filter((line) => line !== '');

      // If paste content is not multiline, just paste as normal
      if (lines.length < 2) return;

      // If paste content is multiline, paste first line into selection, rest as new options
      event.preventDefault();

      const currentIndex = parseInt(event.target.dataset.optionIndex, 10);
      const currentInput = event.target;
      const currentValue = this.formData.selectOptions[currentIndex].value;

      const { selectionStart, selectionEnd } = currentInput;

      // Respect user selection for first line so it pastes as it would otherwise, e.g. replacing selected text
      const newValue =
        currentValue.substring(0, selectionStart) + lines[0] + currentValue.substring(selectionEnd);

      this.formData.selectOptions[currentIndex] = {
        ...this.formData.selectOptions[currentIndex],
        value: newValue,
      };

      const newOptions = lines.slice(1).map((line) => ({
        localId: uniqueId(),
        value: line,
      }));
      this.formData.selectOptions.splice(currentIndex + 1, 0, ...newOptions);

      this.validateSelectOptions();
    },
    resetForm() {
      this.formData = {
        fieldType: FIELD_TYPE_OPTIONS[0].value,
        fieldName: '',
        workItemTypes: [],
        selectOptions: [{ localId: uniqueId(), value: '' }],
      };
      this.formState = {
        fieldName: null,
        selectOptions: null,
      };
      this.mutationError = '';
    },
    async saveCustomField() {
      if (!this.validateForm()) {
        return;
      }
      this.removeEmptyOptions();
      this.mutationError = '';
      this.loading = true;
      try {
        const mutation = this.isEditing ? updateCustomFieldMutation : createCustomFieldMutation;
        const variables = this.isEditing
          ? {
              id: this.customFieldId,
              name: this.formData.fieldName,
              selectOptions: this.isSelect
                ? this.formData.selectOptions.map((opt) => ({
                    id: opt.id,
                    value: opt.value,
                  }))
                : undefined,
              workItemTypeIds: this.formData.workItemTypes,
            }
          : {
              groupPath: this.fullPath,
              name: this.formData.fieldName,
              fieldType: this.formData.fieldType,
              selectOptions: this.isSelect
                ? this.formData.selectOptions.map((opt) => ({
                    value: opt.value,
                  }))
                : undefined,
              workItemTypeIds: this.formData.workItemTypes,
            };

        const { data } = await this.$apollo.mutate({
          mutation,
          variables,
        });

        const resultKey = this.isEditing ? 'customFieldUpdate' : 'customFieldCreate';
        if (data?.[resultKey]?.errors?.length) {
          throw new Error(data[resultKey].errors[0]);
        }

        this.$emit(this.isEditing ? 'updated' : 'created');
        this.visible = false;
        this.resetForm();
      } catch (error) {
        Sentry.captureException(error);
        this.mutationError =
          error.message || s__('WorkItem|An error occurred while saving the custom field.');
      } finally {
        this.loading = false;
      }
    },
    async loadCustomField() {
      if (!this.isEditing) return;

      this.loading = true;
      try {
        const { data } = await this.$apollo.query({
          query: groupCustomFieldQuery,
          variables: {
            fullPath: this.fullPath,
            fieldId: this.customFieldId,
          },
        });

        const customField = data?.group?.customField;
        if (customField) {
          const { name, fieldType, selectOptions, workItemTypes } = customField;
          this.formData = {
            fieldName: name,
            fieldType,
            workItemTypes: workItemTypes.map((type) => type.id),
            selectOptions:
              selectOptions.length > 0
                ? JSON.parse(JSON.stringify(selectOptions))
                : [{ localId: uniqueId(), value: '' }],
          };
        }
      } catch (error) {
        Sentry.captureException(error);
        this.mutationError = s__(
          'WorkItemCustomField|An error occurred while loading the custom field',
        );
      } finally {
        this.loading = false;
      }
    },
    openModal() {
      this.visible = true;
      this.loadCustomField();
    },
  },
};
</script>

<template>
  <div>
    <gl-button
      v-if="isEditing"
      v-gl-tooltip="editButtonText"
      :aria-label="editButtonText"
      icon="pencil"
      category="tertiary"
      data-testid="toggle-edit-modal"
      @click="openModal"
    />
    <gl-button v-else size="small" data-testid="toggle-modal" @click="openModal">{{
      s__('WorkItem|Create field')
    }}</gl-button>
    <gl-modal
      :modal-id="isEditing ? 'edit-work-item-custom-field' : 'new-work-item-custom-field'"
      :visible="visible"
      :title="modalTitle"
      size="sm"
      scrollable
      @shown="focusNameInput"
      @hide="visible = false"
    >
      <gl-loading-icon v-if="loading" size="lg" class="gl-my-7" />
      <template v-else>
        <gl-form-group
          v-if="!isEditing"
          :label="s__('WorkItemCustomField|Type')"
          label-for="field-type"
        >
          <gl-form-select
            id="field-type"
            v-model="formData.fieldType"
            :options="fieldTypes"
            width="md"
          />
        </gl-form-group>

        <gl-form-group
          :label="s__('WorkItemCustomField|Name')"
          label-for="field-name"
          data-testid="custom-field-name"
          :invalid-feedback="s__('WorkItemCustomField|Name is required.')"
          :state="formState.fieldName"
        >
          <gl-form-input
            id="field-name"
            ref="nameInput"
            v-model="formData.fieldName"
            width="md"
            :state="formState.fieldName"
            autocomplete="off"
            @input="validateFieldName"
          />
        </gl-form-group>
        <gl-form-group
          :label="s__('WorkItemCustomField|Use on')"
          label-for="field-use-on"
          data-testid="custom-field-use-on"
        >
          <gl-collapsible-listbox
            id="field-use-on"
            ref="workItemTypeListbox"
            :items="workItemTypesForListbox"
            :loading="$apollo.queries.workItemTypes.loading"
            :selected="formData.workItemTypes"
            :toggle-text="dropdownToggleText"
            toggle-class="gl-form-input-md"
            block
            multiple
            @select="workItemTypeSelected"
          />
        </gl-form-group>
        <gl-form-group
          v-if="isSelect"
          :label="s__('WorkItemCustomField|Options')"
          data-testid="custom-field-options"
          :state="formState.selectOptions"
          :invalid-feedback="s__('WorkItemCustomField|At least one option is required.')"
        >
          <template #label-description>
            <span class="gl-text-sm">
              {{
                s__(
                  'WorkItemCustomField|To add multiple options at once, paste a list of items, one per line.',
                )
              }}
            </span></template
          >
          <draggable
            v-model="formData.selectOptions"
            v-bind="dragOptions"
            :item-key="(option) => option.localId || option.id"
          >
            <div
              v-for="(selectOption, index) in formData.selectOptions"
              :key="selectOption.localId || selectOption.id"
              class="gl-mb-3 gl-flex gl-items-center gl-gap-2"
            >
              <gl-icon
                v-if="formData.selectOptions.length > 1"
                name="grip"
                class="drag-handle gl-cursor-grab"
                role="img"
                aria-hidden="true"
              />
              <gl-form-input
                :ref="`selectOptions${index}`"
                v-model="selectOption.value"
                :data-testid="`select-options-${index}`"
                :data-option-index="index"
                @input="validateSelectOptions"
                @paste="parsePastedOptions"
                @keyup.enter="addSelectOption"
              />
              <gl-button
                v-if="formData.selectOptions.length > 1"
                category="tertiary"
                icon="remove"
                :aria-label="s__('WorkItemCustomField|Remove')"
                :data-testid="`remove-select-option-${index}`"
                @click="removeSelectOption(index)"
              />
            </div>
          </draggable>

          <gl-button
            data-testid="add-select-option"
            category="tertiary"
            icon="plus"
            @click="addSelectOption"
            >{{ s__('WorkItemCustomField|Add option') }}</gl-button
          >
        </gl-form-group>

        <gl-alert v-if="mutationError" variant="danger" :dismissible="false" class="gl-mt-5">
          {{ mutationError }}
        </gl-alert>
      </template>

      <template #modal-footer>
        <gl-button @click="visible = false">{{ __('Cancel') }}</gl-button>
        <gl-button
          :data-testid="isEditing ? 'update-custom-field' : 'save-custom-field'"
          variant="confirm"
          @click="saveCustomField"
          >{{ saveButtonText }}</gl-button
        >
      </template>
    </gl-modal>
  </div>
</template>
<style>
.is-ghost {
  opacity: 0.3;
  pointer-events: none;
}
</style>
