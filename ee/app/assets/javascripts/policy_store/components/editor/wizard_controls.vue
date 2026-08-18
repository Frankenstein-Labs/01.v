<script>
import { GlButton, GlCollapsibleListbox, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  STATUS_COMPLETE,
  STATUS_CURRENT,
  STATUS_UPCOMING,
  ARIA_CURRENT_STEP,
  ENFORCEMENT_AUDIT,
  ENFORCEMENT_ENFORCE,
  ENFORCEMENT_MODES,
  ENFORCEMENT_WARN,
} from './constants';

const MODE_PILL_CLASSES = {
  [ENFORCEMENT_ENFORCE]: '!gl-bg-feedback-danger !gl-text-danger',
  [ENFORCEMENT_WARN]: '!gl-bg-feedback-warning !gl-text-warning',
  [ENFORCEMENT_AUDIT]: '!gl-bg-feedback-neutral !gl-text-strong',
};

const MODE_ICON_CLASSES = {
  [ENFORCEMENT_ENFORCE]: 'gl-text-danger',
  [ENFORCEMENT_WARN]: 'gl-text-warning',
  [ENFORCEMENT_AUDIT]: 'gl-text-subtle',
};

export default {
  name: 'WizardControls',
  components: { GlButton, GlCollapsibleListbox, GlIcon },
  STATUS_COMPLETE,
  STATUS_CURRENT,
  ARIA_CURRENT_STEP,
  ENFORCEMENT_MODES,
  i18n: {
    stepsLabel: s__('PolicyStore|Policy creation steps'),
    modeHeader: s__('PolicyStore|Enforcement mode'),
  },
  props: {
    steps: {
      type: Array,
      required: true,
    },
    mode: {
      type: String,
      required: true,
    },
  },
  emits: ['select-mode'],
  computed: {
    selectedMode() {
      return ENFORCEMENT_MODES.find(({ value }) => value === this.mode) || ENFORCEMENT_MODES[0];
    },
    toggleClass() {
      return `${MODE_PILL_CLASSES[this.selectedMode.value]} !gl-border-0 !gl-px-4 !gl-py-3 !gl-shadow-none`;
    },
  },
  methods: {
    iconClass({ value }) {
      return MODE_ICON_CLASSES[value];
    },
    markerClass(status) {
      return status === STATUS_UPCOMING
        ? 'gl-bg-strong gl-text-subtle'
        : 'gl-bg-neutral-900 gl-text-neutral-0';
    },
    labelClass(status) {
      return status === STATUS_CURRENT ? 'gl-text-strong gl-font-bold' : 'gl-text-subtle';
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-justify-between gl-gap-4 md:gl-pl-8 md:gl-pr-11">
    <div class="gl-flex gl-min-w-0 gl-flex-1 gl-items-center">
      <ol
        class="gl-m-0 gl-flex gl-flex-wrap gl-gap-x-3 gl-gap-y-2 gl-p-0"
        :aria-label="$options.i18n.stepsLabel"
        data-testid="wizard-steps"
      >
        <li
          v-for="step in steps"
          :key="step.id"
          class="gl-flex gl-items-center gl-gap-3"
          :aria-current="
            step.status === $options.STATUS_CURRENT ? $options.ARIA_CURRENT_STEP : null
          "
        >
          <span
            class="gl-flex gl-h-6 gl-w-6 gl-items-center gl-justify-center gl-rounded-full gl-text-sm"
            :class="markerClass(step.status)"
          >
            <gl-icon v-if="step.status === $options.STATUS_COMPLETE" name="check" :size="12" />
            <span v-else>{{ step.number }}</span>
          </span>
          <span class="gl-text-sm" :class="labelClass(step.status)">{{ step.label }}</span>
          <span
            v-if="!step.isLast"
            class="gl-hidden gl-h-px gl-w-8 gl-bg-strong md:gl-block"
            aria-hidden="true"
          ></span>
        </li>
      </ol>
    </div>

    <div class="gl-flex gl-w-31 gl-flex-shrink-0 gl-justify-end" data-testid="mode-reservation">
      <gl-collapsible-listbox
        :items="$options.ENFORCEMENT_MODES"
        :selected="mode"
        :header-text="$options.i18n.modeHeader"
        placement="bottom-end"
        data-testid="mode-selector"
        @select="$emit('select-mode', $event)"
      >
        <template #toggle="{ accessibilityAttributes }">
          <gl-button
            v-bind="accessibilityAttributes"
            :class="toggleClass"
            button-text-classes="gl-flex gl-items-center gl-gap-2 gl-text-sm"
            data-testid="mode-toggle"
          >
            <gl-icon :name="selectedMode.icon" :size="12" />
            {{ selectedMode.text }}
            <gl-icon name="chevron-down" :size="12" />
          </gl-button>
        </template>
        <template #list-item="{ item }">
          <span class="gl-flex gl-gap-3">
            <gl-icon
              :name="item.icon"
              :size="14"
              class="gl-mt-1 gl-flex-shrink-0"
              :class="iconClass(item)"
            />
            <span class="gl-flex gl-flex-col">
              <span class="gl-font-bold">{{ item.text }}</span>
              <span class="gl-text-sm gl-text-subtle">{{ item.description }}</span>
            </span>
          </span>
        </template>
      </gl-collapsible-listbox>
    </div>
  </div>
</template>
