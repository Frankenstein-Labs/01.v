import Vue from 'vue';
import VueApollo from 'vue-apollo';
import PipelinesAdminApp from 'ee/usage_quotas/pipelines/admin/pipelines_admin_app.vue';
import getDedicatedInstanceUsageByYearQuery from 'ee/usage_quotas/pipelines/admin/graphql/queries/dedicated_instance_usage_by_year.query.graphql';
import getDedicatedInstanceUsageByMonthQuery from 'ee/usage_quotas/pipelines/admin/graphql/queries/dedicated_instance_usage_by_month.query.graphql';
import getDedicatedInstanceRunnerFiltersQuery from 'ee/usage_quotas/pipelines/admin/graphql/queries/dedicated_instance_runner_filters.query.graphql';
import MinutesUsageByNamespace from 'ee/usage_quotas/pipelines/admin/components/visualization_types/minutes_usage_by_namespace.vue';
import MinutesUsagePerMonth from 'ee/usage_quotas/pipelines/admin/components/visualization_types/minutes_usage_per_month.vue';
import RunnerUsageHeader from 'ee/usage_quotas/pipelines/admin/components/runner_usage_header.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  mockInstanceAggregatedUsage,
  mockInstanceNamespaceUsage,
  mockRunnerFilters,
} from './mock_data';

Vue.use(VueApollo);

describe('Pipelines Admin App', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const namespaceHandler = jest.fn().mockResolvedValue(mockInstanceAggregatedUsage);
  const monthsHandler = jest.fn().mockResolvedValue(mockInstanceNamespaceUsage);
  const filtersHandler = jest.fn().mockResolvedValue(mockRunnerFilters);

  const requestHandlers = [
    [getDedicatedInstanceUsageByYearQuery, namespaceHandler],
    [getDedicatedInstanceUsageByMonthQuery, monthsHandler],
    [getDedicatedInstanceRunnerFiltersQuery, filtersHandler],
  ];

  const findMinutesUsageByNamespace = () => wrapper.findComponent(MinutesUsageByNamespace);
  const findMinutesUsePerMonth = () => wrapper.findComponent(MinutesUsagePerMonth);
  const findRunnerYearFilter = () => wrapper.findComponentByTestId('runner-year-filter');
  const findRunnerFilterDropdown = () => wrapper.findComponentByTestId('runner-filter');
  const findRunnerUsageHeader = () => wrapper.findComponent(RunnerUsageHeader);

  const createComponent = ({ props = {} } = {}) => {
    wrapper = mountExtended(PipelinesAdminApp, {
      apolloProvider: createMockApollo(requestHandlers),
      propsData: {
        ...props,
      },
    });
  };

  describe('rendering', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('renders a MinutesUsageByNamespace chart component', () => {
      expect(findMinutesUsageByNamespace().exists()).toBe(true);
    });

    it('renders a MinutesUsageByMonth component', () => {
      expect(findMinutesUsePerMonth().exists()).toBe(true);
    });
  });

  describe('Compute minutes by month', () => {
    const mockedMonth = 1; // Select February using 0 index representation from the getUTCMonth method

    beforeEach(async () => {
      jest.spyOn(Date.prototype, 'getUTCMonth').mockImplementation(() => mockedMonth);

      createComponent();

      await waitForPromises();
    });

    afterEach(() => {
      jest.clearAllMocks();
    });

    it('Should display the compute minutes from february', () => {
      const currentMonthMinutes = `${mockInstanceNamespaceUsage.data.ciDedicatedHostedRunnerUsage.nodes[mockedMonth].computeMinutesUsage}`;
      expect(findRunnerUsageHeader().text()).toContain(currentMonthMinutes);
    });
  });

  describe('filtering', () => {
    it('filters chart by year', async () => {
      createComponent();

      await waitForPromises();

      findRunnerYearFilter().vm.$emit('select', 2023);

      await waitForPromises();

      expect(namespaceHandler).toHaveBeenCalledWith({
        grouping: 'INSTANCE_AGGREGATE',
        runnerId: 'gid://gitlab/Ci::Runner/55',
        year: 2023,
      });
    });

    it('filters chart by runner and year', async () => {
      createComponent();

      await waitForPromises();

      findRunnerYearFilter().vm.$emit('select', 2022);

      findRunnerFilterDropdown().vm.$emit('select', 'gid://gitlab/Ci::Runner/60');

      await waitForPromises();

      expect(namespaceHandler).toHaveBeenCalledWith({
        grouping: 'INSTANCE_AGGREGATE',
        runnerId: 'gid://gitlab/Ci::Runner/60',
        year: 2022,
      });
    });
  });
});
