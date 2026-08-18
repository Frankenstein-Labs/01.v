import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { cloneDate, newDate } from '~/lib/utils/datetime_utility';

import { PRESET_TYPES, DAYS_IN_WEEK } from '../constants';

/**
 * Updates provided `epic` or `milestone` object with necessary props
 * representing underlying dates.
 *
 * @param {Object} roadmapItem (epic or milestone)
 * @param {Date} timeframeStartDate
 * @param {Date} timeframeEndDate
 */
export const processRoadmapItemDates = (roadmapItem, timeframeStartDate, timeframeEndDate) => {
  if (!roadmapItem.startDateUndefined) {
    // If startDate is less than first timeframe item
    if (roadmapItem.originalStartDate.getTime() < timeframeStartDate.getTime()) {
      Object.assign(roadmapItem, {
        // startDate is out of range
        startDateOutOfRange: true,
        // Use startDate object to set a proxy date so
        // that timeline bar can render it.
        startDate: cloneDate(timeframeStartDate),
      });
    } else {
      Object.assign(roadmapItem, {
        // startDate is within range
        startDateOutOfRange: false,
        // Set startDate to original startDate
        startDate: cloneDate(roadmapItem.originalStartDate),
      });
    }
  } else {
    Object.assign(roadmapItem, {
      startDate: cloneDate(timeframeStartDate),
    });
  }

  if (!roadmapItem.endDateUndefined) {
    // If endDate is greater than last timeframe item
    if (roadmapItem.originalEndDate.getTime() > timeframeEndDate.getTime()) {
      Object.assign(roadmapItem, {
        // endDate is out of range
        endDateOutOfRange: true,
        // Use endDate object to set a proxy date so
        // that timeline bar can render it.
        endDate: cloneDate(timeframeEndDate),
      });
    } else {
      Object.assign(roadmapItem, {
        // startDate is within range
        endDateOutOfRange: false,
        // Set startDate to original startDate
        endDate: cloneDate(roadmapItem.originalEndDate),
      });
    }
  } else {
    Object.assign(roadmapItem, {
      endDate: cloneDate(timeframeEndDate),
    });
  }

  return roadmapItem;
};

/**
 * Constructs Epic or Milstone object with camelCase props and assigns proxy dates in case
 * start or end dates are unavailable.
 *
 * @param {Object} rawRoadmapItem (epic or milestone)
 * @param {Date} timeframeStartDate
 * @param {Date} timeframeEndDate
 */
export const formatRoadmapItemDetails = (rawRoadmapItem, timeframeStartDate, timeframeEndDate) => {
  const roadmapItem = convertObjectPropsToCamelCase(rawRoadmapItem);
  const rawStartDate = rawRoadmapItem.start_date || rawRoadmapItem.startDate;
  const rawEndDate = rawRoadmapItem.end_date || rawRoadmapItem.dueDate;

  if (rawStartDate) {
    // If startDate is present
    const startDate = newDate(rawStartDate);
    roadmapItem.startDate = startDate;
    roadmapItem.originalStartDate = startDate;
  } else {
    // startDate is not available
    roadmapItem.startDateUndefined = true;
  }

  if (rawEndDate) {
    // If endDate is present
    const endDate = newDate(rawEndDate);
    roadmapItem.endDate = endDate;
    roadmapItem.originalEndDate = endDate;
  } else {
    // endDate is not available
    roadmapItem.endDateUndefined = true;
  }

  processRoadmapItemDates(roadmapItem, timeframeStartDate, timeframeEndDate);

  return roadmapItem;
};

/**
 * Returns number representing index of last item of timeframe array
 *
 * @param {Array} timeframe
 */
export const lastTimeframeIndex = (timeframe) => timeframe.length - 1;

/**
 * Returns first item of the timeframe array
 *
 * @param {string} presetType
 * @param {Array} timeframe
 */
export const timeframeStartDate = (presetType, timeframe) => {
  if (presetType === PRESET_TYPES.QUARTERS) {
    return timeframe[0].range[0];
  }
  return timeframe[0];
};

/**
 * Returns last item of the timeframe array depending on preset type set.
 *
 * @param {string} presetType
 * @param {Array} timeframe
 */
export const timeframeEndDate = (presetType, timeframe) => {
  if (presetType === PRESET_TYPES.QUARTERS) {
    return timeframe[lastTimeframeIndex(timeframe)].range[2];
  }
  if (presetType === PRESET_TYPES.MONTHS) {
    return timeframe[lastTimeframeIndex(timeframe)];
  }
  const endDate = cloneDate(timeframe[lastTimeframeIndex(timeframe)]);
  endDate.setDate(endDate.getDate() + DAYS_IN_WEEK);
  return endDate;
};
