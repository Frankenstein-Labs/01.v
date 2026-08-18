import { shallowMount } from '@vue/test-utils';
import ExplorerNodeSidebar from 'ee/orbit/components/explorer_node_sidebar.vue';

describe('ExplorerNodeSidebar', () => {
  let wrapper;

  const mockNode = {
    id: 'User_1',
    label: 'Administrator',
    type: 'user',
    properties: {
      id: 1,
      username: 'admin',
      name: 'Administrator',
    },
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(ExplorerNodeSidebar, {
      propsData: {
        node: mockNode,
        ...props,
      },
      stubs: { RouterLink: true },
    });
  };

  describe('rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the sidebar', () => {
      expect(wrapper.find('[data-testid="explorer-node-sidebar"]').exists()).toBe(true);
    });

    it('displays node label', () => {
      expect(wrapper.find('[data-testid="sidebar-node-label"]').text()).toBe('Administrator');
    });

    it('displays node type', () => {
      expect(wrapper.find('[data-testid="sidebar-node-type"]').text()).toBe('User');
    });

    it('displays node properties', () => {
      expect(wrapper.find('[data-testid="explorer-node-sidebar"]').text()).toContain('admin');
    });

    it('filters out empty property values', () => {
      createWrapper({
        node: {
          ...mockNode,
          properties: { id: 1, empty: '', nullVal: null },
        },
      });

      const sidebarText = wrapper.find('[data-testid="explorer-node-sidebar"]').text();

      expect(sidebarText).not.toContain('empty');
      expect(sidebarText).not.toContain('nullVal');
    });
  });

  describe('close', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits close on close button click', () => {
      wrapper.findComponent('[data-testid="close-sidebar-btn"]').vm.$emit('click');

      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });

  describe('fallback label', () => {
    it('uses node id as label when label is missing', () => {
      createWrapper({
        node: { ...mockNode, label: '' },
      });

      expect(wrapper.find('[data-testid="sidebar-node-label"]').text()).toBe('User_1');
    });
  });
});
