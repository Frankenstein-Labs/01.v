<script>
import {
  GlAlert,
  GlButton,
  GlCollapsibleListbox,
  GlKeysetPagination,
  GlSkeletonLoader,
} from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { PAGE_SIZE_OPTIONS } from '../constants';

export default {
  name: 'OverviewCard',
  components: {
    GlAlert,
    GlButton,
    GlCollapsibleListbox,
    GlKeysetPagination,
    GlSkeletonLoader,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    expanded: {
      type: Boolean,
      required: true,
    },
    expandAriaLabel: {
      type: String,
      required: true,
    },
    collapseAriaLabel: {
      type: String,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    error: {
      type: Boolean,
      required: false,
      default: false,
    },
    errorMessage: {
      type: String,
      required: false,
      default: '',
    },
    pageInfo: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    pageSize: {
      type: Number,
      required: false,
      default: null,
    },
    emptyText: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['toggle', 'next', 'prev', 'page-size-change'],
  computed: {
    showPagination() {
      return this.expanded && Boolean(this.pageInfo.hasNextPage || this.pageInfo.hasPreviousPage);
    },
    showPageSize() {
      return this.expanded && this.pageSize !== null;
    },
    pageSizeItems() {
      return PAGE_SIZE_OPTIONS.map((value) => ({ value, text: this.pageSizeLabel(value) }));
    },
    rootBindings() {
      // Expanded cards span a full row. Collapsed cards stack full-width on
      // mobile and only share a row from the `sm` breakpoint up.
      return {
        class: this.expanded
          ? 'gl-basis-full'
          : 'gl-grow gl-basis-full @sm:gl-basis-1/3 @lg:gl-basis-0',
        'data-testid': this.expanded ? 'overview-card-expanded' : 'overview-card-collapsed',
      };
    },
    buttonBindings() {
      return {
        icon: this.expanded ? 'minimize' : 'maximize',
        'aria-label': this.expanded ? this.collapseAriaLabel : this.expandAriaLabel,
        'data-testid': this.expanded ? 'collapse-button' : 'expand-button',
      };
    },
  },
  methods: {
    pageSizeLabel(size) {
      return sprintf(s__('ContinuousDeployment|Show %{size} items'), { size });
    },
  },
};
</script>

<template>
  <div
    class="gl-min-w-0 gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-p-4"
    v-bind="rootBindings"
  >
    <div class="gl-mb-3 gl-flex gl-items-center gl-justify-between">
      <h3 class="gl-m-0 gl-text-sm gl-font-bold gl-uppercase gl-text-status-neutral">
        {{ title }}
      </h3>
      <gl-button
        v-bind="buttonBindings"
        category="tertiary"
        size="small"
        @click="$emit('toggle')"
      />
    </div>

    <slot name="filters"></slot>

    <gl-skeleton-loader v-if="loading" :width="400" :height="60">
      <rect width="400" height="12" x="0" y="0" rx="4" />
      <rect width="360" height="12" x="0" y="24" rx="4" />
      <rect width="320" height="12" x="0" y="48" rx="4" />
    </gl-skeleton-loader>
    <gl-alert v-else-if="error" variant="danger" :dismissible="false" data-testid="card-error">
      {{ errorMessage }}
    </gl-alert>
    <p
      v-else-if="emptyText"
      class="gl-mb-2 gl-mt-5 gl-text-center gl-text-sm gl-italic gl-text-subtle"
      data-testid="card-empty"
    >
      {{ emptyText }}
    </p>
    <template v-else>
      <div class="gl-overflow-x-auto">
        <slot></slot>
      </div>

      <div
        v-if="showPagination || showPageSize"
        class="gl-flex gl-flex-col-reverse gl-items-center gl-gap-3 @sm:gl-mt-3 @sm:gl-flex-row @sm:gl-gap-0"
      >
        <div class="gl-hidden @sm:gl-block @sm:gl-flex-1"></div>
        <gl-keyset-pagination
          v-if="showPagination"
          v-bind="pageInfo"
          :disabled="loading"
          @next="$emit('next', $event)"
          @prev="$emit('prev', $event)"
        />
        <div
          class="gl-flex gl-w-full gl-justify-center @sm:gl-w-auto @sm:gl-flex-1 @sm:gl-justify-end"
        >
          <gl-collapsible-listbox
            v-if="showPageSize"
            size="small"
            :items="pageSizeItems"
            :selected="pageSize"
            :toggle-text="pageSizeLabel(pageSize)"
            :disabled="loading"
            data-testid="page-size-dropdown"
            @select="$emit('page-size-change', $event)"
          />
        </div>
      </div>
    </template>
  </div>
</template>
