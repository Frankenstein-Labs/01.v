import { GlCollapsibleListbox } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FlowTypeFilter from 'ee/usage_quotas/usage_billing/users/show/components/flow_type_filter.vue';

describe('FlowTypeFilter', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const mockFlowTypes = [
    { value: 'ai_catalog_agent', text: 'AI Catalog based Agent or Flow' },
    { value: 'other_ai_usage', text: 'Other AI Usage' },
    { value: 'analytics_agent', text: 'Analytics Agent' },
    { value: 'chat', text: 'Agentic Chat' },
    { value: 'code_review', text: 'Code Review Flow' },
    { value: 'code_suggestions', text: 'Code Suggestions' },
    { value: 'software_development', text: 'Software Development Flow' },
  ];

  const createComponent = (props = {}) => {
    wrapper = mountExtended(FlowTypeFilter, {
      propsData: {
        flowTypes: mockFlowTypes,
        appliedFlowTypes: [],
        ...props,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the collapsible listbox', () => {
      expect(findListbox().exists()).toBe(true);
    });

    it('passes flow types to listbox', () => {
      expect(findListbox().props('items')).toEqual(mockFlowTypes);
    });
  });

  describe('toggle text', () => {
    it('shows "Any type" when no flow types are selected', () => {
      createComponent();
      expect(findListbox().props('toggleText')).toBe('Any type');
    });

    it('shows "All types" when all flow types are selected', () => {
      const appliedFlowTypes = mockFlowTypes.map((flowType) => flowType.value);
      createComponent({ appliedFlowTypes });
      expect(findListbox().props('toggleText')).toBe('All types');
    });

    it('shows the flow type name when exactly one is selected', () => {
      createComponent({
        appliedFlowTypes: ['software_development'],
      });
      expect(findListbox().props('toggleText')).toBe('Software Development Flow');
    });

    it('shows count when multiple flow types are selected', () => {
      createComponent({
        appliedFlowTypes: ['software_development', 'code_review'],
      });
      expect(findListbox().props('toggleText')).toBe('2 flow types selected');
    });

    it('shows fallback text when selected type is not found', () => {
      createComponent({
        appliedFlowTypes: ['unknown_type'],
      });
      expect(findListbox().props('toggleText')).toBe('1 flow type selected');
    });
  });

  describe('search functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('filters flow types based on search query', async () => {
      await findListbox().vm.$emit('search', 'code');
      expect(findListbox().props('items')).toEqual([
        { value: 'code_review', text: 'Code Review Flow' },
        { value: 'code_suggestions', text: 'Code Suggestions' },
      ]);
    });

    it('returns all flow types when search is empty', async () => {
      await findListbox().vm.$emit('search', 'code');
      await findListbox().vm.$emit('search', '');
      expect(findListbox().props('items')).toEqual(mockFlowTypes);
    });

    it('is case insensitive', async () => {
      await findListbox().vm.$emit('search', 'SOFTWARE');
      expect(findListbox().props('items')).toEqual([
        { value: 'software_development', text: 'Software Development Flow' },
      ]);
    });

    it('returns empty array when no matches found', async () => {
      await findListbox().vm.$emit('search', 'nonexistent');
      expect(findListbox().props('items')).toEqual([]);
    });
  });

  describe('selection', () => {
    beforeEach(() => {
      createComponent();
    });

    it('initializes with applied flow types', () => {
      createComponent({
        appliedFlowTypes: ['software_development', 'code_review'],
      });
      expect(findListbox().props('selected')).toEqual(['software_development', 'code_review']);
    });

    it('syncs selected flow types when appliedFlowTypes prop changes', async () => {
      createComponent({
        appliedFlowTypes: ['software_development'],
      });
      await wrapper.setProps({
        appliedFlowTypes: ['code_review', 'chat'],
      });
      expect(findListbox().props('selected')).toEqual(['code_review', 'chat']);
    });
  });

  describe('select all functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('selects all flow types when select all is triggered', async () => {
      await findListbox().vm.$emit('select-all');
      expect(findListbox().props('selected')).toEqual(mockFlowTypes.map((ft) => ft.value));
    });

    it('updates toggle text to "All types" after select all', async () => {
      await findListbox().vm.$emit('select-all');
      expect(findListbox().props('toggleText')).toBe('All types');
    });
  });

  describe('reset functionality', () => {
    beforeEach(() => {
      createComponent({
        appliedFlowTypes: ['software_development', 'code_review'],
      });
    });

    it('clears selected flow types when reset is triggered', async () => {
      await findListbox().vm.$emit('reset');
      expect(findListbox().props('selected')).toEqual([]);
    });

    it('clears search when reset is triggered', async () => {
      await findListbox().vm.$emit('search', 'code');
      await findListbox().vm.$emit('reset');
      expect(findListbox().props('items')).toEqual(mockFlowTypes);
    });

    it('updates toggle text to "Any type" after reset', async () => {
      await findListbox().vm.$emit('reset');
      expect(findListbox().props('toggleText')).toBe('Any type');
    });
  });

  describe('apply filter', () => {
    beforeEach(() => {
      createComponent({
        appliedFlowTypes: ['software_development'],
      });
    });

    it('will apply filter on close', async () => {
      await findListbox().vm.$emit('hidden');

      expect(wrapper.emitted('apply')).toHaveLength(1);
      expect(wrapper.emitted('apply')[0]).toEqual([['software_development']]);
    });

    it('emits selected flow types', async () => {
      wrapper.vm.selectedFlowTypes = ['code_review', 'chat'];
      await nextTick();
      await findListbox().vm.$emit('hidden');

      expect(wrapper.emitted('apply')).toHaveLength(1);
      expect(wrapper.emitted('apply')[0]).toEqual([['code_review', 'chat']]);
    });
  });
});
