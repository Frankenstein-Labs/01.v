import { DORA_PERFORMERS_SCORE_CATEGORY_TYPES } from './constants';

/**
 * @typedef {Object} DoraPerformanceScoreCountItem
 * @property {String} __typename - DoraPerformanceScoreCount
 * @property {String} metricName - Metric identifier
 * @property {Integer} lowProjectsCount - Count of projects that score 'low' on the metric
 * @property {Integer} mediumProjectsCount - Count of projects that score 'medium' on the metric
 * @property {Integer} highProjectsCount - Count of projects that score 'high' on the metric
 * @property {Integer} noDataProjectsCount - Count of projects that have no data
 */

/**
 * @typedef {Object} DoraPerformanceScoreCountsByCategory
 * @property {Array} lowProjectsCount - Array of all project counts with 'low' metric scores
 * @property {Array} mediumProjectsCount - Array of all project counts with 'medium' metric scores
 * @property {Array} highProjectsCount - Array of all project counts with 'high' metric scores
 * @property {Array} noDataProjectsCount - Array of all project counts with no data for their respective metric scores
 */

/**
 * Takes an array of DoraPerformanceScoreCount objects and returns a dictionary of
 * DORA performance score categories to an array of count values.
 *
 * For example, given the following array:
 * [
 *     {
 *       __typename: 'DoraPerformanceScoreCount',
 *       metricName: 'deployment_frequency',
 *       lowProjectsCount: 27,
 *       mediumProjectsCount: 24,
 *       highProjectsCount: 86,
 *       noDataProjectsCount: 1,
 *     },
 *     {
 *       __typename: 'DoraPerformanceScoreCount',
 *       metricName: 'lead_time_for_changes',
 *       lowProjectsCount: 25,
 *       mediumProjectsCount: 30,
 *       highProjectsCount: 75,
 *       noDataProjectsCount: 1,
 *     },
 *     ...
 * ]
 *
 * It will return the following object:
 *
 * {
 *   highProjectsCount: [86, 75],
 *   mediumProjectsCount: [24, 30],
 *   lowProjectsCount: [27, 25],
 *   noDataProjectsCount: [1, 1],
 * }
 *
 * @param {DoraPerformanceScoreCountItem[]} data - Array of DoraPerformanceScoreCount objects
 * @returns {DoraPerformanceScoreCountsByCategory} - A dictionary of each DORA performance score category with an array of count values
 */
export const groupDoraPerformanceScoreCountsByCategory = (data = []) => {
  const scoresCountsByCategory = {};
  const scoreCategoryTypes = Object.values(DORA_PERFORMERS_SCORE_CATEGORY_TYPES);

  scoreCategoryTypes.forEach((category) => {
    scoresCountsByCategory[category] = [];
  });

  data.forEach((scoreCount) => {
    scoreCategoryTypes.forEach((category) => {
      const scoreCounts = scoresCountsByCategory[category];

      scoresCountsByCategory[category] = [...scoreCounts, scoreCount[category]];
    });
  });

  return scoresCountsByCategory;
};

/**
 * Filters out any user-inputted project topic filters that
 * contain invalid characters.
 *
 * @param {Array} User-inputted project topic names
 * @returns {Array} Sanitized project topic names
 */
export const validateProjectTopics = (topics) =>
  Array.isArray(topics)
    ? topics.filter((topic) => !topic.match(/\n|\v|\f|\r|\u0085|\u2028|\u2029/))
    : [];
