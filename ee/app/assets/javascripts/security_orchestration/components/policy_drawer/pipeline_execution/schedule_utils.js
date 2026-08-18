import { __, s__, n__, sprintf } from '~/locale';
import { formatDate } from '~/lib/utils/datetime_utility';
import {
  DAILY,
  WEEKLY,
  MONTHLY,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import {
  ALL_BRANCHES,
  ALL_PROTECTED_BRANCHES,
  PROJECT_DEFAULT_BRANCH,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { DEFAULT_TIMEZONE } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/constants';
import { getTimeWindowInfo } from '../utils';

/**
 * Gets the branch information
 * @param {String} branchType
 * @returns {String} Formatted branch information
 */
export const getBranchInfo = (branchType) => {
  const branchTypes = {
    [ALL_PROTECTED_BRANCHES.value]: ALL_PROTECTED_BRANCHES.text,
    [PROJECT_DEFAULT_BRANCH.value]: PROJECT_DEFAULT_BRANCH.text,
    [ALL_BRANCHES.value]: ALL_BRANCHES.text,
  };

  return sprintf(s__('SecurityOrchestration|for %{branchType}'), {
    branchType: branchTypes[branchType] || branchType || PROJECT_DEFAULT_BRANCH.text,
  });
};

/**
 * Gets the time information
 * @param {String} time
 * @returns {String} Formatted time information
 */
export const getTimeInfo = (time) => {
  if (!time) {
    return '';
  }

  return sprintf(s__('SecurityOrchestration|at %{time}'), { time });
};

/**
 * Gets the timezone information
 * @param {String} timezone
 * @returns {String} Formatted timezone information
 */
export const getTimezoneInfo = (timezone) => {
  return sprintf(s__('SecurityOrchestration|in timezone %{timezone}'), {
    timezone: timezone || DEFAULT_TIMEZONE,
  });
};

/**
 * Gets the weekly schedule information
 * @param {Array} days
 * @returns {String} Formatted weekly schedule information
 */
export const getWeeklyScheduleInfo = (days) => {
  if (!days?.length) {
    return __('weekly');
  }

  return sprintf(s__('SecurityOrchestration|starting every %{days}'), {
    days: days.join(', '),
  });
};

/**
 * Gets the monthly schedule information
 * @param {Array} daysOfMonth
 * @returns {String} Formatted monthly schedule information
 */
export const getMonthlyScheduleInfo = (daysOfMonth = []) => {
  if (!daysOfMonth?.length) {
    return __('monthly');
  }

  const days = daysOfMonth.join(', ');
  const dayText = n__('day', 'days', daysOfMonth.length);

  return sprintf(s__('SecurityOrchestration|on %{dayText} %{days} of each month'), {
    dayText,
    days,
  });
};

/**
 * Gets the schedule type information
 * @param {Object} schedule
 * @returns {String} Formatted schedule type information
 */
export const getScheduleTypeInfo = (schedule) => {
  if (schedule.type === DAILY) {
    return __('daily');
  }

  if (schedule.type === WEEKLY) {
    return getWeeklyScheduleInfo(schedule.days);
  }

  if (schedule.type === MONTHLY) {
    return getMonthlyScheduleInfo(schedule.days_of_month);
  }

  return '';
};

/**
 * Gets the snooze information
 * @param {Object} snooze
 * @returns {String} Formatted snooze information
 */
export const getSnoozeInfo = ({ snooze = null }) => {
  if (!snooze) {
    return '';
  }

  const { reason, until } = snooze;

  if (reason) {
    return sprintf(
      s__('SecurityOrchestration|The schedule is snoozed until %{until} for reason: %{reason}.'),
      {
        reason,
        until: formatDate(until),
      },
    );
  }

  return sprintf(s__('SecurityOrchestration|The schedule is snoozed until %{until}.'), {
    until: formatDate(until),
  });
};

/**
 * Generates a complete schedule summary for a pipeline execution policy
 * @param {Object} schedule - The schedule object
 * @returns {String} The full schedule summary
 */
export const generateScheduleSummary = (schedule) => {
  // Get all the individual parts
  const branchInfo = getBranchInfo(schedule.branch_type);
  const scheduleTypeInfo = getScheduleTypeInfo(schedule);
  const timeInfo = getTimeInfo(schedule.start_time);
  const timeWindowInfo = sprintf(s__('SecurityOrchestration|and run for %{timeWindowInfo}'), {
    timeWindowInfo: getTimeWindowInfo(schedule.time_window),
  });
  const timezoneInfo = getTimezoneInfo(schedule.timezone);

  // Combine using sprintf
  return sprintf(
    s__(
      'SecurityOrchestration|Schedule the following pipeline execution policy to run %{branchInfo} %{scheduleTypeInfo} %{timeInfo} %{timeWindowInfo} %{timezoneInfo}.',
    ),
    {
      branchInfo,
      scheduleTypeInfo,
      timeInfo,
      timeWindowInfo,
      timezoneInfo,
    },
  );
};
