// pipeline header fixtures located in ee/spec/frontend/fixtures/pipeline_header.rb
import pipelineHeaderSuccess from 'test_fixtures/graphql/pipelines/pipeline_header_success.json';
import pipelineHeaderRunning from 'test_fixtures/graphql/pipelines/pipeline_header_running.json';
import pipelineHeaderFinishedComputeMinutes from 'test_fixtures/graphql/pipelines/pipeline_header_compute_minutes.json';
import pipelineHeaderFailed from 'test_fixtures/graphql/pipelines/pipeline_header_failed.json';

export const pipelineHeaderMergeTrain = {
  data: {
    project: {
      id: 'gid://gitlab/Project/250',
      pipeline: {
        ...pipelineHeaderSuccess.data.project.pipeline,
        mergeRequestEventType: 'MERGE_TRAIN',
      },
    },
  },
};

export const mockPipelineStatusResponse = {
  data: {
    ciPipelineStatusUpdated: null,
  },
};

export {
  pipelineHeaderFinishedComputeMinutes,
  pipelineHeaderRunning,
  pipelineHeaderSuccess,
  pipelineHeaderFailed,
};
