import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SessionPill from 'ee/ai/duo_agentic_chat/components/session_pills/session_pill.vue';
import { EventsTracker } from 'ee/ai/duo_agentic_chat/observability/events_tracker';

jest.mock('ee/ai/duo_agentic_chat/observability/events_tracker');

describe('SessionPill', () => {
  let wrapper;

  const defaultProps = {
    workflowId: 326,
    flowName: 'fix_pipeline/v1',
    status: 'RUNNING',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(SessionPill, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findButton = () => wrapper.findByTestId('session-pill');
  const findStatusDot = () => wrapper.findByTestId('session-pill-status-dot');

  it('renders the pill with the humanized flow name and workflow id', () => {
    createComponent();

    expect(findButton().exists()).toBe(true);
    expect(wrapper.text()).toContain('Fix pipeline/v1 #326');
  });

  it('renders a status dot with the color class matching the status', () => {
    createComponent({ status: 'RUNNING' });

    expect(findStatusDot().exists()).toBe(true);
    expect(findStatusDot().classes()).toContain('gl-bg-status-info');
    expect(findStatusDot().attributes('aria-hidden')).toBe('true');
  });

  it('exposes the human-readable status in the aria-label', () => {
    createComponent();

    expect(findButton().attributes('aria-label')).toBe('Fix pipeline/v1 #326 Running');
  });

  describe('click handling', () => {
    it('emits click with the workflowId', async () => {
      createComponent();

      await findButton().trigger('click');

      expect(wrapper.emitted('click')).toEqual([[326]]);
    });

    it('tracks the click via EventsTracker.trackClickThroughSessionPill', async () => {
      createComponent();

      await findButton().trigger('click');

      expect(EventsTracker.trackClickThroughSessionPill).toHaveBeenCalledWith({
        workflowId: 326,
      });
    });
  });
});
