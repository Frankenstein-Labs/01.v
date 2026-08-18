<script>
import { GlBadge, GlIcon, GlDisclosureDropdown, GlTruncate } from '@gitlab/ui';
import { SAST_FINDING_DISMISSED } from '~/diffs/constants';
import { firstSentenceOfText } from './inline_findings_dropdown_utils';

export default {
  name: 'InlineFindingsDropdown',
  components: {
    GlIcon,
    GlBadge,
    GlDisclosureDropdown,
    GlTruncate,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    startOpened: {
      type: Boolean,
      required: false,
      default: false,
    },
    compact: {
      type: Boolean,
      required: false,
      default: false,
    },
    iconId: {
      type: String,
      required: false,
      default: '',
    },
    iconKey: {
      type: String,
      required: false,
      default: '',
    },
    iconName: {
      type: String,
      required: false,
      default: '',
    },
    iconClass: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['mouseenter', 'mouseleave'],
  computed: {
    toggleIconSize() {
      return this.compact ? 14 : 16;
    },
    dropdownOffset() {
      return { mainAxis: 8, alignmentAxis: -8 };
    },
    toggleButtonClass() {
      return [
        'gl-cursor-pointer gl-border-0 gl-bg-transparent gl-p-0',
        this.compact ? 'gl-flex' : 'gl-inline-flex gl-relative gl-top-1 !gl-align-baseline',
      ];
    },
  },
  mounted() {
    if (this.startOpened) {
      this.$refs.toggleButton?.focus();
    }
  },
  methods: {
    firstSentence(text) {
      return firstSentenceOfText(text);
    },
    emitMouseEnter() {
      this.$emit('mouseenter');
    },
    emitMouseLeave() {
      this.$emit('mouseleave');
    },
    findingsStatus(item) {
      return item.state === SAST_FINDING_DISMISSED;
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    :items="items"
    :start-opened="startOpened"
    :dropdown-offset="dropdownOffset"
    :fluid-width="true"
    positioning-strategy="absolute"
    class="findings-dropdown gl-whitespace-normal !gl-text-default"
  >
    <template #group-label="{ group }">
      {{ group.name }}
    </template>

    <template #list-item="{ item }">
      <span class="gl-flex gl-items-center gl-text-subtle">
        <gl-icon
          :size="12"
          :name="item.name"
          :class="item.class"
          class="inline-findings-severity-icon gl-mr-4"
        />
        <span class="findings-dropdown-width gl-flex gl-truncate !gl-whitespace-nowrap"
          ><span class="gl-self-center gl-font-bold gl-capitalize gl-text-default"
            >{{ item.severity }}: </span
          ><gl-truncate
            class="findings-dropdown-truncate gl-self-center"
            :text="firstSentence(item.text)"
          />
          <gl-badge v-if="findingsStatus(item)" variant="neutral" class="gl-ml-3 gl-capitalize">{{
            item.state
          }}</gl-badge>
        </span>
      </span>
    </template>
    <template #toggle="{ accessibilityAttributes }">
      <button
        ref="toggleButton"
        type="button"
        :class="toggleButtonClass"
        v-bind="accessibilityAttributes"
      >
        <gl-icon
          :id="iconId"
          :key="iconKey"
          :name="iconName"
          :size="toggleIconSize"
          :class="iconClass"
          class="inline-findings-severity-icon"
          data-testid="toggle-icon"
          @mouseenter="emitMouseEnter"
          @mouseleave="emitMouseLeave"
        />
      </button>
    </template>
  </gl-disclosure-dropdown>
</template>
