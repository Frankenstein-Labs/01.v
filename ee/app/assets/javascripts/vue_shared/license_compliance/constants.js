import { __, s__ } from '~/locale';

import { STATUS_FAILED, STATUS_NEUTRAL, STATUS_SUCCESS } from '~/ci/reports/constants';

const STATUSES = {
  ALLOWED: 'allowed',
  DENIED: 'denied',
  UNCLASSIFIED: 'unclassified',
};

export const LICENSE_APPROVAL_STATUS = STATUSES;

export const REPORT_GROUPS = [
  {
    name: s__('LicenseManagement|Denied'),
    description: __("Out-of-compliance with this project's policies and should be removed"),
    status: STATUS_FAILED,
  },
  {
    name: s__('LicenseManagement|Uncategorized'),
    description: __('No policy matches this license'),
    status: STATUS_NEUTRAL,
  },
  {
    name: s__('LicenseManagement|Allowed'),
    description: __('Acceptable for use in this project'),
    status: STATUS_SUCCESS,
  },
];

export const CLICK_EXTERNAL_LINK_LICENSE_COMPLIANCE = 'click_external_link_license_compliance';
export const LICENSE_LIST = 'licenseList';
