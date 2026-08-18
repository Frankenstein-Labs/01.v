import { SORT_DIRECTION } from 'ee/geo_shared/constants';
import {
  formatListboxItems,
  getReplicableTypeFilter,
  getReplicationStatusFilter,
  getVerificationStatusFilter,
  processFilters,
  formatGraphqlIds,
  getGraphqlFilterVariables,
  getSortVariableString,
  getAvailableFilteredSearchTokens,
  getAvailableSortOptions,
  getPaginationObject,
  getSortObject,
} from 'ee/geo_replicable/filters';
import {
  TOKEN_TYPES,
  FILTERED_SEARCH_TOKENS,
  DEFAULT_PAGE_SIZE,
  SORT_OPTIONS_ARRAY,
  SORT_OPTIONS,
  DEFAULT_SORT,
} from 'ee/geo_replicable/constants';
import { TEST_HOST } from 'spec/test_constants';
import { MOCK_REPLICABLE_TYPES, MOCK_GRAPHQL_REGISTRY_CLASS } from './mock_data';

describe('GeoReplicable filters', () => {
  describe('formatListboxItems', () => {
    it('returns the data property formatted', () => {
      expect(formatListboxItems(MOCK_REPLICABLE_TYPES)).toStrictEqual(
        MOCK_REPLICABLE_TYPES.map((r) => ({ text: r.titlePlural, value: r.namePlural })),
      );
    });
  });

  describe('getReplicableTypeFilter', () => {
    it('returns the data property formatted', () => {
      expect(getReplicableTypeFilter('mock_type')).toStrictEqual({
        type: TOKEN_TYPES.REPLICABLE_TYPE,
        value: 'mock_type',
      });
    });
  });

  describe('getReplicationStatusFilter', () => {
    it('returns the data property formatted', () => {
      expect(getReplicationStatusFilter('synced')).toStrictEqual({
        type: TOKEN_TYPES.REPLICATION_STATUS,
        value: {
          data: 'synced',
        },
      });
    });
  });

  describe('getVerificationStatusFilter', () => {
    it('returns the data property formatted', () => {
      expect(getVerificationStatusFilter('succeeded')).toStrictEqual({
        type: TOKEN_TYPES.VERIFICATION_STATUS,
        value: {
          data: 'succeeded',
        },
      });
    });
  });

  describe('processFilters', () => {
    const originalLocationHref = window.location.href;

    beforeEach(() => {
      Object.defineProperty(window, 'location', {
        writable: true,
        value: { href: `${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type` },
      });
    });

    afterEach(() => {
      Object.defineProperty(window, 'location', {
        writable: true,
        value: { href: originalLocationHref },
      });
    });

    it.each`
      filters                                                                                                                                                       | expected
      ${[]}                                                                                                                                                         | ${{ query: {}, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[getReplicableTypeFilter('mock_type')]}                                                                                                                     | ${{ query: {}, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/mock_type`) }}
      ${[getReplicationStatusFilter('synced')]}                                                                                                                     | ${{ query: { replication_status: 'synced' }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[getVerificationStatusFilter('succeeded')]}                                                                                                                 | ${{ query: { verification_status: 'succeeded' }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[`${MOCK_GRAPHQL_REGISTRY_CLASS}/1`]}                                                                                                                       | ${{ query: { ids: `${MOCK_GRAPHQL_REGISTRY_CLASS}/1` }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[`${MOCK_GRAPHQL_REGISTRY_CLASS}/1 ${MOCK_GRAPHQL_REGISTRY_CLASS}/2`]}                                                                                      | ${{ query: { ids: `${MOCK_GRAPHQL_REGISTRY_CLASS}/1 ${MOCK_GRAPHQL_REGISTRY_CLASS}/2` }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/another_mocked_type`) }}
      ${[getReplicableTypeFilter('mock_type'), getReplicationStatusFilter('synced'), getVerificationStatusFilter('succeeded'), `${MOCK_GRAPHQL_REGISTRY_CLASS}/1`]} | ${{ query: { replication_status: 'synced', verification_status: 'succeeded', ids: `${MOCK_GRAPHQL_REGISTRY_CLASS}/1` }, url: new URL(`${TEST_HOST}/admin/geo/sites/2/replication/mock_type`) }}
    `('returns the correct { query, url }', ({ filters, expected }) => {
      expect(processFilters(filters)).toStrictEqual(expected);
    });
  });

  describe('formatGraphqlIds', () => {
    it.each`
      description                             | ids                                                                                                  | expected
      ${'no ids provided'}                    | ${null}                                                                                              | ${null}
      ${'empty string provided'}              | ${''}                                                                                                | ${null}
      ${'single numeric ID'}                  | ${'123'}                                                                                             | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`]}
      ${'multiple numeric IDs'}               | ${'123 456 789'}                                                                                     | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/789`]}
      ${'single GraphQL ID'}                  | ${`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`}                                                 | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`]}
      ${'multiple GraphQL IDs'}               | ${`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123 gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`} | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`]}
      ${'mixed numeric and GraphQL IDs'}      | ${`123 gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`}                                             | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`]}
      ${'registry class format ID'}           | ${`${MOCK_GRAPHQL_REGISTRY_CLASS}/123`}                                                              | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`]}
      ${'multiple registry class format IDs'} | ${`${MOCK_GRAPHQL_REGISTRY_CLASS}/123 ${MOCK_GRAPHQL_REGISTRY_CLASS}/456`}                           | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`]}
      ${'mixed formats'}                      | ${`123 ${MOCK_GRAPHQL_REGISTRY_CLASS}/456 gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/789`}          | ${[`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/123`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/456`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/789`]}
    `('returns $expected when $description', ({ ids, expected }) => {
      expect(
        formatGraphqlIds({ ids, graphqlRegistryClass: MOCK_GRAPHQL_REGISTRY_CLASS }),
      ).toStrictEqual(expected);
    });
  });

  describe('getGraphqlFilterVariables', () => {
    it.each`
      description                                | filters                                                                                                                                                       | expected
      ${'no filters provided'}                   | ${[]}                                                                                                                                                         | ${{ replicationState: null, verificationState: null, ids: null }}
      ${'no replication status filter provided'} | ${[getReplicableTypeFilter('mock_type')]}                                                                                                                     | ${{ replicationState: null, verificationState: null, ids: null }}
      ${'replication status filter provided'}    | ${[getReplicationStatusFilter('synced')]}                                                                                                                     | ${{ replicationState: 'SYNCED', verificationState: null, ids: null }}
      ${'verification status filter provided'}   | ${[getVerificationStatusFilter('succeeded')]}                                                                                                                 | ${{ replicationState: null, verificationState: 'SUCCEEDED', ids: null }}
      ${'ids filter provided'}                   | ${[`${MOCK_GRAPHQL_REGISTRY_CLASS}/1`]}                                                                                                                       | ${{ replicationState: null, verificationState: null, ids: [`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/1`] }}
      ${'multiple ids filter provided'}          | ${[`${MOCK_GRAPHQL_REGISTRY_CLASS}/1 ${MOCK_GRAPHQL_REGISTRY_CLASS}/2`]}                                                                                      | ${{ replicationState: null, verificationState: null, ids: [`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/1`, `gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/2`] }}
      ${'multiple filters provided'}             | ${[getReplicableTypeFilter('mock_type'), getReplicationStatusFilter('failed'), getVerificationStatusFilter('succeeded'), `${MOCK_GRAPHQL_REGISTRY_CLASS}/1`]} | ${{ replicationState: 'FAILED', verificationState: 'SUCCEEDED', ids: [`gid://gitlab/${MOCK_GRAPHQL_REGISTRY_CLASS}/1`] }}
    `('returns correct variables when $description', ({ filters, expected }) => {
      expect(
        getGraphqlFilterVariables({ filters, graphqlRegistryClass: MOCK_GRAPHQL_REGISTRY_CLASS }),
      ).toStrictEqual(expected);
    });
  });

  describe('getSortVariableString', () => {
    it.each`
      description                           | sortObject                                                                        | expected
      ${'default sort'}                     | ${{ value: DEFAULT_SORT.value, direction: DEFAULT_SORT.direction }}               | ${'id_asc'}
      ${'ID sort ascending'}                | ${{ value: SORT_OPTIONS.ID.value, direction: SORT_DIRECTION.ASC }}                | ${'id_asc'}
      ${'ID sort descending'}               | ${{ value: SORT_OPTIONS.ID.value, direction: SORT_DIRECTION.DESC }}               | ${'id_desc'}
      ${'last synced at sort ascending'}    | ${{ value: SORT_OPTIONS.LAST_SYNCED_AT.value, direction: SORT_DIRECTION.ASC }}    | ${'last_synced_at_asc'}
      ${'last synced at sort descending'}   | ${{ value: SORT_OPTIONS.LAST_SYNCED_AT.value, direction: SORT_DIRECTION.DESC }}   | ${'last_synced_at_desc'}
      ${'last verified at sort ascending'}  | ${{ value: SORT_OPTIONS.LAST_VERIFIED_AT.value, direction: SORT_DIRECTION.ASC }}  | ${'verified_at_asc'}
      ${'last verified at sort descending'} | ${{ value: SORT_OPTIONS.LAST_VERIFIED_AT.value, direction: SORT_DIRECTION.DESC }} | ${'verified_at_desc'}
    `('returns "$expected" when $description', ({ sortObject, expected }) => {
      expect(getSortVariableString(sortObject)).toBe(expected);
    });
  });

  describe('getAvailableFilteredSearchTokens', () => {
    it.each`
      description                   | verificationEnabled | expected
      ${'verification is disabled'} | ${false}            | ${FILTERED_SEARCH_TOKENS.filter((filter) => filter.type !== TOKEN_TYPES.VERIFICATION_STATUS)}
      ${'verification is enabled'}  | ${true}             | ${FILTERED_SEARCH_TOKENS}
    `('returns correct tokens when $description', ({ verificationEnabled, expected }) => {
      expect(getAvailableFilteredSearchTokens(verificationEnabled)).toStrictEqual(expected);
    });
  });

  describe('getAvailableSortOptions', () => {
    it.each`
      description                   | verificationEnabled | expected
      ${'verification is disabled'} | ${false}            | ${SORT_OPTIONS_ARRAY.filter((option) => option.value !== SORT_OPTIONS.LAST_VERIFIED_AT.value)}
      ${'verification is enabled'}  | ${true}             | ${SORT_OPTIONS_ARRAY}
    `('returns correct sort options when $description', ({ verificationEnabled, expected }) => {
      expect(getAvailableSortOptions(verificationEnabled)).toStrictEqual(expected);
    });
  });

  describe('getPaginationObject', () => {
    it.each`
      description                                         | cursor                                            | expected
      ${'no parameters provided'}                         | ${{}}                                             | ${{ before: '', after: '', first: DEFAULT_PAGE_SIZE, last: null }}
      ${'empty parameters provided'}                      | ${{ before: '', after: '', first: '', last: '' }} | ${{ before: '', after: '', first: DEFAULT_PAGE_SIZE, last: null }}
      ${'first parameter is provided as String'}          | ${{ first: '10' }}                                | ${{ before: '', after: '', first: 10, last: null }}
      ${'first parameter is provided as Number'}          | ${{ first: 10 }}                                  | ${{ before: '', after: '', first: 10, last: null }}
      ${'first parameter is provided as negative Number'} | ${{ first: -10 }}                                 | ${{ before: '', after: '', first: DEFAULT_PAGE_SIZE, last: null }}
      ${'last parameter is provided as String'}           | ${{ last: '10' }}                                 | ${{ before: '', after: '', first: null, last: 10 }}
      ${'last parameter is provided as Number'}           | ${{ last: 10 }}                                   | ${{ before: '', after: '', first: null, last: 10 }}
      ${'last parameter is provided as negative Number'}  | ${{ last: -10 }}                                  | ${{ before: '', after: '', first: DEFAULT_PAGE_SIZE, last: null }}
      ${'next page pagination object is provided'}        | ${{ after: 'cursor123', first: 10 }}              | ${{ before: '', after: 'cursor123', first: 10, last: null }}
      ${'prev page pagination object is provided'}        | ${{ before: 'cursor123', last: 10 }}              | ${{ before: 'cursor123', after: '', first: null, last: 10 }}
    `('returns correct pagination object when $description', ({ cursor, expected }) => {
      expect(getPaginationObject(cursor)).toStrictEqual(expected);
    });
  });

  describe('getSortObject', () => {
    it.each`
      description                                 | sortString                                                         | expected
      ${'empty string'}                           | ${''}                                                              | ${DEFAULT_SORT}
      ${'null value'}                             | ${null}                                                            | ${DEFAULT_SORT}
      ${'undefined value'}                        | ${undefined}                                                       | ${DEFAULT_SORT}
      ${'invalid sort option'}                    | ${'invalid_asc'}                                                   | ${DEFAULT_SORT}
      ${'invalid direction'}                      | ${'id_invalid'}                                                    | ${DEFAULT_SORT}
      ${'valid ID sort ascending'}                | ${`${SORT_OPTIONS.ID.value}_${SORT_DIRECTION.ASC}`}                | ${{ value: SORT_OPTIONS.ID.value, direction: SORT_DIRECTION.ASC }}
      ${'valid ID sort descending'}               | ${`${SORT_OPTIONS.ID.value}_${SORT_DIRECTION.DESC}`}               | ${{ value: SORT_OPTIONS.ID.value, direction: SORT_DIRECTION.DESC }}
      ${'valid last synced at sort ascending'}    | ${`${SORT_OPTIONS.LAST_SYNCED_AT.value}_${SORT_DIRECTION.ASC}`}    | ${{ value: SORT_OPTIONS.LAST_SYNCED_AT.value, direction: SORT_DIRECTION.ASC }}
      ${'valid last synced at sort descending'}   | ${`${SORT_OPTIONS.LAST_SYNCED_AT.value}_${SORT_DIRECTION.DESC}`}   | ${{ value: SORT_OPTIONS.LAST_SYNCED_AT.value, direction: SORT_DIRECTION.DESC }}
      ${'valid last verified at sort ascending'}  | ${`${SORT_OPTIONS.LAST_VERIFIED_AT.value}_${SORT_DIRECTION.ASC}`}  | ${{ value: SORT_OPTIONS.LAST_VERIFIED_AT.value, direction: SORT_DIRECTION.ASC }}
      ${'valid last verified at sort descending'} | ${`${SORT_OPTIONS.LAST_VERIFIED_AT.value}_${SORT_DIRECTION.DESC}`} | ${{ value: SORT_OPTIONS.LAST_VERIFIED_AT.value, direction: SORT_DIRECTION.DESC }}
    `('returns $expected when $description', ({ sortString, expected }) => {
      expect(getSortObject(sortString)).toStrictEqual(expected);
    });
  });
});
