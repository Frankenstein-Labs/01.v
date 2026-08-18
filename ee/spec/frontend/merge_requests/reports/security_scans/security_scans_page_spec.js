import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import SecurityScansPage from 'ee/merge_requests/reports/security_scans/security_scans_page.vue';
import SecurityScansProvider from 'ee/merge_requests/reports/security_scans/security_scans_provider.vue';
import SecurityScansContent from 'ee/merge_requests/reports/security_scans/security_scans_content.vue';

describe('SecurityScansPage', () => {
  let wrapper;

  const DEFAULT_MR_PROP = { id: 1 };

  const createComponent = () => {
    wrapper = shallowMountExtended(SecurityScansPage, {
      propsData: {
        mr: DEFAULT_MR_PROP,
      },
    });
  };

  const findProvider = () => wrapper.findComponent(SecurityScansProvider);
  const findContent = () => wrapper.findComponent(SecurityScansContent);

  beforeEach(() => {
    createComponent();
  });

  it('passes mr prop to SecurityScansProvider', () => {
    expect(findProvider().props('mr')).toEqual(DEFAULT_MR_PROP);
  });

  it('passes mr prop to SecurityScansContent', () => {
    expect(findContent().props('mr')).toEqual(DEFAULT_MR_PROP);
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks view_merge_request_report on mount', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith(
        'view_merge_request_report',
        { label: 'security_scan' },
        undefined,
      );
    });
  });
});
