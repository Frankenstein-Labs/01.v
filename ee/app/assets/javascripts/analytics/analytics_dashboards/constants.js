import { humanizeTimeInterval } from '~/lib/utils/datetime_utility';
import { s__ } from '~/locale';
import { DORA_METRICS } from '~/analytics/shared/constants';
import { formatAsPercentage } from './components/visualizations/utils';

export const EVENTS_TABLE_NAME = 'TrackedEvents';
export const SESSIONS_TABLE_NAME = 'Sessions';
export const RETURNING_USERS_TABLE_NAME = 'ReturningUsers';

export const TRACKED_EVENTS_KEY = 'trackedevents';

export const DEFAULT_DASHBOARD_LOADING_ERROR = s__(
  'Analytics|Something went wrong while loading the dashboard. Refresh the page to try again.',
);
export const DASHBOARD_REFRESH_MESSAGE = s__('Analytics|Refresh the page to try again.');

export const EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD = 'user_viewed_custom_dashboard';
export const EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD = 'user_viewed_builtin_dashboard';
export const EVENT_LABEL_VIEWED_DASHBOARD = 'user_viewed_dashboard';

export const AI_IMPACT_TABLE_TRACKING_PROPERTY = 'ai_impact_table';
export const VSD_COMPARISON_TABLE_TRACKING_PROPERTY = 'vsd_comparison_table';

export const EVENT_LABEL_EXCLUDE_ANONYMISED_USERS = 'exclude_anonymised_users';

export {
  PANEL_TROUBLESHOOTING_URL,
  VISUALIZATION_DOCUMENTATION_LINKS,
  VISUALIZATION_SLUG_DORA_PERFORMERS_SCORE,
  VISUALIZATION_SLUG_DORA_PROJECTS_COMPARISON,
  VISUALIZATION_SLUG_VSD_DORA_METRICS_TABLE,
  VISUALIZATION_SLUG_VSD_SECURITY_METRICS_TABLE,
} from '~/analytics/shared/constants';

export const AI_IMPACT_DASHBOARD_LEGACY = 'ai_impact';
export const AI_IMPACT_DASHBOARD = 'duo_and_sdlc_trends';

// The URL name already in use is `value_streams_dashboard`,
// the slug name for a dashboard must match the URL path that is used
export const BUILT_IN_VALUE_STREAM_DASHBOARD = 'value_streams_dashboard';

export const DORA_METRICS_CHARTS_ADDITIONAL_OPTS = {
  [DORA_METRICS.DEPLOYMENT_FREQUENCY]: {},
  [DORA_METRICS.LEAD_TIME_FOR_CHANGES]: {
    yAxis: {
      minInterval: 1,
      axisLabel: {
        formatter(seconds) {
          return humanizeTimeInterval(seconds, { abbreviated: true });
        },
      },
    },
  },
  [DORA_METRICS.TIME_TO_RESTORE_SERVICE]: {
    yAxis: {
      minInterval: 1,
      axisLabel: {
        formatter(seconds) {
          return humanizeTimeInterval(seconds, { abbreviated: true });
        },
      },
    },
  },
  [DORA_METRICS.CHANGE_FAILURE_RATE]: {
    yAxis: {
      axisLabel: {
        formatter(value) {
          return formatAsPercentage(value);
        },
      },
    },
  },
};

export const VISUALIZATION_TYPE_DATA_TABLE = 'DataTable';
export const VISUALIZATION_TYPE_LINE_CHART = 'LineChart';
export const VISUALIZATION_TYPE_COLUMN_CHART = 'ColumnChart';
export const VISUALIZATION_TYPE_SINGLE_STAT = 'SingleStat';
