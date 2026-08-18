<script>
import { s__ } from '~/locale';
import SetCvsForContainerScanningMutation from '../graphql/set_cvs_for_container_scanning.mutation.graphql';
import FeatureCardWithToggle from './feature_card_with_toggle.vue';

export default {
  name: 'CvsContainerScanningFeatureCard',
  components: { FeatureCardWithToggle },
  inject: {
    cvsForContainerScanningEnabled: { default: true },
  },
  props: {
    feature: {
      type: Object,
      required: true,
    },
  },
  mutation: SetCvsForContainerScanningMutation,
  i18n: {
    toastMessageEnabled: s__(
      'CVS|Continuous Vulnerability Scanning for Container Scanning is enabled',
    ),
    toastMessageDisabled: s__(
      'CVS|Continuous Vulnerability Scanning for Container Scanning is disabled',
    ),
  },
};
</script>

<template>
  <feature-card-with-toggle
    :feature="feature"
    :mutation="$options.mutation"
    :initial-value="cvsForContainerScanningEnabled"
    mutation-response-key="setCvsForContainerScanning"
    enabled-key="cvsForContainerScanningEnabled"
    toggle-test-id="cvs-container-scanning-toggle"
    :i18n="$options.i18n"
  />
</template>
