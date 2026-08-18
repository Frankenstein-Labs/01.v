import { GlTableLite } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import ReleasesTable from 'ee/cd/components/releases_table.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';

describe('ReleasesTable', () => {
  let wrapper;

  const releases = [
    {
      id: 'gid://gitlab/Cd::VersionSet/1',
      name: 'v1_1_0',
      createdAt: '2024-06-01T00:00:00Z',
      rollouts: {
        nodes: [{ id: 'gid://gitlab/Cd::Rollout/1', iid: 1 }],
      },
      latestRollout: {
        nodes: [
          {
            state: 'IN_PROGRESS',
            rolloutEnvironments: {
              nodes: [
                {
                  id: 'gid://gitlab/Cd::RolloutEnvironment/1',
                  environment: {
                    id: 'gid://gitlab/Cd::Environment/1',
                    serviceEnvironmentHealths: {
                      nodes: [
                        { id: 'gid://gitlab/Cd::ServiceEnvironmentHealth/1', health: 'HEALTHY' },
                        { id: 'gid://gitlab/Cd::ServiceEnvironmentHealth/2', health: 'DEGRADED' },
                      ],
                    },
                  },
                },
              ],
            },
          },
        ],
      },
      versionSetEntries: {
        count: 2,
        nodes: [
          { service: { id: 'gid://gitlab/Cd::Service/10' } },
          { service: { id: 'gid://gitlab/Cd::Service/10' } },
          { service: { id: 'gid://gitlab/Cd::Service/20' } },
        ],
      },
    },
    {
      id: 'gid://gitlab/Cd::VersionSet/2',
      name: 'v1_0_0',
      createdAt: '2024-05-01T00:00:00Z',
      rollouts: { nodes: [{ id: 'gid://gitlab/Cd::Rollout/2', iid: 2 }] },
      latestRollout: { nodes: [{ state: 'COMPLETED' }] },
      versionSetEntries: {
        count: 1,
        nodes: [{ service: { id: 'gid://gitlab/Cd::Service/10' } }],
      },
    },
  ];

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findRows = () => wrapper.findAll('tbody tr');
  const findHeaders = () => wrapper.findAll('thead th');
  const findRowCells = (rowIndex) => findRows().at(rowIndex).findAll('td');

  const createComponent = (props = {}) => {
    wrapper = mountExtended(ReleasesTable, {
      propsData: { releases, ...props },
    });
  };

  describe('collapsed (default)', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the version and status columns', () => {
      expect(findHeaders().wrappers.map((h) => h.text())).toEqual(['Version', 'Status']);
    });

    it('renders a row per release showing its version name', () => {
      expect(findRows()).toHaveLength(releases.length);
      expect(findRows().at(0).text()).toContain('v1_1_0');
      expect(findRows().at(1).text()).toContain('v1_0_0');
    });

    describe('when the row is clicked', () => {
      beforeEach(() => {
        findTable().vm.$emit('row-clicked', releases[0]);
      });

      it('emits select event with the release data', () => {
        expect(wrapper.emitted('select')).toEqual([[releases[0]]]);
      });
    });
  });

  describe('expanded (full)', () => {
    beforeEach(() => {
      createComponent({ full: true });
    });

    it('renders the columns in order: version, deployment id, services, created, status, health', () => {
      expect(findHeaders().wrappers.map((h) => h.text())).toEqual([
        'Version',
        'Deployment ID',
        'Services',
        'Created',
        'Status',
        'Health',
      ]);
    });

    it('shows the count of services in the release', () => {
      expect(findRowCells(0).at(2).text()).toBe('2');
      expect(findRowCells(1).at(2).text()).toBe('1');
    });

    it('shows the created date via TimeAgo', () => {
      expect(wrapper.findComponent(TimeAgo).props('time')).toBe('2024-06-01T00:00:00Z');
    });
  });

  describe('when a release has multiple rollouts', () => {
    beforeEach(() => {
      createComponent({
        full: true,
        releases: [
          {
            id: 'gid://gitlab/Cd::VersionSet/3',
            name: 'v',
            rollouts: {
              nodes: [
                { id: 'gid://gitlab/Cd::Rollout/1', iid: 3 },
                { id: 'gid://gitlab/Cd::Rollout/2', iid: 4 },
              ],
            },
            latestRollout: { nodes: [{ state: 'COMPLETED', rolloutEnvironments: { nodes: [] } }] },
            versionSetEntries: { count: 0 },
          },
        ],
      });
    });

    it('joins every rollout id in the deployment column', () => {
      expect(findRowCells(0).at(1).text()).toBe('#3, #4');
    });

    it('shows the status from the latest rollout only', () => {
      expect(findRowCells(0).at(4).text()).toBe('Available');
    });
  });

  describe('health column', () => {
    const buildRelease = (healths) => ({
      id: 'gid://gitlab/Cd::VersionSet/9',
      name: 'v',
      latestRollout: {
        nodes: [
          {
            id: 'gid://gitlab/Cd::Rollout/9',
            rolloutEnvironments: {
              nodes: [
                {
                  id: 'gid://gitlab/Cd::RolloutEnvironment/9',
                  environment: {
                    id: 'gid://gitlab/Cd::Environment/9',
                    serviceEnvironmentHealths: {
                      nodes: healths.map((health, index) => ({
                        id: `gid://gitlab/Cd::ServiceEnvironmentHealth/${index}`,
                        health,
                      })),
                    },
                  },
                },
              ],
            },
          },
        ],
      },
    });

    describe('when the release reports health', () => {
      it.each([
        [['DEGRADED', 'FAILED'], 'Failed'],
        [['HEALTHY', 'DEGRADED'], 'Degraded'],
        [['UNKNOWN'], 'Unknown'],
      ])('renders %s as the worst health "%s"', (healths, label) => {
        createComponent({ full: true, releases: [buildRelease(healths)] });

        expect(findRowCells(0).at(5).text()).toBe(label);
      });
    });

    describe('when the release has no health', () => {
      beforeEach(() => {
        createComponent({ full: true, releases: [buildRelease([])] });
      });

      it('shows a neutral placeholder', () => {
        expect(findRowCells(0).at(5).text()).toBe('—');
      });
    });
  });

  describe('status column', () => {
    it.each([
      ['PENDING', 'Pending'],
      ['IN_PROGRESS', 'In progress'],
      ['PAUSED', 'Paused'],
      ['COMPLETED', 'Available'],
      ['FAILED', 'Failed'],
      ['CANCELLED', 'Cancelled'],
    ])('renders the %s rollout state as "%s"', (state, label) => {
      createComponent({
        releases: [
          { id: 'gid://gitlab/Cd::VersionSet/9', name: 'v', latestRollout: { nodes: [{ state }] } },
        ],
      });

      expect(findRowCells(0).at(1).text()).toBe(label);
    });
  });

  describe('with a recent release', () => {
    beforeEach(() => {
      createComponent({ recentId: 'gid://gitlab/Cd::VersionSet/1' });
    });

    it('highlights the recent release row only', () => {
      expect(findRows().at(0).classes()).toContain('gl-bg-purple-50');
      expect(findRows().at(1).classes()).not.toContain('gl-bg-purple-50');
    });
  });

  describe('with a selected release', () => {
    beforeEach(() => {
      createComponent({ selectedId: 'gid://gitlab/Cd::VersionSet/1' });
    });

    it('highlights the selected release row only', () => {
      expect(findRows().at(0).classes()).toContain('gl-bg-blue-50');
      expect(findRows().at(1).classes()).not.toContain('gl-bg-blue-50');
    });
  });

  describe('with no releases', () => {
    beforeEach(() => {
      createComponent({ releases: [] });
    });

    it('renders no rows', () => {
      expect(findTable().exists()).toBe(true);
      expect(findRows()).toHaveLength(0);
    });
  });
});
