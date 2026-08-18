import { GlTab } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import AgentWorkspacesList from 'ee/workspaces/agent/components/agent_workspaces_list.vue';
import ClusterAgentShow from 'ee/clusters/agents/components/show.vue';
import AgentShowPage from '~/clusters/agents/components/show.vue';
import AgentVulnerabilityReport from 'ee/security_dashboard/components/agent/agent_vulnerability_report.vue';

describe('ClusterAgentShow', () => {
  let wrapper;

  const clusterAgentId = 'gid://gitlab/Clusters::Agent/1';

  // FIXME: We should try to use the real AgentShowPage since we're quite coupled to it
  const AgentShowPageStub = stubComponent(AgentShowPage, {
    inject: ['agentName', 'projectPath', 'clusterAgentId'],
    template: `<div>
          <slot name="ee-security-tab" :cluster-agent-id="clusterAgentId"></slot>
          <slot name="ee-workspaces-tab" :agent-name="agentName" :project-path="projectPath"></slot>
        </div>`,
  });

  const createWrapper = ({
    glLicensedFeatures = {
      kubernetesClusterVulnerabilities: true,
      remoteDevelopment: true,
    },
  } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(ClusterAgentShow, {
        provide: {
          glLicensedFeatures,
          agentName: 'test-agent',
          projectPath: 'test-project',
          clusterAgentId,
        },
        stubs: {
          AgentShowPage: AgentShowPageStub,
        },
      }),
    );
  };

  const createEmptyWrapper = () => wrapper.find('does-not-exist');
  const findTab = (title) =>
    wrapper.findAllComponents(GlTab).wrappers.find((x) => x.attributes('title') === title) ||
    createEmptyWrapper();

  describe('security tab', () => {
    const findSecurityTab = () => findTab('Security');
    const findAgentVulnerabilityReport = () =>
      findSecurityTab().findComponent(AgentVulnerabilityReport);

    describe('when a user does have permission', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('does not display the tab', () => {
        expect(findSecurityTab().exists()).toBe(true);
      });

      it('does display the cluster agent id', () => {
        expect(findAgentVulnerabilityReport().props('clusterAgentId')).toBe(clusterAgentId);
      });
    });

    describe('without access', () => {
      beforeEach(() => {
        createWrapper({ glLicensedFeatures: { kubernetesClusterVulnerabilities: false } });
      });

      it('when a user does not have permission', () => {
        expect(findSecurityTab().exists()).toBe(false);
      });
    });
  });

  describe('workspaces tab', () => {
    const findAgentWorkspacesTab = () => findTab('Workspaces');
    const findAgentWorkspacesList = () =>
      findAgentWorkspacesTab().findComponent(AgentWorkspacesList);

    describe('when remote development feature is enabled', () => {
      beforeEach(() => {
        createWrapper({ glLicensedFeatures: { remoteDevelopment: true } });
      });

      it('shows the tab', () => {
        expect(findAgentWorkspacesList().exists()).toBe(true);
        expect(findAgentWorkspacesList().props()).toEqual({
          agentName: 'test-agent',
          projectPath: 'test-project',
        });
      });
    });

    describe('when remote development feature is disabled', () => {
      beforeEach(() => {
        createWrapper({ glLicensedFeatures: { remoteDevelopment: false } });
      });

      it('does not show the tab', () => {
        expect(findAgentWorkspacesTab().exists()).toBe(false);
      });
    });
  });
});
