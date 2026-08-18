import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoCodeReviewFeedback from 'ee/notes/components/duo_code_review_feedback.vue';
import UserFeedback from 'ee/ai/components/user_feedback.vue';

describe('DuoCodeReviewFeedback', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DuoCodeReviewFeedback, {
      propsData: props,
    });
  };

  const findAllButtons = () => wrapper.findAllComponents(GlButton);
  const findLeaveFeedbackButton = () =>
    findAllButtons().wrappers.find((b) => b.text() === 'Leave feedback');
  const findViewAgentSessionButton = () =>
    findAllButtons().wrappers.find((b) => b.text() === 'View agent session');
  const findUserFeedback = () => wrapper.findComponent(UserFeedback);

  it('renders the UserFeedback component', () => {
    createComponent();

    expect(findUserFeedback().exists()).toBe(true);
  });

  it('renders the "Leave feedback" button', () => {
    createComponent();

    expect(findLeaveFeedbackButton()).toBeDefined();
    expect(findLeaveFeedbackButton().attributes('href')).toBe(
      'https://gitlab.com/gitlab-org/gitlab/-/issues/517386',
    );
  });

  describe('when duoSessionUrl is not provided', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render the "View agent session" button', () => {
      expect(findViewAgentSessionButton()).toBeUndefined();
    });
  });

  describe('when duoSessionUrl is provided', () => {
    const duoSessionUrl = 'https://gitlab.example.com/project/agent-sessions/42';

    beforeEach(() => {
      createComponent({ duoSessionUrl });
    });

    it('renders the "View agent session" button', () => {
      expect(findViewAgentSessionButton()).toBeDefined();
    });

    it('links the "View agent session" button to the session URL', () => {
      expect(findViewAgentSessionButton().attributes('href')).toBe(duoSessionUrl);
    });
  });
});
