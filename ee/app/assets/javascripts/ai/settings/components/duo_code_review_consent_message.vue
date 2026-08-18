<script>
import { GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'DuoCodeReviewConsentMessage',
  i18n: {
    consentWarning: s__(
      'DuoCodeReview|Code Review Flow is enabled but reviews for users with a GitLab Duo Enterprise seat are handled by the non-agentic GitLab Duo Code Review instead. To use Code Review Flow for all reviews in this namespace, clear and then re-select Code Review Flow.',
    ),
    consentInfo: s__(
      'DuoCodeReview|Code Review Flow is enabled for this namespace. All reviews are handled by the flow and consume GitLab Credits',
    ),
  },
  components: {
    GlAlert,
  },
  inject: {
    duoEnterpriseActive: {
      default: false,
    },
  },
  props: {
    codeReviewFlowSelected: {
      type: Boolean,
      required: true,
    },
    codeReviewFlowConsentGiven: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    isCodeReviewFlowConsentRequired() {
      return this.duoEnterpriseActive;
    },
    showConsentWarning() {
      return (
        this.isCodeReviewFlowConsentRequired &&
        this.codeReviewFlowSelected &&
        !this.codeReviewFlowConsentGiven
      );
    },
    showConsentInfo() {
      return (
        this.isCodeReviewFlowConsentRequired &&
        this.codeReviewFlowSelected &&
        this.codeReviewFlowConsentGiven
      );
    },
  },
};
</script>
<template>
  <div>
    <gl-alert
      v-if="showConsentWarning"
      variant="warning"
      :dismissible="false"
      class="gl-mb-4 gl-ml-6 gl-mt-2"
      data-testid="code-review-flow-consent-warning"
    >
      {{ $options.i18n.consentWarning }}
    </gl-alert>
    <gl-alert
      v-if="showConsentInfo"
      variant="info"
      :dismissible="false"
      class="gl-mb-4 gl-ml-6 gl-mt-2"
      data-testid="code-review-flow-consent-info"
    >
      {{ $options.i18n.consentInfo }}
    </gl-alert>
  </div>
</template>
