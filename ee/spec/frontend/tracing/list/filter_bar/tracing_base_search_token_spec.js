import { GlFilteredSearchToken } from '@gitlab/ui';
import {
  SERVICE_NAME_FILTER_TOKEN_TYPE,
  OPERATION_FILTER_TOKEN_TYPE,
} from 'ee/tracing/list/filter_bar/filters';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TracingBaseSearchToken from 'ee/tracing/list/filter_bar/tracing_base_search_token.vue';

describe('AttributeSearchToken', () => {
  let wrapper;

  const findBaseToken = () => wrapper.findComponent(GlFilteredSearchToken);

  const defaultProps = {
    active: true,
    config: {
      title: 'test-title',
      operators: [{ value: '=' }],
    },
    value: { data: '' },
    currentValue: [],
  };

  const mount = (propsData = defaultProps) => {
    wrapper = shallowMountExtended(TracingBaseSearchToken, {
      propsData,
    });
  };
  beforeEach(() => {
    mount();
  });

  it('renders a BaseToken', () => {
    const base = findBaseToken();
    expect(base.exists()).toBe(true);
    expect(base.props('active')).toEqual(wrapper.props('active'));
    expect(base.props('value')).toEqual(wrapper.props('value'));
    expect(base.props('config')).toEqual(wrapper.props('config'));
  });

  it('sets the token to view-only if the operation service token are not set', () => {
    mount({ ...defaultProps, currentValue: [{ type: OPERATION_FILTER_TOKEN_TYPE }] });
    expect(findBaseToken().props('viewOnly')).toBe(true);
  });

  it('sets the token to view-only if the service token are not set', () => {
    mount({ ...defaultProps, currentValue: [{ type: SERVICE_NAME_FILTER_TOKEN_TYPE }] });
    expect(findBaseToken().props('viewOnly')).toBe(true);
  });

  it('shows a dropdown text when the required filters are missing', () => {
    mount({ ...defaultProps, currentValue: [] });
    expect(findBaseToken().text()).toContain('You must select a Service and Operation first.');
  });

  it('does not set the token to view-only if the service and operation tokens are set', () => {
    mount({
      ...defaultProps,
      currentValue: [
        { type: SERVICE_NAME_FILTER_TOKEN_TYPE },
        { type: OPERATION_FILTER_TOKEN_TYPE },
      ],
    });
    expect(findBaseToken().props('viewOnly')).toBe(false);
  });

  it('does not show a dropdown text when the required filters are there', () => {
    mount({
      ...defaultProps,
      currentValue: [
        { type: SERVICE_NAME_FILTER_TOKEN_TYPE },
        { type: OPERATION_FILTER_TOKEN_TYPE },
      ],
    });
    expect(findBaseToken().text()).not.toContain('You must select a Service and Operation first.');
  });

  it('filters operators, if there are multiple and service and operation tokens are set', () => {
    mount({
      ...defaultProps,
      config: {
        title: 'test-title',
        operators: [{ value: '=' }, { value: '!=' }],
      },
    });

    expect(findBaseToken().props('config')).toEqual({
      title: 'test-title',
      operators: [{ value: '=' }],
    });
  });

  it('does not filter operators, if there are multiple and service and operation tokens are set', () => {
    mount({
      ...defaultProps,
      config: {
        title: 'test-title',
        operators: [{ value: '=' }, { value: '!=' }],
      },
      currentValue: [
        { type: SERVICE_NAME_FILTER_TOKEN_TYPE },
        { type: OPERATION_FILTER_TOKEN_TYPE },
      ],
    });

    expect(findBaseToken().props('config')).toEqual({
      title: 'test-title',
      operators: [{ value: '=' }, { value: '!=' }],
    });
  });
});
