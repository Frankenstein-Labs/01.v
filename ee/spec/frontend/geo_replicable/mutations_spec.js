import { getGraphqlBulkMutationVariables } from 'ee/geo_replicable/mutations';
import { ACTION_TYPES, GEO_SHARED_STATUS_STATES } from 'ee/geo_replicable/constants';
import { MOCK_GRAPHQL_REGISTRY_CLASS } from './mock_data';

describe('GeoReplicable mutations', () => {
  describe('getGraphqlBulkMutationVariables', () => {
    it.each`
      action                              | expected
      ${ACTION_TYPES.RESYNC_ALL}          | ${{ registryClass: MOCK_GRAPHQL_REGISTRY_CLASS, action: ACTION_TYPES.RESYNC_ALL.toUpperCase(), replicationState: null, verificationState: null }}
      ${ACTION_TYPES.REVERIFY_ALL}        | ${{ registryClass: MOCK_GRAPHQL_REGISTRY_CLASS, action: ACTION_TYPES.REVERIFY_ALL.toUpperCase(), replicationState: null, verificationState: null }}
      ${ACTION_TYPES.RESYNC_ALL_FAILED}   | ${{ registryClass: MOCK_GRAPHQL_REGISTRY_CLASS, action: ACTION_TYPES.RESYNC_ALL.toUpperCase(), replicationState: GEO_SHARED_STATUS_STATES.FAILED.value.toUpperCase(), verificationState: null }}
      ${ACTION_TYPES.REVERIFY_ALL_FAILED} | ${{ registryClass: MOCK_GRAPHQL_REGISTRY_CLASS, action: ACTION_TYPES.REVERIFY_ALL.toUpperCase(), replicationState: null, verificationState: GEO_SHARED_STATUS_STATES.FAILED.value.toUpperCase() }}
    `('returns correct variables when action is $action', ({ action, expected }) => {
      expect(
        getGraphqlBulkMutationVariables({ action, registryClass: MOCK_GRAPHQL_REGISTRY_CLASS }),
      ).toStrictEqual(expected);
    });
  });
});
