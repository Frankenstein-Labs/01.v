import { sendDuoChatCommand } from 'ee/ai/utils';
import DuoAnalyzeCard from 'ee/ci/pipeline_editor/components/ui/duo_analyze_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

jest.mock('ee/ai/utils', () => ({
  sendDuoChatCommand: jest.fn(),
}));

describe('DuoAnalyzeCard', () => {
  let wrapper;

  const mockResourceId = 'gid://gitlab/Project/42';

  const createComponent = () => {
    wrapper = shallowMountExtended(DuoAnalyzeCard, {
      provide: {
        resourceId: mockResourceId,
      },
    });
  };

  const findAnalyzeButton = () => wrapper.findComponentByTestId('analyze-repository-button');

  describe('when the analyze repository button is clicked', () => {
    beforeEach(() => {
      createComponent();
      findAnalyzeButton().vm.$emit('click');
    });

    it('calls sendDuoChatCommand with the correct parameters', () => {
      expect(sendDuoChatCommand).toHaveBeenCalledWith({
        question: '/pipeline_authoring',
        resourceId: mockResourceId,
        agenticPrompt:
          'Analyze this repository and create a CI/CD pipeline that meets the needs of the project.',
        agent: { id: 'gid://gitlab/Ai::FoundationalChatAgent/ci_expert_agent-v1' },
      });
    });

    it('emits the create-empty-config-file event', () => {
      expect(wrapper.emitted('create-empty-config-file')).toHaveLength(1);
    });
  });
});
