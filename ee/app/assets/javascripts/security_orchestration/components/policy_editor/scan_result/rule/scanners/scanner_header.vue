<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import { getCollapseIcon } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/utils';
import DefaultRuleBadge from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/default_rule_badge.vue';

export default {
  i18n: {
    ariaLabel: __('Remove'),
  },
  name: 'ScannerHeader',
  components: {
    GlButton,
    DefaultRuleBadge,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    visible: {
      type: Boolean,
      required: true,
    },
    showRemoveButton: {
      type: Boolean,
      required: false,
      default: false,
    },
    isDefaultConfiguration: {
      type: Boolean,
      required: false,
      default: false,
    },
    showDefaultRuleBadge: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['toggle', 'remove', 'reset'],
  computed: {
    collapseIcon() {
      return getCollapseIcon(this.visible);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-justify-between" :class="{ 'gl-mb-3': visible }">
    <div class="gl-flex gl-items-center gl-gap-3">
      <gl-button
        category="tertiary"
        :aria-label="collapseIcon"
        :icon="collapseIcon"
        @click="$emit('toggle')"
      />
      <h5 class="gl-m-0">{{ title }}</h5>

      <default-rule-badge
        v-if="showDefaultRuleBadge"
        :is-default-configuration="isDefaultConfiguration"
        @reset="$emit('reset')"
      />
    </div>
    <gl-button
      v-if="showRemoveButton"
      icon="remove"
      category="tertiary"
      :aria-label="$options.i18n.ariaLabel"
      data-testid="remove-scanner"
      @click="$emit('remove')"
    />
  </div>
</template>
