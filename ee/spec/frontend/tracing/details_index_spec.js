import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DetailsIndex from 'ee/tracing/details_index.vue';
import TracingDetails from 'ee/tracing/details/tracing_details.vue';
import * as observabilityClient from '~/observability/client';
import { createMockClient, mockApiConfig } from 'helpers/mock_observability_client';

describe('DetailsIndex', () => {
  const props = {
    traceId: 'test-trace-id',
    tracingIndexUrl: 'https://example.com/tracing/index',
    logsIndexUrl: 'https://example.com/logs/index',
    metricsIndexUrl: 'https://example.com/metrics/index',
    createIssueUrl: 'https://example.com/issues/new',
    projectFullPath: 'foo/bar',
    apiConfig: {
      ...mockApiConfig,
    },
  };

  let wrapper;

  const observabilityClientMock = createMockClient();

  const mountComponent = () => {
    wrapper = shallowMountExtended(DetailsIndex, {
      propsData: props,
    });
  };

  beforeEach(() => {
    jest.spyOn(observabilityClient, 'buildClient').mockReturnValue(observabilityClientMock);

    mountComponent();
  });

  it('renders TracingDetails component', () => {
    const detailsCmp = wrapper.findComponent(TracingDetails);
    expect(detailsCmp.exists()).toBe(true);
    expect(detailsCmp.props('traceId')).toBe(props.traceId);
    expect(detailsCmp.props('logsIndexUrl')).toBe(props.logsIndexUrl);
    expect(detailsCmp.props('metricsIndexUrl')).toBe(props.metricsIndexUrl);
    expect(detailsCmp.props('createIssueUrl')).toBe(props.createIssueUrl);
    expect(detailsCmp.props('projectFullPath')).toBe(props.projectFullPath);
  });

  it('builds the observability client', () => {
    expect(observabilityClient.buildClient).toHaveBeenCalledWith(props.apiConfig);
    expect(wrapper.findComponent(TracingDetails).props('observabilityClient')).toBe(
      observabilityClientMock,
    );
  });
});
