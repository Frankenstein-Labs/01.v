<script>
import { GlAccordion, GlAccordionItem, GlDatepicker, GlFormInput, GlSprintf } from '@gitlab/ui';
import { toISOStringWithoutMilliseconds, newDate } from '~/lib/utils/datetime_utility';
import { s__ } from '~/locale';

export default {
  name: 'SnoozeForm',
  components: {
    GlAccordion,
    GlAccordionItem,
    GlDatepicker,
    GlFormInput,
    GlSprintf,
  },
  props: {
    data: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['update'],
  i18n: {
    reasonPlaceholder: s__('SecurityOrchestration|Reason for snoozing policy (optional)'),
    untilPlaceholder: s__('SecurityOrchestration|Select date'),
  },
  computed: {
    hasUntil() {
      return Boolean(this.data?.until);
    },
    minDate() {
      return new Date();
    },
    reason() {
      return this.data?.reason || '';
    },
    until() {
      return new Date(this.data?.until) || '';
    },
  },
  methods: {
    handleUpdateReason(reason) {
      this.$emit('update', { ...this.data, reason });
    },
    handleUpdateUntil(until) {
      this.$emit('update', {
        ...this.data,
        until: toISOStringWithoutMilliseconds(newDate(until), '00:00'),
      });
    },
  },
};
</script>

<template>
  <gl-accordion :header-level="3" class="gl-mt-3">
    <gl-accordion-item
      :title="s__('SecurityOrchestration|Snooze policy')"
      :visible="hasUntil"
      data-testid="snooze-options"
    >
      <gl-sprintf
        :message="s__('SecurityOrchestration|Snooze the policy until %{until} because %{reason}')"
      >
        <template #until>
          <gl-datepicker
            class="gl-inline-block gl-w-20"
            data-testid="until-input"
            :aria-label="$options.i18n.untilPlaceholder"
            :value="until"
            type="date"
            :placeholder="$options.i18n.untilPlaceholder"
            :min-date="minDate"
            @input="handleUpdateUntil"
          />
        </template>
        <template #reason>
          <gl-form-input
            class="gl-inline-block gl-w-34"
            data-testid="reason-input"
            :aria-label="$options.i18n.reasonPlaceholder"
            :value="reason"
            type="text"
            :placeholder="$options.i18n.reasonPlaceholder"
            @update="handleUpdateReason"
          />
        </template>
      </gl-sprintf>
    </gl-accordion-item>
  </gl-accordion>
</template>
