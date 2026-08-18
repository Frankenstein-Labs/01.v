import { shallowMount } from '@vue/test-utils';
import SetLicenseScanningForCyclonedx from 'ee/security_configuration/graphql/set_license_scanning_for_cyclonedx.mutation.graphql';
import LicenseScanningForCyclonedxFeatureCard from 'ee/security_configuration/components/license_scanning_for_cyclonedx_feature_card.vue';
import FeatureCardWithToggle from 'ee/security_configuration/components/feature_card_with_toggle.vue';
import { REPORT_TYPE_LICENSE_SCANNING_FOR_CYCLONEDX } from '~/vue_shared/security_reports/constants';

describe('LicenseScanningForCyclonedxFeatureCard', () => {
  const defaultFeature = {
    type: REPORT_TYPE_LICENSE_SCANNING_FOR_CYCLONEDX,
    name: 'License Scanning for CycloneDX',
    description: 'Description',
    helpPath: '/help/user/application_security/license_scanning/_index.md',
    canUserConfigure: true,
  };

  const createComponent = () =>
    shallowMount(LicenseScanningForCyclonedxFeatureCard, {
      provide: {
        projectFullPath: 'group/project',
        licenseScanningForCyclonedxEnabled: false,
      },
      propsData: { feature: defaultFeature },
    });

  it('renders FeatureCardWithToggle with the correct props', () => {
    const wrapper = createComponent();
    const card = wrapper.findComponent(FeatureCardWithToggle);

    expect(card.props()).toMatchObject({
      feature: defaultFeature,
      mutation: SetLicenseScanningForCyclonedx,
      initialValue: false,
      mutationResponseKey: 'setLicenseScanningForCyclonedx',
      enabledKey: 'licenseScanningForCyclonedxEnabled',
      toggleTestId: 'license-scanning-for-cyclonedx-toggle',
      i18n: expect.objectContaining({
        toastMessageEnabled: expect.stringContaining('CycloneDX'),
      }),
    });
  });
});
