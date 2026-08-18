<script>
import { GlButton, GlSprintf } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';

const ITEMS_MAX_LIST = 5;
const NO_STYLE_LIST_ITEMS_CSS = ['gl-list-none'];
const INLINE_STYLE_CSS = ['gl-flex', 'gl-flex-wrap', 'gl-gap-2'];

export default {
  NO_STYLE_LIST_ITEMS_CSS,
  INLINE_STYLE_CSS,
  name: 'ToggleList',
  components: {
    GlButton,
    GlSprintf,
  },
  props: {
    items: {
      type: Array,
      required: true,
      validator: (items) => items.length && items.every((item) => typeof item === 'string'),
    },
    bulletStyle: {
      type: Boolean,
      required: false,
      default: false,
    },
    customButtonText: {
      type: String,
      required: false,
      default: '',
    },
    customCloseButtonText: {
      type: String,
      required: false,
      default: '',
    },
    hasNextPage: {
      type: Boolean,
      required: false,
      default: false,
    },
    page: {
      type: Number,
      required: false,
      default: 1,
    },
    itemsToShow: {
      type: Number,
      required: false,
      default: 0,
    },
    inlineList: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['load-next-page'],
  data() {
    return {
      visibleItemIndex: ITEMS_MAX_LIST * this.page,
    };
  },
  computed: {
    tags() {
      return this.inlineList ? { wrapper: 'div', list: 'span' } : { wrapper: 'ul', list: 'li' };
    },
    currentPage() {
      return this.hasNextPage ? this.page : 1;
    },
    buttonText() {
      if (this.isInitialState || this.hasNextPage) {
        const itemsLength = this.items.length - ITEMS_MAX_LIST;

        if (this.customButtonText) return this.customButtonText;

        return sprintf(__('+ %{itemsLength} more'), {
          itemsLength,
        });
      }

      return this.customCloseButtonText || s__('SecurityOrchestration|Hide extra items');
    },
    isInitialState() {
      return this.visibleItemIndex === ITEMS_MAX_LIST;
    },
    initialList() {
      return this.itemsFormatted.slice(0, this.visibleItemIndex * this.currentPage);
    },
    showButton() {
      return (this.items.length > ITEMS_MAX_LIST || this.hasNextPage) && !this.hasHiddenLabels;
    },
    hiddenLabelsText() {
      return sprintf(__('+ %{hiddenLabelsLength} more'), {
        hiddenLabelsLength: this.hiddenLabelsLength,
      });
    },
    hiddenLabelsLength() {
      const difference = this.items.length - this.sanitizedLabelsTo;
      return Math.max(difference, 0);
    },
    sanitizedLabelsTo() {
      return Number.isNaN(this.itemsToShow) ? 0 : Math.ceil(this.itemsToShow);
    },
    hasHiddenLabels() {
      const { length } = this.items;

      return length > 0 && this.sanitizedLabelsTo > 0 && this.sanitizedLabelsTo < length;
    },
    itemsFormatted() {
      return this.sanitizedLabelsTo === 0
        ? this.items
        : this.items.slice(0, this.sanitizedLabelsTo);
    },
    cssClasses() {
      if (this.inlineList) {
        return this.$options.INLINE_STYLE_CSS;
      }

      if (!this.bulletStyle && !this.inlineList) {
        return this.$options.NO_STYLE_LIST_ITEMS_CSS;
      }

      return '';
    },
  },
  methods: {
    toggleItemsLength() {
      if (this.hasNextPage) {
        this.$emit('load-next-page');
      } else {
        this.visibleItemIndex = this.isInitialState ? this.items.length : ITEMS_MAX_LIST;
      }
    },
  },
};
</script>

<template>
  <div>
    <component :is="tags.wrapper" :class="cssClasses" data-testid="items-list" class="gl-m-0">
      <component
        :is="tags.list"
        v-for="(item, itemIdx) in initialList"
        :key="itemIdx"
        data-testid="list-item"
        class="gl-mt-2"
      >
        <gl-sprintf :message="item">
          <template #code="{ content }">
            <code>{{ content }}</code>
          </template>
        </gl-sprintf>
      </component>
    </component>

    <p v-if="hasHiddenLabels" data-testid="hidden-items-text" class="gl-m-0 gl-mt-3">
      {{ hiddenLabelsText }}
    </p>

    <gl-button
      v-if="showButton"
      class="gl-ml-8 gl-mt-2"
      category="tertiary"
      variant="link"
      @click="toggleItemsLength"
    >
      {{ buttonText }}
    </gl-button>
  </div>
</template>
