import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AgentFlowErrorAlert from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_error_alert.vue';

describe('AgentFlowErrorAlert', () => {
  let wrapper;

  const createComponent = ({ lastExecutorUrl = '', ...props } = {}) => {
    wrapper = shallowMountExtended(AgentFlowErrorAlert, {
      propsData: { hasMessages: false, ...props },
      provide: {
        lastExecutorLogUrl: () => lastExecutorUrl,
      },
      stubs: { GlSprintf },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLink = () => wrapper.findComponent(GlLink);

  beforeEach(() => {
    createComponent();
  });

  it('renders a dismissible danger alert', () => {
    expect(findAlert().props()).toMatchObject({ variant: 'danger', dismissible: true });
  });

  describe.each`
    hasMessages | expectedTitle                | expectedDescription
    ${false}    | ${'Session failed to start'} | ${'This session encountered an error before any messages were recorded.'}
    ${true}     | ${'Session failed'}          | ${'This session started but failed before completing.'}
  `('when hasMessages=$hasMessages', ({ hasMessages, expectedTitle, expectedDescription }) => {
    beforeEach(() => createComponent({ hasMessages }));

    it(`shows title "${expectedTitle}"`, () => {
      expect(findAlert().props('title')).toBe(expectedTitle);
    });

    it('shows the correct description', () => {
      expect(findAlert().text()).toContain(expectedDescription);
    });
  });

  it('shows errorSummary instead of the default description when provided', () => {
    createComponent({ hasMessages: true, errorSummary: 'Out of memory error' });

    expect(findAlert().text()).toContain('Out of memory error');
    expect(findAlert().text()).not.toContain('This session started but failed');
  });

  it('shows the job link when hasMessages and lastExecutorUrl are provided', () => {
    createComponent({ hasMessages: true, lastExecutorUrl: 'https://gitlab.com/jobs/123' });

    expect(findLink().attributes()).toMatchObject({
      href: 'https://gitlab.com/jobs/123',
      target: '_blank',
    });
  });

  it('does not show the job link when lastExecutorUrl is absent', () => {
    createComponent({ hasMessages: true });

    expect(findLink().exists()).toBe(false);
  });

  it('emits "dismiss" when the alert is dismissed', () => {
    findAlert().vm.$emit('dismiss');

    expect(wrapper.emitted('dismiss')).toHaveLength(1);
  });
});
