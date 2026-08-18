import { shallowMount } from '@vue/test-utils';
import SetCvsForDependencyScanningMutation from 'ee/security_configuration/graphql/set_cvs_for_dependency_scanning.mutation.graphql';
import CvsDependencyScanningFeatureCard from 'ee/security_configuration/components/cvs_dependency_scanning_feature_card.vue';
import FeatureCardWithToggle from 'ee/security_configuration/components/feature_card_with_toggle.vue';

describe('CvsDependencyScanningFeatureCard', () => {
  const defaultFeature = {
    type: 'cvs_for_dependency_scanning',
    name: 'Continuous Vulnerability Scanning for Dependency Scanning',
    description:
      'Automatically detects new dependency vulnerabilities based on SBOM data when new security advisories are ingested.',
    helpPath: '/help/user/application_security/continuous_vulnerability_scanning/_index.md',
    canUserConfigure: true,
  };

  const createComponent = ({ provide = {}, feature = defaultFeature } = {}) =>
    shallowMount(CvsDependencyScanningFeatureCard, {
      provide: {
        projectFullPath: 'group/project',
        cvsForDependencyScanningEnabled: true,
        ...provide,
      },
      propsData: { feature },
    });

  it('renders FeatureCardWithToggle with the correct props', () => {
    const wrapper = createComponent({ provide: { cvsForDependencyScanningEnabled: false } });
    const card = wrapper.findComponent(FeatureCardWithToggle);

    expect(card.props()).toMatchObject({
      feature: defaultFeature,
      mutation: SetCvsForDependencyScanningMutation,
      initialValue: false,
      mutationResponseKey: 'setCvsForDependencyScanning',
      enabledKey: 'cvsForDependencyScanningEnabled',
      toggleTestId: 'cvs-dependency-scanning-toggle',
      i18n: expect.objectContaining({
        toastMessageEnabled: expect.stringContaining('Dependency Scanning'),
      }),
    });
  });
});
