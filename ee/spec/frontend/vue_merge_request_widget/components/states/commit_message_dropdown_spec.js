import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CommitMessageDropdown from '~/vue_merge_request_widget/components/states/commit_message_dropdown.vue';
import AiCommitMessage from 'ee/vue_merge_request_widget/components/ai_commit_message.vue';

describe('Commit message drodpown component', () => {
  let wrapper;

  const findAiCommitMessage = () => wrapper.findComponent(AiCommitMessage);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(CommitMessageDropdown, {
      propsData: {
        mrId: 1,
        commits: [],
        ...props,
      },
      stubs: { AiCommitMessage },
    });
  };

  describe('when aiCommitMessageEnabled is false', () => {
    it('does not render AI commit message component', () => {
      createComponent({ aiCommitMessageEnabled: false });

      expect(findAiCommitMessage().exists()).toBe(false);
    });
  });

  describe('when aiCommitMessageEnabled is true', () => {
    it('renders AI commit message component', () => {
      createComponent({ aiCommitMessageEnabled: true });

      expect(findAiCommitMessage().exists()).toBe(true);
    });

    it('emits append when AI commit message component emits update', () => {
      createComponent({ aiCommitMessageEnabled: true });

      findAiCommitMessage().vm.$emit('update', 'commit message');

      expect(wrapper.emitted('append')).toEqual([['commit message']]);
    });
  });
});
