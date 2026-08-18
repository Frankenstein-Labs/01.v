<script>
import { s__ } from '~/locale';
import SetCvsForDependencyScanningMutation from '../graphql/set_cvs_for_dependency_scanning.mutation.graphql';
import FeatureCardWithToggle from './feature_card_with_toggle.vue';

export default {
  name: 'CvsDependencyScanningFeatureCard',
  components: { FeatureCardWithToggle },
  inject: {
    cvsForDependencyScanningEnabled: { default: true },
  },
  props: {
    feature: {
      type: Object,
      required: true,
    },
  },
  mutation: SetCvsForDependencyScanningMutation,
  i18n: {
    toastMessageEnabled: s__(
      'CVS|Continuous Vulnerability Scanning for Dependency Scanning is enabled',
    ),
    toastMessageDisabled: s__(
      'CVS|Continuous Vulnerability Scanning for Dependency Scanning is disabled',
    ),
  },
};
</script>

<template>
  <feature-card-with-toggle
    :feature="feature"
    :mutation="$options.mutation"
    :initial-value="cvsForDependencyScanningEnabled"
    mutation-response-key="setCvsForDependencyScanning"
    enabled-key="cvsForDependencyScanningEnabled"
    toggle-test-id="cvs-dependency-scanning-toggle"
    :i18n="$options.i18n"
  />
</template>
