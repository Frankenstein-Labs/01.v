import { EXCEPTION_MODE, WARN_MODE } from './constants';

export const getSelectedModeOption = ({
  hasBypassPolicies = false,
  hasBypassExceptions = false,
}) => {
  if (hasBypassPolicies && hasBypassExceptions) return '';
  if (hasBypassPolicies) return WARN_MODE;
  if (hasBypassExceptions) return EXCEPTION_MODE;
  return '';
};
