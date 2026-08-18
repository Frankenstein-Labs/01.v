import { sum } from 'lodash-es';
import UserAiUserMetricsQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_user_ai_user_metrics.query.graphql';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import { DATE_RANGE_OPTION_LAST_30_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { hasAnyNonNullFields } from 'ee/analytics/shared/utils';
import { defaultClient } from '../graphql/client';

// We want to default to 10 items per page to keep the tables small
const PAGINATION_PAGE_SIZE = 10;

const extractFields = (obj, fields = []) =>
  fields.reduce((acc, field) => ({ ...acc, [field]: obj?.[field] ?? 0 }), {});

// Getters to simplify field extraction ready for the data table
const getDuoCodeReviewReactedFields = (codeReview) => {
  const fields = [
    'requestReviewDuoCodeReviewOnMrByAuthorEventCount',
    'reactThumbsDownOnDuoCodeReviewCommentEventCount',
    'reactThumbsUpOnDuoCodeReviewCommentEventCount',
  ];
  const {
    requestReviewDuoCodeReviewOnMrByAuthorEventCount,
    reactThumbsUpOnDuoCodeReviewCommentEventCount,
    reactThumbsDownOnDuoCodeReviewCommentEventCount,
  } = extractFields(codeReview, fields);
  return {
    requestReviewDuoCodeReviewOnMrByAuthorEventCount,
    duoCodeReviewCommentsReactedTo: sum([
      reactThumbsUpOnDuoCodeReviewCommentEventCount,
      reactThumbsDownOnDuoCodeReviewCommentEventCount,
    ]),
  };
};

const getCodeSuggestionsAcceptanceRateFields = (codeSuggestions) => {
  const fields = ['codeSuggestionAcceptedInIdeEventCount', 'codeSuggestionShownInIdeEventCount'];
  const { codeSuggestionAcceptedInIdeEventCount, codeSuggestionShownInIdeEventCount } =
    extractFields(codeSuggestions, fields);
  return {
    codeSuggestionAcceptedInIdeEventCount,
    codeSuggestionShownInIdeEventCount,
    codeSuggestionsAcceptanceRate: {
      numerator: codeSuggestionAcceptedInIdeEventCount,
      denominator: codeSuggestionShownInIdeEventCount,
    },
  };
};

const prepareAdditionalMetrics = ({ nodes = [], pageInfo = {}, ...rest }, pagination) => {
  // Since we are using `gl_introduced`, we need to check that the fields actually exist in the response
  if (
    !hasAnyNonNullFields(nodes, [
      'codeSuggestions',
      'codeReview',
      'troubleshootJob',
      'totalEventCount',
    ])
  ) {
    return {};
  }

  return {
    nodes: nodes.map(({ codeSuggestions, codeReview, troubleshootJob, ...nodeRest }) => ({
      ...extractFields(troubleshootJob, ['troubleshootJobEventCount']),
      ...getCodeSuggestionsAcceptanceRateFields(codeSuggestions),
      ...getDuoCodeReviewReactedFields(codeReview),
      ...nodeRest,
    })),
    pageInfo: {
      ...pagination,
      ...pageInfo,
    },
    ...rest,
  };
};

const SORTABLE_FIELD_KEYS = {
  requestReviewDuoCodeReviewOnMrByAuthorEventCount:
    'REQUEST_REVIEW_DUO_CODE_REVIEW_ON_MR_BY_AUTHOR',
  codeSuggestionShownInIdeEventCount: 'CODE_SUGGESTION_SHOWN_IN_IDE',
  codeSuggestionAcceptedInIdeEventCount: 'CODE_SUGGESTION_ACCEPTED_IN_IDE',
  troubleshootJobEventCount: 'TROUBLESHOOT_JOB_TOTAL_COUNT',
  totalEventCount: 'TOTAL_EVENTS_COUNT',
};

const constructSortKey = ({ sortBy, sortDesc }) => {
  if (SORTABLE_FIELD_KEYS[sortBy]) {
    const baseKey = SORTABLE_FIELD_KEYS[sortBy];
    return sortDesc ? `${baseKey}_DESC` : `${baseKey}_ASC`;
  }
  return null;
};

export default async function fetch({
  namespace: fullPath,
  query: { dateRange, sortBy, sortDesc, pagination = { first: PAGINATION_PAGE_SIZE } } = {},
  setVisualizationOverrides = () => {},
}) {
  const {
    startDate,
    endDate,
    text: subtitle,
  } = getDateRange(dateRange, DATE_RANGE_OPTION_LAST_30_DAYS);

  const response = await defaultClient.query({
    query: UserAiUserMetricsQuery,
    variables: {
      fullPath,
      startDate,
      endDate,
      first: pagination.first,
      last: pagination.last,
      before: pagination.startCursor,
      after: pagination.endCursor,
      sort: constructSortKey({ sortBy, sortDesc }),
    },
  });

  setVisualizationOverrides({
    visualizationOptionOverrides: { subtitle },
  });

  return prepareAdditionalMetrics(
    extractQueryResponseFromNamespace({
      result: response,
      resultKey: 'aiUserMetrics',
    }),
    pagination,
  );
}
