<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import SkipCiConfiguration from 'ee/security_orchestration/components/policy_drawer/skip_ci_configuration.vue';
import {
  DEFAULT_SKIP_SI_CONFIGURATION,
  SCAN_EXECUTION_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import ToggleList from 'ee/security_orchestration/components/scope/toggle_list.vue';
import { ACTIONS } from '../../policy_editor/constants';
import { CONFIGURATION_TITLE, SUMMARY_TITLE } from '../constants';
import InfoRow from '../info_row.vue';
import DrawerLayout from '../drawer_layout.vue';
import Tags from './humanized_actions/tags.vue';
import Variables from './humanized_actions/variables.vue';
import { humanizeActions, humanizeRules } from './utils';

export default {
  name: 'ScanExecutionDetailsDrawer',
  i18n: {
    noActionMessage: s__('SecurityOrchestration|No actions defined - policy will not run.'),
    scanExecution: s__('SecurityOrchestration|Scan execution'),
    summary: SUMMARY_TITLE,
    ruleMessage: s__('SecurityOrchestration|And scans to be performed:'),
    configuration: CONFIGURATION_TITLE,
  },
  HUMANIZED_ACTION_COMPONENTS: {
    [ACTIONS.tags]: Tags,
    [ACTIONS.variables]: Variables,
  },
  components: {
    SkipCiConfiguration,
    ToggleList,
    Tags,
    Variables,
    GlSprintf,
    DrawerLayout,
    InfoRow,
  },
  props: {
    policy: {
      type: Object,
      required: true,
    },
  },
  computed: {
    actions() {
      return this.parsedYaml?.actions || [];
    },
    rules() {
      return this.parsedYaml?.rules || [];
    },
    description() {
      return this.parsedYaml?.description || '';
    },
    policyScope() {
      return this.policy?.policyScope;
    },
    humanizedActions() {
      return humanizeActions(this.actions);
    },
    humanizedRules() {
      return humanizeRules(this.rules);
    },
    parsedYaml() {
      return fromYaml({
        manifest: this.policy.yaml,
        type: SCAN_EXECUTION_POLICY_TYPE,
      });
    },
    configuration() {
      return this.parsedYaml.skip_ci || DEFAULT_SKIP_SI_CONFIGURATION;
    },
  },
  methods: {
    humanizedActionComponent({ action }) {
      return this.$options.HUMANIZED_ACTION_COMPONENTS[action];
    },
    showBranchExceptions(exceptions) {
      return exceptions?.length > 0;
    },
  },
};
</script>

<template>
  <drawer-layout
    key="scan_execution_policy"
    :description="description"
    :policy="policy"
    :policy-scope="policyScope"
    :type="$options.i18n.scanExecution"
  >
    <template v-if="parsedYaml" #summary>
      <info-row :label="$options.i18n.summary">
        <section data-testid="actions">
          <template v-if="!humanizedActions.length">{{ $options.i18n.noActionMessage }}</template>
          <div v-for="{ message, criteriaList } in humanizedActions" :key="message" class="gl-mb-3">
            <gl-sprintf :message="message">
              <template #scanner="{ content }">
                <strong>{{ content }}</strong>
              </template>
            </gl-sprintf>
            <ul>
              <li v-for="criteria in criteriaList" :key="criteria.message" class="gl-mt-3">
                {{ criteria.message }}
                <component :is="humanizedActionComponent(criteria)" :criteria="criteria" />
              </li>
            </ul>
          </div>
        </section>
        <section data-testid="rules">
          <div class="gl-mb-3">{{ $options.i18n.ruleMessage }}</div>
          <ul>
            <li v-for="(rule, idx) in humanizedRules" :key="idx">
              {{ rule.summary }}
              <toggle-list
                v-if="showBranchExceptions(rule.branchExceptions)"
                class="gl-my-2"
                :items="rule.branchExceptions"
              />
            </li>
          </ul>
        </section>
      </info-row>
      <info-row data-testid="policy-configuration" :label="$options.i18n.configuration">
        <skip-ci-configuration :configuration="configuration" />
      </info-row>
    </template>
  </drawer-layout>
</template>
