import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ListIndex from 'ee/metrics/list_index.vue';
import MetricsList from 'ee/metrics/list/metrics_list.vue';
import * as observabilityClient from '~/observability/client';
import { createMockClient, mockApiConfig } from 'helpers/mock_observability_client';

describe('ListIndex', () => {
  const props = {
    apiConfig: {
      ...mockApiConfig,
    },
  };

  let wrapper;

  const observabilityClientMock = createMockClient();

  const mountComponent = () => {
    wrapper = shallowMountExtended(ListIndex, {
      propsData: props,
    });
  };

  beforeEach(() => {
    jest.spyOn(observabilityClient, 'buildClient').mockReturnValue(observabilityClientMock);

    mountComponent();
  });

  it('renders MetricsList component', () => {
    expect(wrapper.findComponent(MetricsList).exists()).toBe(true);
  });

  it('builds the observability client', () => {
    expect(observabilityClient.buildClient).toHaveBeenCalledWith(props.apiConfig);
    expect(wrapper.findComponent(MetricsList).props('observabilityClient')).toBe(
      observabilityClientMock,
    );
  });
});
