import { shallowMount } from '@vue/test-utils';
import NodeDetailOverlay from 'ee/orbit/components/node_detail_overlay.vue';

describe('NodeDetailOverlay', () => {
  let wrapper;

  const mockNode = {
    id: 'User_1',
    label: 'Administrator',
    type: 'user',
    fqn: 'gitlab.User.1',
  };

  const mockPosition = { x: 100, y: 200 };

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(NodeDetailOverlay, {
      propsData: props,
    });
  };

  describe('when node and position are provided', () => {
    beforeEach(() => {
      createWrapper({ node: mockNode, position: mockPosition });
    });

    it('renders the overlay', () => {
      expect(wrapper.find('[data-testid="node-detail-overlay"]').exists()).toBe(true);
    });

    it('displays node label', () => {
      expect(wrapper.find('[data-testid="overlay-node-label"]').text()).toBe('Administrator');
    });

    it('positions overlay relative to cursor', () => {
      const style = wrapper.find('[data-testid="node-detail-overlay"]').attributes('style');

      expect(style).toContain('left: 116px');
      expect(style).toContain('top: 190px');
    });
  });

  describe('when node is null', () => {
    beforeEach(() => {
      createWrapper({ node: null, position: mockPosition });
    });

    it('does not render overlay', () => {
      expect(wrapper.find('[data-testid="node-detail-overlay"]').exists()).toBe(false);
    });
  });

  describe('when position is null', () => {
    beforeEach(() => {
      createWrapper({ node: mockNode, position: null });
    });

    it('does not render overlay', () => {
      expect(wrapper.find('[data-testid="node-detail-overlay"]').exists()).toBe(false);
    });
  });

  describe('fallback label', () => {
    it('uses node id when label is missing', () => {
      createWrapper({
        node: { ...mockNode, label: null },
        position: mockPosition,
      });

      expect(wrapper.find('[data-testid="overlay-node-label"]').text()).toBe('User_1');
    });
  });
});
