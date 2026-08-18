import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { createAlert } from '~/alert';
import GraphExplorer from 'ee/orbit/components/graph_explorer.vue';
import GraphCanvas from 'ee/orbit/components/graph_canvas.vue';
import GraphFilterBar from 'ee/orbit/components/graph_filter_bar.vue';
import GraphLegend from 'ee/orbit/components/graph_legend.vue';
import ExplorerNodeSidebar from 'ee/orbit/components/explorer_node_sidebar.vue';
import ExplorerQueryPanel from 'ee/orbit/components/explorer_query_panel.vue';
import ExplorerTablePanel from 'ee/orbit/components/explorer_table_panel.vue';
import * as orbitApi from 'ee/orbit/api/orbit_api';
import { mockQueryResponse, mockNeighborResponse } from '../mock_data';

jest.mock('~/alert');
jest.mock('ee/orbit/api/orbit_api');

describe('GraphExplorer', () => {
  let wrapper;

  const mockGroupNode = {
    id: 'Group_1',
    label: 'frontend',
    type: 'group',
    properties: { id: 1, full_path: 'gitlab-org/frontend' },
  };

  const mockTemplates = [
    {
      name: 'my_neighbors',
      description: 'My neighbors in the graph',
      raw_query: {
        query_type: 'neighbors',
        node: { id: 'me', entity: 'User', node_ids: [1] },
        neighbors: { node: 'me', direction: 'both' },
        limit: 100,
      },
    },
    {
      name: 'recent_merges',
      description: 'Recently merged merge requests and the people who merged them',
      raw_query: { query_type: 'traversal', nodes: [], relationships: [], limit: 100 },
    },
  ];

  const GraphCanvasStub = {
    name: 'GraphCanvas',
    props: ['nodes', 'edges', 'selectedNodeId', 'nodeStyleMap', 'darkMode', 'mapMode'],
    template: '<div data-testid="graph-canvas-stub"></div>',
    methods: {
      setFullData: jest.fn(),
      addData: jest.fn(),
      highlightByTypes: jest.fn(),
      zoomIn: jest.fn(),
      zoomOut: jest.fn(),
      setNodeLoading: jest.fn(),
    },
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(GraphExplorer, {
      propsData: {
        initialNodes: [mockGroupNode],
        initialEdges: [],
        ...props,
      },
      stubs: { GraphCanvas: GraphCanvasStub },
    });
  };

  beforeEach(() => {
    jest.clearAllMocks();
    localStorage.clear();
    orbitApi.executeOrbitQuery.mockResolvedValue({ data: { result: { nodes: [], edges: [] } } });
    orbitApi.executeOrbitNamedQuery.mockResolvedValue({
      data: { result: { nodes: [], edges: [] } },
    });
    orbitApi.fetchOrbitTemplates.mockResolvedValue({ data: mockTemplates });
  });

  describe('rendering', () => {
    it('renders the explorer container', () => {
      createWrapper();

      expect(wrapper.find('[data-testid="graph-explorer"]').exists()).toBe(true);
    });

    it('renders the graph canvas in map view', () => {
      createWrapper({ view: 'map' });

      expect(wrapper.findComponent(GraphCanvas).exists()).toBe(true);
      expect(wrapper.findComponent(ExplorerTablePanel).exists()).toBe(false);
    });

    it('renders the table panel in table view', () => {
      createWrapper({ view: 'table' });

      expect(wrapper.findComponent(ExplorerTablePanel).exists()).toBe(true);
      expect(wrapper.findComponent(GraphCanvas).exists()).toBe(false);
    });

    it('renders the query panel only when advancedOpen is true', () => {
      createWrapper({ advancedOpen: false });
      expect(wrapper.findComponent(ExplorerQueryPanel).exists()).toBe(false);

      createWrapper({ advancedOpen: true });
      expect(wrapper.findComponent(ExplorerQueryPanel).exists()).toBe(true);
    });

    it('renders the filter bar with the legend items derived from nodes', async () => {
      createWrapper({ initialNodes: [mockGroupNode], filterOpen: true });
      await nextTick();

      const filterBar = wrapper.findComponent(GraphFilterBar);
      expect(filterBar.exists()).toBe(true);
      expect(filterBar.props('legendItems')).toEqual(
        expect.arrayContaining([expect.objectContaining({ type: 'group' })]),
      );
    });

    it('does not render the filter bar when filterOpen is false', () => {
      createWrapper({ filterOpen: false });

      expect(wrapper.findComponent(GraphFilterBar).exists()).toBe(false);
    });
  });

  describe('initial neighbor expansion', () => {
    it('fetches neighbors of the initial group nodes on mount', async () => {
      createWrapper();
      await waitForPromises();

      expect(orbitApi.executeOrbitNamedQuery).toHaveBeenCalledWith('expand_neighbors', {
        parameters: { entity: 'Group', node_ids: [1], limit: 500 },
      });
    });

    it('fetches neighbors when initial group nodes arrive after mount', async () => {
      createWrapper({ initialNodes: [] });
      await waitForPromises();

      expect(orbitApi.executeOrbitNamedQuery).not.toHaveBeenCalled();

      await wrapper.setProps({ initialNodes: [mockGroupNode] });
      await waitForPromises();

      expect(orbitApi.executeOrbitNamedQuery).toHaveBeenCalledWith('expand_neighbors', {
        parameters: { entity: 'Group', node_ids: [1], limit: 500 },
      });
    });

    it('skips initial expansion when an instance map request is supplied', async () => {
      createWrapper({
        instanceMapRequest: { entityType: 'Project', filters: { name: 'foo' } },
      });
      await waitForPromises();

      // The instance-map query goes through executeOrbitQuery as a traversal
      // (single-node, no relationships), not a named neighbors query.
      expect(orbitApi.executeOrbitNamedQuery).not.toHaveBeenCalled();
      expect(orbitApi.executeOrbitQuery).toHaveBeenCalledWith(
        expect.objectContaining({ query_type: 'traversal' }),
      );
    });

    it('alerts when the neighbor fetch fails', async () => {
      orbitApi.executeOrbitNamedQuery.mockRejectedValueOnce(new Error('boom'));
      createWrapper();
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({ message: 'boom' });
    });
  });

  describe('executing a custom query', () => {
    it('forwards the parsed query to the API and stores the response', async () => {
      orbitApi.executeOrbitQuery.mockResolvedValueOnce(mockQueryResponse);
      createWrapper({ initialNodes: [], advancedOpen: true, view: 'table' });

      const query = {
        query_type: 'traversal',
        node: { id: 'n', entity: 'User', columns: '*' },
      };
      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      queryPanel.vm.$emit('update:query-text', JSON.stringify(query));
      queryPanel.vm.$emit('execute');
      await waitForPromises();

      expect(orbitApi.executeOrbitQuery).toHaveBeenCalledWith(query);
      expect(wrapper.findComponent(ExplorerTablePanel).props('rows')).toEqual([
        { type: 'User', id: 1, username: 'admin', name: 'Administrator' },
        { type: 'User', id: 2, username: 'dev', name: 'Developer' },
      ]);
    });

    it('surfaces an inline error on invalid JSON', async () => {
      createWrapper({ initialNodes: [], advancedOpen: true });

      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      queryPanel.vm.$emit('update:query-text', '{ invalid');
      queryPanel.vm.$emit('execute');
      await waitForPromises();

      expect(queryPanel.props('errorMessage')).toEqual(expect.stringContaining('Invalid JSON'));
      expect(queryPanel.props('errorDetails')).toBeNull();
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('exposes the backend message as details on 4xx responses', async () => {
      orbitApi.executeOrbitQuery.mockRejectedValueOnce({
        response: { status: 400, data: { message: 'schema violation: "blah"' } },
      });
      createWrapper({ initialNodes: [], advancedOpen: true });

      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      queryPanel.vm.$emit('update:query-text', '{"query_type":"blah"}');
      queryPanel.vm.$emit('execute');
      await waitForPromises();

      expect(queryPanel.props('errorMessage')).toEqual(expect.stringContaining('Invalid query'));
      expect(queryPanel.props('errorDetails')).toContain('schema violation');
    });

    it('hides the backend message on 5xx responses', async () => {
      orbitApi.executeOrbitQuery.mockRejectedValueOnce({
        response: { status: 500, data: { message: 'internal: panic at row 0x1234' } },
      });
      createWrapper({ initialNodes: [], advancedOpen: true });

      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      queryPanel.vm.$emit(
        'update:query-text',
        '{"query_type":"traversal","node":{"id":"n","entity":"User"}}',
      );
      queryPanel.vm.$emit('execute');
      await waitForPromises();

      expect(queryPanel.props('errorMessage')).toEqual(
        expect.stringContaining('Failed to execute query'),
      );
      expect(queryPanel.props('errorDetails')).toBeNull();
    });

    it('fetches the template catalog when the advanced panel opens', async () => {
      createWrapper({ initialNodes: [], advancedOpen: true });
      await waitForPromises();

      expect(orbitApi.fetchOrbitTemplates).toHaveBeenCalledTimes(1);
      expect(wrapper.findComponent(ExplorerQueryPanel).props('templateItems')).toEqual([
        { value: 'my_neighbors', text: mockTemplates[0].description },
        { value: 'recent_merges', text: mockTemplates[1].description },
      ]);
    });

    it('selects the first catalog preset by default and populates the editor', async () => {
      createWrapper({ initialNodes: [], advancedOpen: true });
      await waitForPromises();

      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      expect(queryPanel.props('selectedTemplate')).toBe('my_neighbors');
      expect(queryPanel.props('queryText')).toBe(
        JSON.stringify(mockTemplates[0].raw_query, null, 2),
      );
    });

    it('does not override a caller-provided initial query with the default preset', async () => {
      const initialQuery = { query_type: 'traversal', node: { id: 'n', entity: 'User' } };
      createWrapper({ initialNodes: [], advancedOpen: true, initialQuery });
      await waitForPromises();

      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      expect(queryPanel.props('selectedTemplate')).toBeNull();
      expect(queryPanel.props('queryText')).toBe(JSON.stringify(initialQuery, null, 2));
    });

    it('does not fetch the template catalog when the advanced panel is closed', () => {
      createWrapper({ initialNodes: [], advancedOpen: false });

      expect(orbitApi.fetchOrbitTemplates).not.toHaveBeenCalled();
    });

    it('does not refetch the catalog on repeated opens', async () => {
      createWrapper({ initialNodes: [], advancedOpen: true });
      await waitForPromises();

      await wrapper.setProps({ advancedOpen: false });
      await wrapper.setProps({ advancedOpen: true });
      await waitForPromises();

      expect(orbitApi.fetchOrbitTemplates).toHaveBeenCalledTimes(1);
    });

    it('alerts when the template catalog fails to load', async () => {
      orbitApi.fetchOrbitTemplates.mockRejectedValueOnce(new Error('boom'));
      createWrapper({ initialNodes: [], advancedOpen: true });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({ message: 'boom' });
    });

    it('passes the chosen template back to the query panel as selectedTemplate', async () => {
      createWrapper({ initialNodes: [], advancedOpen: true });
      await waitForPromises();

      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      const [firstTemplate] = queryPanel.props('templateItems');
      queryPanel.vm.$emit('template-select', firstTemplate.value);
      await nextTick();

      expect(wrapper.findComponent(ExplorerQueryPanel).props('selectedTemplate')).toBe(
        firstTemplate.value,
      );
    });

    it("populates the editor with the template's rendered DSL on selection", async () => {
      createWrapper({ initialNodes: [], advancedOpen: true });
      await waitForPromises();

      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      queryPanel.vm.$emit('template-select', 'my_neighbors');
      await nextTick();

      expect(wrapper.findComponent(ExplorerQueryPanel).props('queryText')).toBe(
        JSON.stringify(mockTemplates[0].raw_query, null, 2),
      );
    });

    it('executes a pristine selected template by name, not as free-form DSL', async () => {
      createWrapper({ initialNodes: [], advancedOpen: true });
      await waitForPromises();

      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      queryPanel.vm.$emit('template-select', 'my_neighbors');
      await nextTick();
      queryPanel.vm.$emit('execute');
      await waitForPromises();

      expect(orbitApi.executeOrbitNamedQuery).toHaveBeenCalledWith('my_neighbors');
      expect(orbitApi.executeOrbitQuery).not.toHaveBeenCalled();
    });

    it('reverts to a free-form query when the editor text changes after a template was selected', async () => {
      createWrapper({ initialNodes: [], advancedOpen: true });
      await waitForPromises();

      const query = {
        query_type: 'traversal',
        node: { id: 'n', entity: 'User', columns: '*' },
      };
      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      queryPanel.vm.$emit('template-select', 'my_neighbors');
      queryPanel.vm.$emit('update:query-text', JSON.stringify(query));
      queryPanel.vm.$emit('execute');
      await waitForPromises();

      expect(orbitApi.executeOrbitNamedQuery).not.toHaveBeenCalled();
      expect(orbitApi.executeOrbitQuery).toHaveBeenCalledWith(query);
      expect(wrapper.findComponent(ExplorerQueryPanel).props('selectedTemplate')).toBeNull();
    });

    it('keeps the selected template when the editor re-emits the programmatic clear', async () => {
      createWrapper({ initialNodes: [], advancedOpen: true });
      await waitForPromises();

      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      queryPanel.vm.$emit('template-select', 'my_neighbors');
      await nextTick();
      queryPanel.vm.$emit('update:query-text', queryPanel.props('queryText'));
      await nextTick();

      expect(wrapper.findComponent(ExplorerQueryPanel).props('selectedTemplate')).toBe(
        'my_neighbors',
      );
    });

    it('clears selectedTemplate when the panel emits clear', async () => {
      createWrapper({ initialNodes: [], advancedOpen: true });
      await waitForPromises();

      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      const [firstTemplate] = queryPanel.props('templateItems');
      queryPanel.vm.$emit('template-select', firstTemplate.value);
      await nextTick();

      queryPanel.vm.$emit('clear');
      await nextTick();

      expect(wrapper.findComponent(ExplorerQueryPanel).props('selectedTemplate')).toBeNull();
    });
  });

  describe('node interaction', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('records the selected node and shows the sidebar', async () => {
      const canvas = wrapper.findComponent(GraphCanvas);
      canvas.vm.$emit('node-select', { id: 'Group_1', label: 'frontend', type: 'group' });
      await nextTick();

      expect(wrapper.findComponent(ExplorerNodeSidebar).exists()).toBe(true);
    });

    it('hides the sidebar when the selection is cleared', async () => {
      const canvas = wrapper.findComponent(GraphCanvas);
      canvas.vm.$emit('node-select', { id: 'Group_1' });
      await nextTick();

      wrapper.findComponent(ExplorerNodeSidebar).vm.$emit('close');
      await nextTick();

      expect(wrapper.findComponent(ExplorerNodeSidebar).exists()).toBe(false);
    });

    it('expands a node by fetching its neighbors with the per-node limit', async () => {
      // Wait for the mount-time auto-expand to complete first so we can
      // observe the per-node expansion in isolation.
      await waitForPromises();
      orbitApi.executeOrbitNamedQuery.mockClear();
      orbitApi.executeOrbitNamedQuery.mockResolvedValue(mockNeighborResponse);

      const canvas = wrapper.findComponent(GraphCanvas);
      canvas.vm.$emit('node-expand', {
        id: 'Project_2',
        type: 'project',
        properties: { id: 2 },
      });
      await waitForPromises();

      expect(orbitApi.executeOrbitNamedQuery).toHaveBeenCalledWith('expand_neighbors', {
        parameters: { entity: 'Project', node_ids: [2], limit: 50 },
      });
    });

    it('does not re-expand a node that was already expanded', async () => {
      await waitForPromises();
      orbitApi.executeOrbitNamedQuery.mockClear();
      orbitApi.executeOrbitNamedQuery.mockResolvedValue(mockNeighborResponse);

      const canvas = wrapper.findComponent(GraphCanvas);
      const node = { id: 'Project_2', type: 'project', properties: { id: 2 } };

      canvas.vm.$emit('node-expand', node);
      await waitForPromises();
      const firstCallCount = orbitApi.executeOrbitNamedQuery.mock.calls.length;

      canvas.vm.$emit('node-expand', node);
      await waitForPromises();

      expect(orbitApi.executeOrbitNamedQuery).toHaveBeenCalledTimes(firstCallCount);
    });

    it('marks the node as loading on the canvas while the request is in flight', async () => {
      await waitForPromises();
      orbitApi.executeOrbitNamedQuery.mockClear();
      orbitApi.executeOrbitNamedQuery.mockResolvedValue(mockNeighborResponse);
      GraphCanvasStub.methods.setNodeLoading.mockClear();

      const canvas = wrapper.findComponent(GraphCanvas);
      const node = { id: 'Project_2', type: 'project', index: 4, properties: { id: 2 } };
      expect(GraphCanvasStub.methods.setNodeLoading).not.toHaveBeenCalled();
      canvas.vm.$emit('node-expand', node);
      await waitForPromises();

      expect(GraphCanvasStub.methods.setNodeLoading).toHaveBeenNthCalledWith(1, 4, true);
      expect(GraphCanvasStub.methods.setNodeLoading).toHaveBeenNthCalledWith(2, 4, false);
    });

    it('clears the loading flag even when the expand request fails', async () => {
      await waitForPromises();
      orbitApi.executeOrbitNamedQuery.mockClear();
      orbitApi.executeOrbitNamedQuery.mockRejectedValueOnce(new Error('boom'));
      GraphCanvasStub.methods.setNodeLoading.mockClear();

      const canvas = wrapper.findComponent(GraphCanvas);
      const node = { id: 'Project_3', type: 'project', index: 7, properties: { id: 3 } };
      expect(GraphCanvasStub.methods.setNodeLoading).not.toHaveBeenCalled();
      canvas.vm.$emit('node-expand', node);
      await waitForPromises();

      expect(GraphCanvasStub.methods.setNodeLoading).toHaveBeenNthCalledWith(1, 7, true);
      expect(GraphCanvasStub.methods.setNodeLoading).toHaveBeenLastCalledWith(7, false);
    });
  });

  describe('legend interactions', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('soloes a type when the legend emits select-type', async () => {
      const legend = wrapper.findComponent(GraphLegend);
      legend.vm.$emit('select-type', 'group');
      await nextTick();

      expect(Array.from(wrapper.findComponent(GraphLegend).props('activeTypeFilters'))).toEqual([
        'group',
      ]);
    });

    it('clears the highlight when the same type is selected twice', async () => {
      const legend = wrapper.findComponent(GraphLegend);
      legend.vm.$emit('select-type', 'group');
      await nextTick();
      legend.vm.$emit('select-type', 'group');
      await nextTick();

      expect(Array.from(wrapper.findComponent(GraphLegend).props('activeTypeFilters'))).toEqual([]);
    });
  });

  describe('row clicks from the table view', () => {
    beforeEach(async () => {
      // Skip auto-expand by starting with no initial nodes, so the only API
      // call we observe is the explicit query below.
      orbitApi.executeOrbitQuery.mockResolvedValue(mockQueryResponse);
      createWrapper({ view: 'table', advancedOpen: true, initialNodes: [] });
      const queryPanel = wrapper.findComponent(ExplorerQueryPanel);
      queryPanel.vm.$emit(
        'update:query-text',
        JSON.stringify({
          query_type: 'traversal',
          node: { id: 'n', entity: 'User' },
        }),
      );
      queryPanel.vm.$emit('execute');
      await waitForPromises();
    });

    it('selects the matching graph node when a row is clicked', async () => {
      const tablePanel = wrapper.findComponent(ExplorerTablePanel);
      tablePanel.vm.$emit('row-click', { type: 'User', id: 1 });
      await nextTick();
      await wrapper.setProps({ view: 'map' });

      const sidebar = wrapper.findComponent(ExplorerNodeSidebar);
      expect(sidebar.exists()).toBe(true);
      expect(sidebar.props('node')).toEqual(expect.objectContaining({ id: 'User_1' }));
    });

    it('alerts when the row has no matching graph node', async () => {
      const tablePanel = wrapper.findComponent(ExplorerTablePanel);
      tablePanel.vm.$emit('row-click', { type: 'User', id: 9999 });
      await nextTick();

      expect(createAlert).toHaveBeenCalledWith({
        message: expect.stringContaining('Could not locate'),
      });
    });
  });

  describe('search and clear', () => {
    beforeEach(async () => {
      createWrapper({ activeTypeFilters: new Set(['project']), filterOpen: true });
      await waitForPromises();
      orbitApi.executeOrbitQuery.mockClear();
    });

    it('issues a traversal query when the filter bar emits search-graph', async () => {
      const filterBar = wrapper.findComponent(GraphFilterBar);
      filterBar.vm.$emit('search-graph', { text: 'foo', field: 'name' });
      await waitForPromises();

      expect(orbitApi.executeOrbitQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          query_type: 'traversal',
          node: expect.objectContaining({
            entity: 'Project',
            filters: expect.objectContaining({
              name: { op: 'contains', value: 'foo' },
            }),
          }),
        }),
      );
    });

    it('restores the initial graph when clear-filters is emitted', async () => {
      const filterBar = wrapper.findComponent(GraphFilterBar);
      const canvas = wrapper.findComponent(GraphCanvas);

      filterBar.vm.$emit('update-search-query', 'foo');
      canvas.vm.$emit('node-select', { id: 'Group_1', label: 'frontend', type: 'group' });
      await nextTick();

      expect(wrapper.findComponent(ExplorerNodeSidebar).exists()).toBe(true);

      filterBar.vm.$emit('clear-filters');
      await nextTick();

      expect(wrapper.findComponent(GraphCanvas).props('nodes')).toEqual([mockGroupNode]);
      expect(wrapper.findComponent(ExplorerNodeSidebar).exists()).toBe(false);
      expect(wrapper.findComponent(GraphFilterBar).props('searchQuery')).toBe('');
    });
  });

  describe('zoom controls', () => {
    it('proxies zoom controls to the canvas', async () => {
      createWrapper();
      const canvas = wrapper.findComponent(GraphCanvas);
      canvas.vm.zoomIn = jest.fn();
      canvas.vm.zoomOut = jest.fn();

      const legend = wrapper.findComponent(GraphLegend);
      legend.vm.$emit('zoom-in');
      legend.vm.$emit('zoom-out');
      await nextTick();

      expect(canvas.vm.zoomIn).toHaveBeenCalled();
      expect(canvas.vm.zoomOut).toHaveBeenCalled();
    });
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks click_orbit_execute_query when the query panel emits execute', async () => {
      createWrapper({
        advancedOpen: true,
        initialQuery: { query_type: 'list', entity: 'project' },
      });
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      wrapper.findComponent(ExplorerQueryPanel).vm.$emit('execute');
      await waitForPromises();

      expect(trackEventSpy).toHaveBeenCalledWith('click_orbit_execute_query', {}, undefined);
    });

    it('tracks click_orbit_highlight_legend_type with the picked type as label', () => {
      createWrapper();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      wrapper.findComponent(GraphLegend).vm.$emit('select-type', 'project');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_orbit_highlight_legend_type',
        { label: 'project' },
        undefined,
      );
    });

    it('does not track highlight when toggling the already-soloed type off', async () => {
      createWrapper();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      wrapper.findComponent(GraphLegend).vm.$emit('select-type', 'project');
      await nextTick();
      trackEventSpy.mockClear();

      wrapper.findComponent(GraphLegend).vm.$emit('select-type', 'project');

      expect(trackEventSpy).not.toHaveBeenCalled();
    });

    it.each(['2d', '3d'])(
      'tracks click_orbit_map_node with mapMode "%s" as label when a node is selected',
      (mapMode) => {
        createWrapper({ mapMode });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        wrapper.findComponent(GraphCanvas).vm.$emit('node-select', { id: 'Project_1' });

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_orbit_map_node',
          { label: mapMode },
          undefined,
        );
      },
    );

    it.each(['2d', '3d'])(
      'tracks click_orbit_expand_map_node with mapMode "%s" as label when a node is double-clicked',
      (mapMode) => {
        createWrapper({ mapMode });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        wrapper.findComponent(GraphCanvas).vm.$emit('node-expand', {
          id: 'Project_1',
          type: 'project',
          properties: { id: 1 },
        });

        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_orbit_expand_map_node',
          { label: mapMode },
          undefined,
        );
      },
    );
  });
});
