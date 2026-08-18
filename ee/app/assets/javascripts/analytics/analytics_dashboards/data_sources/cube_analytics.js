import { CubeApi, HttpTransport } from '@cubejs-client/core';
import {
  TODAY,
  SEVEN_DAYS_AGO,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { convertToSnakeCase } from '~/lib/utils/text_utility';
import { toISODateFormat } from '~/lib/utils/datetime_utility';
import csrf from '~/lib/utils/csrf';
import { joinPaths } from '~/lib/utils/url_utility';
import {
  EVENTS_TABLE_NAME,
  RETURNING_USERS_TABLE_NAME,
  SESSIONS_TABLE_NAME,
  TRACKED_EVENTS_KEY,
  VISUALIZATION_TYPE_DATA_TABLE,
  VISUALIZATION_TYPE_LINE_CHART,
  VISUALIZATION_TYPE_COLUMN_CHART,
  VISUALIZATION_TYPE_SINGLE_STAT,
} from 'ee/analytics/analytics_dashboards/constants';

// This can be any value because the cube proxy adds the real API token.
const CUBE_API_TOKEN = '1';
const PRODUCT_ANALYTICS_CUBE_PROXY = '/api/v4/projects/:id/product_analytics/request';
const CUBE_CONTINUE_WAIT_ERROR = 'Continue wait';

// Filter measurement types must be lowercase
export const DATE_RANGE_FILTER_DIMENSIONS = {
  [TRACKED_EVENTS_KEY]: `${EVENTS_TABLE_NAME}.derivedTstamp`,
  sessions: `${SESSIONS_TABLE_NAME}.startAt`,
  returningusers: `${RETURNING_USERS_TABLE_NAME}.first_timestamp`,
};

const convertToCommonChartFormat = (resultSet) => {
  const seriesNames = resultSet.seriesNames();
  const pivot = resultSet.chartPivot();

  return seriesNames.map((series) => ({
    name: series.title,
    data: pivot.map((p) => [p.x, p[series.key]]),
  }));
};

const findLinkOptions = (key, visualizationOptions) => {
  const links = visualizationOptions?.links;
  if (!links) return null;

  const normalizedLinks = links.map(({ text, href }) => ({ text, href: [href].flat() }));
  return normalizedLinks.find(({ text, href }) => [text, ...href].includes(key));
};

export const convertToTableFormat = (resultSet, _query, visualizationOptions) => {
  const columns = resultSet.tableColumns();
  const rows = resultSet.tablePivot();

  const columnTitles = Object.fromEntries(
    columns.map((column) => [column.key, convertToSnakeCase(column.shortTitle)]),
  );

  const nodes = rows.map((row) => {
    return Object.fromEntries(
      Object.entries(row)
        .map(([key, value]) => {
          const linkOptions = findLinkOptions(key, visualizationOptions);

          if (key === linkOptions?.text) {
            return [
              columnTitles[key],
              {
                text: value,
                href: joinPaths(...linkOptions.href.map((hrefPart) => row[hrefPart])),
              },
            ];
          }

          if (linkOptions?.href.includes(key)) {
            // Skipped because the href gets rendered as part of the link text column.
            return null;
          }

          return [columnTitles[key], value];
        })
        .filter(Boolean),
    );
  });
  return { nodes };
};

const convertToSingleValue = (resultSet, query) => {
  const [measure] = query?.measures ?? [];
  const [row] = resultSet.rawData();

  if (!row) {
    return 0;
  }

  return row[measure] ?? 0;
};

const getTableName = (query) => query.measures[0].split('.')[0];
const getQueryTableKey = (query) => getTableName(query).toLowerCase();

const getDynamicSchemaDateRangeDimension = (query) => {
  const tableName = getTableName(query);

  return `${tableName}.date`;
};

const getDateRangeDimension = (query) => {
  const tableKey = getQueryTableKey(query);

  return DATE_RANGE_FILTER_DIMENSIONS[tableKey] ?? getDynamicSchemaDateRangeDimension(query);
};

const buildDateRangeFilter = (query, { startDate, endDate }) => ({
  filters: [
    ...(query.filters ?? []),
    {
      member: getDateRangeDimension(query),
      operator: 'inDateRange',
      values: [toISODateFormat(startDate ?? SEVEN_DAYS_AGO), toISODateFormat(endDate ?? TODAY)],
    },
  ],
});

const buildAnonUsersFilter = (query, { filterAnonUsers }) => {
  if (!filterAnonUsers) return {};

  // knownUsers is only applicable on tracked events
  if (getQueryTableKey(query) !== TRACKED_EVENTS_KEY) return {};

  return {
    segments: [...(query.segments ?? []), 'TrackedEvents.knownUsers'],
  };
};

const buildCubeQuery = (query, filters) => ({
  ...query,
  ...buildDateRangeFilter(query, filters),
  ...buildAnonUsersFilter(query, filters),
});

const VISUALIZATION_PARSERS = {
  [VISUALIZATION_TYPE_LINE_CHART]: convertToCommonChartFormat,
  [VISUALIZATION_TYPE_COLUMN_CHART]: convertToCommonChartFormat,
  [VISUALIZATION_TYPE_DATA_TABLE]: convertToTableFormat,
  [VISUALIZATION_TYPE_SINGLE_STAT]: convertToSingleValue,
};

export const createCubeApi = (projectId) =>
  new CubeApi(CUBE_API_TOKEN, {
    transport: new HttpTransport({
      apiUrl: PRODUCT_ANALYTICS_CUBE_PROXY.replace(':id', projectId),
      method: 'POST',
      headers: {
        [csrf.headerKey]: csrf.token,
        'X-Requested-With': 'XMLHttpRequest',
      },
      credentials: 'same-origin',
    }),
  });

export const fetchFilterOptions = async (projectId) => {
  const cubeApi = createCubeApi(projectId);
  const { cubes = [] } = await cubeApi.meta({});

  let availableMeasures = [];
  let availableDimensions = [];
  let availableTimeDimensions = [];

  // Find all the measures, dimensions, and time dimensions by looping through each of the cube schemas
  // The difference between dimensions and time dimensions are whether they have the type of "time"
  cubes.forEach(({ dimensions, measures }) => {
    availableMeasures = [...availableMeasures, ...measures];
    availableDimensions = [...availableDimensions, ...dimensions.filter((d) => d.type !== 'time')];
    availableTimeDimensions = [
      ...availableTimeDimensions,
      ...dimensions.filter((d) => d.type === 'time'),
    ];
  });

  return { availableMeasures, availableDimensions, availableTimeDimensions };
};

export default async function fetch({
  projectId,
  visualizationType,
  visualizationOptions,
  query,
  filters = {},
  onRequestDelayed = () => {},
}) {
  const cubeApi = createCubeApi(projectId);

  const userQuery = buildCubeQuery(query, filters);
  const request = cubeApi.load(userQuery, {
    castNumerics: true,
    progressCallback: ({ progressResponse }) => {
      if (progressResponse?.error === CUBE_CONTINUE_WAIT_ERROR) {
        onRequestDelayed();
      }
    },
  });

  return request.then((resultSet) =>
    VISUALIZATION_PARSERS[visualizationType](resultSet, userQuery, visualizationOptions),
  );
}
