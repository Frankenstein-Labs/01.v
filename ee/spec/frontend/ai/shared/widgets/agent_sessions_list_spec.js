import { GlCollapse } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AgentSessionsList from 'ee/ai/shared/widgets/agent_sessions_list.vue';
import AgentSessionsGroup from 'ee/ai/shared/widgets/agent_sessions_group.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { buildSession } from 'ee_jest/ai/mocks';
import { AWAITING_INPUT_HEADER_BG_CLASS } from 'ee/ai/shared/widgets/constants';

describe('AgentSessionsList', () => {
  let wrapper;

  const createComponent = ({ sessions = [], isLoading = false } = {}) => {
    wrapper = shallowMountExtended(AgentSessionsList, {
      propsData: { sessions, isLoading },
    });
  };

  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findAllSessionGroups = () => wrapper.findAllComponents(AgentSessionsGroup);
  const findAwaitingInputGroup = () => wrapper.findAllComponents(AgentSessionsGroup).at(0);
  const findOtherSessionsHeading = () => wrapper.findByTestId('other-sessions-heading');
  const findToggleOtherButton = () => wrapper.findComponentByTestId('toggle-sessions-other');
  const findOtherCollapse = () => wrapper.findComponent(GlCollapse);

  describe('with no sessions', () => {
    it('does not render the crud component', () => {
      createComponent();

      expect(findCrudComponent().exists()).toBe(false);
    });
  });

  describe('with only awaiting-input sessions', () => {
    it('renders the crud component expanded', () => {
      createComponent({ sessions: [buildSession({ status: 'INPUT_REQUIRED' })] });

      expect(findCrudComponent().props('collapsed')).toBe(false);
    });

    it('renders a single AgentSessionsGroup for all awaiting-input statuses', () => {
      createComponent({
        sessions: [
          buildSession({ status: 'INPUT_REQUIRED' }),
          buildSession({ status: 'PLAN_APPROVAL_REQUIRED' }),
        ],
      });

      expect(findAllSessionGroups()).toHaveLength(1);
      expect(findAwaitingInputGroup().props('group')).toMatchObject({ key: 'INPUT_REQUIRED' });
      expect(findAwaitingInputGroup().props('headerBgClass')).toBe(AWAITING_INPUT_HEADER_BG_CLASS);
    });

    it('does not render the other-sessions heading', () => {
      createComponent({ sessions: [buildSession({ status: 'INPUT_REQUIRED' })] });

      expect(findOtherSessionsHeading().exists()).toBe(false);
    });
  });

  describe('with only non-awaiting-input sessions', () => {
    it('renders the crud component collapsed', () => {
      createComponent({ sessions: [buildSession()] });

      expect(findCrudComponent().props('collapsed')).toBe(true);
    });

    it('renders one AgentSessionsGroup per status group with sessions', () => {
      createComponent({
        sessions: [buildSession({ status: 'RUNNING' }), buildSession()],
      });

      expect(findAllSessionGroups()).toHaveLength(2);
    });

    it('does not render the other-sessions heading', () => {
      createComponent({ sessions: [buildSession({ status: 'RUNNING' })] });

      expect(findOtherSessionsHeading().exists()).toBe(false);
    });
  });

  describe('with both awaiting-input and other sessions', () => {
    beforeEach(() => {
      createComponent({
        sessions: [
          buildSession({ status: 'INPUT_REQUIRED' }),
          buildSession({ status: 'RUNNING' }),
          buildSession(),
        ],
      });
    });

    it('renders the crud component expanded', () => {
      expect(findCrudComponent().props('collapsed')).toBe(false);
    });

    it('renders the other-sessions heading', () => {
      expect(findOtherSessionsHeading().exists()).toBe(true);
    });

    it('renders one group for awaiting-input and one per other status group', () => {
      // 1 awaiting-input group + 2 other groups (RUNNING, FINISHED)
      expect(findAllSessionGroups()).toHaveLength(3);
    });

    it('other sessions are collapsed by default and shows "Show" label', () => {
      expect(findToggleOtherButton().attributes('aria-expanded')).toBe('false');
      expect(findToggleOtherButton().text()).toContain('Show');
      expect(findOtherCollapse().props('visible')).toBe(false);
    });

    it('toggles other sessions on button click and shows "Hide" label', async () => {
      await findToggleOtherButton().vm.$emit('click');

      expect(findToggleOtherButton().attributes('aria-expanded')).toBe('true');
      expect(findToggleOtherButton().text()).toContain('Hide');
      expect(findOtherCollapse().props('visible')).toBe(true);
    });

    it('shows a dot-separated summary with counts and status labels', () => {
      expect(findOtherSessionsHeading().text()).toContain('1 running');
      expect(findOtherSessionsHeading().text()).toContain('·');
      expect(findOtherSessionsHeading().text()).toContain('1 completed');
    });
  });

  describe('isLoading', () => {
    it('passes isLoading to CrudComponent', () => {
      createComponent({ sessions: [buildSession()], isLoading: true });

      expect(findCrudComponent().props('isLoading')).toBe(true);
    });
  });
});
