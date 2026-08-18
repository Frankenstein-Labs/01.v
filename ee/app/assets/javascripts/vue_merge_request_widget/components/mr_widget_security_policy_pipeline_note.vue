<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'MrWidgetSecurityPolicyPipelineNote',
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
  },
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  i18n: {
    message: s__(
      'mrWidget|Merge request pipeline has passed, but a security policy requires all pipelines to succeed. Another pipeline for this commit has failed. %{linkStart}View policies%{linkEnd}',
    ),
  },
};
</script>

<template>
  <div
    class="mr-section-container mr-widget-security-policy-pipeline-note !gl-mt-0 gl-flex gl-items-center gl-gap-3 !gl-rounded-t-none !gl-border-t-0 gl-bg-subtle gl-px-5 gl-py-3 gl-text-sm gl-text-subtle"
    data-testid="security-policy-pipeline-note"
  >
    <gl-icon name="status-alert" :size="16" variant="warning" class="gl-shrink-0" />
    <p class="gl-mb-0">
      <gl-sprintf :message="$options.i18n.message">
        <template #link="{ content }">
          <gl-link :href="mr.securityPoliciesPath" data-testid="view-policies-link">{{
            content
          }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
  </div>
</template>
