import { __ } from '~/locale';
import { DORA_TABLE_METRICS } from '../constants';

export const TABLE_FIELDS = [
  {
    key: 'name',
    label: __('Project'),
    thClass: 'gl-w-1/5',
  },
  ...Object.entries(DORA_TABLE_METRICS).map(([key, opts]) => ({
    key,
    ...opts,
  })),
].map((col) => ({
  ...col,
  sortable: true,
  thClass: 'gl-w-1/5',
}));

export const DEFAULT_TABLE_SORT_COLUMN = TABLE_FIELDS[1].key;
