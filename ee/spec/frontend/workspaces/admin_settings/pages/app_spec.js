import { nextTick } from 'vue';
import { GlTableLite, GlBadge, GlAlert, GlKeysetPagination, GlSkeletonLoader } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import WorkspacesAgentAvailabilityApp from 'ee_component/workspaces/admin_settings/pages/app.vue';
import AvailabilityPopover from 'ee_component/workspaces/admin_settings/components/availability_popover.vue';
import GetOrganizationWorkspacesClusterAgentsQuery from 'ee_component/workspaces/admin_settings/components/get_organization_workspaces_cluster_agents_query.vue';
import AvailabilityToggle from 'ee_component/workspaces/admin_settings/components/availability_toggle.vue';
import { stubComponent } from 'helpers/stub_component';
import { getSlotFunction } from '~/lib/utils/vue3compat/normalize_render';

const MOCK_ORG_ID = 'gid://gitlab/Organizations::Organization/1';

const createMockAgents = (customAgent = {}) => {
  return [
    {
      id: 'gid://gitlab/Clusters::Agent/14',
      name: 'midnightowlgarden',
      url: 'http://test.host/gitlab-org/gitlab-agent-configurations/-/cluster_agents/midnightowlgarden',
      project: 'gitlab-agent-configurations',
      group: 'Gitlab Org',
      workspacesEnabled: true,
      isConnected: false,
      isMapped: true,
      ...customAgent,
    },
  ];
};

const MOCK_PAGINATION_DATA = {
  show: true,
  hasNextPage: true,
  hasPreviousPage: false,
  nextPage: jest.fn(),
  prevPage: jest.fn(),
};

describe('workspaces/admin_settings/pages/app.vue', () => {
  let wrapper;

  const buildWrapper = (organizationWorkspacesClusterAgentsQueryState = {}) => {
    wrapper = mountExtended(WorkspacesAgentAvailabilityApp, {
      provide: {
        organizationId: MOCK_ORG_ID,
      },
      stubs: {
        GetOrganizationWorkspacesClusterAgentsQuery: stubComponent(
          GetOrganizationWorkspacesClusterAgentsQuery,
          {
            // Vue 3-style zero-arg render; opt out of @vue/compat's legacy
            // render-function emulation, which misclassifies it.
            compatConfig: { RENDER_FUNCTION: false },
            render() {
              return getSlotFunction(this)?.({
                loading: false,
                agents: createMockAgents(),
                error: null,
                pagination: MOCK_PAGINATION_DATA,
                ...organizationWorkspacesClusterAgentsQueryState,
              });
            },
          },
        ),
      },
    });
  };

  const findGetOrganizationWorkspacesClusterAgentsQuery = () =>
    wrapper.findComponent(GetOrganizationWorkspacesClusterAgentsQuery);
  const findAgentsTable = () => wrapper.findComponent(GlTableLite);
  const findAvailabilityPopover = () => wrapper.findComponent(AvailabilityPopover);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findLoadingState = () => wrapper.findComponent(GlSkeletonLoader);
  const findAvailabilityToggle = () => wrapper.findComponent(AvailabilityToggle);

  describe('default', () => {
    beforeEach(async () => {
      buildWrapper({
        loading: true,
      });
      await nextTick();
    });

    it('renders GetOrganizationWorkspacesClusterAgentsQuery component and passes organizationId', () => {
      expect(findGetOrganizationWorkspacesClusterAgentsQuery().props('organizationId')).toBe(
        MOCK_ORG_ID,
      );
    });

    it('does not render agents table', () => {
      expect(findAgentsTable().exists()).toBe(false);
    });

    it('renders loading state', () => {
      expect(findLoadingState().exists()).toBe(true);
    });
  });

  describe('when GetOrganizationWorkspacesClusterAgentsQuery component emits result event', () => {
    it('renders empty state if no agents are returned', async () => {
      buildWrapper({
        agents: [],
      });

      await nextTick();

      const emptyStateComponent = wrapper.findByTestId('agent-availability-empty-state');

      expect(findAgentsTable().exists()).toBe(false);
      expect(emptyStateComponent.exists()).toBe(true);
    });

    describe('when an error is returned', () => {
      it('renders alert component', async () => {
        buildWrapper({
          agents: [],
          error: new Error('Some error'),
        });

        await nextTick();

        const alertComponent = findAlert();
        expect(alertComponent.exists()).toBe(true);
        expect(alertComponent.props('variant')).toBe('danger');
        expect(alertComponent.text()).toBe('Could not load agents. Refresh the page to try again.');
      });
    });

    describe('when agents are returned', () => {
      const mockResult = createMockAgents();
      beforeEach(async () => {
        buildWrapper({
          agents: mockResult,
        });
        await nextTick();
      });

      it('renders agents table', () => {
        expect(findAgentsTable().exists()).toBe(true);
      });

      it('renders popover in availability header column', () => {
        expect(findAvailabilityPopover().exists()).toBe(true);
      });

      it('renders agent name with link to the agent page', () => {
        const nameElement = wrapper.findByTestId('agent-link');

        expect(nameElement.exists()).toBe(true);
        expect(nameElement.attributes('href')).toBe(mockResult[0].url);
      });

      it('renders agent availability toggle', () => {
        expect(findAvailabilityToggle().exists()).toBe(true);
        expect(findAvailabilityToggle().props('agentId')).toBe(mockResult[0].id);
        expect(findAvailabilityToggle().props('isMapped')).toBe(mockResult[0].isMapped);
      });
    });
  });

  describe('status badges', () => {
    describe('connection status badge', () => {
      it('renders correct badge variant based for connected', async () => {
        buildWrapper({
          agents: createMockAgents({ isConnected: true }),
        });

        await nextTick();

        const badge = findBadge();
        expect(badge.props('variant')).toBe('success');
        expect(badge.text()).toBe('Connected');
      });

      it('renders correct badge variant based for not connected', async () => {
        buildWrapper({
          agents: createMockAgents({ isConnected: false }),
        });

        await nextTick();

        const badge = findBadge();
        expect(badge.props('variant')).toBe('neutral');
        expect(badge.text()).toBe('Not connected');
      });
    });
  });

  describe('pagination', () => {
    describe('when show is false', () => {
      it('does not render component', async () => {
        buildWrapper({
          pagination: {
            show: false,
            hasPreviousPage: false,
            hasNextPage: false,
          },
        });
        await nextTick();
        expect(findPagination().exists()).toBe(false);
      });
    });

    describe('when show is true', () => {
      const nextPageSpy = jest.fn();
      const prevPageSpy = jest.fn();

      beforeEach(async () => {
        nextPageSpy.mockClear();
        prevPageSpy.mockClear();

        buildWrapper({
          pagination: {
            ...MOCK_PAGINATION_DATA,
            nextPage: nextPageSpy,
            prevPage: prevPageSpy,
          },
        });
        await nextTick();
      });

      it('renders component if show is true', () => {
        const paginationComponent = findPagination();

        expect(paginationComponent.exists()).toBe(true);
        expect(paginationComponent.props('hasNextPage')).toBe(MOCK_PAGINATION_DATA.hasNextPage);
        expect(paginationComponent.props('hasPreviousPage')).toBe(
          MOCK_PAGINATION_DATA.hasPreviousPage,
        );
      });

      it('calls correct method when next event is emitted', async () => {
        const paginationComponent = findPagination();

        paginationComponent.vm.$emit('next');
        await nextTick();

        expect(nextPageSpy).toHaveBeenCalledTimes(1);
        expect(prevPageSpy).not.toHaveBeenCalled();
      });

      it('calls correct method when prev event is emitted', async () => {
        const paginationComponent = findPagination();

        paginationComponent.vm.$emit('prev');
        await nextTick();

        expect(prevPageSpy).toHaveBeenCalledTimes(1);
        expect(nextPageSpy).not.toHaveBeenCalled();
      });
    });
  });
});
