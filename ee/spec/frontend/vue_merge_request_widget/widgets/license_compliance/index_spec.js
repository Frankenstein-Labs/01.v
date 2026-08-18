import MockAdapter from 'axios-mock-adapter';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import waitForPromises from 'helpers/wait_for_promises';
import api from '~/api';
import axios from '~/lib/utils/axios_utils';
import Widget from '~/vue_merge_request_widget/components/widget/widget.vue';

import licenseComplianceExtension from 'ee/vue_merge_request_widget/widgets/license_compliance/index.vue';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { licenseComplianceNewLicenses } from './mock_data';

describe('License Compliance extension', () => {
  let wrapper;
  let mock;

  const licenseComparisonPath =
    '/group-name/project-name/-/merge_requests/78/license_scanning_reports';
  const licenseComparisonPathCollapsed =
    '/group-name/project-name/-/merge_requests/78/license_scanning_reports_collapsed';
  const fullReportPath = '/group-name/project-name/-/merge_requests/78/full_report';
  const settingsPath = '/group-name/project-name/-/licenses#licenses';
  const apiApprovalsPath = '/group-name/project-name/-/licenses#policies';
  const reportsTabPath = '/group-name/project-name/-/merge_requests/78/reports';

  const mockApi = (endpoint, statusCode, data) => {
    mock.onGet(endpoint).reply(statusCode, data, {});
  };

  const findWidget = () => wrapper.findComponent(Widget);
  const findSummary = () => wrapper.findByTestId('widget-extension-top-level-summary');

  const createComponent = ({ licenseComplianceProps = {}, provide } = {}) => {
    wrapper = mountExtended(licenseComplianceExtension, {
      provide,
      propsData: {
        mr: {
          reportsTabPath,
          licenseCompliance: {
            license_scanning_comparison_path: licenseComparisonPath,
            license_scanning_comparison_collapsed_path: licenseComparisonPathCollapsed,
            api_approvals_path: apiApprovalsPath,
            license_scanning: {
              settings_path: settingsPath,
              full_report_path: fullReportPath,
            },
            ...licenseComplianceProps,
          },
        },
      },
    });
  };

  beforeEach(() => {
    jest.spyOn(api, 'trackRedisCounterEvent').mockImplementation(() => {});
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  it('emits loaded event', async () => {
    mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

    createComponent();

    await waitForPromises();

    expect(wrapper.emitted('loaded')[0]).toContain(4);
  });

  describe('summary', () => {
    it('displays loading text', () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

      createComponent();

      expect(findSummary().text()).toBe('License Compliance test metrics results are being parsed');
    });

    it('displays failed loading text', async () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_INTERNAL_SERVER_ERROR);

      createComponent();

      await waitForPromises();
      expect(findSummary().text()).toBe('License Compliance failed loading results');
    });

    it('displays the help popover', () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

      createComponent();

      expect(findWidget().props('helpPopover')).toEqual({
        content: {
          learnMorePath:
            '/help/user/compliance/license_approval_policies#criteria-to-compare-licenses-detected-in-the-merge-request-branch-to-licenses-in-the-default-branch',
          text: 'Detects known vulnerabilities in your software dependencies.',
        },
        options: {
          title: 'License scan results',
        },
      });
    });
  });

  describe('action buttons', () => {
    it('displays the "View report" button', async () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

      createComponent();

      await waitForPromises();

      const actionButtons = findWidget().props('actionButtons');
      expect(actionButtons).toHaveLength(1);
      expect(actionButtons[0]).toMatchObject({
        href: `${reportsTabPath}/license-compliance`,
        text: 'View report',
      });
    });

    it('onClick navigates to the reports tab without page reload', async () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

      createComponent();

      await waitForPromises();

      const pushStateSpy = jest.spyOn(window.history, 'pushState');
      const dispatchEventSpy = jest.spyOn(window, 'dispatchEvent');

      const actionButtons = findWidget().props('actionButtons');
      const event = { preventDefault: jest.fn() };
      actionButtons[0].onClick(actionButtons[0], event);

      expect(event.preventDefault).toHaveBeenCalled();
      expect(pushStateSpy).toHaveBeenCalledWith(null, null, `${reportsTabPath}/license-compliance`);
      expect(dispatchEventSpy).toHaveBeenCalledWith(expect.any(PopStateEvent));
    });

    describe('tracking', () => {
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      it('onClick tracks click_view_report_on_merge_request_widget', async () => {
        mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

        createComponent();
        await waitForPromises();

        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        const actionButtons = findWidget().props('actionButtons');
        const event = { preventDefault: jest.fn() };
        actionButtons[0].onClick(actionButtons[0], event);

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_view_report_on_merge_request_widget',
          { label: 'license_compliance' },
          undefined,
        );
      });
    });

    it('should not be collapsible', async () => {
      mockApi(licenseComparisonPathCollapsed, HTTP_STATUS_OK, licenseComplianceNewLicenses);

      createComponent();

      await waitForPromises();

      expect(findWidget().props('isCollapsible')).toBe(false);
    });
  });
});
