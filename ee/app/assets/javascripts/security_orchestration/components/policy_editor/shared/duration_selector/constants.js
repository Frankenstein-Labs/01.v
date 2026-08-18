import { __ } from '~/locale';
import { SECONDS_IN_DAY } from '~/lib/utils/datetime_utility';

export const MINIMUM_SECONDS = 600; // 10 minutes, set in ee/app/validators/json_schemas/security_orchestration_policy.json
export const MAXIMUM_SECONDS = 2629746; // 30 days, set in ee/app/validators/json_schemas/security_orchestration_policy.json
export const DEFAULT_TIME_WINDOW = { distribution: 'random' };

// Constants for time units in seconds
export const TIME_UNITS = {
  MINUTE: 60,
  HOUR: 3600,
  DAY: SECONDS_IN_DAY,
};

// Constants for time units in seconds
export const DEFAULT_TIME_PER_UNIT = {
  [TIME_UNITS.MINUTE]: MINIMUM_SECONDS,
  [TIME_UNITS.HOUR]: TIME_UNITS.HOUR,
  [TIME_UNITS.DAY]: TIME_UNITS.DAY,
};

export const TIME_UNIT_OPTIONS = [
  { value: TIME_UNITS.MINUTE, text: __('Minutes') },
  { value: TIME_UNITS.HOUR, text: __('Hours') },
  { value: TIME_UNITS.DAY, text: __('Days') },
];
