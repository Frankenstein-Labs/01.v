import { GlButton, GlCollapsibleListbox, GlFormInput } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import GraphFilterBar from 'ee/orbit/components/graph_filter_bar.vue';

describe('GraphFilterBar', () => {
  let wrapper;

  const legendItems = [
    { type: 'group', name: 'Group', color: '#aaa', count: 3 },
    { type: 'project', name: 'Project', color: '#bbb', count: 5 },
    { type: 'user', name: 'User', color: '#ccc', count: 2 },
  ];

  const schemaNodes = [
    {
      name: 'Project',
      label_field: 'name',
      properties: [
        { name: 'name', data_type: 'string' },
        { name: 'path', data_type: 'string' },
        { name: 'created_at', data_type: 'datetime' },
        { name: 'visibility', data_type: 'enum' },
      ],
    },
  ];

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(GraphFilterBar, {
      propsData: {
        searchQuery: '',
        legendItems,
        activeTypeFilters: new Set(),
        schemaNodes,
        loading: false,
        ...props,
      },
    });
  };

  const findSearchInput = () => wrapper.findByTestId('graph-search-input');
  const findClearButton = () => wrapper.findComponentByTestId('clear-filter-x');
  const findSubmitButton = () => wrapper.findComponentByTestId('search-submit');

  describe('type listbox', () => {
    it('renders the type selector with one item per legend entry', () => {
      createWrapper();

      const listbox = wrapper.findAllComponents(GlCollapsibleListbox).at(0);
      expect(listbox.props('items')).toHaveLength(3);
      expect(listbox.props('items')[0].text).toBe('Group');
      expect(listbox.props('headerText')).toBe('Filter by type');
      expect(listbox.props('resetButtonLabel')).toBe('Clear');
    });

    it('emits update-active-type-filters with a single-element set when a type is picked', () => {
      createWrapper();

      const listbox = wrapper.findAllComponents(GlCollapsibleListbox).at(0);
      listbox.vm.$emit('select', 'project');

      const emitted = wrapper.emitted('update-active-type-filters');
      expect(emitted).toHaveLength(1);
      expect(Array.from(emitted[0][0])).toEqual(['project']);
    });

    it('does not emit when the picked type is already the solo filter', () => {
      createWrapper({ activeTypeFilters: new Set(['user']) });

      const listbox = wrapper.findAllComponents(GlCollapsibleListbox).at(0);
      listbox.vm.$emit('select', 'user');

      expect(wrapper.emitted('update-active-type-filters')).toBeUndefined();
    });
  });

  describe('with a solo type selected', () => {
    beforeEach(() => {
      createWrapper({ activeTypeFilters: new Set(['project']) });
    });

    it('renders the field listbox with the schema string/enum properties', () => {
      const fieldListbox = wrapper.findAllComponents(GlCollapsibleListbox).at(1);
      const items = fieldListbox.props('items');

      expect(items.map((i) => i.value)).toEqual(['name', 'path', 'visibility']);
    });

    it('renders the search input and clear button', () => {
      expect(findSearchInput().exists()).toBe(true);
      expect(findClearButton().exists()).toBe(true);
    });

    it('emits update-search-query as the user types', () => {
      const input = wrapper.findComponent(GlFormInput);
      input.vm.$emit('input', 'foo');

      expect(wrapper.emitted('update-search-query')).toEqual([['foo']]);
    });

    it('emits search-graph with the trimmed text and active field on submit', async () => {
      await wrapper.setProps({ searchQuery: '  hello  ' });

      findSubmitButton().vm.$emit('click');

      expect(wrapper.emitted('search-graph')).toEqual([[{ text: 'hello', field: 'name' }]]);
    });

    it('does not emit search-graph when the query is empty/whitespace', async () => {
      await wrapper.setProps({ searchQuery: '   ' });

      findSubmitButton().vm.$emit('click');

      expect(wrapper.emitted('search-graph')).toBeUndefined();
    });

    it('clear button clears search text, filters, and graph results', () => {
      findClearButton().vm.$emit('click');

      expect(wrapper.emitted('update-search-query')).toEqual([['']]);
      const updates = wrapper.emitted('update-active-type-filters');
      expect(Array.from(updates[updates.length - 1][0])).toEqual([]);
      expect(wrapper.emitted('clear-filters')).toHaveLength(1);
    });

    it('type listbox reset clears filters', () => {
      const listbox = wrapper.findAllComponents(GlCollapsibleListbox).at(0);
      listbox.vm.$emit('reset');

      expect(wrapper.emitted('update-search-query')).toEqual([['']]);
      const updates = wrapper.emitted('update-active-type-filters');
      expect(Array.from(updates[updates.length - 1][0])).toEqual([]);
      expect(wrapper.emitted('clear-filters')).toHaveLength(1);
    });
  });

  describe('field selection', () => {
    it('switches the active field when the field listbox emits select', async () => {
      createWrapper({ activeTypeFilters: new Set(['project']), searchQuery: 'foo' });

      const fieldListbox = wrapper.findAllComponents(GlCollapsibleListbox).at(1);
      fieldListbox.vm.$emit('select', 'path');
      await nextTick();

      const submit = wrapper
        .findAllComponents(GlButton)
        .wrappers.find((b) => b.attributes('data-testid') === 'search-submit');
      submit.vm.$emit('click');

      expect(wrapper.emitted('search-graph')).toEqual([[{ text: 'foo', field: 'path' }]]);
    });
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks click_orbit_apply_filter with the active type as label when search submits', () => {
      createWrapper({ activeTypeFilters: new Set(['project']), searchQuery: 'hello' });
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findSubmitButton().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_orbit_apply_filter',
        { label: 'project' },
        undefined,
      );
    });

    it('does not track when search submits with an empty query', () => {
      createWrapper({ activeTypeFilters: new Set(['project']), searchQuery: '   ' });
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findSubmitButton().vm.$emit('click');

      expect(trackEventSpy).not.toHaveBeenCalled();
    });

    it('does not track when only a type is picked from the listbox', () => {
      createWrapper();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      const listbox = wrapper.findAllComponents(GlCollapsibleListbox).at(0);
      listbox.vm.$emit('select', 'project');

      expect(trackEventSpy).not.toHaveBeenCalled();
    });
  });
});
