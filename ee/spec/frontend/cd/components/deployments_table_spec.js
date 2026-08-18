import { GlTableLite } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import DeploymentsTable from 'ee/cd/components/deployments_table.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';

describe('DeploymentsTable', () => {
  let wrapper;

  const environments = [
    { id: 'gid://gitlab/Cd::Environment/1', name: 'dev-1', tier: 'DEVELOPMENT' },
    { id: 'gid://gitlab/Cd::Environment/2', name: 'staging-1', tier: 'STAGING' },
    { id: 'gid://gitlab/Cd::Environment/3', name: 'prod-1', tier: 'PRODUCTION' },
  ];

  const rolloutEnvironment = (id, state, environment) => ({
    id: `gid://gitlab/Cd::RolloutEnvironment/${id}`,
    state,
    environment,
  });

  const deployments = [
    {
      id: 'gid://gitlab/Cd::Rollout/1',
      iid: 7,
      state: 'IN_PROGRESS',
      createdAt: '2024-06-01T00:00:00Z',
      versionSet: { id: 'gid://gitlab/Cd::VersionSet/1', name: 'v2_5_7' },
      rolloutEnvironments: {
        nodes: [
          rolloutEnvironment(1, 'COMPLETED', {
            id: 'gid://gitlab/Cd::Environment/1',
            name: 'dev-1',
            tier: 'DEVELOPMENT',
          }),
          rolloutEnvironment(2, 'FAILED', {
            id: 'gid://gitlab/Cd::Environment/3',
            name: 'prod-1',
            tier: 'PRODUCTION',
          }),
        ],
      },
    },
    {
      id: 'gid://gitlab/Cd::Rollout/2',
      iid: 8,
      state: 'COMPLETED',
      createdAt: '2024-05-01T00:00:00Z',
      versionSet: { id: 'gid://gitlab/Cd::VersionSet/2', name: 'v2_5_6' },
      rolloutEnvironments: { nodes: [] },
    },
  ];

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findRows = () => wrapper.findAll('tbody tr');
  const findHeaders = () => wrapper.findAll('thead th');
  const findRowCells = (rowIndex) => findRows().at(rowIndex).findAll('td');
  const findStateDots = () => wrapper.findAllByTestId('state-dot');
  const findTierEnvironments = () => wrapper.findAllByTestId('tier-environment');

  const createComponent = (props = {}) => {
    wrapper = mountExtended(DeploymentsTable, {
      propsData: { deployments, environments, ...props },
    });
  };

  describe('collapsed (default)', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the id, version and status columns', () => {
      expect(findHeaders().wrappers.map((h) => h.text())).toEqual(['ID', 'Version', 'Status']);
    });

    it('renders a row per deployment showing its id and version name', () => {
      expect(findRows()).toHaveLength(deployments.length);
      expect(findRowCells(0).at(0).text()).toBe('#7');
      expect(findRowCells(0).at(1).text()).toBe('v2_5_7');
      expect(findRowCells(1).at(0).text()).toBe('#8');
      expect(findRowCells(1).at(1).text()).toBe('v2_5_6');
    });

    describe('when a row is clicked', () => {
      beforeEach(() => {
        findTable().vm.$emit('row-clicked', deployments[0]);
      });

      it('emits select with the deployment', () => {
        expect(wrapper.emitted('select')).toEqual([[deployments[0]]]);
      });
    });
  });

  describe('expanded (full)', () => {
    beforeEach(() => {
      createComponent({ full: true });
    });

    it('renders id, release, status, a column per present tier, then created', () => {
      expect(findHeaders().wrappers.map((h) => h.text())).toEqual([
        'ID',
        'Release',
        'Status',
        'Development',
        'Staging',
        'Production',
        'Created',
      ]);
    });

    it('shows the release name in the release column', () => {
      expect(findRowCells(0).at(1).text()).toBe('v2_5_7');
    });

    it('shows the created date via TimeAgo', () => {
      expect(wrapper.findComponent(TimeAgo).props('time')).toBe('2024-06-01T00:00:00Z');
    });

    it('lists each environment under its tier column and a placeholder where empty', () => {
      // columns: 0 ID, 1 Release, 2 Status, 3 Development, 4 Staging, 5 Production, 6 Created
      expect(findRowCells(0).at(3).text()).toContain('dev-1');
      expect(findRowCells(0).at(4).text()).toBe('—');
      expect(findRowCells(0).at(5).text()).toContain('prod-1');
    });

    it('colors the dot by the rollout state in each environment', () => {
      expect(findStateDots().at(0).classes()).toContain('gl-bg-green-500');
      expect(findStateDots().at(1).classes()).toContain('gl-bg-red-500');
    });

    it('shows the per-environment rollout state as a tooltip', () => {
      expect(findTierEnvironments().at(1).attributes('title')).toBe('Failed');
    });

    describe('when a rollout environment has no state', () => {
      beforeEach(() => {
        createComponent({
          full: true,
          environments: [
            { id: 'gid://gitlab/Cd::Environment/1', name: 'dev-1', tier: 'DEVELOPMENT' },
          ],
          deployments: [
            {
              id: 'gid://gitlab/Cd::Rollout/9',
              iid: 9,
              state: 'IN_PROGRESS',
              versionSet: { name: 'v' },
              rolloutEnvironments: {
                nodes: [
                  {
                    id: 'gid://gitlab/Cd::RolloutEnvironment/9',
                    state: null,
                    environment: {
                      id: 'gid://gitlab/Cd::Environment/1',
                      name: 'dev-1',
                      tier: 'DEVELOPMENT',
                    },
                  },
                ],
              },
            },
          ],
        });
      });

      it('falls back to a neutral dot and an unknown tooltip', () => {
        expect(findStateDots().at(0).classes()).toContain('gl-bg-gray-400');
        expect(findTierEnvironments().at(0).attributes('title')).toBe('Unknown');
      });
    });

    describe('when a deployment has no version set', () => {
      beforeEach(() => {
        createComponent({
          full: true,
          deployments: [{ id: 'gid://gitlab/Cd::Rollout/9', iid: 9, state: 'IN_PROGRESS' }],
        });
      });

      it('shows a placeholder in the release column', () => {
        expect(findRowCells(0).at(1).text()).toBe('—');
      });
    });
  });

  describe('tier columns', () => {
    it('renders known tiers in promotion order regardless of environment prop order', () => {
      createComponent({
        full: true,
        environments: [
          { id: 'gid://gitlab/Cd::Environment/3', name: 'prod-1', tier: 'PRODUCTION' },
          { id: 'gid://gitlab/Cd::Environment/1', name: 'dev-1', tier: 'DEVELOPMENT' },
          { id: 'gid://gitlab/Cd::Environment/9', name: 'qa-1', tier: 'QA' },
        ],
      });

      expect(findHeaders().wrappers.map((h) => h.text())).toEqual([
        'ID',
        'Release',
        'Status',
        'Development',
        'QA',
        'Production',
        'Created',
      ]);
    });

    it('appends an unknown tier after the known ones, labeled with its raw value', () => {
      createComponent({
        full: true,
        environments: [
          { id: 'gid://gitlab/Cd::Environment/1', name: 'dev-1', tier: 'DEVELOPMENT' },
          { id: 'gid://gitlab/Cd::Environment/8', name: 'canary-1', tier: 'CANARY' },
        ],
      });

      expect(findHeaders().wrappers.map((h) => h.text())).toEqual([
        'ID',
        'Release',
        'Status',
        'Development',
        'CANARY',
        'Created',
      ]);
    });

    it('ignores environments with a null tier', () => {
      createComponent({
        full: true,
        environments: [
          { id: 'gid://gitlab/Cd::Environment/1', name: 'dev-1', tier: 'DEVELOPMENT' },
          { id: 'gid://gitlab/Cd::Environment/7', name: 'orphan', tier: null },
        ],
      });

      expect(findHeaders().wrappers.map((h) => h.text())).toEqual([
        'ID',
        'Release',
        'Status',
        'Development',
        'Created',
      ]);
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
        deployments: [
          { id: 'gid://gitlab/Cd::Rollout/9', iid: 9, state, versionSet: { name: 'v' } },
        ],
      });

      expect(findRowCells(0).at(2).text()).toBe(label);
    });
  });

  describe('with no deployments', () => {
    beforeEach(() => {
      createComponent({ deployments: [] });
    });

    it('renders no rows', () => {
      expect(findTable().exists()).toBe(true);
      expect(findRows()).toHaveLength(0);
    });
  });

  describe('row highlighting', () => {
    it('applies the recent highlight to the matching row', () => {
      createComponent({ recentId: 'gid://gitlab/Cd::Rollout/1' });

      expect(findRows().at(0).classes()).toContain('gl-bg-purple-50');
      expect(findRows().at(1).classes()).not.toContain('gl-bg-purple-50');
    });

    it('applies the selected highlight to the matching row', () => {
      createComponent({ selectedId: 'gid://gitlab/Cd::Rollout/1' });

      expect(findRows().at(0).classes()).toContain('gl-bg-blue-50');
      expect(findRows().at(1).classes()).not.toContain('gl-bg-blue-50');
    });

    describe('when a row is both selected and recent', () => {
      beforeEach(() => {
        createComponent({
          selectedId: 'gid://gitlab/Cd::Rollout/1',
          recentId: 'gid://gitlab/Cd::Rollout/1',
        });
      });

      it('prefers the selected (blue) highlight', () => {
        expect(findRows().at(0).classes()).toContain('gl-bg-blue-50');
        expect(findRows().at(0).classes()).not.toContain('gl-bg-purple-50');
      });
    });
  });
});
