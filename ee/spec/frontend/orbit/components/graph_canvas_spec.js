import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import GraphCanvas from 'ee/orbit/components/graph_canvas.vue';

const mockGraphInstance = {
  init: jest.fn(),
  setData: jest.fn(),
  addData: jest.fn(),
  dispose: jest.fn(),
  selectNode: jest.fn(),
  deselectNode: jest.fn(),
  resize: jest.fn(),
  zoomBy: jest.fn(),
  searchNodes: jest.fn(() => []),
  highlightByTypes: jest.fn(),
  onNodeHover: jest.fn(),
  onNodeSelect: jest.fn(),
  onNodeExpand: jest.fn(),
  setLabelsVisible: jest.fn(),
  setNodeLoading: jest.fn(),
};

jest.mock('ee/orbit/utils/three_graph_2d', () => ({
  __esModule: true,
  default: jest.fn(),
}));

jest.mock('ee/orbit/utils/three_graph_3d', () => ({
  __esModule: true,
  default: jest.fn(),
}));

// eslint-disable-next-line import/first
import ThreeGraph2D from 'ee/orbit/utils/three_graph_2d';
// eslint-disable-next-line import/first
import ThreeGraph3D from 'ee/orbit/utils/three_graph_3d';

const mockThreeGraph2D = ThreeGraph2D;
const mockThreeGraph3D = ThreeGraph3D;

describe('GraphCanvas', () => {
  let wrapper;
  let mockResizeObserverDisconnect;

  const mockNodes = [
    { id: 'User_1', label: 'Admin', type: 'user' },
    { id: 'User_2', label: 'Dev', type: 'user' },
  ];

  beforeEach(() => {
    jest.clearAllMocks();
    mockThreeGraph2D.mockImplementation(() => mockGraphInstance);
    mockThreeGraph3D.mockImplementation(() => mockGraphInstance);
    mockResizeObserverDisconnect = jest.fn();
    global.ResizeObserver = jest.fn().mockImplementation((cb) => ({
      observe: jest.fn(() => cb([{ contentRect: { width: 800, height: 600 } }])),
      disconnect: mockResizeObserverDisconnect,
    }));
  });

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(GraphCanvas, {
      propsData: {
        nodes: mockNodes,
        edges: [],
        ...props,
      },
      attachTo: document.body,
    });
  };

  describe('rendering', () => {
    it('renders the canvas container', () => {
      createWrapper();

      expect(wrapper.find('[data-testid="graph-canvas"]').exists()).toBe(true);
    });
  });

  describe('initialization by mapMode', () => {
    it('uses ThreeGraph3D by default', () => {
      createWrapper();

      expect(mockThreeGraph3D).toHaveBeenCalled();
      expect(mockThreeGraph2D).not.toHaveBeenCalled();
      expect(mockGraphInstance.init).toHaveBeenCalled();
    });

    it('uses ThreeGraph2D when mapMode is "2d"', () => {
      createWrapper({ mapMode: '2d' });

      expect(mockThreeGraph2D).toHaveBeenCalled();
      expect(mockThreeGraph3D).not.toHaveBeenCalled();
    });

    it('passes nodeStyleMap and darkMode through to the constructor', () => {
      const styleMap = { user: { color: 0x00ff00 } };
      createWrapper({ nodeStyleMap: styleMap, darkMode: false });

      expect(mockThreeGraph3D).toHaveBeenCalledWith(expect.anything(), {
        nodeStyleMap: styleMap,
        darkMode: false,
      });
    });

    it('sets initial data when nodes are provided', () => {
      createWrapper();

      expect(mockGraphInstance.setData).toHaveBeenCalledWith(mockNodes, []);
    });

    it('does not call setData when there are no nodes', () => {
      createWrapper({ nodes: [] });

      expect(mockGraphInstance.setData).not.toHaveBeenCalled();
    });

    it('emits init-error if graph construction throws', () => {
      const error = new Error('boom');
      mockThreeGraph3D.mockImplementationOnce(() => {
        throw error;
      });
      createWrapper({ nodes: [] });

      expect(wrapper.emitted('init-error')).toEqual([[error]]);
      expect(wrapper.emitted('node-select')).toBeUndefined();
    });
  });

  describe('event wiring', () => {
    it('emits node-hover, node-select, and node-expand from the graph callbacks', () => {
      createWrapper();

      const hoverCb = mockGraphInstance.onNodeHover.mock.calls[0][0];
      const selectCb = mockGraphInstance.onNodeSelect.mock.calls[0][0];
      const expandCb = mockGraphInstance.onNodeExpand.mock.calls[0][0];

      hoverCb({ id: 'a' }, { x: 1, y: 2 });
      selectCb({ id: 'a' });
      expandCb({ id: 'a' });

      expect(wrapper.emitted('node-hover')).toEqual([[{ id: 'a' }, { x: 1, y: 2 }]]);
      expect(wrapper.emitted('node-select')).toEqual([[{ id: 'a' }]]);
      expect(wrapper.emitted('node-expand')).toEqual([[{ id: 'a' }]]);
    });
  });

  describe('selectedNodeId watcher', () => {
    it('selects the node by index when the prop becomes set', async () => {
      createWrapper();

      await wrapper.setProps({ selectedNodeId: 'User_2' });

      expect(mockGraphInstance.selectNode).toHaveBeenCalledWith(1);
    });

    it('deselects when the prop becomes null', async () => {
      createWrapper({ selectedNodeId: 'User_1' });
      mockGraphInstance.deselectNode.mockClear();

      await wrapper.setProps({ selectedNodeId: null });

      expect(mockGraphInstance.deselectNode).toHaveBeenCalled();
    });

    it('is a no-op for an unknown id', async () => {
      createWrapper();
      mockGraphInstance.selectNode.mockClear();

      await wrapper.setProps({ selectedNodeId: 'does-not-exist' });

      expect(mockGraphInstance.selectNode).not.toHaveBeenCalled();
    });
  });

  describe('mapMode watcher', () => {
    it('rebuilds the graph when mapMode changes', async () => {
      createWrapper({ mapMode: '3d' });
      mockThreeGraph2D.mockClear();

      await wrapper.setProps({ mapMode: '2d' });
      await nextTick();

      expect(mockGraphInstance.dispose).toHaveBeenCalled();
      expect(mockThreeGraph2D).toHaveBeenCalled();
    });
  });

  describe('exposed methods', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('setFullData calls graph.setData with current props', () => {
      mockGraphInstance.setData.mockClear();
      wrapper.vm.setFullData();

      expect(mockGraphInstance.setData).toHaveBeenCalledWith(mockNodes, []);
    });

    it('addData forwards new nodes and edges to the graph', () => {
      const newNodes = [{ id: 'new' }];
      const newEdges = [{ source: 0, target: 1 }];
      wrapper.vm.addData(newNodes, newEdges);

      expect(mockGraphInstance.addData).toHaveBeenCalledWith(newNodes, newEdges);
    });

    it('searchNodes proxies to the graph implementation', () => {
      mockGraphInstance.searchNodes.mockReturnValueOnce([{ id: 'match' }]);

      const result = wrapper.vm.searchNodes('admin');

      expect(mockGraphInstance.searchNodes).toHaveBeenCalledWith('admin');
      expect(result).toEqual([{ id: 'match' }]);
    });

    it('zoomIn and zoomOut call zoomBy with the documented factors', () => {
      wrapper.vm.zoomIn();
      wrapper.vm.zoomOut();

      expect(mockGraphInstance.zoomBy).toHaveBeenNthCalledWith(1, 0.6);
      expect(mockGraphInstance.zoomBy).toHaveBeenNthCalledWith(2, 1.65);
    });

    it('highlightByTypes proxies the active types set', () => {
      const activeTypes = new Set(['user']);
      wrapper.vm.highlightByTypes(activeTypes);

      expect(mockGraphInstance.highlightByTypes).toHaveBeenCalledWith(activeTypes);
    });

    it('setNodeLoading proxies the node index and loading flag', () => {
      wrapper.vm.setNodeLoading(3, true);
      wrapper.vm.setNodeLoading(3, false);

      expect(mockGraphInstance.setNodeLoading).toHaveBeenNthCalledWith(1, 3, true);
      expect(mockGraphInstance.setNodeLoading).toHaveBeenNthCalledWith(2, 3, false);
    });
  });

  describe('resize handling', () => {
    it('observes the canvas with a ResizeObserver and forwards size changes', () => {
      createWrapper();

      expect(global.ResizeObserver).toHaveBeenCalled();
      expect(mockGraphInstance.resize).toHaveBeenCalledWith(800, 600);
    });
  });

  describe('cleanup on unmount', () => {
    it('disconnects the ResizeObserver and disposes the graph', () => {
      createWrapper();
      expect(mockGraphInstance.dispose).not.toHaveBeenCalled();

      // beforeUnmount (Vue 3 name) doesn't fire under Vue 2 + VTU 1.x destroy()
      // and unmount() isn't part of VTU 1.x. Resolve the hook from $options
      // and invoke it directly so the test runs portably across both runtimes.
      // wrapper.vm hides component data behind `expose:`, so don't reach
      // through it. Trigger the real lifecycle so beforeUnmount fires:
      // unmount() in VTU 2.x (Vue 3) or $destroy() on the instance in
      // VTU 1.x (Vue 2 + compat MODE 3, which routes through the alias).
      // Trigger the real lifecycle so beforeUnmount fires. Vue 3 + VTU 2.x
      // exposes unmount(); Vue 2 + VTU 1.x destroy() routes through
      // beforeDestroy, which the component aliases via a beforeDestroy hook.
      if (typeof wrapper.unmount === 'function') {
        wrapper.unmount();
      } else {
        wrapper.destroy();
      }

      expect(mockResizeObserverDisconnect).toHaveBeenCalled();
      expect(mockGraphInstance.dispose).toHaveBeenCalled();
    });
  });
});
