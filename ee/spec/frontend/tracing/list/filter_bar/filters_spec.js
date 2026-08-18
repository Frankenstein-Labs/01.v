import {
  queryToFilterObj,
  filterObjToQuery,
  filterObjToFilterToken,
  filterTokensToFilterObj,
  tracingListQueryFromAttributes,
} from 'ee/tracing/list/filter_bar/filters';

describe('utils', () => {
  const query =
    'sortBy=timestamp_desc' +
    '&service[]=accountingservice&not%5Bservice%5D[]=adservice' +
    '&operation[]=orders%20receive&not%5Boperation%5D[]=orders%20receive' +
    '&gt%5BdurationMs%5D[]=100&lt%5BdurationMs%5D[]=1000' +
    '&trace_id[]=9609bf00-4b68-f86c-abe2-5e23d0089c83' +
    '&not%5Btrace_id%5D[]=9609bf00-4b68-f86c-abe2-5e23d0089c83' +
    '&attribute[]=foo%3Dbar&attribute[]=baz%3Dbar' +
    '&status[]=ok&not%5Bstatus%5D[]=error' +
    '&search=searchquery' +
    '&date_range=custom' +
    '&date_end=2020-01-02T00%3A00%3A00.000Z' +
    '&date_start=2020-01-01T00%3A00%3A00.000Z';

  const filterObj = {
    attributes: {
      service: [
        { operator: '=', value: 'accountingservice' },
        { operator: '!=', value: 'adservice' },
      ],
      operation: [
        { operator: '=', value: 'orders receive' },
        { operator: '!=', value: 'orders receive' },
      ],
      traceId: [
        { operator: '=', value: '9609bf00-4b68-f86c-abe2-5e23d0089c83' },
        { operator: '!=', value: '9609bf00-4b68-f86c-abe2-5e23d0089c83' },
      ],
      durationMs: [
        { operator: '>', value: '100' },
        { operator: '<', value: '1000' },
      ],
      attribute: [
        { operator: '=', value: 'foo=bar' },
        { operator: '=', value: 'baz=bar' },
      ],
      status: [
        { operator: '=', value: 'ok' },
        { operator: '!=', value: 'error' },
      ],
      search: [{ value: 'searchquery' }],
    },
    dateRange: {
      value: 'custom',
      startDate: new Date('2020-01-01'),
      endDate: new Date('2020-01-02'),
    },
  };

  const queryObj = {
    attribute: ['foo=bar', 'baz=bar'],
    durationMs: null,
    'gt[durationMs]': ['100'],
    'lt[durationMs]': ['1000'],
    'not[attribute]': null,
    'not[durationMs]': null,
    'not[operation]': ['orders receive'],
    'not[service]': ['adservice'],
    'not[trace_id]': ['9609bf00-4b68-f86c-abe2-5e23d0089c83'],
    'not[status]': ['error'],
    operation: ['orders receive'],
    status: ['ok'],
    search: 'searchquery',
    service: ['accountingservice'],
    trace_id: ['9609bf00-4b68-f86c-abe2-5e23d0089c83'],
    date_range: 'custom',
    date_end: '2020-01-02T00:00:00.000Z',
    date_start: '2020-01-01T00:00:00.000Z',
  };

  const attributesFilterTokens = [
    { type: 'service-name', value: { data: 'accountingservice', operator: '=' } },
    { type: 'service-name', value: { data: 'adservice', operator: '!=' } },
    { type: 'operation', value: { data: 'orders receive', operator: '=' } },
    { type: 'operation', value: { data: 'orders receive', operator: '!=' } },
    {
      type: 'trace-id',
      value: { data: '9609bf00-4b68-f86c-abe2-5e23d0089c83', operator: '=' },
    },
    {
      type: 'trace-id',
      value: { data: '9609bf00-4b68-f86c-abe2-5e23d0089c83', operator: '!=' },
    },
    { type: 'duration-ms', value: { data: '100', operator: '>' } },
    { type: 'duration-ms', value: { data: '1000', operator: '<' } },
    { type: 'attribute', value: { data: 'foo=bar', operator: '=' } },
    { type: 'attribute', value: { data: 'baz=bar', operator: '=' } },
    { type: 'filtered-search-term', value: { data: 'searchquery', operator: undefined } },
    { type: 'status', value: { data: 'ok', operator: '=' } },
    { type: 'status', value: { data: 'error', operator: '!=' } },
  ];

  describe('queryToFilterObj', () => {
    it('should build a filter obj', () => {
      expect(queryToFilterObj(query)).toEqual(filterObj);
    });
  });

  describe('filterObjToQuery', () => {
    it('should convert filter object to URL query', () => {
      expect(filterObjToQuery(filterObj)).toEqual(queryObj);
    });
  });

  describe('filterObjToFilterToken', () => {
    it('should convert filter object to filter tokens', () => {
      expect(filterObjToFilterToken(filterObj.attributes)).toEqual(attributesFilterTokens);
    });
  });

  describe('filterTokensToFilterObj', () => {
    it('should convert filter tokens to filter object', () => {
      expect(filterTokensToFilterObj(attributesFilterTokens)).toEqual(filterObj.attributes);
    });
  });
});

describe('tracingListQueryFromAttributes', () => {
  it('returns the query object from attributes', () => {
    expect(
      tracingListQueryFromAttributes({
        traceIds: ['a', 'b'],
        startTimestamp: new Date('2024-08-04').getTime(),
        endTimestamp: new Date('2024-08-05').getTime(),
      }),
    ).toMatchObject({
      date_end: '2024-08-05T00:00:00.000Z',
      date_start: '2024-08-04T00:00:00.000Z',
      date_range: 'custom',
      trace_id: ['a', 'b'],
    });
  });
});
