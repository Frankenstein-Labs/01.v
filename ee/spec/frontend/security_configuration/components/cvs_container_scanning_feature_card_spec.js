import { shallowMount } from '@vue/test-utils';
import SetCvsForContainerScanningMutation from 'ee/security_configuration/graphql/set_cvs_for_container_scanning.mutation.graphql';
import CvsContainerScanningFeatureCard from 'ee/security_configuration/components/cvs_container_scanning_feature_card.vue';
import FeatureCardWithToggle from 'ee/security_configuration/components/feature_card_with_toggle.vue';

describe('CvsContainerScanningFeatureCard', () => {
  const defaultFeature = {
    type: 'cvs_for_container_scanning',
    name: 'Continuous Vulnerability Scanning for Container Scanning',
    description:
      'Automatically detects new container vulnerabilities based on SBOM data when new security advisories are ingested.',
    helpPath: '/help/user/application_security/continuous_vulnerability_scanning/_index.md',
    canUserConfigure: true,
  };

  const createComponent = ({ provide = {}, feature = defaultFeature } = {}) =>
    shallowMount(CvsContainerScanningFeatureCard, {
      provide: {
        projectFullPath: 'group/project',
        cvsForContainerScanningEnabled: true,
        ...provide,
      },
      propsData: { feature },
    });

  it('renders FeatureCardWithToggle with the correct props', () => {
    const wrapper = createComponent({ provide: { cvsForContainerScanningEnabled: false } });
    const card = wrapper.findComponent(FeatureCardWithToggle);

    expect(card.props()).toMatchObject({
      feature: defaultFeature,
      mutation: SetCvsForContainerScanningMutation,
      initialValue: false,
      mutationResponseKey: 'setCvsForContainerScanning',
      enabledKey: 'cvsForContainerScanningEnabled',
      toggleTestId: 'cvs-container-scanning-toggle',
      i18n: expect.objectContaining({
        toastMessageEnabled: expect.stringContaining('Container Scanning'),
      }),
    });
  });
});
