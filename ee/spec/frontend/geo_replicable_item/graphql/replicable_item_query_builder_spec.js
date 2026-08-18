import { print } from 'graphql/language/printer';
import buildReplicableItemQuery from 'ee/geo_replicable_item/graphql/replicable_item_query_builder';
import { MOCK_REPLICABLE_CLASS } from '../mock_data';

describe('buildReplicableItemQuery', () => {
  describe('query fields', () => {
    it.each([true, false])('shows correct fields when verification=%s', (verificationEnabled) => {
      const query = buildReplicableItemQuery(
        MOCK_REPLICABLE_CLASS.graphqlRegistryIdType,
        MOCK_REPLICABLE_CLASS.graphqlFieldName,
        verificationEnabled,
      );
      expect(print(query)).toMatchSnapshot();
    });
  });
});
