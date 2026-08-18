<script>
import { GlButton, GlAlert, GlSprintf } from '@gitlab/ui';
import { ANY_MERGE_REQUEST, SCAN_FINDING, LICENSE_FINDING } from '../lib';
import { RULE_OR_LABEL } from '../../constants';
import AnyMergeRequestRuleBuilder from './any_merge_request_rule_builder.vue';
import SecurityScanRuleBuilder from './security_scan_rule_builder.vue';
import LicenseScanRuleBuilder from './license_scan_rule_builder.vue';
import DefaultRuleBuilder from './default_rule_builder.vue';

export default {
  name: 'RuleSection',
  RULE_OR_LABEL,
  components: {
    GlAlert,
    GlButton,
    GlSprintf,
    DefaultRuleBuilder,
    AnyMergeRequestRuleBuilder,
    SecurityScanRuleBuilder,
    LicenseScanRuleBuilder,
  },
  props: {
    errorSources: {
      type: Array,
      required: false,
      default: () => [],
    },
    index: {
      type: Number,
      required: false,
      default: 0,
    },
    initRule: {
      type: Object,
      required: true,
    },
  },
  emits: ['changed', 'remove'],
  data() {
    const previousRules = {
      [ANY_MERGE_REQUEST]: null,
      [SCAN_FINDING]: null,
      [LICENSE_FINDING]: null,
    };

    /**
     * Case for existing initRule
     * Or updates from yaml editor
     */
    if (this.initRule.type) {
      previousRules[this.initRule.type] = { ...this.initRule };
    }

    return {
      previousRules,
      error: null,
    };
  },
  computed: {
    isAnyMergeRequestRule() {
      return this.initRule.type === ANY_MERGE_REQUEST;
    },
    isSecurityRule() {
      return this.initRule.type === SCAN_FINDING;
    },
    isLicenseRule() {
      return this.initRule.type === LICENSE_FINDING;
    },
    isEmptyRule() {
      return this.initRule.type === '';
    },
    isFirstRule() {
      return this.index === 0;
    },
  },
  methods: {
    removeRule() {
      this.$emit('remove');
    },
    updateRule(rule) {
      this.$emit('changed', rule);
    },
    setScanType(rule) {
      const { type: previousType } = this.initRule;

      if (previousType) {
        this.previousRules[previousType] = this.initRule;
      }

      const value = this.previousRules[rule.type] || rule;
      this.$emit('changed', value);
    },
    handleError(error) {
      this.error = error;
    },
  },
};
</script>

<template>
  <div>
    <gl-alert v-if="error" :dismissible="false" class="gl-mb-3" variant="danger">
      <gl-sprintf :message="error">
        <template #bold="{ content }">
          <span class="!gl-font-bold">{{ content }}</span>
        </template>
      </gl-sprintf>
    </gl-alert>

    <div v-if="!isFirstRule" class="gl-mb-4 gl-ml-5 gl-text-subtle" data-testid="rule-separator">
      {{ $options.RULE_OR_LABEL }}
    </div>

    <div class="gl-flex">
      <div>
        <default-rule-builder
          v-if="isEmptyRule"
          :error-sources="errorSources"
          :index="index"
          :init-rule="initRule"
          @error="handleError"
          @changed="updateRule"
          @remove="removeRule"
          @set-scan-type="setScanType"
        />

        <any-merge-request-rule-builder
          v-else-if="isAnyMergeRequestRule"
          :init-rule="initRule"
          @changed="updateRule"
          @remove="removeRule"
          @set-scan-type="setScanType"
        />

        <security-scan-rule-builder
          v-else-if="isSecurityRule"
          :init-rule="initRule"
          @error="handleError"
          @changed="updateRule"
          @remove="removeRule"
          @set-scan-type="setScanType"
        />

        <license-scan-rule-builder
          v-else-if="isLicenseRule"
          :init-rule="initRule"
          @error="handleError"
          @changed="updateRule"
          @remove="removeRule"
          @set-scan-type="setScanType"
        />
      </div>

      <div class="security-policies-bg-subtle">
        <gl-button
          icon="remove"
          category="tertiary"
          :aria-label="__('Remove')"
          data-testid="remove-rule"
          @click="$emit('remove')"
        />
      </div>
    </div>
  </div>
</template>
