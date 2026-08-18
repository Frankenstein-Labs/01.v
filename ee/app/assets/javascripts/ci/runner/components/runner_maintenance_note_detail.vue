<script>
import SafeHtml from '~/vue_shared/directives/safe_html';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import RunnerDetail from '~/ci/runner/components/runner_detail.vue';

export default {
  name: 'RunnerMaintenanceNoteDetail',
  components: {
    RunnerDetail,
  },
  directives: {
    SafeHtml,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    runner: {
      type: Object,
      required: true,
    },
    value: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    canUpdateRunner() {
      // The maintenance note is only relevant to users that can edit the runner
      return this.runner.userPermissions?.updateRunner;
    },
    hasFeature() {
      const { runnerMaintenanceNote, runnerMaintenanceNoteForNamespace } = this.glFeatures;
      return runnerMaintenanceNote || runnerMaintenanceNoteForNamespace;
    },
    shouldRender() {
      return this.canUpdateRunner && this.hasFeature;
    },
  },
};
</script>

<template>
  <runner-detail v-if="shouldRender" :label="s__('Runners|Maintenance note')">
    <template v-if="value" #value>
      <div v-safe-html="value" class="md"></div>
    </template>
  </runner-detail>
</template>
