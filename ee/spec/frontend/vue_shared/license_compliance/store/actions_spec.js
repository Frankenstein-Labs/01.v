import MockAdapter from 'axios-mock-adapter';
import { LICENSE_APPROVAL_STATUS } from 'ee/vue_shared/license_compliance/constants';
import * as actions from 'ee/vue_shared/license_compliance/store/actions';
import * as mutationTypes from 'ee/vue_shared/license_compliance/store/mutation_types';
import createState from 'ee/vue_shared/license_compliance/store/state';
import testAction from 'helpers/vuex_action_helper';
import { TEST_HOST } from 'spec/test_constants';
import axios from '~/lib/utils/axios_utils';
import {
  HTTP_STATUS_BAD_REQUEST,
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';
import { allowedLicense } from '../mock_data';

describe('License store actions', () => {
  const apiUrlManageLicenses = `${TEST_HOST}/licenses/management`;
  const approvalsApiPath = `${TEST_HOST}/approvalsApiPath`;
  const licensesApiPath = `${TEST_HOST}/licensesApiPath`;

  let axiosMock;
  let state;

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
    state = {
      ...createState(),
      apiUrlManageLicenses,
      approvalsApiPath,
    };
  });

  afterEach(() => {
    axiosMock.restore();
  });

  describe('setAPISettings', () => {
    it('commits SET_API_SETTINGS', async () => {
      const payload = { apiUrlManageLicenses };
      await testAction(
        actions.setAPISettings,
        payload,
        state,
        [{ type: mutationTypes.SET_API_SETTINGS, payload }],
        [],
      );
    });
  });

  describe('requestManagedLicenses', () => {
    it('commits REQUEST_MANAGED_LICENSES', async () => {
      await testAction(
        actions.requestManagedLicenses,
        null,
        state,
        [{ type: mutationTypes.REQUEST_MANAGED_LICENSES }],
        [],
      );
    });
  });

  describe('receiveManagedLicensesSuccess', () => {
    it('commits RECEIVE_MANAGED_LICENSES_SUCCESS', async () => {
      const payload = [allowedLicense];
      await testAction(
        actions.receiveManagedLicensesSuccess,
        payload,
        state,
        [{ type: mutationTypes.RECEIVE_MANAGED_LICENSES_SUCCESS, payload }],
        [],
      );
    });
  });

  describe('receiveManagedLicensesError', () => {
    it('commits RECEIVE_MANAGED_LICENSES_ERROR', async () => {
      const error = new Error('Test');
      await testAction(
        actions.receiveManagedLicensesError,
        error,
        state,
        [{ type: mutationTypes.RECEIVE_MANAGED_LICENSES_ERROR }],
        [],
      );
    });
  });

  describe('fetchManagedLicenses', () => {
    let endpointMock;

    beforeEach(() => {
      endpointMock = axiosMock.onGet(apiUrlManageLicenses, { params: { per_page: 100 } });
    });

    it('dispatches requestManagedLicenses and receiveManagedLicensesSuccess for successful response', async () => {
      const payload = [{ name: 'foo', approval_status: LICENSE_APPROVAL_STATUS.DENIED }];
      endpointMock.replyOnce(() => [HTTP_STATUS_OK, payload]);

      await testAction(
        actions.fetchManagedLicenses,
        null,
        state,
        [],
        [{ type: 'requestManagedLicenses' }, { type: 'receiveManagedLicensesSuccess', payload }],
      );
    });

    it('dispatches requestManagedLicenses and receiveManagedLicensesError for error response', async () => {
      endpointMock.replyOnce(() => [HTTP_STATUS_INTERNAL_SERVER_ERROR, '']);

      await testAction(
        actions.fetchManagedLicenses,
        null,
        state,
        [],
        [{ type: 'requestManagedLicenses' }, { type: 'receiveManagedLicensesError' }],
      );
    });
  });

  describe('requestParsedLicenseReport', () => {
    it(`should commit ${mutationTypes.REQUEST_PARSED_LICENSE_REPORT}`, async () => {
      await testAction(
        actions.requestParsedLicenseReport,
        null,
        state,
        [{ type: mutationTypes.REQUEST_PARSED_LICENSE_REPORT }],
        [],
      );
    });
  });

  describe('receiveParsedLicenseReportSuccess', () => {
    it(`should commit ${mutationTypes.RECEIVE_PARSED_LICENSE_REPORT_SUCCESS} with the correct payload`, async () => {
      const payload = { newLicenses: [{ name: 'foo' }] };

      await testAction(
        actions.receiveParsedLicenseReportSuccess,
        payload,
        state,
        [{ type: mutationTypes.RECEIVE_PARSED_LICENSE_REPORT_SUCCESS, payload }],
        [],
      );
    });
  });

  describe('receiveParsedLicenseReportError', () => {
    it(`should commit ${mutationTypes.RECEIVE_PARSED_LICENSE_REPORT_ERROR}`, async () => {
      const payload = new Error('Test');

      await testAction(
        actions.receiveParsedLicenseReportError,
        payload,
        state,
        [{ type: mutationTypes.RECEIVE_PARSED_LICENSE_REPORT_ERROR, payload }],
        [],
      );
    });
  });

  describe('fetchParsedLicenseReport', () => {
    let licensesApiMock;
    let rawLicenseReport;

    beforeEach(() => {
      licensesApiMock = axiosMock.onGet(licensesApiPath);
      state = {
        ...createState(),
        licensesApiPath,
      };
    });

    describe('pipeline reports', () => {
      beforeEach(() => {
        rawLicenseReport = [
          {
            name: 'MIT',
            classification: { id: 2, approval_status: LICENSE_APPROVAL_STATUS.DENIED, name: 'MIT' },
            dependencies: [{ name: 'vue' }],
            count: 1,
            url: 'http://opensource.org/licenses/mit-license',
          },
        ];
      });

      it('should fetch, parse, and dispatch the new licenses on a successful request', async () => {
        licensesApiMock.replyOnce(() => [HTTP_STATUS_OK, rawLicenseReport]);

        const parsedLicenses = {
          existingLicenses: [],
          newLicenses: [
            {
              ...rawLicenseReport[0],
              id: 2,
              approvalStatus: LICENSE_APPROVAL_STATUS.DENIED,
              packages: [{ name: 'vue' }],
              status: 'failed',
            },
          ],
        };

        await testAction(
          actions.fetchParsedLicenseReport,
          null,
          state,
          [],
          [
            { type: 'requestParsedLicenseReport' },
            { type: 'receiveParsedLicenseReportSuccess', payload: parsedLicenses },
          ],
        );
      });

      it('should send an error on an unsuccessful request', async () => {
        licensesApiMock.replyOnce(HTTP_STATUS_BAD_REQUEST);

        await testAction(
          actions.fetchParsedLicenseReport,
          null,
          state,
          [],
          [
            { type: 'requestParsedLicenseReport' },
            { type: 'receiveParsedLicenseReportError', payload: expect.any(Error) },
          ],
        );
      });
    });

    describe('MR widget reports', () => {
      beforeEach(() => {
        rawLicenseReport = {
          new_licenses: [
            {
              name: 'Apache 2.0',
              classification: {
                id: 1,
                approval_status: LICENSE_APPROVAL_STATUS.ALLOWED,
                name: 'Apache 2.0',
              },
              dependencies: [{ name: 'echarts' }],
              count: 1,
              url: 'http://www.apache.org/licenses/LICENSE-2.0.txt',
            },
            {
              name: 'New BSD',
              classification: { id: 3, approval_status: 'unclassified', name: 'New BSD' },
              dependencies: [{ name: 'zrender' }],
              count: 1,
              url: 'http://opensource.org/licenses/BSD-3-Clause',
            },
          ],
          existing_licenses: [
            {
              name: 'MIT',
              classification: {
                id: 2,
                approval_status: LICENSE_APPROVAL_STATUS.DENIED,
                name: 'MIT',
              },
              dependencies: [{ name: 'vue' }],
              count: 1,
              url: 'http://opensource.org/licenses/mit-license',
            },
          ],
          removed_licenses: [],
        };
      });

      it('should fetch, parse, and dispatch the new licenses on a successful request', async () => {
        licensesApiMock.replyOnce(() => [HTTP_STATUS_OK, rawLicenseReport]);

        const parsedLicenses = {
          existingLicenses: [
            {
              ...rawLicenseReport.existing_licenses[0],
              id: 2,
              approvalStatus: LICENSE_APPROVAL_STATUS.DENIED,
              packages: [{ name: 'vue' }],
              status: 'failed',
            },
          ],
          newLicenses: [
            {
              ...rawLicenseReport.new_licenses[0],
              id: 1,
              approvalStatus: LICENSE_APPROVAL_STATUS.ALLOWED,
              packages: [{ name: 'echarts' }],
              status: 'success',
            },
            {
              ...rawLicenseReport.new_licenses[1],
              id: 3,
              approvalStatus: 'unclassified',
              packages: [{ name: 'zrender' }],
              status: 'neutral',
            },
          ],
        };

        await testAction(
          actions.fetchParsedLicenseReport,
          null,
          state,
          [],
          [
            { type: 'requestParsedLicenseReport' },
            { type: 'receiveParsedLicenseReportSuccess', payload: parsedLicenses },
          ],
        );
      });
    });
  });
});
