import {
  queryToFilterObj,
  filterObjToQuery,
  filterObjToFilterToken,
  filterTokensToFilterObj,
  metricsListQueryFromAttributes,
} from 'ee/metrics/list/filters';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';

const query = 'search=foo+bar&attribute[]=foo.bar&traceId[]=test-trace-id';
const filterObj = {
  search: [{ value: 'foo bar' }],
  attribute: [{ value: 'foo.bar', operator: '=' }],
  traceId: [{ value: 'test-trace-id', operator: '=' }],
};

const queryObj = {
  search: 'foo bar',
  attribute: ['foo.bar'],
  'not[attribute]': null,
  traceId: ['test-trace-id'],
  'not[traceId]': null,
};

const filterTokens = [
  { type: FILTERED_SEARCH_TERM, value: { data: 'foo bar', operator: undefined } },
  { type: 'attribute', value: { data: 'foo.bar', operator: '=' } },
  { type: 'trace-id', value: { data: 'test-trace-id', operator: '=' } },
];

describe('queryToFilterObj', () => {
  it('converts query to filter obj', () => {
    expect(queryToFilterObj(query)).toEqual(filterObj);
  });
  it('handles empty query', () => {
    expect(queryToFilterObj('')).toEqual({});
  });

  it('ignores unsupported filters', () => {
    expect(queryToFilterObj('unsupported=foo')).toEqual({});
  });
});

describe('filterObjToQuery', () => {
  it('converts a filter object to a query object', () => {
    expect(filterObjToQuery(filterObj)).toEqual(queryObj);
  });

  it('ignores unsupported filters', () => {
    expect(
      filterObjToQuery({
        unsupported: [{ value: 'foo bar' }],
      }),
    ).toEqual({
      traceId: null,
      'not[traceId]': null,
      attribute: null,
      'not[attribute]': null,
      'filtered-search-term': null,
      'not[filtered-search-term]': null,
    });
  });
});

describe('filterObjToFilterToken', () => {
  it('converts filter object to filter token', () => {
    expect(filterObjToFilterToken(filterObj)).toEqual(filterTokens);
  });

  it('ignores unsupported filters', () => {
    expect(filterObjToFilterToken({ unsupported: [{ value: 'foo bar' }] })).toEqual([]);
  });
});

describe('filterTokensToFilterObj', () => {
  it('converts filter token to filter obj', () => {
    expect(filterTokensToFilterObj(filterTokens)).toEqual(filterObj);
  });

  it('ignores unsupported filters', () => {
    expect(
      filterTokensToFilterObj([{ type: 'unsupported', value: { data: 'foo.bar', operator: '=' } }]),
    ).toEqual({});
  });
});

describe('metricsListQueryFromAttributes', () => {
  it('return the metrics list query object from given attributes', () => {
    expect(metricsListQueryFromAttributes({ traceId: 'test-trace-id' })).toMatchObject({
      traceId: ['test-trace-id'],
    });
  });
});
