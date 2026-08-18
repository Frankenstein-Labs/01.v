<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  mapOptions,
  EXCEPTIONS_FULL_OPTIONS_MAP,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';

export default {
  name: 'PolicyExceptionsSelector',
  components: {
    GlButton,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    selectedExceptions: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['select'],
  computed: {
    availableOptions() {
      return mapOptions(EXCEPTIONS_FULL_OPTIONS_MAP);
    },
    hasMultipleOptions() {
      return this.availableOptions.length > 1;
    },
  },
  methods: {
    buttonText(key) {
      return this.exceptionSelected(key) ? __('Update') : __('Select');
    },
    exceptionSelected(key) {
      return key in (this.selectedExceptions || {});
    },
    selectItem(key) {
      this.$emit('select', key);
    },
  },
};
</script>

<template>
  <div>
    <div
      v-for="(option, index) in availableOptions"
      :key="option.key"
      :class="{
        'gl-border-none': index === 0 && hasMultipleOptions,
        'gl-border-b': !hasMultipleOptions,
      }"
      class="gl-border-t gl-flex"
      data-testid="exception-type"
    >
      <div>
        <h4 data-testid="exception-type-header">{{ option.header }}</h4>
        <p>{{ option.description }}</p>
        <p>
          <strong>{{ __('Example:') }}</strong>
          <span>{{ option.example }}</span>
        </p>
      </div>
      <div class="gl-pt-4">
        <gl-button category="primary" variant="confirm" @click="selectItem(option.key)">
          {{ buttonText(option.key) }}
        </gl-button>
      </div>
    </div>
  </div>
</template>
