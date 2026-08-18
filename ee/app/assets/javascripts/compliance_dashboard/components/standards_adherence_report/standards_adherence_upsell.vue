<script>
import { GlEmptyState, GlBadge } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { PROMO_URL } from '~/constants';

export default {
  name: 'StandardsAdherenceUpsell',
  components: {
    GlEmptyState,
    GlBadge,
  },
  i18n: {
    title: s__('ComplianceReport|The compliance status report requires GitLab Ultimate'),
    description: s__(
      'ComplianceReport|Track requirement status across your projects with the compliance status report, available with GitLab Ultimate.',
    ),
    upgradeButtonText: s__('ComplianceReport|Upgrade your plan'),
    learnMoreButtonText: __('Learn more'),
    ultimateBadgeText: __('Ultimate'),
  },
  props: {
    upgradePath: {
      type: String,
      required: true,
    },
  },
  documentationPath: helpPagePath('user/compliance/compliance_center/compliance_status_report.md'),
  pricingUrl: `${PROMO_URL}/pricing/`,
};
</script>

<template>
  <gl-empty-state
    :description="$options.i18n.description"
    :primary-button-link="upgradePath"
    :primary-button-text="$options.i18n.upgradeButtonText"
    :secondary-button-link="$options.documentationPath"
    :secondary-button-text="$options.i18n.learnMoreButtonText"
  >
    <template #title>
      <h1 class="gl-mb-0 gl-mt-0 gl-text-size-h-display">
        {{ $options.i18n.title }}
        <gl-badge
          variant="tier"
          icon="license"
          :href="$options.pricingUrl"
          target="_blank"
          rel="noopener noreferrer"
        >
          {{ $options.i18n.ultimateBadgeText }}
        </gl-badge>
      </h1>
    </template>
  </gl-empty-state>
</template>
