import { GlButton } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import { setActivePinia, createPinia } from 'pinia';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import PdfExportButton from 'ee/security_dashboard/components/shared/pdf_export_button_new.vue';
import { useChartExportStore } from 'ee/security_dashboard/stores/chart_export_store';
import { TEST_HOST } from 'helpers/test_constants';
import axios from '~/lib/utils/axios_utils';
import {
  HTTP_STATUS_NOT_FOUND,
  HTTP_STATUS_OK,
  HTTP_STATUS_TOO_MANY_REQUESTS,
} from '~/lib/utils/http_status';

jest.mock('~/alert');

const vulnerabilitiesPdfExportEndpoint = `${TEST_HOST}/vulnerability_exports?export_format=pdf`;
const dashboardType = 'project';

describe('PdfExportButton', () => {
  let wrapper;
  let mock;

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(PdfExportButton, {
      provide: {
        vulnerabilitiesPdfExportEndpoint,
        dashboardType,
      },
      propsData: {
        ...props,
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  const mockAsyncExportRequest = (status = HTTP_STATUS_OK, response = {}) => {
    mock.onPost(vulnerabilitiesPdfExportEndpoint).reply(status, response);
  };

  const expectButtonToBeLoading = (isLoading) => {
    expect(findButton().props()).toMatchObject({
      loading: isLoading,
      icon: isLoading ? '' : 'export',
    });
  };

  beforeEach(() => {
    setActivePinia(createPinia());
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  it('renders the button', () => {
    createWrapper();
    expect(findButton().props()).toMatchObject({
      category: 'secondary',
      icon: 'export',
    });
    expect(findButton().attributes('title')).toBe('Export as PDF');
    expect(findButton().text()).toBe('Export');
  });

  it('toggles loading and icon correctly during async export', async () => {
    createWrapper();
    mockAsyncExportRequest();

    expectButtonToBeLoading(false);

    findButton().vm.$emit('click');
    await nextTick();
    expectButtonToBeLoading(true);

    await axios.waitForAll();
    expectButtonToBeLoading(false);
  });

  it('sends the export request and shows the success alert on click', async () => {
    createWrapper();
    mockAsyncExportRequest();

    expect(createAlert).not.toHaveBeenCalled();
    findButton().vm.$emit('click');
    await axios.waitForAll();

    expect(mock.history.post[0].data).toBe(
      JSON.stringify({ report_data: { dashboard_type: dashboardType }, export_format: 'pdf' }),
    );
    expect(createAlert).toHaveBeenCalledWith({
      message:
        'Report export in progress. After the report is generated, an email will be sent with the download link.',
      variant: 'info',
      dismissible: true,
    });
  });

  it('shows error alert when export fails', async () => {
    createWrapper();
    mockAsyncExportRequest(HTTP_STATUS_NOT_FOUND);

    findButton().vm.$emit('click');
    await axios.waitForAll();

    expect(createAlert).toHaveBeenCalledWith({
      message: 'There was an error while generating the report.',
      variant: 'danger',
      dismissible: true,
    });
  });

  it('shows error alert when export is rate limited (HTTP_STATUS_TOO_MANY_REQUESTS)', async () => {
    const serverMessage =
      'Export already in progress. Please retry after the current export completes.';

    createWrapper();
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

  describe('store integration', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('includes chart data in the export request', async () => {
      const store = useChartExportStore();
      const mockChartFn1 = jest.fn().mockResolvedValue('chart-1-svg');
      const mockChartFn2 = jest.fn().mockResolvedValue('chart-2-svg');
      store.register('chart-1', mockChartFn1);
      store.register('chart-2', mockChartFn2);

      mockAsyncExportRequest();

      findButton().vm.$emit('click');
      await axios.waitForAll();

      const requestData = JSON.parse(mock.history.post[0].data);
      expect(requestData.report_data['chart-1']).toBe('chart-1-svg');
      expect(requestData.report_data['chart-2']).toBe('chart-2-svg');
    });

    it('handles store errors gracefully', async () => {
      useChartExportStore().register(
        'test-chart',
        jest.fn().mockRejectedValue(new Error('Chart export failed')),
      );

      findButton().vm.$emit('click');

      await nextTick();

      expect(findButton().props('loading')).toBe(true);

      await axios.waitForAll();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error while generating the report.',
        variant: 'danger',
        dismissible: true,
      });

      expect(findButton().props('loading')).toBe(false);
    });

    describe('severity count aggregation', () => {
      const severities = ['critical', 'high', 'medium', 'low', 'info', 'unknown'];

      it('includes vulnerabilities_by_severity_count as a nested object in the request', async () => {
        const store = useChartExportStore();
        const severityData = {};

        severities.forEach((severity) => {
          const data = { count: 7, medianAge: 30, color: '#test-color' };
          severityData[severity] = data;
          store.registerNested('vulnerabilities_by_severity_count', severity, () => data);
        });

        mockAsyncExportRequest();
        findButton().vm.$emit('click');
        await axios.waitForAll();

        const requestData = JSON.parse(mock.history.post[0].data);
        expect(requestData.report_data.vulnerabilities_by_severity_count).toEqual(severityData);
      });

      it('does not include vulnerabilities_by_severity_count when no severity keys are registered', async () => {
        mockAsyncExportRequest();
        findButton().vm.$emit('click');
        await axios.waitForAll();

        const requestData = JSON.parse(mock.history.post[0].data);
        expect(requestData.report_data).not.toHaveProperty('vulnerabilities_by_severity_count');
      });

      it('only includes registered severity keys', async () => {
        const store = useChartExportStore();
        const criticalData = { count: 3, medianAge: 20 };
        store.registerNested('vulnerabilities_by_severity_count', 'critical', () => criticalData);

        mockAsyncExportRequest();
        findButton().vm.$emit('click');
        await axios.waitForAll();

        const requestData = JSON.parse(mock.history.post[0].data);
        expect(requestData.report_data.vulnerabilities_by_severity_count).toEqual({
          critical: criticalData,
        });
        expect(requestData.report_data.vulnerabilities_by_severity_count).not.toHaveProperty(
          'high',
        );
      });
    });
  });
});
