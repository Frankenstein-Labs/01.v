import { GlCollapse } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AgentSessionsGroup from 'ee/ai/shared/widgets/agent_sessions_group.vue';
import AgentSessionRow from 'ee/ai/shared/widgets/agent_session_row.vue';
import AgentStatusIcon from 'ee/ai/shared/widgets/agent_status_icon.vue';
import { buildSessionGroup } from 'ee_jest/ai/mocks';

describe('AgentSessionsGroup', () => {
  let wrapper;

  const createComponent = (group = buildSessionGroup()) => {
    wrapper = shallowMountExtended(AgentSessionsGroup, {
      propsData: { group, headerBgClass: 'gl-bg-feedback-warning' },
    });
  };

  const findHeading = () => wrapper.findByTestId('sessions-group-heading');
  const findStatusIcon = () => wrapper.findComponent(AgentStatusIcon);
  const findToggleButton = () =>
    wrapper.findComponentByTestId(`toggle-sessions-${buildSessionGroup().key}`);
  const findAllSessionRows = () => wrapper.findAllComponents(AgentSessionRow);
  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findSessionsBody = () => wrapper.findByTestId('sessions-group-body');

  describe('header', () => {
    it('renders the heading with the correct bg class and title', () => {
      createComponent();

      expect(findHeading().classes()).toContain('gl-bg-feedback-warning');
      expect(findHeading().text()).toContain('2 sessions awaiting your input');
    });

    it('passes status and humanStatus to AgentStatusIcon', () => {
      createComponent();

      expect(findStatusIcon().props('status')).toBe('INPUT_REQUIRED');
      expect(findStatusIcon().props('humanStatus')).toBe('Input required');
    });
  });

  describe('collapse toggle', () => {
    it('is expanded with Collapse label by default', () => {
      createComponent();

      expect(findToggleButton().attributes('aria-expanded')).toBe('true');
      expect(findToggleButton().attributes('aria-label')).toBe('Collapse');
      expect(findCollapse().props('visible')).toBe(true);
    });

    it('collapses with Expand label on toggle click', async () => {
      createComponent();

      await findToggleButton().vm.$emit('click');

      expect(findToggleButton().attributes('aria-expanded')).toBe('false');
      expect(findToggleButton().attributes('aria-label')).toBe('Expand');
      expect(findCollapse().props('visible')).toBe(false);
    });

    it('expands again on second toggle click', async () => {
      createComponent();

      await findToggleButton().vm.$emit('click');
      await findToggleButton().vm.$emit('click');

      expect(findToggleButton().attributes('aria-expanded')).toBe('true');
      expect(findCollapse().props('visible')).toBe(true);
    });
  });

  describe('session rows', () => {
    it('renders a row for each session', () => {
      createComponent();

      expect(findAllSessionRows()).toHaveLength(2);
    });

    it('uses a subtle divider between rows', () => {
      createComponent();

      expect(findSessionsBody().classes()).toContain('gl-divide-subtle');
    });
  });
});
