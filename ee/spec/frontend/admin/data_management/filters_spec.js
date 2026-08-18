import {
  formatListboxItems,
  processFilters,
  isValidFilter,
  extractFiltersFromQuery,
} from 'ee/admin/data_management/filters';

describe('formatListboxItems', () => {
  it('handles empty array', () => {
    expect(formatListboxItems([])).toStrictEqual([]);
  });

  it('returns formatted items', () => {
    const items = [
      { titlePlural: 'Users', namePlural: 'users' },
      { titlePlural: 'Projects', namePlural: 'projects' },
      { titlePlural: 'Issues', namePlural: 'issues' },
    ];

    expect(formatListboxItems(items)).toStrictEqual([
      { text: 'Users', value: 'users' },
      { text: 'Projects', value: 'projects' },
      { text: 'Issues', value: 'issues' },
    ]);
  });
});

describe('isValidFilter', () => {
  const validStates = [
    { value: 'verified', text: 'Verified' },
    { value: 'failed', text: 'Failed' },
    { value: 'pending', text: 'Pending' },
  ];

  it.each`
    data          | array          | expected
    ${'verified'} | ${validStates} | ${true}
    ${'invalid'}  | ${validStates} | ${false}
    ${null}       | ${validStates} | ${false}
    ${undefined}  | ${validStates} | ${false}
    ${'verified'} | ${null}        | ${false}
    ${'verified'} | ${undefined}   | ${false}
    ${'verified'} | ${[]}          | ${false}
  `('returns $expected when data is $data and array is $array', ({ data, array, expected }) => {
    expect(isValidFilter(data, array)).toBe(expected);
  });
});

describe('processFilters', () => {
  it.each`
    filters                                                      | query
    ${[]}                                                        | ${{}}
    ${[{ type: 'checksum_state', value: { data: 'verified' } }]} | ${{ checksum_state: 'verified' }}
    ${['123 456 789']}                                           | ${{ identifiers: ['123', '456', '789'] }}
  `('returns the correct { query, url } for filters: $filters', ({ filters, query }) => {
    expect(processFilters(filters)).toStrictEqual(query);
  });

  it('handles mixed filter types', () => {
    const filters = ['123 456', { type: 'checksum_state', value: { data: 'verified' } }];

    const expectedQuery = {
      identifiers: ['123', '456'],
      checksum_state: 'verified',
    };

    expect(processFilters(filters)).toStrictEqual(expectedQuery);
  });

  it('handles empty string filters', () => {
    const filters = [''];
    const expectedQuery = {
      identifiers: [''],
    };

    expect(processFilters(filters)).toStrictEqual(expectedQuery);
  });
});

describe('extractFiltersFromQuery', () => {
  it('returns empty array when no query parameters provided', () => {
    expect(extractFiltersFromQuery({})).toStrictEqual([]);
  });

  it('returns single identifier', () => {
    const query = { identifiers: ['123'] };

    expect(extractFiltersFromQuery(query)).toStrictEqual(['123']);
  });

  it('returns multiple identifiers', () => {
    const query = { identifiers: ['123', '456', '789'] };

    expect(extractFiltersFromQuery(query)).toStrictEqual(['123 456 789']);
  });

  it('returns checksum state filter', () => {
    const query = { checksumState: 'succeeded' };

    expect(extractFiltersFromQuery(query)).toStrictEqual([
      { type: 'checksum_state', value: { data: 'succeeded' } },
    ]);
  });

  it('ignores invalid checksum state', () => {
    const query = { checksumState: 'invalid_state' };

    expect(extractFiltersFromQuery(query)).toStrictEqual([]);
  });

  it('handles empty identifiers array', () => {
    const query = { identifiers: [] };

    expect(extractFiltersFromQuery(query)).toStrictEqual(['']);
  });
});
