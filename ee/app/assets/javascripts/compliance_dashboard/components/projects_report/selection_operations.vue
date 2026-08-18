<script>
import { GlButton, GlCollapsibleListbox, GlSprintf, GlTooltip } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import FrameworkSelectionBox from './framework_selection_box.vue';

export default {
  name: 'SelectionOperations',
  components: {
    GlButton,
    GlCollapsibleListbox,
    GlSprintf,
    GlTooltip,

    FrameworkSelectionBox,
  },
  props: {
    selection: {
      type: Array,
      required: true,
    },
    isApplyInProgress: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupPath: {
      type: String,
      required: true,
    },
    defaultFramework: {
      type: Object,
      required: false,
      default: null,
    },
    isFrameworkCreatingEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change', 'create'],
  data() {
    return {
      selectedOperation: null,
      selectedFrameworks: this.defaultFramework ? [this.defaultFramework.id] : [],
    };
  },
  computed: {
    hasSelection() {
      return this.selection.length > 0;
    },
    isRemoveOperation() {
      return this.selectedOperation === this.$options.operations.REMOVE_OPERATION;
    },
    isSubmitButtonDisabled() {
      return !this.isSelectionValid || this.isApplyInProgress || !this.hasSelection;
    },
    isSubmitButtonLoading() {
      return !this.isSubmitButtonDisabled && this.isApplyInProgress;
    },
    operationsDropdownItems() {
      return [
        {
          text: this.$options.i18n.applyFramework,
          value: this.$options.operations.APPLY_OPERATION,
        },
        {
          text: this.$options.i18n.removeFramework,
          value: this.$options.operations.REMOVE_OPERATION,
        },
      ];
    },
    isSelectionValid() {
      return this.selectedOperation && this.selectedFrameworks.length;
    },
    actionButtonText() {
      if (this.isRemoveOperation) {
        return __('Remove');
      }

      return __('Apply');
    },
    actionButtonVariant() {
      if (this.isRemoveOperation) {
        return 'danger';
      }

      return 'confirm';
    },
  },
  watch: {
    selectedOperation() {
      this.selectedFrameworks = [];
    },
    defaultFramework(newValue) {
      if (newValue) {
        this.selectedFrameworks = [...this.selectedFrameworks, newValue.id];
      }
    },
  },
  methods: {
    reset() {
      this.selectedOperation = null;
      this.selectedFrameworks = [];
    },
    async apply() {
      const operations = this.selection.map((project) => ({
        projectId: project.id,
        previousFrameworkIds: this.getPreviousFrameworkIds(project),
        frameworkIds: this.getFrameworkIds(project),
      }));
      this.$emit('change', operations);
      this.reset();
    },
    getFrameworkIds(project) {
      const previousFrameworkIds = this.getPreviousFrameworkIds(project);
      if (this.isRemoveOperation) {
        return previousFrameworkIds.filter((id) => !this.selectedFrameworks.includes(id));
      }
      return [...new Set([...previousFrameworkIds, ...this.selectedFrameworks])];
    },

    getPreviousFrameworkIds(project) {
      return project.complianceFrameworks
        ? project.complianceFrameworks?.map((framework) => framework.id)
        : [];
    },
  },
  i18n: {
    dropdownActionPlaceholder: s__('ComplianceReport|Choose one bulk action'),
    applyFramework: s__('ComplianceReport|Apply frameworks to selected projects'),
    removeFramework: s__('ComplianceReport|Remove frameworks from selected projects'),
    operationSelectionTooltip: s__(
      'ComplianceReport|Select at least one project to apply the bulk action',
    ),
  },
  operations: {
    APPLY_OPERATION: 'apply',
    REMOVE_OPERATION: 'remove',
  },
};
</script>

<template>
  <section
    class="gl-border-t gl-items-center gl-border-default gl-py-5 @md/panel:gl-flex @md/panel:gl-px-5"
  >
    <span
      class="gl-mb-3 gl-inline-block gl-border-0 gl-border-solid gl-border-default gl-pr-5 @md/panel:gl-mb-0 @md/panel:gl-border-r-1"
    >
      <gl-sprintf :message="__('%{count} selected')">
        <template #count>
          <span class="gl-font-bold"> {{ selection.length }}</span>
        </template>
      </gl-sprintf>
    </span>
    <gl-tooltip :target="() => $refs.operations" :disabled="hasSelection">
      {{ $options.i18n.operationSelectionTooltip }}
    </gl-tooltip>
    <div ref="operations" class="gl-mb-4 gl-pl-0 @md/panel:gl-mb-0 @md/panel:gl-pl-5">
      <gl-collapsible-listbox
        v-model="selectedOperation"
        class="gl-mb-2 gl-block @md/panel:gl-mb-0 @md/panel:gl-inline"
        data-testid="choose-bulk-action"
        :disabled="!hasSelection"
        :toggle-text="
          selectedOperation ? selectedOperation.text : $options.i18n.dropdownActionPlaceholder
        "
        :header-text="$options.i18n.dropdownActionPlaceholder"
        :items="operationsDropdownItems"
        role="button"
        tabindex="0"
      />
      <framework-selection-box
        v-if="selectedOperation"
        v-model="selectedFrameworks"
        data-testid="choose-framework"
        :disabled="!hasSelection"
        :group-path="groupPath"
        :is-framework-creating-enabled="isFrameworkCreatingEnabled && !isRemoveOperation"
        @create="$emit('create')"
      />
    </div>

    <gl-button variant="reset" class="gl-ml-auto" :disabled="!selectedOperation" @click="reset">
      {{ __('Cancel') }}
    </gl-button>
    <gl-button
      class="gl-ml-2"
      data-testid="apply-bulk-operation-button"
      :variant="actionButtonVariant"
      :disabled="isSubmitButtonDisabled"
      :loading="isSubmitButtonLoading"
      @click="apply"
    >
      {{ actionButtonText }}
    </gl-button>
  </section>
</template>
