import {
  filterObjToQuery,
  queryToFilterObj,
  metricsDetailsQueryFromAttributes,
} from 'ee/metrics/details/filters';

describe('filterObjToQuery', () => {
  const query =
    'foo.bar[]=eq-val' +
    '&not%5Bfoo.bar%5D[]=not-eq-val' +
    '&like%5Bfoo.baz%5D[]=like-val' +
    '&not_like%5Bfoo.baz%5D[]=not-like-val' +
    '&group_by_fn=avg' +
    '&group_by_attrs[]=foo' +
    '&group_by_attrs[]=bar' +
    '&date_range=custom' +
    '&date_start=2020-01-01T00%3A00%3A00.000Z' +
    '&date_end=2020-01-02T00%3A00%3A00.000Z';

  const filterObj = {
    attributes: {
      'foo.bar': [
        { operator: '=', value: 'eq-val' },
        { operator: '!=', value: 'not-eq-val' },
      ],
      'foo.baz': [
        { operator: '=~', value: 'like-val' },
        { operator: '!~', value: 'not-like-val' },
      ],
    },
    groupBy: {
      func: 'avg',
      attributes: ['foo', 'bar'],
    },
    dateRange: {
      value: 'custom',
      startDate: new Date('2020-01-01'),
      endDate: new Date('2020-01-02'),
    },
  };

  const queryObj = {
    'foo.bar': ['eq-val'],
    'not[foo.bar]': ['not-eq-val'],
    'like[foo.bar]': null,
    'not_like[foo.bar]': null,
    'foo.baz': null,
    'not[foo.baz]': null,
    'like[foo.baz]': ['like-val'],
    'not_like[foo.baz]': ['not-like-val'],
    group_by_fn: 'avg',
    group_by_attrs: ['foo', 'bar'],
    date_range: 'custom',
    date_end: '2020-01-02T00:00:00.000Z',
    date_start: '2020-01-01T00:00:00.000Z',
  };

  describe('filterObjToQuery', () => {
    it('should convert filter object to URL query', () => {
      expect(filterObjToQuery(filterObj)).toEqual(queryObj);
    });

    it('handles empty group by attrs', () => {
      expect(
        filterObjToQuery({
          groupBy: {
            attributes: [],
          },
        }),
      ).toEqual({});
    });

    it('handles missing values', () => {
      expect(filterObjToQuery({})).toEqual({});
    });
  });

  describe('queryToFilterObj', () => {
    it('should build a filter obj', () => {
      expect(queryToFilterObj(query)).toEqual(filterObj);
    });

    it('handles empty group by attrs', () => {
      expect(queryToFilterObj('group_by_attrs[]=')).toEqual({
        attributes: {},
        dateRange: {
          value: '1h',
        },
        groupBy: {},
      });
    });

    it('ignores type in the query params', () => {
      expect(queryToFilterObj('type=foo&foo.bar[]=eq-val')).toEqual({
        attributes: {
          'foo.bar': [{ operator: '=', value: 'eq-val' }],
        },
        dateRange: {
          value: '1h',
        },
        groupBy: {},
      });
    });
  });
});

describe('metricsDetailsQueryFromAttributes', () => {
  it('returns the metrics details query params from the given attributes', () => {
    expect(
      metricsDetailsQueryFromAttributes({
        dateRange: {
          startDate: new Date('2024-08-29 11:00:00'),
          endDate: new Date('2024-08-29 12:00:00'),
        },
      }),
    ).toEqual({
      date_end: '2024-08-29T12:00:00.000Z',
      date_range: 'custom',
      date_start: '2024-08-29T11:00:00.000Z',
    });
  });

  it('returns an empty obj if the end date is missing', () => {
    expect(
      metricsDetailsQueryFromAttributes({
        dateRange: {
          startDate: new Date('2024-08-29 11:00:00'),
        },
      }),
    ).toEqual({});
  });

  it('returns an empty obj if the start date is missing', () => {
    expect(
      metricsDetailsQueryFromAttributes({
        dateRange: {
          endDate: new Date('2024-08-29 11:00:00'),
        },
      }),
    ).toEqual({});
  });

  it('returns an empty obj if the dateRange is missing', () => {
    expect(metricsDetailsQueryFromAttributes({})).toEqual({});
  });
});
