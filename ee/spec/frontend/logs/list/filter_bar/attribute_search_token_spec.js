import AttributeSearchToken from 'ee/logs/list/filter_bar/attribute_search_token.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';

describe('AttributeSearchToken', () => {
  let wrapper;

  const findBaseToken = () => wrapper.findComponent(BaseToken);

  beforeEach(() => {
    wrapper = shallowMountExtended(AttributeSearchToken, {
      propsData: {
        active: true,
        config: {
          title: 'test-title',
        },
        value: { data: '' },
      },
    });
  });

  it('renders a BaseToken', () => {
    const base = findBaseToken();
    expect(base.exists()).toBe(true);
    expect(base.props('active')).toBe(wrapper.props('active'));
    expect(base.props('value')).toBe(wrapper.props('value'));
  });

  it('sets suggestionsDisabled in the config', () => {
    expect(findBaseToken().props('config')).toEqual({
      ...wrapper.props('config'),
      suggestionsDisabled: true,
    });
  });
});
