import { GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { CLICK_EXTERNAL_LINK_LICENSE_COMPLIANCE } from 'ee/vue_shared/license_compliance/constants';
import LicenseIssueBody from 'ee/vue_shared/license_compliance/components/license_issue_body.vue';
import LicensePackages from 'ee/vue_shared/license_compliance/components/license_packages.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { licenseReport } from '../mock_data';

describe('LicenseIssueBody', () => {
  let wrapper;

  const findLicenseIssueBody = () => wrapper.findComponent(LicenseIssueBody);
  const findLicensePackages = () => wrapper.findComponent(LicensePackages);
  const findGlLink = () => wrapper.findComponent(GlLink);
  const findText = () => wrapper.find('[data-testid="license-copy"]');

  const createComponent = (props = {}) => {
    wrapper = extendedWrapper(
      shallowMount(LicenseIssueBody, {
        propsData: {
          ...props,
        },
      }),
    );
  };

  beforeEach(() => {
    createComponent({ issue: licenseReport[0] });
  });

  describe('on load', () => {
    it('renders license issue body', () => {
      expect(findLicenseIssueBody().exists()).toBe(true);
    });

    it('renders packages list', () => {
      expect(findLicensePackages().exists()).toBe(true);
    });
  });

  describe('when issue url is defined', () => {
    it('renders link to view license', () => {
      const link = findGlLink();
      const text = findText();

      expect(link.text()).toBe(licenseReport[0].name);
      expect(link.attributes('href')).toBe(licenseReport[0].url);
      expect(text.exists()).toBe(false);
    });
  });

  describe('when issue url is undefined', () => {
    beforeEach(() => {
      createComponent({ issue: licenseReport[1] });
    });

    it('renders text to view license', () => {
      const link = findGlLink();
      const text = findText();

      expect(text.text()).toBe(licenseReport[1].name);
      expect(link.exists()).toBe(false);
    });
  });

  describe('template without packages', () => {
    beforeEach(() => {
      const issueWithoutPackages = licenseReport[0];
      issueWithoutPackages.packages = [];

      createComponent({ issue: issueWithoutPackages });
    });

    it('does not render packages list', () => {
      const packages = findLicensePackages();
      expect(packages.exists()).toBe(false);
    });
  });

  describe('event tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks click_external_link_license_compliance', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findGlLink().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        CLICK_EXTERNAL_LINK_LICENSE_COMPLIANCE,
        {},
        undefined,
      );
    });
  });
});
