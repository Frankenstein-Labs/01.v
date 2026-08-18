<script>
import { s__ } from '~/locale';
import SetLicenseScanningForCyclonedx from 'ee/security_configuration/graphql/set_license_scanning_for_cyclonedx.mutation.graphql';
import FeatureCardWithToggle from './feature_card_with_toggle.vue';

export default {
  name: 'LicenseScanningForCyclonedxFeatureCard',
  components: { FeatureCardWithToggle },
  inject: {
    licenseScanningForCyclonedxEnabled: { default: true },
  },
  props: {
    feature: {
      type: Object,
      required: true,
    },
  },
  mutation: SetLicenseScanningForCyclonedx,
  i18n: {
    toastMessageEnabled: s__('LicenseScanning|License scanning for CycloneDX is enabled'),
    toastMessageDisabled: s__('LicenseScanning|License scanning for CycloneDX is disabled'),
  },
};
</script>

<template>
  <feature-card-with-toggle
    :feature="feature"
    :mutation="$options.mutation"
    :initial-value="licenseScanningForCyclonedxEnabled"
    mutation-response-key="setLicenseScanningForCyclonedx"
    enabled-key="licenseScanningForCyclonedxEnabled"
    toggle-test-id="license-scanning-for-cyclonedx-toggle"
    :i18n="$options.i18n"
  />
</template>
