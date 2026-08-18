<script>
import { GlLink, GlIcon, GlModalDirective } from '@gitlab/ui';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import RunnerPerformanceModal from './runner_performance_modal.vue';

export default {
  name: 'RunnerPerformanceStat',
  components: {
    GlLink,
    GlIcon,
    RunnerPerformanceModal,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  mixins: [glLicensedFeaturesMixin()],
  computed: {
    shouldShowPerformanceStat() {
      return this.glLicensedFeatures?.runnerPerformanceInsights;
    },
  },
  MODAL_ID: 'runner-performance-modal',
};
</script>
<template>
  <div v-if="shouldShowPerformanceStat" class="gl-p-2 gl-leading-normal">
    <div class="gl-mb-4">
      <span class="gl-text-subtle">{{ s__('Runners|Runners performance') }}</span>
    </div>
    <div>
      <gl-link v-gl-modal="$options.MODAL_ID" class="!gl-text-default">
        {{ s__('Runners|View metrics') }} <gl-icon name="chart" />
      </gl-link>
      <runner-performance-modal :modal-id="$options.MODAL_ID" />
    </div>
  </div>
</template>
