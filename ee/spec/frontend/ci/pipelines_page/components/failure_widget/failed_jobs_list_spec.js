import Vue from 'vue';
import VueApollo from 'vue-apollo';

import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import FailedJobsList from '~/ci/pipelines_page/components/failure_widget/failed_jobs_list.vue';
import FailedJobDetails from '~/ci/pipelines_page/components/failure_widget/failed_job_details.vue';
import getPipelineFailedJobs from '~/ci/pipelines_page/graphql/queries/get_pipeline_failed_jobs.query.graphql';
import { failedJobsMock } from './mock_data';

Vue.use(VueApollo);

describe('FailedJobsList component', () => {
  let wrapper;
  let mockFailedJobsResponse;

  const defaultProps = {
    graphqlResourceEtag: 'api/graphql',
    isMaximumJobLimitReached: false,
    pipelineIid: 'gid://gitlab/Pipeline/1',
    pipelinePath: 'namespace/project/pipeline',
    projectPath: 'namespace/project/',
  };

  const defaultProvide = {
    graphqlPath: 'api/graphql',
  };

  const createComponent = ({ props = {}, provide } = {}) => {
    const handlers = [[getPipelineFailedJobs, mockFailedJobsResponse]];
    const mockApollo = createMockApollo(handlers);

    wrapper = shallowMountExtended(FailedJobsList, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      apolloProvider: mockApollo,
    });
  };

  const findFailedJobRows = () => wrapper.findAllComponents(FailedJobDetails);

  beforeEach(() => {
    mockFailedJobsResponse = jest.fn();
  });

  describe('when failed jobs have loaded', () => {
    beforeEach(async () => {
      mockFailedJobsResponse.mockResolvedValue(failedJobsMock);

      createComponent();

      await waitForPromises();
    });

    it('passes the correct props to failed jobs row', () => {
      expect(findFailedJobRows().at(0).props()).toStrictEqual({
        canTroubleshootJob: true,
        job: failedJobsMock.data.project.pipeline.jobs.nodes[0],
      });
    });
  });
});
