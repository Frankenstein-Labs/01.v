import { nextTick } from 'vue';
import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VulnerabilitiesPopover from 'ee/dependencies/components/vulnerabilities_popover.vue';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';

describe('VulnerabilitiesPopover component', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const createWrapper = ({ shouldShowCallout = true, glFeatures = {} } = {}) => {
    userCalloutDismissSpy = jest.fn();

    wrapper = shallowMountExtended(VulnerabilitiesPopover, {
      provide: {
        glFeatures: { maliciousPackageDetection: true, ...glFeatures },
      },
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
      },
    });
  };

  const findVulnerabilityInfoIcon = () => wrapper.findComponent(GlIcon);
  const findVulnerabilityInfoPopover = () =>
    wrapper.findComponentByTestId('vulnerability-info-popover');

  beforeEach(createWrapper);

  it('renders vulnerability info icon and popover', () => {
    expect(findVulnerabilityInfoIcon().exists()).toBe(true);
    expect(findVulnerabilityInfoPopover().exists()).toBe(true);
    expect(findVulnerabilityInfoPopover().props()).toMatchObject({
      title: 'Focused risk reporting',
      show: true,
    });
  });

  it('renders the risk explanation including malware packages', () => {
    expect(findVulnerabilityInfoPopover().text()).toBe(
      'Risk includes known vulnerabilities and malware packages currently detected in your project. Previously detected findings that are no longer present are excluded to keep risk assessments accurate.',
    );
  });

  describe('when maliciousPackageDetection feature flag is disabled', () => {
    beforeEach(() => {
      createWrapper({ glFeatures: { maliciousPackageDetection: false } });
    });

    it('renders the risk explanation without mentioning malware packages', () => {
      expect(findVulnerabilityInfoPopover().text()).toBe(
        'Risk includes known vulnerabilities currently detected in your project. Previously detected findings that are no longer present are excluded to keep risk assessments accurate.',
      );
    });
  });

  describe('when popover has been dismissed', () => {
    beforeEach(() => {
      createWrapper({ shouldShowCallout: false });
    });

    it('does not show popover', () => {
      expect(findVulnerabilityInfoPopover().props('show')).toBe(false);
    });
  });

  describe('when popover is dismissed', () => {
    it('handles closing the feature pop-up', async () => {
      findVulnerabilityInfoPopover().vm.$emit('close-button-clicked');
      await nextTick();
      expect(userCalloutDismissSpy).toHaveBeenCalled();
    });
  });
});
