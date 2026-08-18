import { GlTabs, GlTab } from '@gitlab/ui';
import { nextTick } from 'vue';
import Api from '~/api';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import SecurityConfigurationApp from '~/security_configuration/components/app.vue';
import VulnerabilityArchives from 'ee/security_configuration/components/vulnerability_archives.vue';
import { securityFeaturesMock, provideMock } from 'jest/security_configuration/mock_data';
import { SERVICE_PING_SECURITY_CONFIGURATION_THREAT_MANAGEMENT_VISIT } from '~/tracking/constants';
import {
  TAB_VULNERABILITY_MANAGEMENT_INDEX,
  LICENSE_INFORMATION_SOURCE,
  i18n,
} from '~/security_configuration/constants';
import { REPORT_TYPE_CONTAINER_SCANNING_FOR_REGISTRY } from '~/vue_shared/security_reports/constants';
import FeatureCard from '~/security_configuration/components/feature_card.vue';
import ContainerScanningForRegistryFeatureCard from 'ee_component/security_configuration/components/container_scanning_for_registry_feature_card.vue';
import ProjectSecurityAttributesList from 'ee/security_configuration/security_attributes/components/project_attributes_list.vue';
import LicenseInformationSourceFeatureCard from 'ee/security_configuration/components/license_information_source_feature_card.vue';
import ScanProfileConfiguration from 'ee/security_configuration/components/scan_profiles/scan_profile_configuration.vue';
import { stubComponent } from 'helpers/stub_component';
import vulnerabilityArchivesQuery from 'ee/security_configuration/graphql/vulnerability_archives.query.graphql';
import getProjectSecurityAttributesQuery from 'ee_component/security_configuration/graphql/project_security_attributes.query.graphql';
import projectMergeRequestsEnabledQuery from '~/security_configuration/graphql/project_merge_requests_enabled.query.graphql';

jest.mock('~/api.js');

describe('~/security_configuration/components/app', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const vulnerabilityArchivesHandler = jest.fn().mockResolvedValue({
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        vulnerabilityArchives: [],
      },
    },
  });

  const projectSecurityAttributesHandler = jest.fn().mockResolvedValue({
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        securityAttributes: {
          nodes: [],
        },
      },
    },
  });

  const projectMergeRequestsEnabledHandler = jest.fn().mockResolvedValue({
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        __typename: 'Project',
        mergeRequestsEnabled: true,
      },
    },
  });

  const createComponent = ({
    props: { shouldShowCallout = true, ...propsData } = {},
    provide = {},
    mountFn = mountExtended,
    stubs,
  } = {}) => {
    userCalloutDismissSpy = jest.fn();

    wrapper = mountFn(SecurityConfigurationApp, {
      propsData: {
        augmentedSecurityFeatures: securityFeaturesMock,
        securityTrainingEnabled: true,
        ...propsData,
      },
      provide: {
        ...provideMock,
        vulnerabilityArchiveExportPath: '/some/path',
        userIsProjectAdmin: true,
        ...provide,
      },
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
        ...stubs,
      },
      apolloProvider: createMockApollo([
        [vulnerabilityArchivesQuery, vulnerabilityArchivesHandler],
        [getProjectSecurityAttributesQuery, projectSecurityAttributesHandler],
        [projectMergeRequestsEnabledQuery, projectMergeRequestsEnabledHandler],
      ]),
    });
  };

  const findVulnerabilityArchives = () => wrapper.findComponent(VulnerabilityArchives);
  const findTabsComponent = () => wrapper.findComponent(GlTabs);
  const findTabAtIndex = (i) => wrapper.findAllComponents(GlTab).at(i);
  const findFeatureCards = () => wrapper.findAllComponents(FeatureCard);
  const findContainerScanningForRegistry = () =>
    wrapper.findComponent(ContainerScanningForRegistryFeatureCard);
  const findLicenseInformationSource = () =>
    wrapper.findComponent(LicenseInformationSourceFeatureCard);
  const findScanProfileConfiguration = () => wrapper.findComponent(ScanProfileConfiguration);

  describe('tab change', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders two tabs', () => {
      expect(findTabAtIndex(0).exists()).toBe(true);
      expect(findTabAtIndex(1).exists()).toBe(true);
    });

    it('tracks "users_visiting_security_configuration_threat_management" when threat management tab is selected', () => {
      findTabsComponent().vm.$emit('input', TAB_VULNERABILITY_MANAGEMENT_INDEX);

      expect(Api.trackRedisHllUserEvent).toHaveBeenCalledTimes(1);
      expect(Api.trackRedisHllUserEvent).toHaveBeenCalledWith(
        SERVICE_PING_SECURITY_CONFIGURATION_THREAT_MANAGEMENT_VISIT,
      );
    });

    it("doesn't track the metric when other tab is selected", () => {
      findTabsComponent().vm.$emit('input', 0);

      expect(Api.trackRedisHllUserEvent).not.toHaveBeenCalled();
    });
  });

  describe('with container scanning for registry', () => {
    beforeEach(() => {
      createComponent({
        props: {
          augmentedSecurityFeatures: [
            {
              type: REPORT_TYPE_CONTAINER_SCANNING_FOR_REGISTRY,
            },
          ],
        },
      });
    });

    it('does not render the feature card component', () => {
      expect(findFeatureCards()).toHaveLength(0);
    });

    it('renders the component', () => {
      expect(findContainerScanningForRegistry().exists()).toBe(true);
      expect(findContainerScanningForRegistry().props('feature')).toEqual({
        type: REPORT_TYPE_CONTAINER_SCANNING_FOR_REGISTRY,
      });
    });
  });

  describe('with license information source', () => {
    beforeEach(() => {
      createComponent({
        props: {
          augmentedSecurityFeatures: [
            {
              type: LICENSE_INFORMATION_SOURCE,
            },
          ],
        },
      });
    });

    it('does not render the feature card component', () => {
      expect(findFeatureCards()).toHaveLength(0);
    });

    it('renders the component', () => {
      expect(findLicenseInformationSource().props('feature')).toEqual({
        type: LICENSE_INFORMATION_SOURCE,
      });
    });
  });

  describe('Vulnerability archives', () => {
    it.each`
      featureFlag
      ${true}
      ${false}
    `('does not render archives if flag is $featureFlag', async ({ featureFlag }) => {
      await createComponent({
        provide: { glFeatures: { vulnerabilityArchival: featureFlag } },
        mountFn: shallowMountExtended,
        stubs: {
          GlTab: stubComponent(GlTab, {
            template: `
              <li>
                <slot name="title"></slot>
                <slot></slot>
              </li>
            `,
          }),
        },
      });

      // VulnerabilityArchives is an async component.
      await waitForPromises();

      expect(findVulnerabilityArchives().exists()).toBe(featureFlag);
    });
  });

  describe('Security attributes tab', () => {
    describe.each`
      securityAttributes | canReadAttributes | result
      ${false}           | ${false}          | ${false}
      ${false}           | ${true}           | ${false}
      ${true}            | ${false}          | ${false}
      ${true}            | ${true}           | ${true}
    `(
      'with licensed feature set to $securityAttributes, and canManageAttributes set to $canManageAttributes',
      ({ securityAttributes, canReadAttributes, result }) => {
        beforeEach(async () => {
          window.gon = {
            licensed_features: { securityAttributes },
          };

          createComponent({
            provide: { canReadAttributes },
            mountFn: shallowMountExtended,
            stubs: {
              GlTab: stubComponent(GlTab, {
                template: `
              <li>
                <slot name="title"></slot>
                <slot></slot>
              </li>
            `,
              }),
            },
          });

          await nextTick();
        });

        it('renders the tab when correctly licensed', () => {
          expect(wrapper.findComponent(ProjectSecurityAttributesList).exists()).toBe(result);
        });
      },
    );
  });

  describe('scanner profiles section', () => {
    describe('when securityScanProfilesFeature feature flag is enabled', () => {
      beforeEach(async () => {
        createComponent({
          props: {
            augmentedSecurityFeatures: securityFeaturesMock,
            securityTrainingEnabled: true,
          },
          provide: {
            glFeatures: {
              securityScanProfilesFeature: true,
            },
          },
        });
        await nextTick();
      });

      it('renders scanner profile configuration component', () => {
        expect(findScanProfileConfiguration().exists()).toBe(true);
      });

      it('displays scanner profiles section with correct heading', () => {
        const section = wrapper.text();
        expect(section).toContain(i18n.securityProfiles);
      });

      it('displays scanner profiles description', () => {
        const section = wrapper.text();
        expect(section).toContain(i18n.securityProfilesDesc);
      });
    });

    describe('when securityScanProfilesFeature feature flag is disabled', () => {
      beforeEach(() => {
        createComponent({
          props: {
            augmentedSecurityFeatures: securityFeaturesMock,
            securityTrainingEnabled: true,
          },
          provide: {
            glFeatures: {
              securityScanProfilesFeature: false,
            },
          },
        });
      });

      it('does not render scanner profile configuration component', () => {
        expect(findScanProfileConfiguration().exists()).toBe(false);
      });

      it('does not display scanner profiles section', () => {
        const section = wrapper.text();
        expect(section).not.toContain(i18n.securityProfiles);
      });
    });
  });
});
