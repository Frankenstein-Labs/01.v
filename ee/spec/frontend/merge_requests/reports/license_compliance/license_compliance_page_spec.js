import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import LicenseCompliancePage from 'ee/merge_requests/reports/license_compliance/license_compliance_page.vue';
import LicenseComplianceProvider from 'ee/merge_requests/reports/license_compliance/license_compliance_provider.vue';
import LicenseComplianceContent from 'ee/merge_requests/reports/license_compliance/license_compliance_content.vue';

describe('LicenseCompliancePage', () => {
  let wrapper;

  const DEFAULT_MR_PROP = { id: 1 };

  const findProvider = () => wrapper.findComponent(LicenseComplianceProvider);
  const findContent = () => wrapper.findComponent(LicenseComplianceContent);

  const createComponent = () => {
    wrapper = shallowMountExtended(LicenseCompliancePage, {
      propsData: {
        mr: DEFAULT_MR_PROP,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders LicenseComplianceProvider with mr prop', () => {
    expect(findProvider().props('mr')).toBe(DEFAULT_MR_PROP);
  });

  it('renders LicenseComplianceContent inside provider', () => {
    expect(findContent().exists()).toBe(true);
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks view_merge_request_report on mount', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith(
        'view_merge_request_report',
        { label: 'license_compliance' },
        undefined,
      );
    });
  });
});
