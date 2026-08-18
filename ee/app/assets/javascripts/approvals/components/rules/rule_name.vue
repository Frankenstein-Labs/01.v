<script>
import { uniqueId } from 'lodash-es';
import { GlLink, GlPopover } from '@gitlab/ui';
import { COVERAGE_CHECK_NAME, APPROVAL_RULE_CONFIGS } from 'ee/approvals/constants';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

export default {
  name: 'RuleName',
  components: {
    GlLink,
    GlPopover,
    HelpIcon,
  },
  inject: {
    coverageCheckHelpPagePath: {
      default: '',
    },
  },
  props: {
    name: {
      type: String,
      required: true,
    },
  },
  computed: {
    rulesWithTooltips() {
      return {
        [COVERAGE_CHECK_NAME]: {
          description: APPROVAL_RULE_CONFIGS[COVERAGE_CHECK_NAME].popoverText,
          linkPath: this.coverageCheckHelpPagePath,
        },
      };
    },
    description() {
      return this.rulesWithTooltips[this.name]?.description;
    },
    linkPath() {
      return this.rulesWithTooltips[this.name]?.linkPath;
    },
    popoverContainerId() {
      return uniqueId('approval-rule-name-popover-');
    },
  },
  methods: {
    popoverTarget() {
      return this.$refs.helpIcon?.$el;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center">
    <span class="-gl-mt-1">{{ name }}</span>
    <span v-if="description" :id="popoverContainerId" class="gl-ml-3">
      <help-icon ref="helpIcon" :aria-label="__('Help')" class="author-link" />
      <gl-popover :target="popoverTarget" :container="popoverContainerId" placement="top">
        <template #title>{{ __('Who can approve?') }}</template>
        <p>{{ description }}</p>
        <gl-link v-if="linkPath" :href="linkPath" class="gl-text-sm" target="_blank">{{
          __('More information')
        }}</gl-link>
      </gl-popover>
    </span>
  </div>
</template>
