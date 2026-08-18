import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import PipelinesDashboardClickhouse from '~/ci/analytics/project_ci_cd_analytics/components/pipelines_dashboard_clickhouse.vue';
import JobAnalyticsTable from 'ee_component/ci/analytics/project_ci_cd_analytics/components/job_analytics_table.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useFakeDate } from 'helpers/fake_date';

Vue.use(VueApollo);

describe('PipelinesDashboardClickhouse', () => {
  useFakeDate('2022-02-15T08:30'); // a date with a time

  let wrapper;

  const findJobAnalyticsTable = () => wrapper.findComponent(JobAnalyticsTable);

  const createComponent = () => {
    wrapper = shallowMount(PipelinesDashboardClickhouse, {
      apolloProvider: createMockApollo(),
      stubs: {
        JobAnalyticsTable,
      },
    });
  };

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  it('renders the job analytics table', () => {
    expect(findJobAnalyticsTable().props('variables')).toEqual({
      branch: null,
      fromTime: new Date('2022-02-08'),
      toTime: new Date('2022-02-15'),
      fullPath: '',
      jobName: null,
      source: null,
    });
  });

  it('filters according to the job analytics table', async () => {
    findJobAnalyticsTable().vm.$emit('filters-input', { jobName: 'a-job-name' });
    await waitForPromises();

    expect(findJobAnalyticsTable().props('variables')).toMatchObject({
      jobName: 'a-job-name',
    });
  });
});
