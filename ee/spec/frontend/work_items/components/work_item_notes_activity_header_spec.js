import DuoChatQuickAction from 'ee_component/ai/shared/widgets/duo_chat_quick_action.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemNotesActivityHeader from '~/work_items/components/notes/work_item_notes_activity_header.vue';

describe('WorkItemNotesActivityHeader component', () => {
  let wrapper;

  const findDuoChatQuickAction = () => wrapper.findComponent(DuoChatQuickAction);

  const createComponent = ({ canSummarizeComments = false } = {}) => {
    wrapper = shallowMountExtended(WorkItemNotesActivityHeader, {
      propsData: {
        canSummarizeComments,
        disableActivityFilterSort: false,
        workItemId: 'gid://gitlab/WorkItem/123',
        workItemType: 'Task',
      },
    });
  };

  it.each([true, false])(
    'renders DuoChatQuickAction depending on canSummarizeComments',
    async (canSummarizeComments) => {
      createComponent({ canSummarizeComments });
      await waitForPromises();

      expect(findDuoChatQuickAction().exists()).toBe(canSummarizeComments);
    },
  );
});
