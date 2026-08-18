import { GlBadge } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentDataLabel from 'ee/workspaces/agent_mapping/components/agent_data_label.vue';

describe('ee/workspaces/agent_mapping/components/agent_data_label.vue', () => {
  /** @type {import('@vue/test-utils').Wrapper} */

  let wrapper;

  const createWrapper = (propsData = {}) => {
    wrapper = shallowMount(AgentDataLabel, {
      propsData: {
        label: 'Created in',
        ...propsData,
      },
      slots: {
        default: ['Test Agent Project', GlBadge],
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the label', () => {
      expect(wrapper.text()).toContain('Created in');
    });

    it('renders the value', () => {
      expect(wrapper.text()).toContain('Test Agent Project');
    });
  });

  describe('When adding a component to default slot', () => {
    beforeEach(() => {
      createWrapper();
    });
    it('renders value as a badge if badge prop is provided', () => {
      const badge = wrapper.findComponent(GlBadge);
      expect(badge.exists()).toBe(true);
    });
  });
});
