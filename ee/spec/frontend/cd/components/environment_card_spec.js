import { GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EnvironmentCard from 'ee/cd/components/environment_card.vue';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import {
  defaultAvailableAgents,
  makeCdEnvironment,
  makeCdEnvironmentDriverBinding,
  makeCdRolloutEnvironment,
  makeCdServiceEnvironmentHealth,
} from './mock_data';

describe('EnvironmentCard', () => {
  let wrapper;

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findRelease = () => wrapper.findByTestId('environment-card-release');
  const findLastDeploy = () => wrapper.findByTestId('environment-card-last-deploy');
  const findTimeAgo = () => findLastDeploy().findComponent(TimeAgoTooltip);
  const findDeployedBy = () => wrapper.findByTestId('environment-card-deployed-by');
  const findApps = () => wrapper.findByTestId('environment-card-apps');
  const findClusterAgent = () => wrapper.findByTestId('environment-card-cluster-agent');

  const createComponent = ({
    environment = makeCdEnvironment(),
    agents = defaultAvailableAgents,
  } = {}) => {
    wrapper = shallowMountExtended(EnvironmentCard, {
      propsData: { environment, agents },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the environment name', () => {
    expect(wrapper.text()).toContain('prod-eu-west-1');
  });

  describe('health badge', () => {
    it('renders the healthy badge when the environment is healthy', () => {
      expect(findBadge().props('variant')).toBe('success');
      expect(findBadge().text()).toBe('Healthy');
    });

    describe('when the environment is degraded', () => {
      beforeEach(() => {
        createComponent({
          environment: makeCdEnvironment({
            serviceEnvironmentHealths: {
              nodes: [makeCdServiceEnvironmentHealth({ health: 'DEGRADED' })],
            },
          }),
        });
      });

      it('renders a warning badge', () => {
        expect(findBadge().props('variant')).toBe('warning');
        expect(findBadge().text()).toBe('Degraded');
      });
    });

    describe('when the environment is failed', () => {
      beforeEach(() => {
        createComponent({
          environment: makeCdEnvironment({
            serviceEnvironmentHealths: {
              nodes: [makeCdServiceEnvironmentHealth({ health: 'FAILED' })],
            },
          }),
        });
      });

      it('renders a danger badge', () => {
        expect(findBadge().props('variant')).toBe('danger');
        expect(findBadge().text()).toBe('Failed');
      });
    });

    describe('when the environment has no health data', () => {
      beforeEach(() => {
        createComponent({
          environment: makeCdEnvironment({
            serviceEnvironmentHealths: { nodes: [] },
          }),
        });
      });

      it('renders a neutral badge with a placeholder label', () => {
        expect(findBadge().props('variant')).toBe('neutral');
        expect(findBadge().text()).toBe('—');
      });
    });
  });

  it('renders the Kubernetes infrastructure type', () => {
    expect(wrapper.text()).toContain('Kubernetes');
  });

  it('renders the applications count', () => {
    expect(findApps().text()).toBe('5 apps');
  });

  it('renders the name of the agent the driver config points at', () => {
    expect(findClusterAgent().text()).toBe('production-agent');
  });

  describe('when the environment has a finished rollout', () => {
    it('renders the version set name as the release', () => {
      expect(findRelease().text()).toBe('v2.4.1');
    });

    it('renders the last deploy time', () => {
      expect(findTimeAgo().props('time')).toBe('2026-07-01T10:00:00Z');
    });

    it('renders the username of the principal that triggered the first rollout transition', () => {
      expect(findDeployedBy().text()).toBe('jdoe');
    });
  });

  describe('when the environment has multiple finished rollouts', () => {
    beforeEach(() => {
      createComponent({
        environment: makeCdEnvironment({
          rolloutEnvironments: {
            nodes: [
              makeCdRolloutEnvironment(),
              makeCdRolloutEnvironment({
                id: 'gid://gitlab/Cd::RolloutEnvironment/2',
                finishedAt: '2026-07-05T10:00:00Z',
                rollout: {
                  id: 'gid://gitlab/Cd::Rollout/2',
                  versionSet: { id: 'gid://gitlab/Cd::VersionSet/2', name: 'v2.5.0' },
                  rolloutTransitions: {
                    nodes: [
                      {
                        id: 'gid://gitlab/Cd::RolloutTransition/2',
                        principalUser: { id: 'gid://gitlab/User/2', username: 'asmith' },
                      },
                    ],
                  },
                },
              }),
              makeCdRolloutEnvironment({
                id: 'gid://gitlab/Cd::RolloutEnvironment/3',
                finishedAt: null,
              }),
            ],
          },
        }),
      });
    });

    it('renders the details of the most recently finished rollout', () => {
      expect(findRelease().text()).toBe('v2.5.0');
      expect(findTimeAgo().props('time')).toBe('2026-07-05T10:00:00Z');
      expect(findDeployedBy().text()).toBe('asmith');
    });
  });

  describe('when the environment has no finished rollouts', () => {
    beforeEach(() => {
      createComponent({
        environment: makeCdEnvironment({ rolloutEnvironments: { nodes: [] } }),
      });
    });

    it('renders a placeholder for the release', () => {
      expect(findRelease().text()).toBe('—');
    });

    it('renders a placeholder for the last deploy time', () => {
      expect(findTimeAgo().exists()).toBe(false);
      expect(findLastDeploy().text()).toBe('—');
    });

    it('renders a placeholder for the deployed by value', () => {
      expect(findDeployedBy().text()).toBe('—');
    });
  });

  describe('when the environment has no applications', () => {
    beforeEach(() => {
      createComponent({
        environment: makeCdEnvironment({ applicationsCount: 0 }),
      });
    });

    it('renders a zero applications count', () => {
      expect(findApps().text()).toBe('0 apps');
    });
  });

  describe('when the environment has multiple driver binding versions', () => {
    beforeEach(() => {
      createComponent({
        environment: makeCdEnvironment({
          environmentDriverBindings: {
            nodes: [
              makeCdEnvironmentDriverBinding(),
              makeCdEnvironmentDriverBinding({
                id: 'gid://gitlab/Cd::EnvironmentDriverBinding/2',
                version: 2,
                driverConfig: { cluster_agent_id: '2' },
              }),
            ],
          },
        }),
      });
    });

    it('renders the cluster agent name of the highest version', () => {
      expect(findClusterAgent().text()).toBe('staging-agent');
    });
  });

  describe('when the environment has no driver bindings', () => {
    beforeEach(() => {
      createComponent({
        environment: makeCdEnvironment({ environmentDriverBindings: { nodes: [] } }),
      });
    });

    it('renders a placeholder for the cluster agent name', () => {
      expect(findClusterAgent().text()).toBe('—');
    });
  });

  describe('when the driver config carries no cluster agent id', () => {
    beforeEach(() => {
      createComponent({
        environment: makeCdEnvironment({
          environmentDriverBindings: {
            nodes: [makeCdEnvironmentDriverBinding({ driverConfig: {} })],
          },
        }),
      });
    });

    it('renders a placeholder for the cluster agent name', () => {
      expect(findClusterAgent().text()).toBe('—');
    });
  });

  describe('when the driver config points at an agent the viewer cannot see', () => {
    beforeEach(() => {
      createComponent({
        environment: makeCdEnvironment({
          environmentDriverBindings: {
            nodes: [makeCdEnvironmentDriverBinding({ driverConfig: { cluster_agent_id: '99' } })],
          },
        }),
      });
    });

    it('renders a placeholder for the cluster agent name', () => {
      expect(findClusterAgent().text()).toBe('—');
    });
  });

  describe('when the agents have not loaded yet', () => {
    beforeEach(() => {
      createComponent({ agents: [] });
    });

    it('renders a placeholder for the cluster agent name', () => {
      expect(findClusterAgent().text()).toBe('—');
    });
  });
});
