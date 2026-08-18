import { GlButton, GlPopover, GlBadge } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentDetailsPopover from 'ee/workspaces/agent_mapping/components/agent_details_popover.vue';
import AgentDataLabel from 'ee/workspaces/agent_mapping/components/agent_data_label.vue';
import { MAPPED_CLUSTER_AGENT } from 'ee_jest/workspaces/mock_data';

jest.mock('lodash-es', () => ({
  ...jest.requireActual('lodash-es'),
  uniqueId: (val) => `${val}unique-id`,
}));

const TEST_AGENT_NO_CONNECTED = {
  ...MAPPED_CLUSTER_AGENT,
  connections: {
    nodes: [],
  },
};
const EXPECTED_BUTTON_ID = 'Agent-Details-Popover-unique-id';

describe('ee/workspaces/agent_mapping/components/agent_details_popover.vue', () => {
  /** @type {import('@vue/test-utils').Wrapper} */
  let wrapper;

  const createWrapper = (propsData = {}) => {
    wrapper = shallowMount(AgentDetailsPopover, {
      propsData: {
        agent: MAPPED_CLUSTER_AGENT,
        ...propsData,
      },
    });
  };

  const findAgentDataByLabel = (label) => {
    const agentDataComponent = wrapper
      .findAllComponents(AgentDataLabel)
      .wrappers.find((x) => x.props('label') === label);

    return agentDataComponent;
  };

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders button', () => {
      const button = wrapper.findComponent(GlButton);

      expect(button.attributes()).toMatchObject({
        id: EXPECTED_BUTTON_ID,
        'aria-label': 'Agent Information',
      });
    });

    it('render popover', () => {
      const popover = wrapper.findComponent(GlPopover);

      expect(popover.attributes()).toMatchObject({
        target: EXPECTED_BUTTON_ID,
        title: 'root-group-agent',
      });
    });

    it('renders agent data for project name', () => {
      expect(findAgentDataByLabel('Created in').text()).toEqual('GitLab Agent One');
    });

    it('renders agent data for status', () => {
      const agentData = findAgentDataByLabel('Status');
      const badge = agentData.findComponent(GlBadge);

      expect(badge.props('variant')).toEqual('success');
      expect(badge.text()).toEqual('Connected');
    });
  });

  describe('with agent not connected', () => {
    beforeEach(() => {
      createWrapper({
        agent: TEST_AGENT_NO_CONNECTED,
      });
    });

    it('render popover', () => {
      const popover = wrapper.findComponent(GlPopover);

      expect(popover.attributes()).toMatchObject({
        target: EXPECTED_BUTTON_ID,
        title: 'root-group-agent',
      });
    });

    it('renders agent data for status', () => {
      const agentData = findAgentDataByLabel('Status');
      const badge = agentData.findComponent(GlBadge);
      expect(badge.props('variant')).toEqual('neutral');
      expect(badge.text()).toEqual('Not Connected');
    });
  });
});
