import {
  dateAtFirstDayOfMonth,
  nDaysBefore,
  nMonthsBefore,
  toISODateFormat,
} from '~/lib/utils/datetime_utility';
import { n__ } from '~/locale';
import { BUCKETING_INTERVAL_MONTHLY } from '~/analytics/shared/graphql/constants';
import {
  GENERIC_DASHBOARD_ERROR,
  UNSUPPORTED_PROJECT_NAMESPACE_ERROR,
  SUPPORTED_DORA_METRICS,
} from 'ee/analytics/dashboards/constants';
import { percentChange } from 'ee/analytics/dashboards/utils';
import GetGroupOrProjectQuery from '~/analytics/dashboards/graphql/get_group_or_project.query.graphql';
import DoraMetricsByProjectQuery from '~/analytics/dashboards/graphql/dora_metrics_by_project.query.graphql';
import { DORA_METRICS } from '~/analytics/shared/constants';
import { defaultClient } from '../graphql/client';

const calculateTrends = (previous, current) =>
  SUPPORTED_DORA_METRICS.reduce(
    (trends, id) => ({
      ...trends,
      [id]: percentChange({ current: current[id], previous: previous[id] }),
    }),
    {},
  );

const fetchAllProjects = async (params) => {
  const {
    data: {
      group: {
        projects: { count },
        dora: {
          projects: {
            nodes,
            pageInfo: { endCursor, hasNextPage },
          },
        },
      },
    },
  } = await defaultClient.query({
    query: DoraMetricsByProjectQuery,
    variables: {
      ...params,
      interval: BUCKETING_INTERVAL_MONTHLY,
    },
  });

  if (hasNextPage) {
    const { projects: nextNodes } = await fetchAllProjects({
      ...params,
      after: endCursor,
    });
    return {
      projects: [...nodes, ...nextNodes],
      count,
    };
  }

  return {
    projects: nodes,
    count,
  };
};

const formatProjects = (projects) =>
  projects.map(
    ({
      id,
      name,
      avatarUrl,
      webUrl,
      dora: {
        metrics: [pastMetrics, currentMetrics],
      },
    }) => ({
      id,
      name,
      avatarUrl,
      webUrl,
      trends: calculateTrends(pastMetrics, currentMetrics),
      ...currentMetrics,
    }),
  );

export const filterProjects = (projects) => {
  const hasData = (project) =>
    [
      project[DORA_METRICS.DEPLOYMENT_FREQUENCY],
      project[DORA_METRICS.LEAD_TIME_FOR_CHANGES],
      project[DORA_METRICS.TIME_TO_RESTORE_SERVICE],
      project[DORA_METRICS.CHANGE_FAILURE_RATE],
    ].some((value) => value !== null);

  return projects.filter(hasData);
};

export default async function fetch({ namespace, setAlerts, setVisualizationOverrides }) {
  const { data: namespaceReq } = await defaultClient.query({
    query: GetGroupOrProjectQuery,
    variables: {
      fullPath: namespace,
    },
  });

  const isProject = Boolean(namespaceReq?.project);

  if (isProject) {
    setAlerts({
      title: GENERIC_DASHBOARD_ERROR,
      errors: [UNSUPPORTED_PROJECT_NAMESPACE_ERROR],
      canRetry: false,
    });

    return undefined;
  }

  const thisMonth = dateAtFirstDayOfMonth(new Date());
  const endDate = nDaysBefore(thisMonth, 1);
  const startDate = nMonthsBefore(thisMonth, 2);

  const { projects, count } = await fetchAllProjects({
    startDate: toISODateFormat(startDate),
    endDate: toISODateFormat(endDate),
    fullPath: namespace,
  });

  const filteredProjects = filterProjects(formatProjects(projects));

  const shownProjectText = n__(
    'Showing %d project.',
    'Showing %d projects.',
    filteredProjects.length,
  );

  const excludedProjectText = n__(
    'Excluding %d project with no DORA metrics.',
    'Excluding %d projects with no DORA metrics.',
    Math.max(0, count - filteredProjects.length) || 0,
  );

  const visualizationOptionOverrides = {
    tooltip: {
      description: `${shownProjectText} ${excludedProjectText}`,
    },
  };

  setVisualizationOverrides({ visualizationOptionOverrides });

  return filteredProjects;
}
