<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { DEFAULT_SCHEDULE, INJECT, SCHEDULE } from '../constants';
import ScheduleForm from './schedule_form.vue';

export default {
  name: 'PipelineExecutionRuleSection',
  i18n: {
    conditionText: s__(
      'SecurityOrchestration|Configure your conditions in the pipeline execution file. %{linkStart}What can pipeline execution do?%{linkEnd}',
    ),
    helpPageLink: helpPagePath('user/application_security/policies/pipeline_execution_policies'),
  },
  components: {
    GlLink,
    GlSprintf,
    ScheduleForm,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    errorSources: {
      type: Array,
      required: false,
      default: () => [],
    },
    schedules: {
      type: Array,
      required: false,
      default: () => [DEFAULT_SCHEDULE],
    },
    strategy: {
      type: String,
      required: false,
      default: INJECT,
    },
  },
  emits: ['changed'],
  computed: {
    schedule() {
      return this.schedules[0];
    },
    showTriggeredMessage() {
      return !this.glFeatures.scheduledPipelineExecutionPolicies || this.strategy !== SCHEDULE;
    },
  },
  methods: {
    handleUpdateSchedules(schedule) {
      this.$emit('changed', schedule);
    },
  },
};
</script>

<template>
  <div
    class="security-policies-bg-subtle gl-flex gl-flex-col gl-gap-3 gl-rounded-base gl-p-5 @lg/panel:gl-flex-row"
  >
    <gl-sprintf v-if="showTriggeredMessage" :message="$options.i18n.conditionText">
      <template #link="{ content }">
        <gl-link :href="$options.i18n.helpPageLink" target="_blank">{{ content }}</gl-link>
      </template>
    </gl-sprintf>
    <schedule-form
      v-else
      :error-sources="errorSources"
      :schedule="schedule"
      @changed="handleUpdateSchedules"
    />
  </div>
</template>
