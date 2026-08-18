import { s__ } from '~/locale';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import {
  STATUS_KEY,
  STATUS_NEEDS_ATTENTION,
  STATUS_STALE_SCANS,
  STATUS_UNPROTECTED,
  STATUS_FILTER_LABELS,
} from '../constants';

const options = [
  { value: STATUS_NEEDS_ATTENTION, title: STATUS_FILTER_LABELS[STATUS_NEEDS_ATTENTION] },
  { value: STATUS_STALE_SCANS, title: STATUS_FILTER_LABELS[STATUS_STALE_SCANS] },
  { value: STATUS_UNPROTECTED, title: STATUS_FILTER_LABELS[STATUS_UNPROTECTED] },
];

export const statusTokens = [
  {
    type: STATUS_KEY,
    title: s__('SecurityInventory|Status'),
    token: BaseToken,
    unique: true,
    operators: OPERATORS_IS,
    options,
  },
];
