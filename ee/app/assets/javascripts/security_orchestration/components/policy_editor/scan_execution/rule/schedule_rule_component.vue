<script>
import {
  GlFormInput,
  GlSprintf,
  GlCollapsibleListbox,
  GlAlert,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import TimezoneDropdown from '~/vue_shared/components/timezone_dropdown/timezone_dropdown.vue';
import DurationSelector from 'ee/security_orchestration/components/policy_editor/shared/duration_selector/duration_selector.vue';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { getHostname, slugify, slugifyToArray } from '../../utils';
import {
  DAYS,
  HOUR_MINUTE_LIST,
  CRON_DEFAULT_TIME,
  CRON_DEFAULT_DAY,
  setCronTime,
  parseCronTime,
  isCronDaily,
} from '../lib';
import {
  AGENT_KEY,
  DEFAULT_AGENT_NAME,
  SCAN_EXECUTION_RULE_SCOPE_TYPE,
  SCAN_EXECUTION_RULE_SCOPE_BRANCH_KEY,
  SCAN_EXECUTION_RULE_SCOPE_AGENT_KEY,
  SCAN_EXECUTION_RULE_PERIOD_TYPE,
  SCAN_EXECUTION_RULES_SCHEDULE_KEY,
  SCAN_EXECUTION_RULE_PERIOD_DAILY_KEY,
  SCAN_EXECUTION_RULE_PERIOD_WEEKLY_KEY,
} from '../constants';
import { TIME_UNITS } from '../../shared/duration_selector/constants';
import BaseRuleComponent from './base_rule_component.vue';

export default {
  DAYS,
  HOUR_MINUTE_LIST,
  SCAN_EXECUTION_RULE_PERIOD_DAILY_KEY,
  SCAN_EXECUTION_RULE_PERIOD_TYPE,
  SCAN_EXECUTION_RULE_PERIOD_WEEKLY_KEY,
  SCAN_EXECUTION_RULE_SCOPE_TYPE,
  SCAN_EXECUTION_RULES_SCHEDULE_KEY,
  TIME_UNITS,
  i18n: {
    schedulePeriod: s__(
      'ScanExecutionPolicy|at the following times: %{period} %{days} around %{time} %{timezone}, run for: %{duration}, %{timezoneLabel}',
    ),
    selectedAgentsPlaceholder: s__('ScanExecutionPolicy|Select agent'),
    selectedNamespacesPlaceholder: s__('ScanExecutionPolicy|Select namespaces'),
    namespaceLabel: s__('ScanExecutionPolicy|in namespaces'),
    branchTimezoneHeader: s__('ScanExecutionPolicy|Select timezone'),
    kubernetesTimezoneHeader: s__("ScanExecutionPolicy|Kubernetes agent's timezone"),
    kubernetesTimezoneLabel: s__('ScanExecutionPolicy|on the Kubernetes agent pod'),
    branchTimezoneLabel: s__('ScanExecutionPolicy|on %{hostname}'),
    agentTimezoneTooltipText: s__("ScanExecutionPolicy|Kubernetes agent's timezone"),
    branchTimezoneTooltipText: s__("ScanExecutionPolicy|%{hostname}'s timezone"),
    timeWindowWarning: s__(
      'ScanExecutionPolicy|A time window is not set. Setting a time window helps distribute scheduled scans and reduces the load on runner infrastructure. We recommend a time window of at least 6 hours.',
    ),
  },
  name: 'ScheduleRuleComponent',
  components: {
    BaseRuleComponent,
    DurationSelector,
    GlFormInput,
    GlCollapsibleListbox,
    GlSprintf,
    GlAlert,
    TimezoneDropdown,
  },
  directives: {
    GlTooltip,
  },
  mixins: [glListenersMixin],
  inject: ['timezones'],
  props: {
    initRule: {
      type: Object,
      required: true,
    },
  },
  emits: ['changed'],
  data() {
    return {
      selectedTime: parseCronTime(this.initRule.cadence).time,
      selectedDay: parseCronTime(this.initRule.cadence).day,
      selectedDayIndex: parseCronTime(this.initRule.cadence).dayIndex,
      selectedTimeIndex: parseCronTime(this.initRule.cadence).timeIndex,
      cronString: this.initRule.cadence,
      agent: Object.keys(this.initRule.agents || {})[0] || DEFAULT_AGENT_NAME,
      selectedScope:
        AGENT_KEY in this.initRule
          ? SCAN_EXECUTION_RULE_SCOPE_AGENT_KEY
          : SCAN_EXECUTION_RULE_SCOPE_BRANCH_KEY,
      selectedPeriod: isCronDaily(this.initRule.cadence)
        ? SCAN_EXECUTION_RULE_PERIOD_DAILY_KEY
        : SCAN_EXECUTION_RULE_PERIOD_WEEKLY_KEY,
    };
  },
  computed: {
    hostname() {
      return getHostname();
    },
    isBranchScope() {
      return this.selectedScope === SCAN_EXECUTION_RULE_SCOPE_BRANCH_KEY;
    },
    isCronDaily() {
      return this.selectedPeriod === SCAN_EXECUTION_RULE_PERIOD_DAILY_KEY;
    },
    nameSpacesToAdd() {
      return (this.initRule.agents?.[this.agent]?.namespaces || []).join(',') || '';
    },
    timezone() {
      return this.initRule.timezone || '';
    },
    selectedScopeText() {
      return SCAN_EXECUTION_RULE_SCOPE_TYPE[this.selectedScope];
    },
    selectedPeriodText() {
      return SCAN_EXECUTION_RULE_PERIOD_TYPE[this.selectedPeriod];
    },
    timezoneHeader() {
      return this.isBranchScope
        ? this.$options.i18n.branchTimezoneHeader
        : this.$options.i18n.kubernetesTimezoneHeader;
    },
    timezoneLabel() {
      return this.isBranchScope
        ? sprintf(this.$options.i18n.branchTimezoneLabel, { hostname: this.hostname })
        : this.$options.i18n.kubernetesTimezoneLabel;
    },
    timezoneTooltipText() {
      return this.isBranchScope
        ? sprintf(this.$options.i18n.branchTimezoneTooltipText, { hostname: this.hostname })
        : this.$options.i18n.agentTimezoneTooltipText;
    },
    showTimeWindowWarning() {
      return !this.initRule.time_window?.value;
    },
  },
  methods: {
    convertToListboxItems(items) {
      return Object.entries(items).map(([value, text]) => ({ value, text }));
    },
    handleTimeWindowUpdate(timeWindow) {
      this.triggerChanged({ time_window: timeWindow });
    },
    handleTimeZoneInput({ identifier }) {
      this.triggerChanged({ timezone: identifier });
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.initRule, ...value });
    },
    triggerChangedScope(value) {
      this.$emit('changed', { type: this.initRule.type, ...value, cadence: this.initRule.cadence });
    },
    resetScope() {
      this.updateNamespaces('');
      this.agent = Object.keys(this.initRule.agents || {})[0] || DEFAULT_AGENT_NAME;
    },
    resetTime() {
      this.selectedTimeIndex = 0;
      this.selectedTime = HOUR_MINUTE_LIST[this.selectedTimeIndex];
      this.selectedDayIndex = 0;
      this.selectedDay = DAYS[this.selectedDayIndex];
    },
    setPeriodSelected(key) {
      this.selectedPeriod = key;
      this.cronString = this.isCronDaily ? CRON_DEFAULT_TIME : CRON_DEFAULT_DAY;
      this.resetTime();
      this.triggerChanged({ cadence: this.cronString });
    },
    setTimeSelected(key) {
      this.selectedTime = HOUR_MINUTE_LIST[key];
      this.selectedTimeIndex = key;
      this.setCronString({ time: key, day: this.selectedDayIndex });
    },
    setDaySelected(key) {
      this.selectedDay = DAYS[key];
      this.selectedDayIndex = key;
      this.setCronString({ time: this.selectedTimeIndex, day: key });
    },
    setCronString({ day, time }) {
      this.cronString = setCronTime({ time, day });
      this.triggerChanged({ cadence: this.cronString });
    },
    setScopeSelected(key) {
      this.selectedScope = key;
      this.resetScope();
      const payload = this.isBranchScope
        ? { branches: [] }
        : { agents: { [DEFAULT_AGENT_NAME]: { namespaces: [] } } };
      this.triggerChangedScope(payload);
    },
    slugifyNamespaces(values) {
      return slugifyToArray(values, ',');
    },
    updateAgent(values) {
      this.agent = slugify(values, '') || DEFAULT_AGENT_NAME;

      this.triggerChanged({
        agents: {
          [this.agent]: {
            namespaces: this.slugifyNamespaces(this.nameSpacesToAdd) || [],
          },
        },
      });
    },
    updateNamespaces(values) {
      this.triggerChanged({
        agents: {
          [this.agent]: {
            namespaces: this.slugifyNamespaces(values),
          },
        },
      });
    },
  },
};
</script>

<template>
  <div>
    <gl-alert v-if="showTimeWindowWarning" variant="warning" :dismissible="false" class="gl-mb-5">
      {{ $options.i18n.timeWindowWarning }}
    </gl-alert>
    <base-rule-component
      :default-selected-rule="$options.SCAN_EXECUTION_RULES_SCHEDULE_KEY"
      :init-rule="initRule"
      :is-branch-scope="isBranchScope"
      v-on="glListeners()"
    >
      <template #scopes>
        <gl-collapsible-listbox
          data-testid="rule-component-scope"
          :items="convertToListboxItems($options.SCAN_EXECUTION_RULE_SCOPE_TYPE)"
          :selected="selectedScope"
          :toggle-text="selectedScopeText"
          @select="setScopeSelected"
        />
      </template>

      <template #agents>
        <gl-form-input
          v-if="!isBranchScope"
          class="gl-max-w-34"
          :value="agent"
          :placeholder="$options.i18n.selectedAgentsPlaceholder"
          data-testid="pipeline-rule-agent"
          @update="updateAgent"
        />
      </template>

      <template #namespaces>
        <template v-if="!isBranchScope">
          <span>{{ $options.i18n.namespaceLabel }}</span>
        </template>

        <gl-form-input
          v-if="!isBranchScope"
          class="gl-max-w-34"
          :value="nameSpacesToAdd"
          :placeholder="$options.i18n.selectedNamespacesPlaceholder"
          data-testid="pipeline-rule-namespaces"
          @update="updateNamespaces"
        />
      </template>

      <template #period>
        <span class="gl-flex gl-flex-wrap gl-items-center gl-gap-3">
          <gl-sprintf :message="$options.i18n.schedulePeriod">
            <template #period>
              <gl-collapsible-listbox
                data-testid="rule-component-period"
                :items="convertToListboxItems($options.SCAN_EXECUTION_RULE_PERIOD_TYPE)"
                :toggle-text="selectedPeriodText"
                :selected="selectedPeriod"
                @select="setPeriodSelected"
              />
            </template>

            <template #days>
              <gl-collapsible-listbox
                v-if="!isCronDaily"
                data-testid="rule-component-day"
                :items="convertToListboxItems($options.DAYS)"
                :selected="selectedDayIndex"
                :toggle-text="selectedDay"
                @select="setDaySelected"
              />
            </template>

            <template #time>
              <gl-collapsible-listbox
                data-testid="rule-component-time"
                :items="convertToListboxItems($options.HOUR_MINUTE_LIST)"
                :toggle-text="selectedTime"
                :selected="selectedTimeIndex"
                @select="setTimeSelected"
              />
            </template>

            <template #timezoneLabel>
              <span data-testid="timezone-label">{{ timezoneLabel }}</span>
            </template>

            <template #timezone>
              <timezone-dropdown
                v-gl-tooltip.right.viewport
                class="gl-max-w-26"
                :header-text="timezoneHeader"
                :value="timezone"
                :timezone-data="timezones"
                :title="timezoneTooltipText"
                @input="handleTimeZoneInput"
              />
            </template>
            <template #duration>
              <duration-selector
                :minimum-seconds="$options.TIME_UNITS.HOUR"
                :time-window="initRule.time_window"
                @changed="handleTimeWindowUpdate"
              />
            </template>
          </gl-sprintf>
        </span>
      </template>
    </base-rule-component>
  </div>
</template>
