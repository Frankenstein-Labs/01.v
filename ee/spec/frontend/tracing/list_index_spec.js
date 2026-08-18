import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ListIndex from 'ee/tracing/list_index.vue';
import TracingList from 'ee/tracing/list/tracing_list.vue';
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

  it('renders TracingList component', () => {
    expect(wrapper.findComponent(TracingList).exists()).toBe(true);
  });

  it('builds the observability client', () => {
    expect(observabilityClient.buildClient).toHaveBeenCalledWith(props.apiConfig);
    expect(wrapper.findComponent(TracingList).props('observabilityClient')).toBe(
      observabilityClientMock,
    );
  });
});
