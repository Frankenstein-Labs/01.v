import {
  GL_COLOR_NEUTRAL_300,
  GL_COLOR_BLUE_400,
  GL_COLOR_ORANGE_200,
  GL_COLOR_RED_500,
} from '@gitlab/ui/src/tokens/build/js/tokens';
import { createIssueUrlWithDetails } from '~/observability/utils';

const COLORS_MAP = {
  trace: GL_COLOR_NEUTRAL_300,
  debug: GL_COLOR_NEUTRAL_300,
  info: GL_COLOR_BLUE_400,
  warn: GL_COLOR_ORANGE_200,
  error: GL_COLOR_RED_500,
  fatal: GL_COLOR_RED_500,
};

// See OTEL spec: https://opentelemetry.io/docs/specs/otel/logs/data-model/#displaying-severity
const severityConfig = [
  null, // severity-0 is not used
  { name: 'trace', color: COLORS_MAP.trace },
  { name: 'trace2', color: COLORS_MAP.trace },
  { name: 'trace3', color: COLORS_MAP.trace },
  { name: 'trace4', color: COLORS_MAP.trace },
  { name: 'debug', color: COLORS_MAP.debug },
  { name: 'debug2', color: COLORS_MAP.debug },
  { name: 'debug3', color: COLORS_MAP.debug },
  { name: 'debug4', color: COLORS_MAP.debug },
  { name: 'info', color: COLORS_MAP.info },
  { name: 'info2', color: COLORS_MAP.info },
  { name: 'info3', color: COLORS_MAP.info },
  { name: 'info4', color: COLORS_MAP.info },
  { name: 'warn', color: COLORS_MAP.warn },
  { name: 'warn2', color: COLORS_MAP.warn },
  { name: 'warn3', color: COLORS_MAP.warn },
  { name: 'warn4', color: COLORS_MAP.warn },
  { name: 'error', color: COLORS_MAP.error },
  { name: 'error2', color: COLORS_MAP.error },
  { name: 'error3', color: COLORS_MAP.error },
  { name: 'error4', color: COLORS_MAP.error },
  { name: 'fatal', color: COLORS_MAP.fatal },
  { name: 'fatal2', color: COLORS_MAP.fatal },
  { name: 'fatal3', color: COLORS_MAP.fatal },
  { name: 'fatal4', color: COLORS_MAP.fatal },
];

export const DEFAULT_SEVERITY_LEVELS = severityConfig.filter(Boolean).map(({ name }) => name);

export function severityNumberToConfig(severityNumber) {
  return severityConfig[severityNumber] || severityConfig[5]; // default to Debug;
}

export function createIssueUrlWithLogDetails({ log, createIssueUrl }) {
  const {
    trace_id: traceId,
    fingerprint,
    severity_number: severityNumber,
    service_name: service,
    timestamp,
    body: fullBody,
  } = log;

  // To reduce the chances of going over browser's URL max-length, we limit the log body
  const LOG_BODY_LIMIT = 1000;

  const truncatedSuffix = `[...]`;

  const body =
    fullBody.length > LOG_BODY_LIMIT
      ? `${fullBody.slice(0, LOG_BODY_LIMIT - truncatedSuffix.length)}${truncatedSuffix}`
      : fullBody;

  const logDetails = {
    body,
    fingerprint,
    fullUrl: window.location.href,
    service,
    severityNumber,
    timestamp,
    traceId,
  };

  return createIssueUrlWithDetails(createIssueUrl, logDetails, 'observability_log_details');
}
