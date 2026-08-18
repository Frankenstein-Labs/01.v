<script>
import { GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { projectPath } from '~/lib/utils/path_helpers/project';
import { humanizeActions } from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/utils';
import {
  generateScheduleSummary,
  getSnoozeInfo,
} from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/schedule_utils';
import {
  SUMMARY_TITLE,
  CONFIGURATION_TITLE,
} from 'ee/security_orchestration/components/policy_drawer/constants';
import { PIPELINE_EXECUTION_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import DrawerLayout from '../drawer_layout.vue';
import InfoRow from '../info_row.vue';
import SkipCiConfiguration from '../skip_ci_configuration.vue';
import VariablesOverrideConfiguration from './variables_override_configuration.vue';

export default {
  i18n: {
    noActionMessage: s__('SecurityOrchestration|No actions defined - policy will not run.'),
    pipelineExecutionActionsHeader: s__(
      'SecurityOrchestration|Enforce the following pipeline execution policy:',
    ),
    summary: SUMMARY_TITLE,
    configuration: CONFIGURATION_TITLE,
    variablesOverride: s__('SecurityOrchestration|Variable precedence'),
  },
  name: 'PipelineExecutionDrawer',
  components: {
    InfoRow,
    DrawerLayout,
    GlLink,
    SkipCiConfiguration,
    VariablesOverrideConfiguration,
  },
  props: {
    policy: {
      type: Object,
      required: true,
    },
  },
  computed: {
    hasVariablesControl() {
      return this.variablesOverride;
    },
    variablesOverride() {
      return this.parsedYaml?.variables_override;
    },
    hasSchedules() {
      return this.schedules.length > 0;
    },
    humanizedActions() {
      return humanizeActions([this.parsedYaml]);
    },
    policyScope() {
      return this.policy?.policyScope;
    },
    parsedYaml() {
      return fromYaml({
        manifest: this.policy.yaml,
        type: PIPELINE_EXECUTION_POLICY_TYPE,
      });
    },
    configuration() {
      return this.parsedYaml.skip_ci;
    },
    policyType() {
      return this.policy?.policyType || '';
    },
    schedules() {
      return this.parsedYaml?.schedules || [];
    },
  },
  methods: {
    getComponent(prop) {
      return ['file', 'project'].includes(prop) ? GlLink : 'p';
    },
    getHref({ project }, type) {
      switch (type) {
        case 'file':
          return this.policy.policyBlobFilePath;
        case 'project':
          return projectPath(project.content);
        default:
          return '';
      }
    },
    generateScheduleSummary(schedule) {
      return generateScheduleSummary(schedule);
    },
    getSnoozeInfo(schedule) {
      return getSnoozeInfo(schedule);
    },
  },
};
</script>

<template>
  <drawer-layout
    key="pipeline_execution_policy"
    :description="parsedYaml.description"
    :policy="policy"
    :policy-scope="policyScope"
    :type="policyType"
  >
    <template v-if="parsedYaml" #summary>
      <info-row data-testid="policy-summary" :label="$options.i18n.summary">
        <template v-if="!humanizedActions.length">{{ $options.i18n.noActionMessage }}</template>
        <div v-else>
          <div v-if="hasSchedules" data-testid="schedule-summary">
            <div v-for="(schedule, index) in schedules" :key="index">
              <p>{{ generateScheduleSummary(schedule) }}</p>
              <p v-if="schedule.snooze" data-testid="snooze-summary">
                {{ getSnoozeInfo(schedule) }}
              </p>
            </div>
          </div>
          <p data-testid="summary-header">{{ $options.i18n.pipelineExecutionActionsHeader }}</p>

          <ul
            v-for="action in humanizedActions"
            :key="action.project.value"
            class="gl-list-none gl-pl-0"
            data-testid="summary-fields"
          >
            <li
              v-for="{ type, label, content } in action"
              :key="content"
              class="gl-mb-2"
              :data-testid="type"
            >
              <span>
                {{ label }}
              </span>
              <span>:</span>
              <component :is="getComponent(type)" :href="getHref(action, type)" class="gl-inline">
                {{ content }}
              </component>
            </li>
          </ul>
        </div>
      </info-row>
      <info-row data-testid="policy-configuration" :label="$options.i18n.configuration">
        <skip-ci-configuration :configuration="configuration" />
      </info-row>
      <info-row
        v-if="hasVariablesControl"
        data-testid="policy-variables-override"
        :label="$options.i18n.variablesOverride"
      >
        <variables-override-configuration :variables-override="variablesOverride" />
      </info-row>
    </template>
  </drawer-layout>
</template>
