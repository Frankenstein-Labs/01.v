<script>
import { GlEmptyState, GlSprintf, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { DOC_PATH_SECURITY_CONFIGURATION } from 'ee/security_dashboard/constants';

export default {
  components: {
    GlEmptyState,
    GlSprintf,
    GlLink,
  },
  inject: ['emptyStateSvgPath'],
  i18n: {
    title: s__('SecurityReports|No vulnerabilities to report'),
    primaryButtonText: s__('SecurityReports|Learn more about security configuration'),
    description: s__(
      `SecurityReports|If you were expecting vulnerabilities to be shown here, check that you've completed the %{linkStart}security scanning prerequisites%{linkEnd}.`,
    ),
    descriptionLinkText: s__('SecurityReports|security scanning prerequisites'),
  },
  DOC_PATH_SECURITY_CONFIGURATION,
};
</script>

<template>
  <gl-empty-state
    :title="$options.i18n.title"
    :svg-path="emptyStateSvgPath"
    :svg-height="null"
    :primary-button-link="$options.DOC_PATH_SECURITY_CONFIGURATION"
    :primary-button-text="$options.i18n.primaryButtonText"
  >
    <template #description>
      <gl-sprintf :message="$options.i18n.description">
        <template #link>
          <gl-link :href="$options.DOC_PATH_SECURITY_CONFIGURATION">
            {{ $options.i18n.descriptionLinkText }}</gl-link
          >
        </template>
      </gl-sprintf>
    </template>
  </gl-empty-state>
</template>
