<script>
import { GlAlert, GlExperimentBadge } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import EdgeCasesSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/edge_cases_section.vue';
import FallbackSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/fallback_section.vue';
import { CLOSED } from './constants';

export default {
  name: 'FallbackAndEdgeCasesSection',
  i18n: {
    title: s__('ScanResultPolicy|Fallback behavior and edge case settings'),
    fallbackBehaviorTitle: s__('ScanResultPolicy|Fallback behavior'),
    edgeCaseSettingsTitle: s__('ScanResultPolicy|Edge case settings'),
    experimentTitle: __('Experiment'),
    invalidFallbackMessage: s__(
      'ScanResultPolicy|Invalid fallback value detected. Please update your selection.',
    ),
  },
  components: {
    EdgeCasesSection,
    FallbackSection,
    GlAlert,
    GlExperimentBadge,
  },
  props: {
    hasError: {
      type: Boolean,
      required: false,
      default: false,
    },
    policy: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  emits: ['changed'],
  computed: {
    fallbackBehaviorSetting() {
      return this.policy.fallback_behavior?.fail || CLOSED;
    },
  },
  methods: {
    updateProperty(key, value) {
      this.$emit('changed', key, value);
    },
  },
  POPOVER_TARGET_SELECTOR: 'fallback-popover',
};
</script>

<template>
  <div class="gl-mt-7">
    <h4>{{ $options.i18n.title }}</h4>

    <h5>{{ $options.i18n.fallbackBehaviorTitle }}</h5>

    <gl-alert v-if="hasError" variant="danger" :dismissible="false" class="gl-mb-5">
      {{ $options.i18n.invalidFallbackMessage }}
    </gl-alert>

    <fallback-section :property="fallbackBehaviorSetting" @changed="updateProperty" />

    <h5>
      {{ $options.i18n.edgeCaseSettingsTitle }}
      <gl-experiment-badge class="gl-ml-2" />
    </h5>
    <edge-cases-section :policy-tuning="policy.policy_tuning" @changed="updateProperty" />
  </div>
</template>
