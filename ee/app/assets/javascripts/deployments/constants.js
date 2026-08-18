import { s__ } from '~/locale';

export const APPROVAL_STATUSES = {
  APPROVED: 'APPROVED',
  REJECTED: 'REJECTED',
};

export const ACCESS_LEVEL = {
  MAINTAINER: {
    value: 'Maintainers' /* eslint-disable-line @gitlab/require-i18n-strings */,
    display: s__('DeploymentApprovals|Maintainers'),
  },
  DEVELOPER: {
    value: 'Developers + Maintainers' /* eslint-disable-line @gitlab/require-i18n-strings */,
    display: s__('DeploymentApprovals|Developers + Maintainers'),
  },
};
