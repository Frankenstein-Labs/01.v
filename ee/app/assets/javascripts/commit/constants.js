import { __ } from '~/locale';

import {
  verificationStatuses as verificationStatusesCE,
  statusConfig as statusConfigCE,
  VERIFIED_CONFIG,
} from '~/commit/constants';

// eslint-disable-next-line import/export
export * from '~/commit/constants';

// eslint-disable-next-line import/export
export const verificationStatuses = {
  ...verificationStatusesCE,
  VERIFIED_CA: 'VERIFIED_CA',
};

// eslint-disable-next-line import/export
export const statusConfig = {
  ...statusConfigCE,
  [verificationStatuses.VERIFIED_CA]: {
    ...VERIFIED_CONFIG,
    description: __(
      'This commit was signed with a certificate issued by top-level group Certificate Authority (CA) and the committer email was verified to belong to the same user.',
    ),
  },
};
