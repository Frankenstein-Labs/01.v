import { GlToggle } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GraphLegend from 'ee/orbit/components/graph_legend.vue';

describe('GraphLegend', () => {
  let wrapper;

  const items = [
    { type: 'group', name: 'Group', color: '#aaa', count: 3 },
    { type: 'project', name: 'Project', color: '#bbb', count: 5 },
    { type: 'user', name: 'User', color: '#ccc', count: 2 },
    { type: 'mergerequest', name: 'Merge request', color: '#ddd', count: 1 },
    { type: 'workitem', name: 'Work item', color: '#eee', count: null },
    { type: 'pipeline', name: 'Pipeline', color: '#fff', count: 7 },
    { type: 'vulnerability', name: 'Vulnerability', color: '#000', count: 0 },
  ];

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(GraphLegend, {
      propsData: { items, ...props },
      stubs: {
        GlTruncate: { props: ['text'], template: '<span>{{ text }}</span>' },
      },
    });
  };

  const findLegend = () => wrapper.findByTestId('graph-legend');
  const findItems = () => wrapper.findAllByTestId('legend-item');
  const findExpandToggle = () => wrapper.findByTestId('toggle-legend-btn');
  const findLabelsToggle = () => wrapper.findComponent(GlToggle);

  describe('rendering', () => {
    it('renders the legend container only when items exist', () => {
      createWrapper({ items: [] });
      expect(findLegend().exists()).toBe(false);

      createWrapper();
      expect(findLegend().exists()).toBe(true);
    });

    it('sorts items by count descending then name ascending', () => {
      createWrapper();

      const labels = findItems().wrappers.map((w) => w.text());

      // Count descending: pipeline=7, project=5, group=3, user=2, mergerequest=1
      //   then 0/null tied -> name ascending: Vulnerability, Work item
      expect(labels[0]).toContain('Pipeline');
      expect(labels[1]).toContain('Project');
      expect(labels[labels.length - 1]).toContain('Work item');
    });
  });

  describe('compact mode', () => {
    it('shows all items when not compact', () => {
      createWrapper({ isCompact: false });

      expect(findItems()).toHaveLength(items.length);
      expect(findExpandToggle().exists()).toBe(false);
    });

    it('limits to 5 items and shows toggle when compact and over the limit', () => {
      createWrapper({ isCompact: true });

      expect(findItems()).toHaveLength(5);

      const toggle = findExpandToggle();
      expect(toggle.exists()).toBe(true);
      expect(toggle.text()).toContain(`+${items.length - 5}`);
    });

    it('expands to show all items when toggle is clicked', async () => {
      createWrapper({ isCompact: true });

      await findExpandToggle().trigger('click');

      expect(findItems()).toHaveLength(items.length);
    });
  });

  describe('selection state', () => {
    it('all items are active when no filter is applied', () => {
      createWrapper({ activeTypeFilters: new Set() });

      const allItems = findItems();
      allItems.wrappers.forEach((w) => {
        expect(w.attributes('aria-pressed')).toBe('true');
      });
    });

    it('only types in activeTypeFilters are marked active', () => {
      createWrapper({ activeTypeFilters: new Set(['project']) });

      const projectItem = wrapper
        .findAll('[data-testid="legend-item"]')
        .wrappers.find((w) => w.text().includes('Project'));
      const userItem = wrapper
        .findAll('[data-testid="legend-item"]')
        .wrappers.find((w) => w.text().includes('User'));

      expect(projectItem.attributes('aria-pressed')).toBe('true');
      expect(userItem.attributes('aria-pressed')).toBe('false');
    });
  });

  describe('select-type emission', () => {
    it('emits select-type with the clicked type', () => {
      createWrapper();

      const item = wrapper
        .findAll('[data-testid="legend-item"]')
        .wrappers.find((w) => w.text().includes('Project'));
      item.trigger('click');

      expect(wrapper.emitted('select-type')).toEqual([['project']]);
    });
  });

  describe('labels toggle', () => {
    it('reflects the labelsVisible prop', () => {
      createWrapper({ labelsVisible: false });

      expect(findLabelsToggle().props('value')).toBe(false);
    });

    it('emits update-labels-visible with the new value when toggled', () => {
      createWrapper({ labelsVisible: true });

      findLabelsToggle().vm.$emit('change', false);

      expect(wrapper.emitted('update-labels-visible')).toEqual([[false]]);
    });
  });

  describe('counts', () => {
    it('renders the count for items with non-zero counts', () => {
      createWrapper({ items: [items[0]] });

      expect(findItems().at(0).text()).toContain(String(items[0].count));
    });

    it('does not render a count when it is 0 or null', () => {
      createWrapper({ items: [{ type: 'workitem', name: 'Work item', color: '#eee', count: 0 }] });

      expect(findItems().at(0).text()).not.toContain('0');
    });
  });
});
