import { evictCache, fetchCount } from 'ee/members/promotion_requests/graphql/utils';
import { invalidatePromotionRequestsData } from 'ee/members/promotion_requests/store/actions';
import * as types from 'ee/members/promotion_requests/store/mutation_types';
import testAction from 'helpers/vuex_action_helper';
import { groupDefaultProvide } from '../mock_data';

jest.mock('ee/members/promotion_requests/graphql/utils');

describe('Actions', () => {
  let state;

  beforeEach(() => {
    state = { enabled: true };
    evictCache.mockReturnValue(null);
    fetchCount.mockResolvedValue(0);
  });

  describe('invalidatePromotionRequestsData', () => {
    const { context, group, project } = groupDefaultProvide;

    it('will reset the cache', async () => {
      await testAction(
        invalidatePromotionRequestsData,
        { context, group, project },
        state,
        expect.anything(),
        [],
      );

      expect(evictCache).toHaveBeenCalledWith({ context, group, project });
    });

    it('will refetch and update the count', async () => {
      const count = 42;
      fetchCount.mockResolvedValue(count);

      await testAction(
        invalidatePromotionRequestsData,
        { context, group, project },
        state,
        [{ type: types.UPDATE_TOTAL_ITEMS, payload: count }],
        [],
      );
    });

    it('will do nothing if the feature is disabled', async () => {
      state = { enabled: false };

      await testAction(invalidatePromotionRequestsData, { context, group, project }, state, [], []);

      expect(evictCache).not.toHaveBeenCalled();
    });
  });
});
