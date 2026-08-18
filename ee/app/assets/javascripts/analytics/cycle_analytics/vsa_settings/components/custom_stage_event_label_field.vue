<script>
import { GlButton, GlIcon, GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import getCustomStageLabels from '../graphql/get_custom_stage_labels.query.graphql';

export default {
  name: 'CustomStageEventLabelField',
  components: {
    GlButton,
    GlIcon,
    GlFormGroup,
    GlCollapsibleListbox,
  },
  inject: ['groupPath'],
  props: {
    index: {
      type: Number,
      required: true,
    },
    eventType: {
      type: String,
      required: true,
    },
    selectedLabelId: {
      type: String,
      required: false,
      default: null,
    },
    selectedLabel: {
      type: Object,
      required: false,
      default: null,
    },
    fieldLabel: {
      type: String,
      required: true,
    },
    requiresLabel: {
      type: Boolean,
      required: true,
    },
    isLabelValid: {
      type: Boolean,
      required: false,
      default: true,
    },
    labelError: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['update-label', 'error'],
  data() {
    return {
      labels: [],
      searchTerm: '',
      nextCursor: null,
      hasNextPage: false,
      isLoadingMore: false,
      localSelectedLabel: null,
    };
  },
  computed: {
    loading() {
      return this.$apollo.queries.labels.loading && !this.isLoadingMore;
    },
    fieldName() {
      const { eventType, index } = this;
      return `custom-stage-${eventType}-label-${index}`;
    },
    items() {
      return this.labels.map(({ id, title, color }) => ({ value: id, text: title, color }));
    },
    // The labels query is paginated, so the selected label is not guaranteed to be
    // in the currently loaded page. Prefer the locally remembered selection (so a
    // freshly picked label keeps rendering after the list reloads), then fall back
    // to the label persisted on the stage so the selection always renders,
    // regardless of how many labels the group has.
    displayLabel() {
      const loadedLabel = this.labels.find(({ id }) => id === this.selectedLabelId);
      if (loadedLabel) return loadedLabel;

      if (this.localSelectedLabel?.id === this.selectedLabelId) return this.localSelectedLabel;

      return this.selectedLabel;
    },
    selected: {
      get() {
        return this.selectedLabelId;
      },
      set(id) {
        // Remember the full label locally so the toggle keeps displaying it even
        // after the paginated list reloads and no longer contains the selection.
        this.localSelectedLabel = this.labels.find((label) => label.id === id) || null;
        this.$emit('update-label', { id });
      },
    },
  },
  apollo: {
    labels: {
      query: getCustomStageLabels,
      skip() {
        return !this.requiresLabel;
      },
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
      variables() {
        return {
          fullPath: this.groupPath,
          searchTerm: this.searchTerm,
        };
      },
      update({
        group: {
          labels: { nodes },
        },
      }) {
        return nodes;
      },
      result({ data }) {
        const pageInfo = data?.group?.labels?.pageInfo;
        if (pageInfo) {
          this.hasNextPage = pageInfo.hasNextPage;
          this.nextCursor = pageInfo.endCursor;
        }
      },
      error() {
        this.handleError();
      },
    },
  },
  methods: {
    handleError(message = __('There was an error fetching label data for the selected group')) {
      this.$emit('error', message);
    },
    onSearch(value) {
      const newSearchTerm = value.trim();

      if (this.searchTerm !== newSearchTerm) {
        this.searchTerm = newSearchTerm;
        this.nextCursor = null;
        this.hasNextPage = false;
        this.isLoadingMore = false;
      }
    },
    async loadMoreLabels() {
      if (this.isLoadingMore || !this.hasNextPage || this.loading) return;

      this.isLoadingMore = true;

      try {
        await this.$apollo.queries.labels.fetchMore({
          variables: {
            fullPath: this.groupPath,
            searchTerm: this.searchTerm,
            after: this.nextCursor,
          },
        });
      } catch (error) {
        this.handleError(__('There was an error loading more labels'));
      } finally {
        this.isLoadingMore = false;
      }
    },
  },
  headerText: __('Select a label'),
};
</script>
<template>
  <div class="gl-ml-2 gl-w-1/2">
    <transition name="fade">
      <gl-form-group
        v-if="requiresLabel"
        :data-testid="fieldName"
        :label="fieldLabel"
        :state="isLabelValid"
        :invalid-feedback="labelError"
      >
        <gl-collapsible-listbox
          v-model="selected"
          block
          searchable
          infinite-scroll
          :name="fieldName"
          :header-text="$options.headerText"
          :searching="loading"
          :items="items"
          :infinite-scroll-loading="isLoadingMore"
          @search="onSearch"
          @bottom-reached="loadMoreLabels"
        >
          <template #toggle>
            <gl-button
              data-testid="listbox-toggle-btn"
              block
              button-text-classes="gl-w-full gl-flex gl-justify-between"
              :class="{ 'gl-shadow-inner-1-red-500': !isLabelValid }"
            >
              <div v-if="displayLabel">
                <span
                  :style="{ backgroundColor: displayLabel.color }"
                  class="dropdown-label-box gl-inline-block"
                >
                </span>
                {{ displayLabel.title }}
              </div>
              <div v-else class="gl-text-subtle">{{ $options.headerText }}</div>
              <gl-icon name="chevron-down" />
            </gl-button>
          </template>
          <template #list-item="{ item: { text, color } }">
            <span :style="{ backgroundColor: color }" class="dropdown-label-box gl-inline-block">
            </span>
            {{ text }}
          </template>
        </gl-collapsible-listbox>
      </gl-form-group>
    </transition>
  </div>
</template>
