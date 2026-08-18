import { GlSprintf, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { DUO_PANEL_EMPTY_STATE_EVENTS } from 'ee/ai/constants';
import StartTrialEmptyState from 'ee/ai/duo_agentic_chat/components/start_trial_empty_state.vue';

const { bindInternalEventDocument } = useMockInternalEventsTracking();
const newTrialPathMock = '/-/trials/new';
const trialDurationMock = '20';

describe('StartTrialEmptyState', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(StartTrialEmptyState, {
      propsData: {
        newTrialPath: newTrialPathMock,
        trialDuration: trialDurationMock,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findEmptyStateText = () => wrapper.findByTestId('empty-state-text');
  const findStartTrialLink = () => wrapper.findComponentByTestId('start-trial-link');
  const findLearnMoreLink = () => wrapper.findComponentByTestId('learn-more-link');
  const findWorkflowExamples = () => wrapper.findAllByTestId('workflow-example');

  beforeEach(createComponent);

  it('renders the correct content', () => {
    const workflowExamples = findWorkflowExamples();

    expect(findEmptyStateText().text()).toMatchInterpolatedText(
      'Start your free 20-day trial now to accelerate your software delivery. Automate tasks with AI agents, from searching projects to creating commits.',
    );

    expect(findStartTrialLink().props('href')).toBe(newTrialPathMock);
    expect(findLearnMoreLink().props('href')).toBe('/help/user/duo_agent_platform/_index.md');

    expect(workflowExamples.at(0).findComponent(GlIcon).props('name')).toBe('merge-request');
    expect(workflowExamples.at(0).text()).toContain('Review a merge request');
    expect(workflowExamples.at(0).text()).toContain('Identify code improvements');

    expect(workflowExamples.at(1).findComponent(GlIcon).props('name')).toBe('pipeline');
    expect(workflowExamples.at(1).text()).toContain('Fix a failing pipeline');
    expect(workflowExamples.at(1).text()).toContain(
      'Analyze pipeline failures and get fix suggestions',
    );
  });

  it('tracks the `view_duo_agentic_not_available_empty_state` on mount', () => {
    createComponent();
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    expect(trackEventSpy).toHaveBeenCalledWith(
      DUO_PANEL_EMPTY_STATE_EVENTS.VIEW_NOT_AVAILABLE,
      {},
      undefined,
    );
  });

  it('adds the correct tracking properties to the "Start a Free Trial" link', () => {
    expect(findStartTrialLink().attributes()).toMatchObject({
      'data-event-tracking': 'click_link',
      'data-event-label': DUO_PANEL_EMPTY_STATE_EVENTS.CLICK_START_TRIAL,
    });
  });

  it('adds the correct tracking properties to the "Learn more" link', () => {
    expect(findLearnMoreLink().attributes()).toMatchObject({
      'data-event-tracking': 'click_link',
      'data-event-label': DUO_PANEL_EMPTY_STATE_EVENTS.CLICK_LEARN_MORE,
    });
  });
});
