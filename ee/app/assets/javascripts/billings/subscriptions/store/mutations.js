import { TABLE_TYPE_DEFAULT } from 'ee/billings/constants';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import * as types from './mutation_types';
import { tableKey } from './getters';

export default {
  [types.SET_NAMESPACE_ID](state, payload) {
    state.namespaceId = payload;
  },

  [types.REQUEST_SUBSCRIPTION](state) {
    state.isLoadingSubscription = true;
    state.hasErrorSubscription = false;
  },

  [types.RECEIVE_SUBSCRIPTION_SUCCESS](state, payload) {
    const data = convertObjectPropsToCamelCase(payload, { deep: true });
    const { plan, usage, billing } = data;
    state.plan = plan;
    state.billing = billing;

    const stateTableKey = tableKey(state);

    state.tables[stateTableKey].rows.forEach((row) => {
      row.columns.forEach((col) => {
        const setValue = (source) => Object.assign(col, source);

        if (Object.prototype.hasOwnProperty.call(usage, col.id)) {
          setValue({ value: usage[col.id] });
          if (stateTableKey === TABLE_TYPE_DEFAULT) {
            setValue({ type: stateTableKey });
          }
        } else if (Object.prototype.hasOwnProperty.call(billing, col.id)) {
          setValue({ value: billing[col.id] });
        }
      });
    });

    state.isLoadingSubscription = false;
  },

  [types.RECEIVE_SUBSCRIPTION_ERROR](state) {
    state.isLoadingSubscription = false;
    state.hasErrorSubscription = true;
  },
};
