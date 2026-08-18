import { GlButton } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createAlert } from '~/alert';
import PdfExportButton from 'ee/security_dashboard/components/shared/pdf_export_button.vue';
import { TEST_HOST } from 'helpers/test_constants';
import axios from '~/lib/utils/axios_utils';
import {
  HTTP_STATUS_NOT_FOUND,
  HTTP_STATUS_OK,
  HTTP_STATUS_TOO_MANY_REQUESTS,
} from '~/lib/utils/http_status';
import { PdfExportError } from 'ee/security_dashboard/helpers';

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
        getReportData: jest.fn().mockResolvedValue({}),
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

  it('shows error alert when charts are still loading', async () => {
    const errorMessage = 'Chart is still loading. Please try again after all data has loaded.';

    createWrapper({
      getReportData: jest.fn().mockImplementation(() => {
        throw new PdfExportError(errorMessage);
      }),
    });

    findButton().vm.$emit('click');
    await nextTick();

    expect(createAlert).toHaveBeenCalledWith({
      message: errorMessage,
      variant: 'danger',
      dismissible: true,
    });
  });
});
