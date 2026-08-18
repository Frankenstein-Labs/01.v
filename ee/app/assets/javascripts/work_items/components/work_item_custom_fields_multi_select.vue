<script>
import { GlTooltipDirective, GlLink } from '@gitlab/ui';
import fuzzaldrinPlus from 'fuzzaldrin-plus';
import { s__, __, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { formatSelectOptionForCustomField, newWorkItemId } from '~/work_items/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import {
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
  I18N_WORK_ITEM_ERROR_UPDATING,
} from '~/work_items/constants';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import customFieldSelectOptionsQuery from 'ee/work_items/graphql/work_item_custom_field_select_options.query.graphql';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export default {
  name: 'WorkItemCustomFieldsMultiSelect',
  components: {
    WorkItemSidebarDropdownWidget,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['issuesListPath', 'epicsListPath', 'getWorkItemTypeConfiguration'],
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
      selectOptions: [],
      searchTerm: '',
      searchStarted: false,
      isUpdating: false,
      selectedOptions: [],
      currentlySelectedIds: [],
    };
  },
  computed: {
    workItemTypeConfiguration() {
      return this.getWorkItemTypeConfiguration(this.workItemType);
    },
    customFieldId() {
      return this.customField.customField?.id;
    },
    customFieldName() {
      return this.customField.customField?.name;
    },
    currentlySelectedText() {
      return this.defaultOptions
        .filter(({ value }) => this.currentlySelectedIds.includes(value))
        .map((option) => option.text);
    },
    hasSelectedOptions() {
      return this.currentlySelectedIds.length > 0;
    },
    dropDownLabelText() {
      return this.currentlySelectedText.join(', ');
    },
    dropdownText() {
      return this.hasSelectedOptions ? this.dropDownLabelText : __('None');
    },
    visibleOptions() {
      if (this.searchTerm) {
        return fuzzaldrinPlus.filter(this.defaultOptions, this.searchTerm, {
          key: ['text'],
        });
      }

      return this.defaultOptions;
    },
    optionsList() {
      const visibleOptions = this.visibleOptions || [];

      if (this.searchTerm || this.currentlySelectedIds.length === 0) {
        return visibleOptions;
      }

      const unselectedOptions = visibleOptions.filter(
        ({ value }) => !this.selectedOptions.find((l) => l.value === value),
      );

      return [
        { options: this.selectedOptions, text: __('Selected') },
        { options: unselectedOptions, text: __('All'), textSrOnly: true },
      ];
    },
    optionsValues() {
      return this.selectedOptions.map(({ value }) => value);
    },
    defaultOptions() {
      return this.selectOptions.map(formatSelectOptionForCustomField);
    },
    displayWidget() {
      return this.customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_MULTI_SELECT;
    },
    isValueValid() {
      return (
        this.customField.selectedOptions === null || Array.isArray(this.customField.selectedOptions)
      );
    },
    isLoadingOptionsList() {
      return this.$apollo.queries.selectOptions.loading;
    },
    isEpic() {
      return this.workItemTypeConfiguration?.isGroupWorkItemType;
    },
  },
  watch: {
    customField: {
      immediate: true,
      handler(customField) {
        if (this.isValueValid) {
          this.selectedOptions =
            customField.selectedOptions?.map(formatSelectOptionForCustomField) || [];
          this.currentlySelectedIds = this.selectedOptions.map(({ value }) => value);
        }
      },
    },
  },
  apollo: {
    selectOptions: {
      query: customFieldSelectOptionsQuery,
      variables() {
        return {
          fieldId: this.customFieldId,
        };
      },
      skip() {
        return !this.searchStarted || !this.customFieldId;
      },
      update(data) {
        return data?.customField?.selectOptions || [];
      },
      error(e) {
        const msg = sprintf(
          s__(
            'WorkItemCustomFields|Options could not be loaded for field: %{customFieldName}. Please try again.',
          ),
          {
            customFieldName: this.customFieldName,
          },
        );

        this.$emit('error', msg);
        Sentry.captureException(e);
      },
    },
  },
  methods: {
    onDropdownShown() {
      this.searchTerm = '';
      this.searchStarted = true;
    },
    search(searchTerm) {
      this.searchTerm = searchTerm;
      this.searchStarted = true;
    },
    updateSelection(options) {
      this.currentlySelectedIds = options;
    },
    async updateSelectedOptions(selectedOptionsValues) {
      if (!this.canUpdate) return;

      this.isUpdating = true;

      // Create work item flow
      if (this.workItemId === newWorkItemId(this.workItemType)) {
        const selectedOptions = selectedOptionsValues
          ? this.selectOptions.filter(({ id }) => selectedOptionsValues.includes(id))
          : [];

        this.$emit('update-widget-draft', {
          customField: {
            id: this.customFieldId,
            selectedOptions,
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
                  selectedOptionIds: selectedOptionsValues,
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
          const msg = sprintf(I18N_WORK_ITEM_ERROR_UPDATING, {
            workItemType: this.workItemType,
          });
          this.$emit('error', msg);
          Sentry.captureException(error);
        })
        .finally(() => {
          this.searchTerm = '';
          this.isUpdating = false;
        });
    },
    searchPath(optionId) {
      const customFieldId = getIdFromGraphQLId(this.customFieldId);
      const customFieldOptionId = getIdFromGraphQLId(optionId);

      const query = `?custom-field[${customFieldId}]=${customFieldOptionId}`;
      return `${this.isEpic ? this.epicsListPath : this.issuesListPath}/${query}`;
    },
  },
};
</script>

<template>
  <work-item-sidebar-dropdown-widget
    v-if="displayWidget"
    :key="customFieldId"
    dropdown-name="select"
    :dropdown-label="customFieldName"
    :can-update="canUpdate"
    :loading="isLoadingOptionsList"
    :list-items="optionsList"
    :item-value="optionsValues"
    :toggle-dropdown-text="dropdownText"
    :header-text="s__('WorkItemCustomFields|Select one or more')"
    :update-in-progress="isUpdating"
    multi-select
    clear-search-on-item-select
    @dropdown-shown="onDropdownShown"
    @search-started="search"
    @update-value="updateSelectedOptions"
    @updateSelected="updateSelection"
  >
    <template #list-item="{ item }">
      <span class="gl-break-words">{{ item.text }}</span>
    </template>
    <template #readonly>
      <p v-for="option in selectedOptions" :key="option.value" class="gl-fit-content gl-mb-2">
        <gl-link
          v-gl-tooltip
          class="gl-truncate"
          :href="searchPath(option.value)"
          :title="option.text"
          data-testid="option-text"
        >
          {{ option.text }}
        </gl-link>
      </p>
    </template>
  </work-item-sidebar-dropdown-widget>
</template>
