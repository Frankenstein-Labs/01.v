import { shallowMount } from '@vue/test-utils';
import MRWidgetPipeline from '~/vue_merge_request_widget/components/mr_widget_pipeline.vue';
import MrWidgetPipelineDuoAction from 'ee/vue_merge_request_widget/components/mr_duo_fix_pipeline.vue';
import mockData from 'jest/vue_merge_request_widget/mock_data';

describe('MRWidgetPipeline EE', () => {
  let wrapper;

  const defaultProps = {
    pipeline: {
      ...mockData.pipeline,
      details: {
        ...mockData.pipeline.details,
        status: { group: 'failed', label: 'failed', icon: 'status_failed' },
      },
    },
    ciStatus: 'failed',
    mrTroubleshootingDocsPath: 'help',
    ciTroubleshootingDocsPath: 'ci-help',
    targetProjectFullPath: 'gitlab-org/gitlab',
    sourceBranch: 'feature-branch',
    mergeRequestPath: '/gitlab-org/gitlab/-/merge_requests/1',
    retargeted: false,
    targetProjectId: 1,
    iid: 1,
    mrId: 133,
  };

  const findDuoAction = () => wrapper.findComponent(MrWidgetPipelineDuoAction);

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(MRWidgetPipeline, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        MrWidgetPipelineDuoAction,
      },
    });
  };

  describe('DuoWorkflowAction slot integration', () => {
    describe('when pipeline has failed', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders the MrWidgetPipelineDuoAction component in slot', () => {
        expect(findDuoAction().exists()).toBe(true);
      });

      it('passes the correct props to duo action component', () => {
        expect(findDuoAction().props()).toEqual({
          pipeline: defaultProps.pipeline,
          mergeRequestPath: '/gitlab-org/gitlab/-/merge_requests/1',
          targetProjectFullPath: 'gitlab-org/gitlab',
          sourceBranch: 'feature-branch',
        });
      });
    });

    it('does not render duo action when pipeline is successful', () => {
      createWrapper({
        pipeline: {
          ...mockData.pipeline,
          details: {
            ...mockData.pipeline.details,
            status: { group: 'success', label: 'passed', icon: 'status_success' },
          },
        },
        ciStatus: 'success',
      });

      expect(findDuoAction().exists()).toBe(false);
    });

    it('does not render duo action when there is a CI error', () => {
      createWrapper({
        pipeline: defaultProps.pipeline,
        ciStatus: null,
      });

      expect(findDuoAction().exists()).toBe(false);
    });

    it('does not render duo action when pipeline is retargeted', () => {
      createWrapper({ retargeted: true });

      expect(findDuoAction().exists()).toBe(false);
    });

    it('does not render duo action when there is no pipeline', () => {
      createWrapper({ pipeline: {} });

      expect(findDuoAction().exists()).toBe(false);
    });
  });
});
