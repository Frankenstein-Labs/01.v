import { TABLE_TYPE_DEFAULT, TABLE_TYPE_FREE, TABLE_TYPE_TRIAL } from 'ee/billings/constants';

export const isFreePlan = (state) => ['free', null].includes(state.plan.code);
export const tableKey = (state) => {
  let key = TABLE_TYPE_DEFAULT;
  if (state.plan.code === null) {
    key = TABLE_TYPE_FREE;
  } else if (state.plan.trial) {
    key = TABLE_TYPE_TRIAL;
  }
  return key;
};
