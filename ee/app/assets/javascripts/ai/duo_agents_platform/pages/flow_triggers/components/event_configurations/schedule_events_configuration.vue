<script>
import { GlCollapsibleListbox, GlFormGroup, GlFormInput } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { getWeekdayNames } from '~/lib/utils/datetime_utility';
import { s__ } from '~/locale';
import TimezoneDropdown from '~/vue_shared/components/timezone_dropdown/timezone_dropdown.vue';
import {
  FLOW_TRIGGER_TYPE_SCHEDULE,
  SCHEDULE_DAY_OF_MONTH_MAX,
  SCHEDULE_DEFAULT_TIMEZONE,
  SCHEDULE_FIELD_DAY_OF_MONTH,
  SCHEDULE_FIELD_DAY_OF_WEEK,
  SCHEDULE_FIELD_HOUR,
  SCHEDULE_FIELD_MINUTE,
  SCHEDULE_FIELD_TIMEZONE,
  SCHEDULE_FREQUENCIES,
  SCHEDULE_FREQUENCY_FIELDS,
  SCHEDULE_HOUR_MAX,
  SCHEDULE_HOUR_MIN,
  SCHEDULE_MINUTE_VALUES,
} from 'ee/ai/duo_agents_platform/constants';
import { parseScheduleConfig, randomizeScheduleDefaults } from 'ee/ai/duo_agents_platform/utils';

const SCHEDULE_SCOPE = FLOW_TRIGGER_TYPE_SCHEDULE.value;

export default {
  name: 'ScheduleEventsConfiguration',
  components: {
    GlCollapsibleListbox,
    GlFormGroup,
    GlFormInput,
    TimezoneDropdown,
  },
  inject: {
    timezoneData: {
      default: () => [],
    },
    userTimezone: {
      default: '',
    },
  },
  props: {
    value: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    invalidFeedback: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['input'],
  data() {
    return {
      minuteLabelId: uniqueId('schedule-minute-label-'),
    };
  },
  computed: {
    schedule() {
      return parseScheduleConfig(this.value) ?? {};
    },
    frequency() {
      return this.schedule.frequency ?? null;
    },
    activeFields() {
      return SCHEDULE_FREQUENCY_FIELDS[this.frequency] ?? [];
    },
    showMinute() {
      return this.activeFields.includes(SCHEDULE_FIELD_MINUTE);
    },
    showHour() {
      return this.activeFields.includes(SCHEDULE_FIELD_HOUR);
    },
    showDayOfWeek() {
      return this.activeFields.includes(SCHEDULE_FIELD_DAY_OF_WEEK);
    },
    showDayOfMonth() {
      return this.activeFields.includes(SCHEDULE_FIELD_DAY_OF_MONTH);
    },
    showTimezone() {
      return this.activeFields.includes(SCHEDULE_FIELD_TIMEZONE);
    },
    showRunAt() {
      return this.showHour || this.showMinute;
    },
    frequencyToggleText() {
      return (
        SCHEDULE_FREQUENCIES.find((option) => option.value === this.frequency)?.text ??
        s__('DuoAgentsPlatform|Select frequency')
      );
    },
    dayOfWeekItems() {
      return getWeekdayNames().map((text, value) => ({ value, text }));
    },
    dayOfWeekToggleText() {
      return this.dayOfWeekItems[this.schedule.dayOfWeek]?.text ?? '';
    },
    dayOfMonthItems() {
      return Array.from({ length: SCHEDULE_DAY_OF_MONTH_MAX }, (_, index) => ({
        value: index + 1,
        text: String(index + 1),
      }));
    },
    dayOfMonthToggleText() {
      return this.schedule.dayOfMonth != null ? String(this.schedule.dayOfMonth) : '';
    },
    hour() {
      return this.schedule.hour ?? 0;
    },
    minuteItems() {
      return SCHEDULE_MINUTE_VALUES.map((value) => ({
        value,
        text: String(value).padStart(2, '0'),
      }));
    },
    minuteToggleText() {
      return String(this.schedule.minute ?? 0).padStart(2, '0');
    },
    defaultTimezone() {
      // Only default to a zone the dropdown can actually display — storing an identifier absent
      // from `timezoneData` (e.g. a deprecated profile zone) would pass validation yet show blank.
      const isSelectable = (identifier) =>
        this.timezoneData.some((tz) => tz.identifier === identifier);

      if (this.userTimezone && isSelectable(this.userTimezone)) return this.userTimezone;

      const browserTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
      if (isSelectable(browserTimezone)) return browserTimezone;

      return isSelectable(SCHEDULE_DEFAULT_TIMEZONE) ? SCHEDULE_DEFAULT_TIMEZONE : '';
    },
  },
  methods: {
    emitSchedule(nextSchedule) {
      this.$emit('input', { ...this.value, [SCHEDULE_SCOPE]: nextSchedule });
    },
    patchSchedule(patch) {
      this.emitSchedule({ ...this.schedule, ...patch });
    },
    onSelectFrequency(frequency) {
      this.emitSchedule(randomizeScheduleDefaults(frequency, { timezone: this.defaultTimezone }));
    },
    onHourInput(value) {
      const parsed = Number.parseInt(value, 10);
      if (Number.isNaN(parsed)) {
        return;
      }
      this.patchSchedule({
        hour: Math.min(Math.max(parsed, SCHEDULE_HOUR_MIN), SCHEDULE_HOUR_MAX),
      });
    },
    onSelectMinute(minute) {
      this.patchSchedule({ minute });
    },
    onSelectDayOfWeek(dayOfWeek) {
      this.patchSchedule({ dayOfWeek });
    },
    onSelectDayOfMonth(dayOfMonth) {
      this.patchSchedule({ dayOfMonth });
    },
    onSelectTimezone(timezone) {
      this.patchSchedule({ timezone: timezone.identifier });
    },
  },
  runAtDescription: s__(
    'DuoAgentsPlatform|Triggers might run a few minutes after the scheduled time to distribute load across the system.',
  ),
  SCHEDULE_FREQUENCIES,
  SCHEDULE_HOUR_MIN,
  SCHEDULE_HOUR_MAX,
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-4">
    <gl-form-group
      :label="s__('DuoAgentsPlatform|Frequency')"
      :state="!invalidFeedback"
      :invalid-feedback="invalidFeedback"
      class="!gl-mb-0"
    >
      <gl-collapsible-listbox
        :items="$options.SCHEDULE_FREQUENCIES"
        :selected="frequency"
        :toggle-text="frequencyToggleText"
        :header-text="s__('DuoAgentsPlatform|Select frequency')"
        data-testid="frequency-listbox"
        block
        @select="onSelectFrequency"
      />
    </gl-form-group>

    <gl-form-group v-if="showDayOfWeek" :label="s__('DuoAgentsPlatform|Run on')" class="!gl-mb-0">
      <div class="gl-flex gl-items-center gl-gap-3">
        <gl-collapsible-listbox
          :items="dayOfWeekItems"
          :selected="schedule.dayOfWeek"
          :toggle-text="dayOfWeekToggleText"
          :header-text="s__('DuoAgentsPlatform|Select day of the week')"
          data-testid="day-of-week-listbox"
          @select="onSelectDayOfWeek"
        />
        <span class="gl-text-subtle">{{ s__('DuoAgentsPlatform|of each week') }}</span>
      </div>
    </gl-form-group>

    <gl-form-group v-if="showDayOfMonth" :label="s__('DuoAgentsPlatform|Run on')" class="!gl-mb-0">
      <div class="gl-flex gl-items-center gl-gap-3">
        <gl-collapsible-listbox
          :items="dayOfMonthItems"
          :selected="schedule.dayOfMonth"
          :toggle-text="dayOfMonthToggleText"
          :header-text="s__('DuoAgentsPlatform|Select day of the month')"
          data-testid="day-of-month-listbox"
          @select="onSelectDayOfMonth"
        />
        <span class="gl-text-subtle">{{ s__('DuoAgentsPlatform|of each month') }}</span>
      </div>
    </gl-form-group>

    <gl-form-group
      v-if="showRunAt"
      :label="s__('DuoAgentsPlatform|Run at')"
      :description="$options.runAtDescription"
      class="!gl-mb-0"
    >
      <div class="gl-flex gl-items-center gl-gap-2">
        <gl-form-input
          v-if="showHour"
          :value="hour"
          :aria-label="s__('DuoAgentsPlatform|Hour (24-hour)')"
          type="number"
          :min="$options.SCHEDULE_HOUR_MIN"
          :max="$options.SCHEDULE_HOUR_MAX"
          width="xs"
          data-testid="hour-input"
          @input="onHourInput"
        />
        <span v-if="showHour" aria-hidden="true">:</span>
        <span :id="minuteLabelId" class="gl-sr-only">{{ __('Minute') }}</span>
        <gl-collapsible-listbox
          :items="minuteItems"
          :selected="schedule.minute"
          :toggle-text="minuteToggleText"
          :toggle-aria-labelled-by="minuteLabelId"
          :header-text="s__('DuoAgentsPlatform|Select minute')"
          data-testid="minute-listbox"
          @select="onSelectMinute"
        />
        <span v-if="!showHour" class="gl-text-subtle">{{
          s__('DuoAgentsPlatform|minutes past the hour')
        }}</span>
      </div>
    </gl-form-group>

    <gl-form-group v-if="showTimezone" :label="__('Time zone')" class="!gl-mb-0">
      <timezone-dropdown
        :value="schedule.timezone || ''"
        :timezone-data="timezoneData"
        :header-text="__('Select timezone')"
        @input="onSelectTimezone"
      />
    </gl-form-group>
  </div>
</template>
