import MetricsDetails from 'ee/metrics/details/metrics_details.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DetailsIndex from 'ee/metrics/details_index.vue';
import * as observabilityClient from '~/observability/client';
import { createMockClient, mockApiConfig } from 'helpers/mock_observability_client';

describe('DetailsIndex', () => {
  const props = {
    metricId: 'test.metric',
    metricType: 'a-type',
    createIssueUrl: 'https://example.com/new/issue',
    tracingIndexUrl: 'https://example.com/traces/index',
    apiConfig: { ...mockApiConfig },
    projectFullPath: 'foo/bar',
    projectId: 1234,
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

  it('renders MetricsDetails component', () => {
    const detailsCmp = wrapper.findComponent(MetricsDetails);
    expect(detailsCmp.exists()).toBe(true);
    expect(detailsCmp.props('metricId')).toBe(props.metricId);
    expect(detailsCmp.props('metricType')).toBe(props.metricType);
    expect(detailsCmp.props('createIssueUrl')).toBe(props.createIssueUrl);
    expect(detailsCmp.props('projectFullPath')).toBe(props.projectFullPath);
    expect(detailsCmp.props('projectId')).toBe(props.projectId);
    expect(detailsCmp.props('tracingIndexUrl')).toBe(props.tracingIndexUrl);
  });

  it('builds the observability client', () => {
    expect(observabilityClient.buildClient).toHaveBeenCalledWith(props.apiConfig);
    expect(wrapper.findComponent(MetricsDetails).props('observabilityClient')).toBe(
      observabilityClientMock,
    );
  });
});
