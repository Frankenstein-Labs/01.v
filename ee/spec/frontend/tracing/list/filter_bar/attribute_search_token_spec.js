import AttributeSearchToken from 'ee/tracing/list/filter_bar/attribute_search_token.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TracingBaseSearchToken from 'ee/tracing/list/filter_bar/tracing_base_search_token.vue';

describe('AttributeSearchToken', () => {
  let wrapper;

  const findBaseToken = () => wrapper.findComponent(TracingBaseSearchToken);

  beforeEach(() => {
    wrapper = shallowMountExtended(AttributeSearchToken, {
      propsData: {
        active: true,
        config: {
          title: 'test-title',
        },
        value: { data: '' },
        currentValue: [],
      },
    });
  });

  it('renders a BaseToken', () => {
    const base = findBaseToken();
    expect(base.exists()).toBe(true);
    expect(base.props('active')).toEqual(wrapper.props('active'));
    expect(base.props('value')).toEqual(wrapper.props('value'));
    expect(base.props('config')).toEqual(wrapper.props('config'));
  });
});
