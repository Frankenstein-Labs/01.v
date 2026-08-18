import { s__ } from '~/locale';
import { STATUS } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

export const STATUS_FILTER_OPTIONS = [
  {
    text: s__('ScanResultPolicy|New status'),
    value: STATUS,
    tooltip: s__('ScanResultPolicy|Maximum of two status criteria allowed'),
  },
];
