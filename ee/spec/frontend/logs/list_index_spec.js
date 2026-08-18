import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ListIndex from 'ee/logs/list_index.vue';
import LogsList from 'ee/logs/list/logs_list.vue';
import * as observabilityClient from '~/observability/client';
import { createMockClient, mockApiConfig } from 'helpers/mock_observability_client';

describe('ListIndex', () => {
  const props = {
    apiConfig: { ...mockApiConfig },
    tracingIndexUrl: 'https://example.com/tracing/index',
    createIssueUrl: 'https://example.com/issues/new',
    projectFullPath: 'foo/bar',
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

  it('renders the logs list', () => {
    const list = wrapper.findComponent(LogsList);
    expect(list.exists()).toBe(true);
    expect(list.props('tracingIndexUrl')).toBe(props.tracingIndexUrl);
    expect(list.props('createIssueUrl')).toBe(props.createIssueUrl);
    expect(list.props('projectFullPath')).toBe(props.projectFullPath);
  });

  it('builds the observability client', () => {
    expect(observabilityClient.buildClient).toHaveBeenCalledWith(props.apiConfig);
    expect(wrapper.findComponent(LogsList).props('observabilityClient')).toBe(
      observabilityClientMock,
    );
  });
});
