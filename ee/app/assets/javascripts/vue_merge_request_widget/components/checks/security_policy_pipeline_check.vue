<script>
import { uniqueId } from 'lodash-es';
import { GlIcon, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';
import MergeChecksMessage from '~/vue_merge_request_widget/components/checks/message.vue';
import ActionButtons from '~/vue_merge_request_widget/components/action_buttons.vue';

export default {
  name: 'MergeChecksSecurityPolicyPipelineCheck',
  components: {
    ActionButtons,
    GlIcon,
    GlPopover,
    MergeChecksMessage,
  },
  props: {
    mr: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    check: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      helpIconId: uniqueId('security-policy-pipeline-help-icon-'),
    };
  },
  computed: {
    isActive() {
      return this.check.status !== 'INACTIVE';
    },
    hasSecurityPoliciesPath() {
      return Boolean(this.mr.securityPoliciesPath);
    },
    tertiaryActionsButtons() {
      return this.hasSecurityPoliciesPath
        ? [
            {
              href: this.mr.securityPoliciesPath,
              text: s__('MergeChecks|View policies'),
              testId: 'view-policies-button',
            },
          ]
        : [];
    },
    popoverBody() {
      return s__(
        'MergeChecks|When security policies are enforced, all pipelines for the latest commit must succeed before this merge request can be merged.',
      );
    },
  },
};
</script>

<template>
  <merge-checks-message :check="check">
    <template v-if="isActive">
      <div v-if="hasSecurityPoliciesPath">
        <gl-icon
          :id="helpIconId"
          data-testid="security-policy-pipeline-help-icon"
          name="information-o"
          variant="info"
          class="gl-mr-3"
        />
        <gl-popover
          :target="helpIconId"
          data-testid="security-policy-pipeline-help-popover"
          placement="top"
        >
          <template #title>{{ s__('MergeChecks|Security policy pipeline check') }}</template>
          <p class="gl-mb-0">
            {{ popoverBody }}
          </p>
        </gl-popover>
      </div>
      <action-buttons :tertiary-buttons="tertiaryActionsButtons" />
    </template>
  </merge-checks-message>
</template>
