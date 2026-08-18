<script>
import { GlIcon, GlFormCheckbox, GlPopover, GlFormInput, GlFormGroup } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  UNBLOCK_RULES_KEY,
  UNBLOCK_RULES_TEXT,
  TIME_WINDOW_KEY,
  TIME_WINDOW_TEXT,
  TIME_WINDOW_POPOVER_DESC,
  TIME_WINDOW_MIN_VALUE,
  TIME_WINDOW_MAX_VALUE,
} from './constants';

export default {
  name: 'EdgeCasesSection',
  i18n: {
    UNBLOCK_RULES_TEXT,
    TIME_WINDOW_TEXT,
    TIME_WINDOW_POPOVER_DESC,
    popoverTitle: __('Information'),
    popoverDesc: s__(
      'ScanResultPolicy|When enabled, approval rules do not block merge requests when a scan is required by a scan execution policy or a pipeline execution policy but a required scan artifact is missing from the target branch. This option only works when the project or group has an existing scan execution policy or pipeline execution policy with matching scanners.',
    ),
    timeWindowLabel: s__(
      'ScanResultPolicy|Use security reports from pipelines completed within the last',
    ),
    timeWindowUnit: s__('ScanResultPolicy|minutes'),
  },
  components: {
    GlIcon,
    GlFormCheckbox,
    GlPopover,
    GlFormInput,
    GlFormGroup,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    policyTuning: {
      type: Object,
      required: false,
      default: () => ({
        unblock_rules_using_execution_policies: false,
      }),
    },
  },
  emits: ['changed'],
  data() {
    return {
      timeWindowValueEnabled: this.policyTuning[TIME_WINDOW_KEY] !== undefined,
    };
  },
  computed: {
    timeWindowValue() {
      return this.policyTuning[TIME_WINDOW_KEY] || this.$options.TIME_WINDOW_MIN_VALUE;
    },
    timeWindowSettingEnabled() {
      return this.policyTuning[TIME_WINDOW_KEY] !== undefined;
    },
  },
  methods: {
    updateSetting(key, value) {
      const updates = { [key]: value };
      this.updatePolicy(updates);
    },
    updateTimeWindowValue(value) {
      const numericValue = parseInt(value, 10);
      if (
        numericValue >= this.$options.TIME_WINDOW_MIN_VALUE &&
        numericValue <= this.$options.TIME_WINDOW_MAX_VALUE
      ) {
        this.updateSetting(TIME_WINDOW_KEY, numericValue);
      }
    },
    updatePolicy(updates = {}) {
      const payload = { ...this.policyTuning, ...updates };
      if (payload[TIME_WINDOW_KEY] === undefined) {
        delete payload[TIME_WINDOW_KEY];
      }

      this.$emit('changed', 'policy_tuning', { ...payload });
    },
    toggleTimeWindowSetting(enabled) {
      this.timeWindowValueEnabled = enabled;
      const payload = enabled ? this.timeWindowValue : undefined;
      this.updateSetting(TIME_WINDOW_KEY, payload);
    },
  },
  UNBLOCK_RULES_KEY,
  TIME_WINDOW_KEY,
  TIME_WINDOW_MIN_VALUE,
  TIME_WINDOW_MAX_VALUE,
  POPOVER_TARGET_SELECTOR: 'comparison-tuning-popover',
  TIME_WINDOW_POPOVER_TARGET_SELECTOR: 'time-window-popover',
};
</script>

<template>
  <div class="gl-mt-3">
    <gl-form-checkbox
      :id="$options.UNBLOCK_RULES_KEY"
      class="gl-inline-block"
      :checked="policyTuning[$options.UNBLOCK_RULES_KEY]"
      @change="updateSetting($options.UNBLOCK_RULES_KEY, $event)"
    >
      {{ $options.i18n.UNBLOCK_RULES_TEXT }}
      <gl-icon :id="$options.POPOVER_TARGET_SELECTOR" name="information-o" />
    </gl-form-checkbox>

    <gl-popover :target="$options.POPOVER_TARGET_SELECTOR" :title="$options.i18n.popoverTitle">
      {{ $options.i18n.popoverDesc }}
    </gl-popover>

    <div class="gl-mt-3">
      <gl-form-checkbox
        :id="$options.TIME_WINDOW_KEY"
        class="gl-inline-block"
        :checked="timeWindowSettingEnabled"
        @change="toggleTimeWindowSetting"
      >
        {{ $options.i18n.TIME_WINDOW_TEXT }}
        <gl-icon :id="$options.TIME_WINDOW_POPOVER_TARGET_SELECTOR" name="information-o" />
      </gl-form-checkbox>

      <gl-popover :target="$options.TIME_WINDOW_POPOVER_TARGET_SELECTOR" name="information-o">
        {{ $options.i18n.TIME_WINDOW_POPOVER_DESC }}
      </gl-popover>

      <div v-if="timeWindowValueEnabled" class="gl-mt-3 gl-rounded-base gl-p-3">
        <gl-form-group :label="$options.i18n.timeWindowLabel" class="gl-mb-0">
          <div class="gl-flex gl-items-center gl-gap-3">
            <gl-form-input
              :value="timeWindowValue"
              type="number"
              :min="$options.TIME_WINDOW_MIN_VALUE"
              :max="$options.TIME_WINDOW_MAX_VALUE"
              class="gl-w-20"
              @input="updateTimeWindowValue"
            />
            <span class="gl-text-gray-700">{{ $options.i18n.timeWindowUnit }}</span>
          </div>
        </gl-form-group>
      </div>
    </div>
  </div>
</template>
