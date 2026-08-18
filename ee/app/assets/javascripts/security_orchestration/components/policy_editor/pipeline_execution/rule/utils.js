import { DAILY, WEEKLY, MONTHLY } from '../constants';
import { CADENCE_CONFIG } from './constants';

export const isCadenceWeekly = (cadence) => cadence === WEEKLY;
export const isCadenceMonthly = (cadence) => cadence === MONTHLY;

export const updateScheduleCadence = ({ schedule, cadence }) => {
  const { days, days_of_month, ...updatedSchedule } = schedule;
  updatedSchedule.type = cadence;

  if (CADENCE_CONFIG[cadence]) {
    Object.assign(updatedSchedule, {
      ...CADENCE_CONFIG[cadence],
      time_window: {
        ...updatedSchedule.time_window,
        value: CADENCE_CONFIG[cadence].time_window.value,
      },
    });
  }

  return updatedSchedule;
};

/**
 * Generate options for monthly day selection
 * @returns {Array} Array of day options
 */
export const getMonthlyDayOptions = () => {
  return Array.from({ length: 31 }, (_, i) => {
    const day = i + 1;
    return { value: day, text: day };
  });
};

/**
 * Validates a cadence value to ensure it's one of the supported options
 * @param {string} cadence
 * @returns {Boolean}
 */
export const isValidCadence = (cadence) => [DAILY, WEEKLY, MONTHLY].includes(cadence);
