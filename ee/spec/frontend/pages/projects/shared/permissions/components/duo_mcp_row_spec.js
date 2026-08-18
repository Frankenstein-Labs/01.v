import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoReadinessRow from '~/pages/projects/shared/permissions/components/duo_readiness_row.vue';
import DuoMcpRow from 'ee/pages/projects/shared/permissions/components/duo_mcp_row.vue';

describe('DuoMcpRow', () => {
  let wrapper;

  const createComponent = (mcp = {}) => {
    wrapper = shallowMountExtended(DuoMcpRow, {
      propsData: {
        mcp: { serversCount: 0, serversPath: '/group/project/-/automate/mcp-servers', ...mcp },
      },
    });
  };

  const findRow = () => wrapper.findComponent(DuoReadinessRow);
  const findViewServersButton = () => wrapper.findByTestId('mcp-view-servers-button');
  const findHowToConnectButton = () => wrapper.findByTestId('mcp-how-to-connect-button');

  describe('when no servers are available', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a neutral to-do row marked as an experiment', () => {
      expect(findRow().props('title')).toBe('MCP servers');
      expect(findRow().props('status')).toBe('todo');
      expect(findRow().props('description')).toBe(
        'Experiment. Agents can connect to tools your team already uses, such as Jira or Linear.',
      );
    });

    it('links to the MCP servers documentation', () => {
      expect(findHowToConnectButton().text()).toBe('How to connect');
      expect(findHowToConnectButton().attributes('href')).toBe(
        '/help/user/gitlab_duo/model_context_protocol/ai_catalog_mcp_servers.md',
      );
      expect(findHowToConnectButton().attributes('target')).toBe('_blank');
      expect(findViewServersButton().exists()).toBe(false);
    });
  });

  describe('when servers are available', () => {
    it('displays a single server and shows the view servers button', () => {
      createComponent({ serversCount: 1 });

      expect(findRow().props('status')).toBe('done');
      expect(findRow().props('description')).toBe(
        '1 MCP server is connected. Agents can use it in this project.',
      );
      expect(findViewServersButton().exists()).toBe(true);
      expect(findHowToConnectButton().exists()).toBe(false);
    });

    it('displays multiple servers and links to the servers page', () => {
      createComponent({ serversCount: 2 });

      expect(findRow().props('description')).toBe(
        '2 MCP servers are connected. Agents can use them in this project.',
      );
      expect(findViewServersButton().attributes('href')).toBe(
        '/group/project/-/automate/mcp-servers',
      );
      expect(findHowToConnectButton().exists()).toBe(false);
    });
  });
});
