import {
  filterObjToFilterToken,
  filterTokensToFilterObj,
  filterObjToQuery,
  queryToFilterObj,
  selectedLogQueryObject,
  logsQueryFromAttributes,
} from 'ee/logs/list/filter_bar/filters';

describe('utils', () => {
  const filterObj = {
    attributes: {
      service: [
        { operator: '=', value: 'serviceName' },
        { operator: '!=', value: 'serviceName2' },
      ],
      severityName: [
        { operator: '=', value: 'info' },
        { operator: '!=', value: 'warning' },
      ],
      severityNumber: [
        { operator: '=', value: '9' },
        { operator: '!=', value: '10' },
      ],
      traceId: [{ operator: '=', value: 'traceId' }],
      spanId: [{ operator: '=', value: 'spanId' }],
      fingerprint: [{ operator: '=', value: 'fingerprint' }],
      traceFlags: [
        { operator: '=', value: '1' },
        { operator: '!=', value: '2' },
      ],
      attribute: [{ operator: '=', value: 'attr=bar' }],
      resourceAttribute: [{ operator: '=', value: 'res=foo' }],
      search: [{ value: 'some-search' }],
    },
    dateRange: {
      value: 'custom',
      startDate: new Date('2020-01-01'),
      endDate: new Date('2020-01-02'),
    },
  };

  const queryObj = {
    attribute: ['attr=bar'],
    fingerprint: ['fingerprint'],
    'not[fingerprint]': null,
    'not[resourceAttribute]': null,
    'not[service]': ['serviceName2'],
    'not[severityName]': ['warning'],
    'not[severityNumber]': ['10'],
    'not[spanId]': null,
    'not[traceFlags]': ['2'],
    'not[traceId]': null,
    'not[attribute]': null,
    resourceAttribute: ['res=foo'],
    search: 'some-search',
    service: ['serviceName'],
    severityName: ['info'],
    severityNumber: ['9'],
    spanId: ['spanId'],
    traceFlags: ['1'],
    traceId: ['traceId'],
    date_range: 'custom',
    date_end: '2020-01-02T00:00:00.000Z',
    date_start: '2020-01-01T00:00:00.000Z',
  };

  const query =
    'attribute[]=attr%3Dbar' +
    '&fingerprint[]=fingerprint' +
    '&service[]=serviceName' +
    '&not%5Bservice%5D[]=serviceName2' +
    '&resourceAttribute[]=res%3Dfoo' +
    '&search[]=some-search' +
    '&severityName[]=info' +
    '&not%5BseverityName%5D[]=warning' +
    '&severityNumber[]=9' +
    '&not%5BseverityNumber%5D[]=10' +
    '&spanId[]=spanId' +
    '&traceFlags[]=1' +
    '&not%5BtraceFlags%5D[]=2' +
    '&traceId[]=traceId' +
    '&date_range=custom' +
    '&date_end=2020-01-02T00%3A00%3A00.000Z' +
    '&date_start=2020-01-01T00%3A00%3A00.000Z';

  const attributesFilterTokens = [
    {
      type: 'service-name',
      value: { data: 'serviceName', operator: '=' },
    },
    {
      type: 'service-name',
      value: { data: 'serviceName2', operator: '!=' },
    },
    { type: 'severity-name', value: { data: 'info', operator: '=' } },
    { type: 'severity-name', value: { data: 'warning', operator: '!=' } },
    { type: 'severity-number', value: { data: '9', operator: '=' } },
    { type: 'severity-number', value: { data: '10', operator: '!=' } },
    { type: 'trace-id', value: { data: 'traceId', operator: '=' } },
    { type: 'span-id', value: { data: 'spanId', operator: '=' } },
    {
      type: 'fingerprint',
      value: { data: 'fingerprint', operator: '=' },
    },
    { type: 'trace-flags', value: { data: '1', operator: '=' } },
    { type: 'trace-flags', value: { data: '2', operator: '!=' } },
    { type: 'attribute', value: { data: 'attr=bar', operator: '=' } },
    {
      type: 'resource-attribute',
      value: { data: 'res=foo', operator: '=' },
    },
    {
      type: 'filtered-search-term',
      value: { data: 'some-search', operator: undefined },
    },
  ];

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

  describe('filterObjToQuery', () => {
    it('should convert filter object to query', () => {
      expect(filterObjToQuery(filterObj)).toEqual(queryObj);
    });

    it('handles missing attributes filter', () => {
      expect(
        filterObjToQuery({
          dateRange: {
            value: '7d',
          },
        }),
      ).toEqual({ date_range: '7d' });
    });

    it('handles empty values', () => {
      expect(filterObjToQuery({})).toEqual({});
    });

    it('sets an empty search query if missing', () => {
      expect(filterObjToQuery({ attributes: { 'filtered-search-term': undefined } })).toMatchObject(
        {
          search: '',
        },
      );
    });
  });

  describe('queryToFilterObj', () => {
    it('should build a filter obj', () => {
      expect(queryToFilterObj(query)).toEqual(filterObj);
    });
  });

  describe('selectedLogQueryObject', () => {
    it('sets the required query params', () => {
      expect(
        selectedLogQueryObject({
          service_name: 'service1',
          severity_number: '9',
          trace_id: 'test-trace-id',
          fingerprint: 'log-id',
          timestamp: '2024-02-19T16:10:15.4433398Z',
        }),
      ).toEqual({
        attribute: null,
        fingerprint: ['log-id'],
        'not[fingerprint]': null,
        'not[resourceAttribute]': null,
        'not[service]': null,
        'not[severityName]': null,
        'not[severityNumber]': null,
        'not[spanId]': null,
        'not[traceFlags]': null,
        'not[traceId]': null,
        'not[attribute]': null,
        resourceAttribute: null,
        search: '',
        service: ['service1'],
        severityName: null,
        severityNumber: ['9'],
        spanId: null,
        traceFlags: null,
        traceId: ['test-trace-id'],
        timestamp: '2024-02-19T16:10:15.4433398Z',
      });
    });
  });

  describe('logsQueryFromAttributes', () => {
    it('returns an empty object when no arguments are provided', () => {
      const result = logsQueryFromAttributes({});
      expect(result).toMatchObject({});
    });

    it('returns an object with traceId filter when traceId is provided', () => {
      const result = logsQueryFromAttributes({ traceId: 'abc123' });
      expect(result).toMatchObject({
        traceId: ['abc123'],
      });
    });

    it('returns an object with spanId filter when spanId is provided', () => {
      const result = logsQueryFromAttributes({ spanId: 'def456' });
      expect(result).toMatchObject({
        spanId: ['def456'],
      });
    });

    it('returns an object with service filter when service is provided', () => {
      const result = logsQueryFromAttributes({ service: 'my-service' });
      expect(result).toMatchObject({
        service: ['my-service'],
      });
    });

    it('returns an object with severityNumber filter when severityNumber is provided', () => {
      const result = logsQueryFromAttributes({ severityNumber: 2 });
      expect(result).toMatchObject({
        severityNumber: [2],
      });
    });

    it('returns an object with fingerprint filter when fingerprint is provided', () => {
      const result = logsQueryFromAttributes({ fingerprint: 'xyz789' });
      expect(result).toMatchObject({
        fingerprint: ['xyz789'],
      });
    });

    it('returns an object with timestamp filter when timestamp is provided', () => {
      const result = logsQueryFromAttributes({ timestamp: '2023-04-01T12:00:00Z' });
      expect(result).toMatchObject({
        timestamp: '2023-04-01T12:00:00Z',
      });
    });

    it('returns an object with daterange filter when daterange is provided', () => {
      const result = logsQueryFromAttributes({ dateRange: { value: '30d' } });
      expect(result).toMatchObject({
        date_range: '30d',
      });
    });

    it('returns an object with timestamp filter if both timestamp and daterange are provided', () => {
      const result = logsQueryFromAttributes({
        timestamp: '2023-04-01T12:00:00Z',
        dateRange: { value: '30d' },
      });
      expect(result).toMatchObject({
        timestamp: '2023-04-01T12:00:00Z',
      });
    });

    it('returns an object with multiple filters when multiple arguments are provided', () => {
      const result = logsQueryFromAttributes({
        traceId: 'abc123',
        spanId: 'def456',
        service: 'my-service',
        severityNumber: 2,
        fingerprint: 'xyz789',
        timestamp: '2023-04-01T12:00:00Z',
      });
      expect(result).toMatchObject({
        traceId: ['abc123'],
        spanId: ['def456'],
        service: ['my-service'],
        severityNumber: [2],
        fingerprint: ['xyz789'],
        timestamp: '2023-04-01T12:00:00Z',
      });
    });
  });
});
