import AgentTable from '~/clusters_list/components/agent_table.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { clusterAgents } from 'jest/clusters_list/components/mock_data';

describe('AgentTable', () => {
  let wrapper;

  const findReceptiveBadge = () => wrapper.findByTestId('cluster-agent-is-receptive');

  const createWrapper = ({ agents } = {}) => {
    wrapper = mountExtended(AgentTable, {
      propsData: {
        agents,
      },
      provide: { fullPath: 'path/to/project', canAdminCluster: true, isGroup: false },
    });
  };

  describe('agent table', () => {
    it.each`
      condition                               | isReceptive
      ${'displays "receptive" badge'}         | ${true}
      ${'does not display "receptive" badge'} | ${false}
    `('$condition if isReceptive is "$isReceptive"', ({ isReceptive }) => {
      const agent = clusterAgents[0];
      agent.isReceptive = isReceptive;
      createWrapper({ agents: [agent] });

      expect(findReceptiveBadge().exists()).toBe(isReceptive);
    });

    it('renders "receptive" badge with the correct text and attributes', () => {
      const agent = clusterAgents[0];
      agent.isReceptive = true;
      createWrapper({ agents: [agent] });

      expect(findReceptiveBadge().text()).toBe('Receptive');
      expect(findReceptiveBadge().attributes('title')).toBe(
        'GitLab will establish the connection to this agent. A URL configuration is required.',
      );
    });
  });
});
