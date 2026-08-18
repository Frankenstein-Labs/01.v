<script>
import { debounce } from 'lodash-es';
import { GlButton, GlFormInput } from '@gitlab/ui';
import { s__ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import {
  PATTERN,
  SOURCE,
  TARGET,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';

export default {
  SOURCE,
  TARGET,
  name: 'BranchPatternItem',
  components: {
    GlButton,
    GlFormInput,
  },
  props: {
    branch: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    hasValidationError: {
      type: Boolean,
      required: false,
      default: false,
    },
    errorMessage: {
      type: String,
      required: false,
      default: s__('SecurityOrchestration|Please remove duplicates.'),
    },
  },
  emits: ['remove', 'set-branch'],
  computed: {
    sourcePattern() {
      return this.branch?.source?.pattern ?? '';
    },
    targetPattern() {
      return this.branch?.target?.pattern ?? this.branch?.target?.name ?? '';
    },
  },
  created() {
    this.debouncedSetBranch = debounce(this.setBranch, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSetBranch.cancel();
  },
  methods: {
    removeItem() {
      this.$emit('remove');
    },
    setBranch(value, type) {
      this.$emit('set-branch', {
        ...this.branch,
        [type]: {
          [PATTERN]: value,
        },
      });
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-flex gl-w-full gl-flex-col gl-gap-5 md:gl-flex-row md:gl-items-center">
      <div class="gl-flex gl-w-full gl-flex-col gl-items-center md:gl-flex-row">
        <gl-form-input
          :id="`source-${branch.id}`"
          data-testid="source-input"
          :placeholder="s__('ScanResultPolicy|input source branch')"
          :state="!hasValidationError"
          :value="sourcePattern"
          @input="debouncedSetBranch($event, $options.SOURCE)"
        />
        <span class="gl-mx-3">{{ __('to') }}</span>
        <gl-form-input
          :id="`target-${branch.id}`"
          data-testid="target-input"
          :placeholder="s__('ScanResultPolicy|input target branch')"
          :state="!hasValidationError"
          :value="targetPattern"
          @input="debouncedSetBranch($event, $options.TARGET)"
        />
      </div>

      <gl-button :aria-label="__('Remove')" icon="remove" @click="removeItem" />
    </div>

    <p v-if="hasValidationError" data-testid="error-message" class="gl-my-2 gl-text-danger">
      {{ errorMessage }}
    </p>
  </div>
</template>
