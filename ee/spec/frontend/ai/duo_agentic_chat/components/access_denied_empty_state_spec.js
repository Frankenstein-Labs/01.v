import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { DUO_PANEL_EMPTY_STATE_EVENTS } from 'ee/ai/constants';
import AccessDeniedEmptyState from 'ee/ai/duo_agentic_chat/components/access_denied_empty_state.vue';

const { bindInternalEventDocument } = useMockInternalEventsTracking();

describe('AccessDeniedEmptyState', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AccessDeniedEmptyState, {
      propsData: props,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findEmptyStateText = () => wrapper.findByTestId('empty-state-text');
  const findLearnMoreLink = () => wrapper.findComponentByTestId('learn-more-link');

  beforeEach(createComponent);

  it('renders the correct content', () => {
    createComponent();

    expect(findEmptyStateText().text()).toMatchInterpolatedText(
      "You don't have permission to use GitLab Duo Agent Platform in this group. Learn more.",
    );

    expect(findLearnMoreLink().props('href')).toBe('/help/user/duo_agent_platform/_index.md');
  });

  it('renders the correct text within a project', () => {
    createComponent({
      containerType: 'project',
    });

    expect(findEmptyStateText().text()).toMatchInterpolatedText(
      "You don't have permission to use GitLab Duo Agent Platform in this project. Learn more.",
    );

    expect(findLearnMoreLink().props('href')).toBe('/help/user/duo_agent_platform/_index.md');
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
});
