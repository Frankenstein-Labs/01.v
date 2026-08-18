import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import CsvExportButton from 'ee/security_dashboard/components/shared/csv_export_button.vue';
import { filters as currentFilters } from 'ee/security_dashboard/components/shared/vulnerability_report/store';
import { TEST_HOST } from 'helpers/test_constants';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import {
  HTTP_STATUS_TOO_MANY_REQUESTS,
  HTTP_STATUS_NOT_FOUND,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';

jest.mock('~/alert');
jest.mock('~/lib/utils/downloader');
jest.mock('ee/security_dashboard/components/shared/vulnerability_report/store', () => ({
  filters: { value: {} },
}));

const vulnerabilitiesExportEndpoint = `${TEST_HOST}/vulnerability_findings.csv`;

describe('CsvExportButton', () => {
  let wrapper;
  let mock;

  const findButton = () => wrapper.findComponent(GlButton);

  const createComponent = () => {
    wrapper = shallowMount(CsvExportButton, {
      provide: {
        vulnerabilitiesExportEndpoint,
      },
    });
  };

  const mockAsyncExportRequest = (status = HTTP_STATUS_OK, response = {}) => {
    mock
      .onPost(vulnerabilitiesExportEndpoint, { send_email: true, filters: {} })
      .reply(status, response);
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('asynchronous export', () => {
    beforeEach(() => {
      createComponent();
    });

    it('sends async export request and shows success alert', async () => {
      mockAsyncExportRequest();

      findButton().vm.$emit('click');
      await axios.waitForAll();

      expect(mock.history.post[0].data).toEqual(JSON.stringify({ send_email: true, filters: {} }));
      expect(createAlert).toHaveBeenCalledWith({
        message:
          'Report export in progress. After the report is generated, an email will be sent with the download link.',
        variant: 'info',
        dismissible: true,
      });
    });

    it('shows error alert on running export and HTTP_STATUS_TOO_MANY_REQUESTS', async () => {
      const serverMessage =
        'Export already in progress. Please retry after the current export completes.';

      mockAsyncExportRequest(HTTP_STATUS_TOO_MANY_REQUESTS, {
        message: serverMessage,
      });

      findButton().vm.$emit('click');
      await axios.waitForAll();

      expect(createAlert).toHaveBeenCalledWith({
        message: serverMessage,
        variant: 'danger',
        dismissible: true,
      });
    });

    it('shows error alert when async export fails', async () => {
      mockAsyncExportRequest(HTTP_STATUS_NOT_FOUND);

      findButton().vm.$emit('click');
      await axios.waitForAll();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error while generating the report.',
        variant: 'danger',
        dismissible: true,
      });
    });
  });

  describe('filter parameters in export request', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes the currently applied filters as snake-cased parameters to the post request', async () => {
      currentFilters.value = {
        reportType: ['SAST'],
        scannerId: ['123'],
        state: 'CONFIRMED',
      };

      mock.onPost(vulnerabilitiesExportEndpoint).reply(HTTP_STATUS_OK);

      findButton().vm.$emit('click');
      await axios.waitForAll();

      const requestData = JSON.parse(mock.history.post[0].data);
      expect(requestData).toEqual({
        send_email: true,
        filters: {
          report_type: ['SAST'],
          scanner_id: ['123'],
          state: 'CONFIRMED',
        },
      });
    });

    it('sends only send_email when no filters are set', async () => {
      currentFilters.value = {};

      mock.onPost(vulnerabilitiesExportEndpoint).reply(HTTP_STATUS_OK);

      findButton().vm.$emit('click');
      await axios.waitForAll();

      const requestData = JSON.parse(mock.history.post[0].data);
      expect(requestData).toEqual({
        send_email: true,
        filters: {},
      });
    });
  });

  describe('button loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('toggles loading and icon correctly during async export', async () => {
      mockAsyncExportRequest();

      findButton().vm.$emit('click');
      await nextTick();

      expect(findButton().props()).toMatchObject({
        loading: true,
        icon: '',
      });

      await axios.waitForAll();

      expect(findButton().props()).toMatchObject({
        loading: false,
        icon: 'export',
      });
    });
  });

  describe('tooltip', () => {
    it('shows "Send as CSV to email" when async export is enabled', () => {
      createComponent();

      expect(findButton().attributes('title')).toBe('Send as CSV to email');
    });
  });

  describe('button disabled state', () => {
    it('enables the button when vulnerabilitiesExportEndpoint is provided', () => {
      createComponent();

      expect(findButton().props('disabled')).toBe(false);
    });

    it('disables the button when vulnerabilitiesExportEndpoint is not provided', () => {
      wrapper = shallowMount(CsvExportButton, {
        provide: {
          vulnerabilitiesExportEndpoint: null,
        },
      });

      expect(findButton().props('disabled')).toBe(true);
    });
  });
});
