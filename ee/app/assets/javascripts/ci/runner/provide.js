import { runnersAppProvide as ceRunnersAppProvide } from '~/ci/runner/provide';

/**
 * Provides global values to the runners app.
 *
 * Includes a runnerDashboardPath, which is to be shown when the dashboard is
 * enabled.
 *
 * @param {Object} `data-` HTML attributes of the mounting point
 * @returns An object with properties to use provide/inject of the EE root app.
 */
export const runnersAppProvide = (elDataset) => {
  const { runnerDashboardPath } = elDataset;

  return {
    ...ceRunnersAppProvide(elDataset),
    runnerDashboardPath,
  };
};
