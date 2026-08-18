import { GlFilteredSearchToken, GlButton, GlLoadingIcon } from '@gitlab/ui';
import DateRangeFilter from '~/observability/components/date_range_filter.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MetricsFilteredSearch from 'ee/metrics/details/filter_bar/metrics_filtered_search.vue';
import GroupByFilter from 'ee/metrics/details/filter_bar/groupby_filter.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { OPERATORS_IS_NOT } from '~/vue_shared/components/filtered_search_bar/constants';
import { OPERATORS_LIKE_NOT } from '~/observability/constants';

describe('MetricsFilteredSearch', () => {
  let wrapper;

  const defaultSearchMetadata = {
    name: 'cpu_seconds_total',
    type: 'sum',
    description: 'some_description',
    last_ingested_at: 1705374438711900000,
    attribute_keys: ['attribute_one', 'attribute_two'],
    supported_aggregations: ['1m', '1h'],
    supported_functions: ['avg', 'sum', 'p50'],
    default_group_by_attributes: ['attribute_one'],
    default_group_by_function: 'avg',
  };

  const mount = (props = {}, searchMetadata = {}) => {
    wrapper = shallowMountExtended(MetricsFilteredSearch, {
      propsData: {
        searchMetadata: { ...defaultSearchMetadata, ...searchMetadata },
        ...props,
      },
    });
  };

  beforeEach(() => {
    mount();
  });

  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);
  const findDateRangeFilter = () => wrapper.findComponent(DateRangeFilter);
  const findGroupByFilter = () => wrapper.findComponent(GroupByFilter);
  const findSubmitButton = () => wrapper.findComponent(GlButton);

  const mockFilter = {
    id: 'namespace',
    type: 'a-token',
    value: { operator: 'is not', data: 'foo' },
  };

  it('renders the filtered search component with tokens based on attributes', () => {
    const filteredSeach = findFilteredSearchBar();
    expect(filteredSeach.exists()).toBe(true);
    const tokens = filteredSeach.props('tokens');
    expect(tokens).toHaveLength(defaultSearchMetadata.attribute_keys.length);
    tokens.forEach((token, index) => {
      expect(token.type).toBe(defaultSearchMetadata.attribute_keys[index]);
      expect(token.title).toBe(defaultSearchMetadata.attribute_keys[index]);
      expect(token.token).toBe(GlFilteredSearchToken);
      expect(token.operators).toEqual([...OPERATORS_IS_NOT, ...OPERATORS_LIKE_NOT]);
    });
  });

  it('renders the filtered search component with initial tokens', () => {
    const filters = [mockFilter];

    mount({ attributeFilters: filters });

    expect(findFilteredSearchBar().props('initialFilterValue')).toEqual(filters);
  });

  it('renders the date range picker dropdown with the selected date range', () => {
    const date = {
      endDate: new Date('2020-07-06T00:00:00.000Z'),
      startDarte: new Date('2020-07-05T23:00:00.000Z'),
      value: '1h',
    };

    mount({ dateRangeFilter: date });

    const dateRangesDropdown = findDateRangeFilter();
    expect(dateRangesDropdown.exists()).toBe(true);
    expect(dateRangesDropdown.props('selected')).toEqual(date);
  });

  it('renders a submit button', () => {
    mount();

    const button = findSubmitButton();
    expect(button.props('variant')).toBe('confirm');
    expect(button.text()).toBe('Search');
    expect(button.findComponent(GlLoadingIcon).exists()).toBe(false);
  });

  describe('cancel button', () => {
    beforeEach(() => {
      mount({ loading: true });
    });
    it('renders a cancel button when loading', () => {
      const button = findSubmitButton();
      expect(button.props('variant')).toBe('danger');
      expect(button.text()).toBe('Cancel');
      expect(button.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    it('emits cancel when clicked', () => {
      findSubmitButton().vm.$emit('click');
      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });

  describe('group-by filter', () => {
    it('renders the group-by filter with list of supported values from search metadata', () => {
      const groupBy = findGroupByFilter();
      expect(groupBy.exists()).toBe(true);
      expect(groupBy.props('supportedAttributes')).toEqual(defaultSearchMetadata.attribute_keys);
      expect(groupBy.props('supportedFunctions')).toEqual(
        defaultSearchMetadata.supported_functions,
      );
    });

    it('sets selectedFunction to searchMetadata.default_group_by_function', () => {
      expect(findGroupByFilter().props('selectedFunction')).toEqual(
        defaultSearchMetadata.default_group_by_function,
      );
    });

    it('ignores invalid default_group_by_function', () => {
      mount({
        searchMetadata: {
          ...defaultSearchMetadata,
          default_group_by_function: 'not-valid',
        },
      });

      expect(findGroupByFilter().props('selectedFunction')).toBeUndefined();
    });

    it('handles missing default_group_by_function', () => {
      mount({
        searchMetadata: {
          ...defaultSearchMetadata,
          default_group_by_function: undefined,
        },
      });

      expect(findGroupByFilter().props('selectedFunction')).toBeUndefined();
    });

    it('sets selectedAttributes to searchMetadata.default_group_by_attributes', () => {
      expect(findGroupByFilter().props('selectedAttributes')).toEqual(
        defaultSearchMetadata.default_group_by_attributes,
      );
    });

    it('ignores invalid default_group_by_attributes', () => {
      mount({
        searchMetadata: {
          ...defaultSearchMetadata,
          default_group_by_attributes: ['', ' ', 'not-valid'],
        },
      });

      expect(findGroupByFilter().props('selectedAttributes')).toEqual([]);
    });

    it('handles missing default_group_by_attributes', () => {
      mount({
        searchMetadata: {
          ...defaultSearchMetadata,
          default_group_by_attributes: undefined,
        },
      });

      expect(findGroupByFilter().props('selectedAttributes')).toEqual([]);
    });

    it(`handles default_group_by_attributes=['*']`, () => {
      mount({
        searchMetadata: {
          ...defaultSearchMetadata,
          default_group_by_attributes: ['*'],
        },
      });

      expect(findGroupByFilter().props('selectedAttributes')).toEqual([
        ...defaultSearchMetadata.attribute_keys,
      ]);
    });

    it('sets GroupByFilter selectedFunction prop to groupByFilter.func', () => {
      mount({
        groupByFilter: {
          func: 'sum',
        },
      });

      expect(findGroupByFilter().props('selectedFunction')).toEqual('sum');
    });

    it('sets GroupByFilter selectedAttributes prop to groupByFilter.attributes', () => {
      mount({
        groupByFilter: {
          attributes: ['attribute_one'],
        },
      });

      expect(findGroupByFilter().props('selectedAttributes')).toEqual(['attribute_one']);
    });

    it('does not render the group-by filter when metric type is histogram', () => {
      mount({
        searchMetadata: {
          ...defaultSearchMetadata,
          type: 'Histogram',
        },
      });

      expect(findGroupByFilter().exists()).toBe(false);
    });
  });

  it('emits the submit event when the attributes filter is changed and submit button is clicked', async () => {
    const filters = [mockFilter];

    await findFilteredSearchBar().vm.$emit('on-filter', filters);

    expect(wrapper.emitted('submit')).toBeUndefined();

    await findSubmitButton().vm.$emit('click');

    expect(wrapper.emitted('submit')).toEqual([
      [
        {
          attributes: [mockFilter],
          groupBy: {
            attributes: defaultSearchMetadata.default_group_by_attributes,
            func: defaultSearchMetadata.default_group_by_function,
          },
        },
      ],
    ]);
    expect(findFilteredSearchBar().props('initialFilterValue')).toEqual(filters);
  });

  it('handles the on-input event by removing incomplete filters', async () => {
    const filters = [
      mockFilter,
      {
        id: 'namespace',
        type: 'a-token',
        value: { operator: '', data: '' },
      },
    ];

    await findFilteredSearchBar().vm.$emit('on-input', filters);

    await findSubmitButton().vm.$emit('click');

    expect(wrapper.emitted('submit')).toEqual([
      [
        {
          attributes: [mockFilter],
          dateRange: undefined,
          groupBy: {
            attributes: defaultSearchMetadata.default_group_by_attributes,
            func: defaultSearchMetadata.default_group_by_function,
          },
        },
      ],
    ]);
    expect(findFilteredSearchBar().props('initialFilterValue')).toEqual([mockFilter]);
  });

  it('emits the filter event when the date range is changed and submit button is clicked', async () => {
    const dateRange = {
      value: '24h',
      startDate: new Date('2022-01-01'),
      endDate: new Date('2022-01-02'),
    };

    await findDateRangeFilter().vm.$emit('on-date-range-selected', dateRange);

    expect(wrapper.emitted('submit')).toBeUndefined();

    await findSubmitButton().vm.$emit('click');

    expect(wrapper.emitted('submit')).toEqual([
      [
        {
          attributes: [],
          dateRange,
          groupBy: {
            attributes: defaultSearchMetadata.default_group_by_attributes,
            func: defaultSearchMetadata.default_group_by_function,
          },
        },
      ],
    ]);
    expect(findDateRangeFilter().props('selected')).toEqual(dateRange);
  });

  it('emits the submit event with default group-by when submit button is clicked', async () => {
    mount(
      {},
      {
        default_group_by_function: 'avg',
        default_group_by_attributes: ['attribute_one', 'attribute_two'],
      },
    );
    await findSubmitButton().vm.$emit('click');

    expect(wrapper.emitted('submit')).toEqual([
      [
        {
          attributes: [],
          groupBy: {
            attributes: ['attribute_one', 'attribute_two'],
            func: 'avg',
          },
        },
      ],
    ]);
  });

  it('emits the submit event when the group-by is changed and submit button is clicked', async () => {
    const groupBy = {
      attributes: ['attribute_one'],
      func: 'sum',
    };

    await findGroupByFilter().vm.$emit('group-by', groupBy);

    expect(wrapper.emitted('submit')).toBeUndefined();

    await findSubmitButton().vm.$emit('click');

    expect(wrapper.emitted('submit')).toEqual([
      [
        {
          attributes: [],
          groupBy,
        },
      ],
    ]);
    expect(findGroupByFilter().props('selectedFunction')).toEqual(groupBy.func);
    expect(findGroupByFilter().props('selectedAttributes')).toEqual(groupBy.attributes);
  });
});
