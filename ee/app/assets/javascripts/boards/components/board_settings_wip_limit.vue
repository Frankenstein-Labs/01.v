<script>
import { GlButton, GlFormInput, GlForm, GlCollapsibleListbox } from '@gitlab/ui';
import { __, n__, sprintf } from '~/locale';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';
import { setError } from '~/boards/graphql/cache_updates';
import { WIP_ITEMS, WIP_WEIGHT, WIP_CATEGORY_LIST } from '~/boards/constants';
import listUpdateLimitMetricsMutation from '../graphql/list_update_limit_metrics.mutation.graphql';

export default {
  name: 'BoardSettingsWipLimit',
  i18n: {
    wipLimitText: __('Work in progress limit'),
    editButtonText: __('Edit'),
    noneText: __('None'),
    inputPlaceholderText: __('Enter a number'),
    removeLimitText: __('Remove limit'),
    updateListError: __('Something went wrong while updating your list settings'),
  },
  components: {
    GlButton,
    GlFormInput,
    GlForm,
    GlCollapsibleListbox,
  },
  directives: {
    autofocusonshow,
  },
  props: {
    activeListId: {
      type: String,
      required: true,
    },
    maxIssueCount: {
      type: Number,
      required: false,
      default: 0,
    },
    maxIssueWeight: {
      type: Number,
      required: false,
      default: 0,
    },
    currentLimitMetric: {
      type: String,
      required: false,
      default: WIP_ITEMS,
    },
    toggleAriaLabelledBy: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['error'],
  data() {
    return {
      currentWipLimit: null,
      edit: false,
      updating: false,
      wipCategoryList: WIP_CATEGORY_LIST,
      selectedWIPCategory: this.currentLimitMetric || WIP_ITEMS,
      wipCategoryUpdated: false,
      initialWipLimitValue: null,
      limitValueUpdated: false,
      isDropdownOpen: false,
    };
  },
  computed: {
    wipLimitTypeText() {
      if (this.selectedWIPCategory === WIP_WEIGHT) {
        return this.maxIssueWeight > 0
          ? sprintf(__('Weight - %{maxIssueWeight}'), { maxIssueWeight: this.maxIssueWeight || 0 })
          : __('Weight');
      }

      return this.maxIssueCount > 0
        ? n__('Item - %d', 'Items - %d', this.maxIssueCount || 0)
        : __('Items');
    },
    wipLimitIsSet() {
      if (this.selectedWIPCategory === WIP_WEIGHT) {
        return this.maxIssueWeight !== 0;
      }
      return this.maxIssueCount !== 0;
    },
    activeListWipLimit() {
      if (this.currentWipLimit === 0 || !this.wipLimitIsSet) {
        return this.$options.i18n.noneText;
      }
      return this.wipLimitTypeText;
    },
    wipLimitDisplayValue() {
      return this.currentWipLimit || this.currentWipLimit ? this.currentWipLimit : null;
    },
  },
  methods: {
    showInput() {
      this.edit = true;

      if (this.maxIssueWeight || this.maxIssueCount) {
        this.currentWipLimit =
          this.currentLimitMetric === WIP_WEIGHT ? this.maxIssueWeight : this.maxIssueCount;
      }

      this.initialWipLimitValue = this.currentWipLimit;
      this.wipCategoryUpdated = false;
      this.limitValueUpdated = false;
    },
    handleWipLimitChange(event) {
      const wipLimit = event && event.target ? event.target.value : event;
      this.limitValueUpdated = true;
      if (!wipLimit || Number.isNaN(Number(wipLimit))) {
        this.currentWipLimit = 0;
      } else {
        this.currentWipLimit = Number(wipLimit);
      }
    },
    resetStateAfterUpdate() {
      this.edit = false;
      this.updating = false;
      this.currentWipLimit = null;
      this.wipCategoryUpdated = false;
      this.initialWipLimitValue = null;
      this.limitValueUpdated = false;
      this.isDropdownOpen = false;
    },
    offFocus() {
      this.$nextTick(() => {
        if (!this.$refs.wipForm) {
          return;
        }

        const dropdownEl = this.$refs.wipCategoryDropdown?.$el;
        const inputEl = this.$refs.wipInput?.$el || this.$refs.wipInput;
        const isNewFocusInside =
          dropdownEl?.contains(this.lastFocusedElement) ||
          inputEl?.contains(this.lastFocusedElement);

        if (isNewFocusInside) {
          return;
        }

        const isClickOutside =
          !this.$refs.wipForm?.$el?.contains(document.activeElement) &&
          !this.$refs.wipCategoryDropdown?.$el?.contains(document.activeElement);

        if (isClickOutside) {
          if (!this.limitValueUpdated && !this.wipCategoryUpdated) {
            this.edit = false;
            return;
          }

          this.applyChanges();
        }
      });
    },

    clearWipLimit() {
      this.updateWipLimit({ listId: this.activeListId, maxIssueWeight: 0, maxIssueCount: 0 });
    },
    async updateWipLimit({ listId, maxIssueWeight, maxIssueCount }) {
      try {
        await this.$apollo.mutate({
          mutation: listUpdateLimitMetricsMutation,
          variables: {
            input: {
              listId,
              maxIssueCount,
              maxIssueWeight,
              limitMetric: this.selectedWIPCategory,
            },
          },
        });

        this.resetStateAfterUpdate();
      } catch (error) {
        setError({
          error,
          message: this.$options.i18n.updateListError,
        });
      }
    },
    updateMetric(value) {
      this.selectedWIPCategory = value;

      this.$nextTick(() => {
        this.wipCategoryUpdated = true;
      });
    },
    applyChanges() {
      if (!this.limitValueUpdated && !this.wipCategoryUpdated) {
        this.edit = false;
        return;
      }

      let valueToSave = this.currentWipLimit;

      if (valueToSave === null) {
        valueToSave =
          this.selectedWIPCategory === WIP_WEIGHT ? this.maxIssueWeight : this.maxIssueCount;
      }

      this.updating = true;

      this.updateWipLimit({
        listId: this.activeListId,
        maxIssueWeight: this.selectedWIPCategory === WIP_WEIGHT ? valueToSave : 0,
        maxIssueCount: this.selectedWIPCategory === WIP_ITEMS ? valueToSave : 0,
      })
        .then(() => {
          this.$nextTick(() => {
            this.currentWipLimit = valueToSave;
            this.updating = false;

            if (!this.limitValueUpdated && this.wipCategoryUpdated) {
              this.wipCategoryUpdated = false;
              return;
            }

            this.edit = false;

            this.wipCategoryUpdated = false;
            this.limitValueUpdated = false;
          });
        })
        .catch(() => {
          this.$emit('error', this.updateListError);
          this.updating = false;
        });
    },
    setDropdownState(isOpen) {
      this.isDropdownOpen = isOpen;
    },
    handleEscape(event) {
      event.stopPropagation();
      event.preventDefault();
      this.edit = false;
    },
    focusInputAfterDropdown() {
      this.isDropdownOpen = false;
    },

    saveAndExit() {
      if (this.wipCategoryUpdated && !this.limitValueUpdated) {
        this.applyChanges();
        return;
      }
      this.applyChanges();
    },
    handleMouseDown(event) {
      const dropdownEl = this.$refs.wipCategoryDropdown?.$el;
      const inputEl = this.$refs.wipInput?.$el || this.$refs.wipInput;

      this.clickedInside = dropdownEl?.contains(event.target) || inputEl?.contains(event.target);
    },
    handleFocusIn(event) {
      this.lastFocusedElement = event.target;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-justify-between">
    <div class="gl-mb-2 gl-flex gl-items-center gl-justify-between">
      <label class="gl-m-0">{{ $options.i18n.wipLimitText }}</label>
      <gl-button
        v-if="!edit"
        class="gl-h-full gl-border-0"
        category="tertiary"
        size="small"
        data-testid="edit-button"
        @click="showInput"
      >
        {{ $options.i18n.editButtonText }}
      </gl-button>
      <gl-button
        v-if="edit"
        class="gl-h-full gl-border-0"
        category="tertiary"
        size="small"
        data-testid="apply-button"
        :disabled="!limitValueUpdated && !wipCategoryUpdated"
        @click.stop="applyChanges"
      >
        {{ __('Apply') }}
      </gl-button>
    </div>
    <gl-form
      v-if="edit"
      ref="wipForm"
      class="gl-flex gl-items-center gl-justify-between gl-gap-3"
      @focusout="offFocus"
      @mousedown="handleMouseDown"
      @focusin="handleFocusIn"
    >
      <gl-collapsible-listbox
        ref="wipCategoryDropdown"
        v-model="selectedWIPCategory"
        :items="wipCategoryList"
        :toggle-aria-labelled-by="toggleAriaLabelledBy"
        role="button"
        @select="updateMetric"
        @keydown.enter.prevent="saveAndExit"
        @shown="setDropdownState(true)"
        @hidden="focusInputAfterDropdown"
      >
        <template #list-item="{ item }">
          <slot name="list-item" :item="item">{{ item.text }}</slot>
        </template>
      </gl-collapsible-listbox>
      <gl-form-input
        v-if="edit"
        ref="wipInput"
        v-autofocusonshow
        :value="wipLimitDisplayValue"
        :disabled="updating"
        :placeholder="$options.i18n.inputPlaceholderText"
        trim
        number
        type="number"
        min="0"
        @input="handleWipLimitChange"
        @change="handleWipLimitChange"
        @keydown.enter.prevent="saveAndExit"
        @keydown.esc="handleEscape"
      />
    </gl-form>
    <div v-else class="gl-flex gl-items-center gl-gap-1">
      <p class="gl-m-0 gl-gap-1 gl-font-bold gl-text-subtle" data-testid="wip-limit">
        {{ activeListWipLimit }}
      </p>
      <template v-if="wipLimitIsSet">
        <span class="gl-ml-1"></span>
        <gl-button
          class="gl-h-full gl-border-0 gl-text-subtle"
          category="tertiary"
          size="small"
          data-testid="remove-limit"
          @click="clearWipLimit"
        >
          {{ $options.i18n.removeLimitText }}
        </gl-button>
      </template>
    </div>
  </div>
</template>
