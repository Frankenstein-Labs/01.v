import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlTooltip } from '@gitlab/ui';
import {
  FLOW_METRICS,
  DORA_METRICS,
  VULNERABILITY_METRICS,
  MERGE_REQUEST_METRICS,
  CONTRIBUTOR_METRICS,
  AI_METRICS,
  PIPELINE_ANALYTICS_METRICS,
} from '~/analytics/shared/constants';
import DoraMetricsQuery from '~/analytics/shared/graphql/dora_metrics.query.graphql';
import FlowMetricsQuery from '~/analytics/shared/graphql/flow_metrics.query.graphql';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  DASHBOARD_LOADING_FAILURE,
  SUPPORTED_DORA_METRICS,
  SUPPORTED_VULNERABILITY_METRICS,
  SUPPORTED_CONTRIBUTOR_METRICS,
  SUPPORTED_MERGE_REQUEST_METRICS,
  SUPPORTED_FLOW_METRICS,
  SUPPORTED_PIPELINE_ANALYTICS_METRICS,
  TREND_STYLE_ASC,
  TREND_STYLE_DESC,
} from 'ee/analytics/dashboards/constants';
import AggregatedPipelineMetricsQuery from '~/analytics/dashboards/graphql/get_aggregate_pipeline_metrics.query.graphql';
import VulnerabilitiesQuery from '~/analytics/dashboards/graphql/vulnerabilities.query.graphql';
import MergeRequestsQuery from '~/analytics/dashboards/graphql/merge_requests.query.graphql';
import ContributorCountQuery from '~/analytics/dashboards/graphql/contributor_count.query.graphql';
import AiMetricsQuery from '~/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import MetricTable from 'ee/analytics/dashboards/ai_impact/components/metric_table.vue';
import {
  SUPPORTED_AI_METRICS,
  AI_IMPACT_TABLE_METRICS,
} from 'ee/analytics/dashboards/ai_impact/constants';
import TrendIndicator from '~/analytics/dashboards/components/trend_indicator.vue';
import { setLanguage } from 'jest/__helpers__/locale_helper';
import { AI_IMPACT_TABLE_TRACKING_PROPERTY } from 'ee/analytics/analytics_dashboards/constants';
import MetricLabel from '~/analytics/analytics_dashboards/components/visualizations/data_table/metric_label.vue';
import TrendLine from '~/analytics/analytics_dashboards/components/visualizations/data_table/trend_line.vue';
import { useFakeDate } from 'helpers/fake_date';
import {
  mockGraphqlMergeRequestsResponse,
  mockGraphqlContributorCountResponse,
} from '../../helpers';
import { mockMergeRequestsResponseData, mockContributorCountResponseData } from '../../mock_data';
import {
  mockDoraMetricsResponse,
  mockFlowMetricsResponse,
  mockVulnerabilityMetricsResponse,
  mockAiMetricsResponse,
  mockAggregatedPipelineMetricsResponse,
} from '../helpers';
import {
  mockTableValues,
  mockTableBlankValues,
  mockTableZeroValues,
  mockTableMaxLimitValues,
  mockTableAndChartValues,
  mockAiTableAndChartValues,
} from '../mock_data';

const mockTypePolicy = {
  Query: { fields: { project: { merge: false }, group: { merge: false } } },
};
const mockGlAbilities = {
  readDora4Analytics: true,
  readCycleAnalytics: true,
  readSecurityResource: true,
};

Vue.use(VueApollo);

describe('Metric table', () => {
  let wrapper;

  const namespace = 'test-namespace';
  const metricLinks = Object.fromEntries(
    Object.keys(AI_IMPACT_TABLE_METRICS).map((identifier) => [
      identifier,
      `/groups/${namespace}/-/${identifier}`,
    ]),
  );

  const createMockApolloProvider = ({
    flowMetricsRequest = mockFlowMetricsResponse(mockTableAndChartValues),
    doraMetricsRequest = mockDoraMetricsResponse(mockTableAndChartValues),
    vulnerabilityMetricsRequest = mockVulnerabilityMetricsResponse(mockTableAndChartValues),
    mrMetricsRequest = mockGraphqlMergeRequestsResponse(mockMergeRequestsResponseData),
    contributorMetricsRequest = mockGraphqlContributorCountResponse(
      mockContributorCountResponseData,
    ),
    aiMetricsRequest = mockAiMetricsResponse(mockAiTableAndChartValues),
    pipelineMetricsRequest = mockAggregatedPipelineMetricsResponse(mockTableAndChartValues),
  } = {}) => {
    return createMockApollo(
      [
        [FlowMetricsQuery, flowMetricsRequest],
        [DoraMetricsQuery, doraMetricsRequest],
        [VulnerabilitiesQuery, vulnerabilityMetricsRequest],
        [MergeRequestsQuery, mrMetricsRequest],
        [ContributorCountQuery, contributorMetricsRequest],
        [AiMetricsQuery, aiMetricsRequest],
        [AggregatedPipelineMetricsQuery, pipelineMetricsRequest],
      ],
      {},
      {
        typePolicies: mockTypePolicy,
      },
    );
  };

  const createWrapper = (
    metricIds,
    {
      props = {},
      glAbilities = {},
      glFeatures = {},
      dataSourceClickhouse = true,
      apolloProvider = createMockApolloProvider(),
    } = {},
  ) => {
    wrapper = mountExtended(MetricTable, {
      apolloProvider,
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        namespace,
        metricLinks,
        includeMetrics: Object.keys(AI_IMPACT_TABLE_METRICS).filter((id) => metricIds.includes(id)),
        ...props,
      },
      provide: {
        dataSourceClickhouse,
        glAbilities: {
          ...mockGlAbilities,
          ...glAbilities,
        },
        glFeatures: {
          ...glFeatures,
        },
      },
    });

    return waitForPromises();
  };

  const metricIdToTestId = (identifier) => `ai-impact-metric-${identifier.replaceAll('_', '-')}`;

  const findTableRow = (metricId) => wrapper.findByTestId(metricIdToTestId(metricId));
  const findMetricLabel = (metricId) => findTableRow(metricId).findComponent(MetricLabel);
  const findValueTableCells = (metricId) =>
    findTableRow(metricId).findAll(`[data-testid="ai-impact-table-value-cell"]`);
  const findTrendIndicator = (metricId) => findTableRow(metricId).findComponent(TrendIndicator);
  const findTrendLineChart = (metricId) => findTableRow(metricId).findComponent(TrendLine);
  const findSkeletonLoaders = (metricId) =>
    wrapper.findAll(
      `[data-testid="${metricIdToTestId(metricId)}"] [data-testid="metric-skeleton-loader"]`,
    );
  const findChartSkeletonLoader = (metricId) =>
    wrapper.find(
      `[data-testid="${metricIdToTestId(metricId)}"] [data-testid="metric-chart-skeleton"]`,
    );
  const findMetricNoChangeLabel = (metricId) =>
    wrapper.find(
      `[data-testid="${metricIdToTestId(metricId)}"] [data-testid="metric-cell-no-change"]`,
    );
  const findMetricNoChangeTooltip = (metricId) =>
    getBinding(findMetricNoChangeLabel(metricId).element, 'gl-tooltip');

  beforeEach(() => {
    // Needed due to a deprecation in the GlSparkline API:
    // https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2119 [CLOSED]
    // eslint-disable-next-line no-console
    console.warn = jest.fn();
  });

  describe.each`
    identifier                                     | hasLink  | trackingProperty
    ${DORA_METRICS.DEPLOYMENT_FREQUENCY}           | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${DORA_METRICS.LEAD_TIME_FOR_CHANGES}          | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${DORA_METRICS.TIME_TO_RESTORE_SERVICE}        | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${DORA_METRICS.CHANGE_FAILURE_RATE}            | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${FLOW_METRICS.CYCLE_TIME}                     | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${FLOW_METRICS.LEAD_TIME}                      | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${FLOW_METRICS.ISSUES}                         | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${FLOW_METRICS.ISSUES_COMPLETED}               | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${FLOW_METRICS.DEPLOYS}                        | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${FLOW_METRICS.MEDIAN_TIME_TO_MERGE}           | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${VULNERABILITY_METRICS.CRITICAL}              | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${VULNERABILITY_METRICS.HIGH}                  | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${MERGE_REQUEST_METRICS.THROUGHPUT}            | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${CONTRIBUTOR_METRICS.COUNT}                   | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${AI_METRICS.CODE_SUGGESTIONS_USERS_COUNT}     | ${false} | ${''}
    ${AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE} | ${false} | ${''}
    ${AI_METRICS.DUO_CHAT_USERS_COUNT}             | ${false} | ${''}
    ${AI_METRICS.DUO_RCA_USERS_COUNT}              | ${false} | ${''}
    ${AI_METRICS.DUO_REVIEW_REQUESTS_COUNT}        | ${false} | ${''}
    ${AI_METRICS.DUO_REVIEW_COMMENT_COUNT}         | ${false} | ${''}
    ${AI_METRICS.DUO_AGENT_PLATFORM_FLOWS}         | ${false} | ${''}
    ${AI_METRICS.DUO_AGENT_PLATFORM_CHATS}         | ${false} | ${''}
    ${PIPELINE_ANALYTICS_METRICS.COUNT}            | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${PIPELINE_ANALYTICS_METRICS.MEDIAN}           | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${PIPELINE_ANALYTICS_METRICS.SUCCESS_RATE}     | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${PIPELINE_ANALYTICS_METRICS.FAILURE_RATE}     | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
    ${PIPELINE_ANALYTICS_METRICS.OTHER_RATE}       | ${true}  | ${AI_IMPACT_TABLE_TRACKING_PROPERTY}
  `('for the $identifier table row', ({ identifier, hasLink, trackingProperty }) => {
    beforeEach(() => {
      createWrapper([identifier]);
    });

    it('renders the metric name', () => {
      const link = hasLink ? metricLinks[identifier] : '';
      expect(findMetricLabel(identifier).props()).toEqual(
        expect.objectContaining({ identifier, link, trackingProperty }),
      );
    });
  });

  describe.each`
    identifier                                     | name
    ${DORA_METRICS.DEPLOYMENT_FREQUENCY}           | ${'Deployment frequency'}
    ${DORA_METRICS.LEAD_TIME_FOR_CHANGES}          | ${'Lead time for changes'}
    ${DORA_METRICS.TIME_TO_RESTORE_SERVICE}        | ${'Time to restore service'}
    ${DORA_METRICS.CHANGE_FAILURE_RATE}            | ${'Change failure rate'}
    ${FLOW_METRICS.CYCLE_TIME}                     | ${'Cycle time'}
    ${FLOW_METRICS.LEAD_TIME}                      | ${'Lead time'}
    ${FLOW_METRICS.ISSUES}                         | ${'Issues created'}
    ${FLOW_METRICS.ISSUES_COMPLETED}               | ${'Issues closed'}
    ${FLOW_METRICS.DEPLOYS}                        | ${'Deploys'}
    ${FLOW_METRICS.MEDIAN_TIME_TO_MERGE}           | ${'Median time to merge'}
    ${VULNERABILITY_METRICS.CRITICAL}              | ${'Critical vulnerabilities over time'}
    ${VULNERABILITY_METRICS.HIGH}                  | ${'High vulnerabilities over time'}
    ${MERGE_REQUEST_METRICS.THROUGHPUT}            | ${'Merge request throughput'}
    ${CONTRIBUTOR_METRICS.COUNT}                   | ${'Contributor count'}
    ${AI_METRICS.DUO_USED_COUNT}                   | ${'Feature usage'}
    ${AI_METRICS.CODE_SUGGESTIONS_USERS_COUNT}     | ${'Code Suggestions usage'}
    ${AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE} | ${'Code Suggestions acceptance rate'}
    ${AI_METRICS.DUO_CHAT_USERS_COUNT}             | ${'Chat (non-agentic) usage'}
    ${AI_METRICS.DUO_RCA_USERS_COUNT}              | ${'Root Cause Analysis usage'}
    ${AI_METRICS.DUO_REVIEW_REQUESTS_COUNT}        | ${'Code Review requests'}
    ${AI_METRICS.DUO_REVIEW_COMMENT_COUNT}         | ${'Code Review comments'}
    ${AI_METRICS.DUO_AGENT_PLATFORM_FLOWS}         | ${'Agent Platform flows'}
    ${AI_METRICS.DUO_AGENT_PLATFORM_CHATS}         | ${'Agent Platform chats'}
    ${PIPELINE_ANALYTICS_METRICS.COUNT}            | ${'Total pipeline runs'}
    ${PIPELINE_ANALYTICS_METRICS.MEDIAN}           | ${'Median duration'}
    ${PIPELINE_ANALYTICS_METRICS.SUCCESS_RATE}     | ${'Success rate'}
    ${PIPELINE_ANALYTICS_METRICS.FAILURE_RATE}     | ${'Failure rate'}
    ${PIPELINE_ANALYTICS_METRICS.OTHER_RATE}       | ${'Other'}
  `('for the $identifier table row', ({ identifier, name }) => {
    describe('when loading data', () => {
      beforeEach(() => {
        createWrapper([identifier]);
      });

      it('renders a skeleton loader in each cell', () => {
        // Metric count + 1 for the trend indicator
        const loadingCellCount = Object.keys(mockTableValues).length + 1;
        expect(findSkeletonLoaders(identifier)).toHaveLength(loadingCellCount);
      });

      it('renders a skeleton loader for the sparkline chart', () => {
        expect(findChartSkeletonLoader(identifier).exists()).toBe(true);
      });
    });

    describe('when the data fails to load', () => {
      beforeEach(() => {
        return createWrapper([identifier], {
          apolloProvider: createMockApolloProvider({
            flowMetricsRequest: jest.fn().mockRejectedValue({}),
            doraMetricsRequest: jest.fn().mockRejectedValue({}),
            vulnerabilityMetricsRequest: jest.fn().mockRejectedValue({}),
            mrMetricsRequest: jest.fn().mockRejectedValue({}),
            contributorMetricsRequest: jest.fn().mockRejectedValue({}),
            aiMetricsRequest: jest.fn().mockRejectedValue({}),
            pipelineMetricsRequest: jest.fn().mockRejectedValue({}),
          }),
        });
      });

      it('emits `set-alerts` with table warnings', () => {
        expect(wrapper.emitted('set-alerts')).toHaveLength(1);
        expect(wrapper.emitted('set-alerts')[0][0].warnings).toHaveLength(1);
      });

      it('lists name of the failed metric in the table metrics warning', () => {
        const [tableMetrics] = wrapper.emitted('set-alerts')[0][0].warnings;
        expect(tableMetrics).toContain(DASHBOARD_LOADING_FAILURE);
        expect(tableMetrics).toContain(name);
      });
    });

    describe('when the data is loaded', () => {
      useFakeDate('2024-01-01');

      beforeEach(() => {
        return createWrapper([identifier]);
      });

      it('does not render loading skeletons', () => {
        expect(findSkeletonLoaders(identifier)).toHaveLength(0);

        expect(findChartSkeletonLoader(identifier).exists()).toBe(false);
      });

      it('renders the metric values', () => {
        const metricCells = findValueTableCells(identifier).wrappers;
        expect(metricCells.map((w) => w.text().replace(/\s+/g, ' '))).toMatchSnapshot();
      });

      it('renders the sparkline chart with expected props', () => {
        expect(findTrendLineChart(identifier).exists()).toBe(true);
        expect(findTrendLineChart(identifier).props()).toMatchSnapshot();
      });
    });
  });

  describe.each`
    identifier                                 | startDate
    ${AI_METRICS.CODE_SUGGESTIONS_USERS_COUNT} | ${'2024-07-15'}
    ${AI_METRICS.DUO_RCA_USERS_COUNT}          | ${'2025-07-15'}
    ${AI_METRICS.DUO_AGENT_PLATFORM_FLOWS}     | ${'2025-09-01'}
    ${AI_METRICS.DUO_AGENT_PLATFORM_CHATS}     | ${'2025-09-01'}
  `('for the $identifier table row', ({ identifier, startDate }) => {
    useFakeDate(startDate);

    beforeEach(() => {
      return createWrapper([identifier]);
    });

    it('renders the correct metric values and tooltips pre- and post-release', () => {
      const metricCells = findValueTableCells(identifier).wrappers;
      expect(metricCells.map((w) => w.text().replace(/\s+/g, ' '))).toMatchSnapshot();
    });
  });

  describe('change %', () => {
    describe('when there is no data', () => {
      beforeEach(() => {
        return createWrapper([DORA_METRICS.DEPLOYMENT_FREQUENCY], {
          apolloProvider: createMockApolloProvider({
            doraMetricsRequest: mockDoraMetricsResponse(mockTableBlankValues),
          }),
        });
      });

      it('renders n/a instead of a percentage', () => {
        expect(findMetricNoChangeLabel(DORA_METRICS.DEPLOYMENT_FREQUENCY).text()).toBe('n/a');
      });

      it('renders a tooltip on the change cell', () => {
        expect(findMetricNoChangeTooltip(DORA_METRICS.DEPLOYMENT_FREQUENCY).value).toBe(
          'No data available',
        );
      });
    });

    describe('when there is blank data', () => {
      beforeEach(() => {
        return createWrapper([DORA_METRICS.DEPLOYMENT_FREQUENCY], {
          apolloProvider: createMockApolloProvider({
            doraMetricsRequest: mockDoraMetricsResponse(mockTableZeroValues),
          }),
        });
      });

      it('renders n/a instead of a percentage', () => {
        expect(findMetricNoChangeLabel(DORA_METRICS.DEPLOYMENT_FREQUENCY).text()).toBe('0.0%');
      });

      it('renders a tooltip on the change cell', () => {
        expect(findMetricNoChangeTooltip(DORA_METRICS.DEPLOYMENT_FREQUENCY).value).toBe(
          'No change',
        );
      });
    });

    describe('when there is a change', () => {
      beforeEach(() => {
        return createWrapper([DORA_METRICS.DEPLOYMENT_FREQUENCY, DORA_METRICS.CHANGE_FAILURE_RATE]);
      });

      it('does not invert the trend indicator for ascending metrics', () => {
        expect(findTrendIndicator(DORA_METRICS.DEPLOYMENT_FREQUENCY).props().change).toBe(1);
        expect(findTrendIndicator(DORA_METRICS.DEPLOYMENT_FREQUENCY).props().trendStyle).toBe(
          TREND_STYLE_ASC,
        );
      });

      it('inverts the trend indicator for declining metrics', () => {
        expect(findTrendIndicator(DORA_METRICS.CHANGE_FAILURE_RATE).props().change).toBe(1);
        expect(findTrendIndicator(DORA_METRICS.CHANGE_FAILURE_RATE).props().trendStyle).toBe(
          TREND_STYLE_DESC,
        );
      });
    });
  });

  describe('metric tooltips', () => {
    const hoverClasses = ['gl-cursor-pointer', 'hover:gl-underline'];

    beforeEach(() => {
      return createWrapper([AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE, FLOW_METRICS.LEAD_TIME]);
    });

    it('adds hover class and tooltip to code suggestions acceptance rate metric', () => {
      const metricCell = findValueTableCells(AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE).at(0);
      const metricValue = metricCell.find('[data-testid="formatted-metric-value"]');

      expect(metricCell.findComponent(GlTooltip).exists()).toBe(true);
      expect(metricValue.classes().some((c) => hoverClasses.includes(c))).toBe(true);
    });

    it('does not add hover class and tooltip to other metrics', () => {
      const metricCell = findValueTableCells(FLOW_METRICS.LEAD_TIME).at(0);
      const metricValue = metricCell.find('[data-testid="formatted-metric-value"]');

      expect(metricCell.findComponent(GlTooltip).exists()).toBe(false);
      expect(metricValue.classes().some((c) => hoverClasses.includes(c))).toBe(false);
    });
  });

  describe('when value has exceeded maximum value', () => {
    beforeEach(() => {
      return createWrapper([FLOW_METRICS.ISSUES_COMPLETED], {
        apolloProvider: createMockApolloProvider({
          flowMetricsRequest: mockFlowMetricsResponse(mockTableMaxLimitValues),
        }),
      });
    });

    it('displays correct value', () => {
      const metricCell = findValueTableCells(FLOW_METRICS.ISSUES_COMPLETED).at(0);
      const metricValue = metricCell.find('[data-testid="formatted-metric-value"]');

      expect(metricValue.text()).toBe('10000+');
    });

    it(`should render value limit info icon with tooltip`, () => {
      const metricCell = findValueTableCells(FLOW_METRICS.ISSUES_COMPLETED).at(0);

      const metricIcon = metricCell.find('[data-testid="metric-max-value-info-icon"]');
      expect(metricIcon.exists()).toBe(true);
      expect(getBinding(metricIcon.element, 'gl-tooltip')).toBeDefined();
      expect(metricIcon.attributes('title')).toBe(
        'This is a lower-bound approximation. Your group has too many issues and MRs to calculate in real time.',
      );
    });
  });

  describe('restricted metrics', () => {
    beforeEach(() => {
      return createWrapper(Object.values(DORA_METRICS), {
        glAbilities: { readDora4Analytics: false },
      });
    });

    it.each(Object.values(DORA_METRICS))('does not render the `%s` metric', (identifier) => {
      expect(findTableRow(identifier).exists()).toBe(false);
    });

    it('emits `set-alerts` warning with the restricted metrics', () => {
      expect(wrapper.emitted('set-alerts')).toHaveLength(1);
      expect(wrapper.emitted('set-alerts')[0][0]).toEqual({
        canRetry: false,
        warnings: [],
        alerts: expect.arrayContaining([
          'You have insufficient permissions to view: Deployment frequency, Lead time for changes, Time to restore service, Change failure rate',
        ]),
      });
    });
  });

  describe('when ClickHouse is not available', () => {
    const contributorMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());

    beforeEach(() => {
      return createWrapper([CONTRIBUTOR_METRICS.COUNT], {
        dataSourceClickhouse: false,
        apolloProvider: createMockApolloProvider({ contributorMetricsRequest }),
      });
    });

    it('does not render the contributor count metric', () => {
      expect(findTableRow(CONTRIBUTOR_METRICS.COUNT).exists()).toBe(false);
    });

    it('does not request contributor count data', () => {
      expect(contributorMetricsRequest).not.toHaveBeenCalled();
    });

    it('does not emit a `set-alerts` warning for the contributor count metric', () => {
      expect(wrapper.emitted('set-alerts')).toBeUndefined();
    });
  });

  describe('metrics filters', () => {
    const flowMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    const doraMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    const vulnerabilityMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    const mrMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    const contributorMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    const aiMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    const pipelineMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
    let apolloProvider;

    beforeEach(() => {
      apolloProvider = createMockApolloProvider({
        flowMetricsRequest,
        doraMetricsRequest,
        vulnerabilityMetricsRequest,
        mrMetricsRequest,
        contributorMetricsRequest,
        aiMetricsRequest,
        pipelineMetricsRequest,
      });
    });

    const metricGroups = [
      {
        group: 'DORA metrics',
        metrics: SUPPORTED_DORA_METRICS,
        apiRequest: doraMetricsRequest,
      },
      {
        group: 'Flow metrics',
        metrics: SUPPORTED_FLOW_METRICS,
        apiRequest: flowMetricsRequest,
      },
      {
        group: 'Vulnerability metrics',
        metrics: SUPPORTED_VULNERABILITY_METRICS,
        apiRequest: vulnerabilityMetricsRequest,
      },
      {
        group: 'MR metrics',
        metrics: SUPPORTED_MERGE_REQUEST_METRICS,
        apiRequest: mrMetricsRequest,
      },
      {
        group: 'Contribution metrics',
        metrics: SUPPORTED_CONTRIBUTOR_METRICS,
        apiRequest: contributorMetricsRequest,
      },
      {
        group: 'AI metrics',
        metrics: SUPPORTED_AI_METRICS,
        apiRequest: aiMetricsRequest,
      },
      {
        group: 'Pipeline metrics',
        metrics: SUPPORTED_PIPELINE_ANALYTICS_METRICS,
        apiRequest: pipelineMetricsRequest,
      },
    ];

    describe('`includeMetrics` set', () => {
      const [selectedMetricGroup, ...omittedMetricGroups] = metricGroups;
      const {
        group: selectedMetricGroupTitle,
        metrics: selectedMetricGroupMetrics,
        apiRequest: selectedMetricGroupRequest,
      } = selectedMetricGroup;
      const [includedMetric, ...omittedMetrics] = selectedMetricGroupMetrics;

      beforeEach(() => {
        return createWrapper([], {
          apolloProvider,
          props: { includeMetrics: [includedMetric] },
        });
      });

      describe(`for included ${selectedMetricGroupTitle}`, () => {
        it(`renders included \`${includedMetric}\``, () => {
          expect(findTableRow(includedMetric).exists()).toBe(true);
        });

        it.each(omittedMetrics)('does not render omitted `%s`', (identifier) => {
          expect(findTableRow(identifier).exists()).toBe(false);
        });

        it(`requests metrics`, () => {
          expect(selectedMetricGroupRequest).toHaveBeenCalled();
        });
      });

      describe.each(omittedMetricGroups)('for omitted $group', ({ metrics, apiRequest }) => {
        it.each(metrics)('does not render `%s`', (identifier) => {
          expect(findTableRow(identifier).exists()).toBe(false);
        });

        it('does not send a request', () => {
          expect(apiRequest).not.toHaveBeenCalled();
        });
      });

      describe('`excludeMetrics` is also set', () => {
        beforeEach(() => {
          return createWrapper([], {
            apolloProvider,
            props: {
              includeMetrics: selectedMetricGroupMetrics,
              excludeMetrics: selectedMetricGroupMetrics,
            },
          });
        });

        it.each(selectedMetricGroupMetrics)(
          'renders `%s`, taking priority over `excludeMetrics`',
          (identifier) => {
            expect(findTableRow(identifier).exists()).toBe(true);
          },
        );

        it('requests metrics', () => {
          expect(selectedMetricGroupRequest).toHaveBeenCalled();
        });
      });
    });

    describe('`excludeMetrics` set', () => {
      describe.each(metricGroups)('for $group', ({ metrics, apiRequest }) => {
        describe('when all metrics excluded', () => {
          beforeEach(() => {
            return createWrapper([], {
              apolloProvider,
              props: { includeMetrics: [], excludeMetrics: metrics },
            });
          });

          it.each(metrics)('does not render `%s`', (identifier) => {
            expect(findTableRow(identifier).exists()).toBe(false);
          });

          it('does not send a request', () => {
            expect(apiRequest).not.toHaveBeenCalled();
          });
        });

        describe('when almost all metrics excluded', () => {
          beforeEach(() => {
            return createWrapper([], {
              apolloProvider,
              props: { includeMetrics: [], excludeMetrics: metrics.slice(1) },
            });
          });

          it('requests metrics', () => {
            expect(apiRequest).toHaveBeenCalled();
          });
        });
      });
    });

    describe('neither `includeMetrics` nor `excludeMetrics` are set', () => {
      beforeEach(() => {
        return createWrapper([], {
          apolloProvider,
          props: { includeMetrics: [], excludeMetrics: [] },
        });
      });

      describe.each(metricGroups)('for $group', ({ metrics, apiRequest }) => {
        it.each(metrics)('renders `%s`', (identifier) => {
          expect(findTableRow(identifier).exists()).toBe(true);
        });

        it('requests metrics', () => {
          expect(apiRequest).toHaveBeenCalled();
        });
      });
    });
  });

  describe('skip requests for unused metrics', () => {
    it.each`
      identifier                              | skipParam
      ${DORA_METRICS.DEPLOYMENT_FREQUENCY}    | ${'skipDeploymentFrequency'}
      ${DORA_METRICS.LEAD_TIME_FOR_CHANGES}   | ${'skipLeadTimeForChanges'}
      ${DORA_METRICS.CHANGE_FAILURE_RATE}     | ${'skipChangeFailureRate'}
      ${DORA_METRICS.TIME_TO_RESTORE_SERVICE} | ${'skipTimeToRestoreService'}
    `('for $identifier', async ({ identifier, skipParam }) => {
      const doraMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
      const apolloProvider = createMockApolloProvider({ doraMetricsRequest });

      await createWrapper([], {
        apolloProvider,
        props: { includeMetrics: SUPPORTED_DORA_METRICS.filter((metric) => metric !== identifier) },
      });

      expect(doraMetricsRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          skipDeploymentFrequency: false,
          skipLeadTimeForChanges: false,
          skipChangeFailureRate: false,
          skipTimeToRestoreService: false,
          [skipParam]: true,
        }),
      );
    });

    it.each`
      identifier                           | skipParam
      ${FLOW_METRICS.CYCLE_TIME}           | ${'skipCycleTime'}
      ${FLOW_METRICS.LEAD_TIME}            | ${'skipLeadTime'}
      ${FLOW_METRICS.ISSUES}               | ${'skipIssueCount'}
      ${FLOW_METRICS.ISSUES_COMPLETED}     | ${'skipIssuesCompletedCount'}
      ${FLOW_METRICS.DEPLOYS}              | ${'skipDeploymentCount'}
      ${FLOW_METRICS.MEDIAN_TIME_TO_MERGE} | ${'skipTimeToMerge'}
    `('for $identifier', async ({ identifier, skipParam }) => {
      const flowMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
      const apolloProvider = createMockApolloProvider({ flowMetricsRequest });

      await createWrapper([], {
        apolloProvider,
        props: { includeMetrics: SUPPORTED_FLOW_METRICS.filter((metric) => metric !== identifier) },
      });

      expect(flowMetricsRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          skipCycleTime: false,
          skipLeadTime: false,
          skipIssueCount: false,
          skipIssuesCompletedCount: false,
          skipDeploymentCount: false,
          skipTimeToMerge: false,
          [skipParam]: true,
        }),
      );
    });

    it.each`
      identifier                        | skipParam
      ${VULNERABILITY_METRICS.CRITICAL} | ${'skipCritical'}
      ${VULNERABILITY_METRICS.HIGH}     | ${'skipHigh'}
    `('for $identifier', async ({ identifier, skipParam }) => {
      const vulnerabilityMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
      const apolloProvider = createMockApolloProvider({ vulnerabilityMetricsRequest });

      await createWrapper([], {
        apolloProvider,
        props: {
          includeMetrics: SUPPORTED_VULNERABILITY_METRICS.filter((metric) => metric !== identifier),
        },
      });

      expect(vulnerabilityMetricsRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          skipCritical: false,
          skipHigh: false,
          [skipParam]: true,
        }),
      );
    });

    const pipelineCountMetrics = [
      PIPELINE_ANALYTICS_METRICS.COUNT,
      PIPELINE_ANALYTICS_METRICS.SUCCESS_RATE,
      PIPELINE_ANALYTICS_METRICS.FAILURE_RATE,
      PIPELINE_ANALYTICS_METRICS.OTHER_RATE,
    ];
    const pipelineCountSkipParams = [
      'skipPipelineCount',
      'skipPipelineSuccessRate',
      'skipPipelineFailureRate',
      'skipPipelineOtherRate',
    ];
    it.each`
      identifiers                                  | skipParams
      ${pipelineCountMetrics}                      | ${pipelineCountSkipParams}
      ${[PIPELINE_ANALYTICS_METRICS.SUCCESS_RATE]} | ${['skipPipelineSuccessRate']}
      ${[PIPELINE_ANALYTICS_METRICS.FAILURE_RATE]} | ${['skipPipelineFailureRate']}
      ${[PIPELINE_ANALYTICS_METRICS.OTHER_RATE]}   | ${['skipPipelineOtherRate']}
      ${[PIPELINE_ANALYTICS_METRICS.MEDIAN]}       | ${['skipPipelineMedian']}
    `('for $identifiers', async ({ identifiers, skipParams }) => {
      const pipelineMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
      const apolloProvider = createMockApolloProvider({ pipelineMetricsRequest });

      await createWrapper([], {
        apolloProvider,
        props: {
          includeMetrics: SUPPORTED_PIPELINE_ANALYTICS_METRICS.filter(
            (metric) => !identifiers.includes(metric),
          ),
        },
      });

      expect(pipelineMetricsRequest).toHaveBeenCalledWith(
        expect.objectContaining(
          skipParams.reduce(
            (acc, skipParam) => ({
              ...acc,
              [skipParam]: true,
            }),
            {
              skipPipelineCount: false,
              skipPipelineSuccessRate: false,
              skipPipelineFailureRate: false,
              skipPipelineOtherRate: false,
              skipPipelineMedian: false,
            },
          ),
        ),
      );
    });

    it.each`
      identifiers                                  | skipParams
      ${[AI_METRICS.CODE_SUGGESTIONS_USERS_COUNT]} | ${['skipCodeSuggestionsUsersCount']}
      ${[AI_METRICS.DUO_RCA_USERS_COUNT]}          | ${['skipRcaUsersCount']}
      ${[AI_METRICS.DUO_CHAT_USERS_COUNT]}         | ${['skipChatContributorsCount']}
      ${[AI_METRICS.DUO_USED_COUNT]}               | ${['skipUsedCount']}
      ${[AI_METRICS.DUO_REVIEW_REQUESTS_COUNT]}    | ${['skipReviewRequestsCount']}
      ${[AI_METRICS.DUO_REVIEW_COMMENT_COUNT]}     | ${['skipReviewCommentCount']}
      ${[AI_METRICS.DUO_AGENT_PLATFORM_CHATS]}     | ${['skipAgentPlatformChats']}
      ${[AI_METRICS.DUO_AGENT_PLATFORM_FLOWS]}     | ${['skipAgentPlatformFlows']}
    `('for $identifiers', async ({ identifiers, skipParams }) => {
      const aiMetricsRequest = jest.fn().mockImplementation(() => Promise.resolve());
      const apolloProvider = createMockApolloProvider({ aiMetricsRequest });

      await createWrapper([], {
        apolloProvider,
        props: {
          includeMetrics: SUPPORTED_AI_METRICS.filter((metric) => !identifiers.includes(metric)),
        },
      });

      expect(aiMetricsRequest).toHaveBeenCalledWith(
        expect.objectContaining(
          skipParams.reduce(
            (acc, skipParam) => ({
              ...acc,
              [skipParam]: true,
            }),
            {
              skipCodeSuggestionsUsersCount: false,
              skipCodeSuggestionsAcceptanceRate: false,
              skipRcaUsersCount: false,
              skipChatContributorsCount: false,
              skipUsedCount: false,
              skipReviewRequestsCount: false,
              skipReviewCommentCount: false,
              skipAgentPlatformChats: false,
              skipAgentPlatformFlows: false,
            },
          ),
        ),
      );
    });
  });

  describe('i18n', () => {
    describe.each`
      language   | formattedValue
      ${'en-US'} | ${'999,999'}
      ${'de-DE'} | ${'999.999'}
    `('When the language is $language', ({ formattedValue, language }) => {
      beforeEach(() => {
        setLanguage(language);
        return createWrapper([VULNERABILITY_METRICS.CRITICAL], {
          apolloProvider: createMockApolloProvider({
            vulnerabilityMetricsRequest: mockVulnerabilityMetricsResponse(mockTableMaxLimitValues),
          }),
        });
      });

      it('formats numbers correctly', () => {
        expect(findTableRow(VULNERABILITY_METRICS.CRITICAL).html()).toContain(formattedValue);
      });
    });
  });
});
