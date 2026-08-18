<script>
import { GlButton, GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isFinished } from '~/deployments/utils';

export default {
  name: 'EnvironmentApproval',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip,
  },
  props: {
    deploymentWebPath: {
      type: String,
      required: true,
    },
    requiredApprovalCount: {
      type: Number,
      required: true,
    },
    showText: {
      type: Boolean,
      required: false,
      default: true,
    },
    size: {
      type: String,
      required: false,
      default: 'medium',
      validator: (value) => ['small', 'medium'].includes(value),
    },
    status: {
      type: String,
      required: true,
    },
  },
  computed: {
    buttonTitle() {
      return this.showText ? '' : this.$options.i18n.button;
    },
    needsApproval() {
      const deploymentStatus = this.status.toUpperCase();
      return !isFinished({ status: deploymentStatus }) && this.requiredApprovalCount > 0;
    },
  },
  i18n: {
    button: s__('DeploymentApproval|Approval options'),
  },
};
</script>
<template>
  <gl-button
    v-if="needsApproval"
    v-gl-tooltip
    :title="buttonTitle"
    :aria-label="buttonTitle"
    :href="deploymentWebPath"
    :size="size"
    icon="approval"
  >
    <template v-if="showText">
      {{ $options.i18n.button }}
    </template>
  </gl-button>
</template>
