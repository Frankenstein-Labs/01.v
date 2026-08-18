import { DORA_PERFORMERS_SCORE_CATEGORIES } from './constants';
import { groupDoraPerformanceScoreCountsByCategory } from './utils';

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
 * Takes the raw Group.doraPerformanceScoreCounts graphql response and prepares the data for display
 * in the tiled column chart.
 *
 * @param {DoraPerformanceScoreCountItem[]} data
 * @returns {Array} DORA performance score counts ready for rendering in the tiled column chart
 */
export const extractDoraPerformanceScoreCounts = (data = []) => {
  const scoreCountsByCategory = groupDoraPerformanceScoreCountsByCategory(data);

  return Object.entries(DORA_PERFORMERS_SCORE_CATEGORIES).map(([category, label]) => ({
    name: label,
    data: scoreCountsByCategory[category] ?? [],
  }));
};
