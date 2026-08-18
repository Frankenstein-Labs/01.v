import { GlButton } from '@gitlab/ui';
import { sendDuoChatCommand } from 'ee/ai/utils';
import RootCauseAnalysisButton from 'ee/ci/job_details/components/root_cause_analysis_button.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

jest.mock('ee/ai/utils', () => ({
  sendDuoChatCommand: jest.fn(),
}));

describe('Root cause analysis button', () => {
  let wrapper;

  const defaultProps = {
    jobStatusGroup: 'failed',
    canTroubleshootJob: true,
    isBuild: true,
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(RootCauseAnalysisButton, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findTroubleshootButton = () => wrapper.findByTestId('rca-duo-button');

  it('should display the Troubleshoot button', () => {
    createComponent();

    expect(findTroubleshootButton().exists()).toBe(true);
  });

  it('should not display the Troubleshoot button when no failure is detected', () => {
    createComponent({ jobStatusGroup: 'canceled' });

    expect(findTroubleshootButton().exists()).toBe(false);
  });

  it('should not display the Troubleshoot button when user cannot troubleshoot', () => {
    createComponent({ canTroubleshootJob: false });

    expect(findTroubleshootButton().exists()).toBe(false);
  });

  it('should not display the Troubleshoot button when job is not a build', () => {
    createComponent({ isBuild: false });

    expect(findTroubleshootButton().exists()).toBe(false);
  });

  describe('with jobId', () => {
    it('sends a call to the sendDuoChatCommand utility function with convereted ID', () => {
      createComponent({ jobId: 123 });

      wrapper.findComponent(GlButton).vm.$emit('click');

      expect(sendDuoChatCommand).toHaveBeenCalledWith({
        question: '/troubleshoot',
        resourceId: 'gid://gitlab/Ci::Build/123',
        agenticPrompt: 'Troubleshoot this broken pipeline.',
      });
    });
  });

  describe('with jobGid', () => {
    it('sends a call to the sendDuoChatCommand utility function with normal GID', () => {
      createComponent({ jobGid: 'gid://gitlab/Ci::Build/11781' });

      wrapper.findComponent(GlButton).vm.$emit('click');

      expect(sendDuoChatCommand).toHaveBeenCalledWith({
        question: '/troubleshoot',
        resourceId: 'gid://gitlab/Ci::Build/11781',
        agenticPrompt: 'Troubleshoot this broken pipeline.',
      });
    });
  });

  describe('with tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks button render and click', () => {
      createComponent({ jobId: 123 });

      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith('render_root_cause_analysis', {}, undefined);

      wrapper.findComponent(GlButton).vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith('click_root_cause_analysis', {}, undefined);
    });

    describe('when no failure is detected', () => {
      it('does not track button render', () => {
        createComponent({ jobStatusGroup: 'canceled' });

        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).not.toHaveBeenCalled();
      });
    });
  });
});
