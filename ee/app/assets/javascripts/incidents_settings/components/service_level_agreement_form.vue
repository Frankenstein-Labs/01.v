<script>
import {
  GlButton,
  GlForm,
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlFormSelect,
  GlTab,
} from '@gitlab/ui';
import { s__ } from '~/locale';

const units = {
  minutes: {
    value: 'minutes',
    text: s__('IncidentSettings|minutes'),
    multiplier: 1,
    step: 15,
  },
  hours: {
    value: 'hours',
    text: s__('IncidentSettings|hours'),
    multiplier: 60,
    step: 1,
  },
};

export default {
  name: 'ServiceLevelAgreementForm',
  i18n: {
    description: s__(
      'IncidentSettings|Introduce a countdown timer in incident issues to better track Service Level Agreements (SLAs). The timer starts automatically when the incident is created, and sets a time limit for resolving the incident. When activated, the time to SLA countdown appears on all new incidents.',
    ),
    checkboxDetail: s__(
      'IncidentSettings|When activated, this applies to all new incidents in the project.',
    ),
    validFeedback: s__('IncidentSettings|Time limit must be a multiple of 15 minutes.'),
  },
  selectOptions: Object.values(units),
  units,
  components: {
    GlButton,
    GlForm,
    GlFormCheckbox,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlTab,
  },
  inject: ['service', 'serviceLevelAgreementSettings'],
  data() {
    return {
      available: this.serviceLevelAgreementSettings.available,
      duration: this.serviceLevelAgreementSettings.minutes ?? '',
      enabled: this.serviceLevelAgreementSettings.active,
      loading: false,
      unit: this.$options.units.minutes.value,
    };
  },
  computed: {
    disableSubmit() {
      return this.loading || !this.showValidFeedback;
    },
    invalidFeedback() {
      // Don't validate when checkbox is disabled
      if (!this.enabled) {
        return '';
      }

      // This checks for empty and non-number values, because input elements of
      // type 'number' automatically convert a non-number input to an empty string.
      if (this.duration === '') {
        return s__('IncidentSettings|Time limit must be a valid number.');
      }

      if (this.duration <= 0) {
        return s__('IncidentSettings|Time limit must be greater than 0.');
      }

      // We're looking for a minutes value provided in multiples of 15
      const minutes = this.duration * this.$options.units[this.unit].multiplier;
      if (minutes % 15 !== 0) {
        return s__('IncidentSettings|Time limit must be a multiple of 15 minutes.');
      }

      return '';
    },
    showValidFeedback() {
      return !this.invalidFeedback;
    },
  },
  methods: {
    updateServiceLevelAgreementSettings() {
      this.loading = true;

      return this.service
        .updateSettings({
          sla_timer: this.enabled,
          sla_timer_minutes: this.duration * this.$options.units[this.unit].multiplier,
        })
        .catch(() => {
          this.loading = false;
        });
    },
  },
};
</script>

<template>
  <gl-tab
    v-if="available"
    key="service-level-agreement"
    :title="s__('IncidentSettings|Incident settings')"
    active
  >
    <gl-form class="gl-pt-3" @submit.prevent="updateServiceLevelAgreementSettings">
      <p class="gl-leading-20">
        {{ $options.i18n.description }}
      </p>
      <gl-form-checkbox v-model="enabled" class="gl-my-4">
        <span>{{ s__('IncidentSettings|Activate "time to SLA" countdown timer') }}</span>
        <template #help>
          {{ $options.i18n.checkboxDetail }}
        </template>
      </gl-form-checkbox>
      <gl-form-group
        :invalid-feedback="invalidFeedback"
        :label="s__('IncidentSettings|Time limit')"
        label-for="sla-duration"
        :state="showValidFeedback"
      >
        <div class="gl-flex gl-flex-row">
          <gl-form-input
            id="sla-duration"
            v-model="duration"
            number
            width="xs"
            :step="$options.units[unit].step"
            type="number"
          />
          <gl-form-select
            v-model="unit"
            class="gl-ml-3 gl-w-auto gl-border-gray-400 gl-leading-normal"
            :options="$options.selectOptions"
          />
        </div>
        <template v-if="showValidFeedback" #description>
          {{ $options.i18n.validFeedback }}
        </template>
      </gl-form-group>
      <gl-button variant="confirm" type="submit" :disabled="disableSubmit" :loading="loading">
        {{ __('Save changes') }}
      </gl-button>
    </gl-form>
  </gl-tab>
</template>
