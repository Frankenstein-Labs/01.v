import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { print } from 'graphql/language/printer';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import OrbitMainPage from 'ee/orbit/components/orbit_main_page.vue';
import { fetchGraphStatus } from 'ee/orbit/api/orbit_api';
import enabledMemberNamespacesQuery from 'ee/orbit/graphql/queries/enabled_member_namespaces.query.graphql';
import memberNamespacesQuery from 'ee/orbit/graphql/queries/member_namespaces.query.graphql';
import { ENABLED_MEMBER_NAMESPACES_LIMIT } from 'ee/orbit/utils/namespace_limits';
import { mockGroups } from '../mock_data';

Vue.use(VueApollo);

jest.mock('ee/orbit/api/orbit_api', () => ({
  fetchOrbitSchema: jest.fn().mockResolvedValue({ data: {} }),
  fetchGraphStatus: jest.fn(),
}));

describe('OrbitMainPage', () => {
  let wrapper;
  let enabledMemberNamespacesHandler;
  let memberNamespacesHandler;

  const enabledGroups = [
    mockGroups[0],
    {
      ...mockGroups[1],
      id: 'gid://gitlab/Group/3',
      name: 'GitLab.org',
      fullName: 'GitLab.org',
      fullPath: 'gitlab-org',
      knowledgeGraphEnabled: true,
    },
  ];

  const createNamespacesResponse = (nodes) => ({
    data: {
      groups: {
        nodes,
      },
    },
  });

  const graphStatusResponse = (domains) => ({ data: { domains } });

  const createComponent = async ({
    enabledGroupsResponse = createNamespacesResponse(enabledGroups),
    memberGroupsResponse = createNamespacesResponse(mockGroups),
  } = {}) => {
    localStorage.clear();
    fetchGraphStatus.mockClear();
    fetchGraphStatus.mockImplementation((fullPath) => {
      if (fullPath === 'frontend') {
        return Promise.resolve(
          graphStatusResponse([{ name: 'core', items: [{ name: 'Group', count: 2 }] }]),
        );
      }

      return Promise.resolve(
        graphStatusResponse([
          {
            name: 'core',
            items: [
              { name: 'Group', count: 1 },
              { name: 'Project', count: 4 },
              { name: 'MergeRequest', count: 10 },
            ],
          },
        ]),
      );
    });

    enabledMemberNamespacesHandler = jest.fn().mockResolvedValue(enabledGroupsResponse);
    memberNamespacesHandler = jest.fn().mockResolvedValue(memberGroupsResponse);

    const apolloProvider = createMockApollo([
      [enabledMemberNamespacesQuery, enabledMemberNamespacesHandler],
      [memberNamespacesQuery, memberNamespacesHandler],
    ]);

    wrapper = shallowMountExtended(OrbitMainPage, {
      apolloProvider,
      stubs: {
        GraphExplorer: {
          name: 'GraphExplorer',
          props: ['initialNodes'],
          template: '<div data-testid="graph-explorer"></div>',
        },
      },
    });

    await waitForPromises();
  };

  const findGraphExplorer = () => wrapper.findComponent({ name: 'GraphExplorer' });
  const findEmptyState = () => wrapper.findComponent({ name: 'OrbitExploreEmptyState' });

  it('queries only top-level enabled member groups', () => {
    expect(print(enabledMemberNamespacesQuery)).toContain('topLevelOnly: true');
    expect(print(enabledMemberNamespacesQuery)).toContain('allAvailable: false');
    expect(print(enabledMemberNamespacesQuery)).toContain('withKnowledgeGraphEnabled: true');
  });

  it('loads enabled member groups for the initial graph nodes', async () => {
    await createComponent();

    expect(enabledMemberNamespacesHandler).toHaveBeenCalledWith({
      first: ENABLED_MEMBER_NAMESPACES_LIMIT,
    });
    expect(memberNamespacesHandler).not.toHaveBeenCalled();
    expect(fetchGraphStatus).toHaveBeenCalledWith('frontend');
    expect(fetchGraphStatus).toHaveBeenCalledWith('gitlab-org');
    expect(
      findGraphExplorer()
        .props('initialNodes')
        .map((node) => node.properties.full_path),
    ).toEqual(['frontend', 'gitlab-org']);
  });

  it('caps graph nodes and graph status totals at 50 enabled member groups', async () => {
    const cappedGroups = Array.from(
      { length: ENABLED_MEMBER_NAMESPACES_LIMIT + 5 },
      (_, index) => ({
        ...mockGroups[0],
        id: `gid://gitlab/Group/${index + 1}`,
        name: `Group ${index}`,
        fullName: `Group ${index}`,
        fullPath: `group-${index}`,
        knowledgeGraphEnabled: true,
      }),
    );

    await createComponent({ enabledGroupsResponse: createNamespacesResponse(cappedGroups) });

    expect(
      findGraphExplorer()
        .props('initialNodes')
        .map((node) => node.properties.full_path),
    ).toHaveLength(ENABLED_MEMBER_NAMESPACES_LIMIT);
    expect(fetchGraphStatus).toHaveBeenCalledTimes(ENABLED_MEMBER_NAMESPACES_LIMIT);
    expect(fetchGraphStatus).toHaveBeenCalledWith('group-49');
    expect(fetchGraphStatus).not.toHaveBeenCalledWith('group-50');
  });

  it('uses the same top-level groups for the map nodes and graph status queries', async () => {
    const groups = [
      {
        ...mockGroups[0],
        fullPath: 'shown-a',
      },
      {
        ...mockGroups[0],
        id: 'gid://gitlab/Group/2',
        fullPath: 'not-kg-enabled',
        knowledgeGraphEnabled: false,
      },
      {
        ...mockGroups[0],
        id: 'gid://gitlab/Group/3',
        fullPath: '',
      },
      {
        ...mockGroups[0],
        id: 'gid://gitlab/Group/not-a-number',
        fullPath: 'invalid-id',
      },
      {
        ...mockGroups[0],
        id: 'gid://gitlab/Group/4',
        fullPath: 'shown-b',
      },
    ];

    await createComponent({ enabledGroupsResponse: createNamespacesResponse(groups) });

    const mapPaths = findGraphExplorer()
      .props('initialNodes')
      .map((node) => node.properties.full_path);
    const graphStatusPaths = fetchGraphStatus.mock.calls.map(([fullPath]) => fullPath);

    expect(mapPaths).toEqual(['shown-a', 'shown-b']);
    expect(graphStatusPaths).toEqual(mapPaths);
  });

  it('loads available groups for the empty state when no groups are enabled', async () => {
    await createComponent({
      enabledGroupsResponse: createNamespacesResponse([]),
    });

    expect(memberNamespacesHandler).toHaveBeenCalledWith({ first: 25 });
    expect(findEmptyState().props('availableGroups')).toEqual(mockGroups);
  });

  it('shows the displayed node count against the indexed graph status total', async () => {
    await createComponent();

    findGraphExplorer().vm.$emit('node-counts-change', { group: 2, project: 3 });
    await waitForPromises();

    expect(wrapper.findByTestId('orbit-index-count').text()).toBe('Showing 5 of 17 indexed nodes.');
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks click_orbit_switch_view with the destination view as label', async () => {
      await createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      wrapper.findComponentByTestId('view-table').vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_orbit_switch_view',
        { label: 'table' },
        undefined,
      );
    });

    it('does not track switch_view when clicking the already-selected view', async () => {
      await createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      wrapper.findComponentByTestId('view-map').vm.$emit('click');

      expect(trackEventSpy).not.toHaveBeenCalled();
    });

    it('tracks click_orbit_switch_map_mode with the picked mode as label', async () => {
      await createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      wrapper.findComponentByTestId('map-mode-2d').vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_orbit_switch_map_mode',
        { label: '2d' },
        undefined,
      );
    });

    it('does not track switch_map_mode when clicking the already-selected mode', async () => {
      await createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      wrapper.findComponentByTestId('map-mode-3d').vm.$emit('click');

      expect(trackEventSpy).not.toHaveBeenCalled();
    });
  });
});
