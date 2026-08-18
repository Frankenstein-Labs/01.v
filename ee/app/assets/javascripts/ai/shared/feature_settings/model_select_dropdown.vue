<script>
import {
  GlBadge,
  GlButton,
  GlCollapsibleListbox,
  GlExperimentBadge,
  GlIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import { RELEASE_STATES } from './constants';

export default {
  name: 'ModelSelectDropdown',
  components: {
    GlBadge,
    GlButton,
    GlCollapsibleListbox,
    GlExperimentBadge,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin(), glSlotsMixin],
  props: {
    selectedOption: {
      type: Object,
      required: false,
      default: null,
    },
    items: {
      type: Array,
      required: true,
    },
    placeholderDropdownText: {
      type: String,
      required: false,
      default: '',
    },
    buttonClass: {
      type: String,
      required: false,
      default: '',
    },
    headerText: {
      type: String,
      required: false,
      default: '',
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['select'],
  data() {
    return {
      searchTerm: '',
    };
  },
  computed: {
    selected() {
      return this.selectedOption?.value || GITLAB_DEFAULT_MODEL;
    },
    dropdownToggleText() {
      return this.selectedOption?.text || this.placeholderDropdownText;
    },
    toggleSubtext() {
      return this.selectedOption?.subtext;
    },
    filteredItems() {
      if (!this.searchTerm) {
        return this.items;
      }
      // Contains both GitLab managed and self-hosted models
      const hasMixedModelOptions = this.items.some((item) => Array.isArray(item.options));

      if (hasMixedModelOptions) {
        return this.items
          .map((group) => ({
            ...group,
            options: group.options.filter((opt) =>
              opt.text.toLowerCase().includes(this.searchTerm),
            ),
          }))
          .filter((group) => group.options.length > 0);
      }

      return this.items.filter((item) => item.text.toLowerCase().includes(this.searchTerm));
    },
  },
  methods: {
    isGitLabManagedModel(model) {
      return model && model.costIndicator;
    },
    isBetaModel(model) {
      return model?.releaseState === RELEASE_STATES.BETA;
    },
    onSelect(option) {
      this.$emit('select', option);
    },
    onSearch(term) {
      this.searchTerm = (term || '').trim().toLowerCase();
    },
  },
};
</script>
<template>
  <gl-collapsible-listbox
    :selected="selected"
    data-testid="model-dropdown-selector"
    :items="filteredItems"
    :header-text="headerText"
    :loading="isLoading"
    :no-results-text="__('No results found')"
    searchable
    fluid-width
    category="primary"
    block
    @search="onSearch"
    @select="onSelect"
  >
    <template #toggle>
      <gl-button
        data-testid="toggle-button"
        :class="buttonClass"
        :disabled="disabled"
        :loading="isLoading"
        :aria-label="dropdownToggleText"
        :button-text-classes="['gl-flex gl-w-full', { '!gl-whitespace-normal': toggleSubtext }]"
        block
      >
        <div class="gl-flex gl-w-full gl-items-center gl-justify-between gl-py-2">
          <div
            data-testid="dropdown-toggle-text"
            class="gl-flex gl-flex-col gl-items-start gl-gap-1 gl-overflow-hidden gl-text-left"
          >
            <div class="gl-flex gl-w-full gl-items-center gl-overflow-hidden">
              <gl-experiment-badge
                v-if="isBetaModel(selectedOption)"
                data-testid="beta-model-selected-badge"
                class="!gl-ml-0 gl-mr-3"
                type="beta"
              />
              <span
                :class="[
                  'gl-overflow-hidden gl-text-ellipsis',
                  { 'gl-whitespace-nowrap': !toggleSubtext },
                ]"
                >{{ dropdownToggleText }}</span
              >
            </div>
            <span
              v-if="toggleSubtext"
              data-testid="dropdown-toggle-subtext"
              class="gl-overflow-hidden gl-text-ellipsis gl-text-sm gl-font-normal gl-text-subtle"
            >
              {{ toggleSubtext }}
            </span>
          </div>
          <gl-icon name="chevron-down" />
        </div>
      </gl-button>
    </template>

    <template #list-item="{ item }">
      <div class="gl-flex gl-max-w-34 gl-items-center gl-justify-between">
        <span class="gl-mr-4 gl-flex gl-flex-col">
          <span
            v-if="item.provider"
            data-testid="model-provider"
            class="gl-text-sm gl-font-semibold gl-text-subtle"
          >
            {{ item.provider }}
          </span>
          <span data-testid="model-name" :class="{ 'gl-font-bold': isGitLabManagedModel(item) }">
            {{ item.text }}
          </span>
          <span v-if="item.description" data-testid="model-description" class="gl-text-subtle">
            {{ item.description }}
          </span>
          <span class="gl-mt-2">
            <gl-badge
              v-if="item.costIndicator"
              class="gl-border-1 gl-border-solid gl-border-strong"
              data-testid="model-cost-indicator"
              variant="neutral"
            >
              {{ item.costIndicator }}
            </gl-badge>
          </span>
        </span>
        <gl-badge
          v-if="isBetaModel(item)"
          data-testid="beta-model-dropdown-badge"
          variant="neutral"
        >
          {{ __('Beta') }}
        </gl-badge>
      </div>
    </template>

    <template v-if="glSlots().footer" #footer>
      <slot name="footer"></slot>
    </template>
  </gl-collapsible-listbox>
</template>
