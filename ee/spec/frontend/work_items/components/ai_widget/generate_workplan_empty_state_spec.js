import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GenerateWorkplanEmptyState from 'ee/work_items/components/ai_widget/generate_workplan_empty_state.vue';
import DuoChatQuickAction from 'ee/ai/shared/widgets/duo_chat_quick_action.vue';
import { buildWorkPlanChatCommand } from 'ee/work_items/components/ai_widget/constants';

const RESOURCE_ID = 'gid://gitlab/WorkItem/1';
const WORK_ITEM_WEB_URL = 'http://gdk.test/gitlab-org/gitlab/-/work_items/1';

describe('GenerateWorkplanEmptyState', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(GenerateWorkplanEmptyState, {
      propsData: { resourceId: RESOURCE_ID, workItemWebUrl: WORK_ITEM_WEB_URL, ...props },
    });
  };

  const findHeader = () => wrapper.findByTestId('workplan-header');
  const findDescription = () => wrapper.findByTestId('workplan-description');
  const findGenerateAction = () => wrapper.findComponentByTestId('generate-workplan-button');

  beforeEach(() => {
    createComponent();
  });

  it('shows the "ready" copy', () => {
    expect(findHeader().text()).toBe('Ready when you are');
    expect(findDescription().text()).toContain('break your item into an efficient implementation');
  });

  it('renders the generate action with the right props', () => {
    const quickAction = wrapper.findComponent(DuoChatQuickAction);
    expect(quickAction.props('resourceId')).toBe(RESOURCE_ID);
    expect(quickAction.props('command')).toEqual(buildWorkPlanChatCommand(WORK_ITEM_WEB_URL));
    expect(quickAction.props('buttonText')).toBe('Generate workplan');
  });

  describe('when chat is opened from the generate action', () => {
    beforeEach(() => {
      findGenerateAction().vm.$emit('chat-opened');
    });

    it('emits generate-workplan', () => {
      expect(wrapper.emitted('generate-workplan')).toHaveLength(1);
    });
  });
});
