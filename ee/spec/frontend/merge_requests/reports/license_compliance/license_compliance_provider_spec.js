import MockAdapter from 'axios-mock-adapter';
import { mount } from '@vue/test-utils';
import waitForPromises from 'helpers/wait_for_promises';
import axios from '~/lib/utils/axios_utils';
import {
  HTTP_STATUS_OK,
  HTTP_STATUS_BAD_REQUEST,
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
} from '~/lib/utils/http_status';
import Poll from '~/lib/utils/poll';
import LicenseComplianceProvider from 'ee/merge_requests/reports/license_compliance/license_compliance_provider.vue';
import {
  licenseComplianceSuccessExpanded,
  licenses,
} from 'ee_jest/vue_merge_request_widget/widgets/license_compliance/mock_data';

describe('LicenseComplianceProvider', () => {
  let wrapper;
  let mock;

  const DEFAULT_MR_PROPS = {
    licenseCompliance: {
      license_scanning_comparison_path: '/license_scanning_reports',
      license_scanning: { full_report_path: '/full-report' },
    },
  };

  const emptyResponse = {
    new_licenses: [],
    existing_licenses: [],
    removed_licenses: [],
  };

  const responseWithExistingLicenses = {
    new_licenses: licenses,
    existing_licenses: [licenses[0], licenses[2]],
    removed_licenses: [],
  };

  const responseWithNoDeniedLicenses = {
    new_licenses: [licenses[0], licenses[2]],
    existing_licenses: [],
    removed_licenses: [],
  };

  const InjectedChild = {
    inject: [
      'newLicensesCount',
      'existingLicensesCount',
      'hasDeniedLicense',
      'hasApprovalRequired',
      'isLicenseComplianceLoading',
      'statusIconName',
      'statusMessage',
      'errorMessage',
      'sections',
      'loadingMessage',
    ],
    template: `
      <div data-testid="child">
        <span data-testid="is-loading">{{ isLicenseComplianceLoading }}</span>
        <span data-testid="new-licenses">{{ newLicensesCount }}</span>
        <span data-testid="existing-licenses">{{ existingLicensesCount }}</span>
        <span data-testid="has-denied-license">{{ hasDeniedLicense }}</span>
        <span data-testid="has-approval-required">{{ hasApprovalRequired }}</span>
        <span data-testid="status-icon-name">{{ statusIconName }}</span>
        <span data-testid="status-message">{{ statusMessage }}</span>
        <span data-testid="error-message">{{ errorMessage }}</span>
        <span data-testid="sections-count">{{ sections.length }}</span>
        <span data-testid="sections-json">{{ JSON.stringify(sections) }}</span>
        <span data-testid="loading-message">{{ loadingMessage }}</span>
      </div>
    `,
  };

  const mockApi = (statusCode, data) => {
    const licenseComplianceEndpoint =
      DEFAULT_MR_PROPS.licenseCompliance.license_scanning_comparison_path;
    mock.onGet(licenseComplianceEndpoint).reply(statusCode, data, {});
  };

  const createComponent = ({ mr = DEFAULT_MR_PROPS } = {}) => {
    wrapper = mount(LicenseComplianceProvider, {
      propsData: { mr },
      slots: {
        default: InjectedChild,
      },
    });
  };

  const findByTestId = (testId) => wrapper.find(`[data-testid="${testId}"]`);
  const getTextByTestId = (testId) => findByTestId(testId).text();
  const findIsLoading = () => getTextByTestId('is-loading');
  const findLoadingMessage = () => getTextByTestId('loading-message');
  const findErrorMessage = () => getTextByTestId('error-message');
  const findStatusMessage = () => getTextByTestId('status-message');
  const findStatusIconName = () => getTextByTestId('status-icon-name');
  const findNewLicensesCount = () => getTextByTestId('new-licenses');
  const findExistingLicensesCount = () => getTextByTestId('existing-licenses');
  const findHasDeniedLicense = () => getTextByTestId('has-denied-license');
  const findHasApprovalRequired = () => getTextByTestId('has-approval-required');
  const findSectionsCount = () => getTextByTestId('sections-count');
  const findSections = () => JSON.parse(getTextByTestId('sections-json'));

  beforeEach(() => {
    mock = new MockAdapter(axios);
    mockApi(HTTP_STATUS_OK, licenseComplianceSuccessExpanded);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('rendering', () => {
    it('renders slot content', async () => {
      createComponent();
      await waitForPromises();

      expect(findByTestId('child').exists()).toBe(true);
    });
  });

  describe('data fetching', () => {
    it('does not fetch when license compliance endpoint is missing', async () => {
      createComponent({ mr: { licenseCompliance: {} } });
      await waitForPromises();

      expect(mock.history.get).toHaveLength(0);
      expect(findStatusMessage()).toBe('No license compliance enabled.');
      expect(findErrorMessage()).toBe('');
      expect(findStatusIconName()).toBe('warning');
      expect(findIsLoading()).toBe('false');
    });

    describe('loading', () => {
      describe('initial fetch', () => {
        it('shows parsing message while fetch is in progress', () => {
          createComponent();

          expect(findLoadingMessage()).toBe(
            'License Compliance test metrics results are being parsed',
          );
        });

        it('shows no message after fetch completes', async () => {
          createComponent();
          await waitForPromises();

          expect(findLoadingMessage()).toBe('');
        });

        it('shows no message when the request fails', async () => {
          mockApi(HTTP_STATUS_INTERNAL_SERVER_ERROR);
          createComponent();
          await waitForPromises();

          expect(findLoadingMessage()).toBe('');
        });
      });
    });

    describe('response data', () => {
      it('provides new license count from response', async () => {
        createComponent();
        await waitForPromises();

        expect(findNewLicensesCount()).toBe(
          String(licenseComplianceSuccessExpanded.new_licenses.length),
        );
      });

      it('provides existing license count', async () => {
        mockApi(HTTP_STATUS_OK, responseWithExistingLicenses);
        createComponent();
        await waitForPromises();

        expect(findExistingLicensesCount()).toBe(
          String(responseWithExistingLicenses.existing_licenses.length),
        );
      });

      it('provides zero counts when no licenses', async () => {
        mockApi(HTTP_STATUS_OK, emptyResponse);
        createComponent();
        await waitForPromises();

        expect(findNewLicensesCount()).toBe('0');
        expect(findExistingLicensesCount()).toBe('0');
      });

      describe('hasDeniedLicense', () => {
        it('is true when has_denied_licenses is true in response', async () => {
          createComponent();
          await waitForPromises();

          expect(findHasDeniedLicense()).toBe('true');
        });

        it('is false when has_denied_licenses is false in response', async () => {
          mockApi(HTTP_STATUS_OK, {
            ...licenseComplianceSuccessExpanded,
            has_denied_licenses: false,
          });
          createComponent();
          await waitForPromises();

          expect(findHasDeniedLicense()).toBe('false');
        });
      });

      describe('hasApprovalRequired', () => {
        it('is false when approval_required is not in response', async () => {
          createComponent();
          await waitForPromises();

          expect(findHasApprovalRequired()).toBe('false');
        });

        it('is true when approval_required is true in response', async () => {
          mockApi(HTTP_STATUS_OK, { ...licenseComplianceSuccessExpanded, approval_required: true });
          createComponent();
          await waitForPromises();

          expect(findHasApprovalRequired()).toBe('true');
        });
      });
    });

    describe('error handling', () => {
      it('sets error message when fetch fails with no status_reason', async () => {
        mockApi(HTTP_STATUS_INTERNAL_SERVER_ERROR);
        createComponent();
        await waitForPromises();

        expect(findErrorMessage()).toBe('License Compliance failed loading results');
        expect(findStatusMessage()).toBe('');
      });

      it('sets status message when fetch fails with status_reason', async () => {
        const statusReason = 'This merge request does not have license scanning reports.';

        mockApi(HTTP_STATUS_BAD_REQUEST, { status_reason: statusReason });
        createComponent();
        await waitForPromises();

        expect(findStatusMessage()).toBe(statusReason);
        expect(findErrorMessage()).toBe('');
      });

      it('has no error or status message on success', async () => {
        createComponent();
        await waitForPromises();

        expect(findErrorMessage()).toBe('');
        expect(findStatusMessage()).toBe('');
      });
    });

    describe('statusIconName', () => {
      it('returns warning when fetch fails with status_reason', async () => {
        mockApi(HTTP_STATUS_BAD_REQUEST, {
          status_reason: 'Some status reason',
        });
        createComponent();
        await waitForPromises();

        expect(findStatusIconName()).toBe('warning');
      });

      it('returns error when fetch fails without status_reason', async () => {
        mockApi(HTTP_STATUS_INTERNAL_SERVER_ERROR);
        createComponent();
        await waitForPromises();

        expect(findStatusIconName()).toBe('error');
      });

      it('returns warning when new licenses exist', async () => {
        createComponent();
        await waitForPromises();

        expect(findStatusIconName()).toBe('warning');
      });

      it('returns success when no new licenses', async () => {
        mockApi(HTTP_STATUS_OK, emptyResponse);
        createComponent();
        await waitForPromises();

        expect(findStatusIconName()).toBe('success');
      });
    });

    describe('sections', () => {
      it('provides sections transformed from response data', async () => {
        createComponent();
        await waitForPromises();

        const sections = findSections();

        expect(sections).toHaveLength(3);
        expect(sections[0].header).toBe('Denied');
        expect(sections[1].header).toBe('Uncategorized');
        expect(sections[2].header).toBe('Allowed');
      });

      it('provides correct children in each section', async () => {
        createComponent();
        await waitForPromises();

        const sections = findSections();

        expect(sections[0].children).toHaveLength(1);
        expect(sections[0].children[0].link.text).toBe('Apache License 2.0');
        expect(sections[1].children).toHaveLength(1);
        expect(sections[1].children[0].link.text).toBe('Academic Free License v2.1');
        expect(sections[2].children).toHaveLength(1);
        expect(sections[2].children[0].link.text).toBe('ISC License');
      });

      it('provides empty sections when no licenses', async () => {
        mockApi(HTTP_STATUS_OK, emptyResponse);
        createComponent();
        await waitForPromises();

        expect(findSectionsCount()).toBe('0');
      });
    });

    describe('polling', () => {
      it('stops the poll when data is resolved', async () => {
        const stopSpy = jest.spyOn(Poll.prototype, 'stop');

        createComponent();
        await waitForPromises();

        expect(stopSpy).toHaveBeenCalled();
        expect(findSectionsCount()).toBe('3');
      });

      it('provides empty sections when fetch fails', async () => {
        mockApi(HTTP_STATUS_INTERNAL_SERVER_ERROR);
        createComponent();
        await waitForPromises();

        expect(findSectionsCount()).toBe('0');
      });

      it('provides sections with only existing statuses', async () => {
        mockApi(HTTP_STATUS_OK, responseWithNoDeniedLicenses);
        createComponent();
        await waitForPromises();

        const sections = findSections();

        expect(sections).toHaveLength(2);
        expect(sections[0].header).toBe('Uncategorized');
        expect(sections[1].header).toBe('Allowed');
      });
    });
  });
});
