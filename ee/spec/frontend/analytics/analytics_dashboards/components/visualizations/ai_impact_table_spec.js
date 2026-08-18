import { GlLoadingIcon } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupOrProjectProvider from 'ee/analytics/dashboards/components/group_or_project_provider.vue';
import GetGroupOrProjectQuery from '~/analytics/dashboards/graphql/get_group_or_project.query.graphql';
import AiImpactTable from 'ee/analytics/analytics_dashboards/components/visualizations/ai_impact_table.vue';
import MetricTable from 'ee/analytics/dashboards/ai_impact/components/metric_table.vue';
import { mockGroup } from 'ee_jest/analytics/dashboards/mock_data';

Vue.use(VueApollo);

describe('AI Impact Table Visualization', () => {
  let wrapper;
  let mockGroupOrProjectRequestHandler;

  const namespace = 'Saiyan';
  const title = `Metric trends for group: ${namespace}`;
  const includeMetrics = ['thing1', 'thing2'];
  const excludeMetrics = ['thing3'];
  const filters = { includeMetrics, excludeMetrics };

  const createWrapper = () => {
    wrapper = shallowMountExtended(AiImpactTable, {
      apolloProvider: createMockApollo([
        [GetGroupOrProjectQuery, mockGroupOrProjectRequestHandler],
      ]),
      propsData: {
        data: { namespace, title, filters },
      },
      stubs: { GroupOrProjectProvider },
    });
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findMetricTable = () => wrapper.findComponent(MetricTable);

  afterEach(() => {
    mockGroupOrProjectRequestHandler = null;
  });

  describe('when loading', () => {
    beforeEach(() => {
      mockGroupOrProjectRequestHandler = jest.fn().mockImplementation(() => new Promise(() => {}));

      createWrapper();
    });

    it('renders the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render the metric table', () => {
      expect(findMetricTable().exists()).toBe(false);
    });
  });

  describe('when mounted', () => {
    beforeEach(() => {
      mockGroupOrProjectRequestHandler = jest
        .fn()
        .mockReturnValueOnce({ data: { group: mockGroup, project: null } });

      createWrapper();
    });

    it('does not render the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('resolves the namespace', () => {
      expect(mockGroupOrProjectRequestHandler).toHaveBeenCalledWith({ fullPath: namespace });
    });

    it('renders the metric table', () => {
      expect(findMetricTable().props()).toMatchObject({
        namespace,
        includeMetrics,
        excludeMetrics,
      });
    });

    it.each`
      identifier                            | expectedLink
      ${'deployment_frequency'}             | ${`/groups/${namespace}/-/analytics/dashboards/dora_metrics`}
      ${'lead_time_for_changes'}            | ${`/groups/${namespace}/-/analytics/dashboards/dora_metrics`}
      ${'time_to_restore_service'}          | ${`/groups/${namespace}/-/analytics/dashboards/dora_metrics`}
      ${'change_failure_rate'}              | ${`/groups/${namespace}/-/analytics/dashboards/dora_metrics`}
      ${'lead_time'}                        | ${`/groups/${namespace}/-/analytics/value_stream_analytics`}
      ${'cycle_time'}                       | ${`/groups/${namespace}/-/analytics/value_stream_analytics`}
      ${'issues'}                           | ${`/groups/${namespace}/-/issues_analytics`}
      ${'commits'}                          | ${`/groups/${namespace}`}
      ${'deploys'}                          | ${`/groups/${namespace}/-/analytics/productivity_analytics`}
      ${'issues_completed'}                 | ${`/groups/${namespace}/-/issues_analytics`}
      ${'contributor_count'}                | ${`/groups/${namespace}/-/contribution_analytics`}
      ${'vulnerability_critical'}           | ${`/groups/${namespace}/-/security/vulnerabilities?severity=CRITICAL`}
      ${'vulnerability_high'}               | ${`/groups/${namespace}/-/security/vulnerabilities?severity=HIGH`}
      ${'merge_request_throughput'}         | ${`/groups/${namespace}/-/analytics/productivity_analytics`}
      ${'median_time_to_merge'}             | ${`/groups/${namespace}/-/analytics/productivity_analytics`}
      ${'code_suggestions_users_count'}     | ${`/groups/${namespace}`}
      ${'code_suggestions_acceptance_rate'} | ${`/groups/${namespace}`}
      ${'duo_chat_users_count'}             | ${`/groups/${namespace}`}
      ${'duo_rca_users_count'}              | ${`/groups/${namespace}`}
      ${'duo_used_count'}                   | ${`/groups/${namespace}`}
      ${'duo_review_requests_count'}        | ${`/groups/${namespace}`}
      ${'duo_review_comment_count'}         | ${`/groups/${namespace}`}
      ${'duo_agent_platform_chats'}         | ${`/groups/${namespace}`}
      ${'duo_agent_platform_flows'}         | ${`/groups/${namespace}`}
      ${'pipeline_count'}                   | ${`/groups/${namespace}`}
      ${'pipeline_success_rate'}            | ${`/groups/${namespace}`}
      ${'pipeline_failed_rate'}             | ${`/groups/${namespace}`}
      ${'pipeline_other_rate'}              | ${`/groups/${namespace}`}
      ${'pipeline_duration_median'}         | ${`/groups/${namespace}`}
    `('links the $identifier metric to $expectedLink', ({ identifier, expectedLink }) => {
      expect(findMetricTable().props('metricLinks')[identifier]).toBe(expectedLink);
    });

    it('echos `set-alerts` event from the metric table', () => {
      const payload = { errors: ['one', 'two'] };
      findMetricTable().vm.$emit('set-alerts', payload);

      expect(wrapper.emitted('set-alerts')).toHaveLength(1);
      expect(wrapper.emitted('set-alerts')[0][0]).toEqual(payload);
    });
  });
});
