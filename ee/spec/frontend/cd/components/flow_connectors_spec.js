import { throttle } from 'lodash-es';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import FlowConnectors from 'ee/cd/components/flow_connectors.vue';
import { measureNode, connectorPath } from 'ee/cd/flow_graph';

jest.mock('lodash-es', () => ({
  ...jest.requireActual('lodash-es'),
  throttle: jest.fn((callback) => Object.assign(callback, { cancel: jest.fn() })),
}));

jest.mock('ee/cd/flow_graph', () => ({
  measureNode: jest.fn((element) => element.dataset.flowNode),
  connectorPath: jest.fn((source, target) => `${source}->${target}`),
}));

const NODE_IDS = ['a', 'b', 'c'];
const CONTAINER_RECT = { left: 100, top: 200 };

describe('FlowConnectors', () => {
  let wrapper;
  let root;
  let container;
  let resize;
  let observed;
  let disconnect;

  beforeEach(() => {
    disconnect = jest.fn();
    global.ResizeObserver = jest.fn((callback) => {
      resize = callback;

      return {
        observe: (element) => {
          observed = element;
        },
        disconnect,
        unobserve: jest.fn(),
      };
    });
  });

  const createNode = (nodeId) => {
    const node = document.createElement('div');
    node.dataset.flowNode = nodeId;

    return node;
  };

  const createComponent = ({ edges, nodeIds = NODE_IDS }) => {
    root = document.createElement('div');
    document.body.appendChild(root);

    const mountPoint = document.createElement('div');
    root.appendChild(mountPoint);

    wrapper = mountExtended(FlowConnectors, { propsData: { edges }, attachTo: mountPoint });

    container = wrapper.element.parentElement;
    container.getBoundingClientRect = () => CONTAINER_RECT;
    nodeIds.forEach((nodeId) => container.appendChild(createNode(nodeId)));
  };

  const findPaths = () => wrapper.findAllByTestId('flow-connector');
  const drawnPaths = () => findPaths().wrappers.map((path) => path.attributes('d'));
  const measuredAgainst = () =>
    measureNode.mock.calls.map(([element, rect]) => [element.dataset.flowNode, rect]);

  afterEach(() => {
    root?.remove();
  });

  describe('drawing', () => {
    describe('for a fan out', () => {
      beforeEach(async () => {
        createComponent({
          edges: [
            { from: 'a', to: 'b' },
            { from: 'a', to: 'c' },
          ],
        });
        await waitForPromises();
      });

      it('measures every node an edge names against the container', () => {
        expect(measuredAgainst()).toEqual([
          ['a', CONTAINER_RECT],
          ['b', CONTAINER_RECT],
          ['a', CONTAINER_RECT],
          ['c', CONTAINER_RECT],
        ]);
      });

      it('draws a path from the shared source to each target, in order', () => {
        expect(drawnPaths()).toEqual(['a->b', 'a->c']);
      });
    });

    it('redraws when the edges change', async () => {
      createComponent({ edges: [{ from: 'a', to: 'b' }] });
      await waitForPromises();

      await wrapper.setProps({ edges: [{ from: 'a', to: 'c' }] });
      await waitForPromises();

      expect(drawnPaths()).toEqual(['a->c']);
    });
  });

  describe('redrawing when the container resizes', () => {
    beforeEach(async () => {
      createComponent({ edges: [{ from: 'a', to: 'b' }] });
      await waitForPromises();
    });

    it('observes the container it measures, not itself', () => {
      expect(observed).toBe(container);
    });

    it('redraws on a resize, so the arrows follow the boxes', async () => {
      connectorPath.mockReturnValue('redrawn');

      resize();
      await waitForPromises();

      expect(drawnPaths()).toEqual(['redrawn']);
    });

    it('throttles the redraw, so a drag does not remeasure every frame', () => {
      expect(throttle).toHaveBeenCalledWith(expect.any(Function), 250);
    });

    it('stops observing and cancels a pending redraw on destroy', () => {
      const [throttled] = throttle.mock.results;

      wrapper.destroy();

      expect(disconnect).toHaveBeenCalled();
      expect(throttled.value.cancel).toHaveBeenCalled();
    });
  });

  describe('when an edge names a node that is not rendered', () => {
    beforeEach(async () => {
      createComponent({
        edges: [
          { from: 'a', to: 'b' },
          { from: 'a', to: 'missing' },
        ],
        nodeIds: ['a', 'b'],
      });
      await waitForPromises();
    });

    it('skips that edge rather than drawing a broken path', () => {
      expect(findPaths()).toHaveLength(1);
    });
  });

  describe('markup', () => {
    beforeEach(async () => {
      createComponent({ edges: [{ from: 'a', to: 'b' }] });
      await waitForPromises();
    });

    it('points every path at the shared arrowhead marker', () => {
      expect(findPaths().at(0).attributes('marker-end')).toBe('url(#cd-flow-arrow)');
      expect(wrapper.find('marker').attributes('id')).toBe('cd-flow-arrow');
    });

    it('hides the overlay from assistive technology and from the pointer', () => {
      expect(wrapper.attributes('aria-hidden')).toBe('true');
      expect(wrapper.classes()).toContain('gl-pointer-events-none');
    });
  });
});
