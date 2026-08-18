import { s__ } from '~/locale';

export const SEVERITY_TOOLTIP_TITLE_MAP = {
  unknown: s__(
    `SecurityReports|Sometimes a scanner can't determine a finding's severity. Those findings may still be a potential source of risk though. Please review these manually.`,
  ),
};

export const EMPTY_BODY_MESSAGE = '<Message body is not provided>';

export const VALIDITY_CHECK_POPOVER_OPTIONS = {
  content: s__(
    'Vulnerability|GitLab checks if detected secrets are active. You should revoke and replace active secrets immediately, because they can be used to impersonate legitimate activity.',
  ),
  title: s__('Vulnerability|What is a validity check?'),
};
