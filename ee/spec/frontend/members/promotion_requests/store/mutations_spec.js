import { UPDATE_TOTAL_ITEMS } from 'ee/members/promotion_requests/store/mutation_types';
import mutations from 'ee/members/promotion_requests/store/mutations';

describe('Mutations', () => {
  let state;

  beforeEach(() => {
    state = {
      pagination: {
        totalItems: 0,
      },
    };
  });

  describe(UPDATE_TOTAL_ITEMS, () => {
    it('will upate the totalItems value', () => {
      mutations.UPDATE_TOTAL_ITEMS(state, 42);
      expect(state.pagination.totalItems).toBe(42);
    });
  });
});
