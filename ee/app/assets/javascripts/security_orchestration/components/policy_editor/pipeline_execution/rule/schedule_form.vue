<script>
import {
  GlCollapsibleListbox,
  GlFormInput,
  GlIcon,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { sortBy } from 'lodash-es';
import { n__, s__, __, sprintf } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import DurationSelector from 'ee/security_orchestration/components/policy_editor/shared/duration_selector/duration_selector.vue';
import TimezoneDropdown from '~/vue_shared/components/timezone_dropdown/timezone_dropdown.vue';
import { getHostname, isCauseOfError, slugifyToArray } from '../../utils';
import {
  CADENCE_OPTIONS,
  DEFAULT_TIMEZONE,
  HOUR_MINUTE_LIST,
  MAX_SCHEDULE_BRANCHES,
  WEEKDAY_OPTIONS,
} from './constants';
import {
  isCadenceWeekly,
  isCadenceMonthly,
  isValidCadence,
  updateScheduleCadence,
  getMonthlyDayOptions,
} from './utils';
import SnoozeForm from './snooze_form.vue';

export default {
  name: 'ScheduleForm',
  CADENCE_OPTIONS,
  HOUR_MINUTE_LIST,
  MAX_SCHEDULE_BRANCHES,
  WEEKDAY_OPTIONS,
  i18n: {
    branchesInfoText: s__(
      'SecurityOrchestration|Enter up to %{maxBranches} branch names, separated by commas.',
    ),
    branchesLabel: s__('SecurityOrchestration|branches input'),
    branchesPlaceholder: s__('SecurityOrchestration|e.g. main, develop, release'),
    cadence: __('Cadence'),
    cadenceDetail: s__('SecurityOrchestration|on every'),
    cadencePlaceholder: s__('SecurityOrchestration|Select a cadence'),
    details: s__(
      'SecurityOrchestration|at the following times: %{cadenceSelector}, start at %{start}, run for: %{duration}, and timezone is %{timezoneSelector}',
    ),
    headerText: s__('SecurityOrchestration|Select days'),
    message: s__('SecurityOrchestration|Schedule to run for %{branchSelector}'),
    monthly: __('Monthly'),
    monthlyDaysLabel: s__('SecurityOrchestration|Days of month'),
    monthlyDaysPlaceholder: s__('SecurityOrchestration|Select days'),
    resetLabel: __('Clear all'),
    time: __('Time'),
    timezoneLabel: s__('ScanExecutionPolicy|on %{hostname}'),
    timezonePlaceholder: s__('ScanExecutionPolicy|Select timezone'),
    weekly: __('Weekly'),
    weekdayDropdownPlaceholder: __('Select a day'),
  },
  directives: { GlTooltip: GlTooltipDirective },
  components: {
    DurationSelector,
    GlCollapsibleListbox,
    GlFormInput,
    GlIcon,
    GlSprintf,
    TimezoneDropdown,
    SnoozeForm,
  },
  inject: ['timezones'],
  props: {
    errorSources: {
      type: Array,
      required: false,
      default: () => [],
    },
    schedule: {
      type: Object,
      required: true,
    },
  },
  emits: ['changed'],
  computed: {
    hasTimeWindowError() {
      return isCauseOfError({
        errorSources: this.errorSources,
        primaryKey: 'schedules',
        index: 0,
        location: 'time_window',
      });
    },
    branchesInfoText() {
      return sprintf(this.$options.i18n.branchesInfoText, {
        maxBranches: MAX_SCHEDULE_BRANCHES,
      });
    },
    enteredBranches: {
      get() {
        return this.schedule.branches?.join(', ') || '';
      },
      set(value) {
        const branches = [
          ...new Set(slugifyToArray(value).filter((branch) => branch !== '*')),
        ].slice(0, MAX_SCHEDULE_BRANCHES);
        this.updatePolicy('branches', branches);
      },
    },
    cadence() {
      return this.schedule?.type;
    },
    cadenceToggleText() {
      return isValidCadence(this.cadence) ? this.cadence : this.$options.i18n.cadencePlaceholder;
    },
    monthlyDaysMessage() {
      return n__('day of the month', 'days of the month', this.selectedMonthlyDays.length);
    },
    monthlyDayOptions() {
      return getMonthlyDayOptions();
    },
    monthlyDaysToggleText() {
      return getSelectedOptionsText({
        options: this.monthlyDayOptions,
        selected: this.selectedMonthlyDays,
        placeholder: this.$options.i18n.monthlyDaysPlaceholder,
        maxOptionsShown: 2,
      });
    },
    selectedMonthlyDays() {
      return this.schedule.days_of_month || [];
    },
    showMonthlyDropdown() {
      return isCadenceMonthly(this.cadence);
    },
    showWeekdayDropdown() {
      return isCadenceWeekly(this.cadence);
    },
    timezone() {
      return this.schedule.timezone || DEFAULT_TIMEZONE;
    },
    timezoneTooltipText() {
      return sprintf(this.$options.i18n.timezoneLabel, { hostname: getHostname() });
    },
    weekdayToggleText() {
      return getSelectedOptionsText({
        options: this.$options.WEEKDAY_OPTIONS,
        selected: this.schedule.days || [],
        placeholder: this.$options.i18n.weekdayDropdownPlaceholder,
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    handleMonthlyDaysInput(selectedDays) {
      this.updatePolicy('days_of_month', sortBy(selectedDays));
    },
    handleSnoozeUpdate(snoozeData) {
      this.updatePolicy('snooze', snoozeData);
    },
    handleWeeklyDaysInput(selectedDays) {
      this.updatePolicy('days', selectedDays);
    },
    updateCadence(value) {
      const updatedSchedule = updateScheduleCadence({ schedule: this.schedule, cadence: value });
      this.$emit('changed', updatedSchedule);
    },
    updatePolicy(key, value) {
      this.$emit('changed', { ...this.schedule, [key]: value });
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-mb-3 gl-flex gl-flex-wrap gl-items-center gl-gap-3">
      <gl-sprintf :message="$options.i18n.message">
        <template #branchSelector>
          <span class="gl-inline-flex gl-items-center gl-gap-2">
            <label for="schedule-branches-input" class="gl-sr-only">
              {{ $options.i18n.branchesLabel }}
            </label>
            <gl-form-input
              id="schedule-branches-input"
              v-model="enteredBranches"
              class="gl-inline gl-w-30"
              data-testid="branches-input"
              :placeholder="$options.i18n.branchesPlaceholder"
              type="text"
            />
            <gl-icon v-gl-tooltip name="information-o" class="gl-ml-3" :title="branchesInfoText" />
          </span>
        </template>
      </gl-sprintf>
    </div>
    <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-3">
      <gl-sprintf :message="$options.i18n.details">
        <template #cadenceSelector>
          <gl-collapsible-listbox
            :aria-label="$options.i18n.cadence"
            :items="$options.CADENCE_OPTIONS"
            :selected="cadence"
            :toggle-text="cadenceToggleText"
            @select="updateCadence"
          />

          <template v-if="showWeekdayDropdown">
            {{ $options.i18n.cadenceDetail }}
            <gl-collapsible-listbox
              multiple
              data-testid="weekday-dropdown"
              :aria-label="$options.i18n.weekly"
              :header-text="$options.i18n.headerText"
              :items="$options.WEEKDAY_OPTIONS"
              :reset-button-label="$options.i18n.resetLabel"
              :selected="schedule.days"
              :toggle-text="weekdayToggleText"
              @reset="handleWeeklyDaysInput([])"
              @select="handleWeeklyDaysInput"
            />
          </template>

          <template v-else-if="showMonthlyDropdown">
            {{ $options.i18n.cadenceDetail }}
            <div class="gl-flex gl-items-center">
              <gl-collapsible-listbox
                class="gl-mr-3"
                multiple
                data-testid="monthly-days-dropdown"
                :aria-label="$options.i18n.monthlyDaysLabel"
                :header-text="$options.i18n.headerText"
                :items="monthlyDayOptions"
                :reset-button-label="$options.i18n.resetLabel"
                :selected="selectedMonthlyDays"
                :toggle-text="monthlyDaysToggleText"
                @reset="handleMonthlyDaysInput([])"
                @select="handleMonthlyDaysInput"
              />
              {{ monthlyDaysMessage }}
            </div>
          </template>
        </template>

        <template #start>
          <gl-collapsible-listbox
            data-testid="time-dropdown"
            :aria-label="$options.i18n.time"
            :items="$options.HOUR_MINUTE_LIST"
            :selected="schedule.start_time"
            @select="updatePolicy('start_time', $event)"
          />
        </template>

        <template #duration>
          <duration-selector
            time-window-required
            :has-error="hasTimeWindowError"
            :time-window="schedule.time_window"
            @changed="updatePolicy('time_window', $event)"
          />
        </template>

        <template #timezoneSelector>
          <timezone-dropdown
            :aria-label="$options.i18n.timezonePlaceholder"
            class="gl-max-w-26"
            :header-text="$options.i18n.timezonePlaceholder"
            :timezone-data="timezones"
            :title="timezoneTooltipText"
            :value="timezone"
            @input="updatePolicy('timezone', $event.identifier)"
          />
        </template>
      </gl-sprintf>
    </div>
    <snooze-form :data="schedule.snooze" @update="handleSnoozeUpdate" />
  </div>
</template>
