import * as getters from 'ee/billings/subscriptions/store/getters';
import State from 'ee/billings/subscriptions/store/state';
import { TABLE_TYPE_DEFAULT, TABLE_TYPE_FREE, TABLE_TYPE_TRIAL } from 'ee/billings/constants';

describe('EE billings subscription module getters', () => {
  let state;

  beforeEach(() => {
    state = State();
  });

  describe('isFreePlan', () => {
    it('should return false', () => {
      const plan = {
        name: 'Gold',
        code: 'gold',
      };
      state.plan = plan;

      expect(getters.isFreePlan(state)).toBe(false);
    });

    it('should return true', () => {
      const plan = {
        name: null,
        code: null,
      };
      state.plan = plan;

      expect(getters.isFreePlan(state)).toBe(true);
    });
  });

  describe('tableKey', () => {
    it.each`
      tableKey              | planDesc   | plan
      ${TABLE_TYPE_DEFAULT} | ${'valid'} | ${{ name: 'Premium', code: 'premium' }}
      ${TABLE_TYPE_FREE}    | ${'null'}  | ${{ name: 'Premium', code: null }}
      ${TABLE_TYPE_TRIAL}   | ${'trial'} | ${{ name: 'Premium', code: 'premium', trial: 'true' }}
    `('returns $tableKey with $planDesc plan', ({ tableKey, plan }) => {
      state.plan = plan;
      expect(getters.tableKey(state)).toBe(tableKey);
    });
  });
});
