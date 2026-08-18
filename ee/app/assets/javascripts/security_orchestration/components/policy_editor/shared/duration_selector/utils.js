import { isNumeric } from '~/lib/utils/number_utils';
import { MAXIMUM_SECONDS, MINIMUM_SECONDS, TIME_UNITS } from './constants';

/**
 * Determines the most appropriate time unit for a given number of seconds
 * @param {Number} seconds
 * @returns {Number} The appropriate time unit from TIME_UNITS
 */
export const determineTimeUnit = (seconds) => {
  if (!isNumeric(seconds) || seconds < 0) {
    return TIME_UNITS.MINUTE;
  }

  if (seconds % TIME_UNITS.DAY === 0 && seconds >= TIME_UNITS.DAY) {
    return TIME_UNITS.DAY;
  }

  if (seconds % TIME_UNITS.HOUR === 0 && seconds >= TIME_UNITS.HOUR) {
    return TIME_UNITS.HOUR;
  }

  return TIME_UNITS.MINUTE;
};

export const getMinimumSecondsInMinutes = (seconds = MINIMUM_SECONDS) => {
  return seconds / 60;
};

/**
 * Ensures the time is within the limits
 * @param {number} time - Time value in seconds
 * @param {number} minimumSeconds - minimum seconds allowed
 * @returns {number} Time value capped between the minimum seconds property and MAXIMUM_SECONDS
 */
export const getValueWithinLimits = (time, minimumSeconds) => {
  return Math.max(Math.min(time, MAXIMUM_SECONDS), minimumSeconds);
};

/**
 * Converts seconds to a value in the specified unit
 * @param {Number} seconds
 * @param {Number} unit - The time unit to convert to
 * @returns {Number} Value in the specified unit
 */
export const secondsToValue = (seconds, unit) => {
  if (!isNumeric(seconds) || seconds < 0) {
    return 0;
  }

  return seconds / unit;
};

/**
 * Converts a value and time unit to seconds
 * @param {Number} value - The numeric value
 * @param {Number} unit - The time unit in seconds (from TIME_UNITS)
 * @returns {Number} Total seconds
 */
export const timeUnitToSeconds = (value, unit) => {
  return value * unit;
};
