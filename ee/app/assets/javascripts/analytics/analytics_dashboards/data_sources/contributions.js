import { CONTRIBUTIONS_METRICS } from 'ee/analytics/shared/constants';
import ContributionsQuery from 'ee/analytics/contribution_analytics/graphql/contributions.query.graphql';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import {
  filterPushes,
  mergeContributions,
  filterMergeRequests,
  filterIssues,
  restrictRequestEndDate,
} from 'ee/analytics/contribution_analytics/utils';
import { toISODateFormat } from '~/lib/utils/datetime_utility';
import { defaultClient } from '../graphql/client';

function limitPostgresqlRequests(dataSourceClickhouse, startDate, endDate) {
  if (dataSourceClickhouse) {
    // Don't modify request dates when using Clickhouse.
    return { endDate, nextStartDate: null };
  }

  // Limit the request dates when using PostgresQL to prevent
  // excessively large queries.
  return restrictRequestEndDate(startDate, endDate);
}

async function fetchContributions({
  namespace,
  startDate,
  endDate,
  nextPageCursor = '',
  contributions = [],
  dataSourceClickhouse,
}) {
  const { endDate: limitedEndDate, nextStartDate } = limitPostgresqlRequests(
    dataSourceClickhouse,
    startDate,
    endDate,
  );

  const rawQueryResult = await defaultClient.query({
    query: ContributionsQuery,
    variables: {
      fullPath: namespace,
      startDate,
      endDate: limitedEndDate,
      nextPageCursor,
    },
  });

  const resp = extractQueryResponseFromNamespace({
    result: rawQueryResult,
    resultKey: 'contributions',
  });

  const { nodes = [], pageInfo } = resp;

  const allContributions = mergeContributions(contributions, nodes);

  if (pageInfo?.hasNextPage) {
    return fetchContributions({
      namespace,
      startDate,
      endDate,
      nextPageCursor: pageInfo.endCursor,
      contributions: allContributions,
      dataSourceClickhouse,
    });
  }
  if (nextStartDate !== null) {
    return fetchContributions({
      namespace,
      startDate: nextStartDate,
      endDate,
      contributions: allContributions,
      dataSourceClickhouse,
    });
  }

  return allContributions;
}

const fetchContributionsQuery = async ({
  namespace,
  startDate,
  endDate,
  query,
  dataSourceClickhouse,
}) => {
  const contributions = await fetchContributions({
    namespace,
    startDate,
    endDate,
    dataSourceClickhouse,
  });
  const { metric } = query;
  if (metric === CONTRIBUTIONS_METRICS.PUSHES) {
    return filterPushes(contributions);
  }
  if (metric === CONTRIBUTIONS_METRICS.MERGE_REQUESTS) {
    return filterMergeRequests(contributions);
  }
  if (metric === CONTRIBUTIONS_METRICS.ISSUES) {
    return filterIssues(contributions);
  }
  return contributions;
};

export default async function fetch({ query, filters, namespace, dataSourceClickhouse }) {
  const { startDate, endDate } = filters;
  const contributions = await fetchContributionsQuery({
    namespace,
    startDate: toISODateFormat(startDate),
    endDate: toISODateFormat(endDate),
    query,
    dataSourceClickhouse,
  });
  return contributions;
}
