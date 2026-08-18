import Vue from 'vue';
import VueApollo from 'vue-apollo';
// fixture located in spec/frontend/fixtures/pipelines.rb
import fixture from 'test_fixtures/pipelines/pipelines.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import PipelineFailedJobsWidget from '~/ci/pipelines_page/components/failure_widget/pipeline_failed_jobs_widget.vue';
import PipelineMiniGraph from '~/ci/pipeline_mini_graph/pipeline_mini_graph.vue';
import PipelinesTable from '~/ci/common/pipelines_table.vue';
import { PIPELINE_ID_KEY } from '~/ci/constants';
import DuoWorkflowAction from 'ee/ai/shared/widgets/duo_workflow_action.vue';
import { AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';

Vue.use(VueApollo);

describe('EE - Pipelines Table', () => {
  let wrapper;

  const defaultProvide = {
    fullPath: '/my-project/',
    useFailedJobsWidget: false,
    mergeRequestPath: null,
  };

  const { pipelines } = fixture;
  const [firstPipeline] = pipelines;

  const defaultProps = {
    pipelines,
    pipelineIdType: PIPELINE_ID_KEY,
  };

  const createComponent = ({ props = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = mountExtended(PipelinesTable, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        PipelineOperations: true,
        PipelineMiniGraph: stubComponent(PipelineMiniGraph),
        PipelineFailedJobsWidget: stubComponent(PipelineFailedJobsWidget),
        DuoWorkflowAction: true,
        ...stubs,
      },
      apolloProvider: createMockApollo(),
    });
  };

  const findDuoWorkflowAction = () => wrapper.findComponent(DuoWorkflowAction);

  describe('Duo Workflow Action', () => {
    const failedPipelineWithMR = {
      ...firstPipeline,
      path: '/project/-/pipelines/123',
      latest: true,
      details: {
        ...firstPipeline.details,
        status: {
          ...firstPipeline.details.status,
          group: 'failed',
        },
      },
      merge_request: {
        path: '/project/-/merge_requests/123',
        source_branch: 'feature-branch',
      },
      source: 'merge_request_event',
    };

    const failedPipelineWithMRPushSource = {
      ...firstPipeline,
      path: '/project/-/pipelines/124',
      latest: true,
      details: {
        ...firstPipeline.details,
        status: {
          ...firstPipeline.details.status,
          group: 'failed',
        },
      },
      source: 'push',
      ref: {
        name: 'master',
      },
    };

    const failedPipelineWithBothMRAndRef = {
      ...firstPipeline,
      path: '/project/-/pipelines/125',
      latest: true,
      details: {
        ...firstPipeline.details,
        status: {
          ...firstPipeline.details.status,
          group: 'failed',
        },
      },
      merge_request: {
        path: '/project/-/merge_requests/125',
        source_branch: 'feature-branch',
      },
      source: 'push',
      ref: {
        name: 'master',
      },
    };

    const failedPipelineWithoutMR = {
      ...firstPipeline,
      path: '/project/-/pipelines/456',
      latest: true,
      details: {
        ...firstPipeline.details,
        status: {
          ...firstPipeline.details.status,
          group: 'failed',
        },
      },
    };

    const failedPipelineWithMRNoSourceBranch = {
      ...firstPipeline,
      path: '/project/-/pipelines/126',
      latest: true,
      details: {
        ...firstPipeline.details,
        status: {
          ...firstPipeline.details.status,
          group: 'failed',
        },
      },
      merge_request: {
        path: '/project/-/merge_requests/126',
      },
      source: 'merge_train',
      ref: {
        name: 'main',
      },
    };

    const failedExternalPipeline = {
      ...firstPipeline,
      path: '/project/-/pipelines/300',
      latest: true,
      details: {
        ...firstPipeline.details,
        status: {
          ...firstPipeline.details.status,
          group: 'failed',
        },
      },
      merge_request: {
        path: '/project/-/merge_requests/300',
        source_branch: 'feature-branch',
      },
      source: 'external',
      ref: {
        name: 'master',
      },
    };

    const successfulPipelineWithMR = {
      ...firstPipeline,
      path: '/project/-/pipelines/789',
      latest: true,
      details: {
        ...firstPipeline.details,
        status: {
          ...firstPipeline.details.status,
          group: 'success',
        },
      },
      merge_request: {
        path: '/project/-/merge_requests/456',
      },
    };

    const fixPipelineAgentPrivileges = [
      AGENT_PRIVILEGES.READ_WRITE_FILES,
      AGENT_PRIVILEGES.READ_ONLY_GITLAB,
      AGENT_PRIVILEGES.READ_WRITE_GITLAB,
      AGENT_PRIVILEGES.RUN_COMMANDS,
      AGENT_PRIVILEGES.USE_GIT,
    ];

    beforeEach(() => {
      window.gon = { gitlab_url: 'https://gitlab.com' };
    });

    describe('when pipeline has failed and mergeRequestPath is injected', () => {
      const mergeRequestPath = 'https://gitlab.com/project/-/merge_requests/123';

      describe('with merge_request_event source', () => {
        beforeEach(() => {
          gon.api_version = 'v4';
          createComponent({
            props: { pipelines: [failedPipelineWithMR] },
            provide: {
              mergeRequestPath,
            },
          });
        });

        it('renders DuoWorkflowAction component', () => {
          expect(findDuoWorkflowAction().exists()).toBe(true);
        });

        it('should render tables widths', () => {
          expect(wrapper.findAll('col').wrappers.map((e) => e.classes())).toEqual([
            ['gl-w-3/20'],
            ['gl-w-5/20'],
            ['gl-w-3/20'],
            ['gl-w-3/20'],
            ['gl-w-6/20'],
          ]);
        });

        it('passes correct props to DuoWorkflowAction with source branch from merge request', () => {
          expect(findDuoWorkflowAction().props()).toMatchObject({
            projectPath: 'frontend-fixtures/pipelines-project',
            goal: 'https://gitlab.com/project/-/pipelines/123',
            hoverMessage: 'Fix pipeline with Duo',
            workflowDefinition: 'fix_pipeline/v1',
            size: 'medium',
            agentPrivileges: fixPipelineAgentPrivileges,
            sourceBranch: 'feature-branch',
            additionalContext: [
              {
                Category: 'merge_request',
                Content: JSON.stringify({
                  url: mergeRequestPath,
                }),
              },
              {
                Category: 'pipeline',
                Content: JSON.stringify({
                  source_branch: 'feature-branch',
                  source: 'merge_request_event',
                }),
              },
            ],
          });
        });
      });

      describe('with push source', () => {
        beforeEach(() => {
          gon.api_version = 'v4';
          createComponent({
            props: { pipelines: [failedPipelineWithMRPushSource] },
            provide: {
              mergeRequestPath,
            },
          });
        });

        it('renders DuoWorkflowAction component', () => {
          expect(findDuoWorkflowAction().exists()).toBe(true);
        });

        it('passes correct props to DuoWorkflowAction with ref name', () => {
          expect(findDuoWorkflowAction().props()).toMatchObject({
            projectPath: 'frontend-fixtures/pipelines-project',
            goal: 'https://gitlab.com/project/-/pipelines/124',
            hoverMessage: 'Fix pipeline with Duo',
            workflowDefinition: 'fix_pipeline/v1',
            size: 'medium',
            agentPrivileges: fixPipelineAgentPrivileges,
            sourceBranch: 'master',
            additionalContext: [
              {
                Category: 'merge_request',
                Content: JSON.stringify({
                  url: mergeRequestPath,
                }),
              },
              {
                Category: 'pipeline',
                Content: JSON.stringify({
                  source_branch: 'master',
                  source: 'push',
                }),
              },
            ],
          });
        });
      });

      describe('with both merge request source branch and ref name', () => {
        beforeEach(() => {
          gon.api_version = 'v4';
          createComponent({
            props: { pipelines: [failedPipelineWithBothMRAndRef] },
            provide: {
              mergeRequestPath,
            },
          });
        });

        it('renders DuoWorkflowAction component', () => {
          expect(findDuoWorkflowAction().exists()).toBe(true);
        });

        it('prioritizes merge request source branch over ref name', () => {
          const sourceBranch = failedPipelineWithBothMRAndRef.merge_request.source_branch;
          expect(findDuoWorkflowAction().props()).toMatchObject({
            sourceBranch: 'feature-branch',
            additionalContext: [
              {
                Category: 'merge_request',
                Content: JSON.stringify({
                  url: mergeRequestPath,
                }),
              },
              {
                Category: 'pipeline',
                Content: JSON.stringify({
                  source_branch: sourceBranch,
                  source: 'push',
                }),
              },
            ],
          });
        });
      });

      describe('with merge request but no source branch and has ref', () => {
        beforeEach(() => {
          createComponent({
            props: { pipelines: [failedPipelineWithMRNoSourceBranch] },
            provide: {
              mergeRequestPath,
            },
          });
        });

        it('renders DuoWorkflowAction component using ref name as fallback', () => {
          expect(findDuoWorkflowAction().exists()).toBe(true);
        });

        it('uses ref name when merge request has no source branch', () => {
          expect(findDuoWorkflowAction().props()).toMatchObject({
            sourceBranch: 'main',
            additionalContext: [
              {
                Category: 'merge_request',
                Content: JSON.stringify({
                  url: mergeRequestPath,
                }),
              },
              {
                Category: 'pipeline',
                Content: JSON.stringify({
                  source_branch: 'main',
                  source: 'merge_train',
                }),
              },
            ],
          });
        });
      });
    });

    describe('when pipeline has failed but mergeRequestPath is not injected', () => {
      beforeEach(() => {
        createComponent({
          props: { pipelines: [failedPipelineWithMR] },
          provide: {
            mergeRequestPath: null,
          },
        });
      });

      it('does not render DuoWorkflowAction component', () => {
        expect(findDuoWorkflowAction().exists()).toBe(false);
      });

      it('should render tables widths with default actions column', () => {
        expect(wrapper.findAll('col').wrappers.map((e) => e.classes())).toEqual([
          ['gl-w-3/20'],
          ['gl-w-5/20'],
          ['gl-w-3/20'],
          ['gl-w-4/20'],
          ['gl-w-5/20'],
        ]);
      });
    });

    describe('when merge_request property is null but has ref', () => {
      it('renders DuoWorkflowAction component using ref name', () => {
        const failedPipelineWithNullMRButRef = {
          ...failedPipelineWithoutMR,
          merge_request: null,
          ref: {
            name: 'develop',
          },
        };

        createComponent({
          props: { pipelines: [failedPipelineWithNullMRButRef] },
          provide: {
            mergeRequestPath: 'https://gitlab.com/project/-/merge_requests/123',
          },
        });

        expect(findDuoWorkflowAction().exists()).toBe(true);
        expect(findDuoWorkflowAction().props('sourceBranch')).toBe('develop');
      });
    });

    describe('when pipeline is successful', () => {
      beforeEach(() => {
        createComponent({
          props: { pipelines: [successfulPipelineWithMR] },
          provide: {
            mergeRequestPath: 'https://gitlab.com/project/-/merge_requests/456',
          },
        });
      });

      it('does not render DuoWorkflowAction component', () => {
        expect(findDuoWorkflowAction().exists()).toBe(false);
      });
    });

    describe('pipeline path and additional context handling', () => {
      const mergeRequestPath = 'https://gitlab.com/project/-/merge_requests/123';

      it('correctly constructs pipeline URL when gon.gitlab_url is set', () => {
        createComponent({
          props: { pipelines: [failedPipelineWithMR] },
          provide: {
            mergeRequestPath,
          },
        });

        expect(findDuoWorkflowAction().props('goal')).toBe(
          'https://gitlab.com/project/-/pipelines/123',
        );
      });

      it('includes injected merge request URL in additional context', () => {
        createComponent({
          props: { pipelines: [failedPipelineWithMR] },
          provide: {
            mergeRequestPath,
          },
        });

        const additionalContext = findDuoWorkflowAction().props('additionalContext');
        expect(additionalContext[0]).toEqual({
          Category: 'merge_request',
          Content: JSON.stringify({
            url: mergeRequestPath,
          }),
        });
        expect(additionalContext[1]).toEqual({
          Category: 'pipeline',
          Content: JSON.stringify({
            source_branch: 'feature-branch',
            source: 'merge_request_event',
          }),
        });
      });
    });

    describe('multiple pipelines', () => {
      it('renders DuoWorkflowAction for failed pipelines with any valid source branch when mergeRequestPath is provided', () => {
        createComponent({
          props: {
            pipelines: [
              failedPipelineWithMR,
              failedPipelineWithMRPushSource,
              failedPipelineWithBothMRAndRef,
              successfulPipelineWithMR,
              failedPipelineWithoutMR,
              failedPipelineWithMRNoSourceBranch,
            ],
          },
          provide: {
            mergeRequestPath: 'https://gitlab.com/project/-/merge_requests/123',
          },
        });

        expect(wrapper.findAllComponents(DuoWorkflowAction)).toHaveLength(5);
      });

      it('renders no DuoWorkflowAction components when mergeRequestPath is not provided', () => {
        createComponent({
          props: {
            pipelines: [
              failedPipelineWithMR,
              failedPipelineWithMRPushSource,
              failedPipelineWithBothMRAndRef,
              failedPipelineWithoutMR,
            ],
          },
          provide: {
            mergeRequestPath: null,
          },
        });

        expect(wrapper.findAllComponents(DuoWorkflowAction)).toHaveLength(0);
      });
    });

    describe('latest pipeline gating', () => {
      it('renders DuoWorkflowAction only for the latest failed pipeline', () => {
        const olderFailedPipeline = {
          ...failedPipelineWithMR,
          path: '/project/-/pipelines/999',
          latest: false,
        };

        createComponent({
          props: { pipelines: [failedPipelineWithMRPushSource, olderFailedPipeline] },
          provide: { mergeRequestPath: 'https://gitlab.com/project/-/merge_requests/123' },
        });

        expect(wrapper.findAllComponents(DuoWorkflowAction)).toHaveLength(1);
      });
    });

    describe('latest failed pipelines of different sources', () => {
      it('renders DuoWorkflowAction for each latest failed push and external pipeline', () => {
        createComponent({
          props: { pipelines: [failedPipelineWithMRPushSource, failedExternalPipeline] },
          provide: {
            mergeRequestPath: 'https://gitlab.com/project/-/merge_requests/123',
          },
        });

        expect(wrapper.findAllComponents(DuoWorkflowAction)).toHaveLength(2);
      });
    });
  });
});
