<script>
import { GlSkeletonLoader, GlIcon } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';

import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import accordionEventBus from './accordion_event_bus';

// The below is not a CSS util and can therefore safely be built dynamically.
// eslint-disable-next-line @gitlab/tailwind-no-interpolation
const accordionItemUniqueId = (name) => uniqueId(`gl-accordion-item-${name}-`);

export default {
  components: {
    GlSkeletonLoader,
    GlIcon,
  },
  mixins: [glSlotsMixin],
  props: {
    accordionId: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    maxHeight: {
      type: String,
      required: false,
      default: '',
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input'],
  data() {
    return {
      isExpanded: false,
    };
  },
  computed: {
    contentStyles() {
      return {
        maxHeight: this.maxHeight,
        overflow: 'auto',
      };
    },
    isDisabled() {
      return this.disabled || !this.hasContent;
    },
    hasContent() {
      return this.glSlots().default !== undefined;
    },
  },
  created() {
    this.buttonId = accordionItemUniqueId('trigger');
    this.contentContainerId = accordionItemUniqueId('content-container');
    // create a unique event name so multiple accordion instances don't close each other items
    this.closeOtherItemsEvent = `${this.accordionId}.closeOtherAccordionItems`;

    accordionEventBus.$on(this.closeOtherItemsEvent, this.onCloseOtherAccordionItems);
  },
  destroyed() {
    // eslint-disable-next-line @gitlab/no-global-event-off
    accordionEventBus.$off(this.closeOtherItemsEvent);
  },
  methods: {
    onCloseOtherAccordionItems(trigger) {
      if (trigger !== this) {
        this.collapse();
      }
    },
    handleClick() {
      if (this.isExpanded) {
        this.collapse();
      } else {
        this.expand();
      }
      this.$emit('input');
      accordionEventBus.$emit(this.closeOtherItemsEvent, this);
    },
    expand() {
      this.isExpanded = true;
    },
    collapse() {
      this.isExpanded = false;
    },
  },
};
</script>

<template>
  <li class="list-group-item gl-p-0">
    <template v-if="!isLoading">
      <div class="gl-flex gl-items-stretch">
        <button
          :id="buttonId"
          data-testid="expansion-trigger"
          type="button"
          :disabled="isDisabled"
          :aria-expanded="isExpanded"
          :aria-controls="contentContainerId"
          class="gl-w-full gl-rounded-none gl-border-0 gl-bg-transparent gl-p-0 gl-text-left"
          :class="{ 'cursor-default': isDisabled, 'list-group-item-action': !isDisabled }"
          @click="handleClick"
        >
          <div class="gl-flex gl-items-center gl-p-3">
            <gl-icon
              :size="16"
              class="gl-mr-3"
              :name="isExpanded ? 'chevron-lg-down' : 'chevron-lg-right'"
              variant="default"
            />
            <span
              ><slot name="title" :is-expanded="isExpanded" :is-disabled="isDisabled"></slot
            ></span>
          </div>
        </button>
      </div>
      <section
        v-show="isExpanded"
        :id="contentContainerId"
        data-testid="content-container"
        :aria-labelledby="buttonId"
      >
        <slot name="sub-title"></slot>
        <div data-testid="content" :style="contentStyles"><slot name="default"></slot></div>
      </section>
    </template>
    <div v-else data-testid="loading-indicator" class="gl-flex gl-p-3">
      <div class="h-32-px">
        <gl-skeleton-loader :height="32">
          <rect width="12" height="16" rx="4" x="0" y="8" />
          <circle cx="37" cy="15" r="15" />
          <rect width="20" height="16" rx="4" x="63" y="8" />
        </gl-skeleton-loader>
      </div>
    </div>
  </li>
</template>
